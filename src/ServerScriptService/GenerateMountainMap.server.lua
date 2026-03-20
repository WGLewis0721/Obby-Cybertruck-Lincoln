if not workspace:FindFirstChild("BigFootMap") then

-- ============================================================
-- BIG FOOT MAP GENERATOR - Winding Mountain Path
-- Generates a "BigFootMap" folder in Workspace.
-- Mountain body, snow cap, forest floor, trees, and dirt road
-- use the Terrain API.  Guardrails and checkpoints use Parts.
-- ============================================================

local terrain = workspace.Terrain

local map = Instance.new("Folder")
map.Name = "BigFootMap"
map.Parent = workspace

-- ============================================================
-- SETTINGS
-- ============================================================
local ROAD_WIDTH     = 24
local ROAD_THICKNESS = 2
local SEGMENT_LENGTH = 55
local START_POS      = Vector3.new(500, 0, 0) -- offset from Skyscraper map

-- Colors (Parts only)
local BARRIER_COLOR = Color3.fromRGB(180, 140, 80)
local ROCK_COLOR    = Color3.fromRGB(110, 105, 100)
local SNOW_COLOR    = Color3.fromRGB(235, 240, 245)
local STRIPE_COLOR  = Color3.fromRGB(220, 200, 100)

local terrainFills = 0
local partsPlaced  = 0

-- ============================================================
-- HELPERS
-- ============================================================
local function makePart(name, size, cframe, color, parent, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent or map
	partsPlaced = partsPlaced + 1
	return p
end

local function addCheckpoint(pos, rot, number, parent)
	local cp = makePart(
		"Checkpoint_" .. number,
		Vector3.new(ROAD_WIDTH, 0.5, 4),
		CFrame.new(pos) * CFrame.Angles(0, rot, 0),
		Color3.fromRGB(255, 140, 0),
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

local function addRock(pos, size, parent)
	return makePart("Rock", size,
		CFrame.new(pos) * CFrame.Angles(
			math.rad(math.random(-20, 20)),
			math.rad(math.random(0, 360)),
			math.rad(math.random(-15, 15))
		),
		ROCK_COLOR, parent, Enum.Material.Rock)
end

local function addGuardrail(pos, length, side, yRot, parent)
	makePart("Post_"..side, Vector3.new(1, 4, 1),
		CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, yRot, 0),
		BARRIER_COLOR, parent, Enum.Material.Wood)
	makePart("Rail_"..side, Vector3.new(length, 1.5, 1),
		CFrame.new(pos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, yRot, 0),
		BARRIER_COLOR, parent, Enum.Material.Wood)
end

-- ============================================================
-- TERRAIN: FOREST FLOOR BASE
-- ============================================================
-- Large grass base covering the full map area
terrain:FillBlock(
	CFrame.new(START_POS + Vector3.new(0, -3, 600)),
	Vector3.new(800, 4, 800),
	Enum.Material.Grass
)
terrainFills = terrainFills + 1

-- Mud patches near road at low elevation (scattered)
local mudOffsets = {
	Vector3.new(40, -2, 100), Vector3.new(-35, -2, 180),
	Vector3.new(50, -2, 260), Vector3.new(-45, -2, 330),
	Vector3.new(30, -2, 420), Vector3.new(-50, -2, 500),
}
for _, offset in ipairs(mudOffsets) do
	terrain:FillBlock(
		CFrame.new(START_POS + offset),
		Vector3.new(math.random(20, 40), 2, math.random(20, 40)),
		Enum.Material.Mud
	)
	terrainFills = terrainFills + 1
end

-- ============================================================
-- TERRAIN: MOUNTAIN BODY (stacked FillCylinder calls)
-- Mountain center is positioned toward the end of the winding path
-- ============================================================
local MOUNTAIN_CENTER = START_POS + Vector3.new(80, 0, 820)

-- 8 stacked cylinders of decreasing radius to form organic mountain shape
local mountainLayers = {
	{yOffset = 0,   radius = 220, height = 30},
	{yOffset = 15,  radius = 180, height = 40},
	{yOffset = 35,  radius = 150, height = 50},
	{yOffset = 60,  radius = 120, height = 55},
	{yOffset = 90,  radius = 90,  height = 60},
	{yOffset = 125, radius = 65,  height = 60},
	{yOffset = 160, radius = 45,  height = 55},
	{yOffset = 190, radius = 28,  height = 40},
}

for _, layer in ipairs(mountainLayers) do
	terrain:FillCylinder(
		CFrame.new(MOUNTAIN_CENTER.X, layer.yOffset + layer.height / 2, MOUNTAIN_CENTER.Z),
		layer.height, layer.radius, Enum.Material.Rock
	)
	terrainFills = terrainFills + 1
end

-- Snow cap at peak
terrain:FillCylinder(
	CFrame.new(MOUNTAIN_CENTER.X, 210, MOUNTAIN_CENTER.Z),
	40, 60, Enum.Material.Snow
)
terrainFills = terrainFills + 1

-- ============================================================
-- TERRAIN: TREES (FillCylinder for trunk and foliage)
-- 70 trees in the forest zone (low-mid elevation, no snow zone)
-- ============================================================
local SNOW_Y_THRESHOLD = 80 -- no trees above this elevation
local FOREST_RADIUS    = 180

for t = 1, 70 do
	local angle  = math.random() * math.pi * 2
	local dist   = math.random(40, FOREST_RADIUS)
	local treeX  = MOUNTAIN_CENTER.X + math.cos(angle) * dist
	local treeZ  = MOUNTAIN_CENTER.Z + math.sin(angle) * dist
	local treeY  = math.random(0, SNOW_Y_THRESHOLD - 20)

	-- Trunk (WoodPlanks)
	local trunkH = math.random(6, 10)
	terrain:FillCylinder(
		CFrame.new(treeX, treeY + trunkH / 2, treeZ),
		trunkH, math.random(1, 2), Enum.Material.WoodPlanks
	)
	terrainFills = terrainFills + 1

	-- Foliage (LeafyGrass)
	local foliageH = math.random(8, 14)
	terrain:FillCylinder(
		CFrame.new(treeX, treeY + trunkH + foliageH / 2, treeZ),
		foliageH, math.random(4, 7), Enum.Material.LeafyGrass
	)
	terrainFills = terrainFills + 1
end

-- ============================================================
-- SPAWN POINT
-- ============================================================
local spawn = Instance.new("SpawnLocation")
spawn.Name = "BigFootSpawn"
spawn.Size = Vector3.new(ROAD_WIDTH - 4, 1, 8)
spawn.CFrame = CFrame.new(START_POS + Vector3.new(0, 1, 0))
spawn.Anchored = true
spawn.Color = Color3.fromRGB(255, 140, 0)
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.7
spawn.Parent = map
partsPlaced = partsPlaced + 1

-- ============================================================
-- PATH DEFINITION
-- Winding mountain path with elevation gain
-- Each segment: {direction angle in degrees, elevation gain, isSnow}
-- ============================================================
local path = {
	-- Forest floor approach
	{angle=0,   rise=0,  snow=false, label="Forest Entrance"},
	{angle=0,   rise=2,  snow=false, label=""},
	{angle=15,  rise=4,  snow=false, label=""},
	{angle=-10, rise=4,  snow=false, label="First Bend"},
	{angle=0,   rise=5,  snow=false, label=""},
	{angle=20,  rise=5,  snow=false, label=""},
	-- Mid mountain
	{angle=-25, rise=6,  snow=false, label="Hairpin 1"},
	{angle=0,   rise=6,  snow=false, label=""},
	{angle=15,  rise=7,  snow=false, label=""},
	{angle=-15, rise=7,  snow=false, label="Mid Mountain"},
	{angle=0,   rise=8,  snow=false, label=""},
	-- Treeline transition
	{angle=20,  rise=8,  snow=false, label="Treeline"},
	{angle=-20, rise=9,  snow=true,  label="Hairpin 2"},
	{angle=0,   rise=9,  snow=true,  label=""},
	-- Snow zone
	{angle=10,  rise=10, snow=true,  label="Snow Zone"},
	{angle=-10, rise=10, snow=true,  label=""},
	{angle=0,   rise=11, snow=true,  label=""},
	{angle=15,  rise=11, snow=true,  label="Final Climb"},
	{angle=-5,  rise=12, snow=true,  label="Summit Approach"},
	{angle=0,   rise=12, snow=true,  label="Summit"},
}

-- ============================================================
-- GENERATE PATH SEGMENTS
-- ============================================================
local currentPos   = START_POS
local currentAngle = 0
local currentY     = 0
local checkpointNum = 1

for i, seg in ipairs(path) do
	local section = Instance.new("Folder")
	section.Name = "Seg_"..i..(seg.label ~= "" and "_"..seg.label:gsub(" ", "") or "")
	section.Parent = map

	currentAngle = currentAngle + seg.angle
	local rad = math.rad(currentAngle)
	local dir = Vector3.new(math.sin(rad), 0, math.cos(rad))
	currentY  = currentY + seg.rise

	local segCenter = currentPos + dir * (SEGMENT_LENGTH / 2) + Vector3.new(0, currentY, 0)
	local roadCF    = CFrame.new(segCenter, segCenter + dir) * CFrame.Angles(0, math.rad(90), 0)

	-- Road surface (Terrain) – dirt/mud off-road feel, snow in snow zone
	local roadMaterial = seg.snow and Enum.Material.Snow or Enum.Material.Ground
	terrain:FillBlock(
		roadCF,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
		roadMaterial
	)
	terrainFills = terrainFills + 1

	-- Mud overlay for non-snow sections (gives off-road texture)
	if not seg.snow and i % 3 == 1 then
		terrain:FillBlock(
			roadCF,
			Vector3.new(ROAD_WIDTH - 8, ROAD_THICKNESS, SEGMENT_LENGTH / 2),
			Enum.Material.Mud
		)
		terrainFills = terrainFills + 1
	end

	-- Center dashes (Part – subtle marker, only on non-snow sections)
	if not seg.snow then
		makePart("Stripe_"..i,
			Vector3.new(1, ROAD_THICKNESS + 0.1, SEGMENT_LENGTH - 8),
			roadCF * CFrame.new(0, 0.1, 0),
			STRIPE_COLOR, section)
	end

	-- Mountain wall on inside (left) – Part
	makePart("MtnWall_"..i,
		Vector3.new(4, 20, SEGMENT_LENGTH),
		roadCF * CFrame.new(-ROAD_WIDTH/2 - 2, 8, 0),
		ROCK_COLOR, section, Enum.Material.Rock)

	-- Guardrail on outside (right – cliff side) – Parts
	for g = 0, 4 do
		local gOffset = -SEGMENT_LENGTH/2 + g * (SEGMENT_LENGTH/4)
		addGuardrail(
			segCenter + dir:Cross(Vector3.new(0,1,0)) * (ROAD_WIDTH/2 + 1)
				+ Vector3.new(0, currentY - seg.rise, 0) + dir * gOffset,
			SEGMENT_LENGTH/4, "R_"..i.."_"..g, rad, section)
	end

	-- Rocks scattered on mountain side
	if i % 3 == 0 then
		local perpLeft = dir:Cross(Vector3.new(0,1,0)) * -1
		addRock(
			segCenter + perpLeft * (ROAD_WIDTH/2 + 3) + Vector3.new(0, 1, 0),
			Vector3.new(math.random(3,6), math.random(2,4), math.random(3,6)),
			section)
	end

	-- Checkpoints every 4 segments
	if i % 4 == 0 then
		addCheckpoint(segCenter, rad, checkpointNum, section)
		checkpointNum = checkpointNum + 1
	end

	-- Advance position
	currentPos = currentPos + dir * SEGMENT_LENGTH
end

-- ============================================================
-- SUMMIT PLATFORM + FINISH
-- ============================================================
local summit = Instance.new("Folder")
summit.Name = "Summit"
summit.Parent = map

local summitPos = currentPos + Vector3.new(0, currentY + 12, 0)

-- Summit platform (Terrain Snow fill)
terrain:FillBlock(
	CFrame.new(summitPos),
	Vector3.new(60, 4, 60),
	Enum.Material.Snow
)
terrainFills = terrainFills + 1

-- Summit rocks (Parts)
for i = 1, 6 do
	addRock(
		summitPos + Vector3.new(math.random(-25, 25), 2, math.random(-25, 25)),
		Vector3.new(math.random(4,8), math.random(3,6), math.random(4,8)),
		summit)
end

-- Finish line (Part)
local finish = makePart("FinishLine",
	Vector3.new(ROAD_WIDTH, 0.5, 6),
	CFrame.new(summitPos + Vector3.new(0, 3, 0)),
	Color3.fromRGB(255, 255, 255), summit)
finish.Material = Enum.Material.Neon
finish.Transparency = 0.3

local finishGui = Instance.new("SurfaceGui")
finishGui.Face = Enum.NormalId.Top
finishGui.Parent = finish
local finishLabel = Instance.new("TextLabel")
finishLabel.Size = UDim2.new(1, 0, 1, 0)
finishLabel.Text = "🏁 SUMMIT FINISH"
finishLabel.TextColor3 = Color3.new(0, 0, 0)
finishLabel.BackgroundTransparency = 1
finishLabel.Font = Enum.Font.GothamBold
finishLabel.TextScaled = true
finishLabel.Parent = finishGui

-- Summit viewpoint spawn (Part)
local summitSpawn = Instance.new("SpawnLocation")
summitSpawn.Name = "SummitViewpoint"
summitSpawn.Size = Vector3.new(10, 1, 10)
summitSpawn.CFrame = CFrame.new(summitPos + Vector3.new(20, 3, 0))
summitSpawn.Anchored = true
summitSpawn.Color = SNOW_COLOR
summitSpawn.Transparency = 0.5
summitSpawn.Parent = summit
partsPlaced = partsPlaced + 1

addCheckpoint(summitPos + Vector3.new(0, 3, 0), 0, 99, summit)

-- ============================================================
-- CLEANUP: Replace stray Air voxels with Grass
-- ============================================================
workspace.Terrain:ReplaceMaterial(
	Region3.new(
		Vector3.new(START_POS.X - 400, -5, START_POS.Z - 50),
		Vector3.new(START_POS.X + 400, 240, START_POS.Z + 1200)
	),
	4,
	Enum.Material.Air,
	Enum.Material.Grass
)

print("✅ Big Foot terrain generated")
print("Terrain fills: " .. terrainFills .. " calls")
print("Parts placed: " .. partsPlaced)

end
