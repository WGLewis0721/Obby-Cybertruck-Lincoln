-- ── Map catalogue ─────────────────────────────────────────────────────────────
-- Type "Robux" – purchased via MarketplaceService:PromptProductPurchase.
--
-- ProductId values are placeholders (0) until real Developer Products are
-- created on the Roblox Creator Dashboard.
local MapData = {
	{
		Id             = "skyscraper",
		Name           = "Skyscraper",
		Description    = "Navigate surface streets and underground tunnels through a neon-lit city of towering skyscrapers.",
		Unlocked       = true,
		Type           = "Free",
		Price          = 0,
		ProductId      = 0,
		BestTimeTarget = 180,
		FolderName     = "SkyscraperMap",
		SpawnName      = "SkyscraperSpawn",
		Thumbnail      = "rbxassetid://0"
	},
	{
		Id             = "bigfoot",
		Name           = "Big Foot",
		Description    = "Wind your way up a mountain through dense forest into the snow-capped summit. Off-road only.",
		Unlocked       = false,
		Type           = "Robux",
		Price          = 199,
		ProductId      = 0, -- replace with real Developer Product ID
		BestTimeTarget = 240,
		FolderName     = "BigFootMap",
		SpawnName      = "BigFootSpawn",
		Thumbnail      = "rbxassetid://0"
	},
	{
		Id             = "highspeed",
		Name           = "High Speed",
		Description    = "A full street circuit built for pure speed. Grandstands, DRS zone, chicane and a brutal hairpin.",
		Unlocked       = false,
		Type           = "Robux",
		Price          = 299,
		ProductId      = 0, -- replace with real Developer Product ID
		BestTimeTarget = 120,
		FolderName     = "HighSpeedMap",
		SpawnName      = "HighSpeedSpawn",
		Thumbnail      = "rbxassetid://0"
	},
}

return MapData
