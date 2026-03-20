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
