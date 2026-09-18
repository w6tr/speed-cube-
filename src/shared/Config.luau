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
	Height = 1.9, -- cube centre above the pedestal top (clear of the pedestal when it pops)
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
	Arrow = {
		Offset = 0.18, -- studs in front of the face
		Color = Color3.fromRGB(255, 255, 255),
		WrongColor = Color3.fromRGB(255, 70, 70), -- the arrow flashes this on a wrong swipe
		WrongFlashSeconds = 0.25,
		PulseSeconds = 0.6,
		TextSize = 120,
	},
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
	Colors = {
		Floor = Color3.fromRGB(38, 40, 48),
		Ring = Color3.fromRGB(52, 56, 68),
		Pedestal = Color3.fromRGB(70, 74, 90),
		Trim = Color3.fromRGB(231, 174, 58),
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
	TextSize = 22,
	Color = Color3.fromRGB(30, 32, 40),
	TrimColor = Color3.fromRGB(231, 174, 58),
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
