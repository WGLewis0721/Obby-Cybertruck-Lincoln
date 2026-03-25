--!strict
-- SCRIPT: RemoteEventSetup | LOCATION: ServerScriptService/Setup | SIDE: Server
-- Run-once setup script to ensure vehicle RemoteEvents exist
-- Idempotent - safe to run multiple times

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get the Events folder with timeout
local remotesFolder = ReplicatedStorage:WaitForChild("Events", 10)
if not remotesFolder then
	error("[RemoteSetup] ERROR: ReplicatedStorage/Events/ folder not found after 10 seconds!")
	return
end

-- Required RemoteEvents for vehicle input pipeline
local requiredRemotes: {string} = {
	"VehicleInput",
	"HUDUpdate",
	"VehicleSpawned",
}

-- Track results for final report
local createdCount: number = 0
local skippedCount: number = 0

print("[RemoteSetup] Starting RemoteEvent verification...")

-- Step 1: Ensure each RemoteEvent exists
for _, remoteName in ipairs(requiredRemotes) do
	local existingRemote = remotesFolder:FindFirstChild(remoteName)
	
	if existingRemote then
		-- Already exists - skip
		print("[RemoteSetup] '" .. remoteName .. "' already exists — skipping")
		skippedCount += 1
	else
		-- Create new RemoteEvent
		local newRemote = Instance.new("RemoteEvent")
		newRemote.Name = remoteName
		newRemote.Parent = remotesFolder
		print("[RemoteSetup] Created RemoteEvent '" .. remoteName .. "'")
		createdCount += 1
	end
end

-- Step 2: Final verification
print("[RemoteSetup] Verifying all RemoteEvents...")

local verificationResults: {string} = {}
local allPresent: boolean = true

for _, remoteName in ipairs(requiredRemotes) do
	local remote = remotesFolder:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		table.insert(verificationResults, remoteName .. " ✓")
	else
		table.insert(verificationResults, remoteName .. " ✗")
		print("[RemoteSetup] WARNING: '" .. remoteName .. "' still missing")
		allPresent = false
	end
end

-- Final summary
if allPresent then
	print("[RemoteSetup] Verified: " .. table.concat(verificationResults, "  "))
else
	print("[RemoteSetup] VERIFICATION FAILED - some RemoteEvents are missing")
end

print("[RemoteSetup] Setup complete. Created: " .. tostring(createdCount) .. "  Skipped: " .. tostring(skippedCount))

return "RemoteEventSetup complete. Created: " .. createdCount .. ", Skipped: " .. skippedCount
