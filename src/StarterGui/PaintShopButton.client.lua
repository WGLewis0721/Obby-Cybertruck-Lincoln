local MarketplaceService = game:GetService("MarketplaceService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player          = Players.LocalPlayer
local remotesFolder   = ReplicatedStorage:WaitForChild("Remotes")
local openPaintShop   = remotesFolder:WaitForChild("OpenPaintShop")
-- ApplyBoost fires from the server when the player owns a Speed Boost
local applyBoost      = remotesFolder:WaitForChild("ApplyBoost")
-- MapPurchased fires from the server when the player successfully buys a map
local mapPurchased    = remotesFolder:WaitForChild("MapPurchased")
-- OwnedMapsSync fires from the server when the shop opens, sending the player's
-- already-owned map names so buttons reflect their prior purchases correctly.
local ownedMapsSync   = remotesFolder:WaitForChild("OwnedMapsSync")

-- ── Shared shop data ───────────────────────────────────────────────────────────
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local ShopItems    = require(sharedFolder:WaitForChild("ShopItems"))
-- MapData provides the list of maps (free and purchasable)
local MapData      = require(sharedFolder:WaitForChild("MapData"))

-- Extract product IDs and prices for the new item types from ShopItems
local SPEED_BOOST_PRODUCT_ID = 0
local SPEED_BOOST_PRICE      = 150
local BUNDLE_PRODUCT_ID      = 0
local BUNDLE_PRICE           = 1000
for _, item in ipairs(ShopItems) do
	if item.Name == "Speed Boost" then
		SPEED_BOOST_PRODUCT_ID = item.ProductId
		SPEED_BOOST_PRICE      = item.Price
	elseif item.Name == "Ultimate Bundle" then
		BUNDLE_PRODUCT_ID = item.ProductId
		BUNDLE_PRICE      = item.Price
	end
end

-- Local flag – set to true when the server confirms the player owns a Speed Boost
local boostOwned = false
-- Reference to the buy button on the Upgrades card so we can grey it out
local boostBuyBtn

-- Track which maps the local player already owns this session (keyed by map Name)
local ownedMaps = {}
-- References to map buy buttons so MapPurchased can update them (keyed by map Name)
local mapBuyBtns = {}

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

-- ── Paint jobs: filter from the shared ShopItems module ───────────────────────
-- Only include purchasable paint items (Color field present, ProductId non-zero).
local paintJobs = {}
for _, item in ipairs(ShopItems) do
	if item.Color ~= nil and item.ProductId ~= 0 then
		table.insert(paintJobs, item)
	end
end

-- ── ScreenGui ──────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PaintShopGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ── Shop toggle button ─────────────────────────────────────────────────────────
-- Replaced by GameHUD.client.lua which provides the unified nav button bar.
if false then -- replaced by GameHUD
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
	shopToggleBtn.Visible = false -- Reveal only after player spawns

	local tCorner = Instance.new("UICorner")
	tCorner.CornerRadius = UDim.new(0, 10)
	tCorner.Parent = shopToggleBtn

	player.CharacterAdded:Connect(function()
		shopToggleBtn.Visible = true
	end)

	player.CharacterRemoving:Connect(function()
		shopToggleBtn.Visible = false
	end)

	local tStroke = Instance.new("UIStroke")
	tStroke.Color = COLOR_ACCENT
	tStroke.Thickness = 1.5
	tStroke.Transparency = 0.4
	tStroke.Parent = shopToggleBtn
end -- replaced by GameHUD

-- ── Shop frame (hidden by default) ────────────────────────────────────────────
local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0, 660, 0, 360)
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

