local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ControlState = require(script.Parent.Parent.shared.ControlState)

local RUNTIME_EVENT_NAME = "AutoBuildUIInput"

local KEYCODE_TO_ACTION = {
	[Enum.KeyCode.W] = "Accelerate",
	[Enum.KeyCode.Up] = "Accelerate",
	[Enum.KeyCode.ButtonR2] = "Accelerate",
	[Enum.KeyCode.S] = "Brake",
	[Enum.KeyCode.Down] = "Brake",
	[Enum.KeyCode.ButtonL2] = "Brake",
	[Enum.KeyCode.LeftShift] = "Boost",
	[Enum.KeyCode.RightShift] = "Boost",
	[Enum.KeyCode.ButtonX] = "Boost",
	[Enum.KeyCode.A] = "SteerLeft",
	[Enum.KeyCode.Left] = "SteerLeft",
	[Enum.KeyCode.D] = "SteerRight",
	[Enum.KeyCode.Right] = "SteerRight",
}

local activeInputs = {
	Accelerate = {},
	Brake = {},
	Boost = {},
	SteerLeft = {},
	SteerRight = {},
}

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

local function hasActiveInput(bucket)
	return next(bucket) ~= nil
end

local function updateThrottleAndBrake()
	ControlState.Accelerating = hasActiveInput(activeInputs.Accelerate)
	ControlState.Braking = hasActiveInput(activeInputs.Brake)
end

local function updateSteering()
	local leftDown = hasActiveInput(activeInputs.SteerLeft)
	local rightDown = hasActiveInput(activeInputs.SteerRight)

	if leftDown == rightDown then
		ControlState.Steering = 0
	elseif leftDown then
		ControlState.Steering = -1
	else
		ControlState.Steering = 1
	end
end

local function updateBoosting()
	ControlState.Boosting = hasActiveInput(activeInputs.Boost)
		and ControlState.Nitro > 0
		and not ControlState.IsCoolingDown
end

local function applyActionState(action, sourceId, isDown)
	local bucket = activeInputs[action]
	if not bucket then
		return
	end

	if isDown then
		bucket[sourceId] = true
	else
		bucket[sourceId] = nil
	end

	if action == "Accelerate" or action == "Brake" then
		updateThrottleAndBrake()
		return
	end

	if action == "Boost" then
		updateBoosting()
		return
	end

	updateSteering()
end

local function clearAllInputs()
	for _, bucket in pairs(activeInputs) do
		table.clear(bucket)
	end

	updateThrottleAndBrake()
	updateSteering()
	updateBoosting()
end

local function setKeyState(keyCode, isDown)
	local action = KEYCODE_TO_ACTION[keyCode]
	if not action then
		return
	end

	applyActionState(action, "KeyCode:" .. keyCode.Name, isDown)
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	setKeyState(input.KeyCode, true)
end)

UserInputService.InputEnded:Connect(function(input)
	setKeyState(input.KeyCode, false)
end)

inputRelay.Event:Connect(function(action, isDown, sourceId)
	if type(action) ~= "string" or type(isDown) ~= "boolean" then
		return
	end

	applyActionState(action, sourceId or "UI", isDown)
end)

game:GetService("GuiService").MenuOpened:Connect(clearAllInputs)
RunService.RenderStepped:Connect(updateBoosting)
