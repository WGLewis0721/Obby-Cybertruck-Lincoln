-- MapSelectHandler.server.lua
-- Handles map selection from client and triggers exactly one map generator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Map definitions linked to folder names.
local MAPS = {
	skyscraper = {FolderName = "SkyscraperMap"},
	bigfoot    = {FolderName = "BigFootMap"},
	highspeed  = {FolderName = "HighSpeedMap"},
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

local function chooseDefaultMap()
	local selected = workspace:GetAttribute("SelectedMap")
	if selected and MAPS[selected] then
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
		warn("MapSelectHandler: map folder missing - ensure generator script ran on server start")
	end
	-- Do not generate the map here
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
	workspace:SetAttribute("SelectedMap", mapId)
	clearMaps()

	local hasFolder = workspace:FindFirstChild(info.FolderName)
	if not hasFolder then
		warn("MapSelectHandler: selected map folder missing - ensure generator script ran on server start")
	end
end)

-- Ensure the map exists at start so race logic and spawn positions are valid.
ensureMapSelected()
