--[[
	TrackBuilder.lua
	Description: Builds a closed-loop racing circuit from a TrackConfig entry.
	             Control points are smoothed with a Catmull-Rom spline, then road,
	             barriers, curbs, checkpoints, coins and skyline are generated
	             along the resulting centerline. Purely geometry -- no race logic.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- Constants   (ReplicatedStorage.Module.Constants)
		- TrackConfig (ReplicatedStorage.Module.TrackConfig)

	Events Fired / Listened:
		- None
--]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Constants    = require(sharedFolder:WaitForChild("Constants", 10))
local TrackConfig  = require(sharedFolder:WaitForChild("TrackConfig", 10))

local COIN_TAG = "CoinPickup"

local TrackBuilder = {}

-- ── Geometry helpers ─────────────────────────────────────────────────────────

local function makePart(parent, name, size, cframe, color, material, anchored)
	local part = Instance.new("Part")
	part.Name          = name
	part.Size          = size
	part.CFrame        = cframe
	part.Color         = color
	part.Material      = material or Enum.Material.SmoothPlastic
	part.Anchored      = if anchored == nil then true else anchored
	part.CanCollide    = true
	part.TopSurface    = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent        = parent
	return part
end

-- Catmull-Rom: passes smoothly *through* every control point, which is what makes
-- the hand-placed corner positions in TrackConfig land where they were intended.
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * (
		(2 * p1)
		+ (-p0 + p2) * t
		+ (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
		+ (-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

-- Sample the closed loop into evenly-ish spaced centerline points (world space).
local function buildCenterline(controlPoints: {Vector3}, origin: Vector3, samplesPerSeg: number): {Vector3}
	local pts = {}
	local n = #controlPoints
	for i = 1, n do
		local p0 = controlPoints[((i - 2) % n) + 1]
		local p1 = controlPoints[i]
		local p2 = controlPoints[(i % n) + 1]
		local p3 = controlPoints[((i + 1) % n) + 1]
		for s = 0, samplesPerSeg - 1 do
			table.insert(pts, origin + catmullRom(p0, p1, p2, p3, s / samplesPerSeg))
		end
	end
	return pts
end

-- ── Track pieces ─────────────────────────────────────────────────────────────

local function buildRoadAndBarriers(track, pts, folders)
	local theme     = track.Theme
	local halfWidth = TrackConfig.ROAD_WIDTH * 0.5
	local barrierX  = halfWidth + TrackConfig.BARRIER_THICKNESS * 0.5
	local count     = #pts

	for i = 1, count do
		local a = pts[i]
		local b = pts[(i % count) + 1]
		local length = (b - a).Magnitude
		if length <= 0.05 then
			continue
		end

		local cf = CFrame.lookAt((a + b) * 0.5, b)
		local segLength = length + TrackConfig.SEGMENT_OVERLAP

		makePart(
			folders.road, string.format("Road_%03d", i),
			Vector3.new(TrackConfig.ROAD_WIDTH, TrackConfig.ROAD_THICKNESS, segLength),
			cf, theme.Road, Enum.Material.Asphalt
		)

		-- Red/white curbing sits just inside the barriers for visual guidance.
		local curbColor = (i % 2 == 0) and theme.Curb or Color3.fromRGB(238, 238, 238)
		for _, side in ipairs({ -1, 1 }) do
			makePart(
				folders.curb, string.format("Curb_%03d_%d", i, side),
				Vector3.new(3, TrackConfig.ROAD_THICKNESS + 0.4, segLength),
				cf * CFrame.new(side * (halfWidth - 1.5), 0.2, 0),
				curbColor, Enum.Material.Concrete
			)

			makePart(
				folders.barrier, string.format("Barrier_%03d_%d", i, side),
				Vector3.new(TrackConfig.BARRIER_THICKNESS, TrackConfig.BARRIER_HEIGHT, segLength),
				cf * CFrame.new(side * barrierX, TrackConfig.BARRIER_HEIGHT * 0.5, 0),
				theme.Barrier, Enum.Material.Metal
			)
		end
	end
end

local function buildCheckpoints(track, pts, folder)
	local count = #pts
	local step  = count / TrackConfig.CHECKPOINT_COUNT

	-- Numbered checkpoints, evenly distributed around the loop. Index 1 is the
	-- start/finish line itself, so numbered checkpoints begin one step in.
	for n = 1, TrackConfig.CHECKPOINT_COUNT do
		local idx = (math.floor(n * step) % count) + 1
		local a   = pts[idx]
		local b   = pts[(idx % count) + 1]
		local cf  = CFrame.lookAt((a + b) * 0.5, b)

		local cp = makePart(
			folder, string.format("Checkpoint_%d", n),
			Vector3.new(TrackConfig.ROAD_WIDTH, 8, 2),
			cf * CFrame.new(0, 4, 0),
			Constants.CYAN, Enum.Material.Neon
		)
		cp.Transparency = 0.55
		cp.CanCollide   = false
		cp.CastShadow   = false
	end

	-- Start/finish line (Checkpoint_99) at sample 1.
	local a  = pts[1]
	local b  = pts[2]
	local cf = CFrame.lookAt((a + b) * 0.5, b)

	local finish = makePart(
		folder, string.format("Checkpoint_%d", Constants.CHECKPOINT_FINISH),
		Vector3.new(TrackConfig.ROAD_WIDTH, 9, 2),
		cf * CFrame.new(0, 4.5, 0),
		Color3.fromRGB(255, 255, 255), Enum.Material.Neon
	)
	finish.Transparency = 0.5
	finish.CanCollide   = false
	finish.CastShadow   = false

	-- Checkered strip painted on the tarmac under the finish gate.
	makePart(
		folder, "StartFinishStripe",
		Vector3.new(TrackConfig.ROAD_WIDTH, 0.3, 6),
		cf * CFrame.new(0, TrackConfig.ROAD_THICKNESS * 0.5 + 0.15, 0),
		Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic
	).CanCollide = false

	return cf -- start/finish CFrame, used to place the grid
end

local function buildCoins(track, pts, folder)
	local count = #pts
	local made  = 0
	for i = 1, count, TrackConfig.COIN_EVERY_N_SAMPLES do
		local a = pts[i]
		local b = pts[(i % count) + 1]
		local cf = CFrame.lookAt((a + b) * 0.5, b)

		-- Weave the coin line across the track so collecting them traces a
		-- racing line rather than a single boring lane.
		local side = math.sin(i * 0.55) * TrackConfig.COIN_LATERAL_SPREAD
		made += 1

		local coin = makePart(
			folder, string.format("Coin_%03d", made),
			-- Cylinder axis is local X. Rotating 90deg about Y aims that axis down
			-- the road so the disc faces oncoming drivers (most visible at speed),
			-- and the client's Y-axis spin reads as a coin turning face-on.
			Vector3.new(0.5, 6, 6),
			cf * CFrame.new(side, 3.5, 0) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(255, 215, 0), Enum.Material.Neon
		)
		coin.Shape      = Enum.PartType.Cylinder
		coin.CanCollide = false
		coin.CastShadow = false
		CollectionService:AddTag(coin, COIN_TAG)
	end
	return made
end

local function buildSkyline(track, folder)
	local theme = track.Theme
	for i, b in ipairs(track.Buildings) do
		local pos = track.Origin + b.pos + Vector3.new(0, b.size.Y * 0.5, 0)
		makePart(
			folder, string.format("Building_%02d", i),
			b.size, CFrame.new(pos), theme.Building, Enum.Material.Glass
		)
	end
end

local function buildGround(track, pts, folder)
	-- Sized from the actual centerline bounds so it always covers the circuit.
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	local minY = math.huge
	for _, p in ipairs(pts) do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		minY = math.min(minY, p.Y)
	end

	local pad = 700
	local sizeX = (maxX - minX) + pad * 2
	local sizeZ = (maxZ - minZ) + pad * 2
	local center = Vector3.new((minX + maxX) * 0.5, minY - 4, (minZ + maxZ) * 0.5)

	makePart(
		folder, "Ground",
		Vector3.new(sizeX, 6, sizeZ),
		CFrame.new(center),
		Color3.fromRGB(48, 82, 52), Enum.Material.Grass
	).CastShadow = false

	-- Kill volume far below: catches anyone who leaves the circuit entirely.
	local floor = makePart(
		folder, "OutOfBounds_Floor",
		Vector3.new(sizeX + 600, 24, sizeZ + 600),
		CFrame.new(center - Vector3.new(0, 110, 0)),
		Color3.fromRGB(20, 20, 20), Enum.Material.ForceField
	)
	floor.Transparency = 1
	floor.CanCollide   = false
	floor.CastShadow   = false
	floor:SetAttribute("OutOfBoundsKill", true)
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
	Build(trackKey) -> Model
	Generates (or regenerates) the circuit named by trackKey in TrackConfig.Tracks.
	Destroys any existing model of the same name first, so this is safe to re-run.
--]]
function TrackBuilder.Build(trackKey: string): Model
	local track = TrackConfig.Tracks[trackKey]
	assert(track, "TrackBuilder: unknown track key " .. tostring(trackKey))

	local existing = workspace:FindFirstChild(track.FolderName)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = track.FolderName

	local folders = {}
	for _, name in ipairs({ "road", "curb", "barrier", "checkpoints", "coins", "skyline", "terrain" }) do
		local f = Instance.new("Folder")
		f.Name = name:sub(1, 1):upper() .. name:sub(2)
		f.Parent = model
		folders[name] = f
	end

	local pts = buildCenterline(track.ControlPoints, track.Origin, TrackConfig.SAMPLES_PER_SEG)

	buildGround(track, pts, folders.terrain)
	buildRoadAndBarriers(track, pts, folders)
	local startCFrame = buildCheckpoints(track, pts, folders.checkpoints)
	local coinCount   = buildCoins(track, pts, folders.coins)
	buildSkyline(track, folders.skyline)

	-- Grid sits behind the start/finish line, facing down the track. NOTE: Roblox
	-- LookVector is the -Z axis, so +Z here is BEHIND the line. Using -Z put the
	-- grid past the line, and driving forward then never crossed it (no race).
	local spawn = makePart(
		model, track.Id == "skyscraper" and "SkyscraperSpawn" or (track.FolderName .. "Spawn"),
		Vector3.new(20, 1, 20),
		startCFrame * CFrame.new(0, 3, 26),
		track.Theme.Accent, Enum.Material.Metal
	)
	spawn.Transparency = 1
	spawn.CanCollide   = false
	spawn.CastShadow   = false

	model.Parent = workspace

	-- Total centerline length, for lap-time sanity checking.
	local length = 0
	for i = 1, #pts do
		length += (pts[(i % #pts) + 1] - pts[i]).Magnitude
	end

	model:SetAttribute("CenterlineStuds", math.floor(length))
	model:SetAttribute("CoinCount", coinCount)
	model:SetAttribute("TotalLaps", track.TotalLaps)

	return model
end

return TrackBuilder
