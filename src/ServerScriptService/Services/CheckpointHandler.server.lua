--[[
	CheckpointHandler.server.lua
	Description: Core race-loop state machine. Discovers checkpoint Parts from
	             map folders, wires Touched events, enforces checkpoint order,
	             fires EventBus events and client RemoteEvents.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Constants (ReplicatedStorage.Shared.Constants)
		- Logger    (ReplicatedStorage.Shared.Logger)
		- MapData   (ReplicatedStorage.Shared.MapData)
		- EventBus  (ServerScriptService.Services.EventBus)

	Events Fired (via EventBus):
		- RaceStarted(player, mapId)
		- CheckpointHit(player, checkpointNum, total)
		- RaceFinished(player, mapId, elapsed)

	Events Listened (via EventBus):
		- None (uses BindableFunctions for synchronous TimerHandler/CoinHandler results)

	Remote Events Fired (S->C):
		- Remotes.RaceStarted
		- Remotes.CheckpointReached
		- Remotes.RaceFinished

	Remote Events Handled (C->S):
		- Remotes.RaceAgain
--]]

-- 1. Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- 2. Constants & shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))
local MapData      = require(sharedFolder:WaitForChild("MapData", 10))

-- 3. Server-only dependencies
local servicesFolder = script.Parent
local EventBus       = require(servicesFolder:WaitForChild("EventBus", 10))

local TAG = "CheckpointHandler"

-- 4. Remote events
local remotesFolder      = ReplicatedStorage:WaitForChild(Constants.REMOTES_PATH, 10)
local checkpointReached  = remotesFolder:WaitForChild("CheckpointReached", 10)
local raceStartedRemote  = remotesFolder:WaitForChild("RaceStarted", 10)
local raceFinishedRemote = remotesFolder:WaitForChild("RaceFinished", 10)
local raceAgainRemote    = remotesFolder:WaitForChild("RaceAgain", 10)

-- 5. BindableFunctions (synchronous request-reply with TimerHandler / CoinHandler)
local raceHandlers     = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceTime  = raceHandlers:WaitForChild("ProcessRaceTime", 30)
local processRaceCoins = raceHandlers:WaitForChild("ProcessRaceCoins", 30)

-- 6. Private state
-- playerRace[userId] = { mapId, nextCheckpoint, totalCheckpoints, startClock, active }
local playerRace = {}

-- mapCheckpoints[mapId][num] = BasePart
local mapCheckpoints = {}

-- 7. Private functions

-- Resolve a touching part to the owning player via "Vehicle_[UserId]" naming
local function getPlayerFromHit(hit)
	local model = hit:FindFirstAncestorWhichIsA("Model")
	if not model then return nil, nil end
	local userId = tonumber(model.Name:match("^Vehicle_(%d+)$"))
	if not userId then return nil, nil end
	local player = Players:GetPlayerByUserId(userId)
	return player, userId
end

-- Discover checkpoint Parts from all configured map folders
local function discoverCheckpoints()
	local selectedMapId = workspace:GetAttribute("SelectedMap")
	if selectedMapId then
		Logger.Info(TAG, "Limiting discovery to selected map '%s'", tostring(selectedMapId))
	else
		Logger.Info(TAG, "No SelectedMap attribute; discovering all configured maps")
	end

	for _, map in ipairs(MapData) do
		if selectedMapId and map.Id ~= selectedMapId then
			continue
		end

		local folder = workspace:FindFirstChild(map.FolderName)
		if not folder then
			Logger.Warn(TAG, "Map folder not found in Workspace: %s", map.FolderName)
			continue
		end

		local checkpoints = {}
		for _, part in ipairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				local num = tonumber(part.Name:match("^Checkpoint_(%d+)$"))
				if num then
					checkpoints[num] = part
				end
			end
		end

		if next(checkpoints) == nil then
			Logger.Warn(TAG, "No checkpoint parts found in: %s", map.FolderName)
			continue
		end

		local total = 0
		for num in pairs(checkpoints) do
			if num ~= Constants.CHECKPOINT_FINISH then
				total = total + 1
			end
		end

		mapCheckpoints[map.Id] = checkpoints
		Logger.Info(TAG, "%-20s -> %d checkpoint(s) + finish", map.FolderName, total)
	end
end

