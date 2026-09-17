--!nocheck
--[[
	test-moves.luau -- proves the move maths without Studio.

	Loads the REAL Moves.luau under Lune with a tiny fake `game`, builds a
	26-cubie cube the same way CubeView does, and checks:
	  1. every move's inverse really undoes it (cube back to solved),
	  2. every generated scramble + its solution ends solved,
	  3. every move's prompt direction matches where the front row or
	     column actually goes (the "U moves the top row LEFT" claim).

	Run from the repo root:
	    ~/.rokit/bin/lune run tools/test-moves.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

--------------------------------------------------------------------------------
-- A Random that looks like Roblox's
--------------------------------------------------------------------------------

local Random = {}
Random.__index = Random
function Random.new(seed)
	local self = setmetatable({}, Random)
	self.state = (seed or 12345) % 2147483647
	if self.state <= 0 then
		self.state += 2147483646
	end
	return self
end
function Random:NextInteger(lo, hi)
	self.state = (self.state * 16807) % 2147483647
	return lo + (self.state % (hi - lo + 1))
end

--------------------------------------------------------------------------------
-- Load Moves.luau as Roblox would
--------------------------------------------------------------------------------

local source = fs.readFile("src/shared/Moves.luau")
local env = setmetatable({
	Vector3 = Vector3,
	CFrame = CFrame,
	math = math,
	table = table,
	string = string,
	type = type,
	assert = assert,
	error = error,
	print = print,
}, { __index = _G })
local Moves = luau.load(source, { environment = env })()

--------------------------------------------------------------------------------
-- A cube, the way CubeView keeps it
--------------------------------------------------------------------------------

local PITCH = 1.08

local function component(v, axis)
	if axis.X ~= 0 then
		return v.X
	elseif axis.Y ~= 0 then
		return v.Y
	end
	return v.Z
end

local function roundTo(n, step)
	return math.floor(n / step + 0.5) * step
end

local function unit(v)
	return Vector3.new(math.round(v.X), math.round(v.Y), math.round(v.Z))
end

local function snap(cf)
	local p = cf.Position
	local pos = Vector3.new(roundTo(p.X, PITCH), roundTo(p.Y, PITCH), roundTo(p.Z, PITCH))
	return CFrame.fromMatrix(pos, unit(cf.XVector), unit(cf.YVector), unit(cf.ZVector))
end

local function newCube()
	local cubies = {}
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					local home = CFrame.new(x * PITCH, y * PITCH, z * PITCH)
					table.insert(cubies, { home = home, cur = home })
				end
			end
		end
	end
	return cubies
end

local function apply(cubies, move)
	local def = Moves.get(move)
	assert(def, `unknown move {move}`)
	local rot = CFrame.fromAxisAngle(def.axis, def.angle)
	for _, c in cubies do
		if math.round(component(c.cur.Position, def.axis) / PITCH) == def.layer then
			c.cur = snap(rot * c.cur)
		end
	end
end

local function isSolved(cubies)
	for _, c in cubies do
		if (c.cur.Position - c.home.Position).Magnitude > 0.01 then
			return false
		end
		if (c.cur.XVector - Vector3.xAxis).Magnitude > 0.01 then
			return false
		end
		if (c.cur.YVector - Vector3.yAxis).Magnitude > 0.01 then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

local failures = 0
local function check(ok, text)
	if ok then
		print("  ok   " .. text)
	else
		failures += 1
		print("  FAIL " .. text)
	end
end

print("1. inverses")
for _, name in Moves.List do
	local cube = newCube()
	apply(cube, name)
	check(not isSolved(cube), `{name} changes the cube`)
	apply(cube, Moves.get(name).inverse)
	check(isSolved(cube), `{name} then {Moves.get(name).inverse} is solved`)
end

print("2. scramble + solution")
local rng = Random.new(7)
for depth = 1, 15 do
	local solution, scramble = Moves.generate(depth, rng)
	local cube = newCube()
	for _, m in scramble do
		apply(cube, m)
	end
	check(depth == 1 or not isSolved(cube), `depth {depth}: scrambled`)
	for _, m in solution do
		apply(cube, m)
	end
	check(isSolved(cube), `depth {depth}: solved after the solution`)
	for i = 2, #solution do
		check(
			Moves.get(solution[i]).face ~= Moves.get(solution[i - 1]).face,
			`depth {depth}: moves {i - 1},{i} on different faces`
		)
	end
end

print("3. prompt directions on the front face (+Z)")
-- Take the front-face cubie in the prompted row/column and see where it goes.
local expectedShift = {
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
	Up = Vector3.new(0, 1, 0),
	Down = Vector3.new(0, -1, 0),
}
for _, name in Moves.List do
	local def = Moves.get(name)
	local start
	if def.row then
		start = Vector3.new(0, def.row, 1) -- middle of that row, front face
	else
		start = Vector3.new(def.column, 0, 1)
	end
	local cube = newCube()
	local probe
	for _, c in cube do
		if (c.home.Position - start * PITCH).Magnitude < 0.01 then
			probe = c
		end
	end
	apply(cube, name)
	local moved = (probe.cur.Position - probe.home.Position) / PITCH
	-- The probe leaves the front face along the prompted direction: its
	-- shift has a positive dot with the arrow, and it is no longer at z=+1.
	local want = expectedShift[def.direction]
	check(
		moved:Dot(want) > 0.5 and math.abs(probe.cur.Position.Z) < 0.01,
		`{name}: arrow {def.direction}`
	)
end

print("")
if failures == 0 then
	print("all good")
else
	print(`{failures} failure(s)`)
	os.exit(1)
end
