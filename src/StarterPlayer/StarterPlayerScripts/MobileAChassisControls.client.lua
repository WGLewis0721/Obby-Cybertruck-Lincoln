local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not UserInputService.TouchEnabled then
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local okVim, virtualInputManager = pcall(function()
	return game:GetService("VirtualInputManager")
end)

if not okVim or not virtualInputManager then
	warn("MobileAChassisControls: VirtualInputManager is unavailable")
	return
end

local VEHICLE_NAME = "Vehicle_" .. player.UserId
local POINTER_TYPES = {
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.MouseButton1] = true,
}

local ACTION_TO_KEYCODE = {
	Accelerate = Enum.KeyCode.W,
	Brake = Enum.KeyCode.S,
	Boost = Enum.KeyCode.LeftShift,
	SteerLeft = Enum.KeyCode.A,
	SteerRight = Enum.KeyCode.D,
}

local heldActions = {
	Accelerate = false,
	Brake = false,
	Boost = false,
	SteerLeft = false,
	SteerRight = false,
}

local buttonPointers = {
	Accelerate = nil,
	Brake = nil,
	Boost = nil,
}

local currentSeat = nil
local seatedConnection = nil
local steeringInput = nil
local steeringDirection = 0
local actionButtons = {}

local function isPointerInput(input)
	return POINTER_TYPES[input.UserInputType] == true
end

local function isPlayerDriveSeat(seat)
	if not seat or seat.Name ~= "DriveSeat" then
		return false
	end

	return seat:FindFirstAncestor(VEHICLE_NAME) ~= nil
end

local function sendKeyEvent(keyCode, isPressed)
	local ok = pcall(function()
		virtualInputManager:SendKeyEvent(isPressed, keyCode, false, game)
	end)

	if not ok then
		warn(string.format("MobileAChassisControls: failed to send key event for %s", keyCode.Name))
	end
end

local function setActionState(actionName, isDown)
	if heldActions[actionName] == isDown then
		return
	end

	heldActions[actionName] = isDown
	sendKeyEvent(ACTION_TO_KEYCODE[actionName], isDown)

	local button = actionButtons[actionName]
	if button then
		button:SetAttribute("Pressed", isDown)
	end
end

local function releaseAllActions()
	steeringInput = nil
	steeringDirection = 0

	for actionName in pairs(heldActions) do
		setActionState(actionName, false)
	end

	for actionName in pairs(buttonPointers) do
		buttonPointers[actionName] = nil
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileAChassisControls"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 50
screenGui.Enabled = false
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = screenGui

local camera = workspace.CurrentCamera
while not camera do
	workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	camera = workspace.CurrentCamera
end

local viewport = camera.ViewportSize
local shortSide = math.max(320, math.min(viewport.X, viewport.Y))
local buttonSize = math.clamp(math.floor(shortSide * 0.16), 76, 118)
local gap = math.clamp(math.floor(buttonSize * 0.18), 12, 24)
local steerPadSize = math.clamp(math.floor(shortSide * 0.28), 140, 220)

local function createRoundButton(name, label, accentColor, position)
	local frame = Instance.new("Frame")
	frame.Name = name .. "Frame"
	frame.Size = UDim2.fromOffset(buttonSize, buttonSize)
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = root
	frame:SetAttribute("Pressed", false)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 2
	stroke.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = label
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(244, 248, 255)
	button.TextSize = math.clamp(math.floor(buttonSize * 0.28), 18, 30)
	button.AutoButtonColor = false
	button.Parent = frame

	local function refresh()
		local isPressed = frame:GetAttribute("Pressed") == true
		if isPressed then
			frame.BackgroundColor3 = accentColor
			frame.BackgroundTransparency = 0.08
		else
			frame.BackgroundColor3 = Color3.fromRGB(16, 22, 32)
			frame.BackgroundTransparency = 0.15
		end
	end

	frame:GetAttributeChangedSignal("Pressed"):Connect(refresh)
	refresh()

	return button
