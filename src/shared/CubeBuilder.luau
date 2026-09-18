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

--[[
	Restyle every cubie of a built cube to `look`.
]]
function CubeBuilder.applyLook(cube: Cube, look: Cubes.Look)
	local inset = if look.stickerless then 0.015 else Config.Cube.StickerInset
	local glowStickers = look.glow == "stickers" or look.glow == "all"
	for _, cubie in cube.cubies do
		local part = cubie.part
		part.Color = look.body
		part.Material = if look.glow == "all"
			then Enum.Material.Neon
			else Enum.Material.SmoothPlastic
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") then
				local face = string.sub(child.Name, -1)
				local color = look.stickers[face] or look.body
				local fill = child:FindFirstChild("Fill") :: Frame
				fill.BackgroundColor3 = color
				fill.Size = UDim2.fromScale(1 - inset * 2, 1 - inset * 2)
				fill.Position = UDim2.fromScale(inset, inset)
				local corner = fill:FindFirstChild("Corner") :: UICorner
				corner.CornerRadius = UDim.new(if look.stickerless then 0.04 else 0.12, 0)
				local glow = fill:FindFirstChild("Glow") :: UIStroke
				glow.Color = color
				glow.Enabled = glowStickers
				child.LightInfluence = if glowStickers then 0 else 0.6
				child.Brightness = if glowStickers
					then Config.Cube.GlowStickerBrightness
					else Config.Cube.StickerBrightness
			end
		end
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

	local cube: Cube = { model = model, cubies = cubies, pitch = pitch }
	local classic = Cubes.get(Cubes.Default)
	CubeBuilder.applyLook(cube, look or (classic :: Cubes.Def).look)
	model.Parent = parent
	return cube
end

return CubeBuilder
