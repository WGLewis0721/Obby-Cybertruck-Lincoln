local Players = game:GetService("Players")

-- Let Roblox handle the initial spawn normally. Forcing LoadCharacter here
-- creates duplicate CharacterAdded flows and double vehicle spawns.
Players.CharacterAutoLoads = true

print("CharacterAutoLoads enabled")
