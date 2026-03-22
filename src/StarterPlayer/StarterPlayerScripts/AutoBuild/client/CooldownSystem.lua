local RunService = game:GetService("RunService")

local ControlState = require(script.Parent.Parent.shared.ControlState)

RunService.RenderStepped:Connect(function()
	local maxNitro = math.max(ControlState.MaxNitro, 0)
	ControlState.Nitro = math.clamp(ControlState.Nitro, 0, maxNitro)

	if ControlState.Boosting and ControlState.Nitro <= 0 then
		ControlState.Boosting = false
		ControlState.IsCoolingDown = true
	elseif ControlState.IsCoolingDown and ControlState.Nitro >= maxNitro then
		ControlState.IsCoolingDown = false
	end

	if ControlState.IsCoolingDown then
		ControlState.Boosting = false
	end
end)
