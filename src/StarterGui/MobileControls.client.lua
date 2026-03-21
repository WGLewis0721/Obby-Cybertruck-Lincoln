--[[
    MobileControls.client.lua
    Description: On-screen touch controls for A-Chassis vehicles on mobile devices.

    Input Approach: Option B (ContextActionService with UserInputService pass-through)
    ─────────────────────────────────────────────────────────────────────────────────
    A-Chassis 6 handles input via UserInputService.InputBegan / InputEnded /
    InputChanged, checking specific KeyCodes from Tune.Controls:
        Throttle  = Enum.KeyCode.Up      Brake     = Enum.KeyCode.Down
        SteerLeft = Enum.KeyCode.Left    SteerRight = Enum.KeyCode.Right

    ContextActionService.BindAction (createTouchButton = true) creates an on-screen
    touch button.  When pressed the callback fires AND — because the callback returns
    Enum.ContextActionResult.Pass — the InputObject propagates to
    UserInputService.InputBegan (with the bound KeyCode) where A-Chassis's
    DealWithInput function picks it up and updates _GThrot / _GBrake / _GSteerT.

    Option C fallback (RenderStepped): driveSeat.Throttle / driveSeat.Steer are also
    set each frame from button state.  A-Chassis's camera script reads these values
    for smoke / drift effects; Roblox's native VehicleController reads them too.

    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - ReplicatedStorage.Remotes.ApplyBoost (C→S, fired when Boost button is tapped)

    Events Fired:
        - Remotes.ApplyBoost (C→S, on Boost button tap)

    Events Listened:
        - None
--]]

-- ── Services ──────────────────────────────────────────────────────────────────
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

-- ── Mobile guard ──────────────────────────────────────────────────────────────
-- Treat any touch-capable client as eligible so this appears in Studio's
-- device emulator and on touch devices with keyboard support.
local isTouchDevice = UserInputService.TouchEnabled
if not isTouchDevice then return end

-- ── Player reference ─────────────────────────────────────────────────────────
local player = Players.LocalPlayer

-- ── Logger ────────────────────────────────────────────────────────────────────
local Logger = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

-- ── Remote events ─────────────────────────────────────────────────────────────
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

-- ── Theme constants ────────────────────────────────────────────────────────────
local COLOR_BG      = Color3.fromRGB(20, 20, 25)
local COLOR_ACCENT  = Color3.fromRGB(74, 240, 255)
local COLOR_TEXT    = Color3.new(1, 1, 1)
local BTN_SIZE      = 80   -- pixels
local PAD           = 10   -- pixels gap from screen edge / between buttons

-- ── Input state flags (updated by CAS callbacks, read by RenderStepped) ───────
local throttleHeld  = false
local brakeHeld     = false
local steerLeftHeld = false
local steerRightHeld = false

-- ── Runtime references ────────────────────────────────────────────────────────
local isActive       = false      -- true while player is in DriveSeat
local currentSeat    = nil        -- VehicleSeat reference
local renderConn     = nil        -- RenderStepped connection

-- ── Reset vehicle ─────────────────────────────────────────────────────────────
local function resetVehicle()
	local vehicle = workspace:FindFirstChild("Vehicle_" .. player.UserId)
	if not vehicle or not vehicle.PrimaryPart then return end
	local pos = vehicle.PrimaryPart.Position
	vehicle:SetPrimaryPartCFrame(
		CFrame.new(pos + Vector3.new(0, 5, 0))
	)
end

-- ── ScreenGui (hosts Reset and Boost buttons; CAS owns the drive buttons) ─────
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "MobileControls"
screenGui.ResetOnSpawn     = false
screenGui.IgnoreGuiInset   = true
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.Enabled          = false
screenGui.Parent           = player:WaitForChild("PlayerGui")

-- ── Helper: build a cyberpunk-styled Frame + TextButton ───────────────────────
local function makeButton(name, label, position)
	local frame = Instance.new("Frame")
	frame.Name                 = name .. "_Frame"
	frame.Size                 = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
	frame.Position             = position
	frame.BackgroundColor3     = COLOR_BG
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel      = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLOR_ACCENT
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local btn = Instance.new("TextButton")
	btn.Name                 = name
	btn.Size                 = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                 = label
	btn.TextColor3           = COLOR_TEXT
	btn.Font                 = Enum.Font.GothamBold
	btn.TextSize             = 24
	btn.ZIndex               = 2
	btn.Parent               = frame

	frame.Parent = screenGui
	return frame, btn
