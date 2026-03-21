--[[
    ClientState.lua
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
--]]

local State = {
    isInRace = false,
    currentCheckpoint = 0,
    totalCheckpoints = 0,
    raceStartTime = 0,
    currentMapId = nil,
    ownedVehicles = {},
    ownedPaints = {},
    ownedMaps = {},
    coins = 0,
    hasBoost = false,
    equippedVehicle = "cybertruck",
    equippedPaint = "Default",
    hudVisible = false,
    lastRaceResult = nil,
}

local listeners = {}

local ClientState = {}

function ClientState.Get(key)
    return State[key]
end

function ClientState.Set(key, value)
    local old = State[key]
    State[key] = value

    if old ~= value and listeners[key] then
        for _, callback in ipairs(listeners[key]) do
            local ok, err = pcall(callback, value, old)
            if not ok then
                warn(string.format("[ClientState] OnChange callback error for '%s': %s", key, tostring(err)))
            end
        end
    end
end

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
