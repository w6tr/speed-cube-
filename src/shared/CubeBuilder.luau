--!strict
--[[
	CubeBuilder.luau -- makes the 26 little cubes ("cubies") of a 3x3 cube,
	and restyles them.

	One Part per cubie. The coloured stickers are SurfaceGuis (a flat
	picture painted on a face of a part) so a cubie is ONE part to move,
	not seven. Every cubie remembers its "home" position -- where it sits
	when the cube is solved -- relative to the cube's centre.

	A LOOK (Defs/Cubes.luau) is body colour, six sticker colours, whether
	the cube is stickerless (the colour fills the whole face) and what
	glows. `applyLook` restyles a built cube in place, so equipping a cube
	never rebuilds anything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cubes = require(Shared:WaitForChild("Defs"):WaitForChild("Cubes"))

local CubeBuilder = {}

export type Cubie = {
	part: Part,
	home: CFrame, -- solved position, relative to the cube centre
}

export type Cube = {
	model: Model,
	cubies: { Cubie },
	pitch: number, -- centre-to-centre distance between neighbouring cubies
	core: Part, -- invisible, at the cube's centre: the lamp inside a look lives here
}

-- Which sticker goes on which side of a cubie at grid position (x, y, z).
local FACES: { { normal: Enum.NormalId, axis: string, sign: number, face: string } } = {
	{ normal = Enum.NormalId.Top, axis = "Y", sign = 1, face = "U" },
	{ normal = Enum.NormalId.Bottom, axis = "Y", sign = -1, face = "D" },
	{ normal = Enum.NormalId.Back, axis = "Z", sign = 1, face = "F" }, -- Roblox's "Back" is +Z: our front
	{ normal = Enum.NormalId.Front, axis = "Z", sign = -1, face = "B" },
	{ normal = Enum.NormalId.Right, axis = "X", sign = 1, face = "R" },
	{ normal = Enum.NormalId.Left, axis = "X", sign = -1, face = "L" },
}

local function sticker(part: Part, normal: Enum.NormalId, face: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Sticker_{face}`
	gui.Face = normal
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(100, 100)
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Fill"
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.Name = "Corner"
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Glow"
	stroke.Thickness = 6
	stroke.Transparency = 0.35
	stroke.Enabled = false
	stroke.Parent = frame
end

local function shaded(color: Color3, amount: number): Color3
	if amount > 1 then
		return color:Lerp(Color3.new(1, 1, 1), math.min(1, amount - 1))
	elseif amount < 1 then
		return color:Lerp(Color3.new(0, 0, 0), math.min(1, 1 - amount))
	end
	return color
end

-- A look with `shade` is lit by height: the top row gets `top`, the bottom
-- row `bottom`, the middle row halfway. It is what makes a glossy Rare
-- read as one object with light on it rather than six flat colours.
local function shadeAt(look: Cubes.Look, homeY: number, pitch: number): number
	local shade = look.shade
	if not shade then
		return 1
	end
	local t = (homeY / pitch + 1) / 2
	return shade.bottom + (shade.top - shade.bottom) * t
end

-- A glossy look paints a hard highlight into the top corner of every
-- sticker: the crisp white spot light leaves on hard candy. The engine's
-- own specular does not show from the locked camera; this does.
local function sheen(fill: Frame, on: boolean)
	local spot = fill:FindFirstChild("Sheen")
	if not on then
		if spot then
			spot:Destroy()
		end
		return
	end
	if not spot then
		local frame = Instance.new("Frame")
		frame.Name = "Sheen"
		frame.AnchorPoint = Vector2.new(0, 0)
		frame.Position = UDim2.fromScale(0.1, 0.09)
		frame.Size = UDim2.fromScale(0.34, 0.2)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 0.22
		frame.BorderSizePixel = 0
		frame.ZIndex = 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 0
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = fill
	end
end

-- A gummy look darkens the edge of every sticker, the way light leaves
-- the rim of a jelly sweet, so the translucency reads even from a
-- camera that cannot see through the cube.
local function rim(fill: Frame, color: Color3, on: boolean)
	local edge = fill:FindFirstChild("Rim")
	if not on then
		if edge then
			edge:Destroy()
		end
		return
	end
	local stroke = if edge and edge:IsA("UIStroke") then edge else Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.5)
	stroke.Thickness = 6
	stroke.Transparency = 0.1
	stroke.Parent = fill
end

-- A prismatic look sweeps the hue across the whole cube, corner to
-- corner, so one frozen frame shows the spectrum and not three flat
-- colours: the stickers step through the wheel by where they sit.
local function spectral(look: Cubes.Look, color: Color3, home: CFrame, pitch: number): Color3
	if not look.prismatic then
		return color
	end
	local p = home.Position
	local t = ((p.X + p.Y + p.Z) / pitch + 3) / 6
	local h, s, v = color:ToHSV()
	return Color3.fromHSV((h + t * 0.5) % 1, s, v)
end

-- A sparkling look throws slow white sparks off the cube's surface.
local function sparkle(core: Part, on: boolean)
	local emitter = core:FindFirstChildOfClass("ParticleEmitter")
	if not on then
		if emitter then
			emitter:Destroy()
		end
		return
	end
	if emitter then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkle"
	e.Rate = 28
	e.Lifetime = NumberRange.new(0.9, 1.6)
	e.Speed = NumberRange.new(0.6, 1.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.34),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 255))
	e.Parent = core
end

-- The colour a sticker gets under `look`: the face's colour, shaded by
-- height and swept through the spectrum if the look asks for either.
local function stickerColor(look: Cubes.Look, face: string, home: CFrame, pitch: number): Color3
	local base = look.stickers[face] or look.body
	return spectral(look, shaded(base, shadeAt(look, home.Y, pitch)), home, pitch)
end

--[[
	Restyle every cubie of a built cube to `look`.

	Each sticker remembers its base brightness and colour as attributes,
	so the view can brighten the row about to turn and walk a prismatic
	cube's hues without asking this file again.
]]
function CubeBuilder.applyLook(cube: Cube, look: Cubes.Look)
	local inset = look.stickerInset
		or (if look.stickerless then 0.015 else Config.Cube.StickerInset)
	local glowStickers = look.glow == "stickers" or look.glow == "all"
	local glowBody = look.glow == "all" or look.glow == "body"
	local material = look.bodyMaterial
		or (if glowBody then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	local transparency = look.bodyTransparency or 0
	local brightness = if glowStickers
		then (look.glowBrightness or Config.Cube.GlowStickerBrightness)
		else Config.Cube.StickerBrightness
	for _, cubie in cube.cubies do
		local part = cubie.part
		part.Color = look.body
		part.Material = material
		part.Transparency = transparency
		part.Reflectance = look.reflectance or 0
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") then
				local face = string.sub(child.Name, -1)
				local color = stickerColor(look, face, cubie.home, cube.pitch)
				local fill = child:FindFirstChild("Fill") :: Frame
				fill.BackgroundColor3 = color
				-- A see-through body needs see-through faces, or the
				-- transparency only ever shows in the gaps.
				fill.BackgroundTransparency = if look.stickerless then transparency else 0
				fill.Size = UDim2.fromScale(1 - inset * 2, 1 - inset * 2)
				fill.Position = UDim2.fromScale(inset, inset)
				local corner = fill:FindFirstChild("Corner") :: UICorner
				corner.CornerRadius = UDim.new(if look.stickerless then 0.04 else 0.12, 0)
				local glow = fill:FindFirstChild("Glow") :: UIStroke
				glow.Color = color
				glow.Enabled = glowStickers
				sheen(fill, look.gloss == true)
				rim(fill, color, look.rim == true)
				-- Matte stickers take less of the hall's key light than they
				-- did: their top faces were washing out to white.
				child.LightInfluence = if glowStickers then 0 else 0.45
				child.Brightness = brightness
				child:SetAttribute("BaseBrightness", brightness)
				child:SetAttribute("BaseColor", color)
			end
		end
	end

	sparkle(cube.core, look.sparkle == true)

	local light = look.light
	local existing = cube.core:FindFirstChildOfClass("PointLight")
	if light then
		local lamp = existing or Instance.new("PointLight")
		lamp.Shadows = false
		lamp.Color = light.color
		lamp.Brightness = light.brightness
		lamp.Range = light.range
		lamp.Parent = cube.core
	elseif existing then
		existing:Destroy()
	end
end

--[[
	Build a solved cube centred on `root`, styled as `look` (the Classic
	cube when nil). Every part is anchored and ignores collisions and
	clicks; the cube is a picture, not a physics object.
]]
function CubeBuilder.build(parent: Instance, name: string, root: CFrame, look: Cubes.Look?): Cube
	local size = Config.Cube.CubieSize
	local pitch = size + Config.Cube.Gap

	local model = Instance.new("Model")
	model.Name = name

	local cubies: { Cubie } = {}
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					local part = Instance.new("Part")
					part.Name = `Cubie_{x}_{y}_{z}`
					part.Size = Vector3.new(size, size, size)
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.CastShadow = false
					local home = CFrame.new(x * pitch, y * pitch, z * pitch)
					part.CFrame = root * home
					part.Parent = model

					local grid = { X = x, Y = y, Z = z }
					for _, face in FACES do
						if grid[face.axis] == face.sign then
							sticker(part, face.normal, face.face)
						end
					end
					table.insert(cubies, { part = part, home = home })
				end
			end
		end
	end

	-- The core spans the whole cube: a lamp inside sits at its centre, and
	-- a sparkling look throws its sparks from its surface.
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = Vector3.one * (size * 3 + Config.Cube.Gap * 2)
	core.Transparency = 1
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.CFrame = root
	core.Parent = model

	local cube: Cube = { model = model, cubies = cubies, pitch = pitch, core = core }
	local classic = Cubes.get(Cubes.Default)
	CubeBuilder.applyLook(cube, look or (classic :: Cubes.Def).look)
	model.Parent = parent
	return cube
end

--[[
	A cube for a ViewportFrame (the CUBES screen's cards). Viewports draw
	parts and nothing else -- no SurfaceGuis, no lights, no particles --
	so the stickers here are thin parts on each face instead of paint.
	`locked` draws the cube as a dark silhouette: the shape you have not
	earned yet, in the colour of nothing.
]]
function CubeBuilder.buildPreview(parent: Instance, look: Cubes.Look, locked: boolean): Model
	local size = Config.Cube.CubieSize
	local gap = Config.Cube.Gap
	local pitch = size + gap
	local inset = look.stickerInset
		or (if look.stickerless then 0.015 else Config.Cube.StickerInset)
	local glowStickers = look.glow == "stickers" or look.glow == "all"
	local glowBody = look.glow == "all" or look.glow == "body"

	local model = Instance.new("Model")
	model.Name = "Preview"
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				if x ~= 0 or y ~= 0 or z ~= 0 then
					local home = CFrame.new(x * pitch, y * pitch, z * pitch)
					local part = Instance.new("Part")
					part.Name = `Cubie_{x}_{y}_{z}`
					part.Size = Vector3.new(size, size, size)
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CastShadow = false
					part.Color = if locked then Color3.fromRGB(14, 14, 18) else look.body
					part.Material = if not locked
							and (
								look.bodyMaterial or (if glowBody then Enum.Material.Neon else nil)
							)
						then (look.bodyMaterial or Enum.Material.Neon)
						else Enum.Material.SmoothPlastic
					part.CFrame = home
					part.Parent = model

					local grid = { X = x, Y = y, Z = z }
					for _, face in FACES do
						if grid[face.axis] == face.sign then
							local slab = Instance.new("Part")
							slab.Name = `Sticker_{face.face}`
							slab.Anchored = true
							slab.CanCollide = false
							slab.CanQuery = false
							slab.CastShadow = false
							local span = size * (1 - inset * 2)
							local normal = Vector3.new(
								if face.axis == "X" then face.sign else 0,
								if face.axis == "Y" then face.sign else 0,
								if face.axis == "Z" then face.sign else 0
							)
							slab.Size = Vector3.new(
								if normal.X ~= 0 then 0.02 else span,
								if normal.Y ~= 0 then 0.02 else span,
								if normal.Z ~= 0 then 0.02 else span
							)
							slab.CFrame = home * CFrame.new(normal * (size / 2 + 0.01))
							slab.Color = if locked
								then Color3.fromRGB(28, 28, 34)
								else stickerColor(look, face.face, home, pitch)
							slab.Material = if not locked and glowStickers
								then Enum.Material.Neon
								else Enum.Material.SmoothPlastic
							slab.Parent = model
						end
					end
				end
			end
		end
	end
	model.Parent = parent
	return model
end

return CubeBuilder
