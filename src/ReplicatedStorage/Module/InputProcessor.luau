--!strict
-- SCRIPT: InputProcessor | LOCATION: ReplicatedStorage/Shared | SIDE: Shared
-- Pure logic module for sanitizing and processing vehicle input
-- No Roblox service calls — pure functions with no side effects

-- Constants for input validation
local MIN_THROTTLE: number = -1
local MAX_THROTTLE: number = 1
local MIN_STEER: number = -1
local MAX_STEER: number = 1
local MIN_BRAKE: number = 0
local MAX_BRAKE: number = 1

-- Type definition for vehicle input payload
export type VehicleInput = {
	throttle: number,  -- forward/reverse: clamped to [-1, 1]
	steer: number,     -- left/right: clamped to [-1, 1]
	brake: number,     -- braking force: clamped to [0, 1]
}

-- Module table
local InputProcessor = {}

--------------------------------------------------------------------------------
-- InputProcessor.sanitize(rawInput: unknown): VehicleInput
--
-- Purpose: Accept anything the client sends, return a safe VehicleInput.
-- This is the security gate between untrusted client input and server physics.
--
-- Why it exists: Without validation, a malicious or buggy client could send
-- garbage values like {throttle: 9999, steer: "hello", brake: nil} which would
-- break physics or crash scripts.
--
-- Logic:
-- 1. If rawInput is not a table → return zero input
-- 2. For each field: validate type, check for NaN, clamp to valid range
-- 3. Return the sanitized VehicleInput table
--------------------------------------------------------------------------------

function InputProcessor.sanitize(rawInput: unknown): VehicleInput
	-- Step 1: Guard clause — if not a table, return zero input
	if typeof(rawInput) ~= "table" then
		return {
			throttle = 0,
			steer = 0,
			brake = 0,
		}
	end

	-- Step 2: Extract and validate each field
	local rawTable: table = rawInput :: table

	-- Helper function to safely extract a number
	local function safeNumber(value: unknown, min: number, max: number): number
		-- If not a number, substitute 0
		if typeof(value) ~= "number" then
			return 0
		end

		local numValue: number = value :: number

		-- Check for NaN (NaN is the only value not equal to itself)
		if numValue ~= numValue then
			return 0
		end

		-- Clamp to valid range
		return math.clamp(numValue, min, max)
	end

	-- Step 3: Build sanitized input
	return {
		throttle = safeNumber(rawTable.throttle, MIN_THROTTLE, MAX_THROTTLE),
		steer = safeNumber(rawTable.steer, MIN_STEER, MAX_STEER),
		brake = safeNumber(rawTable.brake, MIN_BRAKE, MAX_BRAKE),
	}
end

--------------------------------------------------------------------------------
-- InputProcessor.isZero(input: VehicleInput): boolean
--
-- Purpose: Returns true if all three values are 0 (no active input).
--
-- Why it exists: Performance optimization. When there is no input, we can
-- skip physics updates entirely, avoiding unnecessary constraint updates.
-- This is especially important for idle vehicles that aren't being controlled.
--------------------------------------------------------------------------------

function InputProcessor.isZero(input: VehicleInput): boolean
	return input.throttle == 0 and input.steer == 0 and input.brake == 0
end

--------------------------------------------------------------------------------
-- InputProcessor.lerp(current: VehicleInput, target: VehicleInput, alpha: number): VehicleInput
--
-- Purpose: Smoothly interpolate between two input states.
--
-- Why it exists: Prevents instant steering snaps and throttle spikes.
-- Without interpolation, input changes are jarring and can cause physics jitter.
-- Lerp provides smooth transitions for a better driving feel.
--
-- Formula: lerped = current + (target - current) * alpha
-- Alpha is clamped to [0, 1] internally (0 = current, 1 = target)
--------------------------------------------------------------------------------

function InputProcessor.lerp(current: VehicleInput, target: VehicleInput, alpha: number): VehicleInput
	-- Clamp alpha to valid range
	local clampedAlpha: number = math.clamp(alpha, 0, 1)

	return {
		throttle = current.throttle + (target.throttle - current.throttle) * clampedAlpha,
		steer = current.steer + (target.steer - current.steer) * clampedAlpha,
		brake = current.brake + (target.brake - current.brake) * clampedAlpha,
	}
end

--------------------------------------------------------------------------------
-- InputProcessor.zero(): VehicleInput
--
-- Purpose: Returns a zero input table. Convenience function.
--
-- Why it exists: Useful for initializing input state or resetting.
--------------------------------------------------------------------------------

function InputProcessor.zero(): VehicleInput
	return {
		throttle = 0,
		steer = 0,
		brake = 0,
	}
end

--------------------------------------------------------------------------------
-- InputProcessor.copy(input: VehicleInput): VehicleInput
--
-- Purpose: Creates a shallow copy of a VehicleInput.
--
-- Why it exists: Useful when you need to modify input without affecting
-- the original table (e.g., for prediction or interpolation).
--------------------------------------------------------------------------------

function InputProcessor.copy(input: VehicleInput): VehicleInput
	return {
		throttle = input.throttle,
		steer = input.steer,
		brake = input.brake,
	}
end

return InputProcessor
