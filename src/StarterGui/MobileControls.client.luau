--!strict
-- SCRIPT: MobileControls | LOCATION: StarterGui | SIDE: Client
--[[
    MobileControls.client.luau
    Description: Full mobile driving UI for A-Chassis vehicles.
                 Pure ScreenGui layout — NO ContextActionService for drive buttons.
                 CAS cannot be reliably positioned on iOS; all buttons are plain
                 TextButton frames with InputBegan/InputEnded for multi-touch.

    Layout:
        LEFT SIDE  (AnchorPoint 0,1  bottom-left, 16 px from edges)
            Row 1 (bottom):  [ ◄ SteerLeft ] [ SteerRight ► ]
            Row 2 (above):   [    ↺ Reverse   ]
            Row 3 (above):   [      Reset      ]  (smaller)

        RIGHT SIDE (AnchorPoint 1,1  bottom-right, 16 px from edges)
            Row 1 (bottom):  [ ▼ Brake ] [ ▲ Gas ]  (tall pedals)
            Row 2 (above):   [    ⚡ Boost    ]  (centered above pedals)

    Input:
        Each button frame has InputBegan / InputEnded connections so that
        gas + steer can be held simultaneously (multi-touch works correctly).
        VehicleInput fires every RunService.Heartbeat to the server.

    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - ReplicatedStorage.Events.ApplyBoost     (RemoteEvent)
        - ReplicatedStorage.Events.OpenGarage     (RemoteEvent)
        - ReplicatedStorage.Events.VehicleInput   (RemoteEvent) fires to server
        - ReplicatedStorage.Events.VehicleSpawned (RemoteEvent) shows controls
        - ReplicatedStorage.Events.MobileThrottle (RemoteEvent) server-auth throttle
        - ReplicatedStorage.Module.Logger          (ModuleScript)
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Mobile guard ──────────────────────────────────────────────────────────────
if not UserInputService.TouchEnabled then return end

-- Suppress the default Roblox joystick so it doesn't overlap our controls.
-- This must be set on the server via StarterPlayer in Studio, but we also set
-- the client attribute as documentation; the actual enforcement is in StarterPlayer.
local StarterPlayer = game:GetService("StarterPlayer")
StarterPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable

-- ── Player / shared modules ───────────────────────────────────────────────────
local player = Players.LocalPlayer

local moduleFolder   = ReplicatedStorage:WaitForChild("Module", 10) :: Folder
local Logger         = require(moduleFolder:WaitForChild("Logger", 10) :: ModuleScript)

local eventsFolder   = ReplicatedStorage:WaitForChild("Events", 10) :: Folder
local applyBoost     = eventsFolder:WaitForChild("ApplyBoost",     10) :: RemoteEvent
local openGarage     = eventsFolder:WaitForChild("OpenGarage",     10) :: RemoteEvent
local vehicleInput   = eventsFolder:WaitForChild("VehicleInput",   10) :: RemoteEvent
local vehicleSpawned = eventsFolder:WaitForChild("VehicleSpawned", 10) :: RemoteEvent
local mobileThrottle = eventsFolder:FindFirstChild("MobileThrottle") :: RemoteEvent?

if not mobileThrottle then
	Logger.Warn("MobileControls", "MobileThrottle RemoteEvent not found — using VehicleInput for throttle")
end

-- ── Responsive sizing ─────────────────────────────────────────────────────────
local camera = workspace.CurrentCamera
if camera.ViewportSize.X < 1 then task.wait() end
local _vp    = camera.ViewportSize
local _short = if _vp.X > 0 then math.min(_vp.X, _vp.Y) else 400

-- All sizes in pixels; scale-based UDim2 is used for positions, pixel sizes
-- for button dimensions to guarantee consistent hit targets across devices.
-- Gas/Brake pedals are tall (0.18 × viewport height) per requirements.
local VP_H      = _vp.Y > 0 and _vp.Y or 800
local PAD       = 16  -- fixed 16 px edge inset (matches requirements)
local STEER_W   = math.round(_short * 0.13)   -- steer button width
local STEER_H   = math.round(_short * 0.12)   -- steer button height
local PEDAL_W   = math.round(_short * 0.14)   -- gas / brake width
local PEDAL_H   = math.round(VP_H   * 0.18)   -- gas / brake height (tall)
local BOOST_W   = math.round(_short * 0.11)   -- boost button width
local BOOST_H   = math.round(_short * 0.10)   -- boost button height
local REV_W     = math.round(_short * 0.10)   -- reverse button
local REV_H     = math.round(_short * 0.09)
local RESET_W   = math.round(_short * 0.10)   -- reset button (slightly smaller)
local RESET_H   = math.round(_short * 0.09)
local GAP       = 8   -- gap between adjacent buttons

-- ── Theme ─────────────────────────────────────────────────────────────────────
local COLOR_BG     = Color3.fromRGB(20, 20, 25)
local COLOR_ACCENT = Color3.fromRGB(74, 240, 255)
local COLOR_BOOST  = Color3.fromRGB(255, 140, 0)
local COLOR_TEXT   = Color3.new(1, 1, 1)

-- ── Input state ───────────────────────────────────────────────────────────────
local throttleHeld   = false
local brakeHeld      = false
local steerLeftHeld  = false
local steerRightHeld = false

-- ── Runtime refs ──────────────────────────────────────────────────────────────
local isActive    = false
local currentSeat: VehicleSeat? = nil
local renderConn: RBXScriptConnection? = nil

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MobileControls"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled        = false
screenGui.Parent         = player:WaitForChild("PlayerGui")

-- ── Helper: make a styled button frame ────────────────────────────────────────
-- Returns (frame, textButton).
-- cornerRadius = 1 → full circle; 0.3 → rounded rect
local function makeButton(
	name: string,
	label: string,
	anchorPoint: Vector2,
	position: UDim2,
	sizeX: number,
	sizeY: number,
	accentColor: Color3?,
	cornerRadius: number?
): (Frame, TextButton)
	local ac = accentColor or COLOR_ACCENT
	local cr = cornerRadius or 1

	local frame = Instance.new("Frame")
	frame.Name                   = name .. "_Frame"
	frame.AnchorPoint            = anchorPoint
	frame.Position               = position
	frame.Size                   = UDim2.new(0, sizeX, 0, sizeY)
	frame.BackgroundColor3       = COLOR_BG
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0
	frame.Parent                 = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(cr, 0)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = ac
	stroke.Thickness = 2
	stroke.Parent    = frame

	local btn = Instance.new("TextButton")
	btn.Name                   = name
	btn.Size                   = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                   = label
	btn.TextColor3             = COLOR_TEXT
	btn.Font                   = Enum.Font.GothamBold
	btn.TextScaled             = true
	btn.ZIndex                 = 2
	btn.Parent                 = frame

	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 32
	cap.MinTextSize = 12
	cap.Parent      = btn

	return frame, btn
end

-- ── Helper: pressed / released visual feedback ────────────────────────────────
local function setPressed(frame: Frame, pressed: boolean, accentColor: Color3?)
	local ac = accentColor or COLOR_ACCENT
	if pressed then
		frame.BackgroundColor3       = ac
		frame.BackgroundTransparency = 0.35
	else
		frame.BackgroundColor3       = COLOR_BG
		frame.BackgroundTransparency = 0.25
	end
end

-- ── Helper: wire InputBegan/InputEnded on a frame for multi-touch ─────────────
-- onDown / onUp receive no arguments.
local function wireTouchButton(frame: Frame, onDown: () -> (), onUp: () -> ())
	frame.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			onDown()
		end
	end)
	frame.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			onUp()
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LEFT SIDE — bottom-left, AnchorPoint(0, 1)
--   Row 1 bottom : SteerLeft | SteerRight
--   Row 2 above  : Reverse   (centered above the pair)
--   Row 3 above  : Reset     (smaller, centered)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Steer Left – bottom-left corner
local steerPairW = STEER_W * 2 + GAP  -- total width of the two steer buttons
local steerLeftFrame, _ = makeButton(
	"SteerLeft", "◄",
	Vector2.new(0, 1),
	UDim2.new(0, PAD, 1, -PAD),
	STEER_W, STEER_H)

wireTouchButton(steerLeftFrame,
	function()
		steerLeftHeld = true
		setPressed(steerLeftFrame, true)
	end,
	function()
		steerLeftHeld = false
		setPressed(steerLeftFrame, false)
	end
)

-- Steer Right – immediately right of SteerLeft
local steerRightFrame, _ = makeButton(
	"SteerRight", "►",
	Vector2.new(0, 1),
	UDim2.new(0, PAD + STEER_W + GAP, 1, -PAD),
	STEER_W, STEER_H)

wireTouchButton(steerRightFrame,
	function()
		steerRightHeld = true
		setPressed(steerRightFrame, true)
	end,
	function()
		steerRightHeld = false
		setPressed(steerRightFrame, false)
	end
)

-- Reverse – centered above the steer pair
local reverseX = PAD + (steerPairW - REV_W) / 2
local reverseFrame, reverseBtn = makeButton(
	"ReverseButton", "↺",
	Vector2.new(0, 1),
	UDim2.new(0, reverseX, 1, -(PAD + STEER_H + GAP + REV_H)),
	REV_W, REV_H)

reverseBtn.MouseButton1Click:Connect(function()
	setPressed(reverseFrame, true)
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Health = 0 end
	end
	task.delay(0.15, function() setPressed(reverseFrame, false) end)
end)

-- Reset – centered above Reverse (smaller)
local resetX = PAD + (steerPairW - RESET_W) / 2
local resetFrame, resetBtn = makeButton(
	"ResetButton", "✕",
	Vector2.new(0, 1),
	UDim2.new(0, resetX, 1, -(PAD + STEER_H + GAP + REV_H + GAP + RESET_H)),
	RESET_W, RESET_H)

resetBtn.MouseButton1Click:Connect(function()
	setPressed(resetFrame, true)
	if openGarage then openGarage:FireServer() end
	task.delay(0.15, function() setPressed(resetFrame, false) end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- RIGHT SIDE — bottom-right, AnchorPoint(1, 1)
--   Row 1 bottom : BrakePedal (left) | GasPedal (right)  — tall, easy to tap
--   Row 2 above  : BoostButton  centered above the pedal pair
-- ═══════════════════════════════════════════════════════════════════════════════

-- Gas pedal – rightmost button, bottom-right corner
local gasFrame, _ = makeButton(
	"GasPedal", "▲",
	Vector2.new(1, 1),
	UDim2.new(1, -PAD, 1, -PAD),
	PEDAL_W, PEDAL_H,
	COLOR_ACCENT, 0.3)

wireTouchButton(gasFrame,
	function()
		throttleHeld = true
		setPressed(gasFrame, true)
		if mobileThrottle then mobileThrottle:FireServer(1) end
	end,
	function()
		throttleHeld = false
		setPressed(gasFrame, false)
		if mobileThrottle then mobileThrottle:FireServer(0) end
	end
)

-- Brake pedal – left of Gas
local brakeFrame, _ = makeButton(
	"BrakePedal", "▼",
	Vector2.new(1, 1),
	UDim2.new(1, -(PAD + PEDAL_W + GAP), 1, -PAD),
	PEDAL_W, PEDAL_H,
	Color3.fromRGB(255, 80, 80), 0.3)

wireTouchButton(brakeFrame,
	function()
		brakeHeld = true
		setPressed(brakeFrame, true, Color3.fromRGB(255, 80, 80))
	end,
	function()
		brakeHeld = false
		setPressed(brakeFrame, false, Color3.fromRGB(255, 80, 80))
	end
)

-- Boost – centered above the pedal pair
local pedalPairW = PEDAL_W * 2 + GAP
local boostX = -(PAD + PEDAL_W + GAP + (pedalPairW - BOOST_W) / 2)
local boostFrame, boostBtn = makeButton(
	"BoostButton", "⚡",
	Vector2.new(1, 1),
	UDim2.new(1, boostX, 1, -(PAD + PEDAL_H + GAP + BOOST_H)),
	BOOST_W, BOOST_H,
	COLOR_BOOST)

boostBtn.MouseButton1Click:Connect(function()
	setPressed(boostFrame, true, COLOR_BOOST)
	applyBoost:FireServer()
	task.delay(0.15, function() setPressed(boostFrame, false, COLOR_BOOST) end)
end)

-- ── Reset input state ─────────────────────────────────────────────────────────
local function resetInputs()
	throttleHeld   = false
	brakeHeld      = false
	steerLeftHeld  = false
	steerRightHeld = false
	setPressed(gasFrame,        false)
	setPressed(brakeFrame,      false, Color3.fromRGB(255, 80, 80))
	setPressed(steerLeftFrame,  false)
	setPressed(steerRightFrame, false)
	local seat = currentSeat
	if seat then
		seat.Throttle = 0
		seat.Steer    = 0
	end
end

-- ── Heartbeat: sync VehicleSeat + fire VehicleInput to server ────────────────
local function startRenderLoop()
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.Heartbeat:Connect(function()
		local seat = currentSeat
		if not seat then return end

		local throttleValue = 0
		local steerValue    = 0
		local brakeValue    = 0

		if throttleHeld then
			throttleValue    = 1
			seat.Throttle    = 1
		elseif brakeHeld then
			throttleValue    = -1
			brakeValue       = 1
			seat.Throttle    = -1
		else
			seat.Throttle    = 0
		end

		if steerLeftHeld and not steerRightHeld then
			steerValue    = -1
			seat.Steer    = -1
		elseif steerRightHeld and not steerLeftHeld then
			steerValue    = 1
			seat.Steer    = 1
		else
			seat.Steer    = 0
		end

		vehicleInput:FireServer(throttleValue, steerValue, brakeValue)
	end)
end

local function stopRenderLoop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

-- ── Show / hide controls ──────────────────────────────────────────────────────
local function showControls(driveSeat: VehicleSeat)
	currentSeat       = driveSeat
	isActive          = true
	-- Do NOT set driveSeat.Disabled = true.
	-- A-Chassis checks Disabled to show its own HUD — disabling the seat
	-- silences it.  Server-side throttle authority is handled by MobileInputHandler.
	screenGui.Enabled = true
	startRenderLoop()
	player:SetAttribute("IsDriving", true)
end

local function hideControls()
	isActive          = false
	screenGui.Enabled = false
	resetInputs()
	stopRenderLoop()
	currentSeat = nil
	player:SetAttribute("IsDriving", false)
end

-- ── Seat detection ────────────────────────────────────────────────────────────
local function onSeated(isSeated: boolean, seat: BasePart?)
	if isSeated and seat and seat.Name == "DriveSeat" then
		local vehicleName = "Vehicle_" .. player.UserId
		if seat:FindFirstAncestor(vehicleName) then
			showControls(seat :: VehicleSeat)
		end
	else
		if isActive then hideControls() end
	end
end

local function connectCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(onSeated)

	-- Edge case: already seated when character loads
	if humanoid.SeatPart and humanoid.SeatPart.Name == "DriveSeat" then
		local vehicleName = "Vehicle_" .. player.UserId
		if humanoid.SeatPart:FindFirstAncestor(vehicleName) then
			showControls(humanoid.SeatPart :: VehicleSeat)
		end
	end
end

-- ── Character lifecycle ───────────────────────────────────────────────────────
if player.Character then
	connectCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character: Model)
	if isActive then hideControls() end
	connectCharacter(character)
end)

-- ── VehicleSpawned listener ───────────────────────────────────────────────────
vehicleSpawned.OnClientEvent:Connect(function(vehicleName: string)
	Logger.Info("MobileControls", "Vehicle spawned: %s", vehicleName)
	-- Controls activate via onSeated when the player sits; this is informational.
end)

