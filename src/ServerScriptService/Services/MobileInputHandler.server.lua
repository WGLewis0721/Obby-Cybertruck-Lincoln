--!strict
--[[
    MobileInputHandler.server.lua
    Description: Receives MobileThrottle events from mobile clients and sets
                 VehicleSeat.Throttle directly on the server.

    Why server-side?
    ────────────────
    Roblox's native VehicleController runs on the CLIENT and resets
    VehicleSeat.Throttle = 0 every frame when it detects no keyboard / joystick
    input (normal on mobile).  A server Script setting Throttle is authoritative
    and is not competed with by the client-side VehicleController — so A-Chassis's
    server Script reads the correct value and applies the drive force.

    Events Listened:
        - Events.MobileThrottle (C→S, value: 1 = throttle on, 0 = off)
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger            = require(ReplicatedStorage:WaitForChild("Module"):WaitForChild("Logger"))

local TAG = "MobileInputHandler"

local eventsFolder   = ReplicatedStorage:WaitForChild("Events")
local mobileThrottle = eventsFolder:WaitForChild("MobileThrottle")

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getDriveSeat(player: Player): VehicleSeat?
	local vehicle = workspace:FindFirstChild("Vehicle_" .. player.UserId)
	if not vehicle then return nil end
	-- Try named "DriveSeat" first (matches the seat-detection check in MobileControls)
	local named = vehicle:FindFirstChild("DriveSeat", true)
	if named and named:IsA("VehicleSeat") then return named :: VehicleSeat end
	return vehicle:FindFirstChildWhichIsA("VehicleSeat", true) :: VehicleSeat?
end

local function isPlayerInSeat(player: Player, seat: VehicleSeat): boolean
	local character = player.Character
	if not character then return false end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	return humanoid ~= nil and humanoid.SeatPart == seat
end

-- ── MobileThrottle handler ────────────────────────────────────────────────────
-- throttleValue: 1 (button pressed) or 0 (button released)
mobileThrottle.OnServerEvent:Connect(function(player, throttleValue)
	-- Validate type and range
	if type(throttleValue) ~= "number" then return end
	throttleValue = math.clamp(math.round(throttleValue), 0, 1)

	local seat = getDriveSeat(player)
	if not seat then
		Logger.Warn(TAG, "MobileThrottle from %s — vehicle / seat not found", player.Name)
		return
	end

	-- Security: only apply if this player is actually the occupant
	if not isPlayerInSeat(player, seat) then
		Logger.Warn(TAG, "MobileThrottle from %s — player is not in DriveSeat", player.Name)
		return
	end

	seat.Throttle = throttleValue
end)

-- ── Reset throttle when the player leaves ─────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	local seat = getDriveSeat(player)
	if seat then
		seat.Throttle = 0
	end
end)

Logger.Info(TAG, "MobileInputHandler ready")
