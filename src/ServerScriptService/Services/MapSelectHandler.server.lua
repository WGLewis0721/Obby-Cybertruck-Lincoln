--[[
	MapSelectHandler.server.lua
	Description: Handles map selection logic; minimal stub for default map setup.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Logger (ReplicatedStorage.Shared.Logger)

	Events Fired:
		- None

	Events Listened:
		- None
--]]

-- 1. Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 2. Shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))

local TAG = "MapSelectHandler"

-- 3. Event handlers

local function onPlayerAdded(player)
	Logger.Info(TAG, "Player joined: %s — using default map", player.Name)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Handle players already in game on script load
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- 4. Initialization
Logger.Info(TAG, "MapSelectHandler ready — using default map")
