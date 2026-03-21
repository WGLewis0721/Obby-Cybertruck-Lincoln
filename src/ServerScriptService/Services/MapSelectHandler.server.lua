--[[
    MapSelectHandler.server.lua
    Description: Minimal map selection bootstrapper. Ensures Workspace has a
                 selected map attribute so server systems can agree on the
                 active map before players spawn vehicles or races initialize.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants = require(sharedFolder:WaitForChild("Constants", 10))
local Logger = require(sharedFolder:WaitForChild("Logger", 10))

local TAG = "MapSelectHandler"

local function getSelectedMapId()
    return workspace:GetAttribute("SelectedMap") or Constants.DEFAULT_MAP_ID
end

if not workspace:GetAttribute("SelectedMap") then
    workspace:SetAttribute("SelectedMap", Constants.DEFAULT_MAP_ID)
end

local function onPlayerAdded(player)
    Logger.Info(TAG, "Player joined: %s - using map '%s'", player.Name, getSelectedMapId())
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

Logger.Info(TAG, "MapSelectHandler ready - default map '%s'", getSelectedMapId())
