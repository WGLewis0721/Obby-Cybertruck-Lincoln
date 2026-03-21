local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local vehicleTemplateFactory = require(ServerScriptService:WaitForChild("Services"):WaitForChild("VehicleTemplateFactory"))

-- Let Roblox handle the initial spawn normally. Forcing LoadCharacter here
-- creates duplicate CharacterAdded flows and double vehicle spawns.
Players.CharacterAutoLoads = true

-- Rojo is configured to keep unknown instances, so legacy root-level scripts can
-- survive in Studio after a refactor and double-run server logic. Remove the
-- old top-level service scripts if they are still present outside Services/.
local legacyRootScriptNames = {
	"GarageHandler",
	"PaintShopHandler",
	"CheckpointHandler",
	"MapSelectHandler",
	"CoinHandler",
	"TimerHandler",
	"PlayerDataService",
	"PlayerDataInterface",
}

for _, scriptName in ipairs(legacyRootScriptNames) do
	local legacyScript = ServerScriptService:FindFirstChild(scriptName)
	if legacyScript then
		legacyScript:Destroy()
		print(string.format("Removed legacy root script '%s' from ServerScriptService", scriptName))
	end
end

vehicleTemplateFactory.EnsureTemplate("Tesla Cybertruck")

print("CharacterAutoLoads enabled")
