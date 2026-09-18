--!strict
--[[
	Config.luau -- every number the game runs on.

	Logic lives in the services and the views; numbers live here. Retuning
	how fast coins come, how deep a scramble goes or how a turn feels never
	means touching a service file.

	Read this file first. The sections, top to bottom:
	  Depth     how many moves a scramble is, and how that grows
	  Coins     what a solve pays
	  Combo     the streak multiplier and what breaks it
	  Timing    the server-side clocks (perfect window, spam guard, pop pause)
	  Cube      the 3D cube: size, gaps, turn speed, the arrow prompt
	  Camera    where the camera sits relative to the pedestal
	  Lobby     the ring of pedestals
	  Look      the lighting rig: how dark the hall is and what glows
	  Arena     the hall around the ring, and what of it is ever on screen
	  Input     swipe thresholds and the keys
	  Sounds    which built-in Roblox sounds play
	  Save      DataStore settings
]]

local Config = {}

Config.GameName = "Speed Cube"
Config.MaxPlayers = 8 -- one pedestal each; set the place's max players to match

--------------------------------------------------------------------------------
-- Depth: how long a scramble is
--------------------------------------------------------------------------------
--[[
	A "deal" is a cube scrambled by `depth` moves. The player swipes the
	same number of moves back, guided by an arrow per move. Every solve
	counts toward unlocking deeper scrambles; deeper pays more per solve
	but a wrong swipe anywhere in it breaks the combo.
]]
Config.Depth = {
	Start = 5, -- the first deals are this many moves
	Min = 3, -- the player can dial down to this
	Max = 15, -- and never above this
	SolvesPerUnlock = 3, -- every N solves unlocks +1 depth
}

--------------------------------------------------------------------------------
-- Coins: what a solve pays
--------------------------------------------------------------------------------
--[[
	coins = (PerMove * depth + SolveBonus + speedBonus + perfects)
	        * comboMult * cubeMult
	speedBonus is SpeedBonus when the solve took under ParPerMove * depth
	seconds (measured on the server from the first correct swipe to the
	last), else 0. comboMult comes from the Combo section; cubeMult is the
	equipped cube's multiplier (Defs/Cubes.luau), capped by Boxes.MaxMult.
]]
Config.Coins = {
	PerMove = 1,
	SolveBonus = 5,
	SpeedBonus = 5,
	ParPerMove = 0.6, -- seconds per move that counts as "fast"
	PerfectBonus = 1, -- extra coins per PERFECT swipe (see Timing.PerfectGap)
}

--------------------------------------------------------------------------------
-- Combo: the streak
--------------------------------------------------------------------------------
--[[
	Every correct swipe adds one to the combo; a wrong swipe sets it to 0.
	The combo carries across solves, so a clean session keeps climbing.
	Multiplier = 1 + MultPerCombo * combo, capped at MaxMult.
]]
Config.Combo = {
	MultPerCombo = 0.1,
	MaxMult = 3,
}

--------------------------------------------------------------------------------
-- Timing: server-side clocks
--------------------------------------------------------------------------------
Config.Timing = {
	PerfectGap = 0.35, -- a correct swipe this soon after the previous one is PERFECT
	WrongLockSeconds = 0.3, -- after a wrong swipe, swipes are ignored for this long
	LockSlack = 0.1, -- the server's lock is this much shorter, so lag never eats the next swipe
	PopSeconds = 0.8, -- pause after a solve before the next deal (the pop plays here)
	-- Spam guard: a bucket of BurstMoves swipes that refills one per
	-- MinMoveGap. Two honest swipes that arrive together both count; a
	-- stream faster than a human does not.
	MinMoveGap = 0.04,
	BurstMoves = 3,
	MinHumanPerMove = 0.08, -- a solve faster than this per move earns no speed bonus or best
	SyncThrottle = 0.5, -- the server answers RequestSync at most this often per player
	ActionCooldown = 0.25, -- one box or equip per player per this many seconds; faster is dropped
	ResyncAfter = 2.5, -- the client asks for a Sync if a solve is not confirmed by then
}

