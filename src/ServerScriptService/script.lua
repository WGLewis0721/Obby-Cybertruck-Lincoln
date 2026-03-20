local ss = game:GetService("ServerScriptService")

local toDelete = {
    "PaintShopHandler",
    "CoinHandler", 
    "CheckpointHandler",
    "TimerHandler",
    "GarageHandler",
    "GenerateCityMap",
    "GenerateMountainMap",
    "GenerateRaceTrackMap",
}

for _, name in ipairs(toDelete) do
    local script = ss:FindFirstChild(name)
    if script then
        script:Destroy()
        print("✅ Deleted root duplicate: " .. name)
    else
        print("⏭ Not found at root: " .. name)
    end
end

print("Done - restart playtest now")