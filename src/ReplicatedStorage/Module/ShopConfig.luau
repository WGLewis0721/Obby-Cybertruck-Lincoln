--[[
	ShopConfig.luau
	Every purchasable item in one place: cars, paints and tracks.

	NOTE: cars are defined in Module.VehicleData, not here -- that is the single
	source of truth for vehicles (spawning, purchasing and the summon UI all read
	it). ShopConfig.Cars is kept only as descriptive tier metadata for shop copy.

	Each entry may carry:
	  CoinPrice - buyable with in-game Racing Coins (nil/0 = not sold for coins)
	  ProductId - Roblox Developer Product id for a Robux purchase (0 = not set up)
	Items can offer either or both. Robux ids of 0 are simply hidden in the UI
	until real Developer Products are created on the Creator Dashboard.
--]]

local ShopConfig = {}

-- ── Cars (descriptive tiers; authoritative data lives in VehicleData) ────────
ShopConfig.Cars = {
	{
		Id = 1, Name = "Cybertruck",  ModelName = "Tesla Cybertruck",
		CoinPrice = 0, ProductId = 0, OwnedByDefault = true,
		Stats = { TopSpeed = 120, Acceleration = 7.0, Handling = 6.5, Braking = 6.5 },
		Description = "The starter truck. Balanced and forgiving.",
	},
	{
		Id = 2, Name = "Street Racer", ModelName = "Tesla Cybertruck",
		CoinPrice = 7500, ProductId = 0,
		Stats = { TopSpeed = 145, Acceleration = 8.5, Handling = 7.5, Braking = 7.0 },
		Description = "Quick off the line and easy through traffic.",
	},
	{
		Id = 3, Name = "Sports Car", ModelName = "Tesla Cybertruck",
		CoinPrice = 20000, ProductId = 0,
		Stats = { TopSpeed = 165, Acceleration = 9.0, Handling = 8.5, Braking = 8.0 },
		Description = "Higher top speed with much better grip.",
	},
	{
		Id = 4, Name = "Supercar", ModelName = "Tesla Cybertruck",
		CoinPrice = 55000, ProductId = 0,
		Stats = { TopSpeed = 190, Acceleration = 9.5, Handling = 9.0, Braking = 9.0 },
		Description = "Serious performance for experienced drivers.",
	},
	{
		Id = 5, Name = "Hypercar", ModelName = "Tesla Cybertruck",
		CoinPrice = 150000, ProductId = 0,
		Stats = { TopSpeed = 220, Acceleration = 10, Handling = 9.5, Braking = 9.5 },
		Description = "Endgame machine. Nothing else keeps up.",
	},
}

-- ── Paints ───────────────────────────────────────────────────────────────────
-- Standard colours are coin-only. The three premium finishes keep their existing
-- Robux Developer Products AND accept coins, so both currencies work.
ShopConfig.Paints = {
	{ Name = "White",   Color = Color3.fromRGB(245, 245, 245), CoinPrice = 500,  ProductId = 0 },
	{ Name = "Black",   Color = Color3.fromRGB( 25,  25,  28), CoinPrice = 500,  ProductId = 0 },
	{ Name = "Silver",  Color = Color3.fromRGB(170, 173, 180), CoinPrice = 750,  ProductId = 0 },
	{ Name = "Red",     Color = Color3.fromRGB(200,  30,  40), CoinPrice = 1000, ProductId = 0 },
	{ Name = "Blue",    Color = Color3.fromRGB(  0,  85, 255), CoinPrice = 1000, ProductId = 3244953138 },
	{ Name = "Green",   Color = Color3.fromRGB(  0, 255,   0), CoinPrice = 1000, ProductId = 3244954061 },
	{ Name = "Yellow",  Color = Color3.fromRGB(250, 210,  40), CoinPrice = 1250, ProductId = 0 },
	{ Name = "Orange",  Color = Color3.fromRGB(255, 130,  20), CoinPrice = 1250, ProductId = 0 },
	{ Name = "Purple",  Color = Color3.fromRGB(140,  50, 210), CoinPrice = 1500, ProductId = 0 },
	{ Name = "Pink",    Color = Color3.fromRGB(255, 110, 190), CoinPrice = 1500, ProductId = 0 },
	{ Name = "Cyan",    Color = Color3.fromRGB( 60, 230, 245), CoinPrice = 1750, ProductId = 0 },
	{ Name = "Gold",    Color = Color3.fromRGB(255, 215,   0), CoinPrice = 5000, ProductId = 3244953838 },
}

-- ── Tracks ───────────────────────────────────────────────────────────────────
ShopConfig.Tracks = {
	{
		Id = "skyscraper", Name = "City Circuit",
		CoinPrice = 0, ProductId = 0, OwnedByDefault = true,
		Difficulty = "Medium", Style = "Street Racing",
		Description = "A closed street circuit through downtown. 12 corners, 3 laps.",
	},
}

-- ── Lookup helpers ───────────────────────────────────────────────────────────

function ShopConfig.GetCar(id: number)
	for _, c in ipairs(ShopConfig.Cars) do
		if c.Id == id then return c end
	end
	return nil
end

function ShopConfig.GetPaint(name: string)
	for _, p in ipairs(ShopConfig.Paints) do
		if p.Name == name then return p end
	end
	return nil
end

function ShopConfig.GetTrack(id: string)
	for _, t in ipairs(ShopConfig.Tracks) do
		if t.Id == id then return t end
	end
	return nil
end

return ShopConfig
