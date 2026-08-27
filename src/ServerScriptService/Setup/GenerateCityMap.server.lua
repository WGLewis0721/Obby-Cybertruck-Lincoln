--[[
	GenerateCityMap.server.lua
	Description: Builds the City Circuit at server start if it isn't already in
	             Workspace. All geometry/shape lives in TrackConfig; the build
	             logic lives in Services.TrackBuilder. This script is the trigger.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	NOTE: this deliberately does NOT move workspace.VehicleSpawn. Players spawn in
	the CityHub lobby for free driving and reach the circuit via the pit lane --
	relocating the spawn to the race grid here would defeat that.

	Dependencies:
		- Logger       (ReplicatedStorage.Module.Logger)
		- Constants    (ReplicatedStorage.Module.Constants)
		- TrackConfig  (ReplicatedStorage.Module.TrackConfig)
		- TrackBuilder (ServerScriptService.Services.TrackBuilder)

	Events Fired / Listened:
		- None
--]]

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Logger      = require(sharedFolder:WaitForChild("Logger", 10))
local Constants   = require(sharedFolder:WaitForChild("Constants", 10))
local TrackConfig = require(sharedFolder:WaitForChild("TrackConfig", 10))

local TAG = "GenerateCityMap"
workspace:SetAttribute("SelectedMap", Constants.DEFAULT_MAP_ID)

local services = ServerScriptService:WaitForChild("Services", 10)
local TrackBuilder = require(services:WaitForChild("TrackBuilder", 10))

for trackKey, track in pairs(TrackConfig.Tracks) do
	local existing = workspace:FindFirstChild(track.FolderName)
	if existing then
		Logger.Info(TAG, "%s already present (%s studs, %s coins) - skipping build",
			track.FolderName,
			tostring(existing:GetAttribute("CenterlineStuds")),
			tostring(existing:GetAttribute("CoinCount")))
		continue
	end

	local ok, result = pcall(TrackBuilder.Build, trackKey)
	if not ok then
		Logger.Error(TAG, "Track build failed for %s: %s", trackKey, tostring(result))
		continue
	end

	Logger.Info(TAG, "Built %s: %d studs, %d coins, %d laps",
		track.FolderName,
		result:GetAttribute("CenterlineStuds"),
		result:GetAttribute("CoinCount"),
		result:GetAttribute("TotalLaps"))
end
