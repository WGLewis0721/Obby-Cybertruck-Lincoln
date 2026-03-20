--[[
    ResultsScreen.client.lua
    Description: Displays post-race results panel when RaceFinished fires.
                 Shows final time, personal-best status, coins earned, and a
                 Race Again button.
    Author: Cybertruck Obby Lincoln
    Last Updated: 2026

    Dependencies:
        - Remotes.RaceFinished (S->C)
        - Remotes.RaceAgain    (C->S)

    Events Fired:
        - Remotes.RaceAgain (C->S on button click)

    Events Listened:
        - Remotes.RaceFinished
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Remote events ─────────────────────────────────────────────────────────────
local remotesFolder   = ReplicatedStorage:WaitForChild("Remotes", 10)
local raceFinished    = remotesFolder:WaitForChild("RaceFinished", 10)
local raceAgainRemote = remotesFolder:WaitForChild("RaceAgain", 10)

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ResultsScreen"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

-- ── Helper: format seconds as MM:SS.mmm ──────────────────────────────────────
local function formatTime(secs)
	local minutes = math.floor(secs / 60)
	local seconds = math.floor(secs % 60)
	local ms      = math.floor((secs % 1) * 1000)
	return string.format("%02d:%02d.%03d", minutes, seconds, ms)
end

-- ── Helper: create a UICorner ─────────────────────────────────────────────────
local function addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

-- ── Build and show the results panel ─────────────────────────────────────────
local function showResults(payload)
	-- Remove any lingering panel from a previous run
	local existing = screenGui:FindFirstChild("ResultsPanel")
	if existing then existing:Destroy() end

	-- ── Outer panel ───────────────────────────────────────────────────────────
	local panel = Instance.new("Frame")
	panel.Name                   = "ResultsPanel"
	panel.AnchorPoint            = Vector2.new(0.5, 0.5)
	-- Start off-screen below; tween will move it to centre
	panel.Position               = UDim2.new(0.5, 0, 1.6, 0)
	panel.Size                   = UDim2.new(0, 400, 0, 340)
	panel.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel        = 0
	panel.Parent                 = screenGui
	addCorner(panel, 12)

	-- Cyan border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(0, 210, 255)
	stroke.Thickness = 2
	stroke.Parent    = panel

	-- ── Title ────────────────────────────────────────────────────────────────
	local title = Instance.new("TextLabel")
	title.Size                   = UDim2.new(1, 0, 0, 52)
	title.Position               = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text                   = "🏁  RACE COMPLETE"
	title.Font                   = Enum.Font.GothamBold
	title.TextSize               = 26
	title.TextColor3             = Color3.fromRGB(0, 210, 255)
	title.TextXAlignment         = Enum.TextXAlignment.Center
	title.Parent                 = panel

	-- ── Final time box ────────────────────────────────────────────────────────
	local timeBox = Instance.new("Frame")
	timeBox.Size                   = UDim2.new(1, -32, 0, 58)
	timeBox.Position               = UDim2.new(0, 16, 0, 58)
	timeBox.BackgroundColor3       = Color3.fromRGB(15, 15, 30)
	timeBox.BackgroundTransparency = 0.2
	timeBox.BorderSizePixel        = 0
	timeBox.Parent                 = panel
	addCorner(timeBox, 8)

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size                   = UDim2.new(1, 0, 1, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text                   = formatTime(payload.elapsed or 0)
	timeLabel.Font                   = Enum.Font.GothamBold
	timeLabel.TextSize               = 42
	timeLabel.TextColor3             = Color3.new(1, 1, 1)
	timeLabel.TextXAlignment         = Enum.TextXAlignment.Center
	timeLabel.Parent                 = timeBox

	-- ── Personal best line ────────────────────────────────────────────────────
	local bestLabel = Instance.new("TextLabel")
	bestLabel.Size                   = UDim2.new(1, -32, 0, 30)
	bestLabel.Position               = UDim2.new(0, 16, 0, 124)
	bestLabel.BackgroundTransparency = 1
	bestLabel.Font                   = Enum.Font.Gotham
	bestLabel.TextSize               = 18
	bestLabel.TextXAlignment         = Enum.TextXAlignment.Center
	bestLabel.Parent                 = panel

	if payload.isNewBest then
		bestLabel.Text       = "⭐  NEW PERSONAL BEST!"
		bestLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
	else
		local best = payload.bestTime
		bestLabel.Text       = best and ("Best: " .. formatTime(best)) or "—"
		bestLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end

	-- ── Coins earned ─────────────────────────────────────────────────────────
	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Size                   = UDim2.new(1, -32, 0, 32)
	coinsLabel.Position               = UDim2.new(0, 16, 0, 160)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text                   = string.format(
		"🪙  +%d   (Total: %d)",
		payload.coinsEarned or 0,
		payload.totalCoins  or 0
	)
	coinsLabel.Font                   = Enum.Font.GothamBold
	coinsLabel.TextSize               = 18
	coinsLabel.TextColor3             = Color3.fromRGB(255, 220, 50)
	coinsLabel.TextXAlignment         = Enum.TextXAlignment.Center
	coinsLabel.Parent                 = panel

	-- ── Race Again button ─────────────────────────────────────────────────────
	local raceAgainBtn = Instance.new("TextButton")
	raceAgainBtn.Name                  = "RaceAgainBtn"
	raceAgainBtn.Size                  = UDim2.new(1, -48, 0, 54)
	raceAgainBtn.Position              = UDim2.new(0, 24, 0, 218)
	raceAgainBtn.BackgroundColor3      = Color3.fromRGB(0, 170, 210)
	raceAgainBtn.BorderSizePixel       = 0
	raceAgainBtn.Text                  = "⟳   RACE AGAIN"
	raceAgainBtn.Font                  = Enum.Font.GothamBold
	raceAgainBtn.TextSize              = 20
	raceAgainBtn.TextColor3            = Color3.new(1, 1, 1)
	raceAgainBtn.AutoButtonColor       = false
	raceAgainBtn.Parent                = panel
	addCorner(raceAgainBtn, 8)

	-- Hover colour tween
	local COLOR_BTN       = Color3.fromRGB(0, 170, 210)
	local COLOR_BTN_HOVER = Color3.fromRGB(0, 200, 255)
	raceAgainBtn.MouseEnter:Connect(function()
		TweenService:Create(
			raceAgainBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ BackgroundColor3 = COLOR_BTN_HOVER }
		):Play()
	end)
	raceAgainBtn.MouseLeave:Connect(function()
		TweenService:Create(
			raceAgainBtn,
			TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ BackgroundColor3 = COLOR_BTN }
		):Play()
	end)

	raceAgainBtn.MouseButton1Click:Connect(function()
		raceAgainRemote:FireServer()
		-- Animate panel off-screen, then destroy once the tween completes
		local exitTween = TweenService:Create(
			panel,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 1.6, 0) }
		)
		exitTween.Completed:Connect(function()
			if panel and panel.Parent then
				panel:Destroy()
			end
		end)
		exitTween:Play()
	end)

	-- ── Slide-in entrance animation ───────────────────────────────────────────
	TweenService:Create(
		panel,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.5, 0) }
	):Play()
end

-- ── Listen for the race finish signal ─────────────────────────────────────────
-- Small delay so the HUD timer has a chance to freeze on the final time first.
raceFinished.OnClientEvent:Connect(function(payload)
	task.wait(0.9)
	showResults(payload)
end)
