--!strict
--[[
	CubeBuilder.luau -- makes the 26 little cubes ("cubies") of a 3x3 cube.

	One Part per cubie, black. The coloured stickers are SurfaceGuis (a flat
	picture painted on a face of a part) so a cubie is ONE part to move,
	not seven. Every cubie remembers its "home" position -- where it sits
	when the cube is solved -- relative to the cube's centre.

	Used twice: the server builds a still, solved cube on every pedestal so
	other players see something there; the client builds its own live cube
	on top of its pedestal and hides the server's still one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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

-- Which sticker colour goes on which side of a cubie at grid position (x, y, z).
local FACES: { { normal: Enum.NormalId, axis: string, sign: number, color: string } } = {
	{ normal = Enum.NormalId.Top, axis = "Y", sign = 1, color = "U" },
	{ normal = Enum.NormalId.Bottom, axis = "Y", sign = -1, color = "D" },
	{ normal = Enum.NormalId.Back, axis = "Z", sign = 1, color = "F" }, -- Roblox's "Back" is +Z: our front
	{ normal = Enum.NormalId.Front, axis = "Z", sign = -1, color = "B" },
	{ normal = Enum.NormalId.Right, axis = "X", sign = 1, color = "R" },
	{ normal = Enum.NormalId.Left, axis = "X", sign = -1, color = "L" },
}

local function sticker(part: Part, face: Enum.NormalId, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sticker"
	gui.Face = face
	gui.LightInfluence = 0.6
	gui.Brightness = 1.2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(100, 100)
	gui.Parent = part

	local inset = Config.Cube.StickerInset
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1 - inset * 2, 1 - inset * 2)
	frame.Position = UDim2.fromScale(inset, inset)
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = frame
end

--[[
	Build a solved cube centred on `root`. Every part is anchored and
	ignores collisions and clicks; the cube is a picture, not a physics
	object.
]]
function CubeBuilder.build(parent: Instance, name: string, root: CFrame): Cube
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
					part.Color = Config.Cube.Body
					part.Material = Enum.Material.SmoothPlastic
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
							sticker(part, face.normal, (Config.Cube.Stickers :: any)[face.color])
						end
					end
					table.insert(cubies, { part = part, home = home })
				end
			end
		end
	end

	model.Parent = parent
	return { model = model, cubies = cubies, pitch = pitch }
end

return CubeBuilder
