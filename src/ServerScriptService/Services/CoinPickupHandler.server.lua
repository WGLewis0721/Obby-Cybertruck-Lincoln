--[[
	CoinPickupHandler.server.lua
	Description: Server-authoritative collection for track coin pickups. Any
	             BasePart tagged "CoinPickup" (via CollectionService) is
	             automatically wired up -- map generators only need to create
	             and tag the part; this handles touch detection, awarding
	             coins, and the respawn timer. Works for any current or future
	             track without per-map wiring code.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- EconomyConfig       (ReplicatedStorage.Module.EconomyConfig)
		- Logger              (ReplicatedStorage.Module.Logger)
		- PlayerDataInterface (ServerScriptService.Services.PlayerDataInterface)

	Events Fired:
		- None (pickup Transparency/CanTouch changes replicate for free; see
		  StarterGui.CoinPickupEffects.client.lua for the client-side reaction)

	Events Listened:
		- None (CollectionService tag signals; BasePart.Touched per pickup)
--]]

-- 1. Services
local CollectionService = game:GetService("CollectionService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- 2. Constants & shared modules
local sharedFolder  = ReplicatedStorage:WaitForChild("Module", 10)
local EconomyConfig = require(sharedFolder:WaitForChild("EconomyConfig", 10))
local Logger         = require(sharedFolder:WaitForChild("Logger", 10))

-- 3. Server-only dependencies
local servicesFolder      = script.Parent
local PlayerDataInterface = require(servicesFolder:WaitForChild("PlayerDataInterface", 10))

local TAG      = "CoinPickupHandler"
local COIN_TAG = "CoinPickup"

-- 4. Private state
local touchConnections: {[BasePart]: RBXScriptConnection} = {}

-- 5. Private functions

-- Vehicle parts live inside nested child Models, so the first Model ancestor is
-- never the Vehicle_ model. RaceUtil walks the full chain -- see its comment.
local RaceUtil = require(script.Parent:WaitForChild("RaceUtil", 10))
local function getPlayerFromHit(hit: BasePart): Player?
	local player = RaceUtil.GetPlayerFromHit(hit)
	return player
end

local function respawnCoin(part: BasePart)
	if not part or not part.Parent then return end
	part.Transparency = 0
	part.CanTouch      = true
	part:SetAttribute("Available", true)
end

local function collectCoin(part: BasePart, player: Player)
	-- Mark unavailable immediately so rapid re-touches during the same frame
	-- (multiple wheel parts overlapping the pickup) can't double-collect.
	part:SetAttribute("Available", false)
	part.Transparency = 1
	part.CanTouch      = false

	local newTotal = PlayerDataInterface.AddCoins(player.UserId, EconomyConfig.COIN_PICKUP_VALUE)
	Logger.Debug(TAG, "%s collected a coin pickup (+%d, total=%d)",
		player.Name, EconomyConfig.COIN_PICKUP_VALUE, newTotal)

	task.delay(EconomyConfig.COIN_PICKUP_RESPAWN_TIME, respawnCoin, part)
end

local function wireCoin(part: Instance)
	if not part:IsA("BasePart") then
		return
	end

	part:SetAttribute("Available", true)
	part.CanCollide = false
	part.CanTouch   = true

	touchConnections[part] = part.Touched:Connect(function(hit)
		if not part:GetAttribute("Available") then
			return
		end
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end
		collectCoin(part, player)
	end)
end

local function unwireCoin(part: BasePart)
	local connection = touchConnections[part]
	if connection then
		connection:Disconnect()
		touchConnections[part] = nil
	end
end

-- 6. Initialization
for _, part in ipairs(CollectionService:GetTagged(COIN_TAG)) do
	wireCoin(part)
end

CollectionService:GetInstanceAddedSignal(COIN_TAG):Connect(wireCoin)
CollectionService:GetInstanceRemovedSignal(COIN_TAG):Connect(unwireCoin)

Logger.Info(TAG, "CoinPickupHandler ready (%d pickup(s) tracked)", #CollectionService:GetTagged(COIN_TAG))
