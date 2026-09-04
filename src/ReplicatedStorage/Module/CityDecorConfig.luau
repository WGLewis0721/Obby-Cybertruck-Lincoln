--[[
	CityDecorConfig.luau
	Description: Config-driven definition of the generic-metropolis dressing built
	             around a race circuit (buildings, street furniture, signage,
	             parked vehicles). Purely tuning numbers -- the generator that reads
	             this lives in Services.CityDecorBuilder. Never touches the actual
	             road/barrier/checkpoint/coin geometry owned by TrackBuilder.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- None

	Events Fired / Listened:
		- None
--]]

local CityDecorConfig = {}

-- ── Safety clearance ─────────────────────────────────────────────────────────
-- Studs beyond each road/barrier segment's outer edge that must stay clear of
-- any decoration. Keeps scenery from ever clipping the driveable surface.
CityDecorConfig.TRACK_CLEARANCE = 26

-- ── Track-edge trim (Phase 4) ────────────────────────────────────────────────
-- Walks the built road segments and dresses the shoulder on both sides.
CityDecorConfig.EDGE_SIDEWALK_OFFSET = 6    -- studs from barrier outer face to sidewalk inner edge
CityDecorConfig.EDGE_SIDEWALK_WIDTH  = 10
CityDecorConfig.EDGE_PROP_OFFSET     = 16   -- studs from barrier outer face to prop row
CityDecorConfig.EDGE_PROP_EVERY_N    = 2    -- place a cluster every N road segments
CityDecorConfig.EDGE_LIGHT_EVERY_N   = 4    -- of those clusters, every Nth gets a real PointLight

-- ── City blocks (Phase 3/5) ──────────────────────────────────────────────────
CityDecorConfig.BLOCK_SIZE      = 150  -- grid cell size, studs
CityDecorConfig.BLOCK_MARGIN    = CityDecorConfig.TRACK_CLEARANCE + 40 -- extra clearance for whole blocks
CityDecorConfig.OUTER_PAD       = 260  -- how far past the ground plane's edge the grid still tries to fill

-- Zones are picked by angle (degrees, 0-360 normalized atan2 around the track's
-- centroid). Band edges sit at 0/90/180/270 -- NOT centered on a zone -- so no
-- wraparound handling is needed when matching an angle to a band.
-- Kept to four bands so the drive-by silhouette reads as distinct districts.
CityDecorConfig.Zones = {
	{ name = "Downtown",   minDeg =   0, maxDeg =  90, buildingWeight = { Skyscraper = 3, MidriseA = 3, MidriseB = 2 } },
	{ name = "Commercial", minDeg =  90, maxDeg = 180, buildingWeight = { LowriseA = 3, LowriseB = 3, LowriseC = 2, MidriseA = 1 } },
	{ name = "Parking",    minDeg = 180, maxDeg = 270, buildingWeight = { ParkingGarage = 3, LowriseB = 2 } },
	{ name = "Quiet",      minDeg = 270, maxDeg = 360, buildingWeight = { LowriseA = 2, LowriseC = 3 } },
}

-- Building archetypes. footprint/height are {min, max} ranges sampled per placement.
CityDecorConfig.BuildingKinds = {
	LowriseA      = { footprint = {26, 34}, height = {18, 26}, color = Color3.fromRGB(196, 176, 150), material = Enum.Material.Brick,    storefront = true },
	LowriseB      = { footprint = {24, 30}, height = {16, 22}, color = Color3.fromRGB(150, 158, 150), material = Enum.Material.Concrete, storefront = true },
	LowriseC      = { footprint = {22, 30}, height = {14, 20}, color = Color3.fromRGB(178, 150, 130), material = Enum.Material.Brick,    storefront = false },
	MidriseA      = { footprint = {34, 44}, height = {50, 80}, color = Color3.fromRGB(120, 130, 140), material = Enum.Material.Concrete, storefront = true, hvac = true },
	MidriseB      = { footprint = {32, 42}, height = {46, 70}, color = Color3.fromRGB(150, 140, 120), material = Enum.Material.Brick,    storefront = true, hvac = true },
	Skyscraper    = { footprint = {44, 58}, height = {140, 220}, color = Color3.fromRGB(90, 150, 200), material = Enum.Material.Glass,   storefront = true, hvac = true, spire = true },
	ParkingGarage = { footprint = {50, 64}, height = {28, 36}, color = Color3.fromRGB(120, 120, 122), material = Enum.Material.Concrete, storefront = false, garage = true },
}

CityDecorConfig.BusinessNames = {
	"NORTHGATE COFFEE", "IRONVALE HARDWARE", "BLUE PINE DINER", "CASCADE AUTO",
	"UNION ST. MARKET", "SUMMIT ELECTRONICS", "GOLDLEAF BAKERY", "METRO BOOKS",
	"HARBOR LIGHT PHARMACY", "GRANITE ROW DELI", "SILVERLINE BANK", "MAPLEWOOD DRY CLEANERS",
}

CityDecorConfig.StreetNames = {
	"MAIN ST", "5TH AVE", "UNION ST", "GRANITE RD", "HARBOR BLVD", "MAPLEWOOD DR",
}

-- ── Parked vehicle palette ───────────────────────────────────────────────────
CityDecorConfig.CarColors = {
	Color3.fromRGB(200, 40, 40), Color3.fromRGB(40, 60, 140), Color3.fromRGB(230, 230, 230),
	Color3.fromRGB(40, 40, 40), Color3.fromRGB(180, 170, 40),
}

return CityDecorConfig
