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
            Analog steering joystick — circular base + draggable knob.
            X-axis only: far left = -1, center = 0, far right = +1.

        RIGHT SIDE (AnchorPoint 1,1  bottom-right, 16 px from edges)
            [ ▼ Brake ] [ ▲ Gas ]  (tall pedals, hold to apply)

    Input:
        Gas/Brake use InputBegan/InputEnded hold-tracking per frame so they
        and the joystick can all be held down simultaneously (multi-touch).
        The joystick tracks ONE specific touch by InputObject identity (set
        on InputBegan over its base, cleared on that same touch's InputEnded)
        so a second finger elsewhere never gets mistaken for steering input.

    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - ReplicatedStorage.Events.ApplyBoost     (RemoteEvent)
        - ReplicatedStorage.Events.OpenGarage     (RemoteEvent)
        - ReplicatedStorage.Events.VehicleSpawned (RemoteEvent) shows controls
        - ReplicatedStorage.Module.Logger          (ModuleScript)

    Drives the vehicle by writing directly into MobileActive/MobileThrottle/
    MobileBrake/MobileSteer value objects under the seated vehicle's own
    "A-Chassis Interface" (client-authoritative, matching how AC6's own
    keyboard input already works for the seated player). No RemoteEvent
    round-trip: this script and the vehicle's Drive LocalScript both run on
    the same client, since AC6's Drive script never reads VehicleSeat.Throttle/
    .Steer at all — only raw UserInputService KeyCode events.
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
local vehicleSpawned = eventsFolder:WaitForChild("VehicleSpawned", 10) :: RemoteEvent
local openPaintShop  = eventsFolder:WaitForChild("OpenPaintShop", 10) :: RemoteEvent
local openGarage     = eventsFolder:WaitForChild("OpenGarage", 10) :: RemoteEvent
local selectMap      = eventsFolder:WaitForChild("SelectMap", 10) :: RemoteEvent

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
local JOYSTICK_RADIUS = math.clamp(math.round(_short * 0.16), 70, 130)   -- outer base radius
local KNOB_RADIUS     = math.round(JOYSTICK_RADIUS * 0.42)              -- draggable knob radius
local STEER_DEADZONE  = 0.12   -- fraction of max travel ignored near center
local PEDAL_W   = math.clamp(math.round(_short * 0.14), 64, 112)   -- gas / brake width
local PEDAL_H   = math.round(VP_H   * 0.18)   -- gas / brake height (tall)
local GAP       = math.clamp(math.round(_short * 0.02), 4, 8)   -- gap between adjacent buttons

-- ── Theme ─────────────────────────────────────────────────────────────────────
local COLOR_BG     = Color3.fromRGB(20, 20, 25)
local COLOR_ACCENT = Color3.fromRGB(74, 240, 255)
local COLOR_BOOST  = Color3.fromRGB(255, 140, 0)
local COLOR_TEXT   = Color3.new(1, 1, 1)

-- ── Input state ───────────────────────────────────────────────────────────────
local throttleHeld   = false
local brakeHeld      = false
local steerValue     = 0  -- authoritative -1..1, driven by the steering joystick

-- ── Runtime refs ──────────────────────────────────────────────────────────────
local isActive    = false
local currentSeat: VehicleSeat? = nil
local renderConn: RBXScriptConnection? = nil
local chassisInterface: Instance? = nil

-- Locates the seated vehicle's AC6 "A-Chassis Interface" so mobile input can be
-- written straight into the values the (patched) Drive LocalScript reads.
local function findChassisInterface(seat: VehicleSeat): Instance?
	local vehicle = seat:FindFirstAncestor("Vehicle_" .. player.UserId)
	if not vehicle then return nil end
	return vehicle:FindFirstChild("A-Chassis Interface", true)
end

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MobileControls"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder    = 10
screenGui.ScreenInsets    = Enum.ScreenInsets.CoreUISafeInsets
screenGui.Enabled        = false
screenGui.Parent         = player:WaitForChild("PlayerGui")

local utilityBar = Instance.new("Frame")
utilityBar.Name = "UtilityBar"
utilityBar.Size = UDim2.fromOffset(216, 36)
utilityBar.Position = UDim2.new(0, PAD, 0, 16)
utilityBar.BackgroundTransparency = 1
utilityBar.Parent = screenGui

local utilityLayout = Instance.new("UIListLayout")
utilityLayout.FillDirection = Enum.FillDirection.Horizontal
utilityLayout.Padding = UDim.new(0, GAP)
utilityLayout.Parent = utilityBar

local mapMenu = Instance.new("Frame")
mapMenu.Name = "MapSelector"
mapMenu.Size = UDim2.fromOffset(190, 72)
mapMenu.Position = UDim2.new(0, PAD, 0, 58)
mapMenu.BackgroundColor3 = COLOR_BG
mapMenu.BackgroundTransparency = 0.08
mapMenu.BorderSizePixel = 0
mapMenu.Visible = false
mapMenu.Parent = screenGui

local mapChoice = Instance.new("TextButton")
mapChoice.Name = "CityCircuitButton"
mapChoice.Size = UDim2.new(1, -12, 1, -12)
mapChoice.Position = UDim2.fromOffset(6, 6)
mapChoice.BackgroundColor3 = Color3.fromRGB(35, 75, 95)
mapChoice.BorderSizePixel = 0
mapChoice.Text = "CITY CIRCUIT"
mapChoice.Font = Enum.Font.GothamBold
mapChoice.TextSize = 13
mapChoice.TextColor3 = COLOR_TEXT
mapChoice.Parent = mapMenu

local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 6)
mapCorner.Parent = mapMenu
local choiceCorner = Instance.new("UICorner")
choiceCorner.CornerRadius = UDim.new(0, 5)
choiceCorner.Parent = mapChoice

