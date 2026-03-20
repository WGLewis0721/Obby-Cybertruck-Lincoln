-- RaceHUD.client.lua
-- Minimal in-race HUD: live timer, checkpoint progress counter, coin total.
--
-- Shown while a race is active; hidden after the finish line.
-- The ResultsScreen takes over once the RaceFinished event fires.
-- Coin total is always visible so the player knows their balance at a glance.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remote events ─────────────────────────────────────────────────────────────
local raceFolder        = ReplicatedStorage:WaitForChild("Race", 10)
local checkpointReached = raceFolder:WaitForChild("CheckpointReached", 10)
local raceStarted       = raceFolder:WaitForChild("RaceStarted", 10)
local raceFinished      = raceFolder:WaitForChild("RaceFinished", 10)

-- ── Race state ────────────────────────────────────────────────────────────────
local raceActive  = false
local localStart  = 0      -- os.clock() when RaceStarted fired on this client
local lastCpIndex = 0
local totalCps    = 0

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "RaceHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- ── Helper: build a rounded label/frame ───────────────────────────────────────
local function makePanel(name, size, position, anchorPoint)
	local frame = Instance.new("Frame")
	frame.Name                   = name
	frame.Size                   = size
	frame.Position               = position
	frame.AnchorPoint            = anchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel        = 0
	frame.Parent                 = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	return frame
end

-- ── Timer (top center) ────────────────────────────────────────────────────────
local timerPanel = makePanel(
	"TimerPanel",
	UDim2.new(0, 280, 0, 56),
	UDim2.new(0.5, 0, 0, 24),
	Vector2.new(0.5, 0)
)
timerPanel.Visible = false

local timerLabel = Instance.new("TextLabel")
timerLabel.Name                  = "TimerLabel"
timerLabel.Size                  = UDim2.new(1, 0, 1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text                  = "00:00.000"
timerLabel.Font                  = Enum.Font.GothamBold
timerLabel.TextSize              = 36
timerLabel.TextColor3            = Color3.fromRGB(0, 210, 255)
timerLabel.TextXAlignment        = Enum.TextXAlignment.Center
timerLabel.Parent                = timerPanel

-- ── Checkpoint counter (below timer) ─────────────────────────────────────────
local cpPanel = makePanel(
	"CPPanel",
	UDim2.new(0, 220, 0, 34),
	UDim2.new(0.5, 0, 0, 88),
	Vector2.new(0.5, 0)
)
cpPanel.BackgroundTransparency = 0.4
cpPanel.Visible = false

local cpLabel = Instance.new("TextLabel")
cpLabel.Name                  = "CPLabel"
cpLabel.Size                  = UDim2.new(1, 0, 1, 0)
cpLabel.BackgroundTransparency = 1
cpLabel.Text                  = "Checkpoint 0 / 0"
cpLabel.Font                  = Enum.Font.Gotham
cpLabel.TextSize              = 18
cpLabel.TextColor3            = Color3.new(1, 1, 1)
cpLabel.TextXAlignment        = Enum.TextXAlignment.Center
cpLabel.Parent                = cpPanel

-- ── Coin counter (top right, always visible) ──────────────────────────────────
local coinPanel = makePanel(
	"CoinPanel",
	UDim2.new(0, 160, 0, 44),
	UDim2.new(1, -16, 0, 24),
	Vector2.new(1, 0)
)
coinPanel.Visible = true

local coinLabel = Instance.new("TextLabel")
coinLabel.Name                  = "CoinLabel"
coinLabel.Size                  = UDim2.new(1, 0, 1, 0)
coinLabel.BackgroundTransparency = 1
coinLabel.Text                  = "🪙 0"
coinLabel.Font                  = Enum.Font.GothamBold
coinLabel.TextSize              = 20
coinLabel.TextColor3            = Color3.fromRGB(255, 220, 50)
coinLabel.TextXAlignment        = Enum.TextXAlignment.Center
coinLabel.Parent                = coinPanel

-- ── Map / Shop / Garage controls (visible when character exists) ──────────
local mapButton = Instance.new("TextButton")
mapButton.Name = "MapButton"
mapButton.Size = UDim2.new(0, 100, 0, 32)
mapButton.Position = UDim2.new(0.5, -170, 0, 24)
mapButton.AnchorPoint = Vector2.new(0.5, 0)
mapButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mapButton.BorderSizePixel = 0
mapButton.Text = "Map"
mapButton.Font = Enum.Font.GothamBold
mapButton.TextSize = 14
mapButton.TextColor3 = Color3.new(1, 1, 1)
mapButton.Visible = false
mapButton.Parent = screenGui

local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopButton"
shopBtn.Size = UDim2.new(0, 100, 0, 32)
shopBtn.Position = UDim2.new(0.5, -50, 0, 24)
shopBtn.AnchorPoint = Vector2.new(0.5, 0)
shopBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
shopBtn.BorderSizePixel = 0
shopBtn.Text = "Shop"
shopBtn.Font = Enum.Font.GothamBold
shopBtn.TextSize = 14
shopBtn.TextColor3 = Color3.new(1, 1, 1)
shopBtn.Visible = false
shopBtn.Parent = screenGui

local garageBtn = Instance.new("TextButton")
garageBtn.Name = "GarageButton"
garageBtn.Size = UDim2.new(0, 100, 0, 32)
garageBtn.Position = UDim2.new(0.5, 70, 0, 24)
garageBtn.AnchorPoint = Vector2.new(0.5, 0)
garageBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
garageBtn.BorderSizePixel = 0
garageBtn.Text = "Garage"
garageBtn.Font = Enum.Font.GothamBold
garageBtn.TextSize = 14
garageBtn.TextColor3 = Color3.new(1, 1, 1)
garageBtn.Visible = false
garageBtn.Parent = screenGui

local mapMenu = Instance.new("Frame")
mapMenu.Name = "MapMenu"
mapMenu.Size = UDim2.new(0, 240, 0, 152)
mapMenu.Position = UDim2.new(0.5, -120, 0.1, 0)
mapMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mapMenu.BorderSizePixel = 0
mapMenu.Visible = false
mapMenu.Parent = screenGui

local mapMenuCorner = Instance.new("UICorner")
mapMenuCorner.CornerRadius = UDim.new(0, 10)
mapMenuCorner.Parent = mapMenu

local mapMenuTitle = Instance.new("TextLabel")
mapMenuTitle.Name = "Title"
mapMenuTitle.Size = UDim2.new(1, 0, 0, 32)
mapMenuTitle.Position = UDim2.new(0, 0, 0, 0)
mapMenuTitle.BackgroundTransparency = 1
mapMenuTitle.Text = "Select Map"
mapMenuTitle.Font = Enum.Font.GothamBold
mapMenuTitle.TextSize = 16
mapMenuTitle.TextColor3 = Color3.fromRGB(0.75, 0.9, 1)
mapMenuTitle.Parent = mapMenu

local function makeMapChoiceButton(label, mapId, offsetY)
	local btn = Instance.new("TextButton")
	btn.Name = label .. "Button"
	btn.Size = UDim2.new(1, -24, 0, 34)
	btn.Position = UDim2.new(0, 12, 0, 40 + offsetY)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	btn.BorderSizePixel = 0
	btn.Text = label
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Parent = mapMenu
	btn.MouseButton1Click:Connect(function()
		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		local selectMap = eventsFolder and eventsFolder:FindFirstChild("SelectMap")
		if selectMap then
			selectMap:FireServer(mapId)
		else
			warn("MapSelector: SelectMap RemoteEvent is missing")
		end
		mapMenu.Visible = false
	end)
	return btn
end

makeMapChoiceButton("Skyscraper", "skyscraper", 0)
makeMapChoiceButton("Big Foot", "bigfoot", 40)
makeMapChoiceButton("High Speed", "highspeed", 80)

-- Close map menu when clicking outside
mapButton.MouseButton1Click:Connect(function()
	mapMenu.Visible = not mapMenu.Visible
end)

shopBtn.MouseButton1Click:Connect(function()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	local openShop = eventsFolder and eventsFolder:FindFirstChild("OpenPaintShop")
	if openShop then
		openShop:FireServer()
	end
end)

garageBtn.MouseButton1Click:Connect(function()
	local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
	local openGarage = eventsFolder and eventsFolder:FindFirstChild("OpenGarage")
	if openGarage then
		openGarage:FireServer()
	end
end)

local function updateMapControls()
	local visible = player.Character ~= nil
	mapButton.Visible = visible
	shopBtn.Visible = visible
	garageBtn.Visible = visible
end

player.CharacterAdded:Connect(function()
	updateMapControls()
end)

player.CharacterRemoving:Connect(function()
	mapButton.Visible = false
	mapMenu.Visible = false
end)

updateMapControls()


-- ── Helper: format seconds as MM:SS.mmm ──────────────────────────────────────
local function formatTime(secs)
	local minutes = math.floor(secs / 60)
	local seconds = math.floor(secs % 60)
	local ms      = math.floor((secs % 1) * 1000)
	return string.format("%02d:%02d.%03d", minutes, seconds, ms)
end

-- ── RenderStepped: tick the timer ─────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
	if not raceActive then return end
	timerLabel.Text = formatTime(os.clock() - localStart)
end)

