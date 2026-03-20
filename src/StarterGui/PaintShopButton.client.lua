local MarketplaceService = game:GetService("MarketplaceService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player       = Players.LocalPlayer
local openPaintShop = ReplicatedStorage:WaitForChild("OpenPaintShop")

-- ── Theme (matches LoadingScreen) ──────────────────────────────────────────────
local COLOR_BG          = Color3.fromRGB(8, 8, 18)
local COLOR_PANEL       = Color3.fromRGB(18, 18, 35)
local COLOR_ACCENT      = Color3.fromRGB(0, 210, 255)
local COLOR_BTN         = Color3.fromRGB(22, 22, 44)
local COLOR_BTN_HOVER   = Color3.fromRGB(0, 170, 210)
local COLOR_TEXT        = Color3.new(1, 1, 1)
local COLOR_SUBTEXT     = Color3.fromRGB(160, 160, 200)
local COLOR_CLOSE       = Color3.fromRGB(180, 40, 40)
local COLOR_CLOSE_HOVER = Color3.fromRGB(220, 60, 60)
local COLOR_TAB_ACTIVE  = Color3.fromRGB(0, 210, 255)
local COLOR_TAB_IDLE    = Color3.fromRGB(30, 30, 60)

-- ── Paint jobs (Blue/Gold ProductIds corrected) ────────────────────────────────
local paintJobs = {
{ Name = "Green", ProductId = 3244954061, Color = Color3.fromRGB(0, 255, 0),   Price = 50 },
{ Name = "Blue",  ProductId = 3244953138, Color = Color3.fromRGB(0, 85, 255),  Price = 50 },
{ Name = "Gold",  ProductId = 3244953838, Color = Color3.fromRGB(255, 215, 0), Price = 50 },
}

-- ── Cars available for Robux purchase ─────────────────────────────────────────
-- TODO: Replace ProductId = 0 placeholders with real Roblox developer product IDs
local carItems = {
{ Name = "Tesla Model 3",  ProductId = 0, Price = 100, Icon = "🚗" },
{ Name = "Tesla Roadster", ProductId = 0, Price = 200, Icon = "🏎️" },
{ Name = "Tesla Model Y",  ProductId = 0, Price = 150, Icon = "🚙" },
}

-- ── ScreenGui ──────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PaintShopGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── Shop toggle button ─────────────────────────────────────────────────────────
local shopToggleBtn = Instance.new("TextButton")
shopToggleBtn.Name = "ShopToggle"
shopToggleBtn.Size = UDim2.new(0, 140, 0, 44)
shopToggleBtn.Position = UDim2.new(0, 20, 0.5, -22)
shopToggleBtn.BackgroundColor3 = COLOR_BTN
shopToggleBtn.BorderSizePixel = 0
shopToggleBtn.Text = "🎨  Shop"
shopToggleBtn.Font = Enum.Font.GothamBold
shopToggleBtn.TextSize = 15
shopToggleBtn.TextColor3 = COLOR_TEXT
shopToggleBtn.AutoButtonColor = false
shopToggleBtn.Parent = screenGui

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 10)
tCorner.Parent = shopToggleBtn

local tStroke = Instance.new("UIStroke")
tStroke.Color = COLOR_ACCENT
tStroke.Thickness = 1.5
tStroke.Transparency = 0.4
tStroke.Parent = shopToggleBtn

-- ── Shop frame (hidden by default) ────────────────────────────────────────────
local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0, 360, 0, 340)
frame.Position = UDim2.new(0, 20, 0.5, -230)
frame.BackgroundColor3 = COLOR_PANEL
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui

local fCorner = Instance.new("UICorner")
fCorner.CornerRadius = UDim.new(0, 16)
fCorner.Parent = frame

local fStroke = Instance.new("UIStroke")
fStroke.Color = COLOR_ACCENT
fStroke.Thickness = 1.5
fStroke.Transparency = 0.4
fStroke.Parent = frame

-- ── Header bar ─────────────────────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 48)
header.BackgroundColor3 = COLOR_BG
header.BorderSizePixel = 0
header.Parent = frame

local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 16)
hCorner.Parent = header

-- Patch to square the bottom corners of the header
local hPatch = Instance.new("Frame")
hPatch.Size = UDim2.new(1, 0, 0, 16)
hPatch.Position = UDim2.new(0, 0, 1, -16)
hPatch.BackgroundColor3 = COLOR_BG
hPatch.BorderSizePixel = 0
hPatch.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -56, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚡  Cybertruck Shop"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextColor3 = COLOR_ACCENT
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -42, 0, 8)
closeBtn.BackgroundColor3 = COLOR_CLOSE
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = COLOR_TEXT
closeBtn.AutoButtonColor = false
closeBtn.Parent = header

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 8)
cCorner.Parent = closeBtn

