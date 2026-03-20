-- GarageHandler.server.lua
-- Handles EquipVehicle remote events from the client.
-- Verifies ownership, swaps the player's vehicle model in Workspace,
-- and persists the selection to DataStore "PlayerData_v1".
--
-- NOTE: MarketplaceService.ProcessReceipt is already defined in
-- PaintShopHandler.server.lua — this script does NOT redefine it.

local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

-- ── DataStore ─────────────────────────────────────────────────────────────────
-- Follows the "PaintJobs_v1" naming convention from PaintShopHandler.
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- ── Remote events ─────────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	warn("GarageHandler: Remotes folder not found in ReplicatedStorage")
	return
end

local equipVehicleEvent = remotesFolder:WaitForChild("EquipVehicle", 10)
if not equipVehicleEvent then
	warn("GarageHandler: EquipVehicle RemoteEvent not found")
	return
end

-- ── Shared data modules ───────────────────────────────────────────────────────
local sharedFolder  = ReplicatedStorage:WaitForChild("Shared", 10)
local vehicleData   = require(sharedFolder:WaitForChild("VehicleData"))
local MapData       = require(sharedFolder:WaitForChild("MapData"))
local PlayerData    = require(sharedFolder:WaitForChild("PlayerData"))

-- ── Helper: get vehicle definition by Id ──────────────────────────────────────
local function getVehicleById(vehicleId)
	for _, v in ipairs(vehicleData) do
		if v.Id == vehicleId then
			return v
		end
	end
	return nil
end

-- ── Helper: load player data from DataStore ───────────────────────────────────
-- Returns a fresh default if no data is stored yet.
local function loadPlayerData(userId)
	local success, data = pcall(function()
		return playerDataStore:GetAsync("Player_" .. userId)
	end)
	if success and data then
		-- Merge defaults in case new fields were added since last save
		local defaults = PlayerData.GetDefault()
		for k, v in pairs(defaults) do
			if data[k] == nil then
				data[k] = v
			end
		end
		return data
	end
	if not success then
		warn("GarageHandler: DataStore load failed for", userId, "—", data)
	end
	return PlayerData.GetDefault()
end

-- ── Helper: save player data to DataStore ─────────────────────────────────────
local function savePlayerData(userId, data)
	local success, err = pcall(function()
		playerDataStore:SetAsync("Player_" .. userId, data)
	end)
	if not success then
		warn("GarageHandler: DataStore save failed for", userId, "—", err)
	end
end

-- ── In-memory cache so we don't hit DataStore on every equip ─────────────────
local playerDataCache = {}

-- Populate cache when a player joins
Players.PlayerAdded:Connect(function(player)
	playerDataCache[player.UserId] = loadPlayerData(player.UserId)

	player.CharacterAdded:Connect(function(character)
		local data = playerDataCache[player.UserId]
		if not data then
			data = loadPlayerData(player.UserId)
			playerDataCache[player.UserId] = data
		end

		local vehicleId = data.EquippedVehicle or 1
		local vehicle = getVehicleById(vehicleId)
		if vehicle then
			spawnVehicle(player, vehicle)
		end
	end)
end)

-- Flush cache and save when a player leaves
Players.PlayerRemoving:Connect(function(player)
	local data = playerDataCache[player.UserId]
	if data then
		savePlayerData(player.UserId, data)
	end
	playerDataCache[player.UserId] = nil

	-- Also remove the player's vehicle from Workspace on disconnect
	local vehicleName = "Vehicle_" .. player.UserId
	local existing = workspace:FindFirstChild(vehicleName)
	if existing then
		existing:Destroy()
	end
end)

