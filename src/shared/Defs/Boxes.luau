--!strict
--[[
	Boxes.luau -- the box maths, pure so the test can prove the real thing.

	A box's odds (Config.Boxes) are weights per tier. `rollTier` turns one
	random number in [0, 1) into a tier; `pool` is the cubes a tier can
	hatch. The Classic cube everyone starts with is left out of the pool
	whenever the tier has anything else, so a box never hands back the
	starter.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cubes = require(script.Parent:WaitForChild("Cubes"))

local Boxes = {}

export type Box = { id: string, name: string, cost: number, odds: { [string]: number } }

local byId: { [string]: Box } = {}
for _, box in Config.Boxes.List :: { Box } do
	byId[box.id] = box
end

function Boxes.get(id: string): Box?
	return byId[id]
end

--[[
	`r` is a random number in [0, 1). Tiers with zero odds are never
	returned; if every tier is zero, the first tier is.
]]
function Boxes.rollTier(box: Box, r: number): string
	local order = Config.Boxes.TierOrder
	local total = 0
	for _, tier in order do
		total += box.odds[tier] or 0
	end
	local pick = r * total
	local acc = 0
	for _, tier in order do
		local weight = box.odds[tier] or 0
		acc += weight
		if weight > 0 and pick < acc then
			return tier
		end
	end
	-- r == 1 cannot happen, but floating point can land exactly on
	-- `total`: give it to the last tier with any weight.
	for i = #order, 1, -1 do
		if (box.odds[order[i]] or 0) > 0 then
			return order[i]
		end
	end
	return order[1]
end

--[[
	The cubes a tier can hatch, without the starter unless it is alone.
]]
function Boxes.pool(tier: string): { Cubes.Def }
	local all = Cubes.ofTier(tier)
	local out: { Cubes.Def } = {}
	for _, def in all do
		if def.id ~= Cubes.Default then
			table.insert(out, def)
		end
	end
	if #out == 0 then
		return all
	end
	return out
end

return Boxes
