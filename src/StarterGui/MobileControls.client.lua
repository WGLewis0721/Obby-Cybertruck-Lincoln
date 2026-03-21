--[[
    MobileControls.client.lua
    Description: Bottom-right mobile drive controls – Accelerate and Boost only.

    Layout (bottom-right corner, same row):
        [ ⚡ Boost ]  [ ▲ Accel ]

    Input approach:
      • Accelerate – CAS touch button bound to KeyCode.Up so A-Chassis receives
                     the propagated UserInputService event.  RenderStepped also
                     writes VehicleSeat.Throttle each frame as a fallback.
      • Boost       – ScreenGui TextButton that fires Remotes.ApplyBoost → server.

    Sizing:
      • BTN_SIZE and PAD are computed from the viewport's shorter dimension so
        buttons are appropriately sized across phones and tablets.

    Controls are hidden until the player is seated in their vehicle (DriveSeat).

    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - ReplicatedStorage.Remotes.ApplyBoost (RemoteEvent)
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

-- ── Mobile guard ──────────────────────────────────────────────────────────────
-- KeyboardEnabled is true on mobile (Roblox enables virtual keyboard everywhere),
-- so only TouchEnabled is checked.
local isTouchDevice = UserInputService.TouchEnabled
if not isTouchDevice then return end

-- ── Player / shared modules ───────────────────────────────────────────────────
local player = Players.LocalPlayer

local Logger = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local applyBoost    = remotesFolder:WaitForChild("ApplyBoost", 10)
if not applyBoost then
	Logger.Warn("MobileControls", "ApplyBoost RemoteEvent not found")
end

-- ── Responsive sizing ─────────────────────────────────────────────────────────
-- Read the shorter viewport dimension so buttons scale with the device.
-- task.wait() yields one frame to ensure the camera has reported its size.
local camera = workspace.CurrentCamera
if camera.ViewportSize.X < 1 then task.wait() end

local _vp    = camera.ViewportSize
local _short = if _vp.X > 0 then math.min(_vp.X, _vp.Y) else 400

-- BTN_SIZE: 12 % of shorter dimension, clamped between 80 px (small phone)
-- and 120 px (large tablet).
-- PAD:      ~16 % of BTN_SIZE, clamped between 12 and 22 px.
local BTN_SIZE = math.clamp(math.round(_short * 0.12), 80, 120)
local PAD      = math.clamp(math.round(BTN_SIZE * 0.16), 12, 22)

-- ── Theme ─────────────────────────────────────────────────────────────────────
local COLOR_BG     = Color3.fromRGB(20, 20, 25)
local COLOR_ACCENT = Color3.fromRGB(74, 240, 255)
local COLOR_TEXT   = Color3.new(1, 1, 1)

-- ── Input state ───────────────────────────────────────────────────────────────
local throttleHeld = false

-- ── Runtime refs ──────────────────────────────────────────────────────────────
local isActive    = false
local currentSeat = nil
local renderConn  = nil
local accelFrame  = nil   -- CAS button frame; set after bind

-- ── ScreenGui (hosts Boost; CAS hosts Accel) ──────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MobileControls"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled        = false
screenGui.Parent         = player:WaitForChild("PlayerGui")

-- ── Helper: styled frame + TextButton ─────────────────────────────────────────
local function makeButton(name, label, position)
	local frame = Instance.new("Frame")
	frame.Name                  = name .. "_Frame"
	frame.Size                  = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
	frame.Position              = position
	frame.BackgroundColor3      = COLOR_BG
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel       = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLOR_ACCENT
	stroke.Thickness = 2
	stroke.Parent    = frame

	local btn = Instance.new("TextButton")
	btn.Name                  = name
	btn.Size                  = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                  = label
	btn.TextColor3            = COLOR_TEXT
	btn.Font                  = Enum.Font.GothamBold
	btn.TextScaled            = true
	btn.ZIndex                = 2
	btn.Parent                = frame

	-- Cap text size so it never bloats on large tablets
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 32
	cap.MinTextSize = 16
	cap.Parent      = btn

	frame.Parent = screenGui
	return frame, btn
end

-- ── Helper: pressed / released visual state ───────────────────────────────────
local function setPressed(frame, pressed)
	if pressed then
		frame.BackgroundColor3       = COLOR_ACCENT
		frame.BackgroundTransparency = 0.45
	else
		frame.BackgroundColor3       = COLOR_BG
		frame.BackgroundTransparency = 0.25
	end
end

-- ── Helper: apply cyberpunk theme to a CAS-managed button frame ───────────────
local function styleCASFrame(frame)
	if not frame then return end

	frame.BackgroundColor3       = COLOR_BG
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0

	-- Strip any default CAS decorations
	for _, child in frame:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UICorner") then
			child:Destroy()
		end
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLOR_ACCENT
	stroke.Thickness = 2
	stroke.Parent    = frame

	-- Neutralise the inner button Roblox generates
	local inner = frame:FindFirstChildWhichIsA("ImageButton")
		or frame:FindFirstChildWhichIsA("TextButton")
	if inner then
		inner.BackgroundTransparency = 1
		if inner:IsA("ImageButton") then
			inner.ImageTransparency = 1
		end
		local lbl = inner:FindFirstChildWhichIsA("TextLabel")
		if lbl then
			lbl.Font       = Enum.Font.GothamBold
			lbl.TextScaled = true
			lbl.TextColor3 = COLOR_TEXT
		else
			inner.Font       = Enum.Font.GothamBold
			inner.TextScaled = true
			inner.TextColor3 = COLOR_TEXT
		end
	end
end

-- ── Boost button (ScreenGui) ──────────────────────────────────────────────────
-- Sits immediately to the left of the Accel button.
-- Accel occupies x in [screenW - BTN_SIZE - PAD,  screenW - PAD].
-- Boost right edge = Accel left edge - PAD  →  left edge = screenW - 2*BTN_SIZE - 2*PAD
local boostFrame, boostBtn = makeButton(
	"Boost", "⚡",
	UDim2.new(1, -(2 * BTN_SIZE + 2 * PAD), 1, -(BTN_SIZE + PAD))
)

boostBtn.MouseButton1Click:Connect(function()
	setPressed(boostFrame, true)
	if applyBoost then
		applyBoost:FireServer()
	end
	task.delay(0.15, function()
		setPressed(boostFrame, false)
	end)
end)

-- ── Accelerate button (CAS) ───────────────────────────────────────────────────
-- Bottom-right corner.  Returns Pass so A-Chassis's DealWithInput receives
-- the KeyCode.Up event through UserInputService.InputBegan.
local function bindDriveControls()
	ContextActionService:BindAction(
		"MC_Throttle",
		function(_, inputState, _)
			local pressed = inputState == Enum.UserInputState.Begin
			throttleHeld = pressed
			if accelFrame then setPressed(accelFrame, pressed) end
			return Enum.ContextActionResult.Pass
		end,
		true,               -- createTouchButton
		Enum.KeyCode.Up
	)

	ContextActionService:SetTitle("MC_Throttle", "▲")
	ContextActionService:SetPosition("MC_Throttle",
		UDim2.new(1, -(BTN_SIZE + PAD), 1, -(BTN_SIZE + PAD)))

	-- CAS creates the frame asynchronously; style it on the next frame.
	task.defer(function()
		accelFrame = ContextActionService:GetButton("MC_Throttle")
		styleCASFrame(accelFrame)
		if accelFrame then
			accelFrame.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
		end
	end)
end

local function unbindDriveControls()
	ContextActionService:UnbindAction("MC_Throttle")
	accelFrame = nil
end

-- ── Reset input state ─────────────────────────────────────────────────────────
local function resetInputs()
	throttleHeld = false
	if currentSeat then
		currentSeat.Throttle = 0
		currentSeat.Steer    = 0
	end
end

-- ── RenderStepped: keep VehicleSeat.Throttle in sync ─────────────────────────
-- Fallback for A-Chassis camera / smoke / Roblox VehicleController.
local function startRenderLoop()
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.RenderStepped:Connect(function()
		if not currentSeat then return end
		currentSeat.Throttle = throttleHeld and 1 or 0
	end)
end

local function stopRenderLoop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

-- ── Show / hide controls ──────────────────────────────────────────────────────
local function showControls(driveSeat)
	currentSeat       = driveSeat
	isActive          = true
	screenGui.Enabled = true
	bindDriveControls()
	startRenderLoop()
	player:SetAttribute("IsDriving", true)
end

local function hideControls()
	isActive          = false
	screenGui.Enabled = false
	unbindDriveControls()
	resetInputs()
	stopRenderLoop()
	currentSeat = nil
	player:SetAttribute("IsDriving", false)
end

-- ── Seat detection ────────────────────────────────────────────────────────────
local function onSeated(isSeated, seat)
	if isSeated and seat and seat.Name == "DriveSeat" then
		local vehicleName = "Vehicle_" .. player.UserId
		if seat:FindFirstAncestor(vehicleName) then
			showControls(seat)
		end
	else
		if isActive then hideControls() end
	end
end

local function connectCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)

	-- Already seated edge case (e.g. respawn while in seat)
	if humanoid.SeatPart and humanoid.SeatPart.Name == "DriveSeat" then
		local vehicleName = "Vehicle_" .. player.UserId
		if humanoid.SeatPart:FindFirstAncestor(vehicleName) then
			showControls(humanoid.SeatPart)
		end
	end
end

-- ── Character lifecycle ───────────────────────────────────────────────────────
if player.Character then
	connectCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character)
	if isActive then hideControls() end
	connectCharacter(character)
end)
