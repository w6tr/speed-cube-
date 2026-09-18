--!strict
--[[
	Spectators.luau -- the other players' cubes.

	One silent, arrow-less CubeView per occupied pedestal other than our
	own, standing on that pedestal and wearing that player's equipped
	cube. The server tells every client what happens on every pedestal
	(Spectate events); this file applies them. On join, Sync carries the
	current state of each pedestal so the copies start in step.

	Pedestal CFrames come from the Lobby the server built.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cubes = require(Shared.Defs.Cubes)
local Remotes = require(Shared.Remotes)

local CubeView = require(script.Parent.CubeView)

local Spectators = {}

local views: { [number]: CubeView.Api } = {}
local myIndex = 0

local function pedestalRoot(index: number): CFrame?
	local lobby = workspace:FindFirstChild("Lobby")
	local pedestal = if lobby then lobby:FindFirstChild(`Pedestal{index}`) else nil
	local column = if pedestal then pedestal:FindFirstChild("Column") else nil
	if not column or not column:IsA("BasePart") then
		return nil
	end
	-- The column is a cylinder lying along its X axis, rotated upright;
	-- rebuild the pedestal-top CFrame the way the server did.
	local base = Vector3.new(column.Position.X, 0, column.Position.Z)
	local outward = base.Unit
	local top = base + Vector3.new(0, Config.Lobby.PedestalHeight, 0)
	return CFrame.lookAt(top, top - outward) * CFrame.new(0, Config.Cube.Height, 0)
end

local function lookFor(cubeId: string): (Cubes.Look, string)
	local def = Cubes.get(cubeId) or (Cubes.get(Cubes.Default) :: Cubes.Def)
	return def.look, def.sound
end

local function ensure(index: number, cubeId: string): CubeView.Api?
	local existing = views[index]
	if existing then
		return existing
	end
	local root = pedestalRoot(index)
	if not root then
		return nil
	end
	local look = lookFor(cubeId)
	local view = CubeView.build(root, {
		name = `Spectator{index}`,
		look = look,
		silent = true,
		noArrow = true,
	})
	views[index] = view
	return view
end

local function remove(index: number)
	local view = views[index]
	if view then
		view.destroy()
		views[index] = nil
	end
end

--[[
	From Sync: which pedestal is ours, and what every other one looks like
	right now.
]]
function Spectators.set(ownIndex: number, others: { Remotes.Other })
	myIndex = ownIndex
	local seen: { [number]: boolean } = {}
	for _, other in others do
		seen[other.index] = true
		local view = ensure(other.index, other.cubeId)
		if view then
			local look = lookFor(other.cubeId)
			view.setLook(look)
			view.reset()
			for _, move in other.scramble do
				view.applyInstant(move)
			end
			for i = 1, other.step do
				view.applyInstant(other.solution[i])
			end
		end
	end
	for index, _ in views do
		if not seen[index] then
			remove(index)
		end
	end
end

function Spectators.start()
	local N = Remotes.Names
	Remotes.get(N.SpectateDeal).OnClientEvent:Connect(function(index: number, scramble: { string })
		if index == myIndex then
			return
		end
		local view = views[index]
		if not view then
			return
		end
		task.spawn(function()
			while view.isBusy() do
				task.wait(0.05)
			end
			view.reset()
			view.shuffle(scramble, function() end)
		end)
	end)
	Remotes.get(N.SpectateMove).OnClientEvent:Connect(function(index: number, move: string)
		if index == myIndex then
			return
		end
		local view = views[index]
		if view then
			view.turn(move)
		end
	end)
	Remotes.get(N.SpectatePop).OnClientEvent:Connect(function(index: number)
		if index == myIndex then
			return
		end
		local view = views[index]
		if view then
			task.spawn(function()
				while view.isBusy() do
					task.wait(0.02)
				end
				view.pop()
			end)
		end
	end)
	Remotes.get(N.SpectateLook).OnClientEvent:Connect(function(index: number, cubeId: string)
		if index == myIndex then
			return
		end
		local view = ensure(index, cubeId)
		if view then
			local look = lookFor(cubeId)
			view.setLook(look)
		end
	end)
	Remotes.get(N.SpectateLeave).OnClientEvent:Connect(function(index: number)
		remove(index)
	end)
end

return Spectators
