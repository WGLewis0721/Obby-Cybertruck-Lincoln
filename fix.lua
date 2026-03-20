-- ============================================================
-- CYBERTRUCK OBBY LINCOLN - ONE SHOT CLEANUP SCRIPT
-- Run this in the Roblox Studio Command Bar ONCE
-- It fixes all known errors directly in the game tree
-- Does NOT require Rojo or file system changes
-- ============================================================

local fixed = {}
local skipped = {}
local errors = {}

local function log(msg) table.insert(fixed, msg) end
local function skip(msg) table.insert(skipped, msg) end
local function fail(msg) table.insert(errors, msg) end

-- ============================================================
-- FIX 1: DELETE ROBLOX_AI_BRIEFING FROM SERVERSCRIPTSERVICE
-- ============================================================
local briefing = game.ServerScriptService:FindFirstChild("ROBLOX_AI_BRIEFING")
if briefing then
    briefing:Destroy()
    log("✅ Deleted ROBLOX_AI_BRIEFING from ServerScriptService")
else
    skip("⏭ ROBLOX_AI_BRIEFING not found in ServerScriptService")
end

-- ============================================================
-- FIX 2: DELETE REDUNDANT SHOP GUI (ShopGui_d)
-- ============================================================
local starterGui = game:GetService("StarterGui")
local shopGui = starterGui:FindFirstChild("ShopGui_d")
if shopGui then
    shopGui:Destroy()
    log("✅ Deleted ShopGui_d from StarterGui")
else
    skip("⏭ ShopGui_d not found in StarterGui")
end

-- ============================================================
-- FIX 3: DELETE REDUNDANT SHOP SCRIPTS FROM STARTERPLAYER
-- ============================================================
local starterPlayer = game:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")

if starterPlayerScripts then
    local clientFolder = starterPlayerScripts:FindFirstChild("Client")
    if clientFolder then
        local shopButtonHandler = clientFolder:FindFirstChild("ShopButtonHandler")
        if shopButtonHandler then
            shopButtonHandler:Destroy()
            log("✅ Deleted ShopButtonHandler from StarterPlayerScripts/Client")
        else
            skip("⏭ ShopButtonHandler not found")
        end

        local shopMenuScript = clientFolder:FindFirstChild("ShopMenuScript")
        if shopMenuScript then
            shopMenuScript:Destroy()
            log("✅ Deleted ShopMenuScript from StarterPlayerScripts/Client")
        else
            skip("⏭ ShopMenuScript not found")
        end
    else
        skip("⏭ Client folder not found in StarterPlayerScripts")
    end
else
    fail("❌ StarterPlayerScripts not found")
end

-- ============================================================
-- FIX 4: FIX EXPANDTOGRID IN ALL 3 MAP GENERATORS
-- ============================================================
local snapToGridFunc = [[
local function snapToGrid(vec, gridSize)
    gridSize = gridSize or 4
    return Vector3.new(
        math.round(vec.X / gridSize) * gridSize,
        math.round(vec.Y / gridSize) * gridSize,
        math.round(vec.Z / gridSize) * gridSize
    )
end
]]

local generatorNames = {
    "GenerateCityMap",
    "GenerateMountainMap",
    "GenerateRaceTrackMap"
}

for _, name in ipairs(generatorNames) do
    local script = game.ServerScriptService:FindFirstChild(name)
    if script then
        local src = script.Source
        if src:find("ExpandToGrid") then
            -- Replace Region3:ExpandToGrid(N) pattern
            -- Pattern: Region3.new(x, y):ExpandToGrid(N)
            src = src:gsub(
                "Region3%.new%((.-)%):ExpandToGrid%((%d+)%)",
                function(args, gridSize)
                    return string.format(
                        "Region3.new(snapToGrid(%s, %s))",
                        args:match("^(.-)%s*,") or args,
                        gridSize
                    )
                end
            )
            -- Simpler fallback: just remove :ExpandToGrid(N) calls
            src = src:gsub(":ExpandToGrid%(%d+%)", "")
            -- Inject snapToGrid function after first line
            local firstNewline = src:find("\n")
            if firstNewline then
                src = src:sub(1, firstNewline) .. snapToGridFunc .. src:sub(firstNewline + 1)
            end
            script.Source = src
            log("✅ Fixed ExpandToGrid in " .. name)
        else
            skip("⏭ No ExpandToGrid found in " .. name)
        end
    else
        skip("⏭ " .. name .. " not found in ServerScriptService")
    end
end

-- ============================================================
-- FIX 5: FIX CAMERA LOCK IN STARTERUI SCRIPTS
-- ============================================================
-- Find any script setting camera to Scriptable without restoring it
local cameraFix = [[

-- AUTO INJECTED CAMERA SAFETY NET
-- Ensures camera is always restored if menu script errors
local _cameraRestoreConnection
_cameraRestoreConnection = game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    local cam = workspace.CurrentCamera
    if cam.CameraType == Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Custom
    end
    _cameraRestoreConnection:Disconnect()
end)
]]

local guiScriptsToCheck = {
    "MainMenu",
    "LoadingScreen",
    "MenuCamera",
    "CinematicMenu",
}

for _, name in ipairs(guiScriptsToCheck) do
    local script = starterGui:FindFirstChild(name, true)
    if script and (script:IsA("LocalScript") or script:IsA("Script")) then
        local src = script.Source
        if src:find("Scriptable") and not src:find("_cameraRestoreConnection") then
            -- Make sure camera restore is in the script
            -- Find the Play button click handler and ensure restore is there
            if src:find("CameraType.Custom") then
                skip("⏭ " .. name .. " already restores camera")
            else
                -- Append safety net to end of script
                script.Source = src .. "\n" .. cameraFix
                log("✅ Added camera safety net to " .. name)
            end
        else
            skip("⏭ " .. name .. " does not use Scriptable camera or already fixed")
        end
    end
