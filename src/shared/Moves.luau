--!strict
--[[
	Moves.luau -- the eight turns the game uses, and the maths behind them.

	A 3x3 cube has six faces. Standard notation names a clockwise quarter
	turn of a face by its letter (U up, D down, L left, R right, F front,
	B back) and the anticlockwise turn with a prime (U'). This game prompts
	every turn as a SWIPE ON THE FRONT FACE, and a swipe on the front face
	can only turn the layers that cross it: the top row (U), the bottom row
	(D), the left column (L) and the right column (R). F and B would need a
	swipe on a different face, so they are not used.

	The cube is laid out in "cube space": +X right, +Y up, +Z toward the
	camera (the front face). Rotations follow the right-hand rule, so a
	clockwise turn seen from a face is a NEGATIVE angle about that face's
	outward axis.

	Direction check, worked once so nobody has to redo it: U is -90 degrees
	about +Y; the front-top cubie at (0, 1, 1) lands at (-1, 1, 0), on the
	left face. So U moves the top row LEFT, and the prompt for U is a left
	arrow on the top row.
]]

local Moves = {}

export type Direction = "Up" | "Down" | "Left" | "Right"

export type Def = {
	name: string,
	face: string, -- U D L R
	axis: Vector3, -- rotation axis (unit)
	layer: number, -- which layer along that axis: +1 or -1
	angle: number, -- radians, sign per the right-hand rule
	direction: Direction, -- the swipe on the front face that performs it
	inverse: string,
	-- where the arrow prompt sits on the front face
	row: number?, -- +1 top row, -1 bottom row (horizontal swipes)
	column: number?, -- -1 left column, +1 right column (vertical swipes)
}

local Q = math.pi / 2

local DEFS: { [string]: Def } = {
	["U"] = {
		name = "U",
		face = "U",
		axis = Vector3.yAxis,
		layer = 1,
		angle = -Q,
		direction = "Left",
		inverse = "U'",
		row = 1,
	},
	["U'"] = {
		name = "U'",
		face = "U",
		axis = Vector3.yAxis,
		layer = 1,
		angle = Q,
		direction = "Right",
		inverse = "U",
		row = 1,
	},
	["D"] = {
		name = "D",
		face = "D",
		axis = Vector3.yAxis,
		layer = -1,
		angle = Q,
		direction = "Right",
		inverse = "D'",
		row = -1,
	},
	["D'"] = {
		name = "D'",
		face = "D",
		axis = Vector3.yAxis,
		layer = -1,
		angle = -Q,
		direction = "Left",
		inverse = "D",
		row = -1,
	},
	["R"] = {
		name = "R",
		face = "R",
		axis = Vector3.xAxis,
		layer = 1,
		angle = -Q,
		direction = "Up",
		inverse = "R'",
		column = 1,
	},
	["R'"] = {
		name = "R'",
		face = "R",
		axis = Vector3.xAxis,
		layer = 1,
		angle = Q,
		direction = "Down",
		inverse = "R",
		column = 1,
	},
	["L"] = {
		name = "L",
		face = "L",
		axis = Vector3.xAxis,
		layer = -1,
		angle = Q,
		direction = "Down",
		inverse = "L'",
		column = -1,
	},
	["L'"] = {
		name = "L'",
		face = "L",
		axis = Vector3.xAxis,
		layer = -1,
		angle = -Q,
		direction = "Up",
		inverse = "L",
		column = -1,
	},
}

Moves.List = { "U", "U'", "D", "D'", "L", "L'", "R", "R'" }
Moves.Directions = { Up = true, Down = true, Left = true, Right = true }

function Moves.get(name: string): Def?
	return DEFS[name]
end

function Moves.isDirection(value: any): boolean
	return type(value) == "string" and Moves.Directions[value] == true
end

--[[
	Make a solution of `depth` moves and the scramble that sets it up.
	The scramble is the solution played backwards with every move inverted,
	so a solved cube scrambled by it is exactly `depth` prompted swipes from
	solved again. Two moves on the same face never follow each other, so
	every prompt is a visibly different layer.
]]
function Moves.generate(depth: number, rng: Random): ({ string }, { string })
	local solution: { string } = {}
	local lastFace = ""
	for _ = 1, depth do
		local name: string
		repeat
			name = Moves.List[rng:NextInteger(1, #Moves.List)]
		until DEFS[name].face ~= lastFace
		lastFace = DEFS[name].face
		table.insert(solution, name)
	end
	local scramble: { string } = {}
	for i = depth, 1, -1 do
		table.insert(scramble, DEFS[solution[i]].inverse)
	end
	return solution, scramble
end

return Moves
