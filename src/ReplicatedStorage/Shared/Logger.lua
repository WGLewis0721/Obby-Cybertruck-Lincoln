--[[
    Logger.lua
    Description: Centralized logging module used by all server and client scripts.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - None

    Events Fired:
        - None

    Events Listened:
        - None
--]]

local Logger = {}

-- ── Log levels (ascending severity) ──────────────────────────────────────────
local LEVELS = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

-- Change to "DEBUG" during development to see verbose output.
local CURRENT_LEVEL = LEVELS["INFO"]

-- ── Internal formatter ────────────────────────────────────────────────────────
local function format(tag, message, ...)
	local ok, formatted = pcall(string.format, message, ...)
	if ok then
		return string.format("[%s] %s", tag, formatted)
	end
	return string.format("[%s] %s", tag, message)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Logger.Debug(tag, message, ...)
	if CURRENT_LEVEL <= LEVELS.DEBUG then
		print(format(tag, message, ...))
	end
end

function Logger.Info(tag, message, ...)
	if CURRENT_LEVEL <= LEVELS.INFO then
		print(format(tag, message, ...))
	end
end

function Logger.Warn(tag, message, ...)
	if CURRENT_LEVEL <= LEVELS.WARN then
		warn(format(tag, message, ...))
	end
end

function Logger.Error(tag, message, ...)
	if CURRENT_LEVEL <= LEVELS.ERROR then
		-- error() would halt the calling coroutine; use warn() to stay non-fatal.
		warn("ERROR " .. format(tag, message, ...))
	end
end

return Logger
