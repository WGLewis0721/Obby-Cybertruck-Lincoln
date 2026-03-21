--[[
	GarageHandler.server.lua
	Description: Handles EquipVehicle remote; verifies ownership; spawns/replaces
	             the player's vehicle model in Workspace. Uses PlayerDataInterface
	             for all persistence — no direct DataStore calls.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Constants           (ReplicatedStorage.Shared.Constants)
		- Logger              (ReplicatedStorage.Shared.Logger)
		- VehicleData         (ReplicatedStorage.Shared.VehicleData)
		- MapData             (ReplicatedStorage.Shared.MapData)
		- PlayerData          (ReplicatedStorage.Shared.PlayerData)
		- PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)
		- EventBus            (ReplicatedStorage.Shared.EventBus)

	Events Fired (via EventBus):
		- VehicleSpawned(player, vehicleId)

	Events Listened (via EventBus):
		- PlayerDataLoaded(player) — triggers initial vehicle spawn

	Remote Events Handled:
		- Remotes.EquipVehicle (C->S)
		- Remotes.OpenGarage   (C->S echo -> S->C)
		- Remotes.SelectMap    (C->S)

	NOTE: ProcessReceipt is defined ONLY in PaintShopHandler.server.lua.
--]]

-- 1. Services
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- 2. Constants & shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))
local VehicleData  = require(sharedFolder:WaitForChild("VehicleData", 10))
local MapData      = require(sharedFolder:WaitForChild("MapData", 10))
local PlayerData   = require(sharedFolder:WaitForChild("PlayerData", 10))

-- 3. Server-only dependencies
local servicesFolder      = script.Parent
local PlayerDataInterface = require(servicesFolder:WaitForChild("PlayerDataInterface", 10))
local EventBus            = require(sharedFolder:WaitForChild("EventBus", 10))

local TAG = "GarageHandler"

-- 4. Remote events
local remotesFolder = ReplicatedStorage:WaitForChild(Constants.REMOTES_PATH, 10)
if not remotesFolder then
	Logger.Error(TAG, "Remotes folder not found in ReplicatedStorage")
	return
end

local equipVehicleEvent = remotesFolder:WaitForChild("EquipVehicle", 10)
local openGarageEvent   = remotesFolder:WaitForChild("OpenGarage", 10)
local selectMapEvent    = remotesFolder:FindFirstChild("SelectMap")

if not equipVehicleEvent then
	Logger.Error(TAG, "EquipVehicle RemoteEvent not found")
	return
end

local characterSpawnConnections = {}
local autoSpawnCharacter = {}

-- 5. Private functions

local function getVehicleById(vehicleId)
	for _, v in ipairs(VehicleData) do
		if v.Id == vehicleId then
			return v
		end
	end
	return nil
end

local spawnEquippedVehicle

local function getDriverSeat(vehicle)
	local driveSeat = vehicle:FindFirstChild("DriveSeat", true)
	if driveSeat and driveSeat:IsA("VehicleSeat") then
		return driveSeat
	end

	return vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function scheduleAutoSpawn(player, character)
	if not character then
		return
	end

	autoSpawnCharacter[player.UserId] = character

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)
		if player.Character ~= character then
			return
		end
		if not humanoid or not rootPart or humanoid.Health <= 0 then
			return
		end

		task.wait(0.25)
		if player.Character ~= character or humanoid.Health <= 0 then
			return
		end

		spawnEquippedVehicle(player)
	end)
end

local function seatPlayerInVehicle(player, vehicle)
	local vehicleSeat = getDriverSeat(vehicle)
	if not vehicleSeat then
		return
	end

	task.spawn(function()
		for _ = 1, 30 do
			if not vehicleSeat.Parent then
				return
			end
			if vehicleSeat.Anchored then
				task.wait(0.1)
				continue
			end

			local character = player.Character
			local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not rootPart or humanoid.Health <= 0 then
				task.wait(0.2)
				continue
			end
			if vehicleSeat.Occupant == humanoid then
				return
			end
			if not humanoid.Parent or not rootPart.Parent or not vehicleSeat.Parent then
				return
			end

			rootPart.CFrame = vehicleSeat.CFrame * CFrame.new(0, 3, 0)
			local ok = pcall(function()
				vehicleSeat:Sit(humanoid)
			end)
			if ok and vehicleSeat.Occupant == humanoid then
				return
			end
			task.wait(0.15)
		end

		Logger.Warn(TAG, "Failed to seat %s in '%s'", player.Name, vehicle.Name)
	end)
end

