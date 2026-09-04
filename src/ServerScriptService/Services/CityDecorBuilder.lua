--[[
	CityDecorBuilder.lua
	Description: Dresses the area AROUND an already-built race circuit with a
	             lightweight, reusable generic-city kit (buildings, street
	             furniture, signage, parked vehicles). Reads the live geometry of
	             the circuit (Road/Barrier/Checkpoints/Ground parts) to figure out
	             where it is safe to place scenery -- it never edits, destroys, or
	             reads into the track's own folders. Output is parented to its own
	             top-level model in Workspace, siblings of the track, so re-running
	             TrackBuilder.Build() (which destroys-and-rebuilds the track model)
	             can never take the decoration down with it.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- TrackConfig     (ReplicatedStorage.Module.TrackConfig)
		- CityDecorConfig (ReplicatedStorage.Module.CityDecorConfig)

	Events Fired / Listened:
		- None
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder     = ReplicatedStorage:WaitForChild("Module", 10)
local TrackConfig      = require(sharedFolder:WaitForChild("TrackConfig", 10))
local CityDecorConfig  = require(sharedFolder:WaitForChild("CityDecorConfig", 10))

local CityDecorBuilder = {}

-- ── Geometry helpers ─────────────────────────────────────────────────────────

local function makePart(parent, name, size, cframe, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name          = name
	part.Size          = size
	part.CFrame        = cframe
	part.Color         = color
	part.Material      = material or Enum.Material.SmoothPlastic
	part.Anchored      = true
	part.CanCollide    = if canCollide == nil then true else canCollide
	part.TopSurface    = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent        = parent
	return part
end

-- Cylinder parts have their round axis along local X; rotate 90 deg about Z so
-- the cylinder stands upright with the round axis along world Y.
local function upright(cf)
	return cf * CFrame.Angles(0, 0, math.rad(90))
end

-- Rectangular exclusion strips built from the track's own Road+Barrier parts,
-- inflated by a margin at query time. Keeps every placement decision anchored
-- to the circuit's REAL built geometry rather than a re-derived approximation.
local function buildExclusionZones(trackModel)
	local zones = {}
	for _, folderName in ipairs({ "Road", "Barrier" }) do
		local folder = trackModel:FindFirstChild(folderName)
		if folder then
			for _, part in ipairs(folder:GetChildren()) do
				if part:IsA("BasePart") then
					table.insert(zones, {
						cf    = part.CFrame,
						halfX = part.Size.X * 0.5,
						halfZ = part.Size.Z * 0.5,
					})
				end
			end
		end
	end
	return zones
end

local function isPointClear(point: Vector3, zones, margin: number): boolean
	for _, z in ipairs(zones) do
		local local_ = z.cf:PointToObjectSpace(point)
		if math.abs(local_.X) < z.halfX + margin and math.abs(local_.Z) < z.halfZ + margin then
			return false
		end
	end
	return true
end

local function pickWeighted(weights)
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local roll = math.random() * total
	local acc = 0
	for kind, w in pairs(weights) do
		acc += w
		if roll <= acc then
			return kind
		end
	end
	return next(weights)
end

local function pickZoneForAngle(angleDeg: number)
	for _, zone in ipairs(CityDecorConfig.Zones) do
		if angleDeg >= zone.minDeg and angleDeg < zone.maxDeg then
			return zone
		end
	end
	return CityDecorConfig.Zones[#CityDecorConfig.Zones]
end

-- ── Small reusable props ─────────────────────────────────────────────────────
-- Grouped by shape so seven of the requested kit items share one function.

local SIMPLE_PROPS = {
	Hydrant    = { size = Vector3.new(1.6, 3.0, 1.6), color = Color3.fromRGB(196, 44, 44),  material = Enum.Material.Metal,    cylinder = true },
	UtilityBox = { size = Vector3.new(2.6, 4.0, 2.0), color = Color3.fromRGB(92, 96, 100),   material = Enum.Material.Metal },
	Bollard    = { size = Vector3.new(1.0, 3.4, 1.0), color = Color3.fromRGB(224, 176, 24),  material = Enum.Material.Plastic,  cylinder = true },
	TrashCan   = { size = Vector3.new(1.8, 3.0, 1.8), color = Color3.fromRGB(58, 92, 70),    material = Enum.Material.Metal,    cylinder = true },
	Planter    = { size = Vector3.new(3.2, 1.6, 3.2), color = Color3.fromRGB(120, 92, 70),   material = Enum.Material.Concrete },
}

local function stampSimpleProp(parent, kind: string, cf: CFrame)
	local def = SIMPLE_PROPS[kind]
	local base = cf * CFrame.new(0, def.size.Y * 0.5, 0)
	local part = makePart(parent, kind, def.size, if def.cylinder then upright(base) else base, def.color, def.material)
	if def.cylinder then
		part.Shape = Enum.PartType.Cylinder
	end
	if kind == "Planter" then
		-- A little foliage so it doesn't read as a plain concrete box.
		makePart(parent, "PlanterBush", Vector3.new(2.2, 1.8, 2.2), cf * CFrame.new(0, 2.4, 0),
			Color3.fromRGB(58, 110, 58), Enum.Material.Grass, false).CastShadow = false
	end
	return part
end

local function stampTree(parent, cf: CFrame)
	local scale = 0.85 + math.random() * 0.5
	local trunk = makePart(parent, "TreeTrunk", Vector3.new(1.4, 8 * scale, 1.4),
		upright(cf * CFrame.new(0, 4 * scale, 0)), Color3.fromRGB(90, 62, 40), Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	local leaves = makePart(parent, "TreeLeaves", Vector3.new(9 * scale, 9 * scale, 9 * scale),
		cf * CFrame.new(0, 8 * scale + 3, 0), Color3.fromRGB(48, 104, 52), Enum.Material.Grass, false)
	leaves.Shape = Enum.PartType.Ball
	leaves.CastShadow = false
end

local function stampBench(parent, cf: CFrame)
	makePart(parent, "BenchSeat", Vector3.new(5, 0.4, 1.6), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(110, 78, 50), Enum.Material.Wood)
	makePart(parent, "BenchBack", Vector3.new(5, 1.4, 0.3), cf * CFrame.new(0, 2.2, -0.7), Color3.fromRGB(110, 78, 50), Enum.Material.Wood)
	makePart(parent, "BenchLegs", Vector3.new(5, 1.2, 1.6), cf * CFrame.new(0, 0.6, 0), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
end

local function stampRoadSign(parent, cf: CFrame)
	local pole = makePart(parent, "SignPost", Vector3.new(0.6, 8, 0.6), upright(cf * CFrame.new(0, 4, 0)), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
	pole.Shape = Enum.PartType.Cylinder
	local plate = makePart(parent, "SignPlate", Vector3.new(4, 1.4, 0.2), cf * CFrame.new(0, 8, 0), Color3.fromRGB(20, 90, 60), Enum.Material.SmoothPlastic, false)
	plate.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = CityDecorConfig.StreetNames[math.random(#CityDecorConfig.StreetNames)]
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
end

local function stampStreetlight(parent, cf: CFrame, withLight: boolean)
	local pole = makePart(parent, "LightPole", Vector3.new(0.8, 16, 0.8), upright(cf * CFrame.new(0, 8, 0)), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
	pole.Shape = Enum.PartType.Cylinder
	makePart(parent, "LightArm", Vector3.new(4, 0.5, 0.5), cf * CFrame.new(1.8, 15.6, 0), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
	local lamp = makePart(parent, "LightLamp", Vector3.new(1.4, 1, 1.4), cf * CFrame.new(3.6, 15, 0), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, false)
	lamp.CastShadow = false
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 225, 180)
		light.Range = 22
		light.Brightness = 1.4
		light.Parent = lamp
	end
end

local function stampTrafficLight(parent, cf: CFrame)
	local pole = makePart(parent, "SignalPole", Vector3.new(0.8, 12, 0.8), upright(cf * CFrame.new(0, 6, 0)), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
	pole.Shape = Enum.PartType.Cylinder
	local housing = makePart(parent, "SignalHousing", Vector3.new(1.4, 3.6, 1.2), cf * CFrame.new(0, 11.5, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal, false)
	housing.CastShadow = false
	local lensColors = { Color3.fromRGB(220, 40, 40), Color3.fromRGB(230, 200, 40), Color3.fromRGB(40, 200, 90) }
	for i, color in ipairs(lensColors) do
		local lens = makePart(parent, "Lens" .. i, Vector3.new(0.9, 0.9, 0.2), cf * CFrame.new(0, 12.6 - (i - 1) * 1.1, -0.7), color, Enum.Material.Neon, false)
		lens.CastShadow = false
	end
end

local function stampGuardrail(parent, cf: CFrame, length: number)
	makePart(parent, "GuardrailBeam", Vector3.new(length, 1.4, 0.3), cf * CFrame.new(0, 2.2, 0), Color3.fromRGB(200, 202, 206), Enum.Material.DiamondPlate)
	local postCount = math.max(2, math.floor(length / 8))
	for i = 0, postCount - 1 do
		local t = (i / (postCount - 1) - 0.5) * length
		local post = makePart(parent, "GuardrailPost" .. i, Vector3.new(0.4, 2.4, 0.4), upright(cf * CFrame.new(t, 1.2, 0)), Color3.fromRGB(120, 122, 126), Enum.Material.Metal)
		post.Shape = Enum.PartType.Cylinder
	end
end

local function stampConcreteBarrier(parent, cf: CFrame, length: number)
	makePart(parent, "ConcreteBarrierBase", Vector3.new(length, 2, 2.4), cf * CFrame.new(0, 1, 0), Color3.fromRGB(190, 190, 184), Enum.Material.Concrete)
	makePart(parent, "ConcreteBarrierTop", Vector3.new(length, 1, 1.2), cf * CFrame.new(0, 2.5, 0), Color3.fromRGB(190, 190, 184), Enum.Material.Concrete)
end

local function stampBusStop(parent, cf: CFrame)
	makePart(parent, "BusStopRoof", Vector3.new(7, 0.4, 3), cf * CFrame.new(0, 7.5, 0), Color3.fromRGB(70, 78, 90), Enum.Material.Metal, false)
	for _, side in ipairs({ -3, 3 }) do
		local post = makePart(parent, "BusStopPost" .. side, Vector3.new(0.5, 7.5, 0.5), upright(cf * CFrame.new(side, 3.75, 1.3)), Color3.fromRGB(70, 78, 90), Enum.Material.Metal)
		post.Shape = Enum.PartType.Cylinder
	end
	makePart(parent, "BusStopBackWall", Vector3.new(6.6, 4, 0.2), cf * CFrame.new(0, 2.5, -1.3), Color3.fromRGB(200, 220, 230), Enum.Material.Glass, false)
	stampBench(parent, cf * CFrame.new(0, 0, -0.4))
end

local function stampParkedCar(parent, cf: CFrame)
	local color = CityDecorConfig.CarColors[math.random(#CityDecorConfig.CarColors)]
	makePart(parent, "CarBody", Vector3.new(6.5, 1.6, 15), cf * CFrame.new(0, 1.5, 0), color, Enum.Material.Metal)
	makePart(parent, "CarCabin", Vector3.new(5.6, 1.6, 8), cf * CFrame.new(0, 2.9, -0.5), color:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Glass)
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -5, 5 }) do
			local wheel = makePart(parent, "Wheel", Vector3.new(1, 2.4, 2.4), upright(cf * CFrame.new(side * 3.1, 0.9, z)), Color3.fromRGB(24, 24, 24), Enum.Material.SmoothPlastic)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end

local function stampDeliveryVan(parent, cf: CFrame)
	makePart(parent, "VanBody", Vector3.new(7.5, 7, 20), cf * CFrame.new(0, 4, 0), Color3.fromRGB(235, 235, 235), Enum.Material.Metal)
	makePart(parent, "VanCab", Vector3.new(7.3, 5.5, 5), cf * CFrame.new(0, 3.2, 8.5), Color3.fromRGB(210, 30, 40), Enum.Material.Metal)
	makePart(parent, "VanWindshield", Vector3.new(7, 3, 0.3), cf * CFrame.new(0, 4.3, 10.9), Color3.fromRGB(160, 190, 200), Enum.Material.Glass, false)
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -7, 7 }) do
			local wheel = makePart(parent, "VanWheel", Vector3.new(1.2, 2.8, 2.8), upright(cf * CFrame.new(side * 3.75, 1.4, z)), Color3.fromRGB(24, 24, 24), Enum.Material.SmoothPlastic)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end

local function stampBillboard(parent, cf: CFrame)
	for _, side in ipairs({ -6, 6 }) do
		local post = makePart(parent, "BillboardPost" .. side, Vector3.new(1.2, 22, 1.2), upright(cf * CFrame.new(side, 11, 0)), Color3.fromRGB(90, 90, 92), Enum.Material.Metal)
		post.Shape = Enum.PartType.Cylinder
	end
	local face = makePart(parent, "BillboardFace", Vector3.new(16, 8, 0.6), cf * CFrame.new(0, 22, 0), Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic, false)
	face.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Parent = face
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = CityDecorConfig.BusinessNames[math.random(#CityDecorConfig.BusinessNames)]
	label.TextColor3 = Color3.fromRGB(255, 205, 90)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
end

local function stampByKind(kind: string, parent, cf: CFrame)
	if SIMPLE_PROPS[kind] then
		stampSimpleProp(parent, kind, cf)
	elseif kind == "Tree" then
		stampTree(parent, cf)
	elseif kind == "Bench" then
		stampBench(parent, cf)
	elseif kind == "RoadSign" then
		stampRoadSign(parent, cf)
	end
end

-- ── Buildings ────────────────────────────────────────────────────────────────

local function stampBuilding(parent, cf: CFrame, kindName: string)
	local def = CityDecorConfig.BuildingKinds[kindName]
	local footprint = def.footprint[1] + math.random() * (def.footprint[2] - def.footprint[1])
	local depth = footprint * (0.8 + math.random() * 0.4)
	local height = def.height[1] + math.random() * (def.height[2] - def.height[1])

	local model = Instance.new("Model")
	model.Name = kindName
	model.Parent = parent

	makePart(model, "Base", Vector3.new(footprint, height, depth), cf * CFrame.new(0, height * 0.5, 0), def.color, def.material)

	if def.storefront then
		makePart(model, "Storefront", Vector3.new(footprint + 0.4, 10, depth + 0.4), cf * CFrame.new(0, 6, 0),
			Color3.fromRGB(40, 50, 60), Enum.Material.Glass, false)

		-- Sign sits on the face pointing toward the track (local -Z == LookVector).
		local sign = makePart(model, "Sign", Vector3.new(footprint * 0.6, 3, 0.3), cf * CFrame.new(0, 11.5, -(depth * 0.5 + 0.2)),
			Color3.fromRGB(18, 18, 18), Enum.Material.SmoothPlastic, false)
		sign.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = CityDecorConfig.BusinessNames[math.random(#CityDecorConfig.BusinessNames)]
		label.TextColor3 = Color3.fromRGB(255, 225, 150)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
	end

	-- Illuminated-window bands: cheap night-time atmosphere via Neon material,
	-- no real light source involved.
	local floors = math.clamp(math.floor(height / 14), 1, 6)
	for f = 1, floors do
		if math.random() < 0.5 then
			makePart(model, "Windows" .. f, Vector3.new(footprint + 0.2, 3, depth + 0.2), cf * CFrame.new(0, math.min(height - 4, f * 14 + 8), 0),
				Color3.fromRGB(255, 214, 120), Enum.Material.Neon, false).CastShadow = false
		end
	end

	if def.hvac then
		for i = 1, math.random(1, 3) do
			local hx = (math.random() - 0.5) * footprint * 0.5
			local hz = (math.random() - 0.5) * depth * 0.5
			makePart(model, "HVAC" .. i, Vector3.new(4, 2.5, 4), cf * CFrame.new(hx, height + 1.25, hz), Color3.fromRGB(150, 150, 150), Enum.Material.Metal)
		end
	end

	if def.spire then
		makePart(model, "Spire", Vector3.new(3, 20, 3), cf * CFrame.new(0, height + 10, 0), Color3.fromRGB(200, 200, 200), Enum.Material.Metal, false)
	end

	if def.garage then
		-- Open-front parking slats read as a garage without a real interior.
		for lvl = 1, 4 do
			makePart(model, "Slat" .. lvl, Vector3.new(footprint - 4, 0.6, depth - 4), cf * CFrame.new(0, lvl * (height / 4), 0),
				Color3.fromRGB(90, 90, 92), Enum.Material.Concrete, false)
		end
	end

	return model
end

-- ── Phase 4: track-edge trim ─────────────────────────────────────────────────

local function buildTrackEdgeTrim(trackModel, folder)
	local roadFolder = trackModel:FindFirstChild("Road")
	if not roadFolder then
		return
	end

	local halfWidth    = TrackConfig.ROAD_WIDTH * 0.5
	local barrierOuter = halfWidth + TrackConfig.BARRIER_THICKNESS

	local roadParts = {}
	for _, part in ipairs(roadFolder:GetChildren()) do
		local idx = part:IsA("BasePart") and tonumber(part.Name:match("_(%d+)$"))
		if idx then
			table.insert(roadParts, { idx = idx, part = part })
		end
	end
	table.sort(roadParts, function(a, b)
		return a.idx < b.idx
	end)

	local propCycle = { "Tree", "Bench", "Hydrant", "TrashCan", "Planter", "RoadSign", "Tree", "UtilityBox" }
	local propIndex = 0

	for _, entry in ipairs(roadParts) do
		if entry.idx % CityDecorConfig.EDGE_PROP_EVERY_N == 0 then
			local road   = entry.part
			local cf     = road.CFrame
			local segLen = road.Size.Z

			for _, side in ipairs({ -1, 1 }) do
				local right = cf.RightVector * side

				local sidewalkCenter = cf.Position + right * (barrierOuter + CityDecorConfig.EDGE_SIDEWALK_OFFSET + CityDecorConfig.EDGE_SIDEWALK_WIDTH * 0.5)
				makePart(folder, string.format("Sidewalk_%03d_%d", entry.idx, side),
					Vector3.new(CityDecorConfig.EDGE_SIDEWALK_WIDTH, 0.6, segLen + 2),
					CFrame.lookAt(sidewalkCenter, sidewalkCenter + cf.LookVector),
					Color3.fromRGB(176, 172, 166), Enum.Material.Concrete)

				propIndex += 1
				local propPos = cf.Position + right * (barrierOuter + CityDecorConfig.EDGE_PROP_OFFSET)
				local facingCf = CFrame.lookAt(propPos, cf.Position)

				stampStreetlight(folder, facingCf, propIndex % CityDecorConfig.EDGE_LIGHT_EVERY_N == 0)

				local kind = propCycle[(propIndex % #propCycle) + 1]
				local extraPos = propPos + cf.LookVector * (segLen * 0.28)
				stampByKind(kind, folder, CFrame.lookAt(extraPos, cf.Position))
			end
		end
	end
end

-- ── Intersections (numbered checkpoints read as cross-streets) ──────────────

local function buildIntersectionMarkers(trackModel, folder)
	local cpFolder = trackModel:FindFirstChild("Checkpoints")
	if not cpFolder then
		return
	end

	local halfWidth    = TrackConfig.ROAD_WIDTH * 0.5
	local barrierOuter = halfWidth + TrackConfig.BARRIER_THICKNESS

	for _, cp in ipairs(cpFolder:GetChildren()) do
		if cp:IsA("BasePart") then
			local n = tonumber(cp.Name:match("^Checkpoint_(%d+)$"))
			if n and n ~= 99 and n % 3 == 0 then
				local gateCf = cp.CFrame
				local basePos = Vector3.new(gateCf.Position.X, 0, gateCf.Position.Z)

				for _, side in ipairs({ -1, 1 }) do
					local pos = basePos + gateCf.RightVector * side * (barrierOuter + CityDecorConfig.EDGE_PROP_OFFSET + 4)
					stampTrafficLight(folder, CFrame.lookAt(pos, basePos))
				end

				local stripe = makePart(folder, "Crosswalk_" .. n, Vector3.new(TrackConfig.ROAD_WIDTH * 0.4, 0.15, 6),
					CFrame.lookAt(basePos, basePos + gateCf.LookVector) * CFrame.new(0, 0.075, 0),
					Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic, false)
				stripe.CastShadow = false
			end
		end
	end
end

-- ── City blocks ──────────────────────────────────────────────────────────────

local function placeBlock(folder, center: Vector3, zone, faceTarget: Vector3)
	local kind = pickWeighted(zone.buildingWeight)
	local cf   = CFrame.lookAt(center, faceTarget)
	stampBuilding(folder, cf, kind)

	local front = cf.LookVector
	local right = cf.RightVector
	local edge  = CityDecorConfig.BLOCK_SIZE * 0.36

	if zone.name == "Commercial" then
		stampSimpleProp(folder, "Bollard", CFrame.new(center + front * edge + right * 16))
		if math.random() < 0.5 then
			local pos = center + front * edge + right * 8
			stampParkedCar(folder, CFrame.lookAt(pos, pos + right))
		end
	elseif zone.name == "Parking" then
		for _, i in ipairs({ -1, 1 }) do
			local pos = center + front * edge + right * 10 * i
			stampParkedCar(folder, CFrame.lookAt(pos, pos + right))
		end
		stampConcreteBarrier(folder, CFrame.new(center + front * (edge + 14)) * CFrame.Angles(0, math.atan2(right.Z, right.X) - math.pi / 2, 0), 20)
		if math.random() < 0.35 then
			local vanPos = center - front * edge
			stampDeliveryVan(folder, CFrame.lookAt(vanPos, vanPos + right))
		end
	elseif zone.name == "Quiet" then
		stampByKind("Planter", folder, CFrame.new(center + front * edge + right * 12))
		stampByKind("Tree", folder, CFrame.new(center + front * edge - right * 12))
	else -- Downtown
		stampStreetlight(folder, CFrame.new(center + front * edge + right * 14), math.random() < 0.4)
		if math.random() < 0.25 then
			stampBillboard(folder, CFrame.lookAt(center + front * edge * 1.4, center))
		end
	end
end

local function buildCityBlocks(trackModel, folder, exclusionZones)
	local ground = trackModel:FindFirstChild("Terrain") and trackModel.Terrain:FindFirstChild("Ground")
	if not ground then
		return 0
	end

	local minX = ground.Position.X - ground.Size.X * 0.5 - CityDecorConfig.OUTER_PAD
	local maxX = ground.Position.X + ground.Size.X * 0.5 + CityDecorConfig.OUTER_PAD
	local minZ = ground.Position.Z - ground.Size.Z * 0.5 - CityDecorConfig.OUTER_PAD
	local maxZ = ground.Position.Z + ground.Size.Z * 0.5 + CityDecorConfig.OUTER_PAD
	local groundY = ground.Position.Y + ground.Size.Y * 0.5
	local cx, cz = ground.Position.X, ground.Position.Z
	local trackCenter = Vector3.new(cx, groundY, cz)

	local blockSize = CityDecorConfig.BLOCK_SIZE
	local placed = 0

	local x = minX + blockSize * 0.5
	while x < maxX do
		local z = minZ + blockSize * 0.5
		while z < maxZ do
			local point = Vector3.new(x, groundY, z)
			if isPointClear(point, exclusionZones, CityDecorConfig.BLOCK_MARGIN) then
				local dx, dz = x - cx, z - cz
				local angle = math.deg(math.atan2(dz, dx))
				if angle < 0 then
					angle += 360
				end
				local zone = pickZoneForAngle(angle)
				placeBlock(folder, point, zone, trackCenter)
				placed += 1
			end
			z += blockSize
		end
		x += blockSize
	end

	return placed
end

-- ── Public API ───────────────────────────────────────────────────────────────

--[[
	Build(trackKey, trackModel) -> Model
	Builds (or rebuilds) the decoration for the given track. Destroys any
	previous decoration model of the same name first, so this is safe to re-run
	after the circuit itself has been reshaped. Reads trackModel's geometry but
	never writes into it.
--]]
function CityDecorBuilder.Build(trackKey: string, trackModel: Model): Model
	local track = TrackConfig.Tracks[trackKey]
	assert(track, "CityDecorBuilder: unknown track key " .. tostring(trackKey))

	local decorName = track.FolderName .. "Decor"
	local existing = workspace:FindFirstChild(decorName)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = decorName

	local folders = {}
	for _, name in ipairs({ "EdgeTrim", "Intersections", "Blocks" }) do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = model
		folders[name] = f
	end

	local exclusionZones = buildExclusionZones(trackModel)

	buildTrackEdgeTrim(trackModel, folders.EdgeTrim)
	buildIntersectionMarkers(trackModel, folders.Intersections)
	local blocksPlaced = buildCityBlocks(trackModel, folders.Blocks, exclusionZones)

	model.Parent = workspace
	model:SetAttribute("BlocksPlaced", blocksPlaced)
	model:SetAttribute("PartCount", #model:GetDescendants())

	return model
end

return CityDecorBuilder
