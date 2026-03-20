--[[
    PlayerDataService.server.lua
    Description: Boot script that initialises the PlayerDataInterface module,
                 ensuring it loads before other services need it.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)

    Events Fired:
        - None (PlayerDataInterface fires PlayerDataLoaded via EventBus)

    Events Listened:
        - None
--]]

-- Requiring PlayerDataInterface here guarantees it initialises first,
-- setting up DataStore connections and the player cache before any other
-- service script runs its own PlayerAdded logic.
local PlayerDataInterface = require(script.Parent:WaitForChild("PlayerDataInterface", 10))

-- Expose on script for runtime diagnostics (optional; other scripts use require)
script:SetAttribute("Ready", true)

print("PlayerDataService: ready — PlayerDataInterface initialised")

return PlayerDataInterface