-- ── RaceStarted ───────────────────────────────────────────────────────────────
raceStarted.OnClientEvent:Connect(function(_payload)
	raceActive    = true
	localStart    = os.clock()
	lastCpIndex   = 0
	totalCps      = 0
	timerLabel.Text = "00:00.000"
	cpLabel.Text    = "Checkpoint 0 / ?"
	timerPanel.Visible = true
	cpPanel.Visible    = true
end)

-- ── CheckpointReached ─────────────────────────────────────────────────────────
checkpointReached.OnClientEvent:Connect(function(payload)
	lastCpIndex = payload.index or lastCpIndex
	totalCps    = payload.total or totalCps
	cpLabel.Text = string.format("Checkpoint %d / %d", lastCpIndex, totalCps)

	-- Brief cyan flash to confirm the checkpoint
	TweenService:Create(
		cpLabel,
		TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ TextColor3 = Color3.fromRGB(0, 210, 255) }
	):Play()
	task.delay(0.4, function()
		TweenService:Create(
			cpLabel,
			TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ TextColor3 = Color3.new(1, 1, 1) }
		):Play()
	end)
end)

-- ── RaceFinished ──────────────────────────────────────────────────────────────
raceFinished.OnClientEvent:Connect(function(payload)
	raceActive = false
	-- Show the authoritative server time for the final freeze frame
	timerLabel.Text = formatTime(payload.elapsed or 0)
	-- Update coin display with the confirmed server total
	if payload.totalCoins then
		coinLabel.Text = "🪙 " .. tostring(payload.totalCoins)
	end
	-- Hide race panels shortly after; ResultsScreen will take focus
	task.wait(0.6)
	timerPanel.Visible = false
	cpPanel.Visible    = false
end)

-- ── Sync coin balance from leaderstats when they first load ───────────────────
-- Keeps the coin display accurate even before any race is finished this session.
task.spawn(function()
	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end
	local coins = leaderstats:WaitForChild("Coins", 10)
	if not coins then return end
	coinLabel.Text = "🪙 " .. tostring(coins.Value)
	coins.Changed:Connect(function(val)
		coinLabel.Text = "🪙 " .. tostring(val)
	end)
end)