end

-- ── Helper: set pressed visual state on a frame ───────────────────────────────
local function setPressed(frame, pressed)
	if pressed then
		frame.BackgroundColor3       = COLOR_ACCENT
		frame.BackgroundTransparency = 0.5
	else
		frame.BackgroundColor3       = COLOR_BG
		frame.BackgroundTransparency = 0.3
	end
end

-- ── Helper: apply cyberpunk styling to a CAS-managed button frame ─────────────
-- ContextActionService:GetButton() returns a Frame whose children depend on the
-- Roblox version; we style the frame itself and neutralise any inner decoration.
local function styleCASFrame(frame, label)
	if not frame then return end

	frame.BackgroundColor3       = COLOR_BG
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel        = 0

	-- Remove default CAS decorations (border images, strokes added by the engine)
	for _, child in frame:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UICorner") then
			child:Destroy()
		end
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLOR_ACCENT
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	-- Neutralise the inner ImageButton so our Frame background shows through
	local inner = frame:FindFirstChildWhichIsA("ImageButton")
		or frame:FindFirstChildWhichIsA("TextButton")
	if inner then
		inner.BackgroundTransparency = 1
		if inner:IsA("ImageButton") then
			inner.ImageTransparency = 1
		end
		-- Style the engine-generated text label
		local textLabel = inner:FindFirstChildWhichIsA("TextLabel")
		if textLabel then
			textLabel.Font      = Enum.Font.GothamBold
			textLabel.TextSize  = 24
			textLabel.TextColor3 = COLOR_TEXT
		else
			-- Some CAS versions put title directly on the button
			inner.Font      = Enum.Font.GothamBold
			inner.TextSize  = 24
			inner.TextColor3 = COLOR_TEXT
		end
	end

	-- If the frame itself is a TextButton variant
	local selfBtn = frame:FindFirstChildWhichIsA("TextLabel")
	if selfBtn then
		selfBtn.Font      = Enum.Font.GothamBold
		selfBtn.TextSize  = 24
		selfBtn.TextColor3 = COLOR_TEXT
		selfBtn.Text       = label
	end
end

-- ── Tap-only buttons (ScreenGui, not CAS) ─────────────────────────────────────
-- Left side, above steer left: Reset ↺
local resetFrame, resetBtn = makeButton(
	"Reset", "↺",
	UDim2.new(0, PAD, 1, -(BTN_SIZE * 2 + PAD * 2))
)
resetBtn.MouseButton1Click:Connect(function()
	setPressed(resetFrame, true)
	resetVehicle()
	task.delay(0.15, function()
		setPressed(resetFrame, false)
	end)
end)

-- Right side, 2nd from right at bottom: Boost ⚡
local boostFrame, boostBtn = makeButton(
	"Boost", "⚡",
	UDim2.new(1, -(BTN_SIZE * 2 + PAD * 2), 1, -(BTN_SIZE + PAD))
)
boostBtn.MouseButton1Click:Connect(function()
	setPressed(boostFrame, true)
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
	if remotes then
		local applyBoost = remotes:WaitForChild("ApplyBoost", 5)
		if applyBoost then
			applyBoost:FireServer()
		else
			Logger.Warn("MobileControls", "ApplyBoost RemoteEvent not found")
		end
	else
		Logger.Warn("MobileControls", "Remotes folder not found")
	end
	task.delay(0.15, function()
		setPressed(boostFrame, false)
	end)
end)

