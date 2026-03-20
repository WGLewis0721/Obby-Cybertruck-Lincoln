-- CheckpointHandler.server.lua
-- Core race-loop state machine.
--
-- Responsibilities:
--   • Discovers checkpoint Parts from every map folder listed in MapData.
--   • Wires Touched events using vehicle-name detection (no Humanoid needed).
--   • Enforces checkpoint order and prevents duplicate triggers.
--   • Starts the race timer on Checkpoint_1; stops it on Checkpoint_99 (finish).
--   • Delegates best-time persistence to TimerHandler via ProcessRaceTime.
--   • Delegates coin awards to CoinHandler via ProcessRaceCoins.
--   • Fires RemoteEvents to the driving client (RaceStarted, CheckpointReached, RaceFinished).
--   • Resets a player's race state when RaceAgain fires from the client.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ── Shared modules ────────────────────────────────────────────────────────────
local moduleFolder = ReplicatedStorage:WaitForChild("Module", 10)
local MapData      = require(moduleFolder:WaitForChild("MapData"))

-- ── Remote events (Race folder declared in default.project.json) ──────────────
local raceFolder         = ReplicatedStorage:WaitForChild("Race", 10)
local checkpointReached  = raceFolder:WaitForChild("CheckpointReached", 10)
local raceStartedRemote  = raceFolder:WaitForChild("RaceStarted", 10)
local raceFinishedRemote = raceFolder:WaitForChild("RaceFinished", 10)
local raceAgainRemote    = raceFolder:WaitForChild("RaceAgain", 10)

-- ── BindableFunctions (set up by TimerHandler / CoinHandler on server) ────────
local raceHandlers     = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceTime  = raceHandlers:WaitForChild("ProcessRaceTime", 30)
local processRaceCoins = raceHandlers:WaitForChild("ProcessRaceCoins", 30)

-- ── Per-player race state ─────────────────────────────────────────────────────
-- playerRace[userId] = {
--   mapId            : string   – which map the player is racing
--   nextCheckpoint   : number   – next sequential checkpoint number expected
--   totalCheckpoints : number   – count of numbered checkpoints (excluding 99)
--   startClock       : number   – os.clock() captured at Checkpoint_1
--   active           : boolean
-- }
local playerRace = {}

-- ── Discovered checkpoint parts, keyed by mapId ───────────────────────────────
-- mapCheckpoints[mapId][num] = BasePart
local mapCheckpoints = {}

-- ── Helper: resolve a touching part → player, userId ─────────────────────────
-- Vehicles are named "Vehicle_[UserId]" by GarageHandler.
-- The touching part is a descendant of that Model; there is no Humanoid.
local function getPlayerFromHit(hit)
	local model = hit:FindFirstAncestorWhichIsA("Model")
	if not model then return nil, nil end
	local userId = tonumber(model.Name:match("^Vehicle_(%d+)$"))
	if not userId then return nil, nil end
	local player = Players:GetPlayerByUserId(userId)
	return player, userId
end

-- ── Discover checkpoint Parts from all map folders ────────────────────────────
local function discoverCheckpoints()
	local selectedMapId = workspace:GetAttribute("SelectedMap")
	if selectedMapId then
		print("CheckpointHandler: limiting map discovery to selected map '" .. tostring(selectedMapId) .. "'")
	else
		print("CheckpointHandler: no SelectedMap attribute; discovering all configured maps")
	end

	for _, map in ipairs(MapData) do
		if selectedMapId and map.Id ~= selectedMapId then
			continue
		end

		local folder = workspace:FindFirstChild(map.FolderName)
		if not folder then
			warn("CheckpointHandler: map folder not found in Workspace:", map.FolderName)
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
			warn("CheckpointHandler: no checkpoint parts found in map folder:", map.FolderName)
			continue
		end

		-- Count numbered checkpoints excluding the finish line (99)
		local total = 0
		for num in pairs(checkpoints) do
			if num ~= 99 then
				total = total + 1
			end
		end

		mapCheckpoints[map.Id] = checkpoints
		print(string.format(
			"CheckpointHandler: %-20s → %d checkpoint(s) + finish",
			map.FolderName, total
		))
	end
end

