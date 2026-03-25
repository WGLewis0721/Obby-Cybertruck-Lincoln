--[[
    EventBus.lua
    Description: Centralized server-side pub-sub event system. All server scripts
                 communicate through this module instead of direct dependencies.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - Logger (ReplicatedStorage.Shared.Logger)

    Events Fired:
        - (All game events are routed through this module)

    Events Listened:
        - (All game events are routed through this module)

    Usage:
        local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
        local EventBus = require(sharedFolder:WaitForChild("EventBus", 10))
        EventBus:On("RaceFinished", function(player, mapId, elapsed) end)
        EventBus:Fire("RaceFinished", player, mapId, elapsed)
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Logger       = require(sharedFolder:WaitForChild("Logger", 10))

local TAG = "EventBus"

-- ── Internal state ────────────────────────────────────────────────────────────
-- handlers[eventName] = { callback1, callback2, ... }
local handlers = {}

-- ── EventBus ──────────────────────────────────────────────────────────────────
local EventBus = {}

--[[
    EventBus:On(eventName, callback)
    Register a callback to be invoked whenever eventName is fired.
    The callback receives all arguments passed to Fire().
--]]
function EventBus:On(eventName, callback)
	if type(eventName) ~= "string" or #eventName == 0 then
		Logger.Warn(TAG, "On: invalid eventName")
		return
	end
	if type(callback) ~= "function" then
		Logger.Warn(TAG, "On: callback is not a function for event '%s'", eventName)
		return
	end
	if not handlers[eventName] then
		handlers[eventName] = {}
	end
	table.insert(handlers[eventName], callback)
	Logger.Debug(TAG, "Registered handler for '%s' (total=%d)", eventName, #handlers[eventName])
end

--[[
    EventBus:Fire(eventName, ...)
    Invoke all registered handlers for eventName, each in its own task.spawn
    so a failing callback cannot break other handlers.
--]]
function EventBus:Fire(eventName, ...)
	if type(eventName) ~= "string" or #eventName == 0 then
		Logger.Warn(TAG, "Fire: invalid eventName")
		return
	end
	local list = handlers[eventName]
	if not list then
		-- No handlers registered – not necessarily an error.
		Logger.Debug(TAG, "Fire '%s' with no listeners", eventName)
		return
	end
	local args = { ... }
	for _, cb in ipairs(list) do
		task.spawn(function()
			local ok, err = pcall(cb, table.unpack(args))
			if not ok then
				Logger.Error(TAG, "Handler error for '%s': %s", eventName, tostring(err))
			end
		end)
	end
end

--[[
    EventBus:Once(eventName, callback)
    Like On, but the callback is removed after the first invocation.
--]]
function EventBus:Once(eventName, callback)
	local function wrapper(...)
		callback(...)
		-- Remove this wrapper from the handler list
		if handlers[eventName] then
			for i, cb in ipairs(handlers[eventName]) do
				if cb == wrapper then
					table.remove(handlers[eventName], i)
					break
				end
			end
		end
	end
	self:On(eventName, wrapper)
end

Logger.Info(TAG, "EventBus module loaded")
return EventBus
