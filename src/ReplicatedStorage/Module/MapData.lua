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
local MapData = {
	{
		Id = "skyscraper",
		Name = "Skyscraper",
		Description = "Navigate surface streets and underground tunnels through a neon-lit city.",
		Unlocked = true,
		Type = "Free",
		Price = 0,
		ProductId = 0,
		BestTimeTarget = 180,
		FolderName = "CityMap",
		SpawnName = "CityMapSpawn",
		Thumbnail = "rbxassetid://0"
	},
	{
		Id = "big_foot",
		Name = "Big Foot",
		Description = "Wind your way up a mountain through dense forest into the snow-capped summit.",
		Unlocked = false,
		Type = "Robux",
		Price = 199,
		ProductId = 0, -- replace with real Developer Product ID
		BestTimeTarget = 240,
		FolderName = "MountainMap",
		SpawnName = "MountainMapSpawn",
		Thumbnail = "rbxassetid://0"
	},
	{
		Id = "high_speed",
		Name = "High Speed",
		Description = "A full street circuit with grandstands, DRS zone, chicane and hairpin.",
		Unlocked = false,
		Type = "Robux",
		Price = 299,
		ProductId = 0, -- replace with real Developer Product ID
		BestTimeTarget = 120,
		FolderName = "RaceTrackMap",
		SpawnName = "RaceTrackSpawn",
		Thumbnail = "rbxassetid://0"
	},
}

return MapData