-- ── Map purchase notification ──────────────────────────────────────────────────
-- Fades in above the shop frame when a map is purchased, then fades out after 3 s.
local mapNotifLabel = Instance.new("TextLabel")
mapNotifLabel.Name = "MapNotification"
mapNotifLabel.Size = UDim2.new(0, 320, 0, 44)
mapNotifLabel.Position = UDim2.new(0, 20, 0.5, -286)
mapNotifLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mapNotifLabel.BorderSizePixel = 0
mapNotifLabel.Text = ""
mapNotifLabel.Font = Enum.Font.GothamBold
mapNotifLabel.TextSize = 15
mapNotifLabel.TextColor3 = Color3.fromRGB(74, 240, 255)
mapNotifLabel.TextXAlignment = Enum.TextXAlignment.Center
mapNotifLabel.BackgroundTransparency = 1
mapNotifLabel.TextTransparency = 1
mapNotifLabel.Parent = screenGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 10)
notifCorner.Parent = mapNotifLabel

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(74, 240, 255)
notifStroke.Thickness = 1.5
notifStroke.Transparency = 1
notifStroke.Parent = mapNotifLabel

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
tab.Size = UDim2.new(0, 100, 1, 0)
tab.BackgroundColor3 = COLOR_TAB_IDLE
tab.BorderSizePixel = 0
tab.Text = label
tab.Font = Enum.Font.GothamBold
tab.TextSize = 13
tab.TextColor3 = COLOR_TEXT
tab.AutoButtonColor = false
tab.LayoutOrder = order
tab.Parent = tabBar
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(0, 8)
tc.Parent = tab
return tab
end

local paintTab    = makeTab("🎨  Paint",    1)
local upgradesTab = makeTab("⚡  Upgrades", 2)  -- NEW: Speed Boost and future upgrades
local bundleTab   = makeTab("💎  Bundle",   3)  -- Ultimate Bundle (best value)
local mapsTab     = makeTab("🗺️  Maps",    4)  -- Purchasable maps

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

-- ── Upgrades tab content ───────────────────────────────────────────────────────
-- Shows purchasable upgrade items (Speed Boost, etc.). Future perks can be
-- appended here following the same card pattern.
local upgradesContent = Instance.new("Frame")
upgradesContent.Name = "UpgradesContent"
upgradesContent.Size = UDim2.new(1, 0, 1, 0)
upgradesContent.BackgroundTransparency = 1
upgradesContent.Visible = false
upgradesContent.Parent = contentArea

-- ── Speed Boost card ──────────────────────────────────────────────────────────
local boostCard = Instance.new("Frame")
boostCard.Name = "SpeedBoostCard"
boostCard.Size = UDim2.new(0, 220, 0, 210)
boostCard.Position = UDim2.new(0.5, -110, 0.5, -105)
boostCard.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
boostCard.BorderSizePixel = 0
boostCard.Parent = upgradesContent

local boostCardCorner = Instance.new("UICorner")
boostCardCorner.CornerRadius = UDim.new(0, 12)
boostCardCorner.Parent = boostCard

-- Cyan border matches Upgrades tab accent
local boostCardStroke = Instance.new("UIStroke")
boostCardStroke.Color = Color3.fromRGB(74, 240, 255)
boostCardStroke.Thickness = 2
boostCardStroke.Parent = boostCard

-- Large ⚡ icon centered at the top of the card
local boostIconLabel = Instance.new("TextLabel")
boostIconLabel.Size = UDim2.new(1, 0, 0, 68)
boostIconLabel.Position = UDim2.new(0, 0, 0, 10)
boostIconLabel.BackgroundTransparency = 1
boostIconLabel.Text = "⚡"
boostIconLabel.Font = Enum.Font.GothamBold
boostIconLabel.TextSize = 46
boostIconLabel.TextColor3 = COLOR_TEXT
boostIconLabel.TextXAlignment = Enum.TextXAlignment.Center
boostIconLabel.Parent = boostCard

local boostNameLabel = Instance.new("TextLabel")
boostNameLabel.Size = UDim2.new(1, -16, 0, 24)
boostNameLabel.Position = UDim2.new(0, 8, 0, 84)
boostNameLabel.BackgroundTransparency = 1
boostNameLabel.Text = "Speed Boost"
boostNameLabel.Font = Enum.Font.GothamBold
boostNameLabel.TextSize = 16
boostNameLabel.TextColor3 = COLOR_TEXT
boostNameLabel.TextXAlignment = Enum.TextXAlignment.Center
boostNameLabel.Parent = boostCard

local boostDescLabel = Instance.new("TextLabel")
boostDescLabel.Size = UDim2.new(1, -16, 0, 38)
boostDescLabel.Position = UDim2.new(0, 8, 0, 112)
boostDescLabel.BackgroundTransparency = 1
boostDescLabel.Text = "Permanent top speed increase for your vehicle"
boostDescLabel.Font = Enum.Font.Gotham
boostDescLabel.TextSize = 12
boostDescLabel.TextColor3 = COLOR_SUBTEXT
boostDescLabel.TextWrapped = true
boostDescLabel.TextXAlignment = Enum.TextXAlignment.Center
boostDescLabel.Parent = boostCard

