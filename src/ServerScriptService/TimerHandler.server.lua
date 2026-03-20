-- TimerHandler.server.lua
-- Implements the ProcessRaceTime BindableFunction called by CheckpointHandler.
--
-- When CheckpointHandler invokes this function it receives:
--   player  : Player
--   mapId   : string   – map identifier matching MapData.Id
--   elapsed : number   – race time in seconds (os.clock() delta)
--
-- It returns:
--   { isNewBest = boolean, bestTime = number }
--
-- NOTE: This script performs its own DataStore read-modify-write on
-- "PlayerData_v1" rather than sharing GarageHandler's in-memory cache.
-- TODO (post-MVP): consolidate into a unified PlayerDataService.

local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ── DataStore (same store used by GarageHandler and PaintShopHandler) ─────────
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- ── Shared module ─────────────────────────────────────────────────────────────
local moduleFolder = ReplicatedStorage:WaitForChild("Module", 10)
local PlayerData   = require(moduleFolder:WaitForChild("PlayerData"))

-- ── BindableFunction ──────────────────────────────────────────────────────────
local raceHandlers    = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceTime = raceHandlers:WaitForChild("ProcessRaceTime", 30)

-- ── Helper: load player data from DataStore ───────────────────────────────────
local function loadPlayerData(userId)
	local ok, data = pcall(function()
		return playerDataStore:GetAsync("Player_" .. userId)
	end)
	if ok and data then
		-- Merge any new default fields that were added after the player's last save
		local defaults = PlayerData.GetDefault()
		for k, v in pairs(defaults) do
			if data[k] == nil then data[k] = v end
		end
		return data
	end
	if not ok then
		warn("TimerHandler: DataStore load failed for", userId, "—", data)
	end
	return PlayerData.GetDefault()
end

-- ── Helper: save player data to DataStore ─────────────────────────────────────
local function savePlayerData(userId, data)
	local ok, err = pcall(function()
		playerDataStore:SetAsync("Player_" .. userId, data)
	end)
	if not ok then
		warn("TimerHandler: DataStore save failed for", userId, "—", err)
	end
end

-- ── ProcessRaceTime ───────────────────────────────────────────────────────────
-- Called synchronously by CheckpointHandler on the finish line.
-- Read-modify-write: only BestTimes is touched; all other fields are unchanged.
processRaceTime.OnInvoke = function(player, mapId, elapsed)
	local userId = player.UserId
	local data   = loadPlayerData(userId)

	-- BestTimes keys are stored as the raw mapId string (e.g. "highspeed")
	if not data.BestTimes then data.BestTimes = {} end
	local previous  = data.BestTimes[mapId]
	local isNewBest = (previous == nil) or (elapsed < previous)

	if isNewBest then
		data.BestTimes[mapId] = elapsed
		savePlayerData(userId, data)
		print(string.format(
			"TimerHandler: new best for %s on '%s' → %.3fs  (was %s)",
			player.Name, mapId, elapsed,
			previous and string.format("%.3fs", previous) or "none"
		))
	end

	return {
		isNewBest = isNewBest,
		bestTime  = isNewBest and elapsed or (previous or elapsed),
	}
end

print("TimerHandler: ready")
