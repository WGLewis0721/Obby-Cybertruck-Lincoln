--[[
	TimerHandler.server.lua
	Description: Implements the ProcessRaceTime BindableFunction called by
	             CheckpointHandler. Persists best times via PlayerDataInterface.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Constants           (ReplicatedStorage.Shared.Constants)
		- Logger              (ReplicatedStorage.Shared.Logger)
		- PlayerData          (ReplicatedStorage.Shared.PlayerData)
		- PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)
		- EventBus            (ReplicatedStorage.Shared.EventBus)

	Events Fired (via EventBus):
		- RaceTimeProcessed(player, mapId, isNewBest, bestTime)

	Events Listened (via EventBus):
		- None

	BindableFunction Implemented:
		- ServerStorage.RaceHandlers.ProcessRaceTime
--]]

-- 1. Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- 2. Constants & shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))

-- 3. Server-only dependencies
local servicesFolder      = script.Parent
local PlayerDataInterface = require(servicesFolder:WaitForChild("PlayerDataInterface", 10))
local EventBus            = require(sharedFolder:WaitForChild("EventBus", 10))

local TAG = "TimerHandler"

-- 4. BindableFunction
local raceHandlers    = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceTime = raceHandlers:WaitForChild("ProcessRaceTime", 30)

-- 5. ProcessRaceTime implementation

processRaceTime.OnInvoke = function(player, mapId, elapsed)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		Logger.Warn(TAG, "ProcessRaceTime: invalid player argument")
		return nil
	end
	if type(mapId) ~= "string" or #mapId == 0 then
		Logger.Warn(TAG, "ProcessRaceTime: invalid mapId from %s", tostring(player))
		return nil
	end
	if type(elapsed) ~= "number" or elapsed <= 0 then
		Logger.Warn(TAG, "ProcessRaceTime: invalid elapsed from %s", player.Name)
		return nil
	end

	local userId    = player.UserId
	local isNewBest = false
	local bestTime  = elapsed

	-- Read-modify-write via PlayerDataInterface (no direct DataStore access)
	PlayerDataInterface.UpdateData(userId, function(data)
		if not data.BestTimes then data.BestTimes = {} end
		local previous = data.BestTimes[mapId]
		isNewBest = (previous == nil) or (elapsed < previous)
		if isNewBest then
			data.BestTimes[mapId] = elapsed
			bestTime = elapsed
		else
			bestTime = previous or elapsed
		end
		return data
	end)

	if isNewBest then
		Logger.Info(TAG, "New best for %s on '%s' -> %.3fs", player.Name, mapId, elapsed)
	end

	EventBus:Fire("RaceTimeProcessed", player, mapId, isNewBest, bestTime)

	return {
		isNewBest = isNewBest,
		bestTime  = bestTime,
	}
end

-- 6. Initialization
Logger.Info(TAG, "TimerHandler ready")