-- Cyan price button at the bottom; becomes greyed out once the player owns the boost
boostBuyBtn = Instance.new("TextButton")
boostBuyBtn.Name = "BuyBoostBtn"
boostBuyBtn.Size = UDim2.new(1, -24, 0, 36)
boostBuyBtn.Position = UDim2.new(0, 12, 1, -48)
boostBuyBtn.BackgroundColor3 = Color3.fromRGB(74, 240, 255)
boostBuyBtn.BorderSizePixel = 0
boostBuyBtn.Text = SPEED_BOOST_PRICE .. " R$"
boostBuyBtn.Font = Enum.Font.GothamBold
boostBuyBtn.TextSize = 14
boostBuyBtn.TextColor3 = COLOR_BG
boostBuyBtn.AutoButtonColor = false
boostBuyBtn.Parent = boostCard

local boostBuyCorner = Instance.new("UICorner")
boostBuyCorner.CornerRadius = UDim.new(0, 8)
boostBuyCorner.Parent = boostBuyBtn

boostBuyBtn.MouseButton1Click:Connect(function()
	if boostOwned then return end
	if SPEED_BOOST_PRODUCT_ID ~= 0 then
		MarketplaceService:PromptProductPurchase(player, SPEED_BOOST_PRODUCT_ID)
	else
		warn("Speed Boost ProductId not set yet")
	end
end)

-- ── Bundle tab content ─────────────────────────────────────────────────────────
-- Shows the Ultimate Bundle – a single highlighted card with gold border and
-- "BEST VALUE" badge, larger than regular cards.
local bundleContent = Instance.new("Frame")
bundleContent.Name = "BundleContent"
bundleContent.Size = UDim2.new(1, 0, 1, 0)
bundleContent.BackgroundTransparency = 1
bundleContent.Visible = false
bundleContent.Parent = contentArea

-- Ultimate Bundle card: gold border, larger than other cards
local bundleCard = Instance.new("Frame")
bundleCard.Name = "UltimateBundleCard"
bundleCard.Size = UDim2.new(0, 260, 0, 226)
bundleCard.Position = UDim2.new(0.5, -130, 0.5, -113)
bundleCard.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
bundleCard.BorderSizePixel = 0
bundleCard.Parent = bundleContent

local bundleCardCorner = Instance.new("UICorner")
bundleCardCorner.CornerRadius = UDim.new(0, 12)
bundleCardCorner.Parent = bundleCard

-- Gold border to highlight Best Value status
local bundleCardStroke = Instance.new("UIStroke")
bundleCardStroke.Color = Color3.fromRGB(255, 200, 0)
bundleCardStroke.Thickness = 2.5
bundleCardStroke.Parent = bundleCard

-- "BEST VALUE" badge centered above the top edge of the card
local bestValueBadge = Instance.new("Frame")
bestValueBadge.Name = "BestValueBadge"
bestValueBadge.Size = UDim2.new(0, 110, 0, 22)
bestValueBadge.Position = UDim2.new(0.5, -55, 0, -11)
bestValueBadge.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
bestValueBadge.BorderSizePixel = 0
bestValueBadge.Parent = bundleCard

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 6)
badgeCorner.Parent = bestValueBadge

local badgeLabel = Instance.new("TextLabel")
badgeLabel.Size = UDim2.new(1, 0, 1, 0)
badgeLabel.BackgroundTransparency = 1
badgeLabel.Text = "★  BEST VALUE"
badgeLabel.Font = Enum.Font.GothamBold
badgeLabel.TextSize = 11
badgeLabel.TextColor3 = Color3.fromRGB(20, 20, 25)
badgeLabel.TextXAlignment = Enum.TextXAlignment.Center
badgeLabel.Parent = bestValueBadge

