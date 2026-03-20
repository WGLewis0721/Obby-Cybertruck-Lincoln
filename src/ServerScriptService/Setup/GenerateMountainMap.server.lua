-- GenerateMountainMap
-- Procedurally generates the "Big Foot" mountain and forest map.
-- Call Generate(parent, origin) from a server Script to build the map inside `parent`.

local GenerateMountainMap = {}

-- ── Configuration ─────────────────────────────────────────────────────────────
local MOUNTAIN_COLOR  = Color3.fromRGB(90,  75,  60)   -- rocky brown
local FOREST_COLOR    = Color3.fromRGB(34,  85,  34)   -- deep green
local PLATFORM_COLOR  = Color3.fromRGB(110, 95,  75)   -- light stone
local OBSTACLE_COLOR  = Color3.fromRGB(60,  50,  40)   -- dark rock
local PLATFORM_SIZE   = Vector3.new(12, 2, 12)
local OBSTACLE_SIZE   = Vector3.new(3, 4, 3)

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
function GenerateMountainMap.Generate(parent, origin)
	origin = origin or Vector3.new(0, 0, 0)

	-- Ground base
	makePart(Vector3.new(200, 2, 200), origin + Vector3.new(0, -1, 0),
		MOUNTAIN_COLOR, "GroundBase", parent)

	-- Ascending platforms simulating a mountain climb
	local platforms = {
		{ pos = Vector3.new(0, 2,  0),  name = "Platform_Start" },
		{ pos = Vector3.new(14, 6,  0), name = "Platform_2" },
		{ pos = Vector3.new(28, 10, 4), name = "Platform_3" },
		{ pos = Vector3.new(42, 14, 0), name = "Platform_4" },
		{ pos = Vector3.new(56, 18, -4),name = "Platform_5" },
		{ pos = Vector3.new(70, 22, 0), name = "Platform_6" },
		{ pos = Vector3.new(84, 26, 4), name = "Platform_7" },
		{ pos = Vector3.new(98, 30, 0), name = "Platform_Peak" },
	}
	for _, p in ipairs(platforms) do
		makePart(PLATFORM_SIZE, origin + p.pos, PLATFORM_COLOR, p.name, parent)
	end

	-- Forest floor obstacles (stumps / boulders)
	local obstacles = {
		Vector3.new(7,  5,  2),
		Vector3.new(21, 9, -2),
		Vector3.new(35, 13, 3),
		Vector3.new(49, 17,-3),
		Vector3.new(63, 21, 2),
		Vector3.new(77, 25,-2),
	}
	for i, pos in ipairs(obstacles) do
		makePart(OBSTACLE_SIZE, origin + pos, OBSTACLE_COLOR,
			"Boulder_" .. i, parent)
	end

	-- Decorative forest trees (thin green pillars)
	for i = 1, 10 do
		local treePos = Vector3.new(-20 + i * 4, 5, 15)
		makePart(Vector3.new(2, 10, 2), origin + treePos, FOREST_COLOR,
			"Tree_" .. i, parent)
	end
end

return GenerateMountainMap
