local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Logger = require(ReplicatedStorage:WaitForChild("Module"):WaitForChild("Logger"))

local VehicleTemplateFactory = {}

local TAG = "VehicleTemplateFactory"
local DEFAULT_TEMPLATE_NAME = "Tesla Cybertruck"

local function findDriveSeat(model)
	local namedSeat = model:FindFirstChild("DriveSeat", true)
	if namedSeat and namedSeat:IsA("VehicleSeat") then
		return namedSeat
	end

	return model:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function configureDriveSeat(seat)
	if not seat then
		return
	end

	seat.Name = "DriveSeat"
	seat.MaxSpeed = 60
	seat.Torque = 20
	seat.TurnSpeed = 1
	seat.HeadsUpDisplay = false
	seat.Disabled = false
end

local function anchorModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function setInitializeScriptDisabled(model, isDisabled)
	local initializeScript = model:FindFirstChild("Initialize", true)
	if initializeScript and initializeScript:IsA("Script") then
		initializeScript.Disabled = isDisabled
	end
end

local function validateVehicleModel(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local driveSeat = findDriveSeat(model)
	if not driveSeat then
		Logger.Warn(TAG, "Vehicle template '%s' is missing a VehicleSeat", model.Name)
		return nil
	end

	return driveSeat
end

function VehicleTemplateFactory.EnsureTemplate(modelName)
	local resolvedName = modelName or DEFAULT_TEMPLATE_NAME
	local modelTemplate = ServerStorage:FindFirstChild(resolvedName)
	if not modelTemplate or not modelTemplate:IsA("Model") then
		Logger.Warn(TAG, "Vehicle template '%s' not found in ServerStorage", tostring(resolvedName))
		return nil
	end

	local driveSeat = validateVehicleModel(modelTemplate)
	if not driveSeat then
		return nil
	end

	configureDriveSeat(driveSeat)
	modelTemplate.PrimaryPart = driveSeat
	anchorModel(modelTemplate)
	setInitializeScriptDisabled(modelTemplate, true)

	return modelTemplate
end

function VehicleTemplateFactory.PrepareForSpawn(model)
	local driveSeat = validateVehicleModel(model)
	if not driveSeat then
		return nil, nil
	end

	configureDriveSeat(driveSeat)
	model.PrimaryPart = driveSeat
	anchorModel(model)
	setInitializeScriptDisabled(model, false)

	return driveSeat, model.PrimaryPart
end

return VehicleTemplateFactory