local bundleIconLabel = Instance.new("TextLabel")
bundleIconLabel.Size = UDim2.new(1, 0, 0, 60)
bundleIconLabel.Position = UDim2.new(0, 0, 0, 18)
bundleIconLabel.BackgroundTransparency = 1
bundleIconLabel.Text = "💎"
bundleIconLabel.Font = Enum.Font.GothamBold
bundleIconLabel.TextSize = 40
bundleIconLabel.TextColor3 = COLOR_TEXT
bundleIconLabel.TextXAlignment = Enum.TextXAlignment.Center
bundleIconLabel.Parent = bundleCard

local bundleNameLabel = Instance.new("TextLabel")
bundleNameLabel.Size = UDim2.new(1, -16, 0, 24)
bundleNameLabel.Position = UDim2.new(0, 8, 0, 84)
bundleNameLabel.BackgroundTransparency = 1
bundleNameLabel.Text = "Ultimate Bundle"
bundleNameLabel.Font = Enum.Font.GothamBold
bundleNameLabel.TextSize = 17
bundleNameLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
bundleNameLabel.TextXAlignment = Enum.TextXAlignment.Center
bundleNameLabel.Parent = bundleCard

local bundleDescLabel = Instance.new("TextLabel")
bundleDescLabel.Size = UDim2.new(1, -16, 0, 40)
bundleDescLabel.Position = UDim2.new(0, 8, 0, 112)
bundleDescLabel.BackgroundTransparency = 1
bundleDescLabel.Text = "Unlock ALL vehicles and ALL paint jobs forever. Best value."
bundleDescLabel.Font = Enum.Font.Gotham
bundleDescLabel.TextSize = 12
bundleDescLabel.TextColor3 = COLOR_SUBTEXT
bundleDescLabel.TextWrapped = true
bundleDescLabel.TextXAlignment = Enum.TextXAlignment.Center
bundleDescLabel.Parent = bundleCard

-- Gold price button matching the card's accent colour
local bundleBuyBtn = Instance.new("TextButton")
bundleBuyBtn.Name = "BuyBundleBtn"
bundleBuyBtn.Size = UDim2.new(1, -24, 0, 36)
bundleBuyBtn.Position = UDim2.new(0, 12, 1, -48)
bundleBuyBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
bundleBuyBtn.BorderSizePixel = 0
bundleBuyBtn.Text = BUNDLE_PRICE .. " R$"
bundleBuyBtn.Font = Enum.Font.GothamBold
bundleBuyBtn.TextSize = 14
bundleBuyBtn.TextColor3 = Color3.fromRGB(20, 20, 25)
bundleBuyBtn.AutoButtonColor = false
bundleBuyBtn.Parent = bundleCard

local bundleBuyCorner = Instance.new("UICorner")
bundleBuyCorner.CornerRadius = UDim.new(0, 8)
bundleBuyCorner.Parent = bundleBuyBtn

bundleBuyBtn.MouseButton1Click:Connect(function()
	if BUNDLE_PRODUCT_ID ~= 0 then
		MarketplaceService:PromptProductPurchase(player, BUNDLE_PRODUCT_ID)
	else
		warn("Bundle ProductId not set yet")
	end
end)

-- ── Maps tab content ───────────────────────────────────────────────────────────
-- Shows only maps where Type == "Robux". Free maps are skipped because they are
-- always available without purchase.
local mapsContent = Instance.new("Frame")
mapsContent.Name = "MapsContent"
mapsContent.Size = UDim2.new(1, 0, 1, 0)
mapsContent.BackgroundTransparency = 1
mapsContent.Visible = false
mapsContent.Parent = contentArea

-- Horizontal layout: centres the cards in the content area
local mapsLayout = Instance.new("UIListLayout")
mapsLayout.FillDirection = Enum.FillDirection.Horizontal
mapsLayout.SortOrder = Enum.SortOrder.LayoutOrder
mapsLayout.Padding = UDim.new(0, 12)
mapsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mapsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
mapsLayout.Parent = mapsContent

