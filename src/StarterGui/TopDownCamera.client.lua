--[[
	TopDownCamera.client.lua
	Description: Replaces the default chase camera with a fixed top-down view
	             (classic arcade racer style) while the local player is seated
	             in their vehicle. Takes exclusive Scriptable control of the
	             camera and disables the vehicle's own A-Chassis camera scripts
	             (Camera, AC6_MSteer_Camera) so they don't fight for control.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- None

	Events Fired:
		- None

	Events Listened:
		- Humanoid.Seated
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- ── Tuning ────────────────────────────────────────────────────────────────────
-- Standard racing-sim chase cam: close behind and just above the car, tilted
-- toward the horizon (Forza/Gran Turismo/NFS default view) -- not a top-down
-- or map-style camera.
local CAMERA_HEIGHT = 8         -- studs above the vehicle
local CAMERA_BACK_OFFSET = 20   -- studs behind the vehicle (along its facing direction)
local CAMERA_LOOK_AHEAD = 15    -- studs the camera aims ahead of the vehicle, not at it --
                                 -- keeps the car slightly low in frame with a clear view
                                 -- of the road ahead, instead of centering on the car
local CAMERA_FOLLOW_SPEED = 12  -- higher = camera catches up to the vehicle faster
local CAMERA_FOV = 70

local isDriving = false
local currentVehicle: Model? = nil
local defaultFOV = camera.FieldOfView

-- ── A-Chassis camera scripts fight for CameraType/CFrame every frame; remove
-- them (client-side only, doesn't affect other players) so our own control is
-- uncontested. The chassis clones its whole "A-Chassis Interface" (Drive,
-- Camera, AC6_MSteer_Camera, etc.) into PlayerGui when the player sits down --
-- the copy still sitting inside the vehicle model is an inert template, not
-- what's actually running, so we have to reach into PlayerGui for the real
-- one. Seating-event listener order between scripts isn't guaranteed, so wait
-- for it to appear rather than assuming it's already there.
local function disableChassisCameraScripts()
	task.spawn(function()
		local interfaceFolder = player:WaitForChild("PlayerGui"):WaitForChild("A-Chassis Interface", 5)
		if not interfaceFolder then
			return
		end

		local chassisCamera = interfaceFolder:FindFirstChild("Camera")
		if chassisCamera then
			chassisCamera:Destroy()
		end

		local mSteerCamera = interfaceFolder:FindFirstChild("AC6_MSteer_Camera")
		if mSteerCamera then
			mSteerCamera:Destroy()
		end
	end)
end

local function enterVehicle(vehicle: Model)
	currentVehicle = vehicle
	isDriving = true
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FOV
	disableChassisCameraScripts()
end

local function exitVehicle()
	isDriving = false
	currentVehicle = nil
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = defaultFOV
end

local function onSeated(isSeated: boolean, seat: BasePart?)
	if isSeated and seat and seat.Name == "DriveSeat" then
		local vehicleName = "Vehicle_" .. player.UserId
		local vehicle = seat:FindFirstAncestor(vehicleName)
		if vehicle then
			enterVehicle(vehicle :: Model)
			return
		end
	end
	if isDriving then
		exitVehicle()
	end
end

local function connectCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Seated:Connect(onSeated)

	-- Edge case: already seated when this script (re)connects
	if humanoid.SeatPart and humanoid.SeatPart.Name == "DriveSeat" then
		local vehicleName = "Vehicle_" .. player.UserId
		local vehicle = humanoid.SeatPart:FindFirstAncestor(vehicleName)
		if vehicle then
			enterVehicle(vehicle :: Model)
		end
	end
end

if player.Character then
	connectCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character: Model)
	if isDriving then
		exitVehicle()
	end
	connectCharacter(character)
end)

-- ── Camera update ─────────────────────────────────────────────────────────────
RunService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if not isDriving then
		return
	end

	local vehicle = currentVehicle
	if not vehicle or not vehicle.Parent then
		return
	end

	local driveSeat = vehicle:FindFirstChild("DriveSeat")
	if not driveSeat or not driveSeat:IsA("BasePart") then
		return
	end

	local vehiclePos = driveSeat.Position
	local vehicleLook = driveSeat.CFrame.LookVector

	local camPos = vehiclePos - (vehicleLook * CAMERA_BACK_OFFSET) + Vector3.new(0, CAMERA_HEIGHT, 0)
	local lookAtPos = vehiclePos + (vehicleLook * CAMERA_LOOK_AHEAD)
	local targetCFrame = CFrame.lookAt(camPos, lookAtPos)

	local alpha = math.clamp(CAMERA_FOLLOW_SPEED * dt, 0, 1)
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, alpha)
end)

player.CharacterRemoving:Connect(function()
	if isDriving then
		exitVehicle()
	end
end)
