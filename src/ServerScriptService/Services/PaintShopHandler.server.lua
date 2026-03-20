--[[
	PaintShopHandler.server.lua
	Description: Handles paint job purchases, Speed Boost, Ultimate Bundle, and
	             map purchases via MarketplaceService.ProcessReceipt. Uses
	             PlayerDataInterface for all data persistence.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Constants           (ReplicatedStorage.Shared.Constants)
		- Logger              (ReplicatedStorage.Shared.Logger)
		- VehicleData         (ReplicatedStorage.Shared.VehicleData)
		- ShopItems           (ReplicatedStorage.Shared.ShopItems)
		- MapData             (ReplicatedStorage.Shared.MapData)
		- PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)

	Events Fired (S->C via RemoteEvents):
		- Remotes.ApplyBoost
		- Remotes.BundlePurchased
		- Remotes.MapPurchased
		- Remotes.OwnedMapsSync
		- Remotes.OpenGarage

	Remote Events Handled (C->S):
		- Remotes.OpenPaintShop

	CRITICAL: MarketplaceService.ProcessReceipt is defined ONLY here.
	          Never define it in any other script.
--]]

-- 1. Services
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- 2. Constants & shared modules
local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))
local VehicleData  = require(sharedFolder:WaitForChild("VehicleData", 10))
local ShopItems    = require(sharedFolder:WaitForChild("ShopItems", 10))
local MapData      = require(sharedFolder:WaitForChild("MapData", 10))

-- 3. Server-only dependencies
local servicesFolder      = script.Parent
local PlayerDataInterface = require(servicesFolder:WaitForChild("PlayerDataInterface", 10))

local TAG = "PaintShopHandler"

-- 4. Remote events
local remotesFolder   = ReplicatedStorage:WaitForChild(Constants.REMOTES_PATH, 10)
local openPaintShop   = remotesFolder:WaitForChild("OpenPaintShop", 10)
local applyBoost      = remotesFolder:WaitForChild("ApplyBoost", 10)
local bundlePurchased = remotesFolder:WaitForChild("BundlePurchased", 10)
local mapPurchased    = remotesFolder:WaitForChild("MapPurchased", 10)
local ownedMapsSync   = remotesFolder:WaitForChild("OwnedMapsSync", 10)
local openGarage      = remotesFolder:WaitForChild("OpenGarage", 10)

-- 5. Private variables

-- In-memory set: which players own Speed Boost this session
local BoostOwners = {}

-- Developer product IDs from ShopItems module
local SPEED_BOOST_PRODUCT_ID = 0
local BUNDLE_PRODUCT_ID      = 0
for _, item in ipairs(ShopItems) do
	if item.Name == "Speed Boost" then
		SPEED_BOOST_PRODUCT_ID = item.ProductId
	elseif item.Name == "Ultimate Bundle" then
		BUNDLE_PRODUCT_ID = item.ProductId
	end
end

-- Paint job product IDs and colour values
local paintProductIds = {
	Green = 3244954061,
	Blue  = 3244953138,
	Gold  = 3244953838,
}

local colorValues = {
	Green = Color3.fromRGB(0, 255, 0),
	Blue  = Color3.fromRGB(0, 85, 255),
	Gold  = Color3.fromRGB(255, 215, 0),
}

-- 6. Private functions

-- Recolour all BaseParts in the "Body" Model of a player's vehicle
local function applyPaintToVehicle(player, colorValue)
	local vehicleName = string.format(Constants.VEHICLE_NAME_FORMAT, player.UserId)
	local truck       = workspace:FindFirstChild(vehicleName)
	if not truck then
		Logger.Warn(TAG, "Vehicle not found for %s", player.Name)
		return false
	end
	local bodyModel = truck:FindFirstChild("Body")
	if not bodyModel or not bodyModel:IsA("Model") then
		Logger.Warn(TAG, "Body model not found inside vehicle for %s", player.Name)
		return false
	end
	for _, part in ipairs(bodyModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Color = colorValue
		end
	end
	return true
end

-- 7. Remote event handlers

-- Client opens paint shop -> send owned-maps sync
openPaintShop.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	Logger.Info(TAG, "%s opened the paint shop", player.Name)
	local data = PlayerDataInterface.GetData(player.UserId)
	ownedMapsSync:FireClient(player, data and data.OwnedMaps or {})
end)

-- 8. ProcessReceipt (CRITICAL: defined only here)
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Paint job purchases
	for colorName, productId in pairs(paintProductIds) do
		if receiptInfo.ProductId == productId then
			local ok = applyPaintToVehicle(player, colorValues[colorName])
			if not ok then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			PlayerDataInterface.UpdateData(player.UserId, function(data)
				if not data.OwnedPaints then data.OwnedPaints = {} end
				if not table.find(data.OwnedPaints, colorName) then
					table.insert(data.OwnedPaints, colorName)
				end
				return data
			end)
			Logger.Info(TAG, "%s painted vehicle %s", player.Name, colorName)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- Speed Boost purchase
	if SPEED_BOOST_PRODUCT_ID ~= 0 and receiptInfo.ProductId == SPEED_BOOST_PRODUCT_ID then
		BoostOwners[player.UserId] = true
		PlayerDataInterface.UpdateData(player.UserId, function(data)
			data.HasBoost = true
			return data
		end)
		applyBoost:FireClient(player)
		Logger.Info(TAG, "%s purchased Speed Boost", player.Name)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Ultimate Bundle purchase
	if BUNDLE_PRODUCT_ID ~= 0 and receiptInfo.ProductId == BUNDLE_PRODUCT_ID then
		PlayerDataInterface.UpdateData(player.UserId, function(data)
			if not data.OwnedVehicles then data.OwnedVehicles = { 1 } end
			if not data.OwnedPaints   then data.OwnedPaints   = {}    end

			for _, vehicle in ipairs(VehicleData) do
				if not table.find(data.OwnedVehicles, vehicle.Id) then
					table.insert(data.OwnedVehicles, vehicle.Id)
				end
			end

			for _, item in ipairs(ShopItems) do
				if item.Color ~= nil and not table.find(data.OwnedPaints, item.Name) then
					table.insert(data.OwnedPaints, item.Name)
				end
			end

			data.HasBoost = true
			return data
		end)

		BoostOwners[player.UserId] = true
		bundlePurchased:FireClient(player)
		openGarage:FireClient(player)
		Logger.Info(TAG, "%s purchased Ultimate Bundle", player.Name)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Map purchases
	for _, map in ipairs(MapData) do
		if map.Type == "Robux" and map.ProductId ~= 0 and receiptInfo.ProductId == map.ProductId then
			PlayerDataInterface.UpdateData(player.UserId, function(data)
				if not data.OwnedMaps then data.OwnedMaps = {} end
				if not table.find(data.OwnedMaps, map.Name) then
					table.insert(data.OwnedMaps, map.Name)
				end
				return data
			end)
			mapPurchased:FireClient(player, map.Name)
			Logger.Info(TAG, "%s purchased map: %s", player.Name, map.Name)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- 9. Initialization
Logger.Info(TAG, "PaintShopHandler ready")