-- ── Helper: spawn / replace a player's vehicle in Workspace ──────────────────
local function spawnVehicle(player, vehicle)
	local vehicleName = "Vehicle_" .. player.UserId

	-- Remove the old vehicle model if one exists
	local existing = workspace:FindFirstChild(vehicleName)
	if existing then
		existing:Destroy()
	end

	-- Look for the model in ServerStorage
	local modelTemplate = ServerStorage:FindFirstChild(vehicle.ModelName)
	if not modelTemplate then
		warn("GarageHandler: Model '" .. vehicle.ModelName .. "' not found in ServerStorage")
		return
	end

	local newVehicle = modelTemplate:Clone()
	newVehicle.Name = vehicleName

	-- Determine spawn position:
	-- 1. Prefer first VehicleSpawn part in workspace.
	-- 2. Prefer selected map's spawn location (MapData.SpawnName).
	-- 3. Fall back to 10 studs in front of the player's character.
	-- 4. Fall back to world origin.
	local spawnCFrame = CFrame.new(0, 5, 0)

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

		if spawnCFrame == CFrame.new(0, 5, 0) then
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					spawnCFrame = rootPart.CFrame * CFrame.new(0, 0, -10)
				else
					warn("GarageHandler: HumanoidRootPart not found for " .. player.Name .. " — using default spawn location")
				end
			else
				warn("GarageHandler: No character for " .. player.Name .. " — using default spawn location")
			end
		end
	end

	-- Place the vehicle using PrimaryPart when available, otherwise pivot the whole model.
	if newVehicle.PrimaryPart then
		newVehicle:SetPrimaryPartCFrame(spawnCFrame)
	else
		newVehicle:PivotTo(spawnCFrame)
	end

	newVehicle.Parent = workspace

	-- Sit player in the vehicle driver seat when possible.
	local vehicleSeat = newVehicle:FindFirstChildWhichIsA("VehicleSeat", true)
	if vehicleSeat and player.Character then
		local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			-- Small delay to avoid conflicts with spawn/respawn timing.
			task.delay(0.1, function()
				if vehicleSeat and vehicleSeat.Parent and humanoid.Parent then
					if vehicleSeat:IsA("VehicleSeat") then
						vehicleSeat:Sit(humanoid)
					end
				end
			end)
		end
	end
end

-- ── EquipVehicle handler ──────────────────────────────────────────────────────
equipVehicleEvent.OnServerEvent:Connect(function(player, vehicleId)
	-- Basic type validation
	if type(vehicleId) ~= "number" then
		warn("GarageHandler: invalid vehicleId from", player.Name)
		return
	end

	local vehicle = getVehicleById(vehicleId)
	if not vehicle then
		warn("GarageHandler: unknown vehicleId", vehicleId, "from", player.Name)
		return
	end

	-- Load (or retrieve cached) player data
	local data = playerDataCache[player.UserId]
	if not data then
		data = loadPlayerData(player.UserId)
		playerDataCache[player.UserId] = data
	end

	-- Verify ownership: always allow if vehicle is free/unlocked
	local owns = vehicle.Unlocked or PlayerData.OwnsVehicle(data, vehicleId)
	if not owns then
		warn("GarageHandler:", player.Name, "does not own vehicle", vehicleId)
		return
	end

	-- Update equipped vehicle in cache and save
	data.EquippedVehicle = vehicleId
	savePlayerData(player.UserId, data)

	-- Swap vehicle model in Workspace
	spawnVehicle(player, vehicle)

	print(string.format("GarageHandler: %s equipped '%s' (Id=%d)", player.Name, vehicle.Name, vehicleId))
end)

-- When the player selects a map, re-spawn their equipped vehicle at the selected map spawn.
local selectMapEvent = remotesFolder:FindFirstChild("SelectMap")
if selectMapEvent then
	selectMapEvent.OnServerEvent:Connect(function(player, mapId)
		local data = playerDataCache[player.UserId]
		if not data then
			data = loadPlayerData(player.UserId)
			playerDataCache[player.UserId] = data
		end

		local vehicleId = data.EquippedVehicle or 1
		local vehicle = getVehicleById(vehicleId)
		if vehicle then
			spawnVehicle(player, vehicle)
		end
	end)
end
