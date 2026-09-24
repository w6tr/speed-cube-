--!nocheck
--[[
	test-sprint.luau -- every edge case in DESIGN-M3.md, against the real
	Shared/Sprint.luau, with a fake clock and fake players.

	Run from the repo root:
	    ~/.rokit/bin/lune run tools/test-sprint.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Sprint = luau.load(fs.readFile("src/shared/Sprint.luau"), {
	environment = setmetatable({ math = math, table = table }, { __index = _G }),
})()

local cfg = {
	Every = 150,
	Countdown = 15,
	Seconds = 45,
	Depth = 8,
	MinPlayers = 2,
	MinHumanPerMove = 0.15,
}

local failures = 0
local function check(ok, message)
	if ok then
		print(`  ok   {message}`)
	else
		failures += 1
		print(`  FAIL {message}`)
	end
end

local function kinds(events)
	local out = {}
	for _, e in events do
		table.insert(out, e.kind)
	end
	return table.concat(out, ",")
end

-- Walk a fresh machine to GO with `joined` players and deal ids for A and B.
local function toRacing(joined)
	local s = Sprint.new()
	Sprint.tick(s, cfg, 0, joined) -- off -> idle
	Sprint.tick(s, cfg, 150, joined) -- idle -> countdown
	local go = Sprint.tick(s, cfg, 165, joined) -- countdown -> go
	assert(kinds(go) == "go", "expected go, got " .. kinds(go))
	Sprint.dealt(s, { A = 7, B = 3, C = 9 })
	return s
end

print("\n-- phases --")
do
	local s = Sprint.new()
	check(kinds(Sprint.tick(s, cfg, 0, 1)) == "", "one player: stays off, announces nothing")
	check(s.phase == "off", "still off")
	check(
		kinds(Sprint.tick(s, cfg, 1, 2)) == "idle",
		"second player joins: idle, countdown in Every"
	)
	check(Sprint.remaining(s, 1) == 150, "remaining is Every")
	check(kinds(Sprint.tick(s, cfg, 100, 2)) == "", "nothing happens mid-idle")
	check(kinds(Sprint.tick(s, cfg, 151, 2)) == "countdown", "Every later: countdown")
	check(kinds(Sprint.tick(s, cfg, 160, 2)) == "", "nothing happens mid-countdown")
	check(kinds(Sprint.tick(s, cfg, 166, 2)) == "go", "Countdown later: GO")
	check(s.phase == "racing" and Sprint.remaining(s, 166) == 45, "racing for Seconds")
end

print("\n-- the countdown cancels below MinPlayers --")
do
	local s = Sprint.new()
	Sprint.tick(s, cfg, 0, 2)
	Sprint.tick(s, cfg, 150, 2)
	check(s.phase == "countdown", "in the countdown")
	check(kinds(Sprint.tick(s, cfg, 155, 1)) == "cancel,idle", "a player leaves: cancel, then idle")
	check(kinds(Sprint.tick(s, cfg, 156, 1)) == "off", "still short a player next tick: off")
end

print("\n-- the pop --")
do
	local s = Sprint.new()
	local v = Sprint.pop(s, cfg, 0, "A", 1, 5, 8)
	check(v == "not-racing", "a pop outside a sprint is not a sprint pop")

	s = toRacing(3)
	check(
		Sprint.pop(s, cfg, 170, "A", 99, 5, 8) == "wrong-deal",
		"a pop on a different deal is not counted"
	)
	check(
		Sprint.pop(s, cfg, 170, "A", 7, 5, 8) == "no-race",
		"nobody else swiped: no win (the idle-alt rule)"
	)
	check(s.phase == "racing" and s.crown == nil, "...and the sprint carries on unlit")

	Sprint.swipe(s, "B", 3)
	check(
		Sprint.pop(s, cfg, 171, "A", 7, 0.5, 8) == "too-fast",
		"faster than MinHumanPerMove x depth cannot win"
	)
	local v2, previous, sinceGo = Sprint.pop(s, cfg, 172, "A", 7, 6.12, 8)
	check(
		v2 == "won" and previous == nil,
		"B swiped, A pops at a human pace: A wins, no previous crown"
	)
	check(sinceGo == 7, "the announced time is seconds since GO (165 -> 172), not the solve's own")
	check(Sprint.live(s, "A", 7) == false, "after the win nobody is live: the dial unlocks")
	check(s.crown == "A" and s.winner == "A", "A holds the crown")
	check(
		s.phase == "idle" and Sprint.remaining(s, 172) == 150,
		"a win ends the sprint and starts the idle wait"
	)
	check(
		Sprint.pop(s, cfg, 173, "B", 3, 7, 8) == "not-racing",
		"B popping after the win is just a normal solve"
	)
end

print("\n-- swipes only count on the live deal --")
do
	local s = toRacing(2)
	Sprint.swipe(s, "B", 1) -- an old deal id
	check(
		Sprint.pop(s, cfg, 170, "A", 7, 5, 8) == "no-race",
		"a swipe on the wrong deal is not a race"
	)
	Sprint.swipe(s, "A", 7)
	check(Sprint.pop(s, cfg, 171, "A", 7, 5, 8) == "no-race", "your own swipe is not a race either")
end

print("\n-- the cap --")
do
	local s = toRacing(2)
	Sprint.swipe(s, "B", 3)
	check(kinds(Sprint.tick(s, cfg, 200, 2)) == "", "mid-race: nothing")
	local ev = Sprint.tick(s, cfg, 211, 2) -- 165 + 45 + 1
	check(kinds(ev) == "nobody,idle", "cap with no pop: nobody, then idle")
	check(ev[1].crown == nil, "no crown to clear on the first sprint")
end

print("\n-- the crown across sprints --")
do
	local s = toRacing(2)
	Sprint.swipe(s, "B", 3)
	Sprint.pop(s, cfg, 170, "A", 7, 6, 8)
	check(s.crown == "A", "A is lit")

	-- next sprint: A wins again -> previous crown is A (caller: set before clear, no blink)
	Sprint.tick(s, cfg, 320, 2) -- idle -> countdown (170 + 150)
	Sprint.tick(s, cfg, 335, 2) -- go
	Sprint.dealt(s, { A = 8, B = 4 })
	Sprint.swipe(s, "B", 4)
	local v, previous = Sprint.pop(s, cfg, 340, "A", 8, 6, 8)
	check(v == "won" and previous == "A", "A wins again: previous crown is A itself")

	-- next sprint: nobody pops -> the light comes off
	Sprint.tick(s, cfg, 490, 2)
	Sprint.tick(s, cfg, 505, 2)
	Sprint.dealt(s, { A = 9, B = 5 })
	local ev = Sprint.tick(s, cfg, 551, 2)
	check(
		kinds(ev) == "nobody,idle" and ev[1].crown == "A",
		"no pop by the cap: A's crown is reported cleared"
	)
	check(s.crown == nil, "...and it is gone")
end

print("\n-- leaving --")
do
	local s = toRacing(2)
	Sprint.swipe(s, "B", 3)
	Sprint.pop(s, cfg, 170, "A", 7, 6, 8)
	check(Sprint.leave(s, "B") == false, "B leaves: had no crown")
	check(Sprint.leave(s, "A") == true, "A leaves: had the crown, now cleared")
	check(s.crown == nil, "nobody is lit")

	s = toRacing(3)
	Sprint.swipe(s, "B", 3)
	Sprint.leave(s, "B")
	check(
		Sprint.pop(s, cfg, 170, "A", 7, 6, 8) == "won",
		"the other racer quit after swiping: the race was real, A still wins"
	)
end

print("\n-- live --")
do
	local s = toRacing(2)
	check(Sprint.live(s, "A", 7) == true, "A's sprint deal is live during the race")
	check(Sprint.live(s, "A", 6) == false, "an older deal of A's is not")
	check(Sprint.live(s, "Z", 7) == false, "someone never dealt is not")
	Sprint.tick(s, cfg, 211, 2) -- the cap
	check(Sprint.live(s, "A", 7) == false, "after the cap nothing is live")
end

if failures == 0 then
	print("\nall good\n")
else
	print(`\n{failures} FAILED\n`)
	os.exit(1)
end
