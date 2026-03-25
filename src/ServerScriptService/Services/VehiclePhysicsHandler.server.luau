--!strict
-- SCRIPT: VehiclePhysicsHandler | LOCATION: ServerScriptService/Services | SIDE: Server
-- Receives sanitized vehicle input from clients and applies physics
-- Part of the Client-Server Input Split architecture

-- Constants
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

local function findDriveSeat(vehicle: Model): VehicleSeat?
	-- Try named "DriveSeat" first (A-Chassis convention), fall back to any VehicleSeat
	local named = vehicle:FindFirstChild("DriveSeat", true)
	if named and named:IsA("VehicleSeat") then
		return named :: VehicleSeat
	end
	return vehicle:FindFirstChildWhichIsA("VehicleSeat", true) :: VehicleSeat?
end

local function applyPhysicsToVehicle(vehicle: Model, input: InputProcessor.VehicleInput): ()
	-- A-Chassis reads VehicleSeat.Throttle and .Steer natively via its own server
	-- Script and applies wheel forces internally.  Do NOT apply AngularVelocity to
	-- HingeConstraints here — that creates competing torques that cause uncontrolled
	-- drift and fight A-Chassis's physics system.
	local seat = findDriveSeat(vehicle)
	if not seat then return end

	-- Braking takes priority: negative throttle signals deceleration to A-Chassis.
	seat.Throttle = if input.brake > 0 then -input.brake else input.throttle
	seat.Steer    = input.steer
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
