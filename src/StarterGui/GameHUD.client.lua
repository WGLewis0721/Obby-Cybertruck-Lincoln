--[[
    GameHUD.client.lua
    Description: Main gameplay navigation buttons (Shop, Garage, Map) shown
                 during play. Revealed when the player's character spawns.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - Remotes.OpenPaintShop (RemoteEvent)
        - Remotes.OpenGarage    (RemoteEvent)

    Events Fired:
        - Remotes.OpenPaintShop (C->S)
        - Remotes.OpenGarage    (C->S)

    Events Listened:
        - None
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remotes ───────────────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("Events", 10)
if not remotesFolder then
	warn("GameHUD: 'Events' folder not found in ReplicatedStorage")
end
	local selectMap     = remotesFolder and remotesFolder:WaitForChild("SelectMap", 10)

local openPaintShop = remotesFolder and remotesFolder:WaitForChild("OpenPaintShop", 10)
local openGarage    = remotesFolder and remotesFolder:WaitForChild("OpenGarage", 10)
local selectMap     = remotesFolder and remotesFolder:WaitForChild("SelectMap", 10)

if not openPaintShop then
	warn("GameHUD: RemoteEvent 'OpenPaintShop' not found in Events folder")
end
if not openGarage then
	warn("GameHUD: RemoteEvent 'OpenGarage' not found in Events folder")
end

-- ── Theme ─────────────────────────────────────────────────────────────────────
local COLOR_BG     = Color3.fromRGB(20, 20, 25)
local COLOR_ACCENT = Color3.fromRGB(74, 240, 255)
local COLOR_TEXT   = Color3.new(1, 1, 1)

local isTouchDevice = UserInputService.TouchEnabled
local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local compactLayout = isTouchDevice and math.min(viewport.X, viewport.Y) < 600
local BTN_W = compactLayout and 92 or (isTouchDevice and 112 or 140)
local BTN_H = compactLayout and 38 or (isTouchDevice and 40 or 44)
local BTN_GAP = compactLayout and 5 or 8

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.IgnoreGuiInset = true
screenGui.ScreenInsets    = Enum.ScreenInsets.CoreUISafeInsets
screenGui.ResetOnSpawn   = false
screenGui.Enabled        = false
screenGui.Parent         = playerGui

-- ── Button container ─────────────────────────────────────────────────────────
-- Mobile (compact): horizontal row across the top, so joystick + pedals stay
-- clear of the nav. Desktop: vertical column centered on the left edge.
local container = Instance.new("Frame")
container.Name                 = "NavButtons"
if compactLayout then
	container.Size                 = UDim2.new(0, BTN_W * 3 + BTN_GAP * 2, 0, BTN_H)
	container.AnchorPoint          = Vector2.new(0.5, 0)
	container.Position             = UDim2.new(0.5, 0, 0, 2)
else
	container.Size                 = UDim2.new(0, BTN_W, 0, BTN_H * 3 + BTN_GAP * 2)
	container.AnchorPoint          = Vector2.new(0, 0.5)
	container.Position             = UDim2.new(-0.2, 0, 0.5, 0)
end
container.BackgroundTransparency = 1
container.Parent               = screenGui

-- ── Helper: create a styled nav button ───────────────────────────────────────
local function createNavButton(label, yOffset)
	local btn = Instance.new("TextButton")
	btn.Name                  = label
	btn.Size                  = UDim2.new(0, BTN_W, 0, BTN_H)
	btn.Position              = UDim2.new(0, 0, 0, yOffset)
	btn.BackgroundColor3      = COLOR_BG
	btn.BackgroundTransparency = 0.18
	btn.BorderSizePixel       = 0
	btn.Text                  = label
	btn.Font                  = Enum.Font.GothamBold
	btn.TextSize              = 12
	btn.TextScaled             = compactLayout
	btn.TextColor3            = COLOR_TEXT
	btn.AutoButtonColor       = false
	btn.Parent                = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	-- Hover: tween to cyan tint, revert on leave
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3      = COLOR_ACCENT,
			BackgroundTransparency = 0.85,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3      = COLOR_BG,
			BackgroundTransparency = 0.18,
		}):Play()
	end)

	return btn
end

-- ── Create three nav buttons ──────────────────────────────────────────────────
local shopBtn, garageBtn, mapBtn
if compactLayout then
	shopBtn   = createNavButton("SHOP",   0)
	garageBtn = createNavButton("GARAGE", 0)
	mapBtn    = createNavButton("MAP",    0)
	shopBtn.Position   = UDim2.new(0, 0, 0, 0)
	garageBtn.Position = UDim2.new(0, BTN_W + BTN_GAP, 0, 0)
	mapBtn.Position    = UDim2.new(0, (BTN_W + BTN_GAP) * 2, 0, 0)
