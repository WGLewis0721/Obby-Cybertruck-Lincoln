-- LoadingScreen.client.lua
-- Displays a full-screen loading/title screen before the player spawns.
-- Buttons: Play (spawns the player), Settings (volume / graphics), Shop (opens paint shop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Theme ────────────────────────────────────────────────────────────────────
local COLOR_BG           = Color3.fromRGB(8, 8, 18)
local COLOR_PANEL        = Color3.fromRGB(18, 18, 35)
local COLOR_ACCENT       = Color3.fromRGB(0, 210, 255)
local COLOR_BTN          = Color3.fromRGB(22, 22, 44)
local COLOR_BTN_HOVER    = Color3.fromRGB(0, 170, 210)
local COLOR_BTN_PLAY     = Color3.fromRGB(0, 210, 255)
local COLOR_BTN_PLAY_H   = Color3.fromRGB(0, 240, 255)
local COLOR_TEXT         = Color3.new(1, 1, 1)
local COLOR_SUBTEXT      = Color3.fromRGB(160, 160, 200)
local COLOR_CLOSE        = Color3.fromRGB(180, 40, 40)
local COLOR_CLOSE_HOVER  = Color3.fromRGB(220, 60, 60)

-- ── Root ScreenGui ────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreenGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 100        -- render on top of everything else
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- ── Full-screen background ────────────────────────────────────────────────────
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = COLOR_BG
bg.BorderSizePixel = 0
bg.Parent = screenGui

-- Subtle gradient overlay
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,  0,  30)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8,  8,  18)),
	ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,  5,  20)),
})
gradient.Rotation = 135
gradient.Parent = bg

-- ── Animated accent line (top) ────────────────────────────────────────────────
local topLine = Instance.new("Frame")
topLine.Name = "TopAccentLine"
topLine.Size = UDim2.new(0, 0, 0, 3)
topLine.Position = UDim2.new(0, 0, 0, 0)
topLine.BackgroundColor3 = COLOR_ACCENT
topLine.BorderSizePixel = 0
topLine.Parent = bg

-- ── Center panel ─────────────────────────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name = "CenterPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0, 520, 0, 420)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3 = COLOR_PANEL
panel.BorderSizePixel = 0
panel.Parent = bg

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

-- Thin accent border
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLOR_ACCENT
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.5
panelStroke.Parent = panel

-- ── Cybertruck icon (⚡) ──────────────────────────────────────────────────────
local iconLabel = Instance.new("TextLabel")
iconLabel.Name = "Icon"
iconLabel.Size = UDim2.new(0, 80, 0, 80)
iconLabel.Position = UDim2.new(0.5, -40, 0, 18)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = "⚡"
iconLabel.TextScaled = true
iconLabel.Font = Enum.Font.GothamBold
iconLabel.TextColor3 = COLOR_ACCENT
iconLabel.Parent = panel

-- ── Title ─────────────────────────────────────────────────────────────────────
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 0, 48)
title.Position = UDim2.new(0, 20, 0, 100)
title.BackgroundTransparency = 1
title.Text = "Obby but in a Cybertruck"
title.Font = Enum.Font.GothamBold
title.TextSize = 32
title.TextColor3 = COLOR_TEXT
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = panel

-- ── Subtitle ──────────────────────────────────────────────────────────────────
local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(1, -40, 0, 24)
subtitle.Position = UDim2.new(0, 20, 0, 152)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Can you survive the electric obstacle course?"
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 14
subtitle.TextColor3 = COLOR_SUBTEXT
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.Parent = panel

-- ── Helper: create a styled button ───────────────────────────────────────────
local function makeButton(name, text, yOffset, bgColor)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 260, 0, 48)
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.Position = UDim2.new(0.5, 0, 0, yOffset)
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = COLOR_TEXT
	btn.AutoButtonColor = false
	btn.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_ACCENT
	stroke.Thickness = 1
	stroke.Transparency = 0.6
	stroke.Parent = btn

	return btn
end

local playBtn     = makeButton("PlayButton",     "▶  Play",     196, COLOR_BTN_PLAY)
local settingsBtn = makeButton("SettingsButton", "⚙  Settings", 256, COLOR_BTN)
local shopBtn     = makeButton("ShopButton",     "🎨  Shop",    316, COLOR_BTN)

