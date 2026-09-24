--!strict
--[[
	SolveService.luau -- the game, from the server's side.

	For every player it keeps ONE deal (a scramble and the moves that undo
	it), the combo, and the clocks. The client sends the direction of each
	swipe; this file decides whether it was the right one, whether it was
	quick enough to be PERFECT, when the cube is solved, and what the solve
	pays. Coins, solves and best times only ever change here.

	Every swipe for the current deal gets an answer (MoveResult), even one
	that was ignored for arriving too fast or during a lockout. The client
	compares the answer's `step` with what it predicted and asks for a
	Sync when they differ, so the two screens never drift for more than a
	round trip. A swipe tagged with an old deal id is dropped silently:
	the Sync that replaced the deal already told the client.

	Every accepted move, every deal and every solve is also broadcast to
	ALL clients as a Spectate event with the pedestal index, so the other
	players' screens show this cube turning for real. Nothing a client
	sends can fake a turn on someone else's screen.

	What can a cheater do? Read the solution: the arrows show it anyway.
	Send swipes without looking: each is checked, a wrong one locks them
	out briefly, so guessing four directions is slower than playing. Send
	swipes faster than a human: the token bucket drops them, and a solve
	faster than MinHumanPerMove earns no speed bonus or best time. Skip
	sending wrong swipes: their combo does not break -- a cosmetic
	multiplier, capped, accepted for now.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cubes = require(Shared.Defs.Cubes)
local Moves = require(Shared.Moves)
local Remotes = require(Shared.Remotes)

local Arena = require(script.Parent.Parent.Arena)
local Leaderboard = require(script.Parent.Parent.Leaderboard)
local SaveService = require(script.Parent.SaveService)

type Deal = {
	id: number,
	depth: number,
	solution: { string },
	scramble: { string },
	step: number,
	startedAt: number?, -- os.clock at the first correct swipe
	lastMoveAt: number?, -- os.clock at the last correct swipe
	perfects: number,
	misses: number,
	sprint: boolean, -- the shared sprint cube: the dial is locked, SprintService is told
}

-- A preset deal: the sprint hands every player the SAME cube.
type Preset = {
	depth: number,
	solution: { string },
	scramble: { string },
}

--[[
	What SprintService wants to hear. Registered at start, so this file
	never requires SprintService (which requires this file).
]]
export type SprintHooks = {
	swipe: (player: Player, dealId: number) -> (),
	finish: (player: Player, dealId: number, seconds: number, depth: number) -> (),
	leave: (player: Player, pedestalIndex: number) -> (),
	-- Is this player's deal the LIVE sprint cube? Not the same as the
	-- deal's `sprint` flag, which stays true on a leftover cube after the
	-- race has resolved.
	live: (player: Player, dealId: number) -> boolean,
	state: (player: Player) -> Remotes.SprintState,
}

type State = {
	player: Player,
	pedestalIndex: number,
	pedestal: CFrame,
	deal: Deal?,
	combo: number,
	lockedUntil: number, -- after a wrong swipe
	lastInputAt: number, -- for the token bucket
	burst: number, -- tokens left in the bucket
	dealCounter: number,
	popping: boolean, -- between a solve and the next deal
	leaderstats: { coins: IntValue, solves: IntValue, best: StringValue },
}

local SolveService = {}

local states: { [Player]: State } = {}
local pedestals: { CFrame } = {}
local taken: { [number]: Player? } = {}
local rng = Random.new()
local sprint: SprintHooks? = nil

local N = Remotes.Names

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function unlockedDepth(solves: number): number
	return math.min(
		Config.Depth.Max,
		Config.Depth.Start + math.floor(solves / Config.Depth.SolvesPerUnlock)
	)
end

local function comboMult(combo: number): number
	return math.min(Config.Combo.MaxMult, 1 + Config.Combo.MultPerCombo * combo)
end

local function formatSeconds(seconds: number): string
	return string.format("%.2fs", seconds)
end

local function toast(player: Player, kind: string, text: string)
	Remotes.get(N.Toast):FireClient(player, kind, text)
end

local function dialDepth(data: SaveService.PlayerData): number
	return math.clamp(data.depth, Config.Depth.Min, unlockedDepth(data.solves))
end

local function updateLeaderstats(state: State, data: SaveService.PlayerData)
	state.leaderstats.coins.Value = data.coins
	state.leaderstats.solves.Value = data.solves
	local depth = dialDepth(data)
	local best = data.best[tostring(depth)]
	state.leaderstats.best.Value = if best then `{formatSeconds(best)} @{depth}` else "-"
	-- And on their own mat, for them: the same figure the HUD shows.
	Arena.setStationBest(
		state.pedestalIndex,
		if best then `BEST {formatSeconds(best)}` else "" -- short: it hides behind the cube from the owner's seat
	)
end

--[[
	The spam guard: a small bucket that refills at one token per MinMoveGap
	and holds BurstMoves. Two honest swipes that bunch up in transit both
	get through; a stream faster than a human does not.
]]
local function takeToken(state: State, now: number): boolean
	state.burst = math.min(
		Config.Timing.BurstMoves,
		state.burst + (now - state.lastInputAt) / Config.Timing.MinMoveGap
	)
	state.lastInputAt = now
	if state.burst < 1 then
		return false
	end
	state.burst -= 1
	return true
end

local function spectate(name: string, index: number, ...: any)
	Remotes.get(name):FireAllClients(index, ...)
end

--------------------------------------------------------------------------------
-- Sync: everything the client needs to draw
--------------------------------------------------------------------------------

local function othersFor(player: Player): { Remotes.Other }
	local out: { Remotes.Other } = {}
	for other, state in states do
		if other ~= player then
			local data = SaveService.get(other)
			local deal = state.deal
			table.insert(out, {
				index = state.pedestalIndex,
				pedestal = state.pedestal,
				cubeId = if data then data.equipped else Cubes.Default,
				dealId = if deal then deal.id else 0,
				scramble = if deal then deal.scramble else {},
				solution = if deal then deal.solution else {},
				step = if deal then deal.step else 0,
			})
		end
	end
	return out
end

function SolveService.sync(player: Player)
	local state = states[player]
	local data = SaveService.get(player)
	if not state or not data then
		return
	end
	local depth = dialDepth(data)
	local deal = state.deal
	local payload: Remotes.SyncState = {
		coins = data.coins,
		solves = data.solves,
		best = data.best[tostring(depth)] or 0,
		depth = depth,
		unlockedDepth = unlockedDepth(data.solves),
		combo = state.combo,
		pedestal = state.pedestal,
		pedestalIndex = state.pedestalIndex,
		deal = if deal
			then {
				id = deal.id,
				depth = deal.depth,
				scramble = deal.scramble,
				solution = deal.solution,
				step = deal.step,
			}
			else nil,
		cubes = data.cubes,
		equipped = data.equipped,
		others = othersFor(player),
		sprint = if sprint
			then sprint.state(player)
			else { phase = "off", seconds = 0, inRace = false },
	}
	Remotes.get(N.Sync):FireClient(player, payload)
end

--------------------------------------------------------------------------------
-- Dealing
--------------------------------------------------------------------------------

--[[
	A fresh cube at the dial depth -- or, with `preset`, the sprint's
	shared cube, which ignores the dial and locks it.
]]
local function deal(state: State, preset: Preset?): number?
	local data = SaveService.get(state.player)
	if not data then
		return nil
	end
	local depth = if preset then preset.depth else dialDepth(data)
	local solution, scramble
	if preset then
		solution, scramble = preset.solution, preset.scramble
	else
		solution, scramble = Moves.generate(depth, rng)
	end
	state.dealCounter += 1
	state.deal = {
		id = state.dealCounter,
		depth = depth,
		solution = solution,
		scramble = scramble,
		step = 0,
		startedAt = nil,
		lastMoveAt = nil,
		perfects = 0,
		misses = 0,
		sprint = preset ~= nil,
	}
	state.popping = false
	SolveService.sync(state.player)
	spectate(N.SpectateDeal, state.pedestalIndex, state.dealCounter, scramble)
	return state.dealCounter
end

--[[
	GO: one scramble, dealt to every seated player at once, replacing
	whatever they were on (the countdown was their warning). Returns each
	player's new deal id, which is how SprintService tells a sprint pop
	from any other. Every racer's deal shares the same solution and
	scramble tables; nothing mutates them, and nothing may.
]]
function SolveService.dealAll(depth: number): { [Player]: number }
	local solution, scramble = Moves.generate(depth, rng)
	local preset: Preset = { depth = depth, solution = solution, scramble = scramble }
	local ids: { [Player]: number } = {}
	for player, state in states do
		local id = deal(state, preset)
		if id then
			ids[player] = id
		end
	end
	return ids
end

-- Coins outside a solve (the sprint's win bonus). Flat: no multipliers.
function SolveService.award(player: Player, coins: number)
	local state = states[player]
	local data = SaveService.get(player)
	if not state or not data then
		return
	end
	data.coins += coins
	updateLeaderstats(state, data)
	SolveService.sync(player)
end

function SolveService.setSprintHooks(hooks: SprintHooks)
	sprint = hooks
end

local function finish(state: State, current: Deal)
	local player = state.player
	local data = SaveService.get(player)
	if not data then
		return
	end
	local now = os.clock()
	local seconds = math.max(0, now - (current.startedAt or now))
	-- Faster than any human is a script (or a one-move deal, which is
	-- timed as zero); it earns the base coins but no speed bonus or best.
	local plausible = current.depth == 1 or seconds >= Config.Timing.MinHumanPerMove * current.depth
	local fast = plausible and seconds <= Config.Coins.ParPerMove * current.depth
	local cubeMult = math.min(Config.Boxes.MaxMult, Cubes.multOf(data.equipped))
	local mult = comboMult(state.combo) * cubeMult
	local raw = Config.Coins.PerMove * current.depth
		+ Config.Coins.SolveBonus
		+ (if fast then Config.Coins.SpeedBonus else 0)
		+ Config.Coins.PerfectBonus * current.perfects
	local coins = math.floor(raw * mult + 0.5)

	local key = tostring(current.depth)
	local previousBest = data.best[key]
	local isBest = plausible and (previousBest == nil or seconds < previousBest)
	if isBest then
		data.best[key] = seconds
	end
	if plausible then
		Leaderboard.recordSolve(player.Name, current.depth, seconds)
	end

	local unlockedBefore = unlockedDepth(data.solves)
	data.coins += coins
	data.solves += 1
	local unlockedAfter = unlockedDepth(data.solves)
	if unlockedAfter > unlockedBefore then
		toast(player, "big", `Depth {unlockedAfter} unlocked!`)
	end
	updateLeaderstats(state, data)

	local result: Remotes.SolveResult = {
		coins = coins,
		seconds = seconds,
		isBest = isBest,
		combo = state.combo,
		mult = mult,
		cubeMult = cubeMult,
		perfects = current.perfects,
		fast = fast,
	}
	Remotes.get(N.Solved):FireClient(player, result)
	spectate(N.SpectatePop, state.pedestalIndex)

	-- A sprint pop: SprintService decides whether it won. It gets the
	-- server's own seconds; the sprint has its own, stricter, human floor.
	if sprint and current.sprint then
		sprint.finish(player, current.id, seconds, current.depth)
	end

	state.popping = true
	task.delay(Config.Timing.PopSeconds, function()
		if states[player] == state and state.deal == current then
			deal(state)
		end
	end)
end

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------

local function onMove(player: Player, direction: any, dealId: any, seq: any)
	local state = states[player]
	if not state or not Moves.isDirection(direction) then
		return
	end
	if type(dealId) ~= "number" or type(seq) ~= "number" then
		return
	end
	local current = state.deal
	if not current or current.id ~= dealId or state.popping then
		return -- an old deal: the Sync that replaced it already said so
	end

	local function reply(ok: boolean, ignored: boolean, perfect: boolean)
		local result: Remotes.MoveResult = {
			ok = ok,
			ignored = ignored,
			perfect = perfect,
			step = current.step,
			combo = state.combo,
			dealId = current.id,
			seq = seq,
		}
		Remotes.get(N.MoveResult):FireClient(player, result)
	end

	local now = os.clock()
	if now < state.lockedUntil or not takeToken(state, now) then
		reply(false, true, false) -- heard, not judged
		return
	end

	local expected = Moves.get(current.solution[current.step + 1])
	if not expected then
		reply(false, true, false)
		return
	end

	if expected.direction == direction then
		local perfect = current.lastMoveAt ~= nil
			and now - (current.lastMoveAt :: number) <= Config.Timing.PerfectGap
		if current.step == 0 then
			current.startedAt = now
		end
		current.lastMoveAt = now
		current.step += 1
		state.combo += 1
		if perfect then
			current.perfects += 1
		end
		reply(true, false, perfect)
		spectate(N.SpectateMove, state.pedestalIndex, expected.name)
		if sprint and current.sprint then
			sprint.swipe(player, current.id) -- "a win needs a race": this is the proof
		end
		if current.step >= current.depth then
			finish(state, current)
		end
	else
		state.combo = 0
		current.misses += 1
		-- Shorter than the client's lock by LockSlack, so the first honest
		-- swipe after the client unlocks is never ignored by a slower server.
		state.lockedUntil = now + Config.Timing.WrongLockSeconds - Config.Timing.LockSlack
		reply(false, false, false)
	end
end

local function onSetDepth(player: Player, delta: any)
	local state = states[player]
	local data = SaveService.get(player)
	if not state or not data or (delta ~= 1 and delta ~= -1) then
		return
	end
	-- The dial is locked while their cube is the LIVE sprint cube: turning
	-- it would redeal a normal cube over the shared one and silently drop
	-- them out of the race (see the "nothing started yet" redeal below).
	-- Once the race resolves a leftover sprint cube is a normal deal and
	-- the dial works again.
	local live = state.deal
	if live and sprint and sprint.live(player, live.id) and not state.popping then
		toast(player, "info", "The dial is locked during a sprint")
		return
	end
	local ceiling = unlockedDepth(data.solves)
	local wanted = math.clamp(dialDepth(data) + delta, Config.Depth.Min, ceiling)
	if wanted == dialDepth(data) then
		if delta == 1 and ceiling < Config.Depth.Max then
			local need = (math.floor(data.solves / Config.Depth.SolvesPerUnlock) + 1)
				* Config.Depth.SolvesPerUnlock
			toast(player, "info", `Depth {ceiling + 1} unlocks at {need} solves`)
		end
		return
	end
	data.depth = wanted
	updateLeaderstats(state, data)
	local current = state.deal
	if current and current.step == 0 and not state.popping then
		deal(state) -- nothing started yet: redeal at the new depth right away
	else
		SolveService.sync(player) -- the next deal will use it
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function SolveService.init(pedestalFrames: { CFrame })
	pedestals = pedestalFrames
end

function SolveService.start()
	Remotes.get(N.Move).OnServerEvent:Connect(onMove)
	Remotes.get(N.SetDepth).OnServerEvent:Connect(onSetDepth)
end

--[[
	Give the player a pedestal and their first deal. Returns false when the
	ring is full (the caller kicks politely).
]]
function SolveService.join(player: Player): boolean
	local data = SaveService.get(player)
	if not data or states[player] then
		return states[player] ~= nil
	end
	local index: number? = nil
	for i = 1, #pedestals do
		if not taken[i] then
			index = i
			break
		end
	end
	if not index then
		return false
	end
	taken[index] = player

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = folder
	local solves = Instance.new("IntValue")
	solves.Name = "Solves"
	solves.Parent = folder
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Parent = folder
	folder.Parent = player

	local state: State = {
		player = player,
		pedestalIndex = index,
		pedestal = pedestals[index],
		deal = nil,
		combo = 0,
		lockedUntil = 0,
		lastInputAt = os.clock(),
		burst = Config.Timing.BurstMoves,
		dealCounter = 0,
		popping = false,
		leaderstats = { coins = coins, solves = solves, best = best },
	}
	states[player] = state
	updateLeaderstats(state, data)
	spectate(N.SpectateLook, index, data.equipped, state.pedestal)
	-- Light their plinth in the tier of whatever they had on when they left
	-- last time, so a station never sits in the house colour with a
	-- Legendary standing on it.
	local equipped = Cubes.get(data.equipped)
	Arena.setStationTier(index, equipped and equipped.tier)
	deal(state)
	return true
end

function SolveService.leave(player: Player)
	local state = states[player]
	if not state then
		return
	end
	taken[state.pedestalIndex] = nil
	states[player] = nil
	spectate(N.SpectateLeave, state.pedestalIndex)
	-- The crown comes off FIRST (it sits above the tint and would otherwise
	-- swallow the reset), then back to the house colour: an empty station
	-- must not keep advertising the Legendary of whoever was sitting there.
	if sprint then
		sprint.leave(player, state.pedestalIndex)
	end
	Arena.setStationTier(state.pedestalIndex, nil)
	Arena.setStationBest(state.pedestalIndex, "")
end

function SolveService.pedestalFor(player: Player): CFrame?
	local state = states[player]
	return if state then state.pedestal else nil
end

function SolveService.pedestalIndexFor(player: Player): number?
	local state = states[player]
	return if state then state.pedestalIndex else nil
end

-- For the join sequence: is there anyone this pedestal belongs to?
function SolveService.isJoined(player: Player): boolean
	return states[player] ~= nil
end

return SolveService
