local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopGui = playerGui:WaitForChild("ShopGui_d", 5)

if not shopGui then
	warn("ShopGui_d not found in PlayerGui after 5 seconds")
	return
end

local shopButton = shopGui:FindFirstChild("ShopButton")

if not shopButton then
	warn("ShopButton not found inside ShopGui_d")
	return
end

local openPaintShop = ReplicatedStorage:FindFirstChild("OpenPaintShop")

if not openPaintShop then
	warn("OpenPaintShop RemoteEvent missing")
	return
end

shopButton.MouseButton1Click:Connect(function()
	openPaintShop:FireServer()
end)