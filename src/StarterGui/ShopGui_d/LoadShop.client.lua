
-- THIS SCRIPT MADE BY @"GetReadyToDieWarrior"
-- UI MADE BY @"Lobezno413"
-- LINK: https://create.roblox.com/marketplace/asset/13424855495/Shop-Gui-Template-No-Scripts%3Fkeyword=&pageNumber=&pagePosition=

--[[ ####      ## ##   ### ##   ### ##   ####      ## ##   #### ##  ###  ##  ### ###  ### ## --]]
--[[  ##      ##   ##   ##  ##   ##  ##   ##      ##   ##  # ## ##   ##  ##   ##  ##   ##  ## --]]
--[[  ##      ##   ##   ##  ##   ##  ##   ##      ##   ##    ##      ##  ##   ##       ##  ## --]]
--[[  ##      ##   ##   ## ##    ##  ##   ##      ##   ##    ##      ## ###   ## ##    ## ## --]]
--[[  ##      ##   ##   ## ##    ##  ##   ##      ##   ##    ##      ##  ##   ##       ## ## --]]
--[[  ##  ##  ##   ##   ##  ##   ##  ##   ##  ##  ##   ##    ##      ##  ##   ##  ##   ##  ## --]]
--[[ ### ###   ## ##   #### ##  ### ##   ### ###   ## ##    ####    ###  ##  ### ###  #### ## --]]




local module = require(game.ReplicatedStorage.Module.ShopItems)

local ScrollFrame = script.Parent.Main.MainFrames.Left.ScrollingFrame1

local button = script.TextButton


local function LoadGUI()
	
	local itemCount = #module

	for i = 1, itemCount do
		
		local item = module[i]
		local clonnedButton = button:Clone()
		clonnedButton.Parent = ScrollFrame
		clonnedButton.Name = item.Name
		clonnedButton.Frame.ImageLabel.Image = item.Pic
		clonnedButton.Frame.ImageLabel.Title.Text = item.Name
		
	end
	
	script.Parent.Enabled = true
	
end


LoadGUI()