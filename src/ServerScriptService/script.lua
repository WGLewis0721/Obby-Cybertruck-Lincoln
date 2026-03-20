local setup = game.ServerScriptService:FindFirstChild("Setup")
if setup then
    local cityMap = setup:FindFirstChild("GenerateCityMap")
    if cityMap then
        cityMap.Disabled = true
        print("✅ GenerateCityMap disabled")
    end
end