--------------------------------------------------------------------------------
-- Cube: the 3D cube and its prompt
--------------------------------------------------------------------------------
Config.Cube = {
	CubieSize = 1, -- studs
	Gap = 0.08, -- between cubies
	StickerInset = 0.1, -- sticker is this much smaller than the cubie face, each side
	TurnSeconds = 0.11, -- one prompted turn
	ShuffleTurnSeconds = 0.04, -- one turn during the scramble animation
	-- Cube centre above the pedestal top. At full pop the cube swells to
	-- PopScale about its centre, so its underside drops to
	-- Height - 1.58 * PopScale = 0.19 studs: enough to clear the station mat
	-- Arena.luau lays on the plinth. At the old 1.9 the gap was 0.04 and the
	-- mat was clipped through on every solve.
	Height = 2.05,
	Body = Color3.fromRGB(20, 20, 24),
	-- Sticker colours, by face. Standard colour scheme: white up, yellow
	-- down, green front, blue back, red right, orange left.
	Stickers = {
		U = Color3.fromRGB(245, 245, 245),
		D = Color3.fromRGB(250, 220, 40),
		F = Color3.fromRGB(40, 190, 80),
		B = Color3.fromRGB(40, 100, 230),
		R = Color3.fromRGB(230, 50, 50),
		L = Color3.fromRGB(250, 130, 30),
	},
	-- The arrow prompt: a see-through slab floating just off the front face
	-- over the row or column that has to turn.
	-- THE ARROW IS THE INTERFACE, not decoration. Most players cannot solve
	-- a cube and are never meant to learn: the arrow is the whole reason the
	-- game is playable, so it must be the second-strongest read on screen
	-- after the cube itself, on every sticker colour, at any size.
	--
	-- Two things were wrong. It was WHITE, which is a sticker colour, so on
	-- a white face it vanished; and the pulse faded it to 55% transparent,
	-- so half of every second it was a grey ghost over a green sticker.
	-- Magenta appears nowhere on a cube, and the pulse now breathes over a
	-- narrow range that never lets the arrow get faint.
	--
	-- SKINNING (for per-cube arrows): only Color and Glow may ever vary per
	-- cube. Size, Stroke and the pulse range are the readable skeleton and
	-- stay fixed, or a cube you unlock could be harder to play than the one
	-- you started with.
	Arrow = {
		Offset = 0.18, -- studs in front of the face
		Color = Color3.fromRGB(255, 64, 180),
		WrongColor = Color3.fromRGB(255, 70, 70), -- the arrow flashes this on a wrong swipe
		WrongFlashSeconds = 0.25,
		PulseSeconds = 0.75,
		PulseTransparency = 0.12, -- never faint enough to lose
		TextSize = 150,
		StrokeColor = Color3.fromRGB(10, 6, 14),
		StrokeThickness = 5, -- holds the shape over any sticker colour
	},
	-- How bright the stickers are drawn. Above about 1.0 an ordinary white
	-- or yellow sticker passes Config.Look.Bloom.Threshold under a station
	-- lamp and the CUBE starts glowing, which is meant to be a cosmetic you
	-- unlock, not something every cube does. Glow-tier cubes (Defs/Cubes
	-- look.glow) get the high one on purpose -- that IS the cosmetic.
	StickerBrightness = 1.0,
	GlowStickerBrightness = 2.0,
	PopScale = 1.18, -- the cube swells to this on a solve
	PopSeconds = 0.35,
	ShakeStuds = 0.18, -- wrong-swipe wobble
	ShakeSeconds = 0.22,
	Particles = 45, -- burst on a solve
}

--------------------------------------------------------------------------------
-- Camera: relative to the pedestal (local +Z is toward the camera)
--------------------------------------------------------------------------------
Config.Camera = {
	Offset = Vector3.new(3.4, 4.6, 7.2), -- from the cube centre, in pedestal space
	FieldOfView = 55,
	PunchStuds = 0.5, -- the camera dips toward the cube by this on a solve
	PunchSeconds = 0.18,
}

