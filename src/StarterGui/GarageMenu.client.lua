-- GarageMenu.client.lua
-- Full-screen garage UI that lets players browse, equip, and purchase vehicles.
-- Opens when the server fires OpenGarage or the player clicks the Garage button.

local MarketplaceService = game:GetService("MarketplaceService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remote events ─────────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotesFolder then
	warn("GarageMenu: Remotes folder not found in ReplicatedStorage")
	return
end

local openGarageEvent = remotesFolder:WaitForChild("OpenGarage", 10)
if not openGarageEvent then
	warn("GarageMenu: OpenGarage RemoteEvent not found")
	return
end

local equipVehicleEvent = remotesFolder:WaitForChild("EquipVehicle", 10)
if not equipVehicleEvent then
	warn("GarageMenu: EquipVehicle RemoteEvent not found")
	return
end

local openPaintShop = remotesFolder:WaitForChild("OpenPaintShop", 10)
if not openPaintShop then
	warn("GarageMenu: OpenPaintShop RemoteEvent not found")
	return
end

local purchaseSuccess = remotesFolder:WaitForChild("PurchaseSuccess", 10)
if not purchaseSuccess then
	warn("GarageMenu: PurchaseSuccess RemoteEvent not found")
	return
end

-- ── Data modules ──────────────────────────────────────────────────────────────
local sharedFolder  = ReplicatedStorage:WaitForChild("Shared", 10)
local vehicleData   = require(sharedFolder:WaitForChild("VehicleData"))

-- ── Theme ─────────────────────────────────────────────────────────────────────
local COLOR_BG          = Color3.fromRGB(15, 15, 20)
local COLOR_PANEL       = Color3.fromRGB(22, 22, 35)
local COLOR_ACCENT      = Color3.fromRGB(74, 240, 255)
local COLOR_BTN         = Color3.fromRGB(28, 28, 48)
local COLOR_BTN_HOVER   = Color3.fromRGB(50, 200, 220)
local COLOR_TEXT        = Color3.new(1, 1, 1)
local COLOR_SUBTEXT     = Color3.fromRGB(160, 160, 200)
local COLOR_CLOSE       = Color3.fromRGB(180, 40, 40)
local COLOR_CLOSE_HOVER = Color3.fromRGB(220, 60, 60)
local COLOR_LOCKED      = Color3.fromRGB(30, 30, 40)
local COLOR_LOCKED_TEXT = Color3.fromRGB(100, 100, 120)
local COLOR_EQUIPPED    = Color3.fromRGB(74, 240, 255)
local COLOR_STAT_TRACK  = Color3.fromRGB(35, 35, 55)
local COLOR_STAT_FILL   = Color3.fromRGB(74, 240, 255)

-- ── State ─────────────────────────────────────────────────────────────────────
-- Tracks the vehicle Id the player currently has equipped (client-side mirror).
local currentEquipped = 1
-- Table of active stat-bar fill frames, keyed by stat name, for tween updates.
local statBarFills = {}

-- ── Helper: add hover tween to a button ───────────────────────────────────────
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

-- ── Helper: add UICorner to an instance ───────────────────────────────────────
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

-- ── Helper: add UIStroke to an instance ───────────────────────────────────────
local function addStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.4
	s.Parent = parent
	return s
end

-- ── Root ScreenGui ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GarageMenuGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ── Garage toggle button (always-visible HUD button) ─────────────────────────
-- Positioned below the paint shop toggle button (PaintShopButton.client.lua sits at 0.5, -22).
local garageBtn = Instance.new("TextButton")
garageBtn.Name = "GarageToggle"
garageBtn.Size = UDim2.new(0, 140, 0, 44)
garageBtn.Position = UDim2.new(0, 20, 0.5, 30)  -- below the paint shop button
garageBtn.BackgroundColor3 = COLOR_BTN
garageBtn.BorderSizePixel = 0
garageBtn.Text = "🚗  Garage"
garageBtn.Font = Enum.Font.GothamBold
garageBtn.TextSize = 15
garageBtn.TextColor3 = COLOR_TEXT
garageBtn.AutoButtonColor = false
garageBtn.Parent = screenGui
garageBtn.Visible = false -- Reveal only after player spawns

addCorner(garageBtn, 10)
addStroke(garageBtn, COLOR_ACCENT, 1.5, 0.4)
addHover(garageBtn, COLOR_BTN, COLOR_BTN_HOVER)

player.CharacterAdded:Connect(function()
	garageBtn.Visible = true
end)

local overlay    -- assigned below after ScreenGui is created
local garagePanel -- assigned below after ScreenGui is created

player.CharacterRemoving:Connect(function()
	garageBtn.Visible = false
	if overlay then
		overlay.Visible = false
	end
	if garagePanel then
		garagePanel.Visible = false
	end
end)

-- ── Full-screen overlay ───────────────────────────────────────────────────────
overlay = Instance.new("Frame")
overlay.Name = "GarageOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = COLOR_BG
overlay.BackgroundTransparency = 0.15
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Parent = screenGui

-- ── Main garage panel ─────────────────────────────────────────────────────────
garagePanel = Instance.new("Frame")
garagePanel.Name = "GaragePanel"
garagePanel.AnchorPoint = Vector2.new(0.5, 0.5)
garagePanel.Size = UDim2.new(0.88, 0, 0.88, 0)
garagePanel.Position = UDim2.new(0.5, 0, 0.5, 0)
garagePanel.BackgroundColor3 = COLOR_PANEL
garagePanel.BorderSizePixel = 0
garagePanel.Parent = overlay

addCorner(garagePanel, 16)
addStroke(garagePanel, COLOR_ACCENT, 1.5, 0.35)

-- ── Header bar ────────────────────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = COLOR_BG
header.BorderSizePixel = 0
header.Parent = garagePanel

addCorner(header, 16)
-- Square the bottom corners of the header with a patch
local headerPatch = Instance.new("Frame")
headerPatch.Size = UDim2.new(1, 0, 0, 16)
headerPatch.Position = UDim2.new(0, 0, 1, -16)
headerPatch.BackgroundColor3 = COLOR_BG
headerPatch.BorderSizePixel = 0
headerPatch.Parent = header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -120, 1, 0)
headerTitle.Position = UDim2.new(0, 18, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "⚡  Garage"
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 20
headerTitle.TextColor3 = COLOR_ACCENT
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

-- Paint button (opens existing paint shop)
local paintBtn = Instance.new("TextButton")
paintBtn.Name = "PaintBtn"
paintBtn.Size = UDim2.new(0, 90, 0, 32)
paintBtn.Position = UDim2.new(1, -138, 0, 10)
paintBtn.BackgroundColor3 = COLOR_BTN
paintBtn.BorderSizePixel = 0
paintBtn.Text = "🎨  Paint"
paintBtn.Font = Enum.Font.GothamBold
paintBtn.TextSize = 13
paintBtn.TextColor3 = COLOR_TEXT
paintBtn.AutoButtonColor = false
paintBtn.Parent = header

addCorner(paintBtn, 8)
addStroke(paintBtn, COLOR_ACCENT, 1, 0.4)
addHover(paintBtn, COLOR_BTN, COLOR_BTN_HOVER)

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -46, 0, 10)
closeBtn.BackgroundColor3 = COLOR_CLOSE
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = COLOR_TEXT
closeBtn.AutoButtonColor = false
closeBtn.Parent = header

