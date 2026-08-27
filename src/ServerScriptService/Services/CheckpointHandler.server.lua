--[[
	CheckpointHandler.server.lua
	Description: Core race-loop state machine for a CLOSED-LOOP circuit. Discovers
	             checkpoint Parts, enforces checkpoint order, counts laps, and
	             fires EventBus events plus client RemoteEvents.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Lap model: Checkpoint_99 is the start/finish line. Crossing it with no active
	race STARTS one. Crossing it again only counts once every numbered checkpoint
	has been hit in order, which is what prevents lap-skipping.

	Dependencies:
		- Constants (ReplicatedStorage.Module.Constants)
		- Logger    (ReplicatedStorage.Module.Logger)
		- MapData   (ReplicatedStorage.Module.MapData)
		- EventBus  (ReplicatedStorage.Module.EventBus)
		- RaceUtil  (ServerScriptService.Services.RaceUtil)

	Events Fired (via EventBus):
		- RaceStarted(player, mapId)
		- CheckpointHit(player, checkpointNum, total)
		- LapCompleted(player, mapId, lapNumber, lapTime)
		- RaceFinished(player, mapId, elapsed)

	Remote Events Fired (S->C):
		- Remotes.RaceStarted / CheckpointReached / LapCompleted / RaceFinished

	Remote Events Handled (C->S):
		- Remotes.RaceAgain
--]]

-- 1. Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- 2. Constants & shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))
local MapData      = require(sharedFolder:WaitForChild("MapData", 10))
local EventBus     = require(sharedFolder:WaitForChild("EventBus", 10))
local PlayerData   = require(sharedFolder:WaitForChild("PlayerData", 10))

local TAG = "CheckpointHandler"
local DEFAULT_TOTAL_LAPS = 3
local MIN_LAP_TIME = Constants.MIN_RACE_TIME or 5

-- 3. Remote events
local remotesFolder      = ReplicatedStorage:WaitForChild(Constants.REMOTES_PATH, 10)
local checkpointReached  = remotesFolder:WaitForChild("CheckpointReached", 10)
local raceStartedRemote  = remotesFolder:WaitForChild("RaceStarted", 10)
local raceFinishedRemote = remotesFolder:WaitForChild("RaceFinished", 10)
local raceAgainRemote    = remotesFolder:WaitForChild("RaceAgain", 10)

local endRaceRemote = remotesFolder:FindFirstChild("EndRace")
if not endRaceRemote then
	endRaceRemote = Instance.new("RemoteEvent")
	endRaceRemote.Name = "EndRace"
	endRaceRemote.Parent = remotesFolder
end

local returnHomeRemote = remotesFolder:FindFirstChild("ReturnToLobby")
if not returnHomeRemote then
	returnHomeRemote = Instance.new("RemoteEvent")
	returnHomeRemote.Name = "ReturnToLobby"
	returnHomeRemote.Parent = remotesFolder
end

local progressFunction = remotesFolder:FindFirstChild("GetRaceProgress")
if not progressFunction then
	progressFunction = Instance.new("RemoteFunction")
	progressFunction.Name = "GetRaceProgress"
	progressFunction.Parent = remotesFolder
end

local lapCompletedRemote = remotesFolder:FindFirstChild("LapCompleted")
if not lapCompletedRemote then
	lapCompletedRemote = Instance.new("RemoteEvent")
	lapCompletedRemote.Name = "LapCompleted"
	lapCompletedRemote.Parent = remotesFolder
end

-- 4. BindableFunctions
local raceHandlers     = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceTime  = raceHandlers:WaitForChild("ProcessRaceTime", 30)
local processRaceCoins = raceHandlers:WaitForChild("ProcessRaceCoins", 30)

-- 5. Private state
-- playerRace[userId] = { mapId, lap, totalLaps, nextCheckpoint, totalCheckpoints,
--                        raceStart, lapStart, bestLap, active }
local playerRace = {}
local mapCheckpoints = {}
local mapTotalLaps = {}

progressFunction.OnServerInvoke = function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return {} end
	local data = PlayerDataInterface.GetData(player.UserId) or {}
	return data.BestTimes or {}
end

local function clearRace(player)
	playerRace[player.UserId] = nil
	player:SetAttribute("RaceActive", false)
	player:SetAttribute("RaceVehicleSpawned", false)
end

-- 6. Private functions

-- Vehicle parts live inside nested child Models, so the first Model ancestor is
-- never the Vehicle_ model. RaceUtil walks the full chain -- see its comment.
local RaceUtil = require(script.Parent:WaitForChild("RaceUtil", 10))
local PlayerDataInterface = require(script.Parent:WaitForChild("PlayerDataInterface", 10))
local function getPlayerFromHit(hit)
	return RaceUtil.GetPlayerFromHit(hit)
