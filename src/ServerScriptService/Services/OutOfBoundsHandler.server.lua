--[[
    OutOfBoundsHandler.server.lua
    Description: Kills and respawns players who fall through the map.
                 This is a driving simulator with open world areas,
                 so wall-based boundaries are DISABLED.
                 Only floor detection is active (for falling through map).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local Constants = require(sharedFolder:WaitForChild("Constants", 10))
local Logger = require(sharedFolder:WaitForChild("Logger", 10))

local TAG = "OutOfBoundsHandler"
local OUT_OF_BOUNDS_ATTRIBUTE = "OutOfBoundsKill"
local RESPAWN_COOLDOWN = 2
local MIN_Y_THRESHOLD = -5  -- Only trigger if player is below this Y level

local activeCooldowns = {}
local boundParts = {}

local function getPlayerFromHit(hit)
    if not hit or not hit.Parent then
        return nil
    end

    local model = hit:FindFirstAncestorWhichIsA("Model")
    if not model then
        return nil
    end

    local userId = tonumber(model.Name:match("^Vehicle_(%d+)$"))
    if userId then
        return Players:GetPlayerByUserId(userId)
    end

    return Players:GetPlayerFromCharacter(model)
end

local function destroyPlayerVehicle(player)
    local vehicleName = string.format(Constants.VEHICLE_NAME_FORMAT, player.UserId)
    local vehicle = Workspace:FindFirstChild(vehicleName)
    if vehicle then
        vehicle:Destroy()
    end
end

local function eliminatePlayer(player, hitPart, hitPosition)
    if not player then
        return
    end

    -- DRIVING SIMULATOR: Open world areas allowed
    -- Only FLOOR detection is active (falling through map)
    -- Wall boundaries are DISABLED for open world driving
    if hitPart ~= "OutOfBounds_Floor" then
        -- Ignore wall triggers - player can drive anywhere
        Logger.Debug(TAG, "Ignoring OutOfBounds wall trigger for %s (open world driving allowed)", player.Name)
        return
    end

    -- Check if player is actually falling through map
    -- Use HIT POSITION for floor check (accessories can be at different Y than HumanoidRootPart)
    if hitPosition.Y > MIN_Y_THRESHOLD then
        -- Hit is above the threshold, likely a false positive from floor
        Logger.Warn(TAG, "Ignoring OutOfBounds floor trigger for %s - hit is above Y threshold (hitY=%.1f > %.1f)", 
            player.Name, hitPosition.Y, MIN_Y_THRESHOLD)
        return
    end

    local now = os.clock()
    local cooldownUntil = activeCooldowns[player.UserId]
    if cooldownUntil and cooldownUntil > now then
        return
    end
    activeCooldowns[player.UserId] = now + RESPAWN_COOLDOWN

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0
        end
    end

    task.delay(0.1, function()
        if player.Parent then
            destroyPlayerVehicle(player)
        end
    end)

    Logger.Info(TAG, "Respawning %s after falling through map (hit: %s at %s)", player.Name, hitPart or "unknown", tostring(hitPosition))
end

local function bindOutOfBoundsPart(part)
    if boundParts[part] then
        return
    end
    if not part:IsA("BasePart") then
        return
    end
    if not part:GetAttribute(OUT_OF_BOUNDS_ATTRIBUTE) then
        return
    end

    boundParts[part] = part.Touched:Connect(function(hit)
        -- Debug: Log what touched the OutOfBounds part
        local hitName = hit and hit.Name or "unknown"
        local hitParent = hit and hit.Parent and hit.Parent.Name or "unknown"
        local hitPosition = hit and hit.Position or Vector3.new(0,0,0)
        
        local player = getPlayerFromHit(hit)
        if player then
            Logger.Warn(TAG, "OutOfBounds triggered: part=%s, hit=%s (parent=%s), position=%s, player=%s", 
                part.Name, hitName, hitParent, tostring(hitPosition), player.Name)
            eliminatePlayer(player, part.Name, hitPosition)
        end
    end)
end

local function watchPart(part)
    if not part:IsA("BasePart") then
        return
    end

    bindOutOfBoundsPart(part)
    part:GetAttributeChangedSignal(OUT_OF_BOUNDS_ATTRIBUTE):Connect(function()
        bindOutOfBoundsPart(part)
    end)
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
    watchPart(descendant)
end

Workspace.DescendantAdded:Connect(watchPart)

Players.PlayerRemoving:Connect(function(player)
    activeCooldowns[player.UserId] = nil
end)

Logger.Info(TAG, "OutOfBoundsHandler ready")