addCorner(closeBtn, 8)
addHover(closeBtn, COLOR_CLOSE, COLOR_CLOSE_HOVER)

-- ── Content area (below header) ───────────────────────────────────────────────
local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -24, 1, -64)
contentFrame.Position = UDim2.new(0, 12, 0, 58)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = garagePanel

-- ── LEFT COLUMN — thumbnail + info + stats ────────────────────────────────────
local leftCol = Instance.new("Frame")
leftCol.Name = "LeftCol"
leftCol.Size = UDim2.new(0.38, 0, 1, 0)
leftCol.BackgroundTransparency = 1
leftCol.Parent = contentFrame

-- Vehicle thumbnail (center section)
local thumbFrame = Instance.new("Frame")
thumbFrame.Name = "ThumbFrame"
thumbFrame.Size = UDim2.new(1, 0, 0.42, 0)
thumbFrame.BackgroundColor3 = COLOR_BG
thumbFrame.BorderSizePixel = 0
thumbFrame.Parent = leftCol

addCorner(thumbFrame, 12)
addStroke(thumbFrame, COLOR_ACCENT, 1, 0.6)

local thumbImage = Instance.new("ImageLabel")
thumbImage.Name = "Thumbnail"
thumbImage.Size = UDim2.new(1, -16, 1, -16)
thumbImage.Position = UDim2.new(0, 8, 0, 8)
thumbImage.BackgroundTransparency = 1
thumbImage.Image = "rbxassetid://0"
thumbImage.ScaleType = Enum.ScaleType.Fit
thumbImage.Parent = thumbFrame