--------------------------------------------------------------------------------
-- Hud: the arrow lane, the combo streak, the solve card
--------------------------------------------------------------------------------
Config.Hud = {
	LaneSize = 3, -- the current arrow plus this many minus one upcoming
	LaneHeight = 56,
	LaneBigSize = 44, -- text size of the current arrow
	LaneSmallSize = 26, -- and of the upcoming ones
	ComboPunch = 1.25, -- the combo box scales to this on every hit
	ComboStrokePer = 5, -- glow thickness = combo / this ...
	ComboStrokeMax = 4, -- ... capped here
	ComboChimeEvery = 10, -- a chime every N combo
	-- The streak's colour by size. Tiers are checked in order; the last
	-- one the combo reaches wins.
	ComboTiers = {
		{ At = 10, Color = Color3.fromRGB(231, 174, 58) }, -- gold
		{ At = 20, Color = Color3.fromRGB(255, 130, 60) }, -- orange
		{ At = 30, Color = Color3.fromRGB(255, 80, 120) }, -- hot pink
	},
}

--------------------------------------------------------------------------------
-- Lobby: a ring of pedestals facing outward
--------------------------------------------------------------------------------
Config.Lobby = {
	Radius = 16, -- pedestal ring radius
	FloorSize = 90,
	PedestalRadius = 1.6,
	PedestalHeight = 2.6,
	StandBack = 2.6, -- the avatar stands this far behind the cube (toward the ring centre)
	HipHeight = 3.2, -- the avatar's root part above the floor when placed
	-- The hall is dark and lit from above (Config.Look), so these are
	-- much darker than they read here: a light pool falls on each of them.
	Colors = {
		Floor = Color3.fromRGB(38, 44, 58),
		Ring = Color3.fromRGB(48, 56, 72), -- the stage disc inside the ring
		Pedestal = Color3.fromRGB(54, 62, 80),
		Trim = Color3.fromRGB(34, 92, 145), -- the station LED. Gold stays for coins.
	},
}

--------------------------------------------------------------------------------
-- Look: the lighting rig
--------------------------------------------------------------------------------
--[[
	The hall is indoors at night. The sun is below the horizon and every
	stud of light comes from this rig and the lamps hanging over the
	stations -- which is the whole reason a Neon cube reads as glowing
	instead of as one more grey part under a midday sun.

	Technology lives in default.project.json, because a script may neither
	read nor write it. ShadowMap keeps the sun's shadows and lets local lights
	light for almost nothing, because under it they cast no shadows of
	their own. Future makes all eight station lamps cast real shadows and
	costs far more on a phone. Flip it in default.project.json to compare,
	but test on a phone before shipping it.
]]
Config.Look = {
	-- NOTE: Lighting.Technology is not here because a script may neither
	-- read nor write it (it throws "lacking capability RobloxScript").
	-- It is set in default.project.json, currently ShadowMap.
	ClockTime = 0, -- midnight: the hall lights itself
	Brightness = 1.1,
	-- Raised off black on purpose. A room whose only values are BLACK and
	-- BLOWN OUT reads as both "empty" and "too bright" at the same time --
	-- there is no middle for a coin burst, a rim light or a confetti pop to
	-- read against. The middle is what makes the rest legible.
	Ambient = Color3.fromRGB(34, 38, 54),
	OutdoorAmbient = Color3.fromRGB(24, 28, 40),
	ExposureCompensation = 0.05,
	EnvironmentDiffuseScale = 0.2,
	EnvironmentSpecularScale = 0.35,
	-- Haze. Distance fades to this colour, which is what stops the far
	-- side of the hall from looking like cardboard standing in a void.
	Atmosphere = {
		Density = 0.32,
		Offset = 0.15,
		Color = Color3.fromRGB(58, 72, 112),
		Decay = Color3.fromRGB(28, 34, 58),
		Glare = 0.4,
		Haze = 1.6,
	},
	-- Bloom is what turns a Neon part into a light source. Threshold -- the
	-- brightness at which a surface starts to glow -- is the most delicate
	-- number in the game. Too low and the
	-- CUBE blooms -- a white or yellow sticker under a station lamp is
	-- brighter than you think -- which steals the glow that is supposed to
	-- be an Epic/Legendary cosmetic. Too high and the arena's neon stops
	-- glowing and the hall goes flat.
	--
	-- If the cube glows again: raise Threshold, or lower
	-- Config.Cube.StickerBrightness.
	-- If the arena stops glowing: lower Threshold.
	-- If the glow is the right places but too strong: lower Intensity.
	-- Threshold is set ABOVE what a white sticker reaches when a station
	-- lamp is on it. That was the bug: 1.05 cleared an UNLIT white sticker
	-- and a lit one sailed straight over it, so the cube glowed. Only a
	-- genuinely emissive thing passes 1.4 now -- which means a glow-tier
	-- cube, and nothing else. Glow is a cosmetic you unlock.
	Bloom = {
		Intensity = 0.7,
		Size = 18,
		Threshold = 1.4,
	},
	Correction = {
		Brightness = 0.0,
		Contrast = 0.1,
		Saturation = 0.12,
		TintColor = Color3.fromRGB(246, 248, 255),
	},
	-- Softens the far side of the hall so the eye stays on the cube. The
	-- cube sits about 8 studs from the camera.
	Depth = {
		FocusDistance = 9,
		InFocusRadius = 20,
		FarIntensity = 0.28,
		NearIntensity = 0,
	},
}

