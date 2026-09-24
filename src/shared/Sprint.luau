--!strict
--[[
	Sprint.luau -- the sprint's rules, as a pure state machine.

	One scramble for the whole lobby, first pop wins, the winner's station
	is lit until the next sprint resolves. Everything that DECIDES lives
	here and touches nothing in Roblox: the clock is passed in, players are
	opaque keys, and the caller (SprintService) turns the events this
	returns into deals, toasts, remotes and part colours. That is what lets
	tools/test-sprint.luau drive every edge case in DESIGN-M3.md without an
	engine.

	Phases:
	  off        fewer than MinPlayers joined; nothing announced
	  idle       waiting for the next countdown (at = when it starts)
	  countdown  the 15 seconds before GO (at = GO)
	  racing     the shared deal is live (at = the cap)

	A win needs a race: the pop only counts if some OTHER player has made a
	correct swipe on the sprint deal. Otherwise an idle second account is
	enough to "win" every sprint on a server.
]]

local Sprint = {}

export type Config = {
	Every: number, -- seconds between sprints (idle length)
	Countdown: number,
	Seconds: number, -- the cap: racing ends with no winner after this
	Depth: number,
	MinPlayers: number,
	MinHumanPerMove: number, -- a sprint pop faster than this per move cannot win
}

export type Phase = "off" | "idle" | "countdown" | "racing"

export type State = {
	phase: Phase,
	at: number, -- when the current phase ends, on the caller's clock
	dealIds: { [any]: number }, -- player -> their sprint deal id, while racing
	swiped: { [any]: boolean }, -- players with a correct swipe on the sprint deal
	winner: any?, -- this sprint's winner, while racing / just after
	crown: any?, -- who is lit right now
}

export type Event = {
	kind: "off" | "idle" | "countdown" | "go" | "cancel" | "nobody",
	seconds: number, -- how long the new phase lasts (0 for cancel / off)
	crown: any?, -- nobody: the crown that was just cleared, if any
}

export type Verdict = "won" | "not-racing" | "wrong-deal" | "too-fast" | "no-race"

function Sprint.new(): State
	return { phase = "off", at = 0, dealIds = {}, swiped = {}, winner = nil, crown = nil }
end

local function enter(s: State, phase: Phase, now: number, seconds: number): Event
	s.phase = phase
	s.at = now + seconds
	return { kind = phase :: any, seconds = seconds, crown = nil }
end

--[[
	Advance the clock. Returns the events the caller has to act on, in
	order. `joined` is how many players are seated right now.
]]
function Sprint.tick(s: State, cfg: Config, now: number, joined: number): { Event }
	local events: { Event } = {}

	if s.phase == "off" then
		if joined >= cfg.MinPlayers then
			table.insert(events, enter(s, "idle", now, cfg.Every))
		end
	elseif s.phase == "idle" then
		if joined < cfg.MinPlayers then
			table.insert(events, enter(s, "off", now, 0))
		elseif now >= s.at then
			table.insert(events, enter(s, "countdown", now, cfg.Countdown))
		end
	elseif s.phase == "countdown" then
		if joined < cfg.MinPlayers then
			table.insert(events, { kind = "cancel", seconds = 0, crown = nil })
			table.insert(events, enter(s, "idle", now, cfg.Every))
		elseif now >= s.at then
			table.clear(s.dealIds)
			table.clear(s.swiped)
			s.winner = nil
			local go = enter(s, "racing", now, cfg.Seconds)
			go.kind = "go"
			table.insert(events, go)
		end
	elseif s.phase == "racing" then
		if now >= s.at then
			-- Nobody popped: the previous light comes off, so a lit station
			-- always means "won the LAST sprint".
			table.insert(events, { kind = "nobody", seconds = 0, crown = s.crown })
			s.crown = nil
			table.insert(events, enter(s, "idle", now, cfg.Every))
		end
	end

	return events
end

-- After a "go" event the caller deals the shared cube and reports the ids.
function Sprint.dealt(s: State, dealIds: { [any]: number })
	s.dealIds = dealIds
end

function Sprint.swipe(s: State, key: any, dealId: number)
	if s.phase == "racing" and s.dealIds[key] == dealId then
		s.swiped[key] = true
	end
end

-- Is this player's deal the live sprint cube? The dial lock and the HUD
-- both ask this, and the answer changes the moment the race resolves.
function Sprint.live(s: State, key: any, dealId: number): boolean
	return s.phase == "racing" and s.dealIds[key] == dealId
end

--[[
	A player finished a cube. Returns the verdict; on a win, also whoever
	held the crown before (so the caller can clear it before lighting the
	new one -- or leave it alone when it is the same player) and the race
	time: seconds since GO, which is the number the room watched. The
	solve's own seconds run from the first swipe and can contradict the
	pop order.
]]
function Sprint.pop(
	s: State,
	cfg: Config,
	now: number,
	key: any,
	dealId: number,
	seconds: number,
	depth: number
): (Verdict, any?, number)
	if s.phase ~= "racing" then
		return "not-racing", nil, 0
	end
	if s.dealIds[key] ~= dealId then
		return "wrong-deal", nil, 0
	end
	if seconds < cfg.MinHumanPerMove * depth then
		return "too-fast", nil, 0
	end
	local raced = false
	for other, did in s.swiped do
		if other ~= key and did then
			raced = true
			break
		end
	end
	if not raced then
		return "no-race", nil, 0
	end

	local sinceGo = now - (s.at - cfg.Seconds)
	local previous = s.crown
	s.winner = key
	s.crown = key
	enter(s, "idle", now, cfg.Every)
	return "won", previous, sinceGo
end

--[[
	A player left. Their deal id goes (a rejoiner gets a fresh seat and a
	normal cube); their SWIPE STAYS -- the race they were in was real, and
	voiding it would let a loser who quits deny the winner. True when they
	held the crown, which is now cleared.
]]
function Sprint.leave(s: State, key: any): boolean
	s.dealIds[key] = nil
	if s.crown == key then
		s.crown = nil
		return true
	end
	return false
end

function Sprint.remaining(s: State, now: number): number
	return math.max(0, s.at - now)
end

return Sprint
