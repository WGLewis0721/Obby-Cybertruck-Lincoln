-- ============================================================
-- CITY MAP GENERATOR - Underground Tunnels & Streets
-- Run this script once in the Roblox Studio Command Bar
-- or as a Script in ServerScriptService set to run once.
-- It will generate a "CityMap" folder in Workspace.
-- ============================================================

local map = Instance.new("Folder")
map.Name = "CityMap"
map.Parent = workspace

-- ============================================================
-- SETTINGS
-- ============================================================
local ROAD_WIDTH = 28
local ROAD_THICKNESS = 2
local WALL_HEIGHT = 16
local TUNNEL_HEIGHT = 20
local SEGMENT_LENGTH = 60
local START_POS = Vector3.new(0, 0, 0)

-- Colors
local ROAD_COLOR = Color3.fromRGB(40, 40, 45)
local WALL_COLOR = Color3.fromRGB(60, 60, 70)
local TUNNEL_COLOR = Color3.fromRGB(30, 30, 35)
local STRIPE_COLOR = Color3.fromRGB(255, 220, 0)
local LIGHT_COLOR = Color3.fromRGB(255, 240, 180)
local NEON_COLOR = Color3.fromRGB(74, 240, 255)
local BUILDING_COLOR = Color3.fromRGB(55, 60, 75)

