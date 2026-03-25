--[[
    PlayerDataInterface.lua
    Description: Single source of truth for all player data. Only this module
                 reads from or writes to DataStore "PlayerData_v1". All other
                 server scripts call this module's API instead of DataStore directly.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - Constants  (ReplicatedStorage.Shared.Constants)
        - Logger     (ReplicatedStorage.Shared.Logger)
        - PlayerData (ReplicatedStorage.Shared.PlayerData)
        - EventBus   (ReplicatedStorage.Shared.EventBus)

    Events Fired (via EventBus):
        - PlayerDataLoaded(player) — when a player's data is ready in cache

    Events Listened:
        - None
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- Guard: this module accesses DataStore and must only run on the server.
if not RunService:IsServer() then
	error("PlayerDataInterface: must only be required on the server")
end

-- ── Dependencies ──────────────────────────────────────────────────────────────
local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))
local PlayerData   = require(sharedFolder:WaitForChild("PlayerData", 10))
local EventBus     = require(sharedFolder:WaitForChild("EventBus", 10))

local TAG = "PlayerDataInterface"

-- ── DataStore ─────────────────────────────────────────────────────────────────
local playerDataStore = DataStoreService:GetDataStore(Constants.DATASTORE_NAME)

-- ── In-memory cache ───────────────────────────────────────────────────────────
-- playerCache[userId] = data table
local playerCache = {}
-- Per-player Coins IntValue references for instant leaderstats updates
local playerCoinsValues = {}

-- ── Internal helpers ──────────────────────────────────────────────────────────
local function datastoreKey(userId)
	return string.format(Constants.DATASTORE_KEY_FORMAT, userId)
end

-- Retry wrapper: attempts up to RETRY_ATTEMPTS times with RETRY_DELAY between.
local function withRetry(fn)
	local lastErr
	for attempt = 1, Constants.DATASTORE_RETRY_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		Logger.Warn(TAG, "DataStore attempt %d/%d failed: %s",
			attempt, Constants.DATASTORE_RETRY_ATTEMPTS, tostring(lastErr))
		if attempt < Constants.DATASTORE_RETRY_ATTEMPTS then
			task.wait(Constants.DATASTORE_RETRY_DELAY)
		end
	end
	return false, lastErr
end

-- Merge default fields into existing data so newly-added fields are always present.
local function mergeDefaults(data)
	local defaults = PlayerData.GetDefault()
	for k, v in pairs(defaults) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

-- Create or refresh the leaderstats Coins IntValue for a player.
local function syncLeaderstats(player, coinsValue)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name   = "leaderstats"
		ls.Parent = player
	end

	local coins = ls:FindFirstChild("Coins")
	if not coins then
		coins          = Instance.new("IntValue")
		coins.Name     = "Coins"
		coins.Parent   = ls
	end
	coins.Value = coinsValue
	playerCoinsValues[player.UserId] = coins
end

-- ── Load / Save ───────────────────────────────────────────────────────────────
local function loadData(userId)
	local ok, result = withRetry(function()
		return playerDataStore:GetAsync(datastoreKey(userId))
	end)
	if ok and result then
		return mergeDefaults(result)
	end
	if not ok then
		Logger.Error(TAG, "Failed to load data for %d: %s", userId, tostring(result))
	end
	Logger.Info(TAG, "Using default data for userId=%d", userId)
	return PlayerData.GetDefault()
end

local function saveData(userId, data)
	if not data then
		Logger.Warn(TAG, "saveData called with nil data for userId=%d", userId)
		return
	end
	local ok, err = withRetry(function()
		playerDataStore:SetAsync(datastoreKey(userId), data)
	end)
	if ok then
		Logger.Debug(TAG, "Saved data for userId=%d", userId)
	else
		Logger.Error(TAG, "Failed to save data for %d: %s", userId, tostring(err))
	end
end

