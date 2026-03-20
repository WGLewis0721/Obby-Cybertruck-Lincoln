-- CoinHandler.server.lua
-- Awards coins on race completion and maintains the "Coins" leaderstats value.
-- Implements the ProcessRaceCoins BindableFunction called by CheckpointHandler.
--
-- When CheckpointHandler invokes this function it receives:
--   player : Player
--   mapId  : string   – map identifier matching MapData.Id
--
-- It returns:
--   { coinsEarned = number, totalCoins = number }
--
-- First-completion of a map earns COINS_FIRST_COMPLETION; subsequent runs earn
-- COINS_REPEAT.  The RaceCompletions field (added to PlayerData.GetDefault())
-- tracks completion counts per map so we never abuse OwnedMaps for this purpose.
--
-- NOTE: performs its own DataStore read-modify-write on "PlayerData_v1".
-- TODO (post-MVP): consolidate into a unified PlayerDataService.

local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ── DataStore (same store used by GarageHandler and PaintShopHandler) ─────────
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- ── Shared module ─────────────────────────────────────────────────────────────
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local PlayerData   = require(sharedFolder:WaitForChild("PlayerData"))

-- ── BindableFunction ──────────────────────────────────────────────────────────
local raceHandlers     = ServerStorage:WaitForChild("RaceHandlers", 30)
local processRaceCoins = raceHandlers:WaitForChild("ProcessRaceCoins", 30)

-- ── Coin reward config ─────────────────────────────────────────────────────────
local COINS_FIRST_COMPLETION = 100   -- awarded for completing a map for the first time
local COINS_REPEAT           = 25    -- awarded for every subsequent completion

-- ── In-memory leaderstats IntValue references, keyed by UserId ────────────────
-- Allows instant UI updates without a DataStore round-trip.
local playerCoinsValue = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function loadPlayerData(userId)
	local ok, data = pcall(function()
		return playerDataStore:GetAsync("Player_" .. userId)
	end)
	if ok and data then
		local defaults = PlayerData.GetDefault()
		for k, v in pairs(defaults) do
			if data[k] == nil then data[k] = v end
		end
		return data
	end
	if not ok then
		warn("CoinHandler: DataStore load failed for", userId, "—", data)
	end
	return PlayerData.GetDefault()
end

local function savePlayerData(userId, data)
	local ok, err = pcall(function()
		playerDataStore:SetAsync("Player_" .. userId, data)
	end)
	if not ok then
		warn("CoinHandler: DataStore save failed for", userId, "—", err)
	end
end

-- ── leaderstats setup ─────────────────────────────────────────────────────────
-- Creates the standard Roblox "leaderstats" Folder and a "Coins" IntValue so the
-- player's coin count appears on the in-game leaderboard.
local function setupLeaderstats(player)
	local data = loadPlayerData(player.UserId)

	local ls = Instance.new("Folder")
	ls.Name   = "leaderstats"
	ls.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name   = "Coins"
	coins.Value  = data.Coins or 0
	coins.Parent = ls

	playerCoinsValue[player.UserId] = coins
end

Players.PlayerAdded:Connect(setupLeaderstats)

Players.PlayerRemoving:Connect(function(player)
	playerCoinsValue[player.UserId] = nil
end)

-- Handle players who were already in the game when this script loaded
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupLeaderstats, player)
end

-- ── ProcessRaceCoins ──────────────────────────────────────────────────────────
-- Called synchronously by CheckpointHandler on the finish line.
-- Read-modify-write: only Coins and RaceCompletions are touched.
processRaceCoins.OnInvoke = function(player, mapId)
	local userId = player.UserId
	local data   = loadPlayerData(userId)

	-- Determine whether this is the player's first completion of this map.
	-- RaceCompletions[mapId] is nil until the player finishes for the first time.
	if not data.RaceCompletions then data.RaceCompletions = {} end
	local isFirst = (data.RaceCompletions[mapId] == nil)

	local earned = isFirst and COINS_FIRST_COMPLETION or COINS_REPEAT

	-- Read-modify-write: increment Coins and record the completion
	if not data.Coins then data.Coins = 0 end
	data.Coins = data.Coins + earned
	data.RaceCompletions[mapId] = (data.RaceCompletions[mapId] or 0) + 1

	savePlayerData(userId, data)

	-- Update the in-memory leaderstats IntValue so the leaderboard refreshes
	local coinsVal = playerCoinsValue[userId]
	if coinsVal then
		coinsVal.Value = data.Coins
	end

	print(string.format(
		"CoinHandler: %s earned %d coins on '%s' (first=%s, total=%d)",
		player.Name, earned, mapId, tostring(isFirst), data.Coins
	))

	return {
		coinsEarned = earned,
		totalCoins  = data.Coins,
	}
end

print("CoinHandler: ready")
