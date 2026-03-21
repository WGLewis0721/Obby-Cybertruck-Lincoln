--[[
    GenerateCityMap.server.lua
    Description: Generates the default Skyscraper map at startup when it is not
                 already present in Workspace. The generated layout includes a
                 spawn marker plus race checkpoints that CheckpointHandler can
                 discover immediately.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants = require(sharedFolder:WaitForChild("Constants", 10))
local Logger = require(sharedFolder:WaitForChild("Logger", 10))

local TAG = "GenerateCityMap"
local MAP_NAME = "SkyscraperMap"
local SPAWN_NAME = "SkyscraperSpawn"
local SPAWN_OFFSET = Vector3.new(-10, 3, 0)
local OUT_OF_BOUNDS_ATTRIBUTE = "OutOfBoundsKill"

local ROAD_COLOR = Color3.fromRGB(54, 58, 66)
local CURB_COLOR = Color3.fromRGB(120, 123, 132)
local GLASS_COLOR = Color3.fromRGB(88, 170, 220)
local ACCENT_COLOR = Color3.fromRGB(255, 191, 71)
local CHECKPOINT_COLOR = Constants.CYAN

local ROAD_WIDTH = 40
local ROAD_THICKNESS = 2
local CURB_HEIGHT = 4
local CURB_THICKNESS = 2
local SEGMENT_LENGTH = 60
local SEGMENT_STEP_X = 90
local SEGMENT_RISE = 8
local SEGMENT_COUNT = 6
local STREET_GROUND_CENTER_OFFSET = Vector3.new(220, -2, 0)
local STREET_GROUND_SIZE = Vector3.new(700, 2, 220)
local OUT_OF_BOUNDS_FLOOR_OFFSET = Vector3.new(220, -45, 0)
local OUT_OF_BOUNDS_FLOOR_SIZE = Vector3.new(900, 24, 360)
local OUT_OF_BOUNDS_WALL_HALF_X = 380
local OUT_OF_BOUNDS_WALL_HALF_Z = 150
local OUT_OF_BOUNDS_WALL_HEIGHT = 180
local OUT_OF_BOUNDS_WALL_THICKNESS = 16
local OUT_OF_BOUNDS_WALL_Y = 40

local function makePart(parent, name, size, cframe, color, material)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = true
    part.CastShadow = true
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function makeCheckpoint(parent, number, position)
    local checkpoint = makePart(
        parent,
        string.format("Checkpoint_%d", number),
        Vector3.new(4, 8, ROAD_WIDTH - 6),
        CFrame.new(position + Vector3.new(0, 4, 0)),
        CHECKPOINT_COLOR,
        Enum.Material.Neon
    )
    checkpoint.Transparency = 0.5
    checkpoint.CanCollide = false
    return checkpoint
end

local function makeCurbs(parent, prefix, cframe, length)
    local offset = (ROAD_WIDTH + CURB_THICKNESS) * 0.5

    makePart(
        parent,
        prefix .. "_Left",
        Vector3.new(length, CURB_HEIGHT, CURB_THICKNESS),
        cframe * CFrame.new(0, CURB_HEIGHT * 0.5, offset),
        CURB_COLOR
    )
    makePart(
        parent,
        prefix .. "_Right",
        Vector3.new(length, CURB_HEIGHT, CURB_THICKNESS),
        cframe * CFrame.new(0, CURB_HEIGHT * 0.5, -offset),
        CURB_COLOR
    )
end

local function makeRamp(parent, prefix, startPosition, endPosition)
    local midpoint = (startPosition + endPosition) * 0.5
    local delta = endPosition - startPosition
    local angle = math.atan2(delta.Y, delta.X)
    local length = delta.Magnitude
    local rampCFrame = CFrame.new(midpoint) * CFrame.Angles(0, 0, angle)

    makePart(
        parent,
        prefix,
        Vector3.new(length, ROAD_THICKNESS, ROAD_WIDTH),
        rampCFrame,
        ROAD_COLOR,
        Enum.Material.Asphalt
    )
    makeCurbs(parent, prefix .. "_Curb", rampCFrame, length)
end

local function makeBuildings(parent, origin)
    local buildingFootprints = {
        { offset = Vector3.new(-70, 25, 75), size = Vector3.new(32, 50, 32) },
        { offset = Vector3.new(35, 35, -76), size = Vector3.new(28, 70, 28) },
        { offset = Vector3.new(145, 42, 78), size = Vector3.new(36, 84, 36) },
        { offset = Vector3.new(240, 32, -80), size = Vector3.new(34, 64, 34) },
        { offset = Vector3.new(340, 46, 82), size = Vector3.new(38, 92, 38) },
        { offset = Vector3.new(440, 52, -78), size = Vector3.new(44, 104, 44) },
    }

    for index, building in ipairs(buildingFootprints) do
        makePart(
            parent,
            string.format("Building_%d", index),
            building.size,
            CFrame.new(origin + building.offset),
            GLASS_COLOR,
            Enum.Material.Glass
        )
    end

    local skylineAccent = makePart(
        parent,
        "SkyBridge",
        Vector3.new(48, 3, 10),
        CFrame.new(origin + Vector3.new(295, 62, 0)),
        ACCENT_COLOR,
        Enum.Material.Neon
    )
    skylineAccent.CanCollide = false
    skylineAccent.Transparency = 0.2
end

local function ensureSelectedMap()
    if not workspace:GetAttribute("SelectedMap") then
        workspace:SetAttribute("SelectedMap", Constants.DEFAULT_MAP_ID)
    end
end

local function ensureVehicleSpawn(parent, origin)
    local spawn = parent:FindFirstChild(SPAWN_NAME)
    if spawn and not spawn:IsA("BasePart") then
        spawn:Destroy()
        spawn = nil
    end

    if not spawn then
        spawn = Instance.new("Part")
        spawn.Name = SPAWN_NAME
        spawn.Size = Vector3.new(16, 1, 16)
        spawn.Anchored = true
        spawn.CanCollide = false
        spawn.Transparency = 1
        spawn.Material = Enum.Material.Metal
        spawn.Color = ACCENT_COLOR
        spawn.TopSurface = Enum.SurfaceType.Smooth
        spawn.BottomSurface = Enum.SurfaceType.Smooth
        spawn.Parent = parent
    end

    spawn.CFrame = CFrame.new(origin + SPAWN_OFFSET)
    return spawn
end

local function ensureOutOfBoundsPart(parent, name, size, cframe)
    local part = parent:FindFirstChild(name)
    if part and not part:IsA("BasePart") then
        part:Destroy()
        part = nil
    end

    if not part then
        part = Instance.new("Part")
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.CastShadow = false
        part.Material = Enum.Material.ForceField
        part.Color = ACCENT_COLOR
        part.TopSurface = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part:SetAttribute(OUT_OF_BOUNDS_ATTRIBUTE, true)
        part.Parent = parent
    end

    part.Size = size
    part.CFrame = cframe
    part:SetAttribute(OUT_OF_BOUNDS_ATTRIBUTE, true)
    return part
end

local function ensureOutOfBoundsVolumes(parent, origin)
    local center = origin + Vector3.new(STREET_GROUND_CENTER_OFFSET.X, OUT_OF_BOUNDS_WALL_Y, STREET_GROUND_CENTER_OFFSET.Z)
    local xSpan = (OUT_OF_BOUNDS_WALL_HALF_X * 2) + OUT_OF_BOUNDS_WALL_THICKNESS
    local zSpan = (OUT_OF_BOUNDS_WALL_HALF_Z * 2) + OUT_OF_BOUNDS_WALL_THICKNESS

    ensureOutOfBoundsPart(
        parent,
        "OutOfBounds_Floor",
        OUT_OF_BOUNDS_FLOOR_SIZE,
        CFrame.new(origin + OUT_OF_BOUNDS_FLOOR_OFFSET)
    )
    ensureOutOfBoundsPart(
        parent,
        "OutOfBounds_West",
        Vector3.new(OUT_OF_BOUNDS_WALL_THICKNESS, OUT_OF_BOUNDS_WALL_HEIGHT, zSpan),
        CFrame.new(center + Vector3.new(-(OUT_OF_BOUNDS_WALL_HALF_X + OUT_OF_BOUNDS_WALL_THICKNESS * 0.5), 0, 0))
    )
    ensureOutOfBoundsPart(
        parent,
        "OutOfBounds_East",
        Vector3.new(OUT_OF_BOUNDS_WALL_THICKNESS, OUT_OF_BOUNDS_WALL_HEIGHT, zSpan),
        CFrame.new(center + Vector3.new(OUT_OF_BOUNDS_WALL_HALF_X + OUT_OF_BOUNDS_WALL_THICKNESS * 0.5, 0, 0))
    )
    ensureOutOfBoundsPart(
        parent,
        "OutOfBounds_North",
        Vector3.new(xSpan, OUT_OF_BOUNDS_WALL_HEIGHT, OUT_OF_BOUNDS_WALL_THICKNESS),
        CFrame.new(center + Vector3.new(0, 0, OUT_OF_BOUNDS_WALL_HALF_Z + OUT_OF_BOUNDS_WALL_THICKNESS * 0.5))
    )
    ensureOutOfBoundsPart(
        parent,
        "OutOfBounds_South",
        Vector3.new(xSpan, OUT_OF_BOUNDS_WALL_HEIGHT, OUT_OF_BOUNDS_WALL_THICKNESS),
        CFrame.new(center + Vector3.new(0, 0, -(OUT_OF_BOUNDS_WALL_HALF_Z + OUT_OF_BOUNDS_WALL_THICKNESS * 0.5)))
    )
end

local function buildMap()
    local origin = Vector3.new(0, 0, 0)
    local existingMap = workspace:FindFirstChild(MAP_NAME)
    if existingMap and existingMap:IsA("Model") then
        ensureVehicleSpawn(existingMap, origin)
        ensureOutOfBoundsVolumes(existingMap, origin)
        Logger.Info(TAG, "%s already exists in Workspace; updated %s", MAP_NAME, SPAWN_NAME)
        ensureSelectedMap()
        return
    end

    local mapModel = Instance.new("Model")
    mapModel.Name = MAP_NAME
    mapModel.Parent = workspace

    makePart(
        mapModel,
        "StreetGround",
        STREET_GROUND_SIZE,
        CFrame.new(origin + STREET_GROUND_CENTER_OFFSET),
        Color3.fromRGB(36, 38, 44),
        Enum.Material.Concrete
    )

    ensureVehicleSpawn(mapModel, origin)
    ensureOutOfBoundsVolumes(mapModel, origin)

    for segmentIndex = 0, SEGMENT_COUNT - 1 do
        local segmentPosition = origin + Vector3.new(segmentIndex * SEGMENT_STEP_X, segmentIndex * SEGMENT_RISE, 0)
        local segmentCFrame = CFrame.new(segmentPosition)

        makePart(
            mapModel,
            string.format("Road_%d", segmentIndex + 1),
            Vector3.new(SEGMENT_LENGTH, ROAD_THICKNESS, ROAD_WIDTH),
            segmentCFrame,
            ROAD_COLOR,
            Enum.Material.Asphalt
        )
        makeCurbs(mapModel, string.format("Road_%d_Curb", segmentIndex + 1), segmentCFrame, SEGMENT_LENGTH)

        if segmentIndex < SEGMENT_COUNT - 1 then
            local currentEnd = segmentPosition + Vector3.new(SEGMENT_LENGTH * 0.5, 0, 0)
            local nextStart = origin + Vector3.new(
                (segmentIndex + 1) * SEGMENT_STEP_X - SEGMENT_LENGTH * 0.5,
                (segmentIndex + 1) * SEGMENT_RISE,
                0
            )
            makeRamp(mapModel, string.format("Ramp_%d", segmentIndex + 1), currentEnd, nextStart)
        end
    end

    local checkpointPositions = {
        origin + Vector3.new(15, 0, 0),
        origin + Vector3.new(105, 8, 0),
        origin + Vector3.new(195, 16, 0),
        origin + Vector3.new(285, 24, 0),
        origin + Vector3.new(375, 32, 0),
    }

    for checkpointIndex, checkpointPosition in ipairs(checkpointPositions) do
        makeCheckpoint(mapModel, checkpointIndex, checkpointPosition)
    end

    makeCheckpoint(
        mapModel,
        Constants.CHECKPOINT_FINISH,
        origin + Vector3.new(475, 40, 0)
    )

    makeBuildings(mapModel, origin)
    ensureSelectedMap()

    Logger.Info(TAG, "Generated %s with %d checkpoints and finish line", MAP_NAME, #checkpointPositions)
end

buildMap()