local function spawnVehicle(player, vehicle)
	local vehicleName = string.format(Constants.VEHICLE_NAME_FORMAT, player.UserId)

	-- Remove old vehicle
	local existing = workspace:FindFirstChild(vehicleName)
	if existing then
		existing:Destroy()
	end

	local modelTemplate = ServerStorage:FindFirstChild(vehicle.ModelName)
	if not modelTemplate then
		Logger.Warn(TAG, "Model '%s' not found in ServerStorage", vehicle.ModelName)
		return
	end

	local newVehicle = modelTemplate:Clone()
	newVehicle.Name = vehicleName
	if not newVehicle.PrimaryPart then
		local driverSeat = getDriverSeat(newVehicle)
		if driverSeat then
			newVehicle.PrimaryPart = driverSeat
		end
	end

	-- Determine spawn CFrame (priority: VehicleSpawn > map spawn > HumanoidRootPart > origin)
	local spawnCFrame = CFrame.new(Constants.VEHICLE_SPAWN_OFFSET)

	local spawnMarker = workspace:FindFirstChild("VehicleSpawn")
	if spawnMarker and spawnMarker:IsA("BasePart") then
		spawnCFrame = spawnMarker.CFrame
	else
		local selectedMap = workspace:GetAttribute("SelectedMap")
		if selectedMap then
			for _, mapInfo in ipairs(MapData) do
				if mapInfo.Id == selectedMap and mapInfo.SpawnName then
					local mapSpawn = workspace:FindFirstChild(mapInfo.SpawnName, true)
					if mapSpawn and mapSpawn:IsA("BasePart") then
						spawnCFrame = mapSpawn.CFrame
						break
					end
				end
			end
		end

		if spawnCFrame == CFrame.new(Constants.VEHICLE_SPAWN_OFFSET) then
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					spawnCFrame = rootPart.CFrame * CFrame.new(0, 0, -10)
				else
					Logger.Warn(TAG, "HumanoidRootPart not found for %s — using default spawn", player.Name)
				end
			else
				Logger.Warn(TAG, "No character for %s — using default spawn", player.Name)
			end
		end
	end

	if newVehicle.PrimaryPart then
		newVehicle:SetPrimaryPartCFrame(spawnCFrame)
	else
		newVehicle:PivotTo(spawnCFrame)
	end

	newVehicle.Parent = workspace
	seatPlayerInVehicle(player, newVehicle)

	EventBus:Fire("VehicleSpawned", player, vehicle.Id)
	Logger.Info(TAG, "Spawned '%s' (Id=%d) for %s", vehicle.Name, vehicle.Id, player.Name)
end

spawnEquippedVehicle = function(player)
	local data = PlayerDataInterface.GetData(player.UserId)
	if not data then return end
	local vehicleId = data.EquippedVehicle or Constants.DEFAULT_VEHICLE_ID
	local vehicle   = getVehicleById(vehicleId)
	if vehicle then
		spawnVehicle(player, vehicle)
	else
		Logger.Warn(TAG, "No vehicle found for Id=%d (player=%s)", vehicleId, player.Name)
	end
end

-- 6. Event handlers

-- Spawn vehicle once player data is ready, and wire CharacterAdded for respawns.
-- Using EventBus("PlayerDataLoaded") ensures data is in cache before spawning.
EventBus:On("PlayerDataLoaded", function(player)
	if characterSpawnConnections[player] then
		characterSpawnConnections[player]:Disconnect()
	end

	-- Wire CharacterAdded for all future spawns (respawns after death)
	characterSpawnConnections[player] = player.CharacterAdded:Connect(function(character)
		scheduleAutoSpawn(player, character)
	end)

	-- Spawn immediately if the character was already loaded when data arrived
	if player.Character and autoSpawnCharacter[player.UserId] ~= player.Character then
		scheduleAutoSpawn(player, player.Character)
	end
end)

-- Remove vehicle when player leaves
Players.PlayerRemoving:Connect(function(player)
	local vehicleName = string.format(Constants.VEHICLE_NAME_FORMAT, player.UserId)
	local existing    = workspace:FindFirstChild(vehicleName)
	if existing then
		existing:Destroy()
	end
	if characterSpawnConnections[player] then
		characterSpawnConnections[player]:Disconnect()
		characterSpawnConnections[player] = nil
	end
	autoSpawnCharacter[player.UserId] = nil
end)

-- EquipVehicle: validate, check ownership, and equip
equipVehicleEvent.OnServerEvent:Connect(function(player, vehicleId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	if type(vehicleId) ~= "number" then
		Logger.Warn(TAG, "Invalid vehicleId type from %s: %s", player.Name, typeof(vehicleId))
		return
	end

	local vehicle = getVehicleById(vehicleId)
	if not vehicle then
		Logger.Warn(TAG, "Unknown vehicleId %d from %s", vehicleId, player.Name)
		return
	end

	local data = PlayerDataInterface.GetData(player.UserId)
	if not data then
		Logger.Warn(TAG, "No data in cache for %s", player.Name)
		return
	end

	local owns = vehicle.Unlocked or PlayerData.OwnsVehicle(data, vehicleId)
	if not owns then
		Logger.Warn(TAG, "%s does not own vehicle Id=%d", player.Name, vehicleId)
		return
	end

	PlayerDataInterface.UpdateData(player.UserId, function(d)
		d.EquippedVehicle = vehicleId
		return d
	end)

	spawnVehicle(player, vehicle)
	Logger.Info(TAG, "%s equipped '%s' (Id=%d)", player.Name, vehicle.Name, vehicleId)
end)

-- SelectMap: re-spawn vehicle at the new map's spawn point
if selectMapEvent then
	selectMapEvent.OnServerEvent:Connect(function(player, mapId)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		if type(mapId) ~= "string" or #mapId == 0 then
			Logger.Warn(TAG, "Invalid mapId from %s: %s", player.Name, tostring(mapId))
			return
		end
		spawnEquippedVehicle(player)
	end)
end

-- OpenGarage echo: client fires -> server echoes back -> client opens garage UI
if openGarageEvent then
	openGarageEvent.OnServerEvent:Connect(function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		openGarageEvent:FireClient(player)
	end)
end

-- 7. Initialization
Logger.Info(TAG, "GarageHandler ready")
