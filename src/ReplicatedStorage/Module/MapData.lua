-- ── Map catalogue ─────────────────────────────────────────────────────────────
-- Type "Free"  – unlocked by default for all players, never shown in the shop.
-- Type "Robux" – purchased via MarketplaceService:PromptProductPurchase.
--
-- ProductId values are placeholders (0) until real Developer Products are
-- created on the Roblox Creator Dashboard.
local MapData = {
	{
		Name           = "City Underground",
		Type           = "Free",
		Description    = "A dark urban underground track. Free for everyone.",
		BestTimeTarget = 120,
		Pic            = "rbxassetid://0",
		ProductId      = 0,
		Price          = 0,
	},
	{
		Name           = "Mountain & Forest",
		Type           = "Robux",
		Description    = "Wind through misty peaks and dense forest terrain.",
		BestTimeTarget = 150,
		Pic            = "rbxassetid://0",
		ProductId      = 0, -- placeholder – replace with real Developer Product ID
		Price          = 199,
	},
	{
		Name           = "Cybertruck Circuit",
		Type           = "Robux",
		Description    = "A high-speed circuit built for the Cybertruck.",
		BestTimeTarget = 90,
		Pic            = "rbxassetid://0",
		ProductId      = 0, -- placeholder – replace with real Developer Product ID
		Price          = 299,
	},
}

return MapData
