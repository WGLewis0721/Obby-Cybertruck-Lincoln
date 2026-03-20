-- VehicleData.lua
-- Shared module containing all vehicle definitions for the garage system.
-- Each vehicle entry has:
--   Id         - unique numeric identifier
--   Name       - display name shown in the garage UI
--   Price      - Robux price shown on the "Buy" button
--   ProductId  - Roblox Developer Product ID for purchasing (0 = placeholder)
--   Unlocked   - true if the vehicle is free/default; false requires purchase
--   ModelName  - name of the Model instance in ServerStorage
--   Stats      - Speed, Handling, Acceleration, Braking (0–100 scale)
--   Thumbnail  - rbxassetid:// image used in the garage preview

local VehicleData = {
	{
		Id          = 1,
		Name        = "Tesla Cybertruck",
		Price       = 0,
		ProductId   = 0,
		Unlocked    = true,   -- default vehicle; every player starts with this
		ModelName   = "Tesla Cybertruck",
		Stats       = { Speed = 72, Handling = 60, Acceleration = 80, Braking = 65 },
		Thumbnail   = "rbxassetid://0",  -- TODO: replace with real thumbnail asset ID
	},
	{
		Id          = 2,
		Name        = "Tesla Model 3",
		Price       = 100,
		ProductId   = 0,     -- TODO: replace with real Roblox Developer Product ID
		Unlocked    = false,
		ModelName   = "Tesla Model 3",
		Stats       = { Speed = 65, Handling = 75, Acceleration = 70, Braking = 70 },
		Thumbnail   = "rbxassetid://0",  -- TODO: replace with real thumbnail asset ID
	},
	{
		Id          = 3,
		Name        = "Tesla Roadster",
		Price       = 200,
		ProductId   = 0,     -- TODO: replace with real Roblox Developer Product ID
		Unlocked    = false,
		ModelName   = "Tesla Roadster",
		Stats       = { Speed = 95, Handling = 85, Acceleration = 98, Braking = 80 },
		Thumbnail   = "rbxassetid://0",  -- TODO: replace with real thumbnail asset ID
	},
	{
		Id          = 4,
		Name        = "Tesla Model Y",
		Price       = 150,
		ProductId   = 0,     -- TODO: replace with real Roblox Developer Product ID
		Unlocked    = false,
		ModelName   = "Tesla Model Y",
		Stats       = { Speed = 68, Handling = 72, Acceleration = 74, Braking = 72 },
		Thumbnail   = "rbxassetid://0",  -- TODO: replace with real thumbnail asset ID
	},
}

return VehicleData
