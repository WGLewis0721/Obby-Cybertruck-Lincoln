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
local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
if not eventsFolder then
	warn("GarageHandler: Events folder not found in ReplicatedStorage")
	return
end

local equipVehicleEvent = eventsFolder:WaitForChild("EquipVehicle", 10)
if not equipVehicleEvent then
	warn("GarageHandler: EquipVehicle RemoteEvent not found")
	return
end

-- ── Shared data modules ───────────────────────────────────────────────────────
local moduleFolder  = ReplicatedStorage:WaitForChild("Module", 10)
local vehicleData   = require(moduleFolder:WaitForChild("VehicleData"))
local PlayerData    = require(moduleFolder:WaitForChild("PlayerData"))

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
	-- 1. Prefer a Part named "VehicleSpawn" in Workspace so level designers can
	--    control exactly where vehicles appear.
	-- 2. Fall back to 10 studs in front of the player's character if no spawn
	--    marker exists.
	local spawnCFrame = CFrame.new(0, 5, 0)  -- absolute last-resort fallback (world origin)

	local spawnMarker = workspace:FindFirstChild("VehicleSpawn")
	if spawnMarker and spawnMarker:IsA("BasePart") then
		-- Use the spawn marker's CFrame so the vehicle inherits its orientation too.
		spawnCFrame = spawnMarker.CFrame
	else
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				-- Place the vehicle 10 studs in front of the character using CFrame arithmetic
				spawnCFrame = rootPart.CFrame * CFrame.new(0, 0, -10)
			else
				warn("GarageHandler: HumanoidRootPart not found for " .. player.Name .. " — spawning vehicle at world origin")
			end
		else
			warn("GarageHandler: No character for " .. player.Name .. " — spawning vehicle at world origin")
		end
	end

	-- Place the vehicle using PrimaryPart when available, otherwise pivot the whole model.
	if newVehicle.PrimaryPart then
		newVehicle:SetPrimaryPartCFrame(spawnCFrame)
	else
		newVehicle:PivotTo(spawnCFrame)
	end

	newVehicle.Parent = workspace
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
