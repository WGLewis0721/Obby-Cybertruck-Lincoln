-- MapSelectHandler: simplified for default map testing
-- Map generation is disabled. Using default Roblox Workspace.
local function onPlayerAdded(player)
    print("MapSelectHandler: player joined, using default map")
end

game:GetService("Players").PlayerAdded:Connect(onPlayerAdded)
print("MapSelectHandler: ready - using default map")
