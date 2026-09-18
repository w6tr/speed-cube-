--!strict
--[[
	Leaderboard.luau -- this server's records, shown on the hoardings.

	It used to be a pillar in the MIDDLE of the ring. That was wrong twice
	over: every camera looks across the centre, so the pillar stood behind
	the cube from all eight seats -- its text printed over the HUD, and its
	bulk hid the thing DESIGN.md calls a feature, watching other players'
	cubes turn across the ring. The middle is empty now.

	The records live on the barrier hoardings instead, where a real
	competition puts them. Arena.luau builds the panels (any hoarding whose
	text is `Config.Board.Marker`); this file only writes numbers into
	them. Several sit round the ring, so one is always in shot.

	A hoarding is read from about fifty studs, so a board says ONE thing
	big -- the fastest solve on this server -- with a quiet line under it.
	The full table belongs in the HUD, where a player can actually read it.

	Server-side text on a SurfaceGui replicates on its own; the client does
	nothing. Nothing here is saved: a server's records live as long as the
	server. The global weekly board is M3.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Leaderboard = {}

type Record = { name: string, seconds: number, depth: number }

local best: Record? = nil
local solves: { [string]: number } = {}
local boards: { { time: TextLabel, sub: TextLabel } } = {}

local function topSolver(): (string?, number)
	local who: string? = nil
	local most = 0
	for name, count in solves do
		if count > most then
			who, most = name, count
		end
	end
	return who, most
end

local function render()
	local time, sub
	if best then
		time = string.format("%.2fs", best.seconds)
		sub = `depth {best.depth}  ·  {best.name}`
	else
		time = "--"
		sub = "no solves yet"
	end

	-- A server where somebody has stacked up forty solves should say so,
	-- but the record is still the headline.
	local who, count = topSolver()
	if who and count > 1 then
		sub = `{sub}   ·   {count} by {who}`
	end

	for _, board in boards do
		board.time.Text = time
		board.sub.Text = sub
	end
end

--[[
	`parent` is the Lobby folder. Arena has already built the panels, so
	this only has to find them.
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
	if #boards == 0 then
		warn(
			`[Leaderboard] no records boards found -- is "{Config.Board.Marker}" still in `
				.. "Config.Arena.Barrier.Texts, and does Arena build before this?"
		)
	end
	render()
end

function Leaderboard.recordSolve(name: string, depth: number, seconds: number)
	if not best or seconds < best.seconds then
		best = { name = name, seconds = seconds, depth = depth }
	end
	solves[name] = (solves[name] or 0) + 1
	render()
end

return Leaderboard
