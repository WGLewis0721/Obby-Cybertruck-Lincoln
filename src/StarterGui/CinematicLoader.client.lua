-- CinematicLoader.client.lua
-- Cinematic pre-loader that orbits the camera around the Tesla Cybertruck
-- while game assets stream in, then fades out and hands control back to the
-- regular title screen (LoadingScreen.client.lua).

local ContentProvider = game:GetService("ContentProvider")
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local Workspace       = game:GetService("Workspace")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

-- ── Black overlay ScreenGui ───────────────────────────────────────────────────
-- DisplayOrder 200 sits above the title-screen panel (DisplayOrder 100) so
-- this cinematic fully covers the menu until we're ready to reveal it.
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "CinematicLoaderGui"
screenGui.ResetOnSpawn     = false
screenGui.DisplayOrder     = 200
screenGui.IgnoreGuiInset   = true
screenGui.Parent           = playerGui

local overlay = Instance.new("Frame")
overlay.Name                   = "BlackOverlay"
overlay.Size                   = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3       = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0   -- fully opaque (black) at start
overlay.BorderSizePixel        = 0
overlay.Parent                 = screenGui

-- ── Background music ──────────────────────────────────────────────────────────
-- Sound is parented to Workspace so it plays in 3-D audio world space.
local bgMusic = Instance.new("Sound")
bgMusic.Name    = "CinematicBGM"
bgMusic.SoundId = "rbxassetid://1837849285"
bgMusic.Volume  = 0       -- start silent; faded in below
bgMusic.Looped  = true
bgMusic.Parent  = Workspace
bgMusic:Play()

-- ── Set camera to Scriptable so we control it frame-by-frame ─────────────────
camera.CameraType = Enum.CameraType.Scriptable

-- ── Find the Cybertruck and compute its world-space centre ───────────────────
-- WaitForChild blocks until the model is fully replicated.
local cybertruck = Workspace:WaitForChild("Tesla Cybertruck")

local truckCFrame = cybertruck:GetBoundingBox()   -- returns CFrame, Vector3
local truckCenter = truckCFrame.Position

-- ── Orbit parameters ─────────────────────────────────────────────────────────
local ORBIT_RADIUS        = 27    -- studs from the truck centre
local ORBIT_HEIGHT_OFFSET = 4     -- studs above the bounding-box centre
local ORBIT_SPEED         = 0.4   -- radians per second (slow, cinematic)
local MIN_CINEMATIC_TIME  = 3     -- seconds before the cinematic may end

-- ── Begin background tasks ────────────────────────────────────────────────────
-- Both tasks run concurrently; we wait for BOTH before ending the cinematic.
local loadingDone  = false
local minTimerDone = false

-- Preload every descendant currently in Workspace.
task.spawn(function()
	ContentProvider:PreloadAsync(Workspace:GetDescendants())
	loadingDone = true
end)

-- Enforce the minimum cinematic duration.
task.delay(MIN_CINEMATIC_TIME, function()
	minTimerDone = true
end)

-- ── Fade in from black ────────────────────────────────────────────────────────
-- Fade music volume up to 0.6 over 1 second.
TweenService:Create(
	bgMusic,
	TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	{ Volume = 0.6 }
):Play()

-- After a short hold, fade the black overlay to transparent to reveal the scene.
task.wait(0.3)
TweenService:Create(
	overlay,
	TweenInfo.new(1.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	{ BackgroundTransparency = 1 }
):Play()

-- ── Orbit camera loop ─────────────────────────────────────────────────────────
-- RenderStepped fires every frame before the scene is rendered, giving the
-- smoothest possible camera motion (matches Gran Turismo / NFS car-select feel).
local orbitAngle = 0
local renderConn = RunService.RenderStepped:Connect(function(dt)
	orbitAngle = orbitAngle + ORBIT_SPEED * dt

	local camX = truckCenter.X + ORBIT_RADIUS * math.cos(orbitAngle)
	local camY = truckCenter.Y + ORBIT_HEIGHT_OFFSET
	local camZ = truckCenter.Z + ORBIT_RADIUS * math.sin(orbitAngle)

	-- CFrame.lookAt positions the camera and aims it at the truck centre.
	camera.CFrame = CFrame.lookAt(Vector3.new(camX, camY, camZ), truckCenter)
end)

-- ── Wait until loading is done AND the minimum time has elapsed ───────────────
repeat task.wait(0.1) until loadingDone and minTimerDone

-- Stop the orbit loop before starting the outro fade.
renderConn:Disconnect()

-- ── Fade out ──────────────────────────────────────────────────────────────────
-- Fade music volume to 0 over 1 second.
TweenService:Create(
	bgMusic,
	TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
	{ Volume = 0 }
):Play()

-- Fade the overlay back to black over 1.5 seconds.
TweenService:Create(
	overlay,
	TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In),
	{ BackgroundTransparency = 0 }
):Play()

task.wait(1.5)

-- ── Restore camera and clean up ───────────────────────────────────────────────
-- Returning to Custom hands camera control back to Roblox's default camera rig,
-- which the existing title-screen uses (it doesn't manipulate the camera).
camera.CameraType = Enum.CameraType.Custom

bgMusic:Stop()
bgMusic:Destroy()
screenGui:Destroy()
