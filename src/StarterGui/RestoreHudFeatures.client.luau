--!strict
-- SCRIPT: RestoreHudFeatures | LOCATION: StarterGui | SIDE: Client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local events = ReplicatedStorage:WaitForChild("Events")
local selectMap = events:WaitForChild("SelectMap") :: RemoteEvent
local startRace = events:WaitForChild("StartRace") :: RemoteEvent
local endRace = events:WaitForChild("EndRace") :: RemoteEvent
local raceAgain = events:WaitForChild("RaceAgain") :: RemoteEvent
local returnHome = events:WaitForChild("ReturnToLobby") :: RemoteEvent
local raceStarted = events:WaitForChild("RaceStarted") :: RemoteEvent
local raceFinished = events:WaitForChild("RaceFinished") :: RemoteEvent

local function getScreenGui(name: string): ScreenGui?
	for _, item in ipairs(playerGui:GetChildren()) do
		if item.Name == name and item:IsA("ScreenGui") then return item end
	end
	return nil
end

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function ensureMapMenu(gameHud: ScreenGui)
	if gameHud:FindFirstChild("MapMenu") then return end
	local navigation = gameHud:FindFirstChild("NavButtons")
	local mapButton = navigation and navigation:FindFirstChild("MAP")
	if not mapButton or not mapButton:IsA("TextButton") then return end

	local menu = Instance.new("Frame")
	menu.Name = "MapMenu"
	menu.Size = UDim2.fromOffset(220, 92)
	menu.Position = UDim2.new(0, 104, 0.5, -46)
	menu.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	menu.BackgroundTransparency = 0.05
	menu.BorderSizePixel = 0
	menu.Visible = false
	menu.ZIndex = 40
	menu.Parent = gameHud
	addCorner(menu, 8)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "SELECT MAP"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(74, 240, 255)
	title.ZIndex = 41
	title.Parent = menu

	local city = Instance.new("TextButton")
	city.Name = "CityCircuitButton"
	city.Size = UDim2.new(1, -20, 0, 42)
	city.Position = UDim2.fromOffset(10, 38)
	city.BackgroundColor3 = Color3.fromRGB(35, 75, 95)
	city.BorderSizePixel = 0
	city.Text = "CITY CIRCUIT"
	city.Font = Enum.Font.GothamBold
	city.TextSize = 14
	city.TextColor3 = Color3.new(1, 1, 1)
	city.ZIndex = 41
	city.Parent = menu
	addCorner(city, 6)

	mapButton.MouseButton1Click:Connect(function()
		menu.Visible = not menu.Visible
	end)
	city.MouseButton1Click:Connect(function()
		selectMap:FireServer("skyscraper")
		menu.Visible = false
	end)
end

local function ensureRaceControls(raceHud: ScreenGui)
	if raceHud:FindFirstChild("RestoreRaceControls") then return end
	local bar = Instance.new("Frame")
	bar.Name = "RestoreRaceControls"
	bar.Size = UDim2.fromOffset(500, 42)
	bar.Position = UDim2.new(0.5, 0, 1, -20)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.ZIndex = 40
	bar.Parent = raceHud

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = bar

	local function button(name: string, text: string, color: Color3): TextButton
		local item = Instance.new("TextButton")
		item.Name = name
		item.Size = UDim2.fromOffset(118, 42)
		item.BackgroundColor3 = color
		item.BorderSizePixel = 0
		item.Text = text
		item.Font = Enum.Font.GothamBold
		item.TextSize = 13
		item.TextColor3 = Color3.new(1, 1, 1)
		item.ZIndex = 41
		item.Parent = bar
		addCorner(item, 6)
		return item
	end

	local startButton = button("StartRaceButton", "START RACE", Color3.fromRGB(0, 150, 205))
	local endButton = button("EndRaceButton", "END RACE", Color3.fromRGB(160, 55, 55))
	local restartButton = button("RestartRaceButton", "RESTART", Color3.fromRGB(190, 135, 35))
	local homeButton = button("HomeButton", "HOME", Color3.fromRGB(45, 115, 75))

	local function sync()
		local onTrack = workspace:GetAttribute("SelectedMap") == "skyscraper"
		bar.Visible = onTrack
		if not onTrack then
			startButton.Visible = false
		endButton.Visible = false
			restartButton.Visible = false
			homeButton.Visible = false
		else
			startButton.Visible = true
			endButton.Visible = true
			restartButton.Visible = true
			homeButton.Visible = true
		end
	end

	startButton.MouseButton1Click:Connect(function() startRace:FireServer("skyscraper") end)
	endButton.MouseButton1Click:Connect(function() endRace:FireServer() end)
	restartButton.MouseButton1Click:Connect(function()
		raceAgain:FireServer()
		task.delay(0.15, function() startRace:FireServer("skyscraper") end)
	end)
	homeButton.MouseButton1Click:Connect(function() returnHome:FireServer() end)
	workspace:GetAttributeChangedSignal("SelectedMap"):Connect(sync)
	raceStarted.OnClientEvent:Connect(sync)
	raceFinished.OnClientEvent:Connect(sync)
	sync()
end

local function refresh()
	local gameHud = getScreenGui("GameHUD")
	local raceHud = getScreenGui("RaceHUD")
	if gameHud then ensureMapMenu(gameHud) end
	if raceHud then ensureRaceControls(raceHud) end
end

refresh()

-- Debounced for the same reason as ResponsiveHudController: initial load
-- creates hundreds of GUI descendants within the same few frames, and each
-- one would otherwise queue its own redundant refresh() pass.
local refreshScheduled = false
playerGui.DescendantAdded:Connect(function()
	if refreshScheduled then return end
	refreshScheduled = true
	task.defer(function()
		refreshScheduled = false
		refresh()
	end)
end)
