local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local openPaintShop = ReplicatedStorage:WaitForChild("OpenPaintShop")

-- 🎨 Developer Product IDs
local paintProductIds = {
    Green = 3244954061,
    Blue = 3244953838,
    Gold = 3244953138
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

-- 💵 Handle paint purchase
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    for colorName, productId in pairs(paintProductIds) do
        if receiptInfo.ProductId == productId then
            local truck = workspace:FindFirstChild("Tesla Cybertruck")
            if not truck then
                warn("🚨 Tesla Cybertruck not found in Workspace!")
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            local bodyModel = truck:FindFirstChild("Body")
            if not bodyModel or not bodyModel:IsA("Model") then
                warn("🚨 Body model not found inside Tesla Cybertruck!")
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end

            for _, part in ipairs(bodyModel:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Color = colorValues[colorName]
                end
            end

            print(player.Name .. " painted the Tesla Cybertruck " .. colorName)
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end