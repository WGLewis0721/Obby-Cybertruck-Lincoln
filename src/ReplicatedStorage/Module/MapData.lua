local MapData = {
	{
		Id = "city_underground",
		Name = "City Underground",
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
		Id = "mountain_forest",
		Name = "Mountain & Forest",
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
		Id = "race_circuit",
		Name = "Cybertruck Circuit",
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
