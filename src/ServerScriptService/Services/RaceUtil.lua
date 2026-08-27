--[[
	RaceUtil.lua
	Description: Shared resolution of "which player does this touched part belong to?".
	Author: Cybertruck Obby Lincoln
	Last Updated: 2026

	A vehicle model is Vehicle_<UserId>, but its parts live inside nested child
	Models (Wheels, Body, Misc). FindFirstAncestorWhichIsA("Model") therefore
	returns the INNER model and never matches the Vehicle_ name -- which silently
	broke coin pickups, checkpoints and lap counting. Walk the full ancestor
	chain instead, and accept the OwnerUserId attribute GarageHandler stamps on
	the vehicle as a second source of truth.

	Dependencies:
		- None

	Events Fired / Listened:
		- None
--]]

local Players = game:GetService("Players")

local RaceUtil = {}

function RaceUtil.GetOwnerUserIdFromHit(hit: BasePart): number?
	local inst: Instance? = hit
	while inst and inst ~= workspace do
		if inst:IsA("Model") then
			local id = tonumber(inst.Name:match("^Vehicle_(%d+)$"))
			if id then
				return id
			end
			local attr = inst:GetAttribute("OwnerUserId")
			if type(attr) == "number" then
				return attr
			end
		end
		inst = inst.Parent
	end
	return nil
end

function RaceUtil.GetPlayerFromHit(hit: BasePart): (Player?, number?)
	local userId = RaceUtil.GetOwnerUserIdFromHit(hit)
	if not userId then
		return nil, nil
	end
	return Players:GetPlayerByUserId(userId), userId
end

return RaceUtil
