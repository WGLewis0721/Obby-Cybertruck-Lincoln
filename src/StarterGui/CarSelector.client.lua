--[[
	CarSelector.client.lua
	"MY CARS" panel: pick any owned car and summon it wherever you are.
	Opens from GameHUD's Garage button (server echoes OpenGarage back to us) --
	this is the single garage UI now; the older GarageMenu.client.lua (hardcoded
	ownership, never called GetShopState) has been retired.

	Fully data-driven -- the list is built from ReplicatedStorage.Module.VehicleData,
	so adding a new car to the game means adding ONE entry to that table and
	dropping its Model into ServerStorage. Nothing here needs to change.

	Spawning stays server-authoritative: this only fires EquipVehicle, and
	GarageHandler re-checks ownership before it spawns anything.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sharedFolder = ReplicatedStorage:WaitForChild("Module", 10)
local VehicleData  = require(sharedFolder:WaitForChild("VehicleData", 10))

local remotes        = ReplicatedStorage:WaitForChild("Events", 10)
local equipVehicle    = remotes:WaitForChild("EquipVehicle", 10)
local getShopState    = remotes:WaitForChild("GetShopState", 20)
local purchaseCoins   = remotes:WaitForChild("PurchaseWithCoins", 20)
local openGarageEvent = remotes:WaitForChild("OpenGarage", 10)

local C_BG     = Color3.fromRGB(14, 15, 22)
local C_CARD   = Color3.fromRGB(28, 31, 44)
local C_ACCENT = Color3.fromRGB(74, 240, 255)
local C_COIN   = Color3.fromRGB(255, 205, 60)
local C_LOCK   = Color3.fromRGB(70, 75, 90)
local C_TEXT   = Color3.new(1, 1, 1)

local state = { coins = 0, ownedCars = { 1 }, equippedCar = 1 }

local function owns(id)
	for _, v in ipairs(VehicleData) do
		if v.Id == id and v.Unlocked then return true end
	end
	return type(state.ownedCars) == "table" and table.find(state.ownedCars, id) ~= nil
end

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = inst
end

-- ── UI ───────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "CarSelectorGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0.9, 0, 0.85, 0)
panel.BackgroundColor3 = C_BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 12)

-- Scale-based sizing keeps this from overflowing small phones while a pixel
-- clamp keeps the desktop/tablet look identical to the original fixed size.
local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(300, 280)
panelConstraint.MaxSize = Vector2.new(560, 440)
panelConstraint.Parent = panel
local pStroke = Instance.new("UIStroke")
pStroke.Color = C_ACCENT
pStroke.Thickness = 2
pStroke.Transparency = 0.3
pStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -110, 0, 52)
title.Position = UDim2.new(0, 18, 0, 4)
title.BackgroundTransparency = 1
title.Text = "MY CARS"
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = C_ACCENT
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local coinLabel = Instance.new("TextLabel")
coinLabel.Size = UDim2.new(0, 160, 0, 52)
coinLabel.Position = UDim2.new(1, -212, 0, 4)
coinLabel.BackgroundTransparency = 1
coinLabel.Text = "0 Coins"
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextSize = 16
coinLabel.TextColor3 = C_COIN
coinLabel.TextXAlignment = Enum.TextXAlignment.Right
coinLabel.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 34, 0, 34)
closeBtn.Position = UDim2.new(1, -44, 0, 12)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 15
closeBtn.TextColor3 = C_TEXT
closeBtn.Parent = panel
corner(closeBtn, 8)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -28, 1, -72)
list.Position = UDim2.new(0, 14, 0, 60)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = C_ACCENT
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -10)
toast.Size = UDim2.new(0, 340, 0, 32)
toast.BackgroundColor3 = C_CARD
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.Font = Enum.Font.GothamBold
toast.TextSize = 14
toast.TextColor3 = C_TEXT
toast.Text = ""
toast.Parent = panel
corner(toast, 8)

local function showToast(msg, color)
	toast.Text = msg
	toast.TextColor3 = color or C_TEXT
	toast.BackgroundTransparency = 0.1
	toast.TextTransparency = 0
	task.delay(2, function()
		TweenService:Create(toast, TweenInfo.new(0.4),
			{ BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

local render

local function makeRow(order, car)
	local owned = owns(car.Id)
	local equipped = (state.equippedCar == car.Id)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 76)
	row.BackgroundColor3 = C_CARD
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = list
	corner(row, 10)

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(0, 260, 0, 22)
	name.Position = UDim2.new(0, 16, 0, 12)
	name.BackgroundTransparency = 1
	name.Text = car.Name
	name.Font = Enum.Font.GothamBold
	name.TextSize = 16
	name.TextColor3 = owned and C_TEXT or Color3.fromRGB(160, 165, 185)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local st = car.Stats or {}
	local stats = Instance.new("TextLabel")
	stats.Size = UDim2.new(0, 260, 0, 18)
	stats.Position = UDim2.new(0, 16, 0, 38)
	stats.BackgroundTransparency = 1
	stats.Text = string.format("SPD %d  ACC %d  HAN %d  BRK %d",
		st.TopSpeed or 0, st.Acceleration or 0, st.Handling or 0, st.Braking or 0)
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 12
	stats.TextColor3 = Color3.fromRGB(150, 155, 175)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 132, 0, 36)
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -14, 0.5, 0)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(18, 19, 26)
	btn.Parent = row
	corner(btn, 8)

	if owned then
		btn.Text = equipped and "SUMMON" or "SELECT"
		btn.BackgroundColor3 = C_ACCENT
		btn.MouseButton1Click:Connect(function()
			-- Server validates ownership, equips and spawns the model.
			equipVehicle:FireServer(car.Id)
			state.equippedCar = car.Id
			showToast("Summoning " .. car.Name .. "...", C_ACCENT)
			task.delay(0.5, render)
		end)
	else
		local price = car.CoinPrice or 0
		local afford = state.coins >= price and price > 0
		btn.Text = price > 0 and (tostring(price) .. " Coins") or "LOCKED"
		btn.BackgroundColor3 = afford and C_COIN or C_LOCK
		btn.TextColor3 = afford and Color3.fromRGB(18, 19, 26) or Color3.fromRGB(160, 160, 175)
		btn.MouseButton1Click:Connect(function()
			if price <= 0 then return end
			local res = purchaseCoins:InvokeServer("car", car.Id)
			if res and res.ok then
				state.coins = res.balance
				showToast("Unlocked " .. car.Name .. "!", C_COIN)
				render()
			else
				showToast((res and res.reason) or "Purchase failed",
					Color3.fromRGB(255, 120, 120))
			end
		end)
	end
end

render = function()
	local s = getShopState:InvokeServer()
	if s then
		state.coins       = s.coins or 0
		state.ownedCars   = s.ownedCars or { 1 }
		state.equippedCar = s.equippedCar or 1
	end
	coinLabel.Text = string.format("%d Coins", state.coins)

	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i, car in ipairs(VehicleData) do
		makeRow(i, car)
	end
end

-- Server echoes OpenGarage back after GameHUD's Garage button fires it.
openGarageEvent.OnClientEvent:Connect(function()
	panel.Visible = true
	render()
end)

closeBtn.MouseButton1Click:Connect(function()
	panel.Visible = false
end)

-- Keep the coin readout live
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 20)
	local coins = ls and ls:WaitForChild("Coins", 10)
	if not coins then return end
	state.coins = coins.Value
	coins.Changed:Connect(function(v)
		state.coins = v
		if panel.Visible then coinLabel.Text = string.format("%d Coins", v) end
	end)
end)
