--[[
	CoinPickupEffects.client.lua
	Description: Purely cosmetic client-side behavior for track coin pickups
	             (tagged "CoinPickup"): idle spin/bob animation, and a pop/
	             sparkle + sound when the server marks one collected (detected
	             by watching its Transparency, which replicates for free --
	             no RemoteEvent needed). Works for any current or future track.
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	Dependencies:
		- None

	Events Fired:
		- None

	Events Listened:
		- None (CollectionService tag signals; BasePart property changes)
--]]

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")

local COIN_TAG = "CoinPickup"
local SPIN_SPEED = 90    -- degrees per second
local BOB_HEIGHT = 0.6   -- studs
local BOB_SPEED  = 2     -- radians per second

local collectSound = Instance.new("Sound")
collectSound.Name = "CoinCollectSound"
collectSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
collectSound.Volume = 0.6
collectSound.Parent = SoundService

local animated: {[BasePart]: {baseCFrame: CFrame, phase: number}} = {}

local function onCollected(part: BasePart)
	collectSound:Play()

	local sparkle = Instance.new("PointLight")
	sparkle.Color = Color3.fromRGB(255, 220, 50)
	sparkle.Range = 12
	sparkle.Brightness = 4
	sparkle.Parent = part
	TweenService:Create(sparkle, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	task.delay(0.4, function()
		if sparkle then sparkle:Destroy() end
	end)
end

local function wireCoin(part: Instance)
	if not part:IsA("BasePart") then
		return
	end

	animated[part] = { baseCFrame = part.CFrame, phase = math.random() * math.pi * 2 }

	part:GetPropertyChangedSignal("Transparency"):Connect(function()
		if part.Transparency >= 1 then
			onCollected(part)
		end
	end)
end

local function unwireCoin(part: BasePart)
	animated[part] = nil
end

for _, part in ipairs(CollectionService:GetTagged(COIN_TAG)) do
	wireCoin(part)
end

CollectionService:GetInstanceAddedSignal(COIN_TAG):Connect(wireCoin)
CollectionService:GetInstanceRemovedSignal(COIN_TAG):Connect(unwireCoin)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for part, state in pairs(animated) do
		if part.Transparency < 1 then
			state.phase += dt * BOB_SPEED
			local bob = math.sin(state.phase) * BOB_HEIGHT
			local spin = CFrame.Angles(0, math.rad(SPIN_SPEED) * now, 0)
			part.CFrame = state.baseCFrame * CFrame.new(0, bob, 0) * spin
		end
	end
end)
