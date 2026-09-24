--!strict
--[[
	Cubes.luau -- every cube a box can hatch.

	A cube is a LOOK (body, six sticker colours, the finish), a turning
	SOUND, and a coin MULTIPLIER. The Classic cube is owned by everyone
	from the start and is the baseline look the whole game was built on.

	THE LADDER HAS TO READ WITHOUT A LABEL. The critic's first pass
	(2026-09-24, art/critic-log.md) scored the set a 5 because a Rare
	looked like a recoloured Common and the Legendary looked like an
	overexposed photo. So each tier now owns a FINISH, not just a palette:

	  Common     matte plastic, toy colours, a black body
	  Rare       candy: a painted gloss highlight on every sticker, shaded
	             lighter on top; Jelly is see-through
	  Epic       light coming OUT of the cube: glowing stickers, or --
	             Void -- a near-black cube leaking violet from thin seams
	  Legendary  a rainbow across every face: the hue sweeps corner to
	             corner over the whole cube so one frame shows the whole
	             spectrum, glowing brighter than any Epic, sparks off it,
	             a halo on the mat, and the client walks the hues round

	Every tier ADDS something the tier below does not have; nothing at a
	higher tier ever has less than the one under it (the critic's second
	round, and Pet Simulator 99's rule).

	Tiers, their colours and the box odds live in Config.Boxes. A cube's
	`mult` should stay inside its tier's range noted there; the best cube
	in the game multiplies coins by 1.5, no more (the CEO's cap).

	The arrow prompt is hot magenta (Config.Cube.Arrow). No sticker in
	this file may sit in that hue: the arrow has to read on every face of
	every cube, and per-cube arrow colours (M4) do not change that rule.

	Sounds are Roblox built-ins for now. Swap for Creator Store ids
	("rbxassetid://...") when the cubes get their own.
]]

local Cubes = {}

export type Look = {
	body: Color3,
	stickers: { [string]: Color3 }, -- U D F B R L
	stickerless: boolean, -- true: the colour fills the whole face, no black border
	glow: string, -- "none" | "stickers" | "body" | "all"
	-- The finish. Everything below is optional and defaults to the Classic answer.
	bodyMaterial: Enum.Material?, -- SmoothPlastic. Glass for gloss; Neon for a body that glows.
	bodyTransparency: number?, -- 0. A little on Jelly, so you can nearly see into it.
	reflectance: number?, -- 0
	shade: { top: number, bottom: number }?, -- brightness by height: { 1.2, 0.8 } lightens the top row
	glowBrightness: number?, -- Config.Cube.GlowStickerBrightness. The Prism uses less, so its faces keep their colour.
	light: { color: Color3, brightness: number, range: number }?, -- a lamp inside the cube
	prismatic: boolean?, -- the client slowly cycles the sticker hues
	gloss: boolean?, -- a hard white highlight painted into the corner of every sticker
	rim: boolean?, -- a darker rim round every sticker, the way light leaves the edge of a gummy
	stickerInset: number?, -- overrides the sticker margin (Config.Cube.StickerInset)
	sparkle: boolean?, -- white sparks off the surface, and a halo on the mat
}

export type Def = {
	id: string,
	name: string,
	tier: string, -- Common | Rare | Epic | Legendary
	mult: number,
	look: Look,
	sound: string, -- the turning sound
	blurb: string, -- one line on the collection card
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function palette(u, d, f, b, r, l): { [string]: Color3 }
	return { U = u, D = d, F = f, B = b, R = r, L = l }
end

local BLACK = rgb(20, 20, 24)

local CLASSIC = palette(
	rgb(245, 245, 245),
	rgb(250, 220, 40),
	rgb(40, 190, 80),
	rgb(40, 100, 230),
	rgb(230, 50, 50),
	rgb(250, 130, 30)
)

local SWITCH = "rbxasset://sounds/switch.wav"
local SNAP = "rbxasset://sounds/snap.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"

local LIST: { Def } = {
	-- Common: matte plastic, toy colours, a black body ----------------------
	{
		id = "Classic",
		name = "Classic",
		tier = "Common",
		mult = 1.0,
		look = { body = BLACK, stickers = CLASSIC, stickerless = false, glow = "none" },
		sound = SWITCH,
		blurb = "The one everybody starts with.",
	},
	{
		id = "Frost",
		name = "Frost",
		tier = "Common",
		mult = 1.02,
		look = {
			body = BLACK,
			stickers = palette(
				rgb(255, 255, 255),
				rgb(110, 200, 255),
				rgb(60, 170, 255),
				rgb(40, 120, 240),
				rgb(150, 215, 255),
				rgb(215, 240, 255)
			),
			stickerless = false,
			glow = "none",
		},
		sound = SWITCH,
		blurb = "Ice blues on black.",
	},
	{
		id = "Ember",
		name = "Ember",
		tier = "Common",
		mult = 1.03,
		look = {
			body = rgb(60, 18, 14),
			stickers = palette(
				rgb(255, 235, 170),
				rgb(255, 175, 40),
				rgb(255, 110, 40),
				rgb(210, 40, 30),
				rgb(255, 60, 60),
				rgb(255, 145, 90)
			),
			stickerless = false,
			glow = "none",
		},
		sound = SWITCH,
		blurb = "Warm colours on a dark red body.",
	},
	{
		id = "Mint",
		name = "Mint",
		tier = "Common",
		mult = 1.04,
		look = {
			body = rgb(14, 40, 30),
			stickers = palette(
				rgb(235, 255, 245),
				rgb(120, 240, 170),
				rgb(30, 210, 120),
				rgb(10, 150, 110),
				rgb(80, 230, 200),
				rgb(170, 250, 200)
			),
			stickerless = false,
			glow = "none",
		},
		sound = SWITCH,
		blurb = "Fresh greens.",
	},
	{
		id = "Slate",
		name = "Slate",
		tier = "Common",
		mult = 1.05,
		look = {
			body = rgb(54, 48, 46),
			stickers = palette(
				rgb(245, 240, 232),
				rgb(160, 150, 140),
				rgb(120, 110, 102),
				rgb(78, 70, 64),
				rgb(215, 205, 195),
				rgb(140, 130, 122)
			),
			stickerless = false,
			glow = "none",
		},
		sound = BUTTON,
		blurb = "Six warm greys. Very serious.",
	},
	-- Rare: glossy candy, stickerless, lighter on top ------------------------
	{
		id = "Pastel",
		name = "Pastel",
		tier = "Rare",
		mult = 1.1,
		look = {
			body = rgb(215, 212, 222),
			stickers = palette(
				rgb(255, 232, 80),
				rgb(255, 120, 170),
				rgb(100, 230, 160),
				rgb(100, 175, 255),
				rgb(175, 130, 255),
				rgb(255, 165, 100)
			),
			stickerless = true,
			glow = "none",
			gloss = true,
			shade = { top = 1.05, bottom = 0.95 },
		},
		sound = SNAP,
		blurb = "Lemon, bubblegum, mint, sky, lilac, peach.",
	},
	{
		id = "Ocean",
		name = "Ocean",
		tier = "Rare",
		mult = 1.12,
		look = {
			body = rgb(8, 28, 52),
			stickers = palette(
				rgb(190, 235, 255),
				rgb(20, 80, 150),
				rgb(30, 160, 220),
				rgb(16, 60, 140),
				rgb(50, 210, 235),
				rgb(80, 120, 210)
			),
			stickerless = true,
			glow = "none",
			gloss = true,
			shade = { top = 1.35, bottom = 0.7 },
		},
		sound = SNAP,
		blurb = "Deep blue, lighter at the surface.",
	},
	{
		id = "Sunset",
		name = "Sunset",
		tier = "Rare",
		mult = 1.13,
		look = {
			body = rgb(50, 20, 40),
			stickers = palette(
				rgb(255, 225, 110),
				rgb(255, 80, 160),
				rgb(255, 120, 60),
				rgb(200, 60, 140),
				rgb(255, 90, 110),
				rgb(255, 160, 70)
			),
			stickerless = true,
			glow = "none",
			gloss = true,
			shade = { top = 1.2, bottom = 0.8 },
		},
		sound = SNAP,
		blurb = "Orange at the top, pink at the bottom.",
	},
	{
		id = "Jelly",
		name = "Jelly",
		tier = "Rare",
		mult = 1.15,
		look = {
			body = rgb(62, 18, 110),
			stickers = palette(
				rgb(215, 150, 255),
				rgb(120, 40, 220),
				rgb(175, 90, 255),
				rgb(140, 60, 235),
				rgb(195, 120, 255),
				rgb(155, 75, 245)
			),
			stickerless = true,
			glow = "none",
			gloss = true,
			rim = true,
			bodyMaterial = Enum.Material.Glass,
			bodyTransparency = 0.4,
			shade = { top = 1.2, bottom = 0.85 },
		},
		sound = PING,
		blurb = "Grape gummy. Light gets in.",
	},
	-- Epic: light coming out of the cube -----------------------------------
	{
		id = "Neon",
		name = "Neon",
		tier = "Epic",
		mult = 1.25,
		look = {
			body = rgb(12, 12, 16),
			stickers = palette(
				rgb(255, 255, 255),
				rgb(255, 255, 60),
				rgb(60, 255, 120),
				rgb(60, 140, 255),
				rgb(255, 60, 80),
				rgb(255, 150, 40)
			),
			stickerless = false,
			glow = "stickers",
		},
		sound = PING,
		blurb = "The classic colours, lit up.",
	},
	{
		id = "Plasma",
		name = "Plasma",
		tier = "Epic",
		mult = 1.25,
		look = {
			body = rgb(16, 10, 24),
			stickers = palette(
				rgb(230, 200, 255),
				rgb(160, 60, 255),
				rgb(90, 220, 255),
				rgb(70, 90, 255),
				rgb(200, 90, 255),
				rgb(140, 160, 255)
			),
			stickerless = false,
			glow = "stickers",
		},
		sound = PING,
		blurb = "Violet and cyan, glowing.",
	},
	{
		id = "Void",
		name = "Void",
		tier = "Epic",
		mult = 1.25,
		look = {
			-- The body glows a deep violet and the stickers are nearly
			-- black and nearly edge to edge, so what leaks out is a thin
			-- violet seam: the cube that looks like it is hiding something.
			body = rgb(96, 20, 160),
			stickers = palette(
				rgb(30, 24, 40),
				rgb(20, 14, 30),
				rgb(26, 20, 36),
				rgb(16, 12, 24),
				rgb(34, 24, 46),
				rgb(24, 18, 34)
			),
			stickerless = false,
			stickerInset = 0.045,
			glow = "body",
			light = { color = rgb(160, 70, 255), brightness = 1.2, range = 5 },
		},
		sound = PING,
		blurb = "Almost black. Something violet inside.",
	},
	-- Legendary ------------------------------------------------------------
	{
		id = "Prism",
		name = "Prism",
		tier = "Legendary",
		mult = 1.5,
		look = {
			body = rgb(40, 40, 52),
			stickers = palette(
				rgb(255, 60, 60),
				rgb(255, 150, 40),
				rgb(255, 230, 60),
				rgb(60, 230, 90),
				rgb(60, 150, 255),
				rgb(170, 80, 255)
			),
			stickerless = false,
			glow = "stickers",
			glowBrightness = 2.4,
			bodyMaterial = Enum.Material.Metal,
			reflectance = 0.35,
			light = { color = rgb(255, 255, 255), brightness = 2.6, range = 9 },
			prismatic = true,
			sparkle = true,
		},
		sound = "rbxasset://sounds/victory.wav",
		blurb = "A rainbow across every face, drifting. Coins x1.5.",
	},
}

local BY_ID: { [string]: Def } = {}
for _, def in LIST do
	BY_ID[def.id] = def
end

Cubes.List = LIST
Cubes.Default = "Classic"

function Cubes.get(id: string): Def?
	return BY_ID[id]
end

function Cubes.multOf(id: string?): number
	local def = if id then BY_ID[id] else nil
	return if def then def.mult else 1
end

function Cubes.ofTier(tier: string): { Def }
	local out: { Def } = {}
	for _, def in LIST do
		if def.tier == tier then
			table.insert(out, def)
		end
	end
	return out
end

return Cubes
