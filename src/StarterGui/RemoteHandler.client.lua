--[[
    RemoteHandler.client.lua
    Description: Single LocalScript that listens to ALL server RemoteEvents and
                 updates ClientState accordingly. No other client script should
                 listen to RemoteEvents directly.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - ClientState (StarterGui.ClientState)

    Events Fired:
        - None (updates ClientState which other scripts can observe)

    Events Listened:
        - Remotes.CheckpointReached
        - Remotes.RaceStarted
        - Remotes.RaceFinished
        - Remotes.CoinsAwarded
        - Remotes.UpdateLeaderboard
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── ClientState ───────────────────────────────────────────────────────────────
-- ClientState is a ModuleScript in StarterGui; require it from PlayerGui after spawn.
local clientStateModule = playerGui:FindFirstChild("ClientState") or game:GetService("StarterGui"):FindFirstChild("ClientState")
if not clientStateModule then
	clientStateModule = playerGui:WaitForChild("ClientState", 10)
end

local ClientState
if clientStateModule and clientStateModule:IsA("ModuleScript") then
	local ok, module = pcall(require, clientStateModule)
	if ok and module then
		ClientState = module
	else
		warn("RemoteHandler: failed to require ClientState module:", module)
	end
else
	warn("RemoteHandler: ClientState module not found or invalid; using stub ClientState")
end

if not ClientState then
	ClientState = {
		Get = function() return nil end,
		Set = function() end,
		OnChange = function() end,
	}
end

-- ── Remotes ───────────────────────────────────────────────────────────────────
local remotesFolder     = ReplicatedStorage:WaitForChild("Remotes", 10)
local checkpointReached = remotesFolder:WaitForChild("CheckpointReached", 10)
local raceStarted       = remotesFolder:WaitForChild("RaceStarted", 10)
local raceFinished      = remotesFolder:WaitForChild("RaceFinished", 10)
local coinsAwarded      = remotesFolder:FindFirstChild("CoinsAwarded")
local updateLeaderboard = remotesFolder:FindFirstChild("UpdateLeaderboard")

-- ── RaceStarted ───────────────────────────────────────────────────────────────
raceStarted.OnClientEvent:Connect(function(payload)
	ClientState.Set("isInRace",          true)
	ClientState.Set("raceStartTime",     os.clock())
	ClientState.Set("currentCheckpoint", 0)
	ClientState.Set("totalCheckpoints",  0)
	ClientState.Set("currentMapId",      payload and payload.mapId or nil)
	ClientState.Set("lastRaceResult",    nil)
end)

-- ── CheckpointReached ─────────────────────────────────────────────────────────
checkpointReached.OnClientEvent:Connect(function(payload)
	if payload then
		ClientState.Set("currentCheckpoint", payload.index or 0)
		ClientState.Set("totalCheckpoints",  payload.total or 0)
	end
end)

-- ── RaceFinished ──────────────────────────────────────────────────────────────
raceFinished.OnClientEvent:Connect(function(payload)
	ClientState.Set("isInRace", false)
	if payload then
		ClientState.Set("lastRaceResult", payload)
		-- Update coin balance from result payload if provided
		if payload.totalCoins ~= nil then
			ClientState.Set("coins", payload.totalCoins)
		end
	end
end)

-- ── CoinsAwarded ─────────────────────────────────────────────────────────────
if coinsAwarded then
	coinsAwarded.OnClientEvent:Connect(function(amount, total)
		if total ~= nil then
			ClientState.Set("coins", total)
		end
	end)
end

-- ── UpdateLeaderboard ─────────────────────────────────────────────────────────
if updateLeaderboard then
	updateLeaderboard.OnClientEvent:Connect(function(data)
		-- Store leaderboard data in state; UI scripts can observe changes
		ClientState.Set("leaderboardData", data)
	end)
end

-- ── Sync coins from leaderstats on join ───────────────────────────────────────
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end
	local coins = leaderstats:WaitForChild("Coins", 10)
	if not coins then return end
	ClientState.Set("coins", coins.Value)
	coins.Changed:Connect(function(val)
		ClientState.Set("coins", val)
	end)
end)