local function makeUtilityButton(name: string, label: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(68, 36)
	button.BackgroundColor3 = COLOR_BG
	button.BackgroundTransparency = 0.18
	button.BorderSizePixel = 0
	button.Text = label
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = COLOR_TEXT
	button.Parent = utilityBar
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	return button
end

local shopButton = makeUtilityButton("ShopButton", "SHOP")
local mapButton = makeUtilityButton("MapButton", "MAP")
local carsButton = makeUtilityButton("CarsButton", "CARS")

shopButton.MouseButton1Click:Connect(function()
	openPaintShop:FireServer()
end)

mapButton.MouseButton1Click:Connect(function()
	mapMenu.Visible = not mapMenu.Visible
end)

mapChoice.MouseButton1Click:Connect(function()
	selectMap:FireServer("skyscraper")
	mapMenu.Visible = false
end)

carsButton.MouseButton1Click:Connect(function()
	openGarage:FireServer()
end)

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
--   Analog steering joystick: circular base + draggable knob, X-axis only.
-- ═══════════════════════════════════════════════════════════════════════════════

local joystickBase = Instance.new("Frame")
joystickBase.Name                   = "SteeringJoystick"
joystickBase.AnchorPoint            = Vector2.new(0, 1)
joystickBase.Position               = UDim2.new(0, PAD, 1, -PAD)
joystickBase.Size                   = UDim2.new(0, JOYSTICK_RADIUS * 2, 0, JOYSTICK_RADIUS * 2)
joystickBase.BackgroundColor3       = COLOR_BG
joystickBase.BackgroundTransparency = 0.35
joystickBase.BorderSizePixel        = 0
joystickBase.Parent                 = screenGui

local baseCorner = Instance.new("UICorner")
baseCorner.CornerRadius = UDim.new(1, 0)
baseCorner.Parent       = joystickBase

local baseStroke = Instance.new("UIStroke")
baseStroke.Color        = COLOR_ACCENT
baseStroke.Thickness    = 2
baseStroke.Transparency = 0.3
baseStroke.Parent       = joystickBase

local knob = Instance.new("Frame")
knob.Name                   = "Knob"
knob.AnchorPoint            = Vector2.new(0.5, 0.5)
knob.Position                = UDim2.new(0.5, 0, 0.5, 0)
knob.Size                    = UDim2.new(0, KNOB_RADIUS * 2, 0, KNOB_RADIUS * 2)
knob.BackgroundColor3       = COLOR_ACCENT
knob.BackgroundTransparency = 0.1
knob.BorderSizePixel        = 0
knob.ZIndex                  = 2
knob.Parent                  = joystickBase

local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1, 0)
knobCorner.Parent       = knob

