-- PlayerData.lua
-- Shared module that provides helpers for reading and writing player data
-- structures used by both the client and server.
-- The actual DataStore persistence is handled by GarageHandler.server.lua;
-- this module only operates on plain Lua tables.

local PlayerData = {}

-- ── Default data structure ────────────────────────────────────────────────────
-- Returns a fresh default data table for a new player.
-- Fields:
--   EquippedVehicle - Id of the vehicle the player currently has equipped
--   OwnedVehicles   - array of vehicle Ids the player owns
--   OwnedMaps       - array of map Ids the player has unlocked
--   BestTimes       - map of mapId -> best time (seconds)
function PlayerData.GetDefault()
	return {
		EquippedVehicle  = 1,        -- Cybertruck (Id=1) is the default free vehicle
		OwnedVehicles    = { 1 },    -- every player starts with vehicle Id 1
		OwnedMaps        = {},
		BestTimes        = {},
		Coins            = 0,        -- total coins earned across all races
		RaceCompletions  = {},       -- mapId → completion count; tracks first-finish bonus
	}
end

-- ── Ownership helpers ─────────────────────────────────────────────────────────

-- Returns true if the given playerData table shows ownership of vehicleId.
function PlayerData.OwnsVehicle(playerData, vehicleId)
	if not playerData or not playerData.OwnedVehicles then
		return false
	end
	for _, id in ipairs(playerData.OwnedVehicles) do
		if id == vehicleId then
			return true
		end
	end
	return false
end

-- Returns true if the given playerData table shows the player has mapId.
function PlayerData.HasMap(playerData, mapId)
	if not playerData or not playerData.OwnedMaps then
		return false
	end
	for _, id in ipairs(playerData.OwnedMaps) do
		if id == mapId then
			return true
		end
	end
	return false
end

-- ── Best-time helper ──────────────────────────────────────────────────────────

-- Updates playerData.BestTimes[mapId] if newTime is better (lower) than
-- the stored time.  Mutates playerData in place and returns the new best.
-- BestTimes keys are always numeric to match the mapId values used in OwnedMaps.
function PlayerData.UpdateBestTime(playerData, mapId, newTime)
	if not playerData then return newTime end
	if not playerData.BestTimes then
		playerData.BestTimes = {}
	end
	local key = tonumber(mapId) or mapId  -- normalise to number when possible
	local current = playerData.BestTimes[key]
	if current == nil or newTime < current then
		playerData.BestTimes[key] = newTime
	end
	return playerData.BestTimes[key]
end

return PlayerData