-- ============================================================
-- HELPERS
-- ============================================================
local function makePart(name, size, cframe, color, parent, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = transparency or 0
	p.Parent = parent or map
	return p
end

local function makeWedge(name, size, cframe, color, parent)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local function addCheckpoint(pos, number, parent)
	local cp = makePart(
		"Checkpoint_" .. number,
		Vector3.new(ROAD_WIDTH, 0.5, 4),
		CFrame.new(pos),
		Color3.fromRGB(74, 240, 255),
		parent
	)
	cp.Transparency = 0.5
	cp.Material = Enum.Material.Neon
	local label = Instance.new("SurfaceGui")
	label.Face = Enum.NormalId.Top
	label.Parent = cp
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.Text = "CHECKPOINT " .. number
	txt.TextColor3 = Color3.new(1, 1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBold
	txt.TextScaled = true
	txt.Parent = label
end

local function addStreetLight(pos, parent)
	-- Pole
	makePart("LightPole", Vector3.new(1, 12, 1),
		CFrame.new(pos + Vector3.new(0, 6, 0)),
		Color3.fromRGB(80, 80, 90), parent)
	-- Arm
	makePart("LightArm", Vector3.new(6, 1, 1),
		CFrame.new(pos + Vector3.new(3, 12, 0)),
		Color3.fromRGB(80, 80, 90), parent)
	-- Light
	local light = makePart("LightBulb", Vector3.new(2, 1, 2),
		CFrame.new(pos + Vector3.new(6, 11.5, 0)),
		LIGHT_COLOR, parent)
	light.Material = Enum.Material.Neon
end

local function addNeonSign(pos, text, parent)
	local sign = makePart("NeonSign", Vector3.new(8, 3, 0.5),
		CFrame.new(pos),
		NEON_COLOR, parent)
	sign.Material = Enum.Material.Neon
	sign.Transparency = 0.3
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
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
-- SPAWN POINT
-- ============================================================
local spawn = Instance.new("SpawnLocation")
spawn.Name = "CityMapSpawn"
spawn.Size = Vector3.new(ROAD_WIDTH - 4, 1, 8)
spawn.CFrame = CFrame.new(START_POS + Vector3.new(0, 1, 0))
spawn.Anchored = true
spawn.Color = Color3.fromRGB(74, 240, 255)
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.7
spawn.Parent = map

-- ============================================================
-- SECTION 1: SURFACE STREET (straight, open air)
-- ============================================================
local section1 = Instance.new("Folder")
section1.Name = "Section1_Street"
section1.Parent = map

local s1Pos = START_POS
for i = 0, 5 do
	local segPos = s1Pos + Vector3.new(0, -1, i * SEGMENT_LENGTH)
	-- Road
	makePart("Road_S1_"..i,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
		CFrame.new(segPos),
		ROAD_COLOR, section1)
	-- Center stripe
	makePart("Stripe_S1_"..i,
		Vector3.new(1, ROAD_THICKNESS + 0.1, SEGMENT_LENGTH - 4),
		CFrame.new(segPos + Vector3.new(0, 0.1, 0)),
		STRIPE_COLOR, section1)
	-- Left wall / building facade
	makePart("WallL_S1_"..i,
		Vector3.new(2, WALL_HEIGHT, SEGMENT_LENGTH),
		CFrame.new(segPos + Vector3.new(-ROAD_WIDTH/2 - 1, WALL_HEIGHT/2, 0)),
		BUILDING_COLOR, section1)
	-- Right wall / building facade
	makePart("WallR_S1_"..i,
		Vector3.new(2, WALL_HEIGHT, SEGMENT_LENGTH),
		CFrame.new(segPos + Vector3.new(ROAD_WIDTH/2 + 1, WALL_HEIGHT/2, 0)),
		BUILDING_COLOR, section1)
	-- Street lights every other segment
	if i % 2 == 0 then
		addStreetLight(segPos + Vector3.new(-ROAD_WIDTH/2 + 2, 0, -SEGMENT_LENGTH/4), section1)
		addStreetLight(segPos + Vector3.new(ROAD_WIDTH/2 - 2, 0, SEGMENT_LENGTH/4), section1)
	end
	-- Neon signs on buildings
	if i % 3 == 0 then
		local signs = {"SPEED ZONE", "CITY CIRCUIT", "NO LIMITS", "RACE ON"}
		addNeonSign(
			segPos + Vector3.new(-ROAD_WIDTH/2 - 1, WALL_HEIGHT/2, 0),
			signs[(i % #signs) + 1], section1)
	end
end

-- Checkpoint 1
addCheckpoint(s1Pos + Vector3.new(0, 0, 2 * SEGMENT_LENGTH), 1, section1)

-- ============================================================
-- SECTION 2: TUNNEL ENTRANCE RAMP (going underground)
-- ============================================================
local section2 = Instance.new("Folder")
section2.Name = "Section2_TunnelEntrance"
section2.Parent = map

local s2Start = s1Pos + Vector3.new(0, -1, 6 * SEGMENT_LENGTH)

-- Ramp down into tunnel
for i = 0, 3 do
	local rampPos = s2Start + Vector3.new(0, -i * 4, i * SEGMENT_LENGTH)
	makePart("Ramp_"..i,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
		CFrame.new(rampPos) * CFrame.Angles(math.rad(-8), 0, 0),
		ROAD_COLOR, section2)
	-- Ramp walls
	makePart("RampWallL_"..i, Vector3.new(2, 10, SEGMENT_LENGTH),
		CFrame.new(rampPos + Vector3.new(-ROAD_WIDTH/2 - 1, 4, 0)) * CFrame.Angles(math.rad(-8), 0, 0),
		WALL_COLOR, section2)
	makePart("RampWallR_"..i, Vector3.new(2, 10, SEGMENT_LENGTH),
		CFrame.new(rampPos + Vector3.new(ROAD_WIDTH/2 + 1, 4, 0)) * CFrame.Angles(math.rad(-8), 0, 0),
		WALL_COLOR, section2)
end

-- ============================================================
-- SECTION 3: UNDERGROUND TUNNEL
-- ============================================================
local section3 = Instance.new("Folder")
section3.Name = "Section3_Tunnel"
section3.Parent = map

local tunnelY = -16
local s3Start = s2Start + Vector3.new(0, -16, 4 * SEGMENT_LENGTH)

-- Tunnel direction changes: straight, left turn, straight, right turn, straight
local tunnelSegments = {
	{dir = Vector3.new(0, 0, 1), count = 4},  -- straight
	{dir = Vector3.new(1, 0, 0), count = 3},  -- turn right
	{dir = Vector3.new(0, 0, 1), count = 4},  -- straight
	{dir = Vector3.new(-1, 0, 0), count = 2}, -- turn left
	{dir = Vector3.new(0, 0, 1), count = 3},  -- straight back
}

local tunnelPos = s3Start
local checkpointCount = 2

for _, seg in ipairs(tunnelSegments) do
	for i = 0, seg.count - 1 do
		local segCenter = tunnelPos + seg.dir * (i * SEGMENT_LENGTH) + Vector3.new(0, tunnelY, 0)

		-- Road floor
		makePart("TRoad_"..i,
			Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
			CFrame.new(segCenter) * CFrame.fromMatrix(Vector3.new(), seg.dir:Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0)),
			TUNNEL_COLOR, section3)

		-- Tunnel ceiling
		makePart("TCeil_"..i,
			Vector3.new(ROAD_WIDTH + 4, ROAD_THICKNESS, SEGMENT_LENGTH),
			CFrame.new(segCenter + Vector3.new(0, TUNNEL_HEIGHT, 0)) * CFrame.fromMatrix(Vector3.new(), seg.dir:Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0)),
			TUNNEL_COLOR, section3)

		-- Tunnel left wall
		makePart("TWallL_"..i,
			Vector3.new(ROAD_THICKNESS, TUNNEL_HEIGHT, SEGMENT_LENGTH),
			CFrame.new(segCenter + Vector3.new(-ROAD_WIDTH/2 - 1, TUNNEL_HEIGHT/2, 0)) * CFrame.fromMatrix(Vector3.new(), seg.dir:Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0)),
			WALL_COLOR, section3)

		-- Tunnel right wall
		makePart("TWallR_"..i,
			Vector3.new(ROAD_THICKNESS, TUNNEL_HEIGHT, SEGMENT_LENGTH),
			CFrame.new(segCenter + Vector3.new(ROAD_WIDTH/2 + 1, TUNNEL_HEIGHT/2, 0)) * CFrame.fromMatrix(Vector3.new(), seg.dir:Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0)),
			WALL_COLOR, section3)

		-- Tunnel lights on ceiling
		local lightStrip = makePart("TLight_"..i,
			Vector3.new(ROAD_WIDTH - 4, 0.5, SEGMENT_LENGTH - 4),
			CFrame.new(segCenter + Vector3.new(0, TUNNEL_HEIGHT - 1, 0)) * CFrame.fromMatrix(Vector3.new(), seg.dir:Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0)),
			LIGHT_COLOR, section3)
		lightStrip.Material = Enum.Material.Neon
		lightStrip.Transparency = 0.5

		-- Center road stripe
		makePart("TStripe_"..i,
			Vector3.new(1, ROAD_THICKNESS + 0.1, SEGMENT_LENGTH - 4),
			CFrame.new(segCenter + Vector3.new(0, 0.2, 0)) * CFrame.fromMatrix(Vector3.new(), seg.dir:Cross(Vector3.new(0,1,0)), Vector3.new(0,1,0)),
			STRIPE_COLOR, section3)
	end

	-- Add checkpoint at end of each tunnel section
	local cpPos = tunnelPos + seg.dir * (seg.count * SEGMENT_LENGTH) + Vector3.new(0, tunnelY, 0)
	addCheckpoint(cpPos, checkpointCount, section3)
	checkpointCount = checkpointCount + 1

	-- Advance tunnel position
	tunnelPos = tunnelPos + seg.dir * (seg.count * SEGMENT_LENGTH)
