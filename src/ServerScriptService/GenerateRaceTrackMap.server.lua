if not workspace:FindFirstChild("RaceTrackMap") then

-- ============================================================
-- STREET CIRCUIT RACE TRACK GENERATOR
-- Run this script once in the Roblox Studio Command Bar
-- or as a Script in ServerScriptService set to run once.
-- It will generate a "RaceTrackMap" folder in Workspace.
-- ============================================================

local map = Instance.new("Folder")
map.Name = "RaceTrackMap"
map.Parent = workspace

-- ============================================================
-- SETTINGS
-- ============================================================
local ROAD_WIDTH = 32        -- wider for a proper race track
local ROAD_THICKNESS = 2
local KERB_WIDTH = 4
local BARRIER_HEIGHT = 6
local START_POS = Vector3.new(-500, 0, 0) -- offset from other maps

-- Colors
local ASPHALT = Color3.fromRGB(35, 35, 38)
local KERB_RED = Color3.fromRGB(200, 40, 40)
local KERB_WHITE = Color3.fromRGB(240, 240, 240)
local BARRIER_COLOR = Color3.fromRGB(220, 220, 220)
local BARRIER_STRIPE = Color3.fromRGB(200, 40, 40)
local RUNOFF_COLOR = Color3.fromRGB(130, 160, 80)  -- grass runoff area
local GRANDSTAND_COLOR = Color3.fromRGB(50, 55, 65)
local GRANDSTAND_SEAT = Color3.fromRGB(200, 40, 40)
local START_GRID = Color3.fromRGB(255, 255, 255)
local STRIPE_WHITE = Color3.fromRGB(255, 255, 255)
local NEON_ORANGE = Color3.fromRGB(255, 120, 0)
local BUILDING_COLOR = Color3.fromRGB(60, 65, 80)