-- ── CAS drive-action definitions ──────────────────────────────────────────────
-- Key codes match A-Chassis Tune.Controls exactly:
--   Throttle = KeyCode.Up, Brake = KeyCode.Down,
--   SteerLeft = KeyCode.Left, SteerRight = KeyCode.Right
local driveActions = {
	{
		name     = "MC_SteerLeft",
		label    = "◀",
		keyCode  = Enum.KeyCode.Left,
		-- Bottom-left corner, 1st column
		position = UDim2.new(0, PAD, 1, -(BTN_SIZE + PAD)),
		setState = function(v) steerLeftHeld = v end,
	},
	{
		name     = "MC_SteerRight",
		label    = "▶",
		keyCode  = Enum.KeyCode.Right,
		-- Bottom-left area, 2nd column
		position = UDim2.new(0, PAD + BTN_SIZE + PAD, 1, -(BTN_SIZE + PAD)),
		setState = function(v) steerRightHeld = v end,
	},
	{
		name     = "MC_Throttle",
		label    = "▲",
		keyCode  = Enum.KeyCode.Up,
		-- Bottom-right corner, one row up
		position = UDim2.new(1, -(BTN_SIZE + PAD), 1, -(BTN_SIZE * 2 + PAD * 2)),
		setState = function(v) throttleHeld = v end,
	},
	{
		name     = "MC_Brake",
		label    = "▼",
		keyCode  = Enum.KeyCode.Down,
		-- Bottom-right corner, bottom row
		position = UDim2.new(1, -(BTN_SIZE + PAD), 1, -(BTN_SIZE + PAD)),
		setState = function(v) brakeHeld = v end,
	},
}

-- ── Bind driving controls via CAS ─────────────────────────────────────────────
-- createTouchButton = true  → CAS creates an on-screen button.
-- Returning Pass             → input propagates to UserInputService.InputBegan
--                              with the bound KeyCode, which A-Chassis's
--                              DealWithInput function receives and processes.
local function bindDriveControls()
	for _, action in ipairs(driveActions) do
		local stateFn   = action.setState
		local btnFrame  -- set by task.defer after CAS creates the button

		ContextActionService:BindAction(
			action.name,
			function(_, inputState, _)
				local pressed = inputState == Enum.UserInputState.Begin
				stateFn(pressed)
				if btnFrame then
					setPressed(btnFrame, pressed)
				end
				-- Pass-through so UserInputService.InputBegan fires →
				-- A-Chassis DealWithInput handles throttle / steer / brake.
				return Enum.ContextActionResult.Pass
			end,
			true,           -- createTouchButton
			action.keyCode
		)

		ContextActionService:SetTitle(action.name, action.label)
		ContextActionService:SetPosition(action.name, action.position)

		-- Style the CAS button after it is created (deferred one frame)
		task.defer(function()
			btnFrame = ContextActionService:GetButton(action.name)
			styleCASFrame(btnFrame, action.label)
			if btnFrame then
				btnFrame.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
			end
		end)
	end
end

-- ── Unbind driving controls ────────────────────────────────────────────────────
local function unbindDriveControls()
	for _, action in ipairs(driveActions) do
		ContextActionService:UnbindAction(action.name)
	end
end

-- ── Reset all input flags and seat properties ──────────────────────────────────
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

-- ── RenderStepped: continuously mirror button state to VehicleSeat ────────────
-- Option C fallback: A-Chassis's camera script reads driveSeat.Throttle / .Steer;
-- Roblox's native VehicleController also consults these values.
local function startRenderLoop()
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.RenderStepped:Connect(function()
		if not currentSeat then return end
		local tVal = throttleHeld and 1 or (brakeHeld and -1 or 0)
		local sVal = steerRightHeld and 1 or (steerLeftHeld and -1 or 0)
		currentSeat.Throttle = tVal
		currentSeat.Steer    = sVal
	end)
end

local function stopRenderLoop()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

-- ── Show controls ─────────────────────────────────────────────────────────────
local function showControls(driveSeat)
	currentSeat        = driveSeat
	isActive           = true
	screenGui.Enabled  = true
	bindDriveControls()
	startRenderLoop()
	player:SetAttribute("IsDriving", true)
end

-- ── Hide controls ─────────────────────────────────────────────────────────────
local function hideControls()
	isActive           = false
	screenGui.Enabled  = false
	unbindDriveControls()
	resetInputs()
	stopRenderLoop()
	currentSeat = nil
	player:SetAttribute("IsDriving", false)
end

-- ── Seat detection ────────────────────────────────────────────────────────────
local function onSeated(isSeated, seat)
	if isSeated and seat and seat.Name == "DriveSeat" then
		-- Confirm the seat is part of this player's vehicle
		local vehicleName = "Vehicle_" .. player.UserId
		if seat:FindFirstAncestor(vehicleName) then
			showControls(seat)
		end
	else
		if isActive then
			hideControls()
		end
	end
end

local function connectCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(onSeated)

	-- Handle already-seated edge case (e.g. respawn while in seat)
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
	if isActive then
		hideControls()
	end
	connectCharacter(character)
end)