end

-- ============================================================
-- SECTION 4: TUNNEL EXIT RAMP (back to surface)
-- ============================================================
local section4 = Instance.new("Folder")
section4.Name = "Section4_TunnelExit"
section4.Parent = map

local s4Start = tunnelPos + Vector3.new(0, tunnelY, 0)

for i = 0, 3 do
	local rampPos = s4Start + Vector3.new(0, i * 4, i * SEGMENT_LENGTH)
	makePart("ExitRamp_"..i,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
		CFrame.new(rampPos) * CFrame.Angles(math.rad(8), 0, 0),
		ROAD_COLOR, section4)
	makePart("ExitWallL_"..i, Vector3.new(2, 10, SEGMENT_LENGTH),
		CFrame.new(rampPos + Vector3.new(-ROAD_WIDTH/2 - 1, 4, 0)) * CFrame.Angles(math.rad(8), 0, 0),
		WALL_COLOR, section4)
	makePart("ExitWallR_"..i, Vector3.new(2, 10, SEGMENT_LENGTH),
		CFrame.new(rampPos + Vector3.new(ROAD_WIDTH/2 + 1, 4, 0)) * CFrame.Angles(math.rad(8), 0, 0),
		WALL_COLOR, section4)
end

-- ============================================================
-- SECTION 5: FINAL STREET STRETCH + FINISH LINE
-- ============================================================
local section5 = Instance.new("Folder")
section5.Name = "Section5_Finish"
section5.Parent = map

local s5Start = s4Start + Vector3.new(0, 16, 4 * SEGMENT_LENGTH)

for i = 0, 3 do
	local segPos = s5Start + Vector3.new(0, -1, i * SEGMENT_LENGTH)
	makePart("Road_S5_"..i,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
		CFrame.new(segPos), ROAD_COLOR, section5)
	makePart("Stripe_S5_"..i,
		Vector3.new(1, ROAD_THICKNESS + 0.1, SEGMENT_LENGTH - 4),
		CFrame.new(segPos + Vector3.new(0, 0.1, 0)),
		STRIPE_COLOR, section5)
	makePart("WallL_S5_"..i, Vector3.new(2, WALL_HEIGHT, SEGMENT_LENGTH),
		CFrame.new(segPos + Vector3.new(-ROAD_WIDTH/2 - 1, WALL_HEIGHT/2, 0)),
		BUILDING_COLOR, section5)
	makePart("WallR_S5_"..i, Vector3.new(2, WALL_HEIGHT, SEGMENT_LENGTH),
		CFrame.new(segPos + Vector3.new(ROAD_WIDTH/2 + 1, WALL_HEIGHT/2, 0)),
		BUILDING_COLOR, section5)
end

-- Finish line
local finish = makePart("FinishLine",
	Vector3.new(ROAD_WIDTH, 0.5, 6),
	CFrame.new(s5Start + Vector3.new(0, 0, 3 * SEGMENT_LENGTH + 20)),
	Color3.fromRGB(255, 255, 255), section5)
finish.Material = Enum.Material.Neon
finish.Transparency = 0.3

local finishGui = Instance.new("SurfaceGui")
finishGui.Face = Enum.NormalId.Top
finishGui.Parent = finish
local finishLabel = Instance.new("TextLabel")
finishLabel.Size = UDim2.new(1, 0, 1, 0)
finishLabel.Text = "🏁 FINISH"
finishLabel.TextColor3 = Color3.new(0, 0, 0)
finishLabel.BackgroundTransparency = 1
finishLabel.Font = Enum.Font.GothamBold
finishLabel.TextScaled = true
finishLabel.Parent = finishGui

addCheckpoint(s5Start + Vector3.new(0, 0, 3 * SEGMENT_LENGTH + 20), 99, section5)

print("✅ CityMap generated successfully!")
print("Sections: Street → Tunnel Entrance → Underground Tunnel → Exit → Finish")
print("Total checkpoints placed: " .. (checkpointCount + 1))
