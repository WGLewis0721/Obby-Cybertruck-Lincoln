--[[
    EconomyConfig.luau
    Description: Single source of truth for all coin/reward balance values.
                 Change numbers here, not scattered through service scripts.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - None

    Events Fired:
        - None

    Events Listened:
        - None
--]]

local EconomyConfig = {}

-- ── Race completion rewards ──────────────────────────────────────────────────
EconomyConfig.FIRST_COMPLETION_REWARD  = 100  -- first time finishing a given map
EconomyConfig.REPEAT_COMPLETION_REWARD = 25   -- every completion after the first
EconomyConfig.PERSONAL_BEST_BONUS      = 50   -- extra coins for beating your own best time on that map

-- ── Track coin pickups ────────────────────────────────────────────────────────
EconomyConfig.COIN_PICKUP_VALUE        = 10   -- coins awarded per pickup collected
EconomyConfig.COIN_PICKUP_RESPAWN_TIME = 20   -- seconds before a collected pickup reappears

return EconomyConfig
