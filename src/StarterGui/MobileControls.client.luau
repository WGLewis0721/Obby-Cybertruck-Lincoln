--!strict
-- SCRIPT: MobileControls | LOCATION: StarterGui/MobileControls | SIDE: Client
--[[
    MobileControls.client.lua
    Description: Full mobile driving UI for A-Chassis vehicles.
                 Left-side steering and right-side driving controls.
                 Fires VehicleInput RemoteEvent to server for physics application.

    Layout:
        LEFT SIDE (bottom-left corner)
            Row 1 (bottom):  [ ◄ Steer Left ]  [ Steer Right ► ]
            Row 2 (above):   [   ↺ Reset    ]  [    ☰ Menu     ]

        RIGHT SIDE (bottom-right corner)
            Row 1 (bottom):  [ ▼ Brake ]  [ ▲ Gas ]
            Row 2 (above):   [      ⚡ Boost      ]
            Row 3 (above):   [ CAM ] [ CLR ] [ HRN ] [ SET ]

    Input approach:
      • Gas / Brake / SteerLeft / SteerRight – CAS touch buttons bound to their
        respective KeyCodes. Input state is sent to server via VehicleInput.
      • RenderStepped writes VehicleSeat.Throttle / .Steer for local A-Chassis.
      • Boost / Reset / Menu / action buttons – ScreenGui TextButtons that fire
        RemoteEvents or perform local actions.

    Sizing:
      • BTN_SIZE and PAD are computed from the viewport's shorter dimension so
        buttons are appropriately sized across phones and tablets.

    Controls are hidden until the player is seated in their vehicle (DriveSeat).

    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - ReplicatedStorage.Events.ApplyBoost    (RemoteEvent)
        - ReplicatedStorage.Events.OpenPaintShop (RemoteEvent)
        - ReplicatedStorage.Events.OpenGarage    (RemoteEvent)
        - ReplicatedStorage.Events.OpenMapSelect (RemoteEvent)
        - ReplicatedStorage.Events.Horn          (RemoteEvent)
        - ReplicatedStorage.Events.VehicleInput  (RemoteEvent) - fires to server
        - ReplicatedStorage.Events.VehicleSpawned (RemoteEvent) - shows controls
        - ReplicatedStorage.Module.Logger         (ModuleScript)
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
	ReplicatedStorage:WaitForChild("Module"):WaitForChild("Logger"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events", 10)
local applyBoost    = eventsFolder:WaitForChild("ApplyBoost",    10)
local openPaintShop = eventsFolder:WaitForChild("OpenPaintShop", 10)
local openGarage    = eventsFolder:WaitForChild("OpenGarage",    10)
local openMapSelect = eventsFolder:WaitForChild("OpenMapSelect", 10)
local hornRemote    = eventsFolder:WaitForChild("Horn",          10)
local vehicleInput  = eventsFolder:WaitForChild("VehicleInput",  10)
local vehicleSpawned = eventsFolder:WaitForChild("VehicleSpawned", 10)

if not applyBoost    then Logger.Warn("MobileControls", "ApplyBoost remote not found")    end
if not openPaintShop then Logger.Warn("MobileControls", "OpenPaintShop remote not found") end
if not openGarage    then Logger.Warn("MobileControls", "OpenGarage remote not found")    end
if not openMapSelect then Logger.Warn("MobileControls", "OpenMapSelect remote not found") end
if not hornRemote    then Logger.Warn("MobileControls", "Horn remote not found")           end
if not vehicleInput  then Logger.Warn("MobileControls", "VehicleInput remote not found")  end
if not vehicleSpawned then Logger.Warn("MobileControls", "VehicleSpawned remote not found") end

local mobileThrottle = eventsFolder:FindFirstChild("MobileThrottle")
if not mobileThrottle then
	Logger.Warn("MobileControls", "MobileThrottle RemoteEvent not found — using VehicleInput instead")
end

-- ── Responsive sizing ─────────────────────────────────────────────────────────
-- Read the shorter viewport dimension so buttons scale with the device.
-- task.wait() yields one frame to ensure the camera has reported its size.
local camera = workspace.CurrentCamera
if camera.ViewportSize.X < 1 then task.wait() end

local _vp    = camera.ViewportSize
local _short = if _vp.X > 0 then math.min(_vp.X, _vp.Y) else 400

-- BTN_SIZE:  12 % of shorter dimension, clamped 80–120 px.
-- SMALL_BTN: 8.5 % of shorter dimension, clamped 56–88 px (action row).
-- PAD:       ~16 % of BTN_SIZE, clamped 12–22 px.
local BTN_SIZE  = math.clamp(math.round(_short * 0.12),  80, 120)
local SMALL_BTN = math.clamp(math.round(_short * 0.085), 56, 88)
local PAD       = math.clamp(math.round(BTN_SIZE * 0.16), 12, 22)

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
local currentSeat = nil
local renderConn  = nil

-- CAS button frame refs (populated asynchronously after bind)
local gasFrame        = nil
local brakeFrame      = nil
local steerLeftFrame  = nil
local steerRightFrame = nil

-- ── ScreenGui (hosts all non-CAS buttons) ─────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MobileControls"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled        = false
screenGui.Parent         = player:WaitForChild("PlayerGui")

-- ── Helper: styled circular Frame + TextButton ────────────────────────────────
local function makeButton(name, label, position, size, accentColor)
	size        = size        or BTN_SIZE
	accentColor = accentColor or COLOR_ACCENT

	local frame = Instance.new("Frame")
	frame.Name                   = name .. "_Frame"
	frame.Size                   = UDim2.new(0, size, 0, size)
	frame.Position               = position
	frame.BackgroundColor3       = COLOR_BG
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0
	frame.Parent                 = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)   -- fully circular
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = accentColor
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
	cap.MaxTextSize = 30
	cap.MinTextSize = 12
	cap.Parent      = btn

	return frame, btn
end

-- ── Helper: pressed / released visual feedback ────────────────────────────────
local function setPressed(frame, pressed, accentColor)
	accentColor = accentColor or COLOR_ACCENT
	if pressed then
		frame.BackgroundColor3       = accentColor
		frame.BackgroundTransparency = 0.35
	else
		frame.BackgroundColor3       = COLOR_BG
		frame.BackgroundTransparency = 0.25
	end
end

-- ── Helper: apply cyberpunk theme to a CAS-managed button frame ───────────────
local function styleCASFrame(frame, label, size)
	if not frame then return end
	size = size or BTN_SIZE

	frame.BackgroundColor3       = COLOR_BG
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0
	frame.Size                   = UDim2.new(0, size, 0, size)

	for _, child in frame:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UICorner") then
			child:Destroy()
		end
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLOR_ACCENT
	stroke.Thickness = 2
	stroke.Parent    = frame

	local inner = frame:FindFirstChildWhichIsA("ImageButton")
		or frame:FindFirstChildWhichIsA("TextButton")
	if inner then
		inner.BackgroundTransparency = 1
		if inner:IsA("ImageButton") then
			inner.ImageTransparency = 1
		end
		if label then
			if inner:IsA("TextButton") then
				inner.Text       = label
				inner.TextScaled = true
				inner.Font       = Enum.Font.GothamBold
				inner.TextColor3 = COLOR_TEXT
			else
				local lbl = inner:FindFirstChildWhichIsA("TextLabel")
				if lbl then
					lbl.Text       = label
					lbl.TextScaled = true
					lbl.Font       = Enum.Font.GothamBold
					lbl.TextColor3 = COLOR_TEXT
				end
			end
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- LEFT SIDE: TurnButton, MenuButton  (CAS will add SteerLeft / SteerRight)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Row 2 (above steering): TurnButton (↺ reset vehicle / respawn)
local turnFrame, turnBtn = makeButton(
	"TurnButton", "↺",
	UDim2.new(0, PAD, 1, -(2 * BTN_SIZE + 2 * PAD)))

turnBtn.MouseButton1Click:Connect(function()
	setPressed(turnFrame, true)
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
	task.delay(0.15, function() setPressed(turnFrame, false) end)
end)

-- Row 2 (above steering): MenuButton (☰ open garage)
local menuFrame, menuBtn = makeButton(
	"MenuButton", "☰",
	UDim2.new(0, BTN_SIZE + 2 * PAD, 1, -(2 * BTN_SIZE + 2 * PAD)))

menuBtn.MouseButton1Click:Connect(function()
	setPressed(menuFrame, true)
	if openGarage then
		openGarage:FireServer()
	end
	task.delay(0.15, function() setPressed(menuFrame, false) end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- RIGHT SIDE: BoostButton, action row  (CAS will add Gas / Brake)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Row 2 (above pedals): BoostButton – centred between the two pedals.
-- Pedals span from x=(screenW-2*BTN_SIZE-2*PAD) to x=(screenW-PAD).
-- Boost centre x = screenW - BTN_SIZE - 1.5*PAD  →  left = screenW - 1.5*BTN_SIZE - 1.5*PAD.
local boostXOff = -math.round(1.5 * BTN_SIZE + 1.5 * PAD)
local boostFrame, boostBtn = makeButton(
	"BoostButton", "⚡",
	UDim2.new(1, boostXOff, 1, -(2 * BTN_SIZE + 2 * PAD)),
	BTN_SIZE, COLOR_BOOST)

boostBtn.MouseButton1Click:Connect(function()
	setPressed(boostFrame, true, COLOR_BOOST)
	if applyBoost then
		applyBoost:FireServer()
	end
	task.delay(0.15, function() setPressed(boostFrame, false, COLOR_BOOST) end)
end)

-- Row 3 (above boost): four small action buttons, right-aligned.
-- Y = -(2*BTN_SIZE + SMALL_BTN + 3*PAD)  (PAD gap between boost top and row bottom)
local actionY = -(2 * BTN_SIZE + SMALL_BTN + 3 * PAD)

-- Settings – opens map selection
local settingsFrame, settingsBtn = makeButton(
	"SettingsButton", "MAP",
	UDim2.new(1, -(SMALL_BTN + PAD), 1, actionY),
	SMALL_BTN)

settingsBtn.MouseButton1Click:Connect(function()
	setPressed(settingsFrame, true)
	if openMapSelect then
		openMapSelect:FireServer()
	end
	task.delay(0.15, function() setPressed(settingsFrame, false) end)
end)

-- Horn
local hornFrame, hornBtn = makeButton(
	"HornButton", "HRN",
	UDim2.new(1, -(2 * SMALL_BTN + 2 * PAD), 1, actionY),
	SMALL_BTN)

hornBtn.MouseButton1Click:Connect(function()
	setPressed(hornFrame, true)
	if hornRemote then
		hornRemote:FireServer()
	end
	task.delay(0.15, function() setPressed(hornFrame, false) end)
end)

-- Paint / customisation
local paintFrame, paintBtn = makeButton(
	"PaintButton", "CLR",
	UDim2.new(1, -(3 * SMALL_BTN + 3 * PAD), 1, actionY),
	SMALL_BTN)

paintBtn.MouseButton1Click:Connect(function()
	setPressed(paintFrame, true)
	if openPaintShop then
		openPaintShop:FireServer()
	end
	task.delay(0.15, function() setPressed(paintFrame, false) end)
end)

-- Camera toggle
local cameraFrame, cameraBtn = makeButton(
	"CameraButton", "CAM",
	UDim2.new(1, -(4 * SMALL_BTN + 4 * PAD), 1, actionY),
	SMALL_BTN)

cameraBtn.MouseButton1Click:Connect(function()
	setPressed(cameraFrame, true)
	local cam = workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Follow then
		cam.CameraType = Enum.CameraType.Custom
	else
		cam.CameraType = Enum.CameraType.Follow
	end
	task.delay(0.15, function() setPressed(cameraFrame, false) end)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- CAS: Gas (Up), Brake (Down), SteerLeft (Left), SteerRight (Right)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── Accelerate button (CAS) ───────────────────────────────────────────────────
-- Bottom-right corner.
-- Only Begin/End/Cancel update throttleHeld.  CAS also fires Change events
-- (touch position jitter) which must be ignored — otherwise throttleHeld
-- would reset to false mid-press and the vehicle would stop immediately.
-- The MobileThrottle RemoteEvent tells the server to set VehicleSeat.Throttle
-- directly, bypassing the native VehicleController which would otherwise
-- reset Throttle = 0 every frame (it sees no keyboard/joystick input on mobile).
local function bindDriveControls()
	-- Gas pedal – bottom-right corner
	ContextActionService:BindAction(
		"MC_Gas",
		function(_, inputState, _)
			if inputState == Enum.UserInputState.Begin then
				throttleHeld = true
				if gasFrame then setPressed(gasFrame, true) end
				if mobileThrottle then mobileThrottle:FireServer(1) end
			elseif inputState == Enum.UserInputState.End
				or inputState == Enum.UserInputState.Cancel then
				throttleHeld = false
				if gasFrame then setPressed(gasFrame, false) end
				if mobileThrottle then mobileThrottle:FireServer(0) end
			end
			-- Ignore Change — CAS fires it for touch-position jitter while held.
			return Enum.ContextActionResult.Pass
		end,
		true, Enum.KeyCode.Up
	)
	ContextActionService:SetTitle("MC_Gas", "▲")
	ContextActionService:SetPosition("MC_Gas",
		UDim2.new(1, -(BTN_SIZE + PAD), 1, -(BTN_SIZE + PAD)))

	-- Brake pedal – left of Gas
	ContextActionService:BindAction(
		"MC_Brake",
		function(_, inputState, _)
			local pressed = inputState == Enum.UserInputState.Begin
			brakeHeld = pressed
			if brakeFrame then setPressed(brakeFrame, pressed) end
			return Enum.ContextActionResult.Pass
		end,
		true, Enum.KeyCode.Down
	)
	ContextActionService:SetTitle("MC_Brake", "▼")
	ContextActionService:SetPosition("MC_Brake",
		UDim2.new(1, -(2 * BTN_SIZE + 2 * PAD), 1, -(BTN_SIZE + PAD)))

	-- Steer left – bottom-left corner
	ContextActionService:BindAction(
		"MC_SteerLeft",
		function(_, inputState, _)
			local pressed = inputState == Enum.UserInputState.Begin
			steerLeftHeld = pressed
			if steerLeftFrame then setPressed(steerLeftFrame, pressed) end
			return Enum.ContextActionResult.Pass
		end,
		true, Enum.KeyCode.Left
	)
	ContextActionService:SetTitle("MC_SteerLeft", "◄")
	ContextActionService:SetPosition("MC_SteerLeft",
		UDim2.new(0, PAD, 1, -(BTN_SIZE + PAD)))

	-- Steer right – right of SteerLeft
	ContextActionService:BindAction(
		"MC_SteerRight",
		function(_, inputState, _)
			local pressed = inputState == Enum.UserInputState.Begin
			steerRightHeld = pressed
			if steerRightFrame then setPressed(steerRightFrame, pressed) end
			return Enum.ContextActionResult.Pass
		end,
		true, Enum.KeyCode.Right
	)
	ContextActionService:SetTitle("MC_SteerRight", "►")
	ContextActionService:SetPosition("MC_SteerRight",
		UDim2.new(0, BTN_SIZE + 2 * PAD, 1, -(BTN_SIZE + PAD)))

	-- CAS creates frames asynchronously; style them on the next frame.
	task.defer(function()
		gasFrame = ContextActionService:GetButton("MC_Gas")
		styleCASFrame(gasFrame, "▲")

		brakeFrame = ContextActionService:GetButton("MC_Brake")
		styleCASFrame(brakeFrame, "▼")

		steerLeftFrame = ContextActionService:GetButton("MC_SteerLeft")
		styleCASFrame(steerLeftFrame, "◄")

		steerRightFrame = ContextActionService:GetButton("MC_SteerRight")
		styleCASFrame(steerRightFrame, "►")
	end)
end

local function unbindDriveControls()
	ContextActionService:UnbindAction("MC_Gas")
	ContextActionService:UnbindAction("MC_Brake")
	ContextActionService:UnbindAction("MC_SteerLeft")
	ContextActionService:UnbindAction("MC_SteerRight")
	gasFrame        = nil
	brakeFrame      = nil
	steerLeftFrame  = nil
	steerRightFrame = nil
end

-- ── Reset input state ─────────────────────────────────────────────────────────
local function resetInputs()
	throttleHeld   = false
	brakeHeld      = false
	steerLeftHeld  = false
	steerRightHeld = false
	if currentSeat then
		currentSeat.Throttle = 0
		currentSeat.Steer    = 0
	end
end

-- ── RenderStepped: sync VehicleSeat.Throttle and .Steer each frame ────────────
-- Also fires VehicleInput RemoteEvent to server for physics application
local function startRenderLoop()
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.RenderStepped:Connect(function()
		if not currentSeat then return end

		-- Calculate input values
		local throttleValue: number = 0
		local steerValue: number = 0
		local brakeValue: number = 0

		if throttleHeld then
			throttleValue = 1
			currentSeat.Throttle = 1
		elseif brakeHeld then
			throttleValue = -1
			brakeValue = 1
			currentSeat.Throttle = -1
		else
			currentSeat.Throttle = 0
		end

		if steerLeftHeld and not steerRightHeld then
			steerValue = -1
			currentSeat.Steer = -1
		elseif steerRightHeld and not steerLeftHeld then
			steerValue = 1
			currentSeat.Steer = 1
		else
			currentSeat.Steer = 0
		end

		-- Fire VehicleInput to server for physics application
		-- This is the A-Chassis integration: server applies forces based on input
		if vehicleInput then
			vehicleInput:FireServer(throttleValue, steerValue, brakeValue)
		end
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
	-- NOTE: Do NOT set currentSeat.Disabled = true here.
	-- A-Chassis's Interface LocalScript checks Disabled to decide whether to
	-- render the driving HUD — disabling the seat silences it entirely.
	-- Server-authoritative throttle is handled via MobileInputHandler instead.
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

-- ── VehicleSpawned event listener ──────────────────────────────────────────────
-- Server fires this when a vehicle is spawned for this player
if vehicleSpawned then
	vehicleSpawned.OnClientEvent:Connect(function(vehicleName: string, spawnPosition: Vector3)
		Logger.Info("MobileControls", "Vehicle spawned: %s", vehicleName)
		-- The controls will show when the player sits in the seat (via onSeated)
		-- This event is for awareness that the vehicle is ready
	end)
end
