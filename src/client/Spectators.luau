--!strict
--[[
	Spectators.luau -- the other players' cubes.

	One silent, arrow-less CubeView per occupied pedestal other than our
	own, standing on that pedestal (the server sends its CFrame) and
	wearing that player's equipped cube. The server tells every client
	what happens on every pedestal (Spectate events); this file applies
	them. On join, Sync carries the current state of each pedestal so the
	copies start in step.

	Sync seeds, events drive, the deal id arbitrates: a Sync that names a
	deal this screen has already drawn is a no-op, so a spectator cube is
	never redrawn under a running animation. Redraws wait for the cube to
	be idle, and give up if the cube has been replaced meanwhile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cubes = require(Shared.Defs.Cubes)
local Remotes = require(Shared.Remotes)

local CubeView = require(script.Parent.CubeView)

local Spectators = {}

local views: { [number]: CubeView.Api } = {}
local known: { [number]: number } = {} -- pedestal index -> deal id drawn
local myIndex = 0

local function lookFor(cubeId: string): Cubes.Look
	local def = Cubes.get(cubeId) or (Cubes.get(Cubes.Default) :: Cubes.Def)
	return def.look
end

local function ensure(index: number, cubeId: string, pedestal: CFrame): CubeView.Api
	local existing = views[index]
	if existing then
		return existing
	end
	local view = CubeView.build(pedestal * CFrame.new(0, Config.Cube.Height, 0), {
		name = `Spectator{index}`,
		look = lookFor(cubeId),
		silent = true,
		noArrow = true,
	})
	views[index] = view
	known[index] = 0
	return view
end

local function remove(index: number)
	local view = views[index]
	if view then
		view.destroy()
		views[index] = nil
		known[index] = nil
	end
end

-- Wait for the cube to be idle, then run `fn`; skip if the cube is gone.
local function whenIdle(index: number, view: CubeView.Api, fn: () -> ())
	task.spawn(function()
		while views[index] == view and view.isBusy() do
			task.wait(0.05)
		end
		if views[index] == view then
			fn()
		end
	end)
end

local function redraw(index: number, view: CubeView.Api, other: Remotes.Other)
	whenIdle(index, view, function()
		view.reset()
		for _, move in other.scramble do
			view.applyInstant(move)
		end
		for i = 1, other.step do
			view.applyInstant(other.solution[i])
		end
	end)
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
		local view = ensure(other.index, other.cubeId, other.pedestal)
		view.setLook(lookFor(other.cubeId))
		if known[other.index] ~= other.dealId then
			known[other.index] = other.dealId
			redraw(other.index, view, other)
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
	Remotes.get(N.SpectateDeal).OnClientEvent
		:Connect(function(index: number, dealId: number, scramble: { string })
			if index == myIndex then
				return
			end
			local view = views[index]
			if not view then
				return
			end
			known[index] = dealId
			whenIdle(index, view, function()
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
			whenIdle(index, view, function()
				view.pop()
			end)
		end
	end)
	Remotes.get(N.SpectateLook).OnClientEvent
		:Connect(function(index: number, cubeId: string, pedestal: CFrame)
			if index == myIndex then
				return
			end
			local view = ensure(index, cubeId, pedestal)
			view.setLook(lookFor(cubeId))
		end)
	Remotes.get(N.SpectateLeave).OnClientEvent:Connect(function(index: number)
		remove(index)
	end)
end

return Spectators
