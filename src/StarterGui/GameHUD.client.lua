-- GameHUD.client.lua
-- Main gameplay navigation buttons shown during play.
-- Hidden until the server fires GameStarted.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remotes ───────────────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local gameStarted   = remotesFolder:WaitForChild("GameStarted")
local openPaintShop = remotesFolder:WaitForChild("OpenPaintShop")
local openGarage    = remotesFolder:WaitForChild("OpenGarage")

-- ── Theme ─────────────────────────────────────────────────────────────────────
local COLOR_BG     = Color3.fromRGB(20, 20, 25)
local COLOR_ACCENT = Color3.fromRGB(74, 240, 255)
local COLOR_TEXT   = Color3.new(1, 1, 1)

local BTN_W, BTN_H, BTN_GAP = 140, 44, 8

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "GameHUD"
screenGui.ResetOnSpawn   = false
screenGui.Enabled        = false
screenGui.Parent         = playerGui

-- ── Button container ─────────────────────────────────────────────────────────
local container = Instance.new("Frame")
container.Name                 = "NavButtons"
container.Size                 = UDim2.new(0, BTN_W, 0, BTN_H * 3 + BTN_GAP * 2)
container.AnchorPoint          = Vector2.new(0, 0.5)
container.Position             = UDim2.new(-0.2, 0, 0.5, 0) -- off-screen left initially
container.BackgroundTransparency = 1
container.Parent               = screenGui

-- ── Helper: create a styled nav button ───────────────────────────────────────
local function createNavButton(label, yOffset)
	local btn = Instance.new("TextButton")
	btn.Name                  = label
	btn.Size                  = UDim2.new(0, BTN_W, 0, BTN_H)
	btn.Position              = UDim2.new(0, 0, 0, yOffset)
	btn.BackgroundColor3      = COLOR_BG
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel       = 0
	btn.Text                  = label
	btn.Font                  = Enum.Font.GothamBold
	btn.TextSize              = 15
	btn.TextColor3            = COLOR_TEXT
	btn.AutoButtonColor       = false
	btn.Parent                = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLOR_ACCENT
	stroke.Thickness = 1.5
	stroke.Parent    = btn

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
			BackgroundTransparency = 0.15,
		}):Play()
	end)

	return btn
end

-- ── Create three nav buttons ──────────────────────────────────────────────────
local shopBtn   = createNavButton("🛒  Shop",   0)
local garageBtn = createNavButton("🚗  Garage", BTN_H + BTN_GAP)
local mapBtn    = createNavButton("🗺️  Map",    (BTN_H + BTN_GAP) * 2)

-- ── Map "coming soon" notification ───────────────────────────────────────────
-- Parented to mapBtn so it always stays above the Map button.
local mapNotif = Instance.new("TextLabel")
mapNotif.Name                  = "MapComingSoonNotif"
mapNotif.Size                  = UDim2.new(0, 220, 0, 36)
mapNotif.AnchorPoint           = Vector2.new(0, 1)
mapNotif.Position              = UDim2.new(0, 0, 0, -6)   -- 6 px above button top
mapNotif.BackgroundColor3      = Color3.fromRGB(15, 15, 20)
mapNotif.BackgroundTransparency = 1
mapNotif.BorderSizePixel       = 0
mapNotif.Text                  = "🗺️ More maps coming soon!"
mapNotif.Font                  = Enum.Font.GothamBold
mapNotif.TextSize              = 14
mapNotif.TextColor3            = COLOR_TEXT
mapNotif.TextXAlignment        = Enum.TextXAlignment.Left
mapNotif.TextTransparency      = 1
mapNotif.Parent                = mapBtn

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 6)
notifCorner.Parent = mapNotif

-- ── Button click handlers ─────────────────────────────────────────────────────

-- Shop: ask the server to open the paint shop (server fires ownedMapsSync back,
-- which PaintShopButton.client.lua catches to show the shop panel).
shopBtn.MouseButton1Click:Connect(function()
	openPaintShop:FireServer()
end)

-- Garage: ask server to open the garage UI (server echoes OpenGarage:FireClient).
garageBtn.MouseButton1Click:Connect(function()
	openGarage:FireServer()
end)

-- Map: show a brief "coming soon" popup instead of opening a menu.
local notifActive = false
mapBtn.MouseButton1Click:Connect(function()
	if notifActive then return end
	notifActive = true

	-- Fade in
	TweenService:Create(mapNotif, TweenInfo.new(0.2), {
		TextTransparency      = 0,
		BackgroundTransparency = 0.2,
	}):Play()

	task.wait(2)

	-- Fade out
	local fadeOut = TweenService:Create(mapNotif, TweenInfo.new(0.5), {
		TextTransparency      = 1,
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		notifActive = false
	end)
end)

-- ── GameStarted: reveal HUD with slide-in animation ───────────────────────────
gameStarted.OnClientEvent:Connect(function()
	screenGui.Enabled = true
	container.Position = UDim2.new(-0.2, 0, 0.5, 0)

	TweenService:Create(
		container,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 12, 0.5, 0) }
	):Play()
end)
