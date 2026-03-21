local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logger"))

local TAG = "VehicleDriveService"
local SIMPLE_TEMPLATE_ATTRIBUTE = "SimpleVehicleTemplate"

local function getDriveSeat(model)
	local namedSeat = model:FindFirstChild("DriveSeat", true)
	if namedSeat and namedSeat:IsA("VehicleSeat") then
		return namedSeat
	end

	return model:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function ensureMover(root, className, name)
	local mover = root:FindFirstChild(name)
	if mover and not mover:IsA(className) then
		mover:Destroy()
		mover = nil
	end

	if not mover then
		mover = Instance.new(className)
		mover.Name = name
		mover.Parent = root
	end

	return mover
end

local function driveSimpleVehicle(model)
	if not model:IsA("Model") or not model:GetAttribute(SIMPLE_TEMPLATE_ATTRIBUTE) then
		return
	end

	local seat = getDriveSeat(model)
	local root = model.PrimaryPart or seat
	if not seat or not root then
		return
	end

	local bodyVelocity = ensureMover(root, "BodyVelocity", "DriveVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
	bodyVelocity.P = 1e4

	local bodyAngularVelocity = ensureMover(root, "BodyAngularVelocity", "DriveAngular")
	bodyAngularVelocity.MaxTorque = Vector3.new(0, 1e4, 0)
	bodyAngularVelocity.P = 1e4

	if not seat.Occupant then
		bodyVelocity.Velocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		bodyAngularVelocity.AngularVelocity = Vector3.zero
		return
	end

	local throttle = math.abs(seat.ThrottleFloat) > 0 and seat.ThrottleFloat or seat.Throttle
	local steer = math.abs(seat.SteerFloat) > 0 and seat.SteerFloat or seat.Steer
	local forward = root.CFrame.LookVector * throttle * 60
	local angular = steer * 1.5

	bodyVelocity.Velocity = Vector3.new(forward.X, root.AssemblyLinearVelocity.Y, forward.Z)
	bodyAngularVelocity.AngularVelocity = Vector3.new(0, -angular, 0)
end

RunService.Heartbeat:Connect(function()
	for _, child in ipairs(Workspace:GetChildren()) do
		driveSimpleVehicle(child)
	end
end)

Logger.Info(TAG, "VehicleDriveService ready")
