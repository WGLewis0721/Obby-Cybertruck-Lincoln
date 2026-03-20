if not workspace:FindFirstChild("MountainMap") then

-- ============================================================
-- MOUNTAIN & FOREST MAP GENERATOR - Winding Path Up the Mountain
-- Run this script once in the Roblox Studio Command Bar
-- or as a Script in ServerScriptService set to run once.
-- It will generate a "MountainMap" folder in Workspace.
-- ============================================================

local map = Instance.new("Folder")
map.Name = "MountainMap"
map.Parent = workspace

-- ============================================================
-- SETTINGS
-- ============================================================
local ROAD_WIDTH = 24
local ROAD_THICKNESS = 2
local SEGMENT_LENGTH = 55
local START_POS = Vector3.new(500, 0, 0) -- offset from city map

-- Colors
local ROAD_COLOR = Color3.fromRGB(80, 75, 65)       -- dirt/gravel road
local BARRIER_COLOR = Color3.fromRGB(180, 140, 80)  -- wooden guardrail
local TREE_TRUNK = Color3.fromRGB(100, 70, 40)
local TREE_LEAVES = Color3.fromRGB(34, 85, 34)
local TREE_LEAVES2 = Color3.fromRGB(20, 110, 40)
local ROCK_COLOR = Color3.fromRGB(110, 105, 100)
local SNOW_COLOR = Color3.fromRGB(235, 240, 245)
local GRASS_COLOR = Color3.fromRGB(60, 120, 40)
local STRIPE_COLOR = Color3.fromRGB(220, 200, 100)
local MOUNTAIN_COLOR = Color3.fromRGB(130, 120, 110)

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

local function addTree(pos, scale, hasSnow, parent)
	scale = scale or 1
	-- Trunk
	makePart("Trunk", Vector3.new(2*scale, 8*scale, 2*scale),
		CFrame.new(pos + Vector3.new(0, 4*scale, 0)),
		TREE_TRUNK, parent, Enum.Material.Wood)
	-- Lower foliage
	makePart("Leaves1", Vector3.new(10*scale, 8*scale, 10*scale),
		CFrame.new(pos + Vector3.new(0, 10*scale, 0)),
		hasSnow and SNOW_COLOR or TREE_LEAVES,
		parent, Enum.Material.Grass)
	-- Upper foliage
	makePart("Leaves2", Vector3.new(7*scale, 6*scale, 7*scale),
		CFrame.new(pos + Vector3.new(0, 16*scale, 0)),
		hasSnow and SNOW_COLOR or TREE_LEAVES2,
		parent, Enum.Material.Grass)
	-- Top
	makePart("Leaves3", Vector3.new(4*scale, 4*scale, 4*scale),
		CFrame.new(pos + Vector3.new(0, 21*scale, 0)),
		hasSnow and SNOW_COLOR or TREE_LEAVES,
		parent, Enum.Material.Grass)
end

local function addRock(pos, size, parent)
	local r = makePart("Rock", size,
		CFrame.new(pos) * CFrame.Angles(
			math.rad(math.random(-20, 20)),
			math.rad(math.random(0, 360)),
			math.rad(math.random(-15, 15))
		),
		ROCK_COLOR, parent, Enum.Material.Rock)
	return r
end

local function addGuardrail(pos, length, side, yRot, parent)
	-- Post
	makePart("Post_"..side, Vector3.new(1, 4, 1),
		CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, yRot, 0),
		BARRIER_COLOR, parent, Enum.Material.Wood)
	-- Rail
	makePart("Rail_"..side, Vector3.new(length, 1.5, 1),
		CFrame.new(pos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, yRot, 0),
		BARRIER_COLOR, parent, Enum.Material.Wood)
end

-- ============================================================
-- SPAWN POINT
-- ============================================================
local spawn = Instance.new("SpawnLocation")
spawn.Name = "MountainMapSpawn"
spawn.Size = Vector3.new(ROAD_WIDTH - 4, 1, 8)
spawn.CFrame = CFrame.new(START_POS + Vector3.new(0, 1, 0))
spawn.Anchored = true
spawn.Color = Color3.fromRGB(255, 140, 0)
spawn.Material = Enum.Material.Neon
spawn.Transparency = 0.7
spawn.Parent = map

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
local currentPos = START_POS
local currentAngle = 0
local currentY = 0
local checkpointNum = 1

