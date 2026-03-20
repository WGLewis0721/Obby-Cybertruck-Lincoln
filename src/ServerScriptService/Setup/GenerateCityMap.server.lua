-- GenerateCityMap
-- Procedurally generates the "Skyscraper" city map.
-- Call Generate(parent, origin) from a server Script to build the map inside `parent`.

local GenerateCityMap = {}

-- ── Configuration ─────────────────────────────────────────────────────────────
local CONCRETE_COLOR  = Color3.fromRGB(120, 120, 130)  -- city concrete
local GLASS_COLOR     = Color3.fromRGB(100, 180, 220)  -- skyscraper glass
local LEDGE_COLOR     = Color3.fromRGB(80,  80,  90)   -- dark ledge
local HAZARD_COLOR    = Color3.fromRGB(200, 50,  50)   -- red hazard
local PLATFORM_SIZE   = Vector3.new(10, 2, 10)
local LEDGE_SIZE      = Vector3.new(16, 2, 4)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function makePart(size, position, color, name, parent)
	local part = Instance.new("Part")
	part.Name          = name or "MapPart"
	part.Size          = size
	part.CFrame        = CFrame.new(position)
	part.Color         = color
	part.Material      = Enum.Material.SmoothPlastic
	part.Anchored      = true
	part.CanCollide    = true
	part.CastShadow    = true
	part.Parent        = parent
	return part
end

-- ── Generate ──────────────────────────────────────────────────────────────────
-- parent – a Model or Folder in Workspace to parent all generated parts into.
-- origin – optional Vector3 world-space start position (defaults to Vector3.zero)
function GenerateCityMap.Generate(parent, origin)
	origin = origin or Vector3.new(0, 0, 0)

	-- Street-level ground
	makePart(Vector3.new(200, 2, 200), origin + Vector3.new(0, -1, 0),
		CONCRETE_COLOR, "StreetGround", parent)

	-- Ascending skyscraper ledges simulating climbing the city skyline
	local ledges = {
		{ pos = Vector3.new(0,  2,   0), name = "Ledge_Street" },
		{ pos = Vector3.new(12, 8,   0), name = "Ledge_2" },
		{ pos = Vector3.new(24, 16,  3), name = "Ledge_3" },
		{ pos = Vector3.new(36, 24, -3), name = "Ledge_4" },
		{ pos = Vector3.new(48, 34,  3), name = "Ledge_5" },
		{ pos = Vector3.new(60, 44, -3), name = "Ledge_6" },
		{ pos = Vector3.new(72, 56,  3), name = "Ledge_7" },
		{ pos = Vector3.new(84, 68,  0), name = "Ledge_Rooftop" },
	}
	for _, l in ipairs(ledges) do
		makePart(LEDGE_SIZE, origin + l.pos, LEDGE_COLOR, l.name, parent)
	end

	-- Skyscraper building pillars (decorative + collision walls)
	local buildings = {
		{ pos = Vector3.new(-15, 35, 0),  size = Vector3.new(8, 70, 8) },
		{ pos = Vector3.new( 15, 35, 0),  size = Vector3.new(8, 70, 8) },
		{ pos = Vector3.new(  0, 35,-15), size = Vector3.new(8, 70, 8) },
	}
	for i, b in ipairs(buildings) do
		makePart(b.size, origin + b.pos, GLASS_COLOR, "Building_" .. i, parent)
	end

	-- Hazard tiles on some ledges (players must avoid)
	local hazards = {
		Vector3.new(14, 9,  0),
		Vector3.new(38, 25, 3),
		Vector3.new(62, 45,-3),
	}
	for i, pos in ipairs(hazards) do
		local h = makePart(Vector3.new(3, 1, 3), origin + pos,
			HAZARD_COLOR, "Hazard_" .. i, parent)
		h.Material = Enum.Material.Neon
	end

	-- Start and finish platforms
	makePart(PLATFORM_SIZE, origin + Vector3.new(0, 2, 0),
		CONCRETE_COLOR, "Platform_Start", parent)
	makePart(PLATFORM_SIZE, origin + Vector3.new(84, 68, 0),
		GLASS_COLOR, "Platform_Finish", parent)
end

return GenerateCityMap
