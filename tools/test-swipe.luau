--!nocheck
--[[
	test-swipe.luau -- drives Swipe.luau with scripted finger paths.

	Run from the repo root:
	    ~/.rokit/bin/lune run tools/test-swipe.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3

local source = fs.readFile("src/shared/Swipe.luau")
local env = setmetatable({ Vector3 = Vector3, math = math }, { __index = _G })
local Swipe = luau.load(source, { environment = env })()

local MIN = 22
local failures = 0

local function run(name, path, want)
	local t = Swipe.begin(Vector3.new(path[1][1], path[1][2], 0), MIN)
	local got = {}
	for i = 2, #path do
		local dir = Swipe.move(t, Vector3.new(path[i][1], path[i][2], 0))
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

-- Positions are (x, y) in pixels; y grows DOWN like a screen.
run("one flick right", { { 0, 0 }, { 10, 1 }, { 30, 2 }, { 60, 3 } }, { "Right" })
run(
	"long swipe right is one swipe",
	{ { 0, 0 }, { 30, 0 }, { 90, 2 }, { 200, 5 }, { 400, 8 } },
	{ "Right" }
)
run(
	"right then left without lifting",
	{ { 0, 0 }, { 40, 0 }, { 80, 0 }, { 60, 0 }, { 40, 0 }, { 10, 0 } },
	{ "Right", "Left" }
)
run(
	"right, left, right (zigzag)",
	{ { 0, 0 }, { 40, 0 }, { 0, 0 }, { 40, 0 } },
	{ "Right", "Left", "Right" }
)
run(
	"right then up (corner)",
	{ { 0, 0 }, { 40, 0 }, { 80, 0 }, { 80, -20 }, { 80, -40 } },
	{ "Right", "Up" }
)
run(
	"right then down with drift",
	{ { 0, 0 }, { 40, 3 }, { 90, 6 }, { 95, 30 }, { 96, 50 } },
	{ "Right", "Down" }
)
run("tiny wobble does nothing", { { 0, 0 }, { 5, 5 }, { -5, 3 }, { 8, -6 } }, {})
run(
	"small backtrack after a swipe does nothing",
	{ { 0, 0 }, { 40, 0 }, { 30, 0 }, { 25, 0 } },
	{ "Right" }
)
run("up then down", { { 0, 0 }, { 0, -30 }, { 0, -60 }, { 0, -20 }, { 0, 10 } }, { "Up", "Down" })
run("diagonal picks the bigger axis", { { 0, 0 }, { 30, -20 } }, { "Right" })
run("lift and re-plant repeats a direction", { { 0, 0 }, { 40, 0 } }, { "Right" })
run(
	"repeat needs a lift: wind-back reads as opposite",
	{ { 0, 0 }, { 40, 0 }, { 10, 0 }, { 50, 0 } },
	{ "Right", "Left", "Right" }
)

print("")
if failures == 0 then
	print("all good")
else
	print(`{failures} failure(s)`)
	os.exit(1)
end
