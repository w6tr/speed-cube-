--!nocheck
--[[
	test-cubes.luau -- checks the cube definitions and the box odds.

	  1. every cube has a valid tier, six sticker colours, a multiplier
	     inside its tier's range and under the cap,
	  2. every box's odds add up to 100 and every tier with odds has at
	     least one cube,
	  3. rolling each box 20,000 times lands within a couple of points of
	     the printed odds (the same roll as CubeService).

	Run from the repo root:
	    ~/.rokit/bin/lune run tools/test-cubes.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Color3 = roblox.Color3
local Vector3 = roblox.Vector3
local Enum = roblox.Enum

local function load(path, extraEnv)
	local env = setmetatable({
		Color3 = Color3,
		Vector3 = Vector3,
		Enum = Enum,
		math = math,
		table = table,
		string = string,
		type = type,
		assert = assert,
		error = error,
		print = print,
	}, { __index = _G })
	for k, v in extraEnv or {} do
		env[k] = v
	end
	return luau.load(fs.readFile(path), { environment = env })()
end

local Config = load("src/shared/Config.luau")
local Cubes = load("src/shared/Defs/Cubes.luau")

local failures = 0
local function check(ok, text)
	if ok then
		print("  ok   " .. text)
	else
		failures += 1
		print("  FAIL " .. text)
	end
end

print("1. cube definitions")
local seen = {}
for _, def in Cubes.List do
	local tier = Config.Boxes.Tiers[def.tier]
	check(tier ~= nil, `{def.id}: tier {def.tier} exists`)
	check(not seen[def.id], `{def.id}: unique id`)
	seen[def.id] = true
	local faces = 0
	for _, f in { "U", "D", "F", "B", "R", "L" } do
		if def.look.stickers[f] then
			faces += 1
		end
	end
	check(faces == 6, `{def.id}: six sticker colours`)
	if tier then
		check(
			def.mult >= tier.Range[1] - 1e-6 and def.mult <= tier.Range[2] + 1e-6,
			`{def.id}: x{def.mult} inside {def.tier} range`
		)
	end
	check(def.mult <= Config.Boxes.MaxMult, `{def.id}: under the cap`)
	check(def.sound ~= "" and def.blurb ~= "", `{def.id}: sound and blurb`)
end
check(Cubes.get(Cubes.Default) ~= nil, "default cube exists")

print("2. box odds")
for _, box in Config.Boxes.List do
	local total = 0
	for _, tier in Config.Boxes.TierOrder do
		local pct = box.odds[tier] or 0
		total += pct
		if pct > 0 then
			check(#Cubes.ofTier(tier) > 0, `{box.id}: {tier} has cubes`)
		end
	end
	check(total == 100, `{box.id}: odds add to 100 (got {total})`)
end

print("3. roll distribution (20,000 per box)")
-- The same roll as CubeService.rollTier, with a deterministic random.
local state = 987654321
local function nextNumber(lo, hi)
	state = (state * 1103515245 + 12345) % 2147483648
	return lo + (state / 2147483648) * (hi - lo)
end
local function rollTier(box)
	local total = 0
	for _, tier in Config.Boxes.TierOrder do
		total += box.odds[tier] or 0
	end
	local pick = nextNumber(0, total)
	local acc = 0
	for _, tier in Config.Boxes.TierOrder do
		acc += box.odds[tier] or 0
		if pick <= acc and (box.odds[tier] or 0) > 0 then
			return tier
		end
	end
	return Config.Boxes.TierOrder[1]
end
for _, box in Config.Boxes.List do
	local counts = {}
	local n = 20000
	for _ = 1, n do
		local tier = rollTier(box)
		counts[tier] = (counts[tier] or 0) + 1
	end
	for _, tier in Config.Boxes.TierOrder do
		local want = box.odds[tier] or 0
		local got = (counts[tier] or 0) / n * 100
		check(
			math.abs(got - want) <= 1.5,
			string.format("%s: %s %.1f%% (want %d%%)", box.id, tier, got, want)
		)
	end
end

print("")
if failures == 0 then
	print("all good")
else
	print(`{failures} failure(s)`)
	os.exit(1)
end
