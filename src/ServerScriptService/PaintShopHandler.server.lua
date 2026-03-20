local DataStoreService   = game:GetService("DataStoreService")
local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local openPaintShop   = ReplicatedStorage:WaitForChild("OpenPaintShop")
local applyBoost      = ReplicatedStorage:WaitForChild("ApplyBoost")
local bundlePurchased = ReplicatedStorage:WaitForChild("BundlePurchased")

local eventsFolder  = ReplicatedStorage:WaitForChild("Events")
local openGarage    = eventsFolder:WaitForChild("OpenGarage")

-- ── Shared data modules ───────────────────────────────────────────────────────
local moduleFolder = ReplicatedStorage:WaitForChild("Module")
local VehicleData  = require(moduleFolder:WaitForChild("VehicleData"))
local ShopItems    = require(moduleFolder:WaitForChild("ShopItems"))

-- ── DataStore (same store as GarageHandler) ───────────────────────────────────
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")

-- ── In-memory set of players who own the Speed Boost this session ─────────────
local BoostOwners = {}

-- ── Helper: load player data ──────────────────────────────────────────────────
local function loadPlayerData(userId)
	local ok, data = pcall(function()
		return playerDataStore:GetAsync("Player_" .. userId)
	end)
	if ok and data then return data end
	if not ok then warn("PaintShopHandler: DataStore load failed for", userId, "—", data) end
	return { EquippedVehicle = 1, OwnedVehicles = { 1 }, OwnedPaints = {}, HasBoost = false }
end

-- ── Helper: save player data ──────────────────────────────────────────────────
local function savePlayerData(userId, data)
	local ok, err = pcall(function()
		playerDataStore:SetAsync("Player_" .. userId, data)
	end)
	if not ok then warn("PaintShopHandler: DataStore save failed for", userId, "—", err) end
end

-- ── Developer product IDs from the shared ShopItems module ───────────────────
local SPEED_BOOST_PRODUCT_ID = 0
local BUNDLE_PRODUCT_ID      = 0
for _, item in ipairs(ShopItems) do
	if item.Name == "Speed Boost" then
		SPEED_BOOST_PRODUCT_ID = item.ProductId
	elseif item.Name == "Ultimate Bundle" then
		BUNDLE_PRODUCT_ID = item.ProductId
	end
end

-- 🎨 Developer Product IDs
local paintProductIds = {
    Green = 3244954061,
    Blue = 3244953138,
    Gold = 3244953838
}

-- 🎨 Color values
local colorValues = {
    Green = Color3.fromRGB(0, 255, 0),
    Blue = Color3.fromRGB(0, 85, 255),
    Gold = Color3.fromRGB(255, 215, 0)
}

-- 🖱️ Handle shop open request from client
openPaintShop.OnServerEvent:Connect(function(player)
    print(player.Name .. " opened the paint shop")
end)

-- 💵 Handle all product purchases (paint jobs, Speed Boost, Ultimate Bundle)
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    -- ── Paint job purchases ───────────────────────────────────────────────────
    for colorName, productId in pairs(paintProductIds) do
        if receiptInfo.ProductId == productId then
            -- Recolor the player's currently equipped vehicle (named "Vehicle_[UserId]"
            -- by GarageHandler) rather than a hardcoded model name.
            local truck = workspace:FindFirstChild("Vehicle_" .. player.UserId)
            if not truck then
                warn("🚨 Vehicle not found in Workspace for " .. player.Name)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            local bodyModel = truck:FindFirstChild("Body")
            if not bodyModel or not bodyModel:IsA("Model") then
                warn("🚨 Body model not found inside vehicle for " .. player.Name)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            for _, part in ipairs(bodyModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Color = colorValues[colorName]
                end
            end

            print(player.Name .. " painted their vehicle " .. colorName)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end

    -- ── Speed Boost purchase ──────────────────────────────────────────────────
    if SPEED_BOOST_PRODUCT_ID ~= 0 and receiptInfo.ProductId == SPEED_BOOST_PRODUCT_ID then
        BoostOwners[player.UserId] = true
        -- Persist boost ownership to DataStore
        local data = loadPlayerData(player.UserId)
        if not data.OwnedPaints then data.OwnedPaints = {} end
        data.HasBoost = true
        savePlayerData(player.UserId, data)
        -- Notify client so the perk hotbar lights up immediately
        applyBoost:FireClient(player)
        print(player.Name .. " purchased Speed Boost")
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- ── Ultimate Bundle purchase ──────────────────────────────────────────────
    if BUNDLE_PRODUCT_ID ~= 0 and receiptInfo.ProductId == BUNDLE_PRODUCT_ID then
        local data = loadPlayerData(player.UserId)
        if not data.OwnedVehicles then data.OwnedVehicles = { 1 } end
        if not data.OwnedPaints   then data.OwnedPaints   = {}    end

        -- Grant every vehicle
        for _, vehicle in ipairs(VehicleData) do
            local alreadyOwned = false
            for _, id in ipairs(data.OwnedVehicles) do
                if id == vehicle.Id then alreadyOwned = true; break end
            end
            if not alreadyOwned then
                table.insert(data.OwnedVehicles, vehicle.Id)
            end
        end

        -- Grant every paint job (items that have a Color field, i.e. are paints)
        for _, item in ipairs(ShopItems) do
            if item.Color ~= nil then
                local alreadyOwned = false
                for _, name in ipairs(data.OwnedPaints) do
                    if name == item.Name then alreadyOwned = true; break end
                end
                if not alreadyOwned then
                    table.insert(data.OwnedPaints, item.Name)
                end
            end
        end

        -- Grant Speed Boost as part of the bundle
        data.HasBoost = true
        BoostOwners[player.UserId] = true

        savePlayerData(player.UserId, data)
        -- Fire both bundle confirmed and open garage so the UI refreshes
        bundlePurchased:FireClient(player)
        openGarage:FireClient(player)
        print(player.Name .. " purchased Ultimate Bundle")
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end