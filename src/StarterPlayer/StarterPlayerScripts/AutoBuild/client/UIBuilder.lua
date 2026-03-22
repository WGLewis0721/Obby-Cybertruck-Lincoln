local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ControlState = require(script.Parent.Parent.shared.ControlState)

local RUNTIME_EVENT_NAME = "AutoBuildUIInput"
local UI_SOURCE = "UIBuilder"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local camera = workspace.CurrentCamera
while not camera do
	workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	camera = workspace.CurrentCamera
end

local viewport = camera.ViewportSize
local shortSide = math.max(320, math.min(viewport.X, viewport.Y))
local buttonSize = math.clamp(math.floor(shortSide * 0.17), 70, 120)
local gap = math.clamp(math.floor(buttonSize * 0.18), 10, 22)
local panelWidth = buttonSize * 2 + gap
local panelHeight = buttonSize * 2 + gap

local function getOrCreateInputRelay()
	local relay = script.Parent:FindFirstChild(RUNTIME_EVENT_NAME)
	if relay and relay:IsA("BindableEvent") then
		return relay
	end

	if relay then
		relay:Destroy()
	end

	relay = Instance.new("BindableEvent")
	relay.Name = RUNTIME_EVENT_NAME
	relay.Parent = script.Parent
	return relay
end

local inputRelay = getOrCreateInputRelay()

local existingGui = playerGui:FindFirstChild("DrivingHUD")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DrivingHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 25
screenGui.Enabled = false
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = screenGui

local leftPanel = Instance.new("Frame")
leftPanel.Name = "SteeringPanel"
leftPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)
leftPanel.Position = UDim2.new(0, gap, 1, -(panelHeight + gap))
leftPanel.BackgroundTransparency = 1
leftPanel.Visible = UserInputService.TouchEnabled
leftPanel.Parent = root

local rightPanel = Instance.new("Frame")
rightPanel.Name = "DrivePanel"
rightPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)
rightPanel.AnchorPoint = Vector2.new(1, 0)
rightPanel.Position = UDim2.new(1, -gap, 1, -(panelHeight + gap))
rightPanel.BackgroundTransparency = 1
rightPanel.Visible = UserInputService.TouchEnabled
rightPanel.Parent = root

local nitroPanel = Instance.new("Frame")
nitroPanel.Name = "NitroPanel"
nitroPanel.Size = UDim2.new(0, math.clamp(buttonSize * 3, 220, 320), 0, 72)
nitroPanel.AnchorPoint = Vector2.new(0.5, 1)
nitroPanel.Position = UDim2.new(0.5, 0, 1, -(panelHeight + gap * 2 + 72))
nitroPanel.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
nitroPanel.BackgroundTransparency = 0.15
nitroPanel.BorderSizePixel = 0
nitroPanel.Parent = root

local nitroCorner = Instance.new("UICorner")
nitroCorner.CornerRadius = UDim.new(0, 16)
nitroCorner.Parent = nitroPanel

local nitroStroke = Instance.new("UIStroke")
nitroStroke.Color = Color3.fromRGB(88, 220, 255)
nitroStroke.Thickness = 2
nitroStroke.Parent = nitroPanel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 22)
statusLabel.Position = UDim2.fromOffset(10, 10)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextColor3 = Color3.fromRGB(232, 240, 255)
statusLabel.TextSize = 18
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Enter your vehicle"
statusLabel.Parent = nitroPanel

local barBackground = Instance.new("Frame")
barBackground.Name = "NitroBar"
barBackground.Size = UDim2.new(1, -20, 0, 18)
barBackground.Position = UDim2.new(0, 10, 1, -28)
barBackground.BackgroundColor3 = Color3.fromRGB(24, 31, 43)
barBackground.BorderSizePixel = 0
barBackground.Parent = nitroPanel

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barBackground

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Color3.fromRGB(255, 152, 72)
barFill.BorderSizePixel = 0
barFill.Parent = barBackground

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = barFill

local buttonFrames = {}
local buttonState = {
	Accelerate = false,
	Brake = false,
	Boost = false,
	SteerLeft = false,
	SteerRight = false,
}
local activePointers = {}

local function makeButton(parent, name, text, position, accentColor)
	local frame = Instance.new("Frame")
	frame.Name = name .. "Frame"
	frame.Size = UDim2.fromOffset(buttonSize, buttonSize)
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(15, 21, 31)
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 2
	stroke.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(243, 247, 255)
	button.TextSize = math.clamp(math.floor(buttonSize * 0.26), 16, 28)
	button.Parent = frame

	buttonFrames[name] = {
		Frame = frame,
		Stroke = stroke,
		Button = button,
		Accent = accentColor,
	}

	return button
end

local function refreshButton(name)
	local data = buttonFrames[name]
	if not data then
		return
	end

	local accent = data.Accent
	if name == "Boost" and ControlState.IsCoolingDown then
		accent = Color3.fromRGB(180, 88, 88)
		data.Button.Text = "COOL"
	else
		data.Button.Text = if name == "SteerLeft" then "LEFT"
			elseif name == "SteerRight" then "RIGHT"
			elseif name == "Accelerate" then "GAS"
			elseif name == "Brake" then "BRAKE"
			else "BOOST"
	end

	data.Stroke.Color = accent
	if buttonState[name] then
		data.Frame.BackgroundColor3 = accent
		data.Frame.BackgroundTransparency = 0.1
	else
		data.Frame.BackgroundColor3 = Color3.fromRGB(15, 21, 31)
		data.Frame.BackgroundTransparency = 0.18
	end
end

local function setActionState(action, isDown)
	if buttonState[action] == isDown then
		return
	end

	buttonState[action] = isDown
	refreshButton(action)
	inputRelay:Fire(action, isDown, UI_SOURCE)
end

local function releaseAllActions()
	table.clear(activePointers)
	for action, isDown in pairs(buttonState) do
		if isDown then
			setActionState(action, false)
		end
	end
end

local function isPointerInput(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function bindHold(button, action)
	button.InputBegan:Connect(function(input)
		if not isPointerInput(input) or activePointers[action] then
			return
		end

		activePointers[action] = input
		setActionState(action, true)
	end)
end

UserInputService.InputEnded:Connect(function(input)
	for action, activeInput in pairs(activePointers) do
		if activeInput == input then
			activePointers[action] = nil
			setActionState(action, false)
		end
	end
end)

local steerLeftButton = makeButton(
	leftPanel,
	"SteerLeft",
	"LEFT",
	UDim2.fromOffset(0, buttonSize + gap),
	Color3.fromRGB(86, 212, 255)
)
local steerRightButton = makeButton(
	leftPanel,
	"SteerRight",
	"RIGHT",
	UDim2.fromOffset(buttonSize + gap, buttonSize + gap),
	Color3.fromRGB(86, 212, 255)
)
local brakeButton = makeButton(
	rightPanel,
	"Brake",
	"BRAKE",
	UDim2.fromOffset(0, buttonSize + gap),
	Color3.fromRGB(255, 112, 112)
)
local accelerateButton = makeButton(
	rightPanel,
	"Accelerate",
	"GAS",
	UDim2.fromOffset(buttonSize + gap, buttonSize + gap),
	Color3.fromRGB(136, 255, 136)
)

local boostFrame = Instance.new("Frame")
boostFrame.Name = "BoostFrame"
boostFrame.Size = UDim2.fromOffset(panelWidth, buttonSize)
boostFrame.Position = UDim2.fromOffset(0, 0)
boostFrame.BackgroundColor3 = Color3.fromRGB(15, 21, 31)
boostFrame.BackgroundTransparency = 0.18
boostFrame.BorderSizePixel = 0
boostFrame.Parent = rightPanel

local boostCorner = Instance.new("UICorner")
boostCorner.CornerRadius = UDim.new(0, 18)
boostCorner.Parent = boostFrame

local boostStroke = Instance.new("UIStroke")
boostStroke.Color = Color3.fromRGB(255, 170, 76)
boostStroke.Thickness = 2
boostStroke.Parent = boostFrame

local boostButton = Instance.new("TextButton")
boostButton.Name = "Boost"
boostButton.Size = UDim2.fromScale(1, 1)
boostButton.BackgroundTransparency = 1
boostButton.AutoButtonColor = false
boostButton.Font = Enum.Font.GothamBold
boostButton.Text = "BOOST"
boostButton.TextColor3 = Color3.fromRGB(243, 247, 255)
boostButton.TextSize = math.clamp(math.floor(buttonSize * 0.26), 16, 28)
boostButton.Parent = boostFrame

buttonFrames.Boost = {
	Frame = boostFrame,
	Stroke = boostStroke,
	Button = boostButton,
	Accent = Color3.fromRGB(255, 170, 76),
}

bindHold(steerLeftButton, "SteerLeft")
bindHold(steerRightButton, "SteerRight")
bindHold(brakeButton, "Brake")
bindHold(accelerateButton, "Accelerate")
bindHold(boostButton, "Boost")

for action in pairs(buttonFrames) do
	refreshButton(action)
end

local currentSeat = nil
local seatedConnection = nil

local function isPlayerDriveSeat(seat)
	if not seat or seat.Name ~= "DriveSeat" then
		return false
	end

	return seat:FindFirstAncestor("Vehicle_" .. player.UserId) ~= nil
end

local function setCurrentSeat(seat)
	local nextSeat = if isPlayerDriveSeat(seat) then seat else nil
	if currentSeat == nextSeat then
		return
	end

	currentSeat = nextSeat
	screenGui.Enabled = currentSeat ~= nil

	if not currentSeat then
		releaseAllActions()
	end
end

local function connectCharacter(character)
	if seatedConnection then
		seatedConnection:Disconnect()
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

	local maxNitro = math.max(ControlState.MaxNitro, 0)
	local nitroRatio = 0
	if maxNitro > 0 then
		nitroRatio = math.clamp(ControlState.Nitro / maxNitro, 0, 1)
	end

	barFill.Size = UDim2.fromScale(nitroRatio, 1)
	barFill.BackgroundColor3 = if ControlState.IsCoolingDown
		then Color3.fromRGB(207, 95, 95)
		else Color3.fromRGB(255, 152, 72)

	if currentSeat == nil then
		statusLabel.Text = string.format("NITRO %d%%  |  Enter your vehicle", math.floor(nitroRatio * 100 + 0.5))
	elseif ControlState.IsCoolingDown then
		statusLabel.Text = string.format("NITRO %d%%  |  Cooling down", math.floor(nitroRatio * 100 + 0.5))
	elseif ControlState.Boosting then
		statusLabel.Text = string.format("NITRO %d%%  |  Boost active", math.floor(nitroRatio * 100 + 0.5))
	else
		statusLabel.Text = string.format("NITRO %d%%  |  Drive ready", math.floor(nitroRatio * 100 + 0.5))
	end

	refreshButton("Boost")
end)