--------------------------------------------------------------------------------
-- Arena: the hall around the ring
--------------------------------------------------------------------------------
--[[
	WHAT THE PLAYER ACTUALLY SEES, and why this section is shaped the way
	it is.

	The camera is locked (CameraRig re-applies it every frame, so nobody
	can look around). It sits 23.5 studs out from the middle, at
	Lobby.PedestalHeight + Cube.Height + Camera.Offset.Y -- 9.25 studs as
	those three are set today, and it MOVES when any of them does -- and
	looks DOWN at the cube by 30 degrees. The field of view is 55, so the
	TOP edge of the picture is already 2.5 degrees BELOW the horizon and
	the frame's ceiling drops a stud for every 23 studs of distance. The
	engine measures the middle of that edge landing at y = 6.77, 56 studs
	out, on the fourth row of seating.

	The CORNERS of a wide screen fall away more slowly and reach y = 8.46
	on an ultrawide. (Roblox's field of view is vertical: a phone sees the
	same height and less width, so phones are the safe case.) So
	`SeenHeight` is the height below which detail is worth BUILDING, not a
	promise that nothing above it is ever seen -- the wall stays 17 studs
	tall to cover that corner, and the first second of a session before
	CameraRig takes the camera over.

	The detail budget goes into the band from the floor to `SeenHeight`:
	the floor itself, the barrier boards, the rows of seating. Everything
	above it -- the wall's upper half, the truss, the lamps -- is built
	cheap, because in play it is only glimpsed before the first Sync and
	then seen again in a free-camera shot for the store icon.

	Radii, from the middle out:
	   0     the leaderboard board (kept under 5 studs, see Config.Board)
	  16     the ring of stations (Config.Lobby.Radius), and the truss
	         above them
	  23.5   every player's camera
	  27     the barrier boards around the competition floor
	  29-36  the seating, raised on a platform so the boards do not hide it
	  41     the back wall
]]
Config.Arena = {
	SeenHeight = 7, -- above this, nothing is seen while playing

	Floor = {
		-- The floor and stage COLOURS live in Config.Lobby.Colors, which is
		-- what LobbyBuilder already builds them from. Only the surface and
		-- the painted markings are here.
		Material = Enum.Material.Concrete,
		StageMaterial = Enum.Material.SmoothPlastic,
		-- Painted rings on the floor, like a competition hall's markings.
		Lines = {
			{ Radius = 20.5, Width = 0.6, Color = Color3.fromRGB(78, 90, 112), Neon = false },
			{ Radius = 25.4, Width = 0.22, Color = Color3.fromRGB(36, 96, 150), Neon = true },
		},
	},

	-- The hoardings around the floor: low boards carrying the event name,
	-- exactly where a real competition puts its sponsors.
	Barrier = {
		Radius = 27,
		Height = 3.2,
		Segments = 40,
		-- The glowing rail gets its OWN, much finer ring. A ring of tangent
		-- boxes is a polygon: at 24 segments each box's corners stand about a
		-- third of a stud proud of the circle, which on a rail a sixth of a
		-- stud thick means the corners double up, glow harder than the middles
		-- and the whole rail reads as dashes instead of a line.
		TrimSegments = 72,
		Color = Color3.fromRGB(28, 32, 42),
		TrimColor = Color3.fromRGB(36, 96, 150),
		TrimHeight = 0.16,
		TextColor = Color3.fromRGB(226, 236, 255),
		TextSize = 38,
		-- Cycled around the ring, one per segment.
		Texts = {
			"SPEED CUBE OPEN",
			"",
			"FINALS",
			"",
			"SPEED CUBE OPEN",
			"",
			"ROUND 8",
			"",
		},
	},

	-- Tiered seating. Only the first four or five rows are ever in frame,
	-- so they are built as concentric cylinders rather than real steps.
	Stands = {
		InnerRadius = 29,
		Rows = 4,
		Segments = 32,
		RowDepth = 2.2,
		-- The bank stands on a platform. Without one the first rows are
		-- SHORTER than the hoardings in front of them and nobody ever sees
		-- them: a sightline grazing the boards passes y = 2.3 by the time it
		-- reaches the seating, so a row has to top out above that.
		Base = 3.6,
		RowRise = 1.15,
		Color = Color3.fromRGB(40, 46, 60),
		AltColor = Color3.fromRGB(48, 55, 70),
		SeatColor = Color3.fromRGB(64, 74, 94),
		Seats = 28, -- little blocks along the front row, to give the bank a scale
		SeatRise = 0.45,
	},

	Wall = {
		Radius = 41,
		Height = 17,
		Segments = 32,
		Color = Color3.fromRGB(26, 30, 40),
		-- The wall's light band is PAINTED on the panels rather than built as
		-- a second ring of parts: painted, it follows each panel exactly, so
		-- there are no protruding corners to glow brighter than the rest, and
		-- it costs no parts at all.
		LedColor = Color3.fromRGB(44, 86, 150),
		LedHeight = 5.8, -- inside the seen band on purpose
		LedThickness = 0.5,
	},

	-- Above the frame in play; there for the store shots.
	Truss = {
		-- Straight over the ring, so the lamp rods meet it instead of
		-- hanging from nothing in a free-camera shot.
		Radius = 16,
		Height = 14.5,
		Segments = 24,
		Thickness = 0.45,
		Color = Color3.fromRGB(38, 42, 54),
	},

	-- One lamp over each station. The housing is never seen while
	-- playing; its light is the whole point.
	Lamp = {
		Height = 13,
		HousingColor = Color3.fromRGB(24, 26, 34),
		LensColor = Color3.fromRGB(150, 180, 215),
		Color = Color3.fromRGB(198, 220, 255),
		-- Was 2.6, which drove a lit white sticker straight past the bloom
		-- threshold and made the cube glow.
		Brightness = 1.5,
		Range = 30,
		Angle = 58,
	},

	-- The station itself: a competition mat on the plinth, a pair of
	-- timer pads in front of the cube, and a pool of light on the floor.
	Station = {
		MatColor = Color3.fromRGB(26, 92, 72), -- competition mat green
		-- Just inside the plinth trim ring (radius 1.75) so the station LED
		-- still shows all the way round.
		MatSize = 3.4,
		MatThickness = 0.08,
		-- The timer pads and the station number are PAINTED on the mat, not
		-- built out of parts. At full pop the cube swells down to within a
		-- fifth of a stud of the mat, so anything standing proud of it would
		-- be clipped straight through on every solve.
		PadColor = Color3.fromRGB(16, 18, 24),
		PadRingColor = Color3.fromRGB(38, 100, 150),
		PadDiameter = 0.3, -- of the mat, across
		PadSpread = 0.19, -- each pad this far from the middle of the mat
		-- Rows down the mat. 0 is the edge nearest the player, 1 the far
		-- edge: the pads sit under the player's own camera, the number at the
		-- far end where the rest of the hall reads it.
		PadRow = 0.26,
		NumberRow = 0.8,
		NumberColor = Color3.fromRGB(150, 210, 255),
		NumberSize = 34,
		GlowRadius = 3.0, -- the lit pool on the floor under the station
		-- The mat's edge glow was flaring up onto the cube's bottom row from
		-- below -- a second, separate cause of "the glow carries over".
		GlowColor = Color3.fromRGB(70, 110, 175),
		GlowTransparency = 0.9,
		LightColor = Color3.fromRGB(150, 190, 255),
		LightBrightness = 0.9,
		LightRange = 14,
	},
}

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
Config.Input = {
	-- The first swipe of a press commits after this much travel, before
	-- the finger lifts. (Shared/Swipe.luau has the rules.)
	SwipeMinPixels = 36,
	-- One press can carry many swipes. A chained swipe (same press, after
	-- a commit) needs this much travel in a NEW direction ...
	ChainPixels = 54,
	-- ... and nothing counts for this long after a commit: the tail of a
	-- real swipe, where the hand slows and curls, must not read as a
	-- second swipe.
	ChainCooldown = 0.12,
	-- A move only counts when the bigger axis is at least this many times
	-- the other; diagonals wait until they resolve.
	AxisRatio = 1.4,
	Keys = {
		Up = { Enum.KeyCode.Up, Enum.KeyCode.W },
		Down = { Enum.KeyCode.Down, Enum.KeyCode.S },
		Left = { Enum.KeyCode.Left, Enum.KeyCode.A },
		Right = { Enum.KeyCode.Right, Enum.KeyCode.D },
	},
}

