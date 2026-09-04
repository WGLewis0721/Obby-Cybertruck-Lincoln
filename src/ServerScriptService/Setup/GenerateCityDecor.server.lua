--[[
	GenerateCityDecor.server.lua
	Description: Dresses the area around each built race circuit with generic
	             city scenery at server start. Runs after the circuit itself
	             exists (waits on it) and only reads its geometry -- shape/build
	             logic for the decoration lives in Services.CityDecorBuilder.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Logger            (ReplicatedStorage.Module.Logger)
		- TrackConfig       (ReplicatedStorage.Module.TrackConfig)
		- CityDecorBuilder  (ServerScriptService.Services.CityDecorBuilder)

	Events Fired / Listened:
		- None
--]]

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Logger      = require(sharedFolder:WaitForChild("Logger", 10))
local TrackConfig = require(sharedFolder:WaitForChild("TrackConfig", 10))

local TAG = "GenerateCityDecor"

local services = ServerScriptService:WaitForChild("Services", 10)
local CityDecorBuilder = require(services:WaitForChild("CityDecorBuilder", 10))

for trackKey, track in pairs(TrackConfig.Tracks) do
	local trackModel = workspace:WaitForChild(track.FolderName, 15)
	if not trackModel then
		Logger.Warn(TAG, "%s never appeared - skipping city decor", track.FolderName)
		continue
	end

	local decorName = track.FolderName .. "Decor"
	local existing = workspace:FindFirstChild(decorName)
	if existing then
		Logger.Info(TAG, "%s already present (%s parts) - skipping build",
			decorName, tostring(existing:GetAttribute("PartCount")))
		continue
	end

	local ok, result = pcall(CityDecorBuilder.Build, trackKey, trackModel)
	if not ok then
		Logger.Error(TAG, "City decor build failed for %s: %s", trackKey, tostring(result))
		continue
	end

	Logger.Info(TAG, "Built %s: %d blocks, %d parts",
		decorName, result:GetAttribute("BlocksPlaced"), result:GetAttribute("PartCount"))
end