end

local function discoverCheckpoints()
	local discovered = 0
	for _, map in ipairs(MapData) do
		local folder = workspace:FindFirstChild(map.FolderName)
		if not folder then
			Logger.Warn(TAG, "Map folder not found in Workspace: %s", map.FolderName)
			continue
		end

		local checkpoints = {}
		for _, part in ipairs(folder:GetDescendants()) do
			if part:IsA("BasePart") then
				local num = tonumber(part.Name:match("^Checkpoint_(%d+)$"))
				if num then checkpoints[num] = part end
			end
		end

		if next(checkpoints) == nil then
			Logger.Warn(TAG, "No checkpoint parts found in: %s", map.FolderName)
			continue
		end

		local total = 0
		for num in pairs(checkpoints) do
			if num ~= Constants.CHECKPOINT_FINISH then total += 1 end
		end

		mapCheckpoints[map.Id] = checkpoints
		mapTotalLaps[map.Id] = folder:GetAttribute("TotalLaps") or DEFAULT_TOTAL_LAPS
		discovered += 1
		Logger.Info(TAG, "%s -> %d checkpoint(s) + finish, %d lap(s)",
			map.FolderName, total, mapTotalLaps[map.Id])
	end

	return discovered
end

local function startRace(player, userId, mapId, totalCheckpoints)
	local now = os.clock()
	player:SetAttribute("RaceActive", true)
	playerRace[userId] = {
		mapId            = mapId,
		lap              = 1,
		totalLaps        = mapTotalLaps[mapId] or DEFAULT_TOTAL_LAPS,
		nextCheckpoint   = 1,
		totalCheckpoints = totalCheckpoints,
		raceStart        = now,
		lapStart         = now,
		bestLap          = nil,
		active           = true,
	}

	EventBus:Fire("RaceStarted", player, mapId)
	raceStartedRemote:FireClient(player, {
		mapId            = mapId,
		lap              = 1,
		totalLaps        = playerRace[userId].totalLaps,
		totalCheckpoints = totalCheckpoints,
	})
	Logger.Info(TAG, "Race started - %s on '%s' (%d laps)",
		player.Name, mapId, playerRace[userId].totalLaps)
end

local function finishRace(player, userId, race)
	local elapsed = os.clock() - race.raceStart
	race.active = false
	clearRace(player)

	local timeResult = processRaceTime:Invoke(player, race.mapId, elapsed)
	local coinResult = processRaceCoins:Invoke(player, race.mapId, timeResult and timeResult.isNewBest)

	EventBus:Fire("RaceFinished", player, race.mapId, elapsed)

	raceFinishedRemote:FireClient(player, {
		mapId       = race.mapId,
		elapsed     = elapsed,
		totalLaps   = race.totalLaps,
		bestLap     = race.bestLap,
		isNewBest   = timeResult and timeResult.isNewBest  or false,
		bestTime    = timeResult and timeResult.bestTime   or elapsed,
		coinsEarned = coinResult and coinResult.coinsEarned or 0,
		totalCoins  = coinResult and coinResult.totalCoins  or 0,
	})

	Logger.Info(TAG, "%s FINISHED '%s' in %.3fs | bestLap=%.3fs | coins+%d",
		player.Name, race.mapId, elapsed, race.bestLap or -1,
		coinResult and coinResult.coinsEarned or 0)
end

local function onFinishLineTouched(player, userId, mapId, totalCheckpoints)
	local race = playerRace[userId]

	-- Races are started from the map menu. The finish line only completes laps.
	if not race or not race.active then return end

	if race.mapId ~= mapId then return end

	-- Must have hit every numbered checkpoint this lap before the line counts.
	if race.nextCheckpoint ~= race.totalCheckpoints + 1 then
		return
	end

	local now = os.clock()
	local lapTime = now - race.lapStart

	-- Anti-cheat: a lap far quicker than physically possible is rejected.
	if lapTime < MIN_LAP_TIME then
		Logger.Warn(TAG, "ANTI-CHEAT: %s lap in %.2fs (min=%ds) - rejected",
			player.Name, lapTime, MIN_LAP_TIME)
		return
	end

	if not race.bestLap or lapTime < race.bestLap then
		race.bestLap = lapTime
	end

	if race.lap >= race.totalLaps then
		finishRace(player, userId, race)
		return
	end

	-- Advance to the next lap.
	race.lap += 1
	race.nextCheckpoint = 1
	race.lapStart = now

	EventBus:Fire("LapCompleted", player, mapId, race.lap - 1, lapTime)
	lapCompletedRemote:FireClient(player, {
		mapId     = mapId,
		lap       = race.lap,
		totalLaps = race.totalLaps,
		lastLap   = lapTime,
		bestLap   = race.bestLap,
	})

	Logger.Info(TAG, "%s completed lap %d/%d in %.3fs",
		player.Name, race.lap - 1, race.totalLaps, lapTime)