-- Fallback icon when no thumbnail is available
local thumbFallback = Instance.new("TextLabel")
thumbFallback.Name = "Fallback"
thumbFallback.Size = UDim2.new(1, 0, 1, 0)
thumbFallback.BackgroundTransparency = 1
thumbFallback.Text = "🚗"
thumbFallback.TextScaled = true
thumbFallback.Font = Enum.Font.GothamBold
thumbFallback.TextColor3 = COLOR_SUBTEXT
thumbFallback.Parent = thumbFrame

-- Vehicle name (top section)
local vehicleNameLabel = Instance.new("TextLabel")
vehicleNameLabel.Name = "VehicleName"
vehicleNameLabel.Size = UDim2.new(1, 0, 0, 32)
vehicleNameLabel.Position = UDim2.new(0, 0, 0.44, 4)
vehicleNameLabel.BackgroundTransparency = 1
vehicleNameLabel.Text = "Tesla Cybertruck"
vehicleNameLabel.Font = Enum.Font.GothamBold
vehicleNameLabel.TextSize = 22
vehicleNameLabel.TextColor3 = COLOR_TEXT
vehicleNameLabel.TextXAlignment = Enum.TextXAlignment.Center
vehicleNameLabel.Parent = leftCol

-- Vehicle description
local vehicleDescLabel = Instance.new("TextLabel")
vehicleDescLabel.Name = "VehicleDesc"
vehicleDescLabel.Size = UDim2.new(1, 0, 0, 24)
vehicleDescLabel.Position = UDim2.new(0, 0, 0.44, 40)
vehicleDescLabel.BackgroundTransparency = 1
vehicleDescLabel.Text = "Electric • All-Wheel Drive"
vehicleDescLabel.Font = Enum.Font.Gotham
vehicleDescLabel.TextSize = 13
vehicleDescLabel.TextColor3 = COLOR_SUBTEXT
vehicleDescLabel.TextXAlignment = Enum.TextXAlignment.Center
vehicleDescLabel.Parent = leftCol

-- ── Stat bars section ─────────────────────────────────────────────────────────
local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsFrame"
statsFrame.Size = UDim2.new(1, 0, 0.38, 0)
statsFrame.Position = UDim2.new(0, 0, 0.62, 0)
statsFrame.BackgroundTransparency = 1
statsFrame.Parent = leftCol

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Vertical
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, 6)
statsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
statsLayout.Parent = statsFrame

-- Helper: create a single stat row with label + animated bar
local function makeStatBar(statName, order)
	local row = Instance.new("Frame")
	row.Name = statName .. "Row"
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = statsFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 100, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = statName
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = COLOR_SUBTEXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -108, 0, 10)
	track.Position = UDim2.new(0, 104, 0.5, -5)
	track.BackgroundColor3 = COLOR_STAT_TRACK
	track.BorderSizePixel = 0
	track.Parent = row

	addCorner(track, 5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)  -- width animated to match stat value
	fill.BackgroundColor3 = COLOR_STAT_FILL
	fill.BorderSizePixel = 0
	fill.Parent = track

	addCorner(fill, 5)

	statBarFills[statName] = fill
end

makeStatBar("Speed",        1)
makeStatBar("Handling",     2)
makeStatBar("Acceleration", 3)
makeStatBar("Braking",      4)

-- ── RIGHT COLUMN — vehicle list ───────────────────────────────────────────────
local rightCol = Instance.new("Frame")
rightCol.Name = "RightCol"
rightCol.Size = UDim2.new(0.60, 0, 1, 0)
rightCol.Position = UDim2.new(0.40, 0, 0, 0)
rightCol.BackgroundTransparency = 1
rightCol.Parent = contentFrame

local listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, 0, 0, 28)
listLabel.BackgroundTransparency = 1
listLabel.Text = "SELECT VEHICLE"
listLabel.Font = Enum.Font.GothamBold
listLabel.TextSize = 13
listLabel.TextColor3 = COLOR_ACCENT
listLabel.TextXAlignment = Enum.TextXAlignment.Left
-- listLabel.LetterSpacingOffset = 2 -- This property isn’t supported for TextLabel here
listLabel.Parent = rightCol

