-- MainMenu.client.lua
-- Main menu shown on game launch before the player enters gameplay.
-- Camera orbits the Cybertruck; three buttons live in the bottom-left corner.
-- Character is already spawned (CharacterAutoLoads = true) but movement is
-- disabled until the player clicks Play.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player        = Players.LocalPlayer
local playerGui     = player:WaitForChild("PlayerGui")
local camera        = Workspace.CurrentCamera
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local openPaintShop = remotesFolder and remotesFolder:WaitForChild("OpenPaintShop", 10)
local equipVehicleEvent = remotesFolder and remotesFolder:FindFirstChild("EquipVehicle")

if not openPaintShop then
	warn("MainMenu: OpenPaintShop RemoteEvent not found")
end
if not remotesFolder then
	warn("MainMenu: Remotes folder not found in ReplicatedStorage")
end
if not equipVehicleEvent then
	warn("MainMenu: EquipVehicle RemoteEvent not found")
end

-- ── Respawn guard ─────────────────────────────────────────────────────────────
-- If the player already clicked Play (HasPlayed attribute is set), the script
-- re-ran because the character died and respawned during the race.  Re-enable
-- movement and bail out so the main menu does NOT reappear.
if player:GetAttribute("HasPlayed") then
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed  = DEFAULT_WALK_SPEED
			humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
			humanoid.JumpPower  = DEFAULT_JUMP_POWER
		end
	end
	return
end

-- ── Camera: Scriptable mode ───────────────────────────────────────────────────
-- Take full control of the camera so the orbit runs right away.
camera.CameraType = Enum.CameraType.Scriptable

-- ── Locate the Cybertruck and camera anchor (placed in Workspace by Studio) ──
local cybertruck = Workspace:WaitForChild("Tesla Cybertruck", 15)
local anchor     = Workspace:WaitForChild("MenuCameraAnchor", 15)

if not cybertruck then
	warn("MainMenu: Tesla Cybertruck not found — skipping orbit")
	camera.CameraType = Enum.CameraType.Custom
end
if not anchor then
	warn("MainMenu: MenuCameraAnchor not found — skipping orbit")
end

-- Use the anchor part's CFrame as the fixed starting reference for the orbit.
-- Storing this follows the Roblox Dev Forum pattern; it documents the initial
-- camera anchor orientation and can be used to reset the orbit start angle.
local DefaultCFrame = anchor and anchor.CFrame  -- luacheck: ignore

local truckCenter = Vector3.new(0, 5, 0)  -- safe fallback for character placement
if cybertruck then
	local truckCFrame, _ = cybertruck:GetBoundingBox()
	truckCenter = truckCFrame.Position
end

-- ── Orbit parameters ─────────────────────────────────────────────────────────
local ORBIT_RADIUS = 30    -- distance from truck
local ORBIT_HEIGHT = 10    -- height above truck center
local ORBIT_SPEED  = 0.25  -- radians per second, slow cinematic pan
local orbitAngle   = 0

-- ── Get the truck's current center each frame (accounts for dynamic bounding box) ──
local function getTruckCenter()
	local cf, size = cybertruck:GetBoundingBox()
	-- Offset upward by 30 % of the bounding-box height so the camera looks at
	-- the upper body of the truck rather than its geometric center (which sits
	-- near ground level due to the wheels/chassis).
	return cf.Position + Vector3.new(0, size.Y * 0.3, 0)
end

-- ── Character movement defaults ───────────────────────────────────────────────
local DEFAULT_WALK_SPEED  = 16
local DEFAULT_JUMP_HEIGHT = 7.2
local DEFAULT_JUMP_POWER  = 50

-- ── Character spawn offset (beside the Cybertruck, facing it) ─────────────────
local CHARACTER_SPAWN_OFFSET = Vector3.new(10, 3, 0)

-- ── Disable character movement while the menu is open ────────────────────────
local charAddedConn  -- forward declaration so the play button can disconnect it