end

-- Also check for any black overlay frames that might be stuck
-- Find ScreenGuis with full black frames at transparency 0
for _, gui in ipairs(starterGui:GetChildren()) do
    if gui:IsA("ScreenGui") then
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("Frame") then
                if child.BackgroundColor3 == Color3.new(0, 0, 0)
                    and child.BackgroundTransparency == 0
                    and child.Size == UDim2.new(1, 0, 1, 0) then
                    -- This might be a stuck black overlay
                    -- Make it transparent by default so it doesn't block view
                    child.BackgroundTransparency = 1
                    log("✅ Fixed stuck black overlay frame in " .. gui.Name .. " > " .. child.Name)
                end
            end
        end
    end
end

-- ============================================================
-- FIX 6: FIX A-CHASSIS TUNE NIL VALUE IN TESLA CYBERTRUCK
-- ============================================================
local function fixAChassisTune(vehicleName, referenceVehicleName)
    local vehicle = workspace:FindFirstChild(vehicleName)
    local refVehicle = workspace:FindFirstChild(referenceVehicleName)

    if not vehicle then
        skip("⏭ " .. vehicleName .. " not found in Workspace")
        return
    end
    if not refVehicle then
        skip("⏭ Reference vehicle " .. referenceVehicleName .. " not found")
        return
    end

    local tune = vehicle:FindFirstChild("A-Chassis Tune", true)
    local refTune = refVehicle:FindFirstChild("A-Chassis Tune", true)

    if not tune or not refTune then
        skip("⏭ A-Chassis Tune not found in one of the vehicles")
        return
    end

    -- Find the Tune ModuleScript inside A-Chassis Tune
    local tuneModule = tune:FindFirstChild("Tune") or tune:FindFirstChildWhichIsA("ModuleScript")
    local refTuneModule = refTune:FindFirstChild("Tune") or refTune:FindFirstChildWhichIsA("ModuleScript")

    if not tuneModule or not refTuneModule then
        skip("⏭ Tune ModuleScript not found")
        return
    end

    -- Common fields that must be numbers in A-Chassis
    local requiredNumericFields = {
        "WeightDistribution",
        "Weight",
        "WheelBase",
        "FrontAxle",
        "RearAxle",
        "Gravity",
        "MaxSteerAngle",
        "SteerInner",
        "SteerOuter",
        "MaxSpeed",
        "Horsepower",
        "TorqueCurve",
    }

    local tuneSource = tuneModule.Source
    local refSource = refTuneModule.Source
    local patched = false

    for _, field in ipairs(requiredNumericFields) do
        -- Check if field is missing or nil in tune
        if not tuneSource:find(field) then
            -- Try to find it in reference
            local refValue = refSource:match(field .. "%s*=%s*([%d%.%-]+)")
            if refValue then
                -- Add field before the closing return statement
                tuneSource = tuneSource:gsub(
                    "(return%s+Tune)",
                    string.format("Tune.%s = %s\nreturn Tune", field, refValue)
                )
                patched = true
                log("✅ Added missing field " .. field .. " = " .. refValue .. " to " .. vehicleName .. " Tune")
            end
        end
    end

    if patched then
        tuneModule.Source = tuneSource
    else
        skip("⏭ No missing fields found in " .. vehicleName .. " A-Chassis Tune")
    end
end

fixAChassisTune("Tesla Cybertruck", "Zonda Revo Barchetta")

-- ============================================================
-- FIX 7: FIX DEVEL DENSITY VALUE
-- ============================================================
local devel = workspace:FindFirstChild("Devel")
if devel then
    local tune = devel:FindFirstChild("A-Chassis Tune", true)
    if tune then
        local tuneModule = tune:FindFirstChild("Tune") or tune:FindFirstChildWhichIsA("ModuleScript")
        if tuneModule then
            local src = tuneModule.Source
            -- Replace Density = 0 with Density = 0.0001
            local newSrc = src:gsub("Density%s*=%s*0([^%.%d])", "Density = 0.0001%1")
            if newSrc ~= src then
                tuneModule.Source = newSrc
                log("✅ Fixed Devel A-Chassis Density value (0 → 0.0001)")
            else
                skip("⏭ Devel Density value already correct or not found")
            end
        else
            skip("⏭ Devel Tune ModuleScript not found")
        end
    else
        skip("⏭ Devel A-Chassis Tune not found")
    end
else
    skip("⏭ Devel vehicle not found in Workspace")
end

-- ============================================================
-- REPORT
-- ============================================================
print("\n========================================")
print("  CYBERTRUCK OBBY CLEANUP REPORT")
print("========================================")
print("\n✅ FIXED (" .. #fixed .. "):")
for _, msg in ipairs(fixed) do print("  " .. msg) end
print("\n⏭ SKIPPED (" .. #skipped .. "):")
for _, msg in ipairs(skipped) do print("  " .. msg) end
if #errors > 0 then
    print("\n❌ ERRORS (" .. #errors .. "):")
    for _, msg in ipairs(errors) do print("  " .. msg) end
end
print("\n========================================")
print("  Run complete. Check output above.")
print("  Remember to enable API Services in")
print("  Home > Game Settings > Security")
print("========================================\n")