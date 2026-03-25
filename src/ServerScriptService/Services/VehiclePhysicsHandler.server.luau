--!strict
-- SCRIPT: VehiclePhysicsHandler | LOCATION: ServerScriptService/Services | SIDE: Server
-- Receives sanitized vehicle input from clients and applies physics
-- Part of the Client-Server Input Split architecture

-- Constants
local MAX_ANGULAR_VELOCITY: number = 50  -- Max wheel rotation speed
local MAX_STEER_ANGLE: number = 35  -- Max steering angle in degrees
local BRAKE_MULTIPLIER: number = 0.1  -- How much braking slows wheels
local INPUT_TIMEOUT: number = 0.5  -- Seconds before considering input stale

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Modules
local InputProcessor = require(ReplicatedStorage.Module.InputProcessor)

-- RemoteEvents
local Remotes = ReplicatedStorage:WaitForChild("Events", 10) :: Folder
local VehicleInput = Remotes:WaitForChild("VehicleInput", 10) :: RemoteEvent
local HUDUpdate = Remotes:FindFirstChild("HUDUpdate") :: RemoteEvent

-- State: player.UserId → last input + timestamp
type PlayerInputState = {
	input: InputProcessor.VehicleInput,
	timestamp: number,
}
local playerInputStates: {[number]: PlayerInputState} = {}

--------------------------------------------------------------------------------
-- VEHICLE PHYSICS APPLICATION
--------------------------------------------------------------------------------

local function findVehicleForPlayer(userId: number): Model?
	-- Vehicle naming convention: Vehicle_[UserId]
	local vehicleName = "Vehicle_" .. tostring(userId)
	return Workspace:FindFirstChild(vehicleName) :: Model
end

local function findHingeConstraints(vehicle: Model): (HingeConstraint?, HingeConstraint?, HingeConstraint?, HingeConstraint?)
	-- Find wheel HingeConstraints for drive and steering
	-- Typical A-Chassis structure: wheels are under vehicle with HingeConstraints
	local driveLeft: HingeConstraint? = nil
	local driveRight: HingeConstraint? = nil
	local steerLeft: HingeConstraint? = nil
	local steerRight: HingeConstraint? = nil
	
	for _, descendant in ipairs(vehicle:GetDescendants()) do
		if descendant:IsA("HingeConstraint") then
			local hinge = descendant :: HingeConstraint
			local name = string.lower(hinge.Name)
			
			-- Drive wheels (rear)
			if string.find(name, "drive") or string.find(name, "rear") or string.find(name, "back") then
				if string.find(name, "left") then
					driveLeft = hinge
				elseif string.find(name, "right") then
					driveRight = hinge
				end
			-- Steering wheels (front)
			elseif string.find(name, "steer") or string.find(name, "front") then
				if string.find(name, "left") then
					steerLeft = hinge
				elseif string.find(name, "right") then
					steerRight = hinge
				end
			end
		end
	end
	
	return driveLeft, driveRight, steerLeft, steerRight
end

local function applyPhysicsToVehicle(vehicle: Model, input: InputProcessor.VehicleInput): ()
	local driveLeft, driveRight, steerLeft, steerRight = findHingeConstraints(vehicle)
	
	-- Apply throttle/brake to drive wheels
	local targetVelocity = input.throttle * MAX_ANGULAR_VELOCITY
	
	-- Braking reduces velocity
	if input.brake > 0 then
		targetVelocity = targetVelocity * (1 - input.brake * BRAKE_MULTIPLIER)
	end
	
	-- Apply to drive wheels
	if driveLeft then
		driveLeft.AngularVelocity = targetVelocity
	end
	if driveRight then
		driveRight.AngularVelocity = targetVelocity
	end
	
	-- Apply steering to front wheels
	local steerAngle = input.steer * MAX_STEER_ANGLE
	
	if steerLeft then
		steerLeft.LowerAngle = -steerAngle
		steerLeft.UpperAngle = steerAngle
	end
	if steerRight then
		steerRight.LowerAngle = -steerAngle
		steerRight.UpperAngle = steerAngle
	end
end

local function calculateVehicleSpeed(vehicle: Model): number
	-- Estimate speed from wheel velocity or primary part
	local primaryPart = vehicle.PrimaryPart
	if primaryPart then
		local velocity = primaryPart.AssemblyLinearVelocity
		return velocity.Magnitude * 2.237  -- Convert studs/sec to mph
	end
	return 0
end

--------------------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------------------

local function onVehicleInputFired(player: Player, throttle: number, steer: number, brake: number): ()
	-- Validate player
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	
	-- Sanitize input (server-side validation)
	local rawInput = {
		throttle = throttle,
		steer = steer,
		brake = brake,
	}
	local sanitized = InputProcessor.sanitize(rawInput)
	
	-- Store input state
	playerInputStates[player.UserId] = {
		input = sanitized,
		timestamp = os.clock(),
	}
end

--------------------------------------------------------------------------------
-- PHYSICS UPDATE LOOP
--------------------------------------------------------------------------------

local function updatePhysics(): ()
	local currentTime = os.clock()
	
	for userId, state in pairs(playerInputStates) do
		-- Skip stale inputs
		if currentTime - state.timestamp > INPUT_TIMEOUT then
			-- Clear stale input
			playerInputStates[userId] = nil
			continue
		end
		
		-- Find player's vehicle
		local vehicle = findVehicleForPlayer(userId)
		if not vehicle or not vehicle.Parent then
			continue
		end
		
		-- Apply physics
		applyPhysicsToVehicle(vehicle, state.input)
	end
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

local function onPlayerRemoving(player: Player): ()
	playerInputStates[player.UserId] = nil
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

-- Connect to VehicleInput RemoteEvent
VehicleInput.OnServerEvent:Connect(onVehicleInputFired)

-- Connect to player removal for cleanup
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Start physics update loop with throttled HUD updates
local lastHUDUpdate = 0
local HUD_UPDATE_INTERVAL = 0.1  -- Update HUD every 100ms instead of every frame

RunService.Heartbeat:Connect(function()
	updatePhysics()
	
	-- Throttle HUD updates to prevent event queue exhaustion
	if HUDUpdate then
		local currentTime = os.clock()
		if currentTime - lastHUDUpdate >= HUD_UPDATE_INTERVAL then
			lastHUDUpdate = currentTime
			for userId, state in pairs(playerInputStates) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					local vehicle = findVehicleForPlayer(userId)
					if vehicle and vehicle.Parent then
						local speed = calculateVehicleSpeed(vehicle)
						HUDUpdate:FireClient(player, speed, 0, 1)
					end
				end
			end
		end
	end
end)

print("[VehiclePhysicsHandler] Server physics handler initialized")