-- ── PlayerAdded / PlayerRemoving ──────────────────────────────────────────────
local function onPlayerAdded(player)
	local userId = player.UserId
	local data   = loadData(userId)
	playerCache[userId] = data

	-- Create leaderstats
	syncLeaderstats(player, data.Coins or 0)

	-- Notify other server systems that this player's data is ready
	EventBus:Fire("PlayerDataLoaded", player)
	Logger.Info(TAG, "Data loaded for %s (userId=%d, coins=%d)",
		player.Name, userId, data.Coins or 0)
end

local function onPlayerRemoving(player)
	local userId = player.UserId
	local data   = playerCache[userId]
	if data then
		saveData(userId, data)
	end
	playerCache[userId]      = nil
	playerCoinsValues[userId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before this module loaded
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ── Auto-save (every 60 s) ────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(60)
		for userId, data in pairs(playerCache) do
			saveData(userId, data)
		end
		Logger.Debug(TAG, "Auto-save complete for %d player(s)", (function()
			local n = 0; for _ in pairs(playerCache) do n = n + 1 end; return n
		end)())
	end
end)

-- ── Public API ────────────────────────────────────────────────────────────────
local PlayerDataInterface = {}

--[[
    GetData(userId) → data or nil
    Returns the in-memory data table for the given userId. Returns nil if the
    player is not in the cache (not yet loaded or already left).
--]]
function PlayerDataInterface.GetData(userId)
	return playerCache[userId]
end

--[[
    UpdateData(userId, callback)
    Safe read-modify-write. callback receives the current data table and must
    return the (possibly modified) data. Changes are applied to the cache and
    saved to DataStore.

    Example:
        PlayerDataInterface.UpdateData(userId, function(data)
            data.Coins = data.Coins + 50
            return data
        end)
--]]
function PlayerDataInterface.UpdateData(userId, callback)
	if type(callback) ~= "function" then
		Logger.Warn(TAG, "UpdateData: callback is not a function for userId=%d", userId)
		return
	end
	local data = playerCache[userId]
	if not data then
		Logger.Warn(TAG, "UpdateData: no cached data for userId=%d — loading from DataStore", userId)
		data = loadData(userId)
		playerCache[userId] = data
	end
	local ok, result = pcall(callback, data)
	if ok and result then
		playerCache[userId] = result
		saveData(userId, result)
	elseif not ok then
		Logger.Error(TAG, "UpdateData callback error for userId=%d: %s", userId, tostring(result))
	end
end

--[[
    GetValue(userId, key) → value
    Returns a single field from the cached data. Returns nil if not found.
--]]
function PlayerDataInterface.GetValue(userId, key)
	local data = playerCache[userId]
	if not data then return nil end
	return data[key]
end

--[[
    SetValue(userId, key, value)
    Sets a single field in the cached data and saves to DataStore.
--]]
function PlayerDataInterface.SetValue(userId, key, value)
	local data = playerCache[userId]
	if not data then
		Logger.Warn(TAG, "SetValue: no cached data for userId=%d", userId)
		return
	end
	data[key] = value
	saveData(userId, data)
end

--[[
    AddCoins(userId, amount) → newTotal
    Atomically adds 'amount' coins to the player's balance, updates leaderstats,
    and persists to DataStore. Returns the new coin total.
--]]
function PlayerDataInterface.AddCoins(userId, amount)
	if type(amount) ~= "number" or amount < 0 then
		Logger.Warn(TAG, "AddCoins: invalid amount %s for userId=%d", tostring(amount), userId)
		return 0
	end
	local data = playerCache[userId]
	if not data then
		Logger.Warn(TAG, "AddCoins: no cached data for userId=%d", userId)
		return 0
	end
	data.Coins = (data.Coins or 0) + amount
	saveData(userId, data)

	-- Update the leaderstats IntValue for instant UI refresh
	local coinsVal = playerCoinsValues[userId]
	if coinsVal then
		coinsVal.Value = data.Coins
	end

	Logger.Debug(TAG, "AddCoins: userId=%d +%d → total=%d", userId, amount, data.Coins)
	return data.Coins
end

Logger.Info(TAG, "PlayerDataInterface initialised")
return PlayerDataInterface