end

local steerFrame = Instance.new("Frame")
steerFrame.Name = "SteeringPad"
steerFrame.Size = UDim2.fromOffset(steerPadSize, steerPadSize)
steerFrame.Position = UDim2.new(0, gap, 1, -(steerPadSize + gap))
steerFrame.BackgroundColor3 = Color3.fromRGB(12, 18, 26)
steerFrame.BackgroundTransparency = 0.12
steerFrame.BorderSizePixel = 0
steerFrame.Parent = root

local steerCorner = Instance.new("UICorner")
steerCorner.CornerRadius = UDim.new(0, 24)
steerCorner.Parent = steerFrame

local steerStroke = Instance.new("UIStroke")
steerStroke.Color = Color3.fromRGB(88, 214, 255)
steerStroke.Thickness = 2
steerStroke.Parent = steerFrame

local steerLabel = Instance.new("TextLabel")
steerLabel.Name = "Label"
steerLabel.Size = UDim2.new(1, 0, 0, 26)
steerLabel.Position = UDim2.fromOffset(0, 12)
steerLabel.BackgroundTransparency = 1
steerLabel.Text = "STEER"
steerLabel.Font = Enum.Font.GothamBold
steerLabel.TextColor3 = Color3.fromRGB(226, 240, 255)
steerLabel.TextSize = 18
steerLabel.Parent = steerFrame

local steerGuide = Instance.new("Frame")
steerGuide.Name = "Guide"
steerGuide.AnchorPoint = Vector2.new(0.5, 0.5)
steerGuide.Size = UDim2.new(1, -28, 0, 8)
steerGuide.Position = UDim2.fromScale(0.5, 0.62)
steerGuide.BackgroundColor3 = Color3.fromRGB(34, 46, 62)
steerGuide.BorderSizePixel = 0
steerGuide.Parent = steerFrame

local steerGuideCorner = Instance.new("UICorner")
steerGuideCorner.CornerRadius = UDim.new(1, 0)
steerGuideCorner.Parent = steerGuide

local steerThumb = Instance.new("Frame")
steerThumb.Name = "Thumb"
steerThumb.AnchorPoint = Vector2.new(0.5, 0.5)
steerThumb.Size = UDim2.fromOffset(math.floor(steerPadSize * 0.22), math.floor(steerPadSize * 0.22))
steerThumb.Position = UDim2.fromScale(0.5, 0.62)
steerThumb.BackgroundColor3 = Color3.fromRGB(88, 214, 255)
steerThumb.BorderSizePixel = 0
steerThumb.Parent = steerFrame

local steerThumbCorner = Instance.new("UICorner")
steerThumbCorner.CornerRadius = UDim.new(1, 0)
steerThumbCorner.Parent = steerThumb

local steerHint = Instance.new("TextLabel")
steerHint.Name = "Hint"
steerHint.Size = UDim2.new(1, -24, 0, 36)
steerHint.AnchorPoint = Vector2.new(0.5, 1)
steerHint.Position = UDim2.new(0.5, 0, 1, -14)
steerHint.BackgroundTransparency = 1
steerHint.Text = "Drag left / right"
steerHint.Font = Enum.Font.Gotham
steerHint.TextColor3 = Color3.fromRGB(170, 188, 208)
steerHint.TextSize = 14
steerHint.Parent = steerFrame

local accelerateButton = createRoundButton(
	"Accelerate",
	"GAS",
	Color3.fromRGB(92, 255, 136),
	UDim2.new(1, -(buttonSize + gap), 1, -(buttonSize + gap))
)
local brakeButton = createRoundButton(
	"Brake",
	"BRAKE",
	Color3.fromRGB(255, 118, 118),
	UDim2.new(1, -(buttonSize * 2 + gap * 2), 1, -(buttonSize + gap))
)
local boostButton = createRoundButton(
	"Boost",
	"SHIFT",
	Color3.fromRGB(255, 176, 76),
	UDim2.new(1, -math.floor(buttonSize * 1.5 + gap * 1.5), 1, -(buttonSize * 2 + gap * 2))
)