-- Horizontal scrolling frame for vehicle cards
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "VehicleScroll"
scrollFrame.Size = UDim2.new(1, 0, 1, -36)
scrollFrame.Position = UDim2.new(0, 0, 0, 32)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)  -- auto-sized by UIListLayout below
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = COLOR_ACCENT
scrollFrame.ScrollingDirection = Enum.ScrollingDirection.X
scrollFrame.HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar
scrollFrame.Parent = rightCol

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.FillDirection = Enum.FillDirection.Horizontal
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0, 12)
scrollLayout.VerticalAlignment = Enum.VerticalAlignment.Center
scrollLayout.Parent = scrollFrame

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingLeft = UDim.new(0, 4)
scrollPadding.PaddingRight = UDim.new(0, 4)
scrollPadding.PaddingTop = UDim.new(0, 6)
scrollPadding.PaddingBottom = UDim.new(0, 6)
scrollPadding.Parent = scrollFrame

-- ── Card stroke references for equipped-highlight updates ──────────────────────
-- Maps vehicleId -> UIStroke on the card outer frame
local cardStrokes = {}

-- ── Update stat bars for the selected vehicle ──────────────────────────────────
local function updateStats(vehicle)
	local stats = vehicle.Stats or {}
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	for statName, fill in pairs(statBarFills) do
		local value = stats[statName] or 0
		local targetWidth = math.clamp(value / 100, 0, 1)
		TweenService:Create(fill, tweenInfo, {
			Size = UDim2.new(targetWidth, 0, 1, 0),
		}):Play()
	end
end

-- ── Update info panel for the selected vehicle ────────────────────────────────
local function selectVehicle(vehicle)
	vehicleNameLabel.Text = vehicle.Name
	updateStats(vehicle)

	-- Thumbnail: show image if valid, otherwise show fallback icon
	if vehicle.Thumbnail and vehicle.Thumbnail ~= "rbxassetid://0" then
		thumbImage.Image = vehicle.Thumbnail
		thumbImage.Visible = true
		thumbFallback.Visible = false
	else
		thumbImage.Visible = false
		thumbFallback.Visible = true
	end

	-- Update card highlight borders: cyan for equipped, dim for others
	for id, stroke in pairs(cardStrokes) do
		if id == currentEquipped then
			stroke.Color = COLOR_EQUIPPED
			stroke.Transparency = 0
			stroke.Thickness = 2.5
		else
			stroke.Color = COLOR_ACCENT
			stroke.Transparency = 0.7
			stroke.Thickness = 1.5
		end
	end
end

-- ── Build vehicle card ────────────────────────────────────────────────────────
-- ownedSet is a lookup table of vehicle Ids the player owns (set to true).
local function buildVehicleCards(ownedSet)
	-- Clear any previously built cards
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	cardStrokes = {}

	for idx, vehicle in ipairs(vehicleData) do
		local owned = ownedSet[vehicle.Id] == true or vehicle.Unlocked

		-- Outer card frame
		local card = Instance.new("Frame")
		card.Name = "VehicleCard_" .. vehicle.Id
		card.Size = UDim2.new(0, 150, 0.92, 0)
		card.BackgroundColor3 = owned and COLOR_BTN or COLOR_LOCKED
		card.BorderSizePixel = 0
		card.LayoutOrder = idx
		card.Parent = scrollFrame

		addCorner(card, 12)

		local stroke = addStroke(
			card,
			vehicle.Id == currentEquipped and COLOR_EQUIPPED or COLOR_ACCENT,
			vehicle.Id == currentEquipped and 2.5 or 1.5,
			vehicle.Id == currentEquipped and 0 or 0.7
		)
		cardStrokes[vehicle.Id] = stroke

		-- Thumbnail / icon inside card
		local cardThumb = Instance.new("ImageLabel")
		cardThumb.Size = UDim2.new(1, -16, 0, 80)
		cardThumb.Position = UDim2.new(0, 8, 0, 8)
		cardThumb.BackgroundTransparency = 1
		cardThumb.Image = (vehicle.Thumbnail ~= "rbxassetid://0") and vehicle.Thumbnail or ""
		cardThumb.ScaleType = Enum.ScaleType.Fit
		cardThumb.Parent = card

		if cardThumb.Image == "" then
			local fallback = Instance.new("TextLabel")
			fallback.Size = UDim2.new(1, -16, 0, 80)
			fallback.Position = UDim2.new(0, 8, 0, 8)
			fallback.BackgroundTransparency = 1
			fallback.Text = "🚗"
			fallback.TextScaled = true
			fallback.Font = Enum.Font.GothamBold
			fallback.TextColor3 = owned and COLOR_SUBTEXT or COLOR_LOCKED_TEXT
			fallback.Parent = card
		end

		-- Vehicle name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -8, 0, 20)
		nameLabel.Position = UDim2.new(0, 4, 0, 94)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = vehicle.Name
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 11
		nameLabel.TextColor3 = owned and COLOR_TEXT or COLOR_LOCKED_TEXT
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = card

		-- Equip / Buy button
		local actionBtn = Instance.new("TextButton")
		actionBtn.Name = "ActionBtn"
		actionBtn.Size = UDim2.new(1, -16, 0, 30)
		actionBtn.Position = UDim2.new(0, 8, 1, -38)
		actionBtn.BorderSizePixel = 0
		actionBtn.AutoButtonColor = false
		actionBtn.Parent = card

		if owned then
			-- Player owns this vehicle: show Equip button
			actionBtn.BackgroundColor3 = COLOR_ACCENT
			actionBtn.Text = vehicle.Id == currentEquipped and "✔ Equipped" or "Equip"
			actionBtn.Font = Enum.Font.GothamBold
			actionBtn.TextSize = 12
			actionBtn.TextColor3 = COLOR_BG
			addCorner(actionBtn, 8)
			addHover(actionBtn, COLOR_ACCENT, COLOR_BTN_HOVER)

			actionBtn.MouseButton1Click:Connect(function()
				if vehicle.Id ~= currentEquipped then
					currentEquipped = vehicle.Id
					equipVehicleEvent:FireServer(vehicle.Id)
					-- Rebuild cards to refresh button states and border highlights
					buildVehicleCards(ownedSet)
					selectVehicle(vehicle)
				end
			end)
		else
			-- Player does not own this vehicle: show Buy button with Robux price
			actionBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
			actionBtn.Text = "🛒 " .. vehicle.Price .. " R$"
			actionBtn.Font = Enum.Font.GothamBold
			actionBtn.TextSize = 12
			actionBtn.TextColor3 = COLOR_SUBTEXT
			addCorner(actionBtn, 8)
			addStroke(actionBtn, COLOR_ACCENT, 1, 0.6)

			actionBtn.MouseButton1Click:Connect(function()
				if vehicle.ProductId and vehicle.ProductId ~= 0 then
					MarketplaceService:PromptProductPurchase(player, vehicle.ProductId)
				else
					warn("GarageMenu: ProductId not set for vehicle: " .. vehicle.Name)
				end
			end)
		end

		-- Clicking the card body selects the vehicle in the info panel
		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				selectVehicle(vehicle)
			end
		end)
	end
