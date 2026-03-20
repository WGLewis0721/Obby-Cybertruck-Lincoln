local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopGui = playerGui:WaitForChild("ShopGui_d", 5)
if not shopGui then
	warn("ShopGui_d not found in PlayerGui after 5 seconds")
	return
end

local shopButton = shopGui:FindFirstChild("ShopButton")
local shopMenu = shopGui:FindFirstChild("Main")

if not shopButton then
	warn("ShopButton not found in ShopGui_d")
	return
end

if not shopMenu then
	warn("Main (shop menu) not found in ShopGui_d")
	return
end

shopButton.MouseButton1Click:Connect(function()
	shopMenu.Visible = true
	shopButton.Visible = false
end)
