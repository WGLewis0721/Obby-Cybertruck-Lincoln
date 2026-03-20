-- MapSelector.server.lua
-- Handles map selection from client and triggers exactly one map generator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Map definitions linked to folder names + generator module names.
local MAPS = {
	skyscraper = {FolderName = "SkyscraperMap", Generator = "GenerateCityMap"},
	bigfoot    = {FolderName = "BigFootMap",     Generator = "GenerateMountainMap"},
	highspeed  = {FolderName = "HighSpeedMap",    Generator = "GenerateRaceTrackMap"},
}

-- Ensure Events folder + SelectMap RemoteEvent exist.
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if not eventsFolder then
	eventsFolder = Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = ReplicatedStorage
end

local selectMapEvent = eventsFolder:FindFirstChild("SelectMap")
if not selectMapEvent then
	selectMapEvent = Instance.new("RemoteEvent")
	selectMapEvent.Name = "SelectMap"
	selectMapEvent.Parent = eventsFolder
end

-- Helper: remove all known map folders from Workspace.
local function clearMaps()
	for _, info in pairs(MAPS) do
		local existing = workspace:FindFirstChild(info.FolderName)
		if existing then
			existing:Destroy()
			print("MapSelector: removed existing map folder", info.FolderName)
		end
	end
end

-- Build map generators table (module scripts in ServerScriptService).
local generators = {}
for id, info in pairs(MAPS) do
	local moduleScript = ServerScriptService:FindFirstChild(info.Generator)
	if moduleScript then
		local ok, module = pcall(require, moduleScript)
		if ok and module and type(module.Generate) == "function" then
			generators[id] = module.Generate
		else
			warn("MapSelector: failed to require generator module", info.Generator)
		end
	else
		warn("MapSelector: missing generator module script", info.Generator)
	end
end

selectMapEvent.OnServerEvent:Connect(function(player, mapId)
	if type(mapId) ~= "string" then
		warn("MapSelector: invalid mapId type from", player.Name)
		return
	end

	mapId = mapId:lower()
	local info = MAPS[mapId]
	if not info then
		warn("MapSelector: unknown mapId from", player.Name, mapId)
		return
	end

	print("MapSelector: player", player.Name, "selected map", mapId)

	workspace:SetAttribute("SelectedMap", mapId)
	clearMaps()

	local generate = generators[mapId]
	if not generate then
		warn("MapSelector: generator function unavailable for", mapId)
		return
	end

	local ok, err = pcall(function()
		generate(workspace)
	end)
	if not ok then
		warn("MapSelector: map generator failed for", mapId, err)
	else
		print("MapSelector: map generation complete for", mapId)
	end
end)