-- ── Version label ─────────────────────────────────────────────────────────────
local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.Size = UDim2.new(0, 200, 0, 20)
versionLabel.Position = UDim2.new(0, 10, 1, -28)
versionLabel.BackgroundTransparency = 1
versionLabel.Text = "v1.0.0"
versionLabel.Font = Enum.Font.Gotham
versionLabel.TextSize = 12
versionLabel.TextColor3 = COLOR_SUBTEXT
versionLabel.Parent = bg

-- ── Settings panel (hidden by default) ───────────────────────────────────────
local settingsPanel = Instance.new("Frame")
settingsPanel.Name = "SettingsPanel"
settingsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
settingsPanel.Size = UDim2.new(0, 400, 0, 300)
settingsPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
settingsPanel.BackgroundColor3 = COLOR_PANEL
settingsPanel.BorderSizePixel = 0
settingsPanel.Visible = false
settingsPanel.ZIndex = 5
settingsPanel.Parent = bg

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 16)
sCorner.Parent = settingsPanel

local sStroke = Instance.new("UIStroke")
sStroke.Color = COLOR_ACCENT
sStroke.Thickness = 1.5
sStroke.Transparency = 0.4
sStroke.Parent = settingsPanel

local sTitle = Instance.new("TextLabel")
sTitle.Size = UDim2.new(1, -20, 0, 40)
sTitle.Position = UDim2.new(0, 10, 0, 8)
sTitle.BackgroundTransparency = 1
sTitle.Text = "⚙  Settings"
sTitle.Font = Enum.Font.GothamBold
sTitle.TextSize = 20
sTitle.TextColor3 = COLOR_TEXT
sTitle.ZIndex = 6
sTitle.Parent = settingsPanel

-- Music toggle
local musicLabel = Instance.new("TextLabel")
musicLabel.Size = UDim2.new(0, 200, 0, 36)
musicLabel.Position = UDim2.new(0, 20, 0, 70)
musicLabel.BackgroundTransparency = 1
musicLabel.Text = "Music"
musicLabel.Font = Enum.Font.GothamBold
musicLabel.TextSize = 15
musicLabel.TextColor3 = COLOR_TEXT
musicLabel.TextXAlignment = Enum.TextXAlignment.Left
musicLabel.ZIndex = 6
musicLabel.Parent = settingsPanel

local musicToggle = Instance.new("TextButton")
musicToggle.Name = "MusicToggle"
musicToggle.Size = UDim2.new(0, 80, 0, 32)
musicToggle.Position = UDim2.new(1, -100, 0, 74)
musicToggle.BackgroundColor3 = COLOR_ACCENT
musicToggle.Text = "ON"
musicToggle.Font = Enum.Font.GothamBold
musicToggle.TextSize = 14
musicToggle.TextColor3 = COLOR_TEXT
musicToggle.AutoButtonColor = false
musicToggle.ZIndex = 6
musicToggle.Parent = settingsPanel

local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 8)
mCorner.Parent = musicToggle

-- Graphics quality
local gfxLabel = Instance.new("TextLabel")
gfxLabel.Size = UDim2.new(0, 200, 0, 36)
gfxLabel.Position = UDim2.new(0, 20, 0, 120)
gfxLabel.BackgroundTransparency = 1
gfxLabel.Text = "Graphics Quality"
gfxLabel.Font = Enum.Font.GothamBold
gfxLabel.TextSize = 15
gfxLabel.TextColor3 = COLOR_TEXT
gfxLabel.TextXAlignment = Enum.TextXAlignment.Left
gfxLabel.ZIndex = 6
gfxLabel.Parent = settingsPanel

local gfxValue = Instance.new("TextLabel")
gfxValue.Name = "GfxValue"
gfxValue.Size = UDim2.new(0, 80, 0, 32)
gfxValue.Position = UDim2.new(1, -100, 0, 124)
gfxValue.BackgroundColor3 = COLOR_BTN
gfxValue.Text = "Auto"
gfxValue.Font = Enum.Font.GothamBold
gfxValue.TextSize = 14
gfxValue.TextColor3 = COLOR_SUBTEXT
gfxValue.ZIndex = 6
gfxValue.Parent = settingsPanel

local gCorner = Instance.new("UICorner")
gCorner.CornerRadius = UDim.new(0, 8)
gCorner.Parent = gfxValue

-- Close settings button
local closeSettings = Instance.new("TextButton")
closeSettings.Name = "CloseSettings"
closeSettings.Size = UDim2.new(0, 120, 0, 36)
closeSettings.AnchorPoint = Vector2.new(0.5, 0)
closeSettings.Position = UDim2.new(0.5, 0, 1, -52)
closeSettings.BackgroundColor3 = COLOR_CLOSE
closeSettings.Text = "Close"
closeSettings.Font = Enum.Font.GothamBold
closeSettings.TextSize = 14
closeSettings.TextColor3 = COLOR_TEXT
closeSettings.AutoButtonColor = false
closeSettings.ZIndex = 6
closeSettings.Parent = settingsPanel

