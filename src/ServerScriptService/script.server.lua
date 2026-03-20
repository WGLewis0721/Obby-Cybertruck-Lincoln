local Players = game:GetService("Players")
Players.CharacterAutoLoads = true
Players.PlayerAdded:Connect(function(player)
    player:LoadCharacter()
end)
for _, player in ipairs(Players:GetPlayers()) do
    player:LoadCharacter()
end
print("✅ CharacterAutoLoads fixed")