for i, seg in ipairs(path) do
	local section = Instance.new("Folder")
	section.Name = "Seg_"..i..(seg.label ~= "" and "_"..seg.label:gsub(" ", "") or "")
	section.Parent = map

	currentAngle = currentAngle + seg.angle
	local rad = math.rad(currentAngle)
	local dir = Vector3.new(math.sin(rad), 0, math.cos(rad))
	currentY = currentY + seg.rise

	local segCenter = currentPos + dir * (SEGMENT_LENGTH / 2) + Vector3.new(0, currentY, 0)
	local roadCF = CFrame.new(segCenter, segCenter + dir) * CFrame.Angles(0, math.rad(90), 0)

	-- Road surface
	local roadColor = seg.snow and SNOW_COLOR or ROAD_COLOR
	makePart("Road_"..i,
		Vector3.new(ROAD_WIDTH, ROAD_THICKNESS, SEGMENT_LENGTH),
		roadCF, roadColor, section,
		seg.snow and Enum.Material.Snow or Enum.Material.Gravel)

	-- Center dashes
	if not seg.snow then
		makePart("Stripe_"..i,
			Vector3.new(1, ROAD_THICKNESS + 0.1, SEGMENT_LENGTH - 8),
			roadCF * CFrame.new(0, 0.1, 0),
			STRIPE_COLOR, section)
	end

	-- Mountain wall on inside (left)
	makePart("MtnWall_"..i,
		Vector3.new(4, 20, SEGMENT_LENGTH),
		roadCF * CFrame.new(-ROAD_WIDTH/2 - 2, 8, 0),
		MOUNTAIN_COLOR, section, Enum.Material.Rock)

	-- Guardrail on outside (right - cliff side)
	for g = 0, 4 do
		local gOffset = -SEGMENT_LENGTH/2 + g * (SEGMENT_LENGTH/4)
		addGuardrail(
			segCenter + dir:Cross(Vector3.new(0,1,0)) * (ROAD_WIDTH/2 + 1) + Vector3.new(0, currentY - seg.rise, 0) + dir * gOffset,
			SEGMENT_LENGTH/4, "R_"..i.."_"..g, rad, section)
	end

	-- Trees on mountain side (left)
	local perpLeft = dir:Cross(Vector3.new(0,1,0)) * -1
	for t = 0, 2 do
		local treeOffset = -SEGMENT_LENGTH/3 + t * (SEGMENT_LENGTH/3)
		local treePos = segCenter + perpLeft * (ROAD_WIDTH/2 + math.random(6, 14)) + dir * treeOffset
		addTree(treePos, math.random(8,12)/10, seg.snow, section)
	end

	-- Rocks scattered on mountain side
	if i % 3 == 0 then
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

-- Summit platform
makePart("SummitPlatform",
	Vector3.new(60, 4, 60),
	CFrame.new(summitPos),
	SNOW_COLOR, summit, Enum.Material.Snow)

-- Summit rocks
for i = 1, 6 do
	addRock(
		summitPos + Vector3.new(math.random(-25, 25), 2, math.random(-25, 25)),
		Vector3.new(math.random(4,8), math.random(3,6), math.random(4,8)),
		summit)
end

-- Finish line
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

-- Summit spawn
local summitSpawn = Instance.new("SpawnLocation")
summitSpawn.Name = "SummitViewpoint"
summitSpawn.Size = Vector3.new(10, 1, 10)
summitSpawn.CFrame = CFrame.new(summitPos + Vector3.new(20, 3, 0))
summitSpawn.Anchored = true
summitSpawn.Color = SNOW_COLOR
summitSpawn.Transparency = 0.5
summitSpawn.Parent = summit

addCheckpoint(summitPos + Vector3.new(0, 3, 0), 0, 99, summit)

print("✅ MountainMap generated successfully!")
print("Segments: " .. #path .. " winding road sections")
print("Elevation gain: ~" .. (currentY + 12) .. " studs")
print("Checkpoints placed: " .. checkpointNum)
print("Features: Forest → Mid Mountain → Treeline → Snow Zone → Summit")

end
