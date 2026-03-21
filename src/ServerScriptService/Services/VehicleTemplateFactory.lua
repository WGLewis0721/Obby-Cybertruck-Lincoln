local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local VehicleTemplateFactory = {}

local TAG = "VehicleTemplateFactory"
local DEFAULT_TEMPLATE_NAME = "Tesla Cybertruck"
local SIMPLE_TEMPLATE_ATTRIBUTE = "SimpleVehicleTemplate"

local function findDriveSeat(model)
	local namedSeat = model:FindFirstChild("DriveSeat", true)
	if namedSeat and namedSeat:IsA("VehicleSeat") then
		return namedSeat
	end

	return model:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function choosePrimaryPart(model, driveSeat)
	local chassis = model:FindFirstChild("Chassis", true)
	if chassis and chassis:IsA("BasePart") then
		return chassis
	end

	if driveSeat then
		return driveSeat
	end

	local largestPart
	local largestVolume = -1
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = descendant
			end
		end
	end

	return largestPart
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
	seat.Anchored = false
	seat.CanCollide = false
	seat.Transparency = 0.15
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
end

local function unanchorModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

local function createWeld(part0, part1)
	local weld = Instance.new("WeldConstraint")
	weld.Name = part1.Name .. "Weld"
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part0
	return weld
end

local function makeWheel(name, position, parent)
	local wheel = Instance.new("Part")
	wheel.Name = name
	wheel.Shape = Enum.PartType.Cylinder
	wheel.Size = Vector3.new(3, 3, 2)
	wheel.Material = Enum.Material.Metal
	wheel.Color = Color3.fromRGB(28, 28, 30)
	wheel.Anchored = false
	wheel.CanCollide = true
	wheel.TopSurface = Enum.SurfaceType.Smooth
	wheel.BottomSurface = Enum.SurfaceType.Smooth
	wheel.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	wheel.Parent = parent
	return wheel
end

local function buildSimpleCybertruckTemplate()
	local model = Instance.new("Model")
	model.Name = DEFAULT_TEMPLATE_NAME
	model:SetAttribute(SIMPLE_TEMPLATE_ATTRIBUTE, true)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(16, 4, 7)
	chassis.Material = Enum.Material.Metal
	chassis.Color = Color3.fromRGB(109, 112, 118)
	chassis.Anchored = false
	chassis.CanCollide = true
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.CFrame = CFrame.new(0, 4, 0)
	chassis.Parent = model

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(8, 2, 6)
	cabin.Material = Enum.Material.Metal
	cabin.Color = Color3.fromRGB(124, 128, 134)
	cabin.Anchored = false
	cabin.CanCollide = true
	cabin.TopSurface = Enum.SurfaceType.Smooth
	cabin.BottomSurface = Enum.SurfaceType.Smooth
	cabin.CFrame = chassis.CFrame * CFrame.new(0, 2.5, -0.5)
	cabin.Parent = model

	local driveSeat = Instance.new("VehicleSeat")
	driveSeat.Name = "DriveSeat"
	driveSeat.Size = Vector3.new(4, 1, 4)
	driveSeat.Material = Enum.Material.SmoothPlastic
	driveSeat.Color = Color3.fromRGB(45, 48, 55)
	driveSeat.Anchored = false
	driveSeat.CanCollide = false
	driveSeat.CFrame = chassis.CFrame * CFrame.new(0, 2.75, 0.25)
	driveSeat.Parent = model
	configureDriveSeat(driveSeat)

	local wheelPositions = {
		Vector3.new(-5.5, 1.5, -3.5),
		Vector3.new(5.5, 1.5, -3.5),
		Vector3.new(-5.5, 1.5, 3.5),
		Vector3.new(5.5, 1.5, 3.5),
	}

	for index, position in ipairs(wheelPositions) do
		local wheel = makeWheel("Wheel" .. index, position, model)
		createWeld(chassis, wheel)
	end

	createWeld(chassis, cabin)
	createWeld(chassis, driveSeat)

	model.PrimaryPart = chassis

	return model
end

local function modelNeedsRebuild(model)
	if not model or not model:IsA("Model") then
		return true
	end

	local driveSeat = findDriveSeat(model)
	if not driveSeat then
		return true
	end

	if model.PrimaryPart == nil then
		return true
	end

	if driveSeat.Anchored then
		return true
	end

	if driveSeat.MaxSpeed <= 0 or driveSeat.Torque <= 0 or driveSeat.TurnSpeed <= 0 then
		return true
	end

	if driveSeat.HeadsUpDisplay then
		return true
	end

	if driveSeat.Size.X < 2 or driveSeat.Size.Z < 2 then
		return true
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Anchored then
			return true
		end
	end

	return false
end

function VehicleTemplateFactory.EnsureTemplate(modelName)
	local modelTemplate = ServerStorage:FindFirstChild(modelName)
	if modelName ~= DEFAULT_TEMPLATE_NAME then
		return modelTemplate
	end

	if modelNeedsRebuild(modelTemplate) then
		if modelTemplate then
			modelTemplate:Destroy()
		end

		modelTemplate = buildSimpleCybertruckTemplate()
		modelTemplate.Parent = ServerStorage
		Logger.Warn(TAG, "Rebuilt '%s' as a simple server-driven template", modelName)
	end

	return modelTemplate
end

function VehicleTemplateFactory.PrepareForSpawn(model)
	local driveSeat = findDriveSeat(model)
	configureDriveSeat(driveSeat)
	unanchorModel(model)

	local primaryPart = choosePrimaryPart(model, driveSeat)
	if primaryPart then
		model.PrimaryPart = primaryPart
	end

	return driveSeat, primaryPart
end

return VehicleTemplateFactory