end

local function onCheckpointTouched(player, userId, mapId, num, totalCheckpoints)
	local race = playerRace[userId]
	if not race or not race.active then return end
	if race.mapId ~= mapId then return end
	if num ~= race.nextCheckpoint then return end

	race.nextCheckpoint += 1

	EventBus:Fire("CheckpointHit", player, num, totalCheckpoints)
	checkpointReached:FireClient(player, {
		mapId     = mapId,
		index     = num,
		total     = totalCheckpoints,
		lap       = race.lap,
		totalLaps = race.totalLaps,
	})
end

local function wireCheckpoints()
	for mapId, checkpoints in pairs(mapCheckpoints) do
		local total = 0
		for num in pairs(checkpoints) do
			if num ~= Constants.CHECKPOINT_FINISH then total += 1 end
		end

		for num, part in pairs(checkpoints) do
			local capturedNum, capturedMapId, capturedTotal = num, mapId, total

			part.Touched:Connect(function(hit)
				local player, userId = getPlayerFromHit(hit)
				if not player then return end

				if capturedNum == Constants.CHECKPOINT_FINISH then
					onFinishLineTouched(player, userId, capturedMapId, capturedTotal)
				else
					onCheckpointTouched(player, userId, capturedMapId, capturedNum, capturedTotal)
				end
			end)
		end
	end
end

-- 7. Event handlers

endRaceRemote.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	clearRace(player)
	Logger.Info(TAG, "%s ended the race", player.Name)
end)

returnHomeRemote.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	clearRace(player)
	workspace:SetAttribute("SelectedMap", Constants.DEFAULT_MAP_ID)
	Logger.Info(TAG, "%s returned to CityHub", player.Name)
end)

local startRaceRemote = remotesFolder:FindFirstChild("StartRace")
if startRaceRemote then
	startRaceRemote.OnServerEvent:Connect(function(player, mapId)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		if playerRace[player.UserId] and playerRace[player.UserId].active then
			Logger.Warn(TAG, "%s attempted to restart an active race", player.Name)
			return
		end

		local targetMap = type(mapId) == "string" and mapId or workspace:GetAttribute("SelectedMap") or "skyscraper"
		local mapInfo
		for _, candidate in ipairs(MapData) do
			if candidate.Id == targetMap then
				mapInfo = candidate
				break
			end
		end
		if not mapInfo then
			Logger.Warn(TAG, "%s requested unknown map '%s'", player.Name, tostring(targetMap))
			return
		end

		local data = PlayerDataInterface.GetData(player.UserId)
		if not data then
			Logger.Warn(TAG, "StartRace rejected for %s: data is not loaded", player.Name)
			return
		end
		if not mapInfo.Unlocked and targetMap ~= Constants.DEFAULT_MAP_ID and not PlayerData.HasMap(data, targetMap) then
			Logger.Warn(TAG, "%s does not own map '%s'", player.Name, targetMap)
			return
		end

		local vehicleName = string.format("Vehicle_%d", player.UserId)
		if not workspace:FindFirstChild(vehicleName) then
			Logger.Warn(TAG, "StartRace rejected for %s: vehicle is missing", player.Name)
			return
		end

		local checkpoints = mapCheckpoints[targetMap]
		if not checkpoints then
			Logger.Warn(TAG, "StartRace rejected: map '%s' has no discovered checkpoints", targetMap)
			return
		end

		workspace:SetAttribute("SelectedMap", targetMap)
		local total = 0
		for num in pairs(checkpoints) do
			if num ~= Constants.CHECKPOINT_FINISH then total += 1 end
		end
		startRace(player, player.UserId, targetMap, total)
	end)
end

raceAgainRemote.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	clearRace(player)
	Logger.Info(TAG, "Race state reset for %s", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	playerRace[player.UserId] = nil
end)

-- 8. Initialization
task.wait(5) -- let map generators finish placing checkpoint parts
local discovered = discoverCheckpoints()
wireCheckpoints()
Logger.Info(TAG, "Ready - monitoring %d map(s)", discovered)
if discovered == 0 then
	Logger.Warn(TAG, "No checkpoint-enabled maps were discovered")
end