-- ── Wire Touched events for every discovered checkpoint ───────────────────────
local function wireCheckpoints()
	for mapId, checkpoints in pairs(mapCheckpoints) do
		-- Count numbered checkpoints (not 99) for this map
		local total = 0
		for num in pairs(checkpoints) do
			if num ~= 99 then total = total + 1 end
		end

		for num, part in pairs(checkpoints) do
			-- Capture loop variables so the closure is correct per checkpoint
			local capturedNum   = num
			local capturedMapId = mapId
			local capturedTotal = total

			part.Touched:Connect(function(hit)
				local player, userId = getPlayerFromHit(hit)
				if not player then return end

				local race = playerRace[userId]

				-- ── Finish line (Checkpoint_99) ────────────────────────────────
				if capturedNum == 99 then
					if not race or not race.active then return end
					if race.mapId ~= capturedMapId then return end
					-- Only accept finish once all prior checkpoints were cleared
					if race.nextCheckpoint ~= capturedTotal + 1 then return end

					-- Stop the race and clear state immediately to prevent re-triggers
					local elapsed = os.clock() - race.startClock
					race.active = false
					playerRace[userId] = nil

					-- Ask TimerHandler to persist best time and return comparison result
					local timeResult = processRaceTime:Invoke(player, capturedMapId, elapsed)
					-- Ask CoinHandler to award coins and return totals
					local coinResult = processRaceCoins:Invoke(player, capturedMapId)

					-- Fire full result payload to the client
					raceFinishedRemote:FireClient(player, {
						mapId       = capturedMapId,
						elapsed     = elapsed,
						isNewBest   = timeResult and timeResult.isNewBest  or false,
						bestTime    = timeResult and timeResult.bestTime   or elapsed,
						coinsEarned = coinResult and coinResult.coinsEarned or 0,
						totalCoins  = coinResult and coinResult.totalCoins  or 0,
					})

					print(string.format(
						"CheckpointHandler: %s finished '%s' in %.3fs | newBest=%s | coins+%d",
						player.Name, capturedMapId, elapsed,
						tostring(timeResult and timeResult.isNewBest),
						coinResult and coinResult.coinsEarned or 0
					))

				-- ── Numbered checkpoint ────────────────────────────────────────
				else
					if not race or not race.active then
						-- Only checkpoint 1 can start a new race
						if capturedNum ~= 1 then return end

						playerRace[userId] = {
							mapId            = capturedMapId,
							nextCheckpoint   = 1,
							totalCheckpoints = capturedTotal,
							startClock       = os.clock(),
							active           = true,
						}
						race = playerRace[userId]
						raceStartedRemote:FireClient(player, { mapId = capturedMapId })
						print(string.format(
							"CheckpointHandler: race started — %s on '%s'",
							player.Name, capturedMapId
						))
					end

					-- Ignore checkpoints from a different map while a race is active
					if race.mapId ~= capturedMapId then return end
					-- Ignore out-of-order or already-hit checkpoints
					if capturedNum ~= race.nextCheckpoint then return end

					-- Accept this checkpoint
					race.nextCheckpoint = race.nextCheckpoint + 1
					checkpointReached:FireClient(player, {
						mapId = capturedMapId,
						index = capturedNum,
						total = capturedTotal,
					})

					print(string.format(
						"CheckpointHandler: %s hit CP %d/%d on '%s'",
						player.Name, capturedNum, capturedTotal, capturedMapId
					))
				end
			end)
		end
	end
end

-- ── RaceAgain: reset the player's race state so they can start fresh ──────────
raceAgainRemote.OnServerEvent:Connect(function(player)
	playerRace[player.UserId] = nil
	print("CheckpointHandler: race state reset for", player.Name)
end)

-- ── Clean up on player disconnect ─────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	playerRace[player.UserId] = nil
end)

-- ── Initialise: wait for map generators to finish, then discover checkpoints ──
-- Map-generator scripts are synchronous (no task.wait) so they complete before
-- this script resumes after its first yield. 5 s gives a comfortable margin for
-- even the heaviest map (HighSpeedMap) to place all its Parts.
local CHECKPOINT_DISCOVERY_DELAY = 5   -- seconds; covers the slowest map generator
task.wait(CHECKPOINT_DISCOVERY_DELAY)
discoverCheckpoints()
wireCheckpoints()
print("CheckpointHandler: ready — monitoring", #MapData, "map(s)")
