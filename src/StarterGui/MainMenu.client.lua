-- MainMenu.client.lua
-- Main menu shown on game launch before the player spawns.
-- Camera orbits the Cybertruck; three buttons live in the bottom-left corner.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace  = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

-- ── Camera: Scriptable mode ───────────────────────────────────────────────────
-- Take full control of the camera immediately so the orbit starts right away.
camera.CameraType = Enum.CameraType.Scriptable

-- ── Locate the Cybertruck and find its world-space centre ─────────────────────
local cybertruck        = Workspace:WaitForChild("Tesla Cybertruck")
local truckCFrame, _    = cybertruck:GetBoundingBox()   -- CFrame (centre), Vector3 (size)
local truckCenter       = truckCFrame.Position

-- ── Orbit parameters ─────────────────────────────────────────────────────────
local ORBIT_RADIUS = 28   -- studs from the truck centre
local ORBIT_HEIGHT = 10   -- studs above the bounding-box centre Y
local ORBIT_SPEED  = 0.3  -- radians per second (slow, cinematic)

-- ── Music ─────────────────────────────────────────────────────────────────────
local bgMusic = Instance.new("Sound")
bgMusic.Name    = "MainMenuBGM"
bgMusic.SoundId = "rbxassetid://1837849285"   -- Cybertruck Obby main menu theme
bgMusic.Looped  = true
bgMusic.Volume  = 0.5
bgMusic.Parent  = Workspace
bgMusic:Play()

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MainMenu"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn   = false
screenGui.Parent         = playerGui

-- ── Fade-in overlay ───────────────────────────────────────────────────────────
-- Starts fully black, tweens to transparent over 1.5 s to reveal the scene.
local overlay = Instance.new("Frame")
overlay.Name                   = "FadeOverlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0
overlay.BorderSizePixel        = 0
overlay.ZIndex                 = 10
overlay.Parent                 = screenGui

TweenService:Create(
	overlay,
	TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	{ BackgroundTransparency = 1 }
):Play()

-- ── Game title ────────────────────────────────────────────────────────────────
-- Drop shadow: identical label offset by 2 px, drawn first at lower ZIndex.
local titleShadow = Instance.new("TextLabel")
titleShadow.Name                 = "TitleShadow"
titleShadow.Size                 = UDim2.new(0.8, 0, 0, 80)
titleShadow.AnchorPoint          = Vector2.new(0.5, 0)
titleShadow.Position             = UDim2.new(0.5, 2, 0, 34)   -- +2 px offset
titleShadow.BackgroundTransparency = 1
titleShadow.Text                 = "CYBERTRUCK OBBY"
titleShadow.Font                 = Enum.Font.GothamBold
titleShadow.TextSize             = 52
titleShadow.TextColor3           = Color3.new(0, 0, 0)
titleShadow.TextTransparency     = 0.5
titleShadow.TextXAlignment       = Enum.TextXAlignment.Center
titleShadow.ZIndex               = 2
titleShadow.Parent               = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Name                  = "Title"
titleLabel.Size                  = UDim2.new(0.8, 0, 0, 80)
titleLabel.AnchorPoint           = Vector2.new(0.5, 0)
titleLabel.Position              = UDim2.new(0.5, 0, 0, 32)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                  = "CYBERTRUCK OBBY"
titleLabel.Font                  = Enum.Font.GothamBold
titleLabel.TextSize              = 52
titleLabel.TextColor3            = Color3.new(1, 1, 1)
titleLabel.TextXAlignment        = Enum.TextXAlignment.Center
titleLabel.ZIndex                = 3
titleLabel.Parent                = screenGui

-- ── Button factory ────────────────────────────────────────────────────────────
-- Buttons are dark semi-transparent rectangles, no rounded corners.
local function makeButton(labelText, bottomOffset)
	local btn = Instance.new("TextButton")
	btn.Name                  = labelText .. "Button"
	btn.Size                  = UDim2.new(0, 220, 0, 52)
	btn.Position              = UDim2.new(0, 40, 1, bottomOffset)
	btn.BackgroundColor3      = Color3.new(0, 0, 0)
	btn.BackgroundTransparency = 0.45
	btn.BorderSizePixel       = 0
	btn.Text                  = labelText
	btn.Font                  = Enum.Font.GothamBold
	btn.TextSize              = 18
	btn.TextColor3            = Color3.new(1, 1, 1)
	btn.AutoButtonColor       = false
	btn.ZIndex                = 4
	btn.Parent                = screenGui
	return btn
end

-- Button layout constants (bottom-left corner, Y measured upward from screen bottom)
local BTN_HEIGHT  = 52   -- matches btn.Size Y above
local BTN_GAP     = 13   -- pixels between buttons
local BTN_MARGIN  = 38   -- pixels from the very bottom of the screen

-- Compute bottom offsets so buttons stack neatly upward: Settings → Shop → Play
local SETTINGS_BOTTOM = -(BTN_MARGIN + BTN_HEIGHT)
local SHOP_BOTTOM     = SETTINGS_BOTTOM - BTN_HEIGHT - BTN_GAP
local PLAY_BOTTOM     = SHOP_BOTTOM     - BTN_HEIGHT - BTN_GAP

local playBtn     = makeButton("Play",     PLAY_BOTTOM)
local shopBtn     = makeButton("Shop",     SHOP_BOTTOM)
local settingsBtn = makeButton("Settings", SETTINGS_BOTTOM)

-- ── Orbit camera loop ─────────────────────────────────────────────────────────
-- RenderStepped fires before each frame render for the smoothest motion.
local orbitAngle = 0
local orbitConn  = RunService.RenderStepped:Connect(function(dt)
	orbitAngle = orbitAngle + ORBIT_SPEED * dt

	local camX = truckCenter.X + ORBIT_RADIUS * math.cos(orbitAngle)
	local camY = truckCenter.Y + ORBIT_HEIGHT
	local camZ = truckCenter.Z + ORBIT_RADIUS * math.sin(orbitAngle)

	camera.CFrame = CFrame.lookAt(Vector3.new(camX, camY, camZ), truckCenter)
end)

-- ── Play button ───────────────────────────────────────────────────────────────
playBtn.MouseButton1Click:Connect(function()
	-- Disable to prevent double-firing.
	playBtn.Active = false

	-- Stop the camera orbit.
	orbitConn:Disconnect()

	-- Fade music volume to 0 over 1 second, then destroy the Sound.
	local musicFade = TweenService:Create(
		bgMusic,
		TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{ Volume = 0 }
	)
	musicFade:Play()
	musicFade.Completed:Connect(function()
		bgMusic:Stop()
		bgMusic:Destroy()
	end)

	-- Fade the overlay back to solid black over 1 second.
	overlay.BackgroundTransparency = 1
	local fadeTween = TweenService:Create(
		overlay,
		TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{ BackgroundTransparency = 0 }
	)
	fadeTween:Play()

	fadeTween.Completed:Connect(function()
		-- Return camera control to Roblox's default rig.
		camera.CameraType = Enum.CameraType.Custom

		-- Spawn the character into the world.
		player:LoadCharacter()

		-- Remove the menu entirely.
		screenGui:Destroy()
	end)
end)

-- ── Shop button (placeholder) ─────────────────────────────────────────────────
shopBtn.MouseButton1Click:Connect(function()
	print("Open Shop")
end)

-- ── Settings button (placeholder) ─────────────────────────────────────────────
settingsBtn.MouseButton1Click:Connect(function()
	print("Open Settings")
end)