-- ── Tab bar ────────────────────────────────────────────────────────────────────
local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -24, 0, 36)
tabBar.Position = UDim2.new(0, 12, 0, 56)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabBar

local function makeTab(label, order)
local tab = Instance.new("TextButton")
tab.Name = label .. "Tab"
tab.Size = UDim2.new(0, 110, 1, 0)
tab.BackgroundColor3 = COLOR_TAB_IDLE
tab.BorderSizePixel = 0
tab.Text = label
tab.Font = Enum.Font.GothamBold
tab.TextSize = 14
tab.TextColor3 = COLOR_TEXT
tab.AutoButtonColor = false
tab.LayoutOrder = order
tab.Parent = tabBar
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 8)
tc.Parent = tab
return tab
end

local paintTab = makeTab("🎨  Paint", 1)
local carsTab  = makeTab("🚗  Cars",  2)

-- ── Content area ───────────────────────────────────────────────────────────────
local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -24, 1, -106)
contentArea.Position = UDim2.new(0, 12, 0, 100)
contentArea.BackgroundTransparency = 1
contentArea.Parent = frame

-- ── Paint tab content ──────────────────────────────────────────────────────────
local paintContent = Instance.new("Frame")
paintContent.Name = "PaintContent"
paintContent.Size = UDim2.new(1, 0, 1, 0)
paintContent.BackgroundTransparency = 1
paintContent.Visible = true
paintContent.Parent = contentArea

local paintLayout = Instance.new("UIListLayout")
paintLayout.FillDirection = Enum.FillDirection.Horizontal
paintLayout.SortOrder = Enum.SortOrder.LayoutOrder
paintLayout.Padding = UDim.new(0, 10)
paintLayout.VerticalAlignment = Enum.VerticalAlignment.Center
paintLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
paintLayout.Parent = paintContent

for idx, job in ipairs(paintJobs) do
local card = Instance.new("TextButton")
card.Name = job.Name
card.Size = UDim2.new(0, 90, 0, 120)
card.BackgroundColor3 = COLOR_BTN
card.BorderSizePixel = 0
card.Text = ""
card.AutoButtonColor = false
card.LayoutOrder = idx
card.Parent = paintContent

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 10)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = job.Color
cardStroke.Thickness = 1.5
cardStroke.Transparency = 0.3
cardStroke.Parent = card

-- Color swatch
local swatch = Instance.new("Frame")
swatch.Size = UDim2.new(0, 60, 0, 60)
swatch.Position = UDim2.new(0.5, -30, 0, 10)
swatch.BackgroundColor3 = job.Color
swatch.BorderSizePixel = 0
swatch.Parent = card

local swatchCorner = Instance.new("UICorner")
swatchCorner.CornerRadius = UDim.new(0, 8)
swatchCorner.Parent = swatch

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -4, 0, 20)
nameLabel.Position = UDim2.new(0, 2, 0, 76)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = job.Name
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 13
nameLabel.TextColor3 = COLOR_TEXT
nameLabel.TextXAlignment = Enum.TextXAlignment.Center
nameLabel.Parent = card

local priceLabel = Instance.new("TextLabel")
priceLabel.Size = UDim2.new(1, -4, 0, 18)
priceLabel.Position = UDim2.new(0, 2, 0, 96)
priceLabel.BackgroundTransparency = 1
priceLabel.Text = job.Price .. " R$"
priceLabel.Font = Enum.Font.Gotham
priceLabel.TextSize = 11
priceLabel.TextColor3 = COLOR_SUBTEXT
priceLabel.TextXAlignment = Enum.TextXAlignment.Center
priceLabel.Parent = card

card.MouseButton1Click:Connect(function()
MarketplaceService:PromptProductPurchase(player, job.ProductId)
end)
end

-- ── Cars tab content ───────────────────────────────────────────────────────────
local carsContent = Instance.new("Frame")
carsContent.Name = "CarsContent"
carsContent.Size = UDim2.new(1, 0, 1, 0)
carsContent.BackgroundTransparency = 1
carsContent.Visible = false
carsContent.Parent = contentArea

local carsLayout = Instance.new("UIListLayout")
carsLayout.FillDirection = Enum.FillDirection.Vertical
carsLayout.SortOrder = Enum.SortOrder.LayoutOrder
carsLayout.Padding = UDim.new(0, 8)
carsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
carsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
carsLayout.Parent = carsContent

