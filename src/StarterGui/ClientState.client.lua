--[[
    ClientState.client.lua
    Description: Centralized client-side state store. All client scripts share
                 state through this module instead of maintaining isolated locals.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - None

    Events Fired:
        - None

    Events Listened:
        - None

    Usage:
        local ClientState = require(game.Players.LocalPlayer.PlayerGui:WaitForChild("ClientState"))
        -- NOTE: Because LocalScripts can't be required directly, other client scripts
        -- access shared state by listening to RemoteHandler-fired BindableEvents,
        -- or by reading the ClientState module if running in the same context.
--]]

-- ── Initial state ─────────────────────────────────────────────────────────────
local State = {
	isInRace           = false,
	currentCheckpoint  = 0,
	totalCheckpoints   = 0,
	raceStartTime      = 0,
	currentMapId       = nil,
	ownedVehicles      = {},
	ownedPaints        = {},
	ownedMaps          = {},
	coins              = 0,
	hasBoost           = false,
	equippedVehicle    = "cybertruck",
	equippedPaint      = "Default",
	hudVisible         = false,

	-- Race result (populated when RaceFinished fires)
	lastRaceResult     = nil,
}

-- ── Change listeners ──────────────────────────────────────────────────────────
-- listeners[key] = { callback1, callback2, ... }
local listeners = {}

-- ── ClientState module ────────────────────────────────────────────────────────
local ClientState = {}

--[[
    ClientState.Get(key) → value
    Returns the current value for the given state key.
--]]
function ClientState.Get(key)
	return State[key]
end

--[[
    ClientState.Set(key, value)
    Updates the state value and fires all registered OnChange callbacks for key.
--]]
function ClientState.Set(key, value)
	local old = State[key]
	State[key] = value
	if old ~= value and listeners[key] then
		for _, cb in ipairs(listeners[key]) do
			local ok, err = pcall(cb, value, old)
			if not ok then
				warn(string.format("[ClientState] OnChange callback error for '%s': %s", key, tostring(err)))
			end
		end
	end
end

--[[
    ClientState.OnChange(key, callback)
    Registers a callback that fires whenever the value for 'key' changes.
    Callback signature: callback(newValue, oldValue)
--]]
function ClientState.OnChange(key, callback)
	if type(callback) ~= "function" then
		warn("[ClientState] OnChange: callback is not a function for key '" .. tostring(key) .. "'")
		return
	end
	if not listeners[key] then
		listeners[key] = {}
	end
	table.insert(listeners[key], callback)
end

return ClientState
