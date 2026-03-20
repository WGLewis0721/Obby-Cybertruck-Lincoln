-- ── Map catalogue ─────────────────────────────────────────────────────────────
-- Type "Robux" – purchased via MarketplaceService:PromptProductPurchase.
--
-- ProductId values are placeholders (0) until real Developer Products are
-- created on the Roblox Creator Dashboard.
--
-- GeneratorModule – the ModuleScript name (in ServerScriptService) responsible
-- for procedurally generating this map's terrain and obstacles.
local MapData = {
	{
		Name            = "Big Foot",
		Type            = "Robux",
		Description     = "Conquer rugged mountain peaks and thick forest terrain.",
		BestTimeTarget  = 150,
		Pic             = "rbxassetid://0",
		ProductId       = 0, -- placeholder – replace with real Developer Product ID
		Price           = 199,
		GeneratorModule = "GenerateMountainMap",
	},
	{
		Name            = "Skyscraper",
		Type            = "Robux",
		Description     = "Scale towering city skyscrapers and narrow urban ledges.",
		BestTimeTarget  = 120,
		Pic             = "rbxassetid://0",
		ProductId       = 0, -- placeholder – replace with real Developer Product ID
		Price           = 249,
		GeneratorModule = "GenerateCityMap",
	},
	{
		Name            = "High Speed",
		Type            = "Robux",
		Description     = "A blazing-fast race track built for the Cybertruck.",
		BestTimeTarget  = 90,
		Pic             = "rbxassetid://0",
		ProductId       = 0, -- placeholder – replace with real Developer Product ID
		Price           = 299,
		GeneratorModule = "GenerateRaceTrackMap",
	},
}

return MapData
