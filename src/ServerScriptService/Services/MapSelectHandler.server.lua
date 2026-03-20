-- MapSelectHandler.server.lua
-- Handles map selection from client and triggers exactly one map generator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Map definitions linked to folder names + generator module names.
local MAPS = {
	skyscraper = {FolderName = "SkyscraperMap", Generator = "GenerateCityMap"},
	bigfoot    = {FolderName = "BigFootMap",     Generator = "GenerateMountainMap"},
	highspeed  = {FolderName = "HighSpeedMap",    Generator = "GenerateRaceTrackMap"},
}

-- SelectMap RemoteEvent lives in the shared Remotes folder.
local remotesFolder  = ReplicatedStorage:WaitForChild("Remotes", 10)
local selectMapEvent = remotesFolder:WaitForChild("SelectMap", 10)

-- Helper: remove all known map folders from Workspace.
local function clearMaps()
	for _, info in pairs(MAPS) do
		local existing = workspace:FindFirstChild(info.FolderName)
		if existing then
			existing:Destroy()
			print("MapSelectHandler: removed existing map folder", info.FolderName)
		end
	end
end

local function getGeneratorModule(name)
	-- Prefer ModuleScript first. (Rojo .lua may map to ModuleScript or Script;
	-- we include both to keep compatibility.)
	local candidate = ServerScriptService:FindFirstChild(name)
	if candidate and (candidate:IsA("ModuleScript") or candidate:IsA("Script")) then
		return candidate
	end

	-- Search recursively for module by name in nested folders.
	local search = ServerScriptService:FindFirstChild(name, true)
	if search and (search:IsA("ModuleScript") or search:IsA("Script")) then
		return search
	end

	return nil
end

-- Build map generators table (module scripts in ServerScriptService).
local generators = {}
for id, info in pairs(MAPS) do
	local moduleScript = getGeneratorModule(info.Generator)
	if moduleScript then
		local ok, module = pcall(require, moduleScript)
		if ok and module and type(module.Generate) == "function" then
			generators[id] = module.Generate
		else
			warn("MapSelectHandler: failed to require generator module", info.Generator, "(module type:", module and type(module) or "nil", ")")
		end
	else
		warn("MapSelectHandler: missing generator ModuleScript", info.Generator)
	end
end

local function generateMap(mapId)
	local generator = generators[mapId]
	if not generator then
		warn("MapSelectHandler: generator function unavailable for", mapId, "(check whether the .lua is imported as ModuleScript)")
		return false
	end

	local mapInfo = MAPS[mapId]
	if not mapInfo then
		warn("MapSelectHandler: unknown map id while generating", mapId)
		return false
	end

	workspace:SetAttribute("SelectedMap", mapId)
	clearMaps()

	local success, err = pcall(function()
		generator(workspace)
	end)
	if not success then
		warn("MapSelectHandler: map generator failed for", mapId, err)
		return false
	end

	print("MapSelectHandler: map generation complete for", mapId)
	return true
end

local function chooseDefaultMap()
	local selected = workspace:GetAttribute("SelectedMap")
	if selected and generators[selected] then
		return selected
	end
	return "skyscraper"
end

local function ensureMapSelected()
	local active = chooseDefaultMap()
	local current = workspace:GetAttribute("SelectedMap")
	local hasFolder = MAPS[active] and workspace:FindFirstChild(MAPS[active].FolderName)

	if current == active and hasFolder then
		print("MapSelectHandler: active map already selected and present:", active)
		return
	end

	print("MapSelectHandler: ensuring map selected; active=", active, "selected=", current, "hasFolder=", tostring(hasFolder))
	if not hasFolder then
		print("MapSelectHandler: existing map folder missing, generating", active)
	end
	generateMap(active)
end

selectMapEvent.OnServerEvent:Connect(function(player, mapId)
	if type(mapId) ~= "string" then
		warn("MapSelectHandler: invalid mapId type from", player.Name)
		return
	end

	mapId = mapId:lower()
	local info = MAPS[mapId]
	if not info then
		warn("MapSelectHandler: unknown mapId from", player.Name, mapId)
		return
	end

	print("MapSelectHandler: player", player.Name, "selected map", mapId)
	generateMap(mapId)
end)

-- Ensure the map exists at start so race logic and spawn positions are valid.
ensureMapSelected()