local function disableMovement(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed  = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower  = 0
	end
	-- Position the character beside the Cybertruck so it appears in the scene.
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(truckCenter + CHARACTER_SPAWN_OFFSET, truckCenter)
	end
end

-- Handle character that is already loaded when this script runs.
if player.Character then
	disableMovement(player.Character)
end
-- Also handle late-spawning characters (rare, but defensive).
charAddedConn = player.CharacterAdded:Connect(function(character)
	task.wait()  -- let the humanoid initialize
	disableMovement(character)
end)

-- ── Music ─────────────────────────────────────────────────────────────────────
local bgMusic = Instance.new("Sound")
bgMusic.Name    = "MainMenuBGM"
bgMusic.SoundId = "rbxassetid://1837849285"
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
local titleShadow = Instance.new("TextLabel")
titleShadow.Name                 = "TitleShadow"
titleShadow.Size                 = UDim2.new(0.8, 0, 0, 80)
titleShadow.AnchorPoint          = Vector2.new(0.5, 0)
titleShadow.Position             = UDim2.new(0.5, 2, 0, 34)
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

local BTN_HEIGHT  = 52
local BTN_GAP     = 13
local BTN_MARGIN  = 38

local SETTINGS_BOTTOM = -(BTN_MARGIN + BTN_HEIGHT)
local SHOP_BOTTOM     = SETTINGS_BOTTOM - BTN_HEIGHT - BTN_GAP
local PLAY_BOTTOM     = SHOP_BOTTOM     - BTN_HEIGHT - BTN_GAP

local playBtn     = makeButton("Play",     PLAY_BOTTOM)
local shopBtn     = makeButton("Shop",     SHOP_BOTTOM)
local settingsBtn = makeButton("Settings", SETTINGS_BOTTOM)

-- ── Orbiting camera (RenderStepped) ──────────────────────────────────────────
-- Only start the orbit if both the truck and anchor were found.
local orbitConn
if cybertruck and anchor then
	orbitConn = RunService.RenderStepped:Connect(function(dt)
		if not cybertruck or not cybertruck.Parent then
			-- Truck was removed from Workspace; stop the orbit cleanly.
			if orbitConn then
				orbitConn:Disconnect()
				orbitConn = nil
			end
			return
		end

		orbitAngle = orbitAngle + ORBIT_SPEED * dt

		local center = getTruckCenter()

		-- Calculate camera position orbiting around truck center.
		local camX = center.X + math.cos(orbitAngle) * ORBIT_RADIUS
		local camZ = center.Z + math.sin(orbitAngle) * ORBIT_RADIUS
		local camY = center.Y + ORBIT_HEIGHT

		local camPos = Vector3.new(camX, camY, camZ)

		-- Always look at the truck center (anchor to a fixed look-at point).
		camera.CFrame = CFrame.lookAt(camPos, center)
	end)
end

-- ── Play button ───────────────────────────────────────────────────────────────
playBtn.MouseButton1Click:Connect(function()
	-- Prevent double-firing.
	playBtn.Active = false

	-- Stop camera orbit and return control to Roblox's default rig.
	if orbitConn then
		orbitConn:Disconnect()
		orbitConn = nil
	end

	-- Stop listening for new characters (menu is closing).
	if charAddedConn then
		charAddedConn:Disconnect()
		charAddedConn = nil
	end

	-- Mark that the player has progressed past the menu so respawns don't
	-- bring the menu back.
	player:SetAttribute("HasPlayed", true)

	-- Fade music out over 1 second.
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

	-- Fade screen to black over 1 second.
	overlay.BackgroundTransparency = 1
	local fadeTween = TweenService:Create(
		overlay,
		TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
		{ BackgroundTransparency = 0 }
	)
	fadeTween:Play()

	fadeTween.Completed:Connect(function()
		-- Hand camera back to Roblox's default follow-cam.
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubjectDistance = 12

		-- Re-enable character movement now that the player is in-game.
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed  = DEFAULT_WALK_SPEED
				humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
				humanoid.JumpPower  = DEFAULT_JUMP_POWER
			end
		end

		-- Equip the default vehicle (Cybertruck) via the server.
		task.delay(0.3, function()
			if equipVehicleEvent then
				equipVehicleEvent:FireServer(1)  -- 1 == Cybertruck
			end
		end)

		-- Remove the menu entirely.
		screenGui:Destroy()
	end)
end)

-- ── Shop button ───────────────────────────────────────────────────────────────
shopBtn.MouseButton1Click:Connect(function()
	if openPaintShop then
		openPaintShop:FireServer()
	else
		warn("MainMenu: cannot open shop, OpenPaintShop missing")
	end
end)

-- ── Settings button (placeholder) ────────────────────────────────────────────
settingsBtn.MouseButton1Click:Connect(function()
	print("Open Settings")
end)