else
	shopBtn   = createNavButton("SHOP",   0)
	garageBtn = createNavButton("GARAGE", BTN_H + BTN_GAP)
	mapBtn    = createNavButton("MAP",    (BTN_H + BTN_GAP) * 2)
end

-- ── Map selector ──────────────────────────────────────────────────────────────
local mapNotif = Instance.new("TextLabel")
mapNotif.Name                  = "MapComingSoonNotif"
mapNotif.Size                  = UDim2.new(0, 220, 0, 36)
mapNotif.AnchorPoint           = Vector2.new(0, 1)
mapNotif.Position              = UDim2.new(0, 0, 0, -6)   -- 6 px above button top
mapNotif.BackgroundColor3      = Color3.fromRGB(15, 15, 20)
mapNotif.BackgroundTransparency = 1
mapNotif.BorderSizePixel       = 0
mapNotif.Text                  = ""
mapNotif.Font                  = Enum.Font.GothamBold
mapNotif.TextSize              = 14
mapNotif.TextColor3            = COLOR_TEXT
mapNotif.TextXAlignment        = Enum.TextXAlignment.Left
mapNotif.TextTransparency      = 1
mapNotif.Parent                = mapBtn

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 6)
notifCorner.Parent = mapNotif

local mapMenu = Instance.new("Frame")
mapMenu.Name = "MapMenu"
mapMenu.Size = UDim2.fromOffset(220, 92)
mapMenu.Position = UDim2.new(0, BTN_W + 12, 0.5, -46)
mapMenu.BackgroundColor3 = COLOR_BG
mapMenu.BackgroundTransparency = 0.08
mapMenu.BorderSizePixel = 0
mapMenu.Visible = false
mapMenu.Parent = screenGui

local mapMenuCorner = Instance.new("UICorner")
mapMenuCorner.CornerRadius = UDim.new(0, 8)
mapMenuCorner.Parent = mapMenu

local mapMenuTitle = Instance.new("TextLabel")
mapMenuTitle.Size = UDim2.new(1, 0, 0, 30)
mapMenuTitle.BackgroundTransparency = 1
mapMenuTitle.Text = "SELECT MAP"
mapMenuTitle.Font = Enum.Font.GothamBold
mapMenuTitle.TextSize = 15
mapMenuTitle.TextColor3 = COLOR_ACCENT
mapMenuTitle.Parent = mapMenu

local cityCircuitButton = Instance.new("TextButton")
cityCircuitButton.Name = "CityCircuitButton"
cityCircuitButton.Size = UDim2.new(1, -20, 0, 42)
cityCircuitButton.Position = UDim2.fromOffset(10, 38)
cityCircuitButton.BackgroundColor3 = Color3.fromRGB(35, 75, 95)
cityCircuitButton.BorderSizePixel = 0
cityCircuitButton.Text = "CITY CIRCUIT"
cityCircuitButton.Font = Enum.Font.GothamBold
cityCircuitButton.TextSize = 14
cityCircuitButton.TextColor3 = COLOR_TEXT
cityCircuitButton.Parent = mapMenu

local cityButtonCorner = Instance.new("UICorner")
cityButtonCorner.CornerRadius = UDim.new(0, 6)
cityButtonCorner.Parent = cityCircuitButton

-- ── Button click handlers ─────────────────────────────────────────────────────

-- Shop: ask the server to open the paint shop (server fires ownedMapsSync back,
-- which PaintShopButton.client.lua catches to show the shop panel).
shopBtn.MouseButton1Click:Connect(function()
	if openPaintShop then
		openPaintShop:FireServer()
		mapMenu.Visible = not mapMenu.Visible
	end
end)

-- Garage: ask server to open the garage UI (server echoes OpenGarage:FireClient).
garageBtn.MouseButton1Click:Connect(function()
	if openGarage then
		openGarage:FireServer()
	end
end)

mapBtn.MouseButton1Click:Connect(function()
	mapMenu.Visible = not mapMenu.Visible
end)

cityCircuitButton.MouseButton1Click:Connect(function()
	if selectMap then selectMap:FireServer("skyscraper") end
	mapMenu.Visible = false
end)

-- ── Reveal HUD when the character spawns ─────────────────────────────────────
local function showHUD()
	screenGui.Enabled = true
	if compactLayout then
		container.Position = UDim2.new(0.5, 0, 0, -60)
		TweenService:Create(
			container,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, 2) }
		):Play()
	else
		container.Position = UDim2.new(-0.2, 0, 0.5, 0)
		TweenService:Create(
			container,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, 12, 0.5, 0) }
		):Play()
	end
end

if player.Character then
	showHUD()
else
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- brief pause so the character fully loads before the HUD slides in
		showHUD()
	end)
end

-- Nav column stays visible while driving on mobile (top-left, out of the way
-- of the bottom-left joystick and bottom-right pedals).
