--[[
    BoostHandler.client.lua
    Description: Manages the Perks Hotbar. Each perk button is hidden until the
                 server confirms ownership. Handles Speed Boost application.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - Remotes.ApplyBoost      (S->C)
        - Remotes.BundlePurchased (S->C)

    Events Fired:
        - None

    Events Listened:
        - Remotes.ApplyBoost
        - Remotes.BundlePurchased
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── Remote events ──────────────────────────────────────────────────────────────
local remotesFolder   = ReplicatedStorage:WaitForChild("Events")
local applyBoost      = remotesFolder:WaitForChild("ApplyBoost")
local bundlePurchased = remotesFolder:WaitForChild("BundlePurchased")

-- ── ScreenGui ──────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "PerkHotbarGui"
screenGui.ResetOnSpawn  = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent        = player:WaitForChild("PlayerGui")

-- ── Hotbar container (bottom center, above native Roblox UI) ──────────────────
-- AnchorPoint (0.5, 1) means the BOTTOM CENTER of the frame sits at Position.
-- Offset -90 keeps it above the default Roblox chat and jump-button strip.
local hotbar = Instance.new("Frame")
hotbar.Name              = "PerkHotbar"
hotbar.AnchorPoint       = Vector2.new(0.5, 1)
hotbar.Position          = UDim2.new(0.5, 0, 1, -90)
hotbar.Size              = UDim2.new(0, 60, 0, 60)  -- grows automatically via AutomaticSize
hotbar.AutomaticSize     = Enum.AutomaticSize.X
hotbar.BackgroundTransparency = 1
hotbar.Parent            = screenGui

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection       = Enum.FillDirection.Horizontal
hotbarLayout.SortOrder           = Enum.SortOrder.LayoutOrder
hotbarLayout.Padding             = UDim.new(0, 6)
hotbarLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.Parent              = hotbar

-- ── Helper: create a square perk button ───────────────────────────────────────
-- Buttons start hidden and are made visible when the player earns the perk.
local function makePerkButton(icon, layoutOrder)
	local btn = Instance.new("TextButton")
	btn.Name              = icon .. "PerkBtn"
	btn.Size              = UDim2.new(0, 60, 0, 60)
	btn.BackgroundColor3  = Color3.fromRGB(30, 30, 30)
	btn.BackgroundTransparency = 0.3
	btn.BorderSizePixel   = 0
	btn.Text              = icon
	btn.Font              = Enum.Font.GothamBold
	btn.TextSize          = 28
	btn.TextColor3        = Color3.new(1, 1, 1)
	btn.AutoButtonColor   = false
	btn.LayoutOrder       = layoutOrder
	btn.Visible           = false   -- hidden until perk is owned
	btn.Parent            = hotbar

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = btn

	-- White border stroke matching native Roblox hotbar style
	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.new(1, 1, 1)
	stroke.Thickness = 1.5
	stroke.Parent    = btn

	return btn
end

-- ── Helper: show a brief notification above the hotbar ────────────────────────
-- The label has no background; it fades out after `duration` seconds.
local function showNotification(text, duration)
	local notif = Instance.new("TextLabel")
	notif.Name             = "PerkNotification"
	notif.AnchorPoint      = Vector2.new(0.5, 1)
	-- Sits 10 px above the top of the hotbar (hotbar bottom = -90, height = 60 → top = -150)
	notif.Position         = UDim2.new(0.5, 0, 1, -160)
	notif.Size             = UDim2.new(0, 420, 0, 30)
	notif.BackgroundTransparency = 1
	notif.Text             = text
	notif.Font             = Enum.Font.GothamBold
	notif.TextSize         = 16
	notif.TextColor3       = Color3.new(1, 1, 1)
	notif.TextTransparency = 0
	notif.TextXAlignment   = Enum.TextXAlignment.Center
	notif.ZIndex           = 10
	notif.Parent           = screenGui

	-- Fade out near the end of the duration
	task.delay(duration - 0.5, function()
		TweenService:Create(
			notif,
			TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		):Play()
		task.wait(0.5)
		if notif and notif.Parent then
			notif:Destroy()
		end
	end)
end

-- ── Helper: apply MaxSpeed boost to the player's current vehicle ───────────────
-- Looks for a NumberValue named "MaxSpeed" inside the vehicle model.
-- Increases it by 30% if found; warns gracefully if not.
-- Only applies once per vehicle instance to prevent exponential stacking.
local boostedVehicle = nil  -- tracks which vehicle the boost has already been applied to

local function applyBoostToVehicle()
	local vehicleModel = workspace:FindFirstChild("Vehicle_" .. player.UserId)
	if not vehicleModel then
		warn("BoostHandler: Vehicle not found for " .. tostring(player.UserId))
		return
	end

	-- Avoid stacking the 30% multiplier if the boost was already applied to this instance
	if boostedVehicle == vehicleModel then
		return
	end

	local maxSpeedVal = vehicleModel:FindFirstChild("MaxSpeed", true)
	if maxSpeedVal and maxSpeedVal:IsA("NumberValue") then
		maxSpeedVal.Value = maxSpeedVal.Value * 1.3
		boostedVehicle = vehicleModel  -- mark as boosted so we don't apply again
	else
		-- Try to find and patch the A-Chassis Tune module's exposed table if the
		-- game exposes MaxSpeed as a script variable (best-effort only).
		local tune = vehicleModel:FindFirstChild("A-Chassis Tune", true)
		if tune then
			warn("BoostHandler: A-Chassis Tune found but MaxSpeed NumberValue is absent — patch manually")
		else
			warn("BoostHandler: MaxSpeed NumberValue not found in vehicle; boost not applied")
		end
	end
end

-- ── Speed Boost perk button (⚡) ──────────────────────────────────────────────
local boostBtn = makePerkButton("⚡", 1)

-- When the player equips a new vehicle the model instance changes; reset the
-- boostedVehicle tracker so the boost is re-applied to the new model.
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Vehicle_" .. player.UserId then
		boostedVehicle = nil
	end
end)

boostBtn.MouseButton1Click:Connect(function()
	applyBoostToVehicle()
end)

-- ── ApplyBoost: reveal ⚡ button, notify, and apply boost immediately ──────────
applyBoost.OnClientEvent:Connect(function()
	boostBtn.Visible = true
	showNotification("⚡ Speed Boost Activated!", 3)
	applyBoostToVehicle()
end)

-- ── BundlePurchased: reveal all perk buttons and show bundle notification ──────
-- The server also fires OpenGarage at the same time, so the garage refreshes
-- automatically to show newly unlocked vehicles.
bundlePurchased.OnClientEvent:Connect(function()
	boostBtn.Visible = true
	showNotification("🎉 Ultimate Bundle Unlocked! All vehicles and paint jobs are yours!", 4)
end)
