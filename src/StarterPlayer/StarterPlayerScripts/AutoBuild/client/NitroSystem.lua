local RunService = game:GetService("RunService")

local ControlState = require(script.Parent.Parent.shared.ControlState)

local DRAIN_RATE = 25
local REGEN_RATE = 10

RunService.RenderStepped:Connect(function(dt)
	local maxNitro = math.max(ControlState.MaxNitro, 0)
	if maxNitro == 0 then
		ControlState.Nitro = 0
		ControlState.Boosting = false
		return
	end

	local nextNitro = ControlState.Nitro
	if ControlState.Boosting then
		nextNitro -= DRAIN_RATE * dt
	else
		nextNitro += REGEN_RATE * dt
	end

	ControlState.Nitro = math.clamp(nextNitro, 0, maxNitro)
end)
