--!strict
--[[
	Arena.luau -- the hall the ring of stations stands in.

	A speedcubing competition floor, staged like a final: painted floor
	markings, hoardings around the floor, a raked bank of seating, a back
	wall, and a lamp over every station. Built from parts at boot, like
	the ring itself, so there is nothing to import and nothing to lose.

	WHAT IS ACTUALLY ON SCREEN. The camera is locked (CameraRig re-applies
	it every frame), so every player sees the same picture forever. The eye
	sits at Lobby.PedestalHeight + Cube.Height + Camera.Offset.Y -- 9.25
	studs as those are set today, and it MOVES when any of the three do --
	pitched 30 degrees down, with 55 degrees of view. That puts the top of
	the picture 2.5 degrees BELOW the horizon, so the frame's ceiling falls
	about a stud per 23 studs of distance: the engine measures it landing
	on the back wall at y = 6.50, 63 studs out.

	That is the CENTRE of the frame. The corners of a wide screen look
	along rays that fall more slowly -- about y = 7.7 at the back wall on a
	21:9 monitor, 8.2 on an ultrawide. (Roblox's FieldOfView is vertical,
	so a narrow phone screen sees the same height and less width: narrow is
	always the safe case.) Config.Arena.SeenHeight is therefore the height
	below which detail is WORTH building, not a promise that nothing above
	it is ever visible. The wall is 17 studs tall so that the corner case
	stays covered; do not trim it to SeenHeight.

	So this file spends its detail low, and builds everything above cheap
	and plain. The truss and the lamp housings are out of frame during
	play; they exist for the store icon, and for the second before the
	first Sync arrives, when the camera is still Roblox's own and the
	player can look wherever they like.

	Arena owns no state and nothing here ever moves. Reactive lighting
	(the hall answering a combo or a pop) is a later job.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Arena = {}

--------------------------------------------------------------------------------
-- Parts
--------------------------------------------------------------------------------

type PartOptions = {
	shape: Enum.PartType?,
	material: Enum.Material?,
	transparency: number?,
	shadow: boolean?,
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: PartOptions?
): Part
	local o: PartOptions = options or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = o.shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = o.material or Enum.Material.SmoothPlastic
	p.Transparency = o.transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	-- Scenery casting shadows buys nothing here: the hall is lit from
	-- straight above by lamps that, under ShadowMap, cast none anyway.
	p.CastShadow = o.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--[[
	A flat disc lying on the floor. A Roblox cylinder points along its own
	X, so it is turned on its side to lie down.
]]
local function disc(
	parent: Instance,
	name: string,
	radius: number,
	thickness: number,
	y: number,
	color: Color3,
	material: Enum.Material?
): Part
	return part(
		parent,
		name,
		Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		{ shape = Enum.PartType.Cylinder, material = material }
	)
end

--[[
	One segment of a ring of `count` boxes at `radius`, facing the middle:
	the part's Front face (-Z) looks at the centre and its X runs along
	the ring. Each box is widened a little so the seams do not show.
]]
local function ringSegment(
	parent: Instance,
	name: string,
	index: number,
	count: number,
	radius: number,
	y: number,
	height: number,
	thickness: number,
	color: Color3,
	options: PartOptions?
): Part
	local angle = (index - 1) / count * math.pi * 2
	local position = Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
	local width = 2 * math.pi * radius / count + 0.2
	local cframe = CFrame.lookAt(position, Vector3.new(0, y, 0))
	return part(parent, name, Vector3.new(width, height, thickness), cframe, color, options)
end

--------------------------------------------------------------------------------
-- The floor
--------------------------------------------------------------------------------
--[[
	LobbyBuilder already laid the floor slab and the stage disc. This adds
	the competition markings. A ring is a wide disc with a narrower disc
	of floor colour laid on top of it: two parts, where a real ring of
	segments would have cost forty.
]]
local function buildFloor(parent: Instance): number
	local A = Config.Arena
	local floorColor = Config.Lobby.Colors.Floor

	local floor = parent:FindFirstChild("Floor")
	if floor and floor:IsA("Part") then
		floor.Material = A.Floor.Material
	end
	local stage = parent:FindFirstChild("Stage")
	if stage and stage:IsA("Part") then
		stage.Material = A.Floor.StageMaterial
	end

	local markings = Instance.new("Folder")
	markings.Name = "Markings"
	markings.Parent = parent

	-- WIDEST FIRST, and each ring a hair higher than the last. A ring's
	-- filler disc is the full circle of floor colour, so a ring drawn
	-- BELOW a wider ring's filler would be buried by it.
	local lines = table.clone(A.Floor.Lines)
	table.sort(lines, function(a, b)
		return a.Radius > b.Radius
	end)

	local top = 0.02
	for i, line in lines do
		disc(
			markings,
			`Line{i}`,
			line.Radius + line.Width / 2,
			0.08,
			top,
			line.Color,
			if line.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
		disc(markings, `Line{i}Inner`, line.Radius - line.Width / 2, 0.08, top + 0.04, floorColor)
		top += 0.08
	end

	-- The first height free of paint. Anything laid on the floor AFTER
	-- this has to start here: a filler disc is the whole circle of the
	-- floor, so something thinner parked underneath one is not merely
	-- hidden, it is swallowed whole and never drawn. That is exactly what
	-- happened to the station light pools the first time round.
	return top + 0.06
end

--------------------------------------------------------------------------------
-- The hoardings around the competition floor
--------------------------------------------------------------------------------
--[[
	Every camera sits INSIDE this ring (23.5 studs out; the boards are at
	27), so what a player sees is the inner face of the boards on the far
	side. The event name goes there.
]]
local function buildBarrier(parent: Instance)
	local B = Config.Arena.Barrier
	local folder = Instance.new("Folder")
	folder.Name = "Barrier"
	folder.Parent = parent

	for i = 1, B.Segments do
		local board = ringSegment(
			folder,
			`Board{i}`,
			i,
			B.Segments,
			B.Radius,
			B.Height / 2,
			B.Height,
			0.5,
			B.Color
		)
		ringSegment(
			folder,
			`Trim{i}`,
			i,
			B.Segments,
			B.Radius,
			B.Height + B.TrimHeight / 2,
			B.TrimHeight,
			0.56,
			B.TrimColor,
			{ material = Enum.Material.Neon }
		)

		local text = B.Texts[(i - 1) % #B.Texts + 1]
		if text ~= "" then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Hoarding"
			gui.Face = Enum.NormalId.Front -- the face looking at the middle
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 24
			gui.LightInfluence = 0.15
			gui.Parent = board

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(0.92, 0.7)
			label.Position = UDim2.fromScale(0.04, 0.15)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			-- Scaled, not fixed: a board is only 174 pixels of canvas wide and
			-- "SPEED CUBE OPEN" at a fixed 38px is about twice that. Roblox
			-- does not clip overflowing text, so it would hang off both ends
			-- of the board and float in front of its neighbours.
			label.TextScaled = true
			label.TextColor3 = B.TextColor
			label.TextTransparency = 0.25
			label.Text = text
			label.Parent = gui

			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = B.TextSize
			cap.Parent = label
		end
	end
end

--------------------------------------------------------------------------------
-- The seating
--------------------------------------------------------------------------------
--[[
	A raked bank, built as rings of boxes rather than real steps: only the
	first three or four rows are ever in frame and the haze eats the rest.
]]
local function buildStands(parent: Instance)
	local S = Config.Arena.Stands
	local folder = Instance.new("Folder")
	folder.Name = "Stands"
	folder.Parent = parent

	for row = 1, S.Rows do
		local radius = S.InnerRadius + (row - 1) * S.RowDepth
		local height = S.Base + (row - 1) * S.RowRise
		local color = if row % 2 == 0 then S.AltColor else S.Color
		for i = 1, S.Segments do
			ringSegment(
				folder,
				`Row{row}_{i}`,
				i,
				S.Segments,
				radius,
				height / 2,
				height,
				S.RowDepth + 0.2,
				color
			)
		end
	end

	-- A row of blocks along the FRONT row -- the one nearest the floor,
	-- which is the only one anybody looks straight at. Nothing reads as
	-- seating until something roughly person-sized is standing on it.
	for i = 1, S.Seats do
		ringSegment(
			folder,
			`Seat{i}`,
			i,
			S.Seats,
			S.InnerRadius,
			S.Base + S.SeatRise,
			0.9,
			0.9,
			S.SeatColor
		)
	end
end

--------------------------------------------------------------------------------
-- The back wall
--------------------------------------------------------------------------------
--[[
	Its job is to stop the night sky showing over the seating, and to put
	one band of light behind the far cubes. Only its bottom six studs are
	ever on screen, which is where the LED strip sits.
]]
local function buildWall(parent: Instance)
	local W = Config.Arena.Wall
	local folder = Instance.new("Folder")
	folder.Name = "Wall"
	folder.Parent = parent

	for i = 1, W.Segments do
		ringSegment(folder, `Panel{i}`, i, W.Segments, W.Radius, W.Height / 2, W.Height, 1, W.Color)
		ringSegment(
			folder,
			`Led{i}`,
			i,
			W.Segments,
			W.Radius - 0.55,
			W.LedHeight,
			W.LedThickness,
			0.2,
			W.LedColor,
			{ material = Enum.Material.Neon }
		)
	end
end

--------------------------------------------------------------------------------
-- The rig overhead
--------------------------------------------------------------------------------
--[[
	Out of frame during play. The lamps still matter: their light is what
	puts a pool on every station and a highlight on every cube.
]]
local function buildRig(parent: Instance, pedestals: { CFrame })
	local A = Config.Arena
	local folder = Instance.new("Folder")
	folder.Name = "Rig"
	folder.Parent = parent

	for i = 1, A.Truss.Segments do
		ringSegment(
			folder,
			`Truss{i}`,
			i,
			A.Truss.Segments,
			A.Truss.Radius,
			A.Truss.Height,
			A.Truss.Thickness,
			A.Truss.Thickness,
			A.Truss.Color
		)
	end

	for index, pedestal in pedestals do
		local above = Vector3.new(pedestal.Position.X, A.Lamp.Height, pedestal.Position.Z)
		local rodLength = A.Truss.Height - A.Lamp.Height
		part(
			folder,
			`LampRod{index}`,
			Vector3.new(0.18, rodLength, 0.18),
			CFrame.new(above + Vector3.new(0, rodLength / 2, 0)),
			A.Truss.Color
		)
		local housing = part(
			folder,
			`Lamp{index}`,
			Vector3.new(1.1, 1.1, 1.1),
			CFrame.new(above),
			A.Lamp.HousingColor
		)
		part(
			folder,
			`LampLens{index}`,
			Vector3.new(0.9, 0.12, 0.9),
			CFrame.new(above - Vector3.new(0, 0.58, 0)),
			A.Lamp.LensColor,
			{ material = Enum.Material.Neon }
		)

		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = A.Lamp.Color
		light.Brightness = A.Lamp.Brightness
		light.Range = A.Lamp.Range
		light.Angle = A.Lamp.Angle
		light.Shadows = false
		light.Parent = housing
	end
end

--------------------------------------------------------------------------------
-- The stations
--------------------------------------------------------------------------------
--[[
	Dressing on top of the pedestals LobbyBuilder placed. Nothing here
	touches a pedestal CFrame: every piece is positioned FROM it, so the
	camera, the cube and the spectator copies all stay exactly where the
	rest of the game expects them.

	A pedestal CFrame sits at the top centre of the plinth with +Z
	pointing outward, at that player's own camera.
]]
local function buildStations(parent: Instance, pedestals: { CFrame }, floorTop: number)
	local S = Config.Arena.Station
	local folder = Instance.new("Folder")
	folder.Name = "Stations"
	folder.Parent = parent

	for index, pedestal in pedestals do
		local station = Instance.new("Model")
		station.Name = `Station{index}`
		station.Parent = folder

		-- The mat, sitting on the plinth with the cube floating over it, so
		-- the solve reads as happening ON something.
		local mat = part(
			station,
			"Mat",
			Vector3.new(S.MatSize, S.MatThickness, S.MatSize),
			pedestal * CFrame.new(0, S.MatThickness / 2, 0),
			S.MatColor
		)

		-- Everything on the mat is PAINTED on it. At full pop the cube's
		-- underside comes down to about 0.19 studs above the plinth (see
		-- Config.Cube.Height), so a timer pad built as a part would be
		-- clipped through on every single solve.
		--
		-- The paint goes on its own thin canvas turned a quarter-turn so
		-- that its FRONT face points at the sky, rather than on the mat's
		-- Top face. A SurfaceGui on a side face has one unambiguous
		-- orientation -- its up is the part's +Y -- while the convention
		-- for Top is the sort of thing you find out by looking. Turning
		-- the canvas ourselves means the layout is decided by this line
		-- and not by engine behaviour nobody can quote.
		--
		-- After the turn the canvas's +Y lies along the pedestal's +Z,
		-- which points outward at the player's own camera. So row 0 is the
		-- edge nearest the player (the pads) and row 1 the far edge (the
		-- number) -- and the number reads the right way up for the rest of
		-- the hall looking across at it, which is who it is for.
		local canvas = part(
			station,
			"MatFace",
			Vector3.new(S.MatSize, S.MatSize, 0.02),
			pedestal * CFrame.new(0, S.MatThickness + 0.01, 0) * CFrame.Angles(math.pi / 2, 0, 0),
			S.MatColor
		)

		local face = Instance.new("SurfaceGui")
		face.Name = "Paint"
		face.Face = Enum.NormalId.Front
		face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		face.PixelsPerStud = 50
		face.LightInfluence = 0.4
		face.Parent = canvas

		local numberLabel = Instance.new("TextLabel")
		numberLabel.Name = "Number"
		numberLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		numberLabel.Size = UDim2.fromScale(0.9, 0.22)
		numberLabel.Position = UDim2.fromScale(0.5, S.NumberRow)
		numberLabel.BackgroundTransparency = 1
		numberLabel.Font = Enum.Font.GothamBlack
		numberLabel.TextSize = S.NumberSize
		numberLabel.TextColor3 = S.NumberColor
		numberLabel.TextTransparency = 0.35
		numberLabel.Text = string.format("%02d", index)
		numberLabel.Parent = face

		-- The two timer pads, where a competitor's hands would rest.
		for side = -1, 1, 2 do
			local pad = Instance.new("Frame")
			pad.Name = `Pad{side}`
			pad.AnchorPoint = Vector2.new(0.5, 0.5)
			pad.Size = UDim2.fromScale(S.PadDiameter, S.PadDiameter)
			pad.Position = UDim2.fromScale(0.5 + side * S.PadSpread, S.PadRow)
			pad.BackgroundColor3 = S.PadColor
			pad.BorderSizePixel = 0
			pad.Parent = face

			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = pad

			local ring = Instance.new("UIStroke")
			ring.Color = S.PadRingColor
			ring.Thickness = 2
			ring.Transparency = 0.15
			ring.Parent = pad
		end

		-- The pool of light on the floor. Under ShadowMap the lamps cast
		-- no shadow, so the pool is painted, not lit. It goes ABOVE every
		-- floor marking (`floorTop`) -- underneath one it is swallowed by
		-- the marking's filler disc and never drawn at all.
		part(
			station,
			"Pool",
			Vector3.new(0.06, S.GlowRadius * 2, S.GlowRadius * 2),
			pedestal
				* CFrame.new(0, -Config.Lobby.PedestalHeight + floorTop, 0)
				* CFrame.Angles(0, 0, math.pi / 2),
			S.GlowColor,
			{
				shape = Enum.PartType.Cylinder,
				material = Enum.Material.Neon,
				transparency = S.GlowTransparency,
			}
		)

		local fill = Instance.new("PointLight")
		fill.Color = S.LightColor
		fill.Brightness = S.LightBrightness
		fill.Range = S.LightRange
		fill.Shadows = false
		fill.Parent = mat
	end
end

--------------------------------------------------------------------------------

--[[
	`parent` is the Lobby folder LobbyBuilder returned; `pedestals` is its
	list of pedestal-top CFrames, untouched.
]]
function Arena.build(parent: Instance, pedestals: { CFrame })
	local floorTop = buildFloor(parent)
	buildBarrier(parent)
	buildStands(parent)
	buildWall(parent)
	buildRig(parent, pedestals)
	buildStations(parent, pedestals, floorTop)
end

return Arena
