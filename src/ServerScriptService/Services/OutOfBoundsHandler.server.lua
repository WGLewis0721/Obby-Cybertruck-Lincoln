--[[
    OutOfBoundsHandler.server.lua
    Description: Kills and respawns players who leave the playable area by
                 touching invisible out-of-bounds volumes placed in maps.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared", 10)
local Constants = require(sharedFolder:WaitForChild("Constants", 10))
local Logger = require(sharedFolder:WaitForChild("Logger", 10))

local TAG = "OutOfBoundsHandler"
local OUT_OF_BOUNDS_ATTRIBUTE = "OutOfBoundsKill"
local RESPAWN_COOLDOWN = 2

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

local function eliminatePlayer(player)
    if not player then
        return
    end

    local now = os.clock()
    local cooldownUntil = activeCooldowns[player.UserId]
    if cooldownUntil and cooldownUntil > now then
        return
    end
    activeCooldowns[player.UserId] = now + RESPAWN_COOLDOWN

    local character = player.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if humanoid and humanoid.Health > 0 then
        humanoid.Health = 0
    end

    task.delay(0.1, function()
        if player.Parent then
            destroyPlayerVehicle(player)
        end
    end)

    Logger.Info(TAG, "Respawning %s after leaving map bounds", player.Name)
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
        local player = getPlayerFromHit(hit)
        if player then
            eliminatePlayer(player)
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
