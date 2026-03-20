local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local openPaintShop = ReplicatedStorage:WaitForChild("OpenPaintShop")

-- 🎨 Paint jobs with product IDs and colors
local paintJobs = {
    { Name = "Green", ProductId = 3244954061, Color = Color3.fromRGB(0, 255, 0) },
    { Name = "Blue",  ProductId = 3244953838, Color = Color3.fromRGB(0, 85, 255) },
    { Name = "Gold",  ProductId = 3244953138, Color = Color3.fromRGB(255, 215, 0) },
}

-- 🖼️ Build the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PaintShopGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 🛒 Shop toggle button (always visible)
local shopBtn = Instance.new("TextButton")
shopBtn.Size = UDim2.new(0, 120, 0, 40)
shopBtn.Position = UDim2.new(0, 20, 0.5, -20)
shopBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.Text = "🎨 Paint Shop"
shopBtn.Font = Enum.Font.GothamBold
shopBtn.TextSize = 14
shopBtn.Parent = screenGui

-- 🪟 Shop menu frame (hidden by default)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 180)
frame.Position = UDim2.new(0, 20, 0.5, -170)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

-- 📝 Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Cybertruck Paint Shop"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

-- 🎨 Color buttons
local x = 20
for _, job in ipairs(paintJobs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.Position = UDim2.new(0, x, 0, 45)
    btn.Text = job.Name
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BackgroundColor3 = job.Color
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = frame

    btn.MouseButton1Click:Connect(function()
        MarketplaceService:PromptProductPurchase(player, job.ProductId)
    end)

    x = x + 90
end

-- ❌ Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 70, 0, 30)
closeBtn.Position = UDim2.new(1, -80, 1, -40)
closeBtn.Text = "Close"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 13
closeBtn.Parent = frame

-- 🔁 Toggle logic
shopBtn.MouseButton1Click:Connect(function()
    frame.Visible = not frame.Visible
    openPaintShop:FireServer()
end)

closeBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
end)