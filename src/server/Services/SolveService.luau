--!strict
--[[
	SolveService.luau -- the game, from the server's side.

	For every player it keeps ONE deal (a scramble and the moves that undo
	it), the combo, and the clocks. The client sends the direction of each
	swipe; this file decides whether it was the right one, whether it was
	quick enough to be PERFECT, when the cube is solved, and what the solve
	pays. Coins, solves and best times only ever change here.

	The player's cube on their screen is drawn by the client from the same
	deal; if the two ever disagree (a dropped packet, a tampered client)
	the next Sync wins and the client redraws.

	What can a cheater do? Read the solution: the arrows show it anyway.
	Send swipes without looking: each is checked, a wrong one locks them
	out briefly, so guessing four directions is slower than playing. Send
	swipes faster than a human: the spam guard drops them. Skip sending
	wrong swipes: their combo does not break -- a cosmetic multiplier,
	capped, accepted for now.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Moves = require(Shared.Moves)
local Remotes = require(Shared.Remotes)

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
}

type State = {
	player: Player,
	pedestalIndex: number,
	pedestal: CFrame,
	deal: Deal?,
	combo: number,
	lockedUntil: number, -- after a wrong swipe
	lastInputAt: number, -- spam guard
	dealCounter: number,
	popping: boolean, -- between a solve and the next deal
	leaderstats: { coins: IntValue, solves: IntValue, best: StringValue },
}

local SolveService = {}

local states: { [Player]: State } = {}
local pedestals: { CFrame } = {}
local taken: { [number]: Player? } = {}
local rng = Random.new()

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
end

--------------------------------------------------------------------------------
-- Sync: everything the client needs to draw
--------------------------------------------------------------------------------

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
	}
	Remotes.get(N.Sync):FireClient(player, payload)
end

--------------------------------------------------------------------------------
-- Dealing
--------------------------------------------------------------------------------

local function deal(state: State)
	local data = SaveService.get(state.player)
	if not data then
		return
	end
	local depth = dialDepth(data)
	local solution, scramble = Moves.generate(depth, rng)
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
	}
	state.popping = false
	SolveService.sync(state.player)
end

local function finish(state: State, current: Deal)
	local player = state.player
	local data = SaveService.get(player)
	if not data then
		return
	end
	local now = os.clock()
	local seconds = math.max(0, now - (current.startedAt or now))
	local fast = seconds <= Config.Coins.ParPerMove * current.depth
	local mult = comboMult(state.combo)
	local raw = Config.Coins.PerMove * current.depth
		+ Config.Coins.SolveBonus
		+ (if fast then Config.Coins.SpeedBonus else 0)
		+ Config.Coins.PerfectBonus * current.perfects
	local coins = math.floor(raw * mult + 0.5)

	local key = tostring(current.depth)
	local previousBest = data.best[key]
	local isBest = previousBest == nil or seconds < previousBest
	if isBest then
		data.best[key] = seconds
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
		perfects = current.perfects,
		fast = fast,
	}
	Remotes.get(N.Solved):FireClient(player, result)

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

local function onMove(player: Player, direction: any)
	local state = states[player]
	if not state or not Moves.isDirection(direction) then
		return
	end
	local current = state.deal
	if not current or state.popping then
		return
	end
	local now = os.clock()
	if now < state.lockedUntil or now - state.lastInputAt < Config.Timing.MinMoveGap then
		return
	end
	state.lastInputAt = now

	local expected = Moves.get(current.solution[current.step + 1])
	if not expected then
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
		local result: Remotes.MoveResult = {
			ok = true,
			step = current.step,
			combo = state.combo,
			perfect = perfect,
		}
		Remotes.get(N.MoveResult):FireClient(player, result)
		if current.step >= current.depth then
			finish(state, current)
		end
	else
		state.combo = 0
		current.misses += 1
		state.lockedUntil = now + Config.Timing.WrongLockSeconds
		local result: Remotes.MoveResult = {
			ok = false,
			step = current.step,
			combo = 0,
			perfect = false,
		}
		Remotes.get(N.MoveResult):FireClient(player, result)
	end
end

local function onSetDepth(player: Player, delta: any)
	local state = states[player]
	local data = SaveService.get(player)
	if not state or not data or (delta ~= 1 and delta ~= -1) then
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
		lastInputAt = 0,
		dealCounter = 0,
		popping = false,
		leaderstats = { coins = coins, solves = solves, best = best },
	}
	states[player] = state
	updateLeaderstats(state, data)
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
end

function SolveService.pedestalFor(player: Player): CFrame?
	local state = states[player]
	return if state then state.pedestal else nil
end

-- For the join sequence: is there anyone this pedestal belongs to?
function SolveService.isJoined(player: Player): boolean
	return states[player] ~= nil
end

return SolveService
