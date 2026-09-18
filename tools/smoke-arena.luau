--!nocheck
--[[
	smoke-arena.luau -- checks the hall inside a real engine.

	This one is NOT a lune test: it runs inside a real Roblox engine, on
	the real parts, so it can measure the hall instead of a pretend one.

	    ~/.rokit/bin/rojo build default.project.json -o build/smoke.rbxl
	    ~/.rokit/bin/run-in-roblox --place build/smoke.rbxl --script tools/smoke-arena.luau

	run-in-roblox drives Studio in EDIT mode, as a plugin, so the game's
	own server scripts never run. This script therefore boots the world
	itself out of the same three modules init.server.luau uses, in the
	same order -- which is the thing worth testing anyway.

	It answers four questions:
	  1. did the hall build at all, and out of how many parts,
	  2. did the lighting rig take,
	  3. is any player's camera buried inside a piece of scenery,
	  4. how high up the far side of the hall can a player actually SEE?
	     (Arena.luau's whole layout rests on that answer being about 7
	     studs; this measures it instead of trusting the trigonometry.)
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Server = ServerScriptService:WaitForChild("Server")
local Arena = require(Server:WaitForChild("Arena"))
local LobbyBuilder = require(Server:WaitForChild("LobbyBuilder"))
local Look = require(Server:WaitForChild("Look"))

local failures = 0

local function check(ok: boolean, message: string)
	if ok then
		print(`  ok    {message}`)
	else
		failures += 1
		print(`  FAIL  {message}`)
	end
end

--------------------------------------------------------------------------------
print("\n-- the hall --")

-- The same three calls, in the same order, as init.server.luau.
Look.apply()
local world = LobbyBuilder.build()
Arena.build(world.folder, world.pedestals)

local lobby = world.folder
check(lobby.Parent == workspace, "the Lobby folder is in the workspace")

local parts = 0
local neon = 0
local lights = 0
for _, d in lobby:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d.Material == Enum.Material.Neon then
			neon += 1
		end
	elseif d:IsA("Light") then
		lights += 1
	end
end
print(`  {parts} parts, {neon} of them Neon, {lights} lights`)
check(parts < 600, `part count is under 600 (it is {parts})`)

for _, name in { "Markings", "Barrier", "Stands", "Wall", "Rig", "Stations" } do
	check(lobby:FindFirstChild(name) ~= nil, `{name} was built`)
end

--------------------------------------------------------------------------------
print("\n-- the lighting rig --")

check(Lighting.ClockTime == Config.Look.ClockTime, "ClockTime is the one in Config.Look")
check(Lighting:FindFirstChildOfClass("Atmosphere") ~= nil, "Atmosphere is in place")
check(Lighting:FindFirstChildOfClass("BloomEffect") ~= nil, "Bloom is in place")
check(Lighting:FindFirstChildOfClass("ColorCorrectionEffect") ~= nil, "ColorCorrection is in place")
check(Lighting:FindFirstChildOfClass("DepthOfFieldEffect") ~= nil, "DepthOfField is in place")
-- Lighting.Technology cannot be READ from a script either, so there is
-- nothing to assert here: check it in Studio if the hall looks flat.

--------------------------------------------------------------------------------
print("\n-- every player's camera --")

local pedestals = world.pedestals
check(#pedestals == Config.MaxPlayers, `there is one pedestal per player ({#pedestals})`)

-- The dressing must sit ON the pedestals, not have moved them: the
-- camera, the cube and every spectator copy are all placed from these.
local stations = lobby:FindFirstChild("Stations")
for i, pedestal in pedestals do
	local mat = stations and stations:FindFirstChild(`Station{i}`)
	mat = mat and mat:FindFirstChild("Mat")
	if mat then
		local expected = (pedestal * CFrame.new(0, Config.Arena.Station.MatThickness / 2, 0)).Position
		check((mat.Position - expected).Magnitude < 0.01, `station {i} sits on its pedestal`)
	end
end

-- Arena builds its scenery with CanQuery = false, which is right for the
-- game (a few hundred static parts no raycast should ever have to
-- consider) and useless for measuring it: rays sail straight through the
-- hall. This is a throwaway place, so switch querying back on.
for _, d in lobby:GetDescendants() do
	if d:IsA("BasePart") then
		d.CanQuery = true
	end
end

-- The tightest fit in the game: at full pop the cube swells about its
-- centre and comes down at the station mat. This has been negative once
-- already.
local halfExtent = (Config.Cube.CubieSize * 3 + Config.Cube.Gap * 2) / 2
local clearance = Config.Cube.Height
	- halfExtent * Config.Cube.PopScale
	- Config.Arena.Station.MatThickness
check(clearance > 0.05, string.format("a popping cube clears the mat by %.3f studs", clearance))

local ignore = RaycastParams.new()
ignore.FilterType = Enum.RaycastFilterType.Exclude
ignore.FilterDescendantsInstances = {}

local lowest = math.huge
local highest = -math.huge

for i, pedestal in pedestals do
	local centre = pedestal * CFrame.new(0, Config.Cube.Height, 0)
	local eye = centre:PointToWorldSpace(Config.Camera.Offset)
	local camera = CFrame.lookAt(eye, centre.Position)

	-- 3. is the camera inside something?
	local touching = workspace:GetPartBoundsInRadius(eye, 0.6)
	local names = {}
	for _, p in touching do
		table.insert(names, p.Name)
	end
	check(
		#touching == 0,
		`camera {i} is in clear air`
			.. (if #touching > 0 then ` (hit {table.concat(names, ", ")})` else "")
	)

	-- 4. where does the TOP edge of the picture land?
	local half = math.rad(Config.Camera.FieldOfView / 2)
	local up = (camera * CFrame.Angles(half, 0, 0)).LookVector
	local hit = workspace:Raycast(eye, up * 400, ignore)
	if hit then
		lowest = math.min(lowest, hit.Position.Y)
		highest = math.max(highest, hit.Position.Y)
		if i == 1 then
			print(
				string.format(
					"  top of frame lands on %s at y = %.2f, %.0f studs out",
					hit.Instance.Name,
					hit.Position.Y,
					(hit.Position - eye).Magnitude
				)
			)
		end
	else
		failures += 1
		print(`  FAIL  camera {i} can see over the hall: the sky is in frame`)
	end
end

if lowest < math.huge then
	print(
		string.format(
			"  across all 8 seats the frame's ceiling is y = %.2f to %.2f",
			lowest,
			highest
		)
	)
	check(
		highest <= Config.Arena.SeenHeight + 1.5,
		string.format(
			"the seen band really is about %d studs (measured %.2f)",
			Config.Arena.SeenHeight,
			highest
		)
	)
end

--------------------------------------------------------------------------------
if failures == 0 then
	print("\nsmoke-arena: all good\n")
else
	print(`\nsmoke-arena: {failures} FAILED\n`)
end
