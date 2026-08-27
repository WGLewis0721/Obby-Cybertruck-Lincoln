--!strict
-- SCRIPT: ResponsiveHudController | LOCATION: StarterGui | SIDE: Client

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Reference denominator for Speedo's UIScale: matches the old non-touch pixel
-- size, so non-touch scale stays 1.0 (native/unmodified) and touch scales down
-- proportionally from there.
local SPEEDO_REFERENCE_SIZE = 220

local function setScale(container: GuiObject, value: number)
	local scale = container:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = container
	end
	scale.Scale = value
end

local function applyLayout()
	local viewport = camera.ViewportSize
	local shortSide = math.max(1, math.min(viewport.X, viewport.Y))
	local compact = UserInputService.TouchEnabled and shortSide < 600
	local touch = UserInputService.TouchEnabled

	for _, item in ipairs(playerGui:GetChildren()) do
		if item:IsA("ScreenGui") and (item.Name == "GameHUD" or item.Name == "RaceHUD" or item.Name == "MobileControls") then
			item.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		end
	end

	local gameHud = playerGui:FindFirstChild("GameHUD")
	local navigation = gameHud and gameHud:FindFirstChild("NavButtons")
	if navigation and navigation:IsA("Frame") then
		local navigationScale = touch and (compact and 0.72 or 0.86) or 1
		setScale(navigation, navigationScale)
		navigation.AnchorPoint = Vector2.new(0, 0.5)
		navigation.Position = UDim2.new(0, touch and 10 or 12, 0.5, 0)
	end

	local raceHud = playerGui:FindFirstChild("RaceHUD")
	local raceControls = raceHud and raceHud:FindFirstChild("RaceControls")
	if raceControls and raceControls:IsA("Frame") then
		local raceScale = touch and (compact and 0.72 or 0.86) or 1
		setScale(raceControls, raceScale)
		raceControls.AnchorPoint = Vector2.new(0.5, 1)
		raceControls.Position = if touch
		then UDim2.new(0.5, 0, 1, -math.max(150, math.floor(viewport.Y * 0.34)))
		else UDim2.new(0.5, 0, 1, -24)
	end

	local coinPanel = raceHud and raceHud:FindFirstChild("CoinPanel")
	if coinPanel and coinPanel:IsA("Frame") then
		setScale(coinPanel, touch and (compact and 0.72 or 0.84) or 1)
		coinPanel.AnchorPoint = Vector2.new(1, 0)
		coinPanel.Position = UDim2.new(1, -12, 0, 18)
	end

	-- Speedo/Speed/Gear/TMode all derive from this one size+offset pair so they
	-- stay proportional and in sync -- computed once rather than re-derived
	-- per item (previously 220/24 non-touch, 116-190/96-190 touch; bumped up
	-- per "make the speedometer bigger").
	local speedSize = touch and math.clamp(math.floor(shortSide * 0.24), 150, 235) or 300
	local bottomOffset = touch and math.clamp(math.floor(viewport.Y * 0.36), 110, 210) or 42
	local rightMargin = touch and 14 or 20

	for _, item in ipairs(playerGui:GetDescendants()) do
		if item:IsA("GuiObject") and item.Name == "Speedo" then
			-- Speedo's tick marks/needle (Gauges_AC6.lua) are positioned with fixed
			-- pixel offsets authored for its native size. Overwriting .Size directly
			-- broke that internal layout (ticks rendered far outside the shrunk
			-- frame since ClipsDescendants is off) -- scale the whole frame
			-- proportionally via UIScale instead, which scales children along with it.
			item.AnchorPoint = Vector2.new(1, 1)
			item.Position = UDim2.new(1, -rightMargin, 1, -bottomOffset)
			setScale(item, speedSize / SPEEDO_REFERENCE_SIZE)
		elseif item:IsA("GuiObject") and item.Name == "Speed" then
			item.AnchorPoint = Vector2.new(1, 1)
			item.Position = UDim2.new(1, -rightMargin, 1, -math.max(24, bottomOffset - 12))
			item.Size = UDim2.fromOffset(speedSize, 24)
		elseif item:IsA("GuiObject") and (item.Name == "Gear" or item.Name == "TMode")
			and item.Parent and item.Parent.Name == "AC6_Compact_Gauges" then
			-- Stack to the dial's left, clear of the whole tick/number arc (which
			-- radiates toward the bottom-right, back toward Speedo's own corner
			-- anchor) rather than trying to dodge the arc vertically.
			item.AnchorPoint = Vector2.new(0.5, 1)
			item.Size = UDim2.fromOffset(math.floor(speedSize * 0.22), math.floor(speedSize * 0.16))
			local sideOffset = math.floor(speedSize * 1.05)
			local liftOffset = item.Name == "Gear" and math.floor(speedSize * 0.55) or math.floor(speedSize * 0.28)
			item.Position = UDim2.new(1, -rightMargin - sideOffset, 1, -bottomOffset - liftOffset)
		end
	end
end

applyLayout()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)

-- Debounced: DescendantAdded fires once per instance, and initial load creates
-- hundreds of GUI descendants across ~10 HUD/menu scripts within the same few
-- frames. Without this, each one queued its own full applyLayout() pass
-- (including a GetDescendants() scan of all of PlayerGui) -- a burst of ~300
-- insertions meant ~300 redundant full scans stacking up, which is a real
-- contributor to load-in lag. Collapse any burst into a single deferred pass.
local refreshScheduled = false
playerGui.DescendantAdded:Connect(function()
	if refreshScheduled then return end
	refreshScheduled = true
	task.defer(function()
		refreshScheduled = false
		applyLayout()
	end)
end)