--!nocheck
--[[
	test-swipe.luau -- drives Swipe.luau with scripted finger paths.

	Each path is a list of { x, y, t }: pixels (y grows DOWN like a screen)
	and seconds. Run from the repo root:
	    ~/.rokit/bin/lune run tools/test-swipe.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local source = fs.readFile("src/shared/Swipe.luau")
local env = setmetatable({ Vector3 = Vector3, math = math }, { __index = _G })
local Swipe = luau.load(source, { environment = env })()

-- Mirror Config.Input; keep in step with it.
local OPTIONS = { minPixels = 36, chainPixels = 54, chainCooldown = 0.12, axisRatio = 1.4 }

local failures = 0

local function run(name, path, want)
	local first = path[1]
	local t = Swipe.begin(Vector3.new(first[1], first[2], 0), OPTIONS)
	local got = {}
	for i = 2, #path do
		local p = path[i]
		local dir = Swipe.move(t, Vector3.new(p[1], p[2], 0), p[3])
		if dir then
			table.insert(got, dir)
		end
	end
	local ok = table.concat(got, ",") == table.concat(want, ",")
	if ok then
		print("  ok   " .. name .. "  -> " .. table.concat(got, ","))
	else
		failures += 1
		print(
			"  FAIL "
				.. name
				.. "  want "
				.. table.concat(want, ",")
				.. "  got "
				.. table.concat(got, ",")
		)
	end
end

-- A quick flick: 60 px in 60 ms.
run(
	"one flick right",
	{ { 0, 0, 0 }, { 15, 1, 0.02 }, { 40, 2, 0.04 }, { 60, 3, 0.06 } },
	{ "Right" }
)

-- A twitch of the mouse must NOT count.
run(
	"small twitch does nothing",
	{ { 0, 0, 0 }, { 12, 0, 0.02 }, { 24, 1, 0.04 }, { 30, 1, 0.06 } },
	{}
)

run(
	"long swipe right is one swipe",
	{ { 0, 0, 0 }, { 40, 0, 0.03 }, { 90, 2, 0.06 }, { 200, 5, 0.1 }, { 400, 8, 0.2 } },
	{ "Right" }
)

-- The user's complaint: a normal swipe ends with the hand slowing and
-- curling down/back. Right 90 px, then a 30 px curl within 100 ms.
run("swipe with a curl tail is one swipe", {
	{ 0, 0, 0 },
	{ 40, 0, 0.03 },
	{ 90, 2, 0.06 },
	{ 96, 14, 0.09 },
	{ 92, 30, 0.13 },
	{ 88, 34, 0.2 },
}, { "Right" })

-- A curl that keeps drifting slowly after the cooldown still does not
-- reach the chained threshold.
run(
	"slow drift after a swipe does nothing",
	{ { 0, 0, 0 }, { 60, 0, 0.05 }, { 62, 10, 0.2 }, { 60, 25, 0.4 }, { 58, 40, 0.6 } },
	{ "Right" }
)

-- A real reversal after the cooldown: right 80, pause, back 70.
run("right then left without lifting", {
	{ 0, 0, 0 },
	{ 40, 0, 0.03 },
	{ 80, 0, 0.06 },
	{ 60, 0, 0.2 },
	{ 40, 0, 0.23 },
	{ 10, 0, 0.26 },
}, { "Right", "Left" })

run(
	"right, left, right (zigzag, deliberate)",
	{ { 0, 0, 0 }, { 60, 0, 0.05 }, { 0, 0, 0.25 }, { 60, 0, 0.45 } },
	{ "Right", "Left", "Right" }
)

run(
	"right then up (corner)",
	{ { 0, 0, 0 }, { 40, 0, 0.03 }, { 80, 0, 0.06 }, { 80, -30, 0.2 }, { 82, -60, 0.24 } },
	{ "Right", "Up" }
)

run(
	"tiny wobble does nothing",
	{ { 0, 0, 0 }, { 5, 5, 0.02 }, { -5, 3, 0.04 }, { 8, -6, 0.06 } },
	{}
)

run(
	"small backtrack after a swipe does nothing",
	{ { 0, 0, 0 }, { 60, 0, 0.05 }, { 40, 0, 0.3 }, { 30, 0, 0.4 } },
	{ "Right" }
)

run(
	"up then down",
	{ { 0, 0, 0 }, { 0, -40, 0.03 }, { 0, -70, 0.06 }, { 0, -20, 0.25 }, { 0, 10, 0.3 } },
	{
		"Up",
		"Down",
	}
)

-- A diagonal waits until one axis clearly wins.
run(
	"diagonal waits, then resolves",
	{ { 0, 0, 0 }, { 30, -28, 0.03 }, { 60, -30, 0.06 } },
	{ "Right" }
)

run("lift and re-plant repeats a direction", { { 0, 0, 0 }, { 50, 0, 0.05 } }, { "Right" })

print("")
if failures == 0 then
	print("all good")
else
	print(`{failures} failure(s)`)
	os.exit(1)
end