actionButtons.Accelerate = accelerateButton.Parent
actionButtons.Brake = brakeButton.Parent
actionButtons.Boost = boostButton.Parent

local function updateSteeringVisual(normalized)
	local deadzone = 0.18
	local clamped = math.clamp(normalized, -1, 1)
	local visual = 0
	if math.abs(clamped) >= deadzone then
		visual = clamped
	end

	steerThumb.Position = UDim2.new(0.5 + visual * 0.3, 0, 0.62, 0)
end

local function applySteeringDirection(nextDirection)
	if steeringDirection == nextDirection then
		return
	end

	steeringDirection = nextDirection
	setActionState("SteerLeft", nextDirection < 0)
	setActionState("SteerRight", nextDirection > 0)
end

local function setSteeringFromPosition(screenPosition)
	local framePosition = steerFrame.AbsolutePosition
	local frameSize = steerFrame.AbsoluteSize
	local centerX = framePosition.X + frameSize.X * 0.5
	local normalized = 0
	if frameSize.X > 0 then
		normalized = (screenPosition.X - centerX) / (frameSize.X * 0.5)
	end

	local deadzone = 0.18
	if normalized <= -deadzone then
		applySteeringDirection(-1)
	elseif normalized >= deadzone then
		applySteeringDirection(1)
	else
		applySteeringDirection(0)
	end

	updateSteeringVisual(normalized)
end

local function resetSteering()
	applySteeringDirection(0)
	updateSteeringVisual(0)
end

local function bindHold(button, actionName)
	button.InputBegan:Connect(function(input)
		if not screenGui.Enabled or not isPointerInput(input) or buttonPointers[actionName] then
			return
		end

		buttonPointers[actionName] = input
		setActionState(actionName, true)
	end)
end

bindHold(accelerateButton, "Accelerate")
bindHold(brakeButton, "Brake")
bindHold(boostButton, "Boost")

steerFrame.InputBegan:Connect(function(input)
	if not screenGui.Enabled or not isPointerInput(input) or steeringInput then
		return
	end

	steeringInput = input
	setSteeringFromPosition(input.Position)
end)

UserInputService.InputChanged:Connect(function(input)
	if input == steeringInput then
		setSteeringFromPosition(input.Position)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	for actionName, activeInput in pairs(buttonPointers) do
		if activeInput == input then
			buttonPointers[actionName] = nil
			setActionState(actionName, false)
		end
	end

	if input == steeringInput then
		steeringInput = nil
		resetSteering()
	end
end)

GuiService.MenuOpened:Connect(releaseAllActions)

local function setControlsVisible(isVisible)
	if screenGui.Enabled == isVisible then
		return
	end

	screenGui.Enabled = isVisible
	player:SetAttribute("IsDriving", isVisible)

	if not isVisible then
		releaseAllActions()
	end
end

local function setCurrentSeat(seat)
	local nextSeat = if isPlayerDriveSeat(seat) then seat else nil
	if currentSeat == nextSeat then
		return
	end

	currentSeat = nextSeat
	setControlsVisible(currentSeat ~= nil)
end

local function connectCharacter(character)
	if seatedConnection then
		seatedConnection:Disconnect()
		seatedConnection = nil
	end

	local humanoid = character:WaitForChild("Humanoid")
	seatedConnection = humanoid.Seated:Connect(function(isSeated, seat)
		setCurrentSeat(if isSeated then seat else nil)
	end)

	setCurrentSeat(humanoid.SeatPart)
end

if player.Character then
	connectCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character)
	setCurrentSeat(nil)
	connectCharacter(character)
end)

RunService.RenderStepped:Connect(function()
	if currentSeat and not currentSeat:IsDescendantOf(workspace) then
		setCurrentSeat(nil)
	end
end)

resetSteering()
player:SetAttribute("IsDriving", false)