-- Build one card per Robux map
for idx, map in ipairs(MapData) do
	if map.Type ~= "Robux" then continue end

	-- ── Card container ────────────────────────────────────────────────────────
	local card = Instance.new("Frame")
	card.Name = map.Name
	card.Size = UDim2.new(0, 200, 0, 240)
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	card.BorderSizePixel = 0
	card.LayoutOrder = idx
	card.Parent = mapsContent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 12)
	cardCorner.Parent = card

	-- Cyan border consistent with the maps accent colour
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Color3.fromRGB(74, 240, 255)
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	-- ── Thumbnail image ────────────────────────────────────────────────────────
	local thumbnail = Instance.new("ImageLabel")
	thumbnail.Size = UDim2.new(1, 0, 0, 100)
	thumbnail.Position = UDim2.new(0, 0, 0, 0)
	thumbnail.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	thumbnail.BorderSizePixel = 0
	thumbnail.Image = map.Pic
	thumbnail.ScaleType = Enum.ScaleType.Crop
	thumbnail.Parent = card

	local thumbCorner = Instance.new("UICorner")
	thumbCorner.CornerRadius = UDim.new(0, 12)
	thumbCorner.Parent = thumbnail

	-- Square off the bottom edge of the thumbnail so it butts up to the card body
	local thumbPatch = Instance.new("Frame")
	thumbPatch.Size = UDim2.new(1, 0, 0, 12)
	thumbPatch.Position = UDim2.new(0, 0, 1, -12)
	thumbPatch.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	thumbPatch.BorderSizePixel = 0
	thumbPatch.Parent = thumbnail

	-- ── Map name ──────────────────────────────────────────────────────────────
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -16, 0, 20)
	nameLabel.Position = UDim2.new(0, 8, 0, 106)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = map.Name
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- ── Description (grey, small, wraps if needed) ────────────────────────────
	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -16, 0, 34)
	descLabel.Position = UDim2.new(0, 8, 0, 130)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = map.Description
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 11
	descLabel.TextColor3 = Color3.fromRGB(160, 160, 200)
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.Parent = card

	-- ── Best time target in accent cyan ──────────────────────────────────────
	local bestTimeLabel = Instance.new("TextLabel")
	bestTimeLabel.Size = UDim2.new(1, -16, 0, 16)
	bestTimeLabel.Position = UDim2.new(0, 8, 0, 168)
	bestTimeLabel.BackgroundTransparency = 1
	bestTimeLabel.Text = "Best Time Target: " .. map.BestTimeTarget .. "s"
	bestTimeLabel.Font = Enum.Font.Gotham
	bestTimeLabel.TextSize = 11
	bestTimeLabel.TextColor3 = Color3.fromRGB(74, 240, 255)
	bestTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
	bestTimeLabel.Parent = card

	-- ── Price / Owned button ──────────────────────────────────────────────────
	local mapBuyBtn = Instance.new("TextButton")
	mapBuyBtn.Name = "BuyMapBtn"
	mapBuyBtn.Size = UDim2.new(1, -24, 0, 32)
	mapBuyBtn.Position = UDim2.new(0, 12, 1, -44)
	mapBuyBtn.BorderSizePixel = 0
	mapBuyBtn.Font = Enum.Font.GothamBold
	mapBuyBtn.TextSize = 14
	mapBuyBtn.AutoButtonColor = false
	mapBuyBtn.Parent = card

	local mapBuyCorner = Instance.new("UICorner")
	mapBuyCorner.CornerRadius = UDim.new(0, 8)
	mapBuyCorner.Parent = mapBuyBtn

	-- Store the button reference so MapPurchased can update it
	mapBuyBtns[map.Name] = mapBuyBtn

	if ownedMaps[map.Name] then
		-- Already owned this session – show greyed-out Owned state
		mapBuyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		mapBuyBtn.TextColor3       = Color3.fromRGB(140, 140, 140)
		mapBuyBtn.Text             = "✅ Owned"
		mapBuyBtn.Active           = false
	else
		-- Not yet owned – show price and wire up purchase
		mapBuyBtn.BackgroundColor3 = Color3.fromRGB(74, 240, 255)
		mapBuyBtn.TextColor3       = Color3.fromRGB(15, 15, 20)
		mapBuyBtn.Text             = map.Price .. " R$"

		-- Capture loop variable for the closure
		local capturedMap = map
		mapBuyBtn.MouseButton1Click:Connect(function()
			if ownedMaps[capturedMap.Name] then return end
			if capturedMap.ProductId ~= 0 then
				MarketplaceService:PromptProductPurchase(player, capturedMap.ProductId)
			else
				warn("Map ProductId not set for: " .. capturedMap.Name)
			end
		end)
	end
end