-- Wire Touched events for every discovered checkpoint
local function wireCheckpoints()
	for mapId, checkpoints in pairs(mapCheckpoints) do
		local total = 0
		for num in pairs(checkpoints) do
			if num ~= Constants.CHECKPOINT_FINISH then total = total + 1 end
		end

		for num, part in pairs(checkpoints) do
			local capturedNum   = num
			local capturedMapId = mapId
			local capturedTotal = total

			part.Touched:Connect(function(hit)
				local player, userId = getPlayerFromHit(hit)
				if not player then return end

				local race = playerRace[userId]

				-- Finish line (Checkpoint_99)
				if capturedNum == Constants.CHECKPOINT_FINISH then
					if not race or not race.active then return end
					if race.mapId ~= capturedMapId then return end
					if race.nextCheckpoint ~= capturedTotal + 1 then return end

					local elapsed = os.clock() - race.startClock

					-- Anti-cheat: reject suspiciously fast completions
					if elapsed < Constants.MIN_RACE_TIME then
						Logger.Warn(TAG, "ANTI-CHEAT: %s finished '%s' in %.2fs (min=%ds) — rejected",
							player.Name, capturedMapId, elapsed, Constants.MIN_RACE_TIME)
						return
					end

					-- Stop the race
					race.active = false
					playerRace[userId] = nil

					-- Delegate to TimerHandler (best-time persistence)
					local timeResult = processRaceTime:Invoke(player, capturedMapId, elapsed)
					-- Delegate to CoinHandler (coin awards)
					local coinResult = processRaceCoins:Invoke(player, capturedMapId)

					-- Notify via EventBus for additional observers
					EventBus:Fire("RaceFinished", player, capturedMapId, elapsed)

					-- Send full result payload to the client
					raceFinishedRemote:FireClient(player, {
						mapId       = capturedMapId,
						elapsed     = elapsed,
						isNewBest   = timeResult and timeResult.isNewBest  or false,
						bestTime    = timeResult and timeResult.bestTime   or elapsed,
						coinsEarned = coinResult and coinResult.coinsEarned or 0,
						totalCoins  = coinResult and coinResult.totalCoins  or 0,
					})

					Logger.Info(TAG, "%s finished '%s' in %.3fs | newBest=%s | coins+%d",
						player.Name, capturedMapId, elapsed,
						tostring(timeResult and timeResult.isNewBest),
						coinResult and coinResult.coinsEarned or 0)

				-- Numbered checkpoint
				else
					if not race or not race.active then
						if capturedNum ~= 1 then return end

						-- Anti-cheat: verify vehicle exists in Workspace
						local vehicleName = string.format("Vehicle_%d", userId)
						if not workspace:FindFirstChild(vehicleName) then
							Logger.Warn(TAG, "ANTI-CHEAT: %s hit CP1 but no vehicle in Workspace", player.Name)
							return
						end

						playerRace[userId] = {
							mapId            = capturedMapId,
							nextCheckpoint   = 1,
							totalCheckpoints = capturedTotal,
							startClock       = os.clock(),
							active           = true,
						}
						race = playerRace[userId]

						EventBus:Fire("RaceStarted", player, capturedMapId)
						raceStartedRemote:FireClient(player, { mapId = capturedMapId })
						Logger.Info(TAG, "Race started — %s on '%s'", player.Name, capturedMapId)
					end

					if race.mapId ~= capturedMapId then return end
					if capturedNum ~= race.nextCheckpoint then return end

					race.nextCheckpoint = race.nextCheckpoint + 1

					EventBus:Fire("CheckpointHit", player, capturedNum, capturedTotal)
					checkpointReached:FireClient(player, {
						mapId = capturedMapId,
						index = capturedNum,
						total = capturedTotal,
					})

					Logger.Info(TAG, "%s hit CP %d/%d on '%s'",
						player.Name, capturedNum, capturedTotal, capturedMapId)
				end
			end)
		end
	end
end

-- 8. Event handlers

raceAgainRemote.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	playerRace[player.UserId] = nil
	Logger.Info(TAG, "Race state reset for %s", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	playerRace[player.UserId] = nil
end)

-- 9. Initialization
-- Wait for map generators (synchronous scripts) to finish placing checkpoint Parts.
local CHECKPOINT_DISCOVERY_DELAY = 5
task.wait(CHECKPOINT_DISCOVERY_DELAY)
discoverCheckpoints()
wireCheckpoints()
Logger.Info(TAG, "Ready — monitoring %d map(s)", #MapData)
