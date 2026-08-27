--!strict
-- SCRIPT: EnsureCityHubGround | LOCATION: ServerScriptService/Setup | SIDE: Server

local Workspace = game:GetService("Workspace")

local hub = Workspace:WaitForChild("CityHub", 30)
if not hub or not hub:IsA("Model") then
	warn("EnsureCityHubGround: CityHub model was not found")
	return
end

local spawnMarker = Workspace:FindFirstChild("VehicleSpawn")
if spawnMarker and spawnMarker:IsA("BasePart") then
	spawnMarker.CFrame = CFrame.lookAt(spawnMarker.Position, spawnMarker.Position + Vector3.new(0, 0, -1))
end

if Workspace:FindFirstChild("CityHubGround") then
	return
end

local boundsCFrame, boundsSize = hub:GetBoundingBox()
local ground = Instance.new("Part")
ground.Name = "CityHubGround"
ground.Size = Vector3.new(boundsSize.X + 160, 4, boundsSize.Z + 160)
ground.CFrame = CFrame.new(boundsCFrame.Position.X, boundsCFrame.Position.Y - boundsSize.Y * 0.5 - 2, boundsCFrame.Position.Z)
ground.Anchored = true
ground.CanCollide = true
ground.CanTouch = true
ground.CanQuery = true
ground.Material = Enum.Material.Grass
ground.Color = Color3.fromRGB(73, 108, 68)
ground.TopSurface = Enum.SurfaceType.Smooth
ground.BottomSurface = Enum.SurfaceType.Smooth
ground.Parent = Workspace