-- ============================================================
-- HELPERS
-- ============================================================
local function makePart(name, size, cframe, color, parent, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = parent or map
	return p
end

local function addCheckpoint(pos, yRot, number, parent)
	local cp = makePart(
		"Checkpoint_" .. number,
		Vector3.new(ROAD_WIDTH + KERB_WIDTH * 2, 0.5, 4),
		CFrame.new(pos) * CFrame.Angles(0, yRot, 0),
		Color3.fromRGB(74, 240, 255),
		parent, Enum.Material.Neon, 0.4
	)
	local label = Instance.new("SurfaceGui")
	label.Face = Enum.NormalId.Top
	label.Parent = cp
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = number == 99 and "🏁 FINISH" or "SECTOR " .. number
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBold
	txt.TextScaled = true
	txt.Parent = label
end

local function addKerb(pos, length, yRot, side, parent)
	-- Alternating red/white kerb pattern
	local stripeCount = math.floor(length / 3)
	for i = 0, stripeCount - 1 do
		local offset = -length/2 + i * 3 + 1.5
		local kerbColor = i % 2 == 0 and KERB_RED or KERB_WHITE
		local sideOffset = side == "L" and -(ROAD_WIDTH/2 + KERB_WIDTH/2) or (ROAD_WIDTH/2 + KERB_WIDTH/2)
		makePart("Kerb_"..side.."_"..i,
			Vector3.new(KERB_WIDTH, ROAD_THICKNESS + 0.3, 3),
			CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(sideOffset, 0.15, offset),
			kerbColor, parent)
	end
end

local function addBarrier(pos, length, yRot, side, parent)
	local sideOffset = side == "L" and -(ROAD_WIDTH/2 + KERB_WIDTH + 1) or (ROAD_WIDTH/2 + KERB_WIDTH + 1)
	-- Main barrier
	local barrier = makePart("Barrier_"..side,
		Vector3.new(2, BARRIER_HEIGHT, length),
		CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(sideOffset, BARRIER_HEIGHT/2, 0),
		BARRIER_COLOR, parent)
	-- Red stripe on barrier
	makePart("BarrierStripe_"..side,
		Vector3.new(2.1, 1.5, length),
		CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(sideOffset, BARRIER_HEIGHT - 1.5, 0),
		BARRIER_STRIPE, parent)
end

local function addRunoff(pos, size, yRot, side, parent)
	local sideOffset = side == "L" and -(ROAD_WIDTH/2 + KERB_WIDTH + size.X/2 + 2) or (ROAD_WIDTH/2 + KERB_WIDTH + size.X/2 + 2)
	makePart("Runoff_"..side,
		size,
		CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(sideOffset, -0.5, 0),
		RUNOFF_COLOR, parent, Enum.Material.Grass)
end

local function addGrandstand(pos, yRot, parent)
	-- Base
	makePart("GS_Base", Vector3.new(80, 4, 20),
		CFrame.new(pos) * CFrame.Angles(0, yRot, 0),
		GRANDSTAND_COLOR, parent)
	-- Rows of seats
	for row = 0, 3 do
		for seat = 0, 15 do
			makePart("GS_Seat_"..row.."_"..seat,
				Vector3.new(4, 2, 3),
				CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(-30 + seat * 4, 4 + row * 3, -4 + row * 4),
				GRANDSTAND_SEAT, parent)
		end
	end
	-- Roof
	makePart("GS_Roof", Vector3.new(84, 2, 22),
		CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(0, 16, 4),
		GRANDSTAND_COLOR, parent)
end

local function addStartGrid(pos, yRot, parent)
	-- Grid boxes on road surface
	for i = 0, 9 do
		local side = i % 2 == 0 and -6 or 6
		makePart("Grid_"..i,
			Vector3.new(6, 0.3, 10),
			CFrame.new(pos) * CFrame.Angles(0, yRot, 0) * CFrame.new(side, 0.2, -i * 12),
			START_GRID, parent)
	end
end

local function addSponsorBoard(pos, text, color, parent)
	local board = makePart("Board", Vector3.new(20, 6, 1),
		CFrame.new(pos), color, parent)
	board.Material = Enum.Material.Neon
	board.Transparency = 0.2
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Text = text
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = gui
end

-- ============================================================
-- CIRCUIT LAYOUT DEFINITION
-- Street circuit: start/finish straight, multiple corners,
-- chicanes, long straight, hairpin, back to start
--
-- Each segment: {type, length, turnAngle, label}
-- types: "straight", "corner", "chicane", "hairpin"
-- ============================================================
local circuit = {
	-- Start/Finish straight with grandstands
	{type="straight", length=300, angle=0,   label="StartFinish"},
	-- Turn 1: fast right hander into city
	{type="corner",   length=120, angle=45,  label="Turn1"},
	-- Short straight through city blocks
	{type="straight", length=180, angle=0,   label="CityBlock1"},
	-- Chicane: left-right through narrow street
	{type="corner",   length=80,  angle=-30, label="ChicaneLeft"},
	{type="corner",   length=80,  angle=30,  label="ChicaneRight"},
	-- City straight past buildings
	{type="straight", length=200, angle=0,   label="CityBlock2"},
	-- Tight right turn
	{type="corner",   length=100, angle=60,  label="Turn4"},
	-- Short blast
	{type="straight", length=120, angle=0,   label="Short1"},
	-- Left kink
	{type="corner",   length=60,  angle=-20, label="Kink"},
	-- Long back straight (DRS zone)
	{type="straight", length=280, angle=0,   label="BackStraight"},
	-- Hairpin turn (slowest corner)
	{type="corner",   length=140, angle=90,  label="Hairpin"},
	-- Acceleration zone
	{type="straight", length=160, angle=0,   label="Acceleration"},
	-- Final complex: right-left
	{type="corner",   length=90,  angle=35,  label="FinalRight"},
	{type="corner",   length=90,  angle=-35, label="FinalLeft"},
	-- Return to start straight
	{type="straight", length=180, angle=0,   label="ReturnStraight"},
}

-- ============================================================
-- GENERATE CIRCUIT
-- ============================================================
local currentPos = START_POS
local currentAngle = 0
local checkpointNum = 1
local segmentIndex = 0

for _, seg in ipairs(circuit) do
	segmentIndex = segmentIndex + 1
	local section = Instance.new("Folder")
	section.Name = "Seg_"..segmentIndex.."_"..seg.label
	section.Parent = map

	currentAngle = currentAngle + seg.angle
	local rad = math.rad(currentAngle)
	local dir = Vector3.new(math.sin(rad), 0, math.cos(rad))
	local segCenter = currentPos + dir * (seg.length / 2)
	local roadCF = CFrame.new(segCenter, segCenter + dir) * CFrame.Angles(0, math.rad(90), 0)

	-- Road surface (asphalt)
	makePart("Road_"..seg.label,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, seg.length),
		roadCF, ASPHALT, section, Enum.Material.SmoothPlastic)

	-- Kerbs both sides
	addKerb(segCenter, seg.length, rad, "L", section)
	addKerb(segCenter, seg.length, rad, "R", section)

	-- Barriers both sides
	addBarrier(segCenter, seg.length, rad, "L", section)
	addBarrier(segCenter, seg.length, rad, "R", section)

	-- Runoff grass
	addRunoff(segCenter, Vector3.new(16, 1, seg.length), rad, "L", section)
	addRunoff(segCenter, Vector3.new(16, 1, seg.length), rad, "R", section)

	-- Segment-specific features
	if seg.label == "StartFinish" then
		-- Start/finish line
		makePart("StartFinishLine",
			Vector3.new(ROAD_WIDTH, ROAD_THICKNESS + 0.2, 6),
			CFrame.new(segCenter + dir * (seg.length/2 - 20)),
			START_GRID, section)

		-- Start grid boxes
		addStartGrid(segCenter + dir * (seg.length/2 - 60), rad, section)

		-- Grandstands on both sides
		addGrandstand(segCenter + dir:Cross(Vector3.new(0,1,0)) * -(ROAD_WIDTH/2 + KERB_WIDTH + 30), rad, section)

		-- Pit lane indicator
		makePart("PitLane",
			Vector3.new(12, ROAD_THICKNESS, seg.length - 40),
			roadCF * CFrame.new(-(ROAD_WIDTH/2 + KERB_WIDTH + 7), 0, 0),
			Color3.fromRGB(50, 50, 55), section)

		-- Sponsor boards
		addSponsorBoard(
			segCenter + dir:Cross(Vector3.new(0,1,0)) * -(ROAD_WIDTH/2 + KERB_WIDTH + 14) + Vector3.new(0, 8, 0),
			"CYBERTRUCK CIRCUIT", NEON_ORANGE, section)

		-- Checkered start/finish
		local finish = makePart("FinishCheckered",
			Vector3.new(ROAD_WIDTH, 0.5, 4),
			CFrame.new(segCenter + dir * (seg.length/2 - 20) + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rad, 0),
			Color3.fromRGB(255, 255, 255), section, Enum.Material.Neon, 0.3)

		addCheckpoint(segCenter + dir * (seg.length/2 - 20) + Vector3.new(0, 1.2, 0), rad, 99, section)

	elseif seg.label == "BackStraight" then
		-- DRS detection zone markers
		for m = 0, 3 do
			makePart("DRS_"..m,
				Vector3.new(ROAD_WIDTH, 0.3, 2),
				CFrame.new(segCenter + dir * (-seg.length/2 + m * 60 + 30) + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rad, 0),
				Color3.fromRGB(74, 240, 255), section, Enum.Material.Neon, 0.5)
		end
		-- Speed signs
		addSponsorBoard(
			segCenter + Vector3.new(0, 8, 0),
			"⚡ DRS ZONE", Color3.fromRGB(74, 240, 255), section)

	elseif seg.label == "Hairpin" then
		-- Hairpin run-off extra wide
		addRunoff(segCenter, Vector3.new(30, 1, seg.length), rad, "R", section)
		-- Tire barriers at hairpin apex
		for t = 0, 5 do
			makePart("Tire_"..t,
				Vector3.new(3, 3, 3),
				CFrame.new(segCenter + dir:Cross(Vector3.new(0,1,0)) * (ROAD_WIDTH/2 + 2) + dir * (-10 + t * 4)),
				Color3.fromRGB(20, 20, 20), section, Enum.Material.SmoothPlastic)
		end
	end

	-- White center line on straights
	if seg.type == "straight" then
		-- Dashed center line
		for d = 0, math.floor(seg.length / 20) - 1 do
			makePart("Dash_"..d,
				Vector3.new(1, ROAD_THICKNESS + 0.1, 10),
				CFrame.new(segCenter + dir * (-seg.length/2 + d * 20 + 10) + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rad, 0),
				STRIPE_WHITE, section)
		end
	end

	-- Checkpoints at key points
	if seg.label == "Turn1" or seg.label == "BackStraight" or
	   seg.label == "Hairpin" or seg.label == "FinalRight" then
		addCheckpoint(segCenter, rad, checkpointNum, section)
		checkpointNum = checkpointNum + 1
	end

	-- City buildings along circuit
	if seg.type == "straight" and seg.length >= 180 then
		local perpRight = dir:Cross(Vector3.new(0,1,0))
		for b = 0, 2 do
			local bHeight = math.random(30, 60)
			local bOffset = -seg.length/3 + b * (seg.length/3)
			makePart("Building_R_"..b,
				Vector3.new(20, bHeight, 30),
				CFrame.new(segCenter + perpRight * (ROAD_WIDTH/2 + KERB_WIDTH + 30) + dir * bOffset + Vector3.new(0, bHeight/2, 0)),
				BUILDING_COLOR, section)
			makePart("Building_L_"..b,
				Vector3.new(20, bHeight - 10, 30),
				CFrame.new(segCenter - perpRight * (ROAD_WIDTH/2 + KERB_WIDTH + 30) + dir * bOffset + Vector3.new(0, (bHeight-10)/2, 0)),
				Color3.fromRGB(50, 55, 68), section)
		end
	end

	-- Advance position
	currentPos = currentPos + dir * seg.length
end

-- ============================================================
-- SPAWN POINT
-- ============================================================
local spawn = Instance.new("SpawnLocation")
spawn.Name = "RaceTrackSpawn"
spawn.Size = Vector3.new(ROAD_WIDTH - 8, 1, 8)
spawn.CFrame = CFrame.new(START_POS + Vector3.new(0, 1, 20))
spawn.Anchored = true
spawn.Color = Color3.fromRGB(255, 120, 0)
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.7
spawn.Parent = map

-- ============================================================
-- TRACK SIGNAGE
-- ============================================================
local signs = {
	{pos = START_POS + Vector3.new(0, 10, -20), text = "🏁 CYBERTRUCK CIRCUIT"},
	{pos = START_POS + Vector3.new(60, 8, 200), text = "SECTOR 1"},
	{pos = START_POS + Vector3.new(-100, 8, 400), text = "SECTOR 2"},
	{pos = START_POS + Vector3.new(0, 8, 600), text = "SECTOR 3 - FINAL"},
}
local signColors = {NEON_ORANGE, Color3.fromRGB(74, 240, 255), NEON_ORANGE, Color3.fromRGB(74, 240, 255)}
for i, s in ipairs(signs) do
	addSponsorBoard(s.pos, s.text, signColors[i], map)
end

print("✅ RaceTrackMap generated successfully!")
print("Circuit type: Street Circuit")
print("Total segments: " .. #circuit)
print("Features: Start/Finish straight, grandstands, pit lane,")
print("          chicane, DRS zone, hairpin, city buildings")
print("Checkpoints placed: " .. checkpointNum)
print("Lap distance: approximately " .. math.floor(
	(function()
		local total = 0
		for _, s in ipairs(circuit) do total = total + s.length end
		return total
	end)()
) .. " studs")

end
