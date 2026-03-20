--[[
	CoinHandler.server.lua
	Description: Implements the ProcessRaceCoins BindableFunction called by
	             CheckpointHandler. Awards coins via PlayerDataInterface.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Constants           (ReplicatedStorage.Shared.Constants)
		- Logger              (ReplicatedStorage.Shared.Logger)
		- PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)
		- EventBus            (ServerScriptService.Services.EventBus)

	Events Fired (via EventBus):
		- CoinsAwarded(player, coinsEarned, totalCoins)

	Events Listened (via EventBus):
		- None

	BindableFunction Implemented:
		- ServerStorage.RaceHandlers.ProcessRaceCoins

	NOTE: leaderstats folder is created by PlayerDataInterface, not here.
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
local EventBus            = require(servicesFolder:WaitForChild("EventBus", 10))

local TAG = "CoinHandler"

-- 4. BindableFunction
local raceHandlers     = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceCoins = raceHandlers:WaitForChild("ProcessRaceCoins", 30)

-- 5. ProcessRaceCoins implementation

processRaceCoins.OnInvoke = function(player, mapId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		Logger.Warn(TAG, "ProcessRaceCoins: invalid player argument")
		return nil
	end
	if type(mapId) ~= "string" or #mapId == 0 then
		Logger.Warn(TAG, "ProcessRaceCoins: invalid mapId from %s", tostring(player))
		return nil
	end

	local userId = player.UserId
	local earned = 0
	local total  = 0

	-- Read-modify-write via PlayerDataInterface (no direct DataStore access)
	PlayerDataInterface.UpdateData(userId, function(data)
		if not data.RaceCompletions then data.RaceCompletions = {} end
		local isFirst = (data.RaceCompletions[mapId] == nil)
		earned = isFirst and Constants.COINS_FIRST_COMPLETION or Constants.COINS_REPEAT

		if not data.Coins then data.Coins = 0 end
		data.Coins = data.Coins + earned
		data.RaceCompletions[mapId] = (data.RaceCompletions[mapId] or 0) + 1
		total = data.Coins
		return data
	end)

	-- Sync the leaderstats IntValue for instant UI update
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coinsVal = leaderstats:FindFirstChild("Coins")
		if coinsVal then
			coinsVal.Value = total
		end
	end

	EventBus:Fire("CoinsAwarded", player, earned, total)

	Logger.Info(TAG, "%s earned %d coins on '%s' (total=%d)",
		player.Name, earned, mapId, total)

	return {
		coinsEarned = earned,
		totalCoins  = total,
	}
end

-- 6. Initialization
Logger.Info(TAG, "CoinHandler ready")