local csCorner = Instance.new("UICorner")
csCorner.CornerRadius = UDim.new(0, 8)
csCorner.Parent = closeSettings

-- ── Utility: button hover effect ─────────────────────────────────────────────
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

addHover(playBtn,     COLOR_BTN_PLAY,  COLOR_BTN_PLAY_H)
addHover(settingsBtn, COLOR_BTN,       COLOR_BTN_HOVER)
addHover(shopBtn,     COLOR_BTN,       COLOR_BTN_HOVER)
addHover(closeSettings, COLOR_CLOSE,   COLOR_CLOSE_HOVER)

-- ── Intro animation ───────────────────────────────────────────────────────────
-- Accent line sweeps across the top
TweenService:Create(topLine, TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
	Size = UDim2.new(1, 0, 0, 3),
}):Play()

-- Panel slides in from slightly below
panel.Position = UDim2.new(0.5, 0, 0.6, 0)
panel.BackgroundTransparency = 1
TweenService:Create(panel, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
	Position = UDim2.new(0.5, 0, 0.5, 0),
	BackgroundTransparency = 0,
}):Play()

-- ── Background music (ambient loading-screen track) ──────────────────────────
-- Roblox asset ID 1843463809 is a free ambient electronic loop.
local bgMusic = Instance.new("Sound")
bgMusic.Name = "LoadingBGM"
bgMusic.SoundId = "rbxassetid://1843463809"
bgMusic.Volume = 0.4
bgMusic.Looped = true
bgMusic.Parent = SoundService
bgMusic:Play()

-- ── Music toggle logic ────────────────────────────────────────────────────────
local musicEnabled = true
musicToggle.MouseButton1Click:Connect(function()
	musicEnabled = not musicEnabled
	if musicEnabled then
		musicToggle.Text = "ON"
		musicToggle.BackgroundColor3 = COLOR_ACCENT
		bgMusic:Resume()
	else
		musicToggle.Text = "OFF"
		musicToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		bgMusic:Pause()
	end
end)

-- ── Settings button ───────────────────────────────────────────────────────────
settingsBtn.MouseButton1Click:Connect(function()
	settingsPanel.Visible = true
	settingsPanel.Size = UDim2.new(0, 360, 0, 260)
	TweenService:Create(settingsPanel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 400, 0, 300),
	}):Play()
end)

closeSettings.MouseButton1Click:Connect(function()
	local t = TweenService:Create(settingsPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 360, 0, 260),
	})
	t:Play()
	t.Completed:Connect(function()
		settingsPanel.Visible = false
	end)
end)

-- ── Shop button ───────────────────────────────────────────────────────────────
shopBtn.MouseButton1Click:Connect(function()
	-- Fire the existing OpenPaintShop remote (wires into PaintShopButton / PaintShopHandler)
	local openPaintShop = ReplicatedStorage:FindFirstChild("OpenPaintShop")
	if openPaintShop then
		openPaintShop:FireServer()
	end

	-- Also open the ShopGui_d if it exists
	local shopGuiD = playerGui:FindFirstChild("ShopGui_d")
	if shopGuiD then
		local mainFrame = shopGuiD:FindFirstChild("Main")
		if mainFrame then
			mainFrame.Visible = true
		end
	end
end)

-- ── Play button — fade out and spawn the player ───────────────────────────────
local function onPlay()
	playBtn.Active = false

	-- Re-enable CoreGui in case it was suppressed before the loading screen
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	if not ok then
		warn("LoadingScreen: could not re-enable CoreGui:", err)
	end

	-- Fade out the whole loading screen
	local fadeTween = TweenService:Create(bg, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})

	-- Also fade the panel and its children
	local panelFade = TweenService:Create(panel, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0.4, 0),
	})
	panelFade:Play()
	fadeTween:Play()

	fadeTween.Completed:Connect(function()
		bgMusic:Stop()
		bgMusic:Destroy()
		screenGui:Destroy()

		-- Spawn the character if it hasn't been spawned yet
		if not player.Character or not player.Character.Parent then
			player:LoadCharacter()
		end
	end)
end

playBtn.MouseButton1Click:Connect(onPlay)
