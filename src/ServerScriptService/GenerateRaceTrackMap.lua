--[[ TEMPORARILY DISABLED
-- GenerateRaceTrackMap
-- Procedurally generates the "High Speed" race track map.
-- Call Generate(parent, origin) from a server Script to build the map inside `parent`.

local GenerateRaceTrackMap = {}

-- ── Configuration ─────────────────────────────────────────────────────────────
local TRACK_COLOR     = Color3.fromRGB(40,  40,  40)   -- asphalt dark
local BARRIER_COLOR   = Color3.fromRGB(220, 50,  50)   -- red safety barrier
local STRIPE_COLOR    = Color3.fromRGB(255, 255, 255)  -- white racing stripe
local BOOST_COLOR     = Color3.fromRGB(74,  240, 255)  -- cyan boost pad
local TRACK_SIZE      = Vector3.new(20, 2, 20)
local BARRIER_SIZE    = Vector3.new(2, 3, 20)

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
function GenerateRaceTrackMap.Generate(parent, origin)
	origin = origin or Vector3.new(0, 0, 0)

	-- Flat track sections laid out as a straight with slight curves
	local sections = {
		{ pos = Vector3.new(  0, 0,   0), name = "Track_Start" },
		{ pos = Vector3.new( 22, 0,   0), name = "Track_S2" },
		{ pos = Vector3.new( 44, 0,   4), name = "Track_S3" },
		{ pos = Vector3.new( 66, 0,   0), name = "Track_S4" },
		{ pos = Vector3.new( 88, 0,  -4), name = "Track_S5" },
		{ pos = Vector3.new(110, 0,   0), name = "Track_S6" },
		{ pos = Vector3.new(132, 0,   4), name = "Track_S7" },
		{ pos = Vector3.new(154, 0,   0), name = "Track_Finish" },
	}
	for _, s in ipairs(sections) do
		makePart(TRACK_SIZE, origin + s.pos, TRACK_COLOR, s.name, parent)
	end

	-- Safety barriers along the sides of each section
	for i, s in ipairs(sections) do
		-- Left barrier
		makePart(BARRIER_SIZE, origin + s.pos + Vector3.new(0, 1.5, 11),
			BARRIER_COLOR, "BarrierL_" .. i, parent)
		-- Right barrier
		makePart(BARRIER_SIZE, origin + s.pos + Vector3.new(0, 1.5, -11),
			BARRIER_COLOR, "BarrierR_" .. i, parent)
	end

	-- Centre racing stripes (decorative, no collision)
	for i, s in ipairs(sections) do
		local stripe = makePart(
			Vector3.new(1, 0.1, 6),
			origin + s.pos + Vector3.new(0, 1.1, 0),
			STRIPE_COLOR, "Stripe_" .. i, parent)
		stripe.CanCollide = false
	end

	-- Cyan boost pads (speed boost trigger zones)
	local boostPositions = {
		Vector3.new(33,  1, 0),
		Vector3.new(77,  1, 0),
		Vector3.new(121, 1, 0),
	}
	for i, pos in ipairs(boostPositions) do
		local pad = makePart(Vector3.new(8, 0.5, 8), origin + pos,
			BOOST_COLOR, "BoostPad_" .. i, parent)
		pad.Material   = Enum.Material.Neon
		pad.CanCollide = false
	end
end

return GenerateRaceTrackMap
--]]
