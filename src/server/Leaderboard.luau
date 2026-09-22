--!strict
--[[
	Leaderboard.luau -- this server's records: kept correctly, shown nowhere.

	The CEO pulled the records board (2026-09-22). Every way of putting ONE
	number on a wall was gameable: a solve's time runs from first swipe to
	last, so a depth-3 solve is three swipes and always "beats" a depth-15
	one, and whoever dials down owns the board. Not a security hole -- the
	server owns every time and `plausible` gates recordSolve -- but a wrong
	incentive, which is worse in a game that wants you to go deeper.

	The records are still kept, per depth, because they are cheap and the
	next competition feature (M3 sprints: one scramble for the whole lobby,
	first pop wins, a crown on the station) will want them. A hoarding in
	Config.Arena.Barrier.Texts carrying Config.Board.Marker becomes a board
	and gets the deepest depth's best written into it; none does today, and
	that is deliberate, so build() finding nothing is not a warning.

	Nothing here is saved: a server's records live as long as the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Leaderboard = {}

type Record = { name: string, seconds: number, depth: number }

local bests: { [number]: Record } = {} -- by depth
local solves: { [string]: number } = {}
local boards: { { time: TextLabel, sub: TextLabel } } = {}

-- The deepest depth anyone has solved on this server, and its best time:
-- the one number that does not reward dialling down. Still not shown.
local function headline(): Record?
	local pick: Record? = nil
	for _, record in bests do
		if not pick or record.depth > pick.depth then
			pick = record
		end
	end
	return pick
end

local function render()
	if #boards == 0 then
		return
	end
	local best = headline()
	local time = if best then string.format("%.2fs", best.seconds) else "--"
	local sub = if best then `depth {best.depth}  ·  {best.name}` else "no solves yet"
	for _, board in boards do
		board.time.Text = time
		board.sub.Text = sub
	end
end

--[[
	`parent` is the Lobby folder. Arena builds any panels; this only finds
	them, and finding none is the current, intended state.
]]
function Leaderboard.build(parent: Instance)
	table.clear(boards)
	for _, d in parent:GetDescendants() do
		if d:IsA("SurfaceGui") and d.Name == "Records" then
			local panel = d:FindFirstChild("Panel")
			local time = panel and panel:FindFirstChild("Time")
			local sub = panel and panel:FindFirstChild("Sub")
			if time and time:IsA("TextLabel") and sub and sub:IsA("TextLabel") then
				table.insert(boards, { time = time, sub = sub })
			end
		end
	end
	render()
end

function Leaderboard.recordSolve(name: string, depth: number, seconds: number)
	local current = bests[depth]
	if not current or seconds < current.seconds then
		bests[depth] = { name = name, seconds = seconds, depth = depth }
	end
	solves[name] = (solves[name] or 0) + 1
	render()
end

--[[
	For whatever shows records next (a sprint crown, a HUD table): the
	best per depth, deepest first, and the solve counts.
]]
function Leaderboard.snapshot(): ({ Record }, { [string]: number })
	local list: { Record } = {}
	for _, record in bests do
		table.insert(list, record)
	end
	table.sort(list, function(a, b)
		return a.depth > b.depth
	end)
	return list, table.clone(solves)
end

return Leaderboard
