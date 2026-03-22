local RunService = game:GetService("RunService")

local ControlState = require(script.Parent.Parent.shared.ControlState)

local function normalizeSteering()
	local steering = ControlState.Steering
	if type(steering) ~= "number" then
		ControlState.Steering = 0
		return
	end

	if steering > 0 then
		ControlState.Steering = 1
	elseif steering < 0 then
		ControlState.Steering = -1
	else
		ControlState.Steering = 0
	end
end

RunService.RenderStepped:Connect(normalizeSteering)
normalizeSteering()
