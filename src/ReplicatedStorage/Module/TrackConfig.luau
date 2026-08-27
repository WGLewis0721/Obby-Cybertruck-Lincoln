--[[
    TrackConfig.luau
    Description: Config-driven definition of every racing circuit. Track shape is
                 a closed loop of control points fed through a Catmull-Rom spline,
                 so adding/reshaping a track means editing numbers here -- never
                 the generator code.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Coordinates are LOCAL to each track's Origin, so a whole circuit can be
    relocated by changing Origin alone.

    Dependencies:
        - None

    Events Fired / Listened:
        - None
--]]

local TrackConfig = {}

-- ── Shared geometry defaults ─────────────────────────────────────────────────
TrackConfig.ROAD_WIDTH        = 44   -- studs across the driving surface
TrackConfig.ROAD_THICKNESS    = 2
TrackConfig.BARRIER_HEIGHT    = 7    -- tall enough to contain a fast car
TrackConfig.BARRIER_THICKNESS = 2
TrackConfig.SAMPLES_PER_SEG   = 8    -- spline resolution between control points
TrackConfig.SEGMENT_OVERLAP   = 1.5  -- studs of overlap so seams don't gap on curves

-- ── Coin pickups ─────────────────────────────────────────────────────────────
TrackConfig.COIN_EVERY_N_SAMPLES = 5   -- spacing of coins along the racing line
TrackConfig.COIN_LATERAL_SPREAD  = 9   -- studs left/right of centerline

-- ── Checkpoints ──────────────────────────────────────────────────────────────
TrackConfig.CHECKPOINT_COUNT = 12  -- numbered checkpoints; finish line is separate

--[[
    City Circuit -- the default/starter track.

    Layout: long main straight -> fast right (T1) -> esses -> uphill sweeper ->
            hairpin -> downhill technical section -> back straight -> final corner.
    Roughly 5,600 studs of centerline: ~60-70s per lap in the starter Cybertruck,
    with ~12 meaningful corners of mixed type.

    Placed well clear of the hand-built hub city (which spans X=-363..461,
    Z=-299..335) so the two never overlap.
--]]
TrackConfig.Tracks = {
	City = {
		Id           = "skyscraper",   -- must match MapData.Id
		FolderName   = "SkyscraperMap", -- must match MapData.FolderName
		DisplayName  = "City Circuit",
		Origin       = Vector3.new(2600, 0, 0),
		TotalLaps    = 3,
		Theme = {
			Road     = Color3.fromRGB(54, 58, 66),
			Barrier  = Color3.fromRGB(196, 199, 206),
			Curb     = Color3.fromRGB(214, 74, 74),
			Building = Color3.fromRGB(88, 170, 220),
			Accent   = Color3.fromRGB(255, 191, 71),
		},
		-- Closed loop: the last point connects back to the first.
		ControlPoints = {
			Vector3.new(-520, 0, -260),
			Vector3.new(-120, 0, -300),
			Vector3.new( 300, 0, -260),
			Vector3.new( 560, 0,  -40),
			Vector3.new( 500, 0,  240),
			Vector3.new( 180, 0,  360),
			Vector3.new(-220, 0,  330),
			Vector3.new(-540, 0,  170),
			Vector3.new(-650, 0,  -60),
		},
		-- Skyline props placed outside the loop (local coords, XZ + height).
		Buildings = {
			{ pos = Vector3.new(-300,  0, -700), size = Vector3.new(90, 220, 90) },
			{ pos = Vector3.new(  60,  0, -720), size = Vector3.new(70, 160, 70) },
			{ pos = Vector3.new( 420,  0, -700), size = Vector3.new(80, 260, 80) },
			{ pos = Vector3.new(1050,  0, -260), size = Vector3.new(85, 190, 85) },
			{ pos = Vector3.new(1060,  0,  180), size = Vector3.new(75, 240, 75) },
			{ pos = Vector3.new( 980,  0,  600), size = Vector3.new(70, 150, 70) },
			{ pos = Vector3.new( 520,  0,  820), size = Vector3.new(88, 200, 88) },
			{ pos = Vector3.new(  80,  0,  700), size = Vector3.new(72, 175, 72) },
			{ pos = Vector3.new(-350,  0,  720), size = Vector3.new(84, 230, 84) },
			{ pos = Vector3.new(-780,  0,  480), size = Vector3.new(76, 165, 76) },
			{ pos = Vector3.new(-980,  0,  100), size = Vector3.new(90, 250, 90) },
			{ pos = Vector3.new(-990,  0, -320), size = Vector3.new(70, 185, 70) },
			-- Infield structures
			{ pos = Vector3.new(-200,  0, -100), size = Vector3.new(60, 120, 60) },
			{ pos = Vector3.new( 250,  0,   60), size = Vector3.new(55, 95, 55) },
			{ pos = Vector3.new(-350,  0,  150), size = Vector3.new(65, 140, 65) },
		},
	},
}

return TrackConfig