end

-- ── Derive owned set from local player (client best-guess) ────────────────────
-- The server authoritative check is in GarageHandler; the client just reads
-- whatever owned data was sent back via PurchaseSuccess or an initial load event.
-- For now default to only the free vehicle until a proper data sync is added.
local ownedVehiclesSet = { [1] = true }  -- Id=1 (Cybertruck) is always free

-- ── Open / close helpers ──────────────────────────────────────────────────────
local function openGarage()
	-- Rebuild cards to reflect latest ownership state each time we open
	buildVehicleCards(ownedVehiclesSet)

	-- Show the first vehicle stats by default
	local defaultVehicle = vehicleData[1]
	for _, v in ipairs(vehicleData) do
		if v.Id == currentEquipped then
			defaultVehicle = v
			break
		end
	end
	selectVehicle(defaultVehicle)

	-- Animate the overlay in
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	garagePanel.Position = UDim2.new(0.5, 0, 0.55, 0)
	garagePanel.BackgroundTransparency = 1

	TweenService:Create(overlay, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15,
	}):Play()
	TweenService:Create(garagePanel, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0,
	}):Play()
end

local function closeGarage()
	local tweenOut = TweenService:Create(garagePanel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.55, 0),
		BackgroundTransparency = 1,
	})
	tweenOut:Play()
	TweenService:Create(overlay, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()

	tweenOut.Completed:Connect(function()
		overlay.Visible = false
	end)
end

-- ── Button / event wiring ─────────────────────────────────────────────────────
garageBtn.MouseButton1Click:Connect(openGarage)
closeBtn.MouseButton1Click:Connect(closeGarage)

-- Paint button opens existing paint shop UI
paintBtn.MouseButton1Click:Connect(function()
	openPaintShop:FireServer()
end)

-- Server can also open the garage remotely (e.g., from an in-world trigger)
openGarageEvent.OnClientEvent:Connect(openGarage)

-- Refresh ownership after a successful purchase
purchaseSuccess.OnClientEvent:Connect(function(vehicleId)
	if vehicleId then
		ownedVehiclesSet[vehicleId] = true
	end
	-- Rebuild if the garage is currently open
	if overlay.Visible then
		buildVehicleCards(ownedVehiclesSet)
	end
end)