-- ── Tab switching ──────────────────────────────────────────────────────────────
local function switchTab(active)
	paintContent.Visible    = (active == "Paint")
	upgradesContent.Visible = (active == "Upgrades")
	bundleContent.Visible   = (active == "Bundle")
	mapsContent.Visible     = (active == "Maps")

	paintTab.BackgroundColor3    = (active == "Paint")    and COLOR_TAB_ACTIVE or COLOR_TAB_IDLE
	paintTab.TextColor3          = (active == "Paint")    and COLOR_BG         or COLOR_TEXT
	upgradesTab.BackgroundColor3 = (active == "Upgrades") and COLOR_TAB_ACTIVE or COLOR_TAB_IDLE
	upgradesTab.TextColor3       = (active == "Upgrades") and COLOR_BG         or COLOR_TEXT
	bundleTab.BackgroundColor3   = (active == "Bundle")   and COLOR_TAB_ACTIVE or COLOR_TAB_IDLE
	bundleTab.TextColor3         = (active == "Bundle")   and COLOR_BG         or COLOR_TEXT
	mapsTab.BackgroundColor3     = (active == "Maps")     and COLOR_TAB_ACTIVE or COLOR_TAB_IDLE
	mapsTab.TextColor3           = (active == "Maps")     and COLOR_BG         or COLOR_TEXT
end

switchTab("Paint")

paintTab.MouseButton1Click:Connect(function()
	switchTab("Paint")
end)

upgradesTab.MouseButton1Click:Connect(function()
	switchTab("Upgrades")
end)

bundleTab.MouseButton1Click:Connect(function()
	switchTab("Bundle")
end)

mapsTab.MouseButton1Click:Connect(function()
	switchTab("Maps")
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

-- shopToggleBtn replaced by GameHUD; hover/click wiring removed
addHover(closeBtn, COLOR_CLOSE, COLOR_CLOSE_HOVER)

closeBtn.MouseButton1Click:Connect(function()
frame.Visible = false
end)

-- ── ApplyBoost: mark boost as owned and grey out the buy button ────────────────
applyBoost.OnClientEvent:Connect(function()
	boostOwned = true
	if boostBuyBtn then
		boostBuyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		boostBuyBtn.TextColor3       = Color3.fromRGB(140, 140, 140)
		boostBuyBtn.Text             = "Owned"
	end
end)

-- ── MapPurchased: mark map as owned and show a notification above the shop ─────
mapPurchased.OnClientEvent:Connect(function(mapName)
	-- Record ownership so the button stays greyed if the shop is reopened
	ownedMaps[mapName] = true

	-- Update the corresponding buy button to show the Owned state
	local btn = mapBuyBtns[mapName]
	if btn then
		btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		btn.TextColor3       = Color3.fromRGB(140, 140, 140)
		btn.Text             = "✅ Owned"
		btn.Active           = false
	end

	-- Show notification above the shop frame, then fade it out after 3 seconds
	mapNotifLabel.Text = "🗺️ " .. mapName .. " Unlocked!"
	mapNotifLabel.TextTransparency      = 1
	mapNotifLabel.BackgroundTransparency = 1
	notifStroke.Transparency             = 1

	-- Fade in
	TweenService:Create(mapNotifLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		TextTransparency      = 0,
		BackgroundTransparency = 0.1,
	}):Play()
	TweenService:Create(notifStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Transparency = 0.4,
	}):Play()

	-- Fade out after 3 seconds
	task.delay(3, function()
		TweenService:Create(mapNotifLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			TextTransparency      = 1,
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(notifStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
	end)
end)

-- ── OwnedMapsSync: initialise map button states from the player's saved data ────
-- Fires from the server each time the shop is opened, sending the list of map
-- names the player already owns so buttons correctly reflect prior purchases.
-- Also shows the shop frame so GameHUD's Shop button (which fires OpenPaintShop
-- to the server) causes this panel to open.
ownedMapsSync.OnClientEvent:Connect(function(ownedList)
	frame.Visible = true
	for _, mapName in ipairs(ownedList) do
		ownedMaps[mapName] = true
		local btn = mapBuyBtns[mapName]
		if btn then
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			btn.TextColor3       = Color3.fromRGB(140, 140, 140)
			btn.Text             = "✅ Owned"
			btn.Active           = false
		end
	end
end)
