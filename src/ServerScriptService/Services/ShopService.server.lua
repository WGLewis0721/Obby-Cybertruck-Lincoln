--[[
	ShopService.server.lua
	Description: Server-authoritative coin purchases for cars, paints and tracks.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	The client NEVER decides affordability or ownership -- it only names the item
	it wants. This script re-reads the balance from PlayerDataInterface, validates,
	deducts and grants inside one UpdateData call, then replies with the result.

	Robux purchases are NOT handled here: MarketplaceService.ProcessReceipt is
	defined only in PaintShopHandler, per the project's single-ProcessReceipt rule.

	Dependencies:
		- Constants           (ReplicatedStorage.Module.Constants)
		- Logger              (ReplicatedStorage.Module.Logger)
		- ShopConfig          (ReplicatedStorage.Module.ShopConfig)
		- VehicleData         (ReplicatedStorage.Module.VehicleData)
		- PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)

	RemoteFunction: Remotes.PurchaseWithCoins(kind, id) -> { ok, reason, balance }
	RemoteFunction: Remotes.GetShopState() -> { coins, ownedCars, ownedPaints, ownedTracks, ... }
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))
local ShopConfig   = require(sharedFolder:WaitForChild("ShopConfig", 10))
local VehicleData  = require(sharedFolder:WaitForChild("VehicleData", 10))

local servicesFolder      = script.Parent
local PlayerDataInterface = require(servicesFolder:WaitForChild("PlayerDataInterface", 10))

local TAG = "ShopService"
local PURCHASE_COOLDOWN = 0.5 -- seconds between purchase attempts per player

local remotesFolder = ReplicatedStorage:WaitForChild(Constants.REMOTES_PATH, 10)

local function ensureRemoteFunction(name)
	local rf = remotesFolder:FindFirstChild(name)
	if not rf then
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotesFolder
	end
	return rf
end

local purchaseWithCoins = ensureRemoteFunction("PurchaseWithCoins")
local getShopState      = ensureRemoteFunction("GetShopState")

-- Per-player rate limiting: a remote is attacker-controlled and can be spammed.
local lastPurchaseAt = {}

local function has(list, value)
	if type(list) ~= "table" then return false end
	return table.find(list, value) ~= nil
end

local function buildState(userId)
	local data = PlayerDataInterface.GetData(userId) or {}
	return {
		coins         = data.Coins or 0,
		ownedCars     = data.OwnedVehicles or { 1 },
		ownedPaints   = data.OwnedPaints or {},
		ownedTracks   = data.OwnedMaps or { "skyscraper" },
		equippedCar   = data.EquippedVehicle or Constants.DEFAULT_VEHICLE_ID,
		equippedPaint = data.SelectedPaint,
	}
end

--[[
	Resolve an item to { price, owned, label, grant(data) }.
	Returns nil when the id is unknown -- caller rejects the request.
--]]
local function resolveItem(kind, id, data)
	if kind == "car" then
		if type(id) ~= "number" then return nil end
		-- VehicleData is the single source of truth for cars.
		local car
		for _, v in ipairs(VehicleData) do
			if v.Id == id then
				car = v
				break
			end
		end
		if not car or not car.CoinPrice or car.CoinPrice <= 0 then return nil end
		return {
			price = car.CoinPrice,
			owned = car.Unlocked or has(data.OwnedVehicles, id),
			label = car.Name,
			grant = function(d)
				d.OwnedVehicles = d.OwnedVehicles or { 1 }
				if not has(d.OwnedVehicles, id) then table.insert(d.OwnedVehicles, id) end
			end,
		}

	elseif kind == "paint" then
		if type(id) ~= "string" then return nil end
		local paint = ShopConfig.GetPaint(id)
		if not paint or not paint.CoinPrice or paint.CoinPrice <= 0 then return nil end
		return {
			price = paint.CoinPrice,
			owned = has(data.OwnedPaints, id),
			label = paint.Name,
			grant = function(d)
				d.OwnedPaints = d.OwnedPaints or {}
				if not has(d.OwnedPaints, id) then table.insert(d.OwnedPaints, id) end
			end,
		}

	elseif kind == "track" then
		if type(id) ~= "string" then return nil end
		local track = ShopConfig.GetTrack(id)
		if not track or not track.CoinPrice or track.CoinPrice <= 0 then return nil end
		return {
			price = track.CoinPrice,
			owned = track.OwnedByDefault or has(data.OwnedMaps, id),
			label = track.Name,
			grant = function(d)
				d.OwnedMaps = d.OwnedMaps or { "skyscraper" }
				if not has(d.OwnedMaps, id) then table.insert(d.OwnedMaps, id) end
			end,
		}
	end
	return nil
end

purchaseWithCoins.OnServerInvoke = function(player, kind, id)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return { ok = false, reason = "invalid" }
	end
	if type(kind) ~= "string" then
		return { ok = false, reason = "invalid" }
	end

	local userId = player.UserId

	local now = os.clock()
	if lastPurchaseAt[userId] and now - lastPurchaseAt[userId] < PURCHASE_COOLDOWN then
		return { ok = false, reason = "Slow down" }
	end
	lastPurchaseAt[userId] = now

	local data = PlayerDataInterface.GetData(userId)
	if not data then
		return { ok = false, reason = "Data not loaded" }
	end

	local item = resolveItem(kind, id, data)
	if not item then
		Logger.Warn(TAG, "%s requested unknown %s '%s'", player.Name, kind, tostring(id))
		return { ok = false, reason = "Unavailable" }
	end
	if item.owned then
		return { ok = false, reason = "Already owned", balance = data.Coins or 0 }
	end
	if (data.Coins or 0) < item.price then
		return { ok = false, reason = "Not enough coins", balance = data.Coins or 0 }
	end

	-- Deduct and grant atomically so a mid-flight failure can't hand out a free item.
	local newBalance = data.Coins or 0
	PlayerDataInterface.UpdateData(userId, function(d)
		if (d.Coins or 0) < item.price then
			return d -- balance changed underneath us; abort without granting
		end
		d.Coins = (d.Coins or 0) - item.price
		item.grant(d)
		newBalance = d.Coins
		return d
	end)

	-- Keep the leaderstats display in sync immediately.
	local ls = player:FindFirstChild("leaderstats")
	local coinsVal = ls and ls:FindFirstChild("Coins")
	if coinsVal then coinsVal.Value = newBalance end

	Logger.Info(TAG, "%s bought %s '%s' for %d coins (balance=%d)",
		player.Name, kind, item.label, item.price, newBalance)

	return { ok = true, balance = newBalance, kind = kind, id = id }
end

getShopState.OnServerInvoke = function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
	return buildState(player.UserId)
end

Players.PlayerRemoving:Connect(function(player)
	lastPurchaseAt[player.UserId] = nil
end)

Logger.Info(TAG, "ShopService ready")
