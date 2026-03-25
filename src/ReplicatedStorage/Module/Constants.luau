--[[
    Constants.lua
    Description: Single source of truth for all game constants. No magic numbers elsewhere.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - None

    Events Fired:
        - None

    Events Listened:
        - None
--]]

local Constants = {}

-- ── Vehicle ───────────────────────────────────────────────────────────────────
Constants.VEHICLE_NAME_FORMAT   = "Vehicle_%d"      -- %d = UserId
Constants.DEFAULT_VEHICLE_ID    = 1                 -- Cybertruck
Constants.VEHICLE_SPAWN_OFFSET  = Vector3.new(0, 5, 0)

-- ── Maps ──────────────────────────────────────────────────────────────────────
Constants.MAP_FOLDER_PREFIX     = "Map_"
Constants.DEFAULT_MAP_ID        = "skyscraper"

-- ── DataStore ─────────────────────────────────────────────────────────────────
Constants.DATASTORE_NAME        = "PlayerData_v1"
Constants.DATASTORE_KEY_FORMAT  = "Player_%d"       -- %d = UserId (capital P)
Constants.DATASTORE_RETRY_ATTEMPTS = 3
Constants.DATASTORE_RETRY_DELAY = 1                 -- seconds between retries

-- ── Race ──────────────────────────────────────────────────────────────────────
Constants.CHECKPOINT_FINISH     = 99
Constants.MIN_RACE_TIME         = 5                 -- seconds; anti-cheat floor
Constants.MAX_RACE_TIME         = 600               -- 10 minutes; timeout

-- ── Coins ─────────────────────────────────────────────────────────────────────
Constants.COIN_BASE_REWARD          = 50
Constants.COIN_PERSONAL_BEST_BONUS  = 100
Constants.COIN_BEAT_TARGET_BONUS    = 150
Constants.COIN_FIRST_COMPLETION_BONUS = 200
Constants.COIN_BOOST_MULTIPLIER     = 1.5

-- Legacy coin reward values (kept for backward-compat with CoinHandler logic)
Constants.COINS_FIRST_COMPLETION = 100   -- first time completing a map
Constants.COINS_REPEAT           = 25    -- all subsequent completions

-- ── UI ────────────────────────────────────────────────────────────────────────
Constants.HUD_TWEEN_DURATION    = 0.4
Constants.NOTIFICATION_DURATION = 2
Constants.NOTIFICATION_FADE_IN  = 0.2
Constants.NOTIFICATION_FADE_OUT = 0.5

-- ── Colours ───────────────────────────────────────────────────────────────────
Constants.CYAN    = Color3.fromRGB(74, 240, 255)
Constants.DARK_BG = Color3.fromRGB(20, 20, 25)
Constants.GOLD    = Color3.fromRGB(255, 200, 0)
Constants.WHITE   = Color3.new(1, 1, 1)

-- ── Folder paths ──────────────────────────────────────────────────────────────
Constants.REMOTES_PATH = "Events"
Constants.SHARED_PATH  = "Module"

return Constants