for idx, car in ipairs(carItems) do
local row = Instance.new("Frame")
row.Name = car.Name
row.Size = UDim2.new(1, 0, 0, 56)
row.BackgroundColor3 = COLOR_BTN
row.BorderSizePixel = 0
row.LayoutOrder = idx
row.Parent = carsContent

local rowCorner = Instance.new("UICorner")
rowCorner.CornerRadius = UDim.new(0, 10)
rowCorner.Parent = row

local rowStroke = Instance.new("UIStroke")
rowStroke.Color = COLOR_ACCENT
rowStroke.Thickness = 1
rowStroke.Transparency = 0.6
rowStroke.Parent = row

local iconLabel = Instance.new("TextLabel")
iconLabel.Size = UDim2.new(0, 48, 1, 0)
iconLabel.Position = UDim2.new(0, 8, 0, 0)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = car.Icon
iconLabel.TextSize = 26
iconLabel.Font = Enum.Font.GothamBold
iconLabel.TextColor3 = COLOR_TEXT
iconLabel.Parent = row

local carNameLabel = Instance.new("TextLabel")
carNameLabel.Size = UDim2.new(0, 160, 1, 0)
carNameLabel.Position = UDim2.new(0, 62, 0, 0)
carNameLabel.BackgroundTransparency = 1
carNameLabel.Text = car.Name
carNameLabel.Font = Enum.Font.GothamBold
carNameLabel.TextSize = 14
carNameLabel.TextColor3 = COLOR_TEXT
carNameLabel.TextXAlignment = Enum.TextXAlignment.Left
carNameLabel.Parent = row

local buyCarBtn = Instance.new("TextButton")
buyCarBtn.Name = "BuyBtn"
buyCarBtn.Size = UDim2.new(0, 80, 0, 36)
buyCarBtn.Position = UDim2.new(1, -92, 0.5, -18)
buyCarBtn.BackgroundColor3 = COLOR_ACCENT
buyCarBtn.BorderSizePixel = 0
buyCarBtn.Text = car.Price .. " R$"
buyCarBtn.Font = Enum.Font.GothamBold
buyCarBtn.TextSize = 13
buyCarBtn.TextColor3 = COLOR_BG
buyCarBtn.AutoButtonColor = false
buyCarBtn.Parent = row

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = buyCarBtn

buyCarBtn.MouseButton1Click:Connect(function()
if car.ProductId ~= 0 then
MarketplaceService:PromptProductPurchase(player, car.ProductId)
else
warn("Car ProductId not set for: " .. car.Name)
end
end)
end

-- ── Tab switching ──────────────────────────────────────────────────────────────
local function switchTab(active)
if active == "Paint" then
paintContent.Visible = true
carsContent.Visible = false
paintTab.BackgroundColor3 = COLOR_TAB_ACTIVE
paintTab.TextColor3 = COLOR_BG
carsTab.BackgroundColor3 = COLOR_TAB_IDLE
carsTab.TextColor3 = COLOR_TEXT
else
paintContent.Visible = false
carsContent.Visible = true
paintTab.BackgroundColor3 = COLOR_TAB_IDLE
paintTab.TextColor3 = COLOR_TEXT
carsTab.BackgroundColor3 = COLOR_TAB_ACTIVE
carsTab.TextColor3 = COLOR_BG
end
end

switchTab("Paint")

paintTab.MouseButton1Click:Connect(function()
switchTab("Paint")
end)

carsTab.MouseButton1Click:Connect(function()
switchTab("Cars")
end)

-- ── Hover effects ──────────────────────────────────────────────────────────────
local function addHover(btn, normalColor, hoverColor)
btn.MouseEnter:Connect(function()
TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
BackgroundColor3 = hoverColor,
}):Play()
end)
btn.MouseLeave:Connect(function()
TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
BackgroundColor3 = normalColor,
}):Play()
end)
end

addHover(shopToggleBtn, COLOR_BTN, COLOR_BTN_HOVER)
addHover(closeBtn, COLOR_CLOSE, COLOR_CLOSE_HOVER)

-- ── Toggle / close logic ───────────────────────────────────────────────────────
shopToggleBtn.MouseButton1Click:Connect(function()
frame.Visible = not frame.Visible
if frame.Visible then
openPaintShop:FireServer()
end
end)

closeBtn.MouseButton1Click:Connect(function()
frame.Visible = false
end)
