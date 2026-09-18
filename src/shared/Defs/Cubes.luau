--!strict
--[[
	Cubes.luau -- every cube a box can hatch.

	A cube is a LOOK (body colour, six sticker colours, stickerless or
	not, what glows), a turning SOUND, and a coin MULTIPLIER. The Classic
	cube is owned by everyone from the start and is the baseline look the
	whole game was built on.

	Tiers, their colours and the box odds live in Config.Boxes. A cube's
	`mult` should stay inside its tier's range noted there; the best cube
	in the game multiplies coins by 1.5, no more (the CEO's cap).

	Sounds are Roblox built-ins for now. Swap for Creator Store ids
	("rbxassetid://...") when the cubes get their own.
]]

local Cubes = {}

export type Look = {
	body: Color3,
	stickers: { [string]: Color3 }, -- U D F B R L
	stickerless: boolean, -- true: the colour fills the whole face, no black border
	glow: string, -- "none" | "stickers" | "all"
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
	-- Common ------------------------------------------------------------
	{
		id = "Classic",
		name = "Classic",
		tier = "Common",
		mult = 1.0,
		look = { body = rgb(20, 20, 24), stickers = CLASSIC, stickerless = false, glow = "none" },
		sound = SWITCH,
		blurb = "The one everybody starts with.",
	},
	{
		id = "Frost",
		name = "Frost",
		tier = "Common",
		mult = 1.02,
		look = {
			body = rgb(235, 240, 248),
			stickers = palette(
				rgb(255, 255, 255),
				rgb(190, 215, 245),
				rgb(120, 200, 230),
				rgb(80, 130, 210),
				rgb(160, 180, 240),
				rgb(210, 230, 255)
			),
			stickerless = false,
			glow = "none",
		},
		sound = SWITCH,
		blurb = "White body, cold colours.",
	},
	{
		id = "Ember",
		name = "Ember",
		tier = "Common",
		mult = 1.03,
		look = {
			body = rgb(60, 18, 14),
			stickers = palette(
				rgb(255, 230, 160),
				rgb(255, 170, 40),
				rgb(255, 110, 40),
				rgb(200, 40, 30),
				rgb(255, 60, 60),
				rgb(255, 140, 90)
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
			body = rgb(22, 40, 34),
			stickers = palette(
				rgb(240, 255, 245),
				rgb(180, 240, 200),
				rgb(90, 220, 160),
				rgb(40, 160, 130),
				rgb(130, 230, 210),
				rgb(200, 250, 220)
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
			body = rgb(40, 42, 48),
			stickers = palette(
				rgb(220, 222, 228),
				rgb(160, 164, 172),
				rgb(120, 126, 136),
				rgb(80, 86, 96),
				rgb(190, 194, 200),
				rgb(140, 146, 156)
			),
			stickerless = false,
			glow = "none",
		},
		sound = BUTTON,
		blurb = "Six greys. Very serious.",
	},
	-- Rare (stickerless) -------------------------------------------------
	{
		id = "Pastel",
		name = "Pastel",
		tier = "Rare",
		mult = 1.1,
		look = {
			body = rgb(250, 250, 250),
			stickers = palette(
				rgb(255, 250, 220),
				rgb(255, 230, 160),
				rgb(190, 240, 200),
				rgb(180, 210, 255),
				rgb(255, 180, 190),
				rgb(255, 205, 160)
			),
			stickerless = true,
			glow = "none",
		},
		sound = SNAP,
		blurb = "Stickerless, soft colours.",
	},
	{
		id = "Ocean",
		name = "Ocean",
		tier = "Rare",
		mult = 1.12,
		look = {
			body = rgb(10, 30, 50),
			stickers = palette(
				rgb(200, 240, 255),
				rgb(20, 90, 140),
				rgb(40, 170, 200),
				rgb(20, 60, 120),
				rgb(60, 200, 220),
				rgb(90, 130, 200)
			),
			stickerless = true,
			glow = "none",
		},
		sound = SNAP,
		blurb = "Deep blues, stickerless.",
	},
	{
		id = "Sunset",
		name = "Sunset",
		tier = "Rare",
		mult = 1.13,
		look = {
			body = rgb(50, 20, 40),
			stickers = palette(
				rgb(255, 220, 120),
				rgb(255, 150, 60),
				rgb(255, 100, 90),
				rgb(180, 60, 120),
				rgb(255, 80, 130),
				rgb(255, 170, 100)
			),
			stickerless = true,
			glow = "none",
		},
		sound = SNAP,
		blurb = "Orange to pink, stickerless.",
	},
	{
		id = "Jelly",
		name = "Jelly",
		tier = "Rare",
		mult = 1.15,
		look = {
			body = rgb(30, 30, 40),
			stickers = palette(
				rgb(240, 255, 120),
				rgb(255, 120, 200),
				rgb(120, 255, 200),
				rgb(120, 160, 255),
				rgb(255, 120, 120),
				rgb(200, 120, 255)
			),
			stickerless = true,
			glow = "none",
		},
		sound = PING,
		blurb = "Candy colours, stickerless.",
	},
	-- Epic (glowing stickers) --------------------------------------------
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
				rgb(255, 120, 255),
				rgb(180, 60, 255),
				rgb(120, 200, 255),
				rgb(80, 80, 255),
				rgb(255, 80, 200),
				rgb(200, 120, 255)
			),
			stickerless = false,
			glow = "stickers",
		},
		sound = PING,
		blurb = "Purple and pink, glowing.",
	},
	{
		id = "Void",
		name = "Void",
		tier = "Epic",
		mult = 1.25,
		look = {
			body = rgb(6, 6, 8),
			stickers = palette(
				rgb(200, 200, 210),
				rgb(120, 100, 200),
				rgb(90, 60, 180),
				rgb(50, 30, 120),
				rgb(150, 90, 230),
				rgb(80, 60, 150)
			),
			stickerless = false,
			glow = "stickers",
		},
		sound = PING,
		blurb = "Almost black. The stickers hum.",
	},
	-- Legendary ------------------------------------------------------------
	{
		id = "Prism",
		name = "Prism",
		tier = "Legendary",
		mult = 1.5,
		look = {
			body = rgb(255, 255, 255),
			stickers = palette(
				rgb(255, 255, 255),
				rgb(255, 230, 80),
				rgb(80, 255, 160),
				rgb(80, 160, 255),
				rgb(255, 80, 120),
				rgb(255, 160, 60)
			),
			stickerless = false,
			glow = "all",
		},
		sound = "rbxasset://sounds/victory.wav",
		blurb = "The whole cube glows. Coins x1.5.",
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