-- ── Steering: track exactly one touch by identity, never global TouchMoved ────
local steerTouch: InputObject? = nil
local maxKnobOffset = JOYSTICK_RADIUS - KNOB_RADIUS

local function resetSteering()
	knob.Position = UDim2.new(0.5, 0, 0.5, 0)
	steerValue = 0
end

local function updateSteeringFromPosition(inputPosition: Vector3)
	local baseCenter = joystickBase.AbsolutePosition + joystickBase.AbsoluteSize / 2
	local delta = Vector2.new(inputPosition.X, inputPosition.Y) - baseCenter

	-- Clamp the knob to the base's radius so it never visually escapes the ring.
	local dist = delta.Magnitude
	local clamped = (dist > maxKnobOffset and maxKnobOffset > 0) and delta.Unit * maxKnobOffset or delta
	knob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)

	-- Only the X axis drives steering: far left = -1, center = 0, far right = +1.
	local raw = maxKnobOffset > 0 and (clamped.X / maxKnobOffset) or 0
	if math.abs(raw) < STEER_DEADZONE then
		raw = 0
	else
		-- Rescale past the deadzone so full deflection still reaches ±1.
		local sign = raw > 0 and 1 or -1
		raw = sign * (math.abs(raw) - STEER_DEADZONE) / (1 - STEER_DEADZONE)
	end
	steerValue = math.clamp(raw, -1, 1)
end

joystickBase.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.Touch then return end
	if steerTouch then return end -- one owner at a time; ignore a second finger here
	steerTouch = input
	updateSteeringFromPosition(input.Position)
end)

-- Tracks the SAME touch as it drags beyond the base's bounds (thumbs drift).
-- Filtered by identity, so this never treats an unrelated touch as steering.
UserInputService.InputChanged:Connect(function(input: InputObject)
	if input ~= steerTouch then return end
	if input.UserInputType ~= Enum.UserInputType.Touch then return end
	updateSteeringFromPosition(input.Position)
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input ~= steerTouch then return end
	steerTouch = nil
	resetSteering()
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- RIGHT SIDE — bottom-right, AnchorPoint(1, 1)
--   Row 1 bottom : BrakePedal (left) | GasPedal (right)  — tall, easy to tap
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
	end,
	function()
		throttleHeld = false
		setPressed(gasFrame, false)
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

-- ── Reset input state ─────────────────────────────────────────────────────────
local function resetInputs()
	throttleHeld = false
	brakeHeld    = false
	steerTouch   = nil
	resetSteering()
	setPressed(gasFrame,   false)
	setPressed(brakeFrame, false, Color3.fromRGB(255, 80, 80))
end

-- ── Heartbeat: push held-button state into the vehicle's mobile input values ──
-- Written directly (no RemoteEvent) because this script and the vehicle's own
-- Drive LocalScript both run on the seated player's client.
local function startRenderLoop()
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.Heartbeat:Connect(function()
		if not chassisInterface then return end
		local ci = chassisInterface :: any

		ci.MobileThrottle.Value = throttleHeld and 1 or 0
		ci.MobileBrake.Value    = brakeHeld and 1 or 0
		ci.MobileSteer.Value    = steerValue
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
	-- silences it.
	chassisInterface = findChassisInterface(driveSeat)
	if chassisInterface then
		(chassisInterface :: any).MobileActive.Value = true
	else
		Logger.Warn("MobileControls", "A-Chassis Interface not found under %s — mobile input will not drive the vehicle", driveSeat:GetFullName())
	end
	screenGui.Enabled = true
	startRenderLoop()
	player:SetAttribute("IsDriving", true)
end

local function hideControls()
	isActive          = false
	screenGui.Enabled = false
	resetInputs()
	stopRenderLoop()
	if chassisInterface then
		local ci = chassisInterface :: any
		ci.MobileActive.Value   = false
		ci.MobileThrottle.Value = 0
		ci.MobileBrake.Value    = 0
		ci.MobileSteer.Value    = 0
	end
	chassisInterface = nil
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
-- Informational only — controls activate via onSeated when the player sits.
-- Speedo/Speed layout is owned solely by ResponsiveHudController.client.luau.
vehicleSpawned.OnClientEvent:Connect(function(vehicleName: string)
	Logger.Info("MobileControls", "Vehicle spawned: %s", vehicleName)
end)

