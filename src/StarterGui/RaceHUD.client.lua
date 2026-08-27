--[[
    RaceHUD.client.lua
    Description: In-race HUD showing live timer, checkpoint/lap progress, and
                 coin total. Shown during a race; hidden on finish.

                 Nav (Shop/Garage/Map) and race-control buttons used to be
                 duplicated here — removed. GameHUD.client.lua owns navigation,
                 ResultsScreen.client.lua owns the post-race Race Again flow.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - Remotes.RaceStarted       (S->C)
        - Remotes.CheckpointReached (S->C)
        - Remotes.RaceFinished      (S->C)
        - Remotes.LapCompleted      (S->C)

    Events Listened:
        - Remotes.RaceStarted
        - Remotes.CheckpointReached
        - Remotes.RaceFinished
        - Remotes.LapCompleted
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remote events ─────────────────────────────────────────────────────────────
local remotesFolder     = ReplicatedStorage:WaitForChild("Events", 10)
local checkpointReached = remotesFolder:WaitForChild("CheckpointReached", 10)
local raceStarted       = remotesFolder:WaitForChild("RaceStarted", 10)
local raceFinished      = remotesFolder:WaitForChild("RaceFinished", 10)
local lapCompleted      = remotesFolder:WaitForChild("LapCompleted", 10)
local startRaceRemote   = remotesFolder:WaitForChild("StartRace", 10)
local endRaceRemote     = remotesFolder:WaitForChild("EndRace", 10)
local raceAgainRemote   = remotesFolder:WaitForChild("RaceAgain", 10)
local returnHomeRemote  = remotesFolder:WaitForChild("ReturnToLobby", 10)

-- ── Race state ────────────────────────────────────────────────────────────────
local raceActive  = false
local localStart  = 0      -- os.clock() when RaceStarted fired on this client
local lastCpIndex = 0
local totalCps    = 0
local activeMapId = "skyscraper"

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "RaceHUD"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder    = 20
screenGui.ScreenInsets    = Enum.ScreenInsets.CoreUISafeInsets
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

-- ── Lap counter (below checkpoint counter) ───────────────────────────────────
local lapPanel = makePanel(
	"LapPanel",
	UDim2.new(0, 220, 0, 40),
	UDim2.new(0.5, 0, 0, 128),
	Vector2.new(0.5, 0)
)
lapPanel.BackgroundTransparency = 0.25
lapPanel.Visible = false

local lapLabel = Instance.new("TextLabel")
lapLabel.Name                  = "LapLabel"
lapLabel.Size                  = UDim2.new(1, 0, 1, 0)
lapLabel.BackgroundTransparency = 1
lapLabel.Text                  = "LAP 1 / 3"
lapLabel.Font                  = Enum.Font.GothamBold
lapLabel.TextSize              = 22
lapLabel.TextColor3            = Color3.fromRGB(255, 220, 50)
lapLabel.TextXAlignment        = Enum.TextXAlignment.Center
lapLabel.Parent                = lapPanel

-- ── Last / best lap readout ──────────────────────────────────────────────────
local lapTimePanel = makePanel(
	"LapTimePanel",
	UDim2.new(0, 220, 0, 30),
	UDim2.new(0.5, 0, 0, 172),
	Vector2.new(0.5, 0)
)
lapTimePanel.BackgroundTransparency = 0.5
lapTimePanel.Visible = false

local lapTimeLabel = Instance.new("TextLabel")
lapTimeLabel.Name                  = "LapTimeLabel"
lapTimeLabel.Size                  = UDim2.new(1, 0, 1, 0)
lapTimeLabel.BackgroundTransparency = 1
lapTimeLabel.Text                  = "Best --:--.---"
lapTimeLabel.Font                  = Enum.Font.Gotham
lapTimeLabel.TextSize              = 15
lapTimeLabel.TextColor3            = Color3.fromRGB(180, 180, 200)
lapTimeLabel.TextXAlignment        = Enum.TextXAlignment.Center
lapTimeLabel.Parent                = lapTimePanel

local raceControls = Instance.new("Frame")
raceControls.Name = "RaceControls"
raceControls.Size = UDim2.fromOffset(500, 42)
raceControls.Position = UDim2.new(0.5, 0, 1, -20)
raceControls.AnchorPoint = Vector2.new(0.5, 1)
raceControls.BackgroundTransparency = 1
raceControls.Visible = false
raceControls.Parent = screenGui

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.FillDirection = Enum.FillDirection.Horizontal
controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
controlsLayout.Padding = UDim.new(0, 6)
controlsLayout.Parent = raceControls

local function makeRaceButton(name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(118, 42)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Parent = raceControls
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	return button
end

local startButton = makeRaceButton("StartRaceButton", "START RACE", Color3.fromRGB(0, 150, 205))
local endButton = makeRaceButton("EndRaceButton", "END RACE", Color3.fromRGB(160, 55, 55))
local restartButton = makeRaceButton("RestartRaceButton", "RESTART", Color3.fromRGB(190, 135, 35))
local homeButton = makeRaceButton("HomeButton", "HOME", Color3.fromRGB(45, 115, 75))

startButton.MouseButton1Click:Connect(function()
	startRaceRemote:FireServer(activeMapId)
end)

endButton.MouseButton1Click:Connect(function()
	endRaceRemote:FireServer()
	raceControls.Visible = false
end)

restartButton.MouseButton1Click:Connect(function()
	raceAgainRemote:FireServer()
	task.delay(0.15, function()
		startRaceRemote:FireServer(activeMapId)
	end)
end)

homeButton.MouseButton1Click:Connect(function()
	returnHomeRemote:FireServer()
	raceControls.Visible = false
end)

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
raceStarted.OnClientEvent:Connect(function(payload)
	raceActive    = true
	raceControls.Visible = true
	activeMapId = payload and payload.mapId or activeMapId
	localStart    = os.clock()
	lastCpIndex   = 0
	totalCps      = 0
	timerLabel.Text = "00:00.000"
	cpLabel.Text    = "Checkpoint 0 / ?"
	timerPanel.Visible = true
	cpPanel.Visible    = true

	local totalLaps = (payload and payload.totalLaps) or 3
	lapLabel.Text = string.format("LAP 1 / %d", totalLaps)
	lapTimeLabel.Text = "Best --:--.---"
	lapPanel.Visible = true
	lapTimePanel.Visible = true
end)

-- ── CheckpointReached ─────────────────────────────────────────────────────────
checkpointReached.OnClientEvent:Connect(function(payload)
	lastCpIndex = payload.index or lastCpIndex
	totalCps    = payload.total or totalCps
	cpLabel.Text = string.format("Checkpoint %d / %d", lastCpIndex, totalCps)
	if payload.lap and payload.totalLaps then
		lapLabel.Text = string.format("LAP %d / %d", payload.lap, payload.totalLaps)
	end

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

-- ── LapCompleted: advance the lap counter and surface last/best lap times ─────
lapCompleted.OnClientEvent:Connect(function(payload)
	lapLabel.Text = string.format("LAP %d / %d", payload.lap, payload.totalLaps)

	local parts = {}
	if payload.lastLap then
		table.insert(parts, "Last " .. formatTime(payload.lastLap))
	end
	if payload.bestLap then
		table.insert(parts, "Best " .. formatTime(payload.bestLap))
	end
	lapTimeLabel.Text = table.concat(parts, "   ")

	-- Restart the on-screen timer for the new lap
	localStart = os.clock()

	lapLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TweenService:Create(
		lapLabel,
		TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ TextColor3 = Color3.fromRGB(255, 220, 50) }
	):Play()
end)

-- ── RaceFinished ──────────────────────────────────────────────────────────────
raceFinished.OnClientEvent:Connect(function(payload)
	raceActive = false
	raceControls.Visible = false
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
	lapPanel.Visible   = false
	lapTimePanel.Visible = false
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