--------------------------------------------------------------------------------
-- Sounds: Roblox's built-in content sounds (no asset ids to look up)
--------------------------------------------------------------------------------
--[[
	These ship inside the Roblox client. Swap any of them for a Creator
	Store id ("rbxassetid://123456") once the cube collection gives each cube
	its own turning sound (M2).
]]
Config.Sounds = {
	-- An empty id means "no sound".
	Turn = "rbxasset://sounds/switch.wav",
	Perfect = "rbxasset://sounds/snap.wav",
	Wrong = "rbxasset://sounds/uuhhh.mp3",
	Solve = "rbxasset://sounds/victory.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	TurnVolume = 0.6,
	SolveVolume = 0.8,
}

--------------------------------------------------------------------------------
-- Boxes: the cube gacha
--------------------------------------------------------------------------------
--[[
	A box costs coins and hatches one cube. The tier is rolled from the
	box's odds (they add up to 100); the cube is then picked evenly from
	that tier (Defs/Cubes.luau). A cube you already own still counts: the
	copy total is what golden variants and trading will build on (M4).
	A hatched cube is equipped automatically when its multiplier beats
	the one you have on.
]]
Config.Boxes = {
	-- Tier colours (cards, the hatch burst) and the multiplier range each
	-- tier's cubes are expected to sit in.
	Tiers = {
		Common = { Color = Color3.fromRGB(170, 178, 190), Range = { 1.0, 1.05 } },
		Rare = { Color = Color3.fromRGB(86, 156, 236), Range = { 1.1, 1.15 } },
		Epic = { Color = Color3.fromRGB(190, 90, 255), Range = { 1.25, 1.25 } },
		Legendary = { Color = Color3.fromRGB(255, 200, 60), Range = { 1.5, 1.5 } },
	},
	TierOrder = { "Common", "Rare", "Epic", "Legendary" },
	List = {
		{
			id = "Basic",
			name = "Basic Box",
			cost = 150,
			odds = { Common = 70, Rare = 25, Epic = 5, Legendary = 0 },
		},
		{
			id = "Pro",
			name = "Pro Box",
			cost = 600,
			odds = { Common = 30, Rare = 45, Epic = 20, Legendary = 5 },
		},
	},
	MaxMult = 1.5, -- no cube may multiply coins by more than this (the CEO's cap)
}

--------------------------------------------------------------------------------
-- Hatch: the box-opening animation (client only)
--------------------------------------------------------------------------------
Config.Hatch = {
	DropSeconds = 0.35, -- the box falls onto the pedestal
	DropHeight = 6,
	ShakeSeconds = 0.9, -- then rattles, harder and harder
	ShakeStuds = 0.25,
	RevealSeconds = 0.4, -- the cube pops out and swells
	HoldSeconds = 0.9, -- the name card stays before play resumes
	Particles = 70,
	BoxColor = Color3.fromRGB(70, 50, 30),
	LidColor = Color3.fromRGB(231, 174, 58),
}

--------------------------------------------------------------------------------
-- Products: Robux purchases (developer products)
--------------------------------------------------------------------------------
--[[
	Create each product on the Creator Dashboard (Monetization -> Developer
	Products), paste its id here, and the matching button appears in the
	CUBES screen. An id of 0 means "not for sale yet"; nothing shows.
	A "coins" product adds coins; a "box" product hatches that many of
	the named box for free. Receipts are remembered so a retried purchase
	is never granted twice.
]]
Config.Products = {
	{ key = "Coins500", id = 0, kind = "coins", amount = 500, label = "500 coins" },
	{ key = "Coins2500", id = 0, kind = "coins", amount = 2500, label = "2,500 coins" },
	{ key = "ProBox3", id = 0, kind = "box", box = "Pro", amount = 3, label = "3 Pro Boxes" },
}

--------------------------------------------------------------------------------
-- Board: the leaderboard pillar in the middle of the ring
--------------------------------------------------------------------------------
--[[
	Kept LOW on purpose: every camera looks across the ring centre at the
	pedestals opposite. A camera sits about 7 studs up and a cube about
	4.5, so a pillar under ~5 studs never hides anybody's cube.
]]
Config.Board = {
	Width = 9,
	Height = 4.6,
	Lines = 4, -- depth records shown (fastest per depth, deepest first)
	SolverLines = 2, -- most solves this server
	-- Quiet on purpose. Every camera looks ACROSS the middle of the ring, so
	-- this board is directly behind the cube from all eight seats and its
	-- text lands on top of the HUD. It is a thing you glance at between
	-- solves, not a thing that should compete with the cube.
	TextSize = 17,
	TextColor = Color3.fromRGB(150, 162, 180),
	Color = Color3.fromRGB(30, 32, 40),
	-- NOT bright, and not gold any more. This is the top face of a
	-- nine-stud-wide slab: from a camera looking down at 30 degrees you see
	-- the whole square, so anything eye-catching here is a big blank
	-- rectangle hanging in the middle of the hall saying nothing.
	TrimColor = Color3.fromRGB(52, 58, 74),
}

--------------------------------------------------------------------------------
-- Save
--------------------------------------------------------------------------------
Config.Save = {
	DataStoreName = "SpeedCubeSave",
	KeyPrefix = "player_",
	SchemaVersion = 2, -- 2: cubes, equipped, receipts
	ReceiptsKept = 50, -- purchase ids remembered per player
	AutosaveSeconds = 90,
	LoadRetries = 3,
	RetryDelay = 1.5,
}

return Config
