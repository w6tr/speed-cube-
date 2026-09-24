--!strict
--[[
	CubeView.luau -- a live cube: drawing, turning, prompting.

	The cube's truth on the client is a list of 26 "current" positions
	relative to the cube's centre (one per cubie). A turn picks the nine
	cubies in a layer and rotates their current positions a quarter turn
	about that layer's axis. Turns are queued and animated one after
	another by a single worker, so a fast player who swipes ahead of the
	animation sees the cube catch up rather than lose moves.

	Built once for the player's own cube (with the arrow prompt and
	sounds) and once per other player in the ring (silent, no arrow),
	driven by Spectate events.

	Everything here is visual. Whether a swipe was right is decided by
	init.client (instantly, from the deal) and by the server (for coins).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CubeBuilder = require(Shared.CubeBuilder)
local Cubes = require(Shared.Defs.Cubes)
local Moves = require(Shared.Moves)

local CubeView = {}

export type Options = {
	name: string?,
	look: Cubes.Look?,
	turnSound: string?,
	silent: boolean?, -- no sounds at all (spectator cubes)
	noArrow: boolean?, -- never show the prompt
}

export type Api = {
	setRoot: (root: CFrame) -> (),
	reset: () -> (),
	applyInstant: (move: string) -> (),
	turn: (move: string, seconds: number?) -> (),
	shuffle: (moves: { string }, done: () -> ()) -> (),
	prompt: (move: string?) -> (),
	isBusy: () -> boolean,
	pop: () -> (),
	shake: () -> (),
	flashWrong: () -> (),
	sound: (name: string) -> (),
	setLook: (look: Cubes.Look, turnSound: string?) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local ARROWS: { [string]: string } = {
	Up = "▲",
	Down = "▼",
	Left = "◀",
	Right = "▶",
}

type Live = {
	part: Part,
	home: CFrame,
	cur: CFrame,
}

local function component(v: Vector3, axis: Vector3): number
	if axis.X ~= 0 then
		return v.X
	elseif axis.Y ~= 0 then
		return v.Y
	end
	return v.Z
end

local function roundTo(n: number, step: number): number
	return math.floor(n / step + 0.5) * step
end

-- Kill floating-point drift after a quarter turn: positions back onto the
-- grid, rotation axes back to exact unit vectors.
local function snap(cf: CFrame, pitch: number): CFrame
	local p = cf.Position
	local pos = Vector3.new(roundTo(p.X, pitch), roundTo(p.Y, pitch), roundTo(p.Z, pitch))
	local function unit(v: Vector3): Vector3
		return Vector3.new(math.round(v.X), math.round(v.Y), math.round(v.Z))
	end
	return CFrame.fromMatrix(pos, unit(cf.XVector), unit(cf.YVector), unit(cf.ZVector))
end

local function easeOut(a: number): number
	return 1 - (1 - a) * (1 - a)
end

-- A UIListLayout for the arrow glyphs (kept out of Theme: it is a 3D thing).
local function glyphLayout(parent: Instance): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = parent
	return layout
end

function CubeView.build(root: CFrame, options: Options?): Api
	local opts: Options = options or {}
	local size = Config.Cube.CubieSize
	local built = CubeBuilder.build(workspace, opts.name or "LiveCube", root, opts.look)
	local pitch = built.pitch
	local live: { Live } = {}
	for _, cubie in built.cubies do
		table.insert(live, { part = cubie.part, home = cubie.home, cur = cubie.home })
	end

	local rootCF = root
	local scale = 1
	local placedScale = 1
	local shakeOffset = Vector3.zero

	local function place()
		local resize = scale ~= placedScale
		for _, c in live do
			c.part.CFrame = rootCF
				* CFrame.new(c.cur.Position * scale + shakeOffset)
				* c.cur.Rotation
			if resize then
				c.part.Size = Vector3.new(size * scale, size * scale, size * scale)
			end
		end
		placedScale = scale
	end

	----------------------------------------------------------------------------
	-- Sounds
	----------------------------------------------------------------------------

	local sounds: { [string]: Sound } = {}
	if not opts.silent then
		for _, name in { "Perfect", "Wrong", "Solve", "Coin" } do
			local id = (Config.Sounds :: any)[name]
			if type(id) == "string" and id ~= "" then
				local s = Instance.new("Sound")
				s.Name = `Cube{name}`
				s.SoundId = id
				s.Volume = if name == "Solve"
					then Config.Sounds.SolveVolume
					else Config.Sounds.TurnVolume
				s.Parent = SoundService
				sounds[name] = s
			end
		end
	end

	-- The turning sound belongs to the equipped cube, so it lives apart
	-- from the fixed ones and can be swapped.
	local turnSound: Sound? = nil
	local function setTurnSound(id: string?)
		if opts.silent then
			return
		end
		local turnId = if id and id ~= "" then id else Config.Sounds.Turn
		local existing = turnSound
		if turnId == "" then
			if existing then
				existing:Destroy()
				turnSound = nil
			end
			return
		end
		if not existing then
			local s = Instance.new("Sound")
			s.Name = "CubeTurn"
			s.Volume = Config.Sounds.TurnVolume
			s.SoundId = turnId
			s.Parent = SoundService
			turnSound = s
			return
		end
		existing.SoundId = turnId
	end
	setTurnSound(opts.turnSound)

	local function sound(name: string)
		local s: Sound? = if name == "Turn" then turnSound else sounds[name]
		if not s then
			return
		end
		if name == "Turn" then
			s.PlaybackSpeed = 0.95 + math.random() * 0.15
		end
		s:Play()
	end

	----------------------------------------------------------------------------
	-- Turning
	----------------------------------------------------------------------------

	local function layerOf(def: Moves.Def): { Live }
		local out: { Live } = {}
		for _, c in live do
			if math.round(component(c.cur.Position, def.axis) / pitch) == def.layer then
				table.insert(out, c)
			end
		end
		return out
	end

	-- The row or column about to turn is drawn a notch brighter and every
	-- other sticker a notch dimmer, so "this slice" reads before the
	-- colours do. Re-run after every turn: the layer's membership changes.
	local promptedMove: string? = nil
	local function highlight()
		local A = Config.Cube.Arrow
		local def = if promptedMove then Moves.get(promptedMove) else nil
		local inLayer: { [Part]: boolean } = {}
		if def then
			for _, c in layerOf(def) do
				inLayer[c.part] = true
			end
		end
		for _, c in live do
			local factor = if not def then 1 elseif inLayer[c.part] then A.SliceBoost else A.RestDim
			for _, gui in c.part:GetChildren() do
				if gui:IsA("SurfaceGui") then
					local base = gui:GetAttribute("BaseBrightness")
					gui.Brightness = (if type(base) == "number" then base else 1) * factor
				end
			end
		end
	end

	local function applyInstant(move: string)
		local def = Moves.get(move)
		if not def then
			return
		end
		local rot = CFrame.fromAxisAngle(def.axis, def.angle)
		for _, c in layerOf(def) do
			c.cur = snap(rot * c.cur, pitch)
		end
		place()
	end

	-- Every motion of the cubies goes through ONE queue and ONE worker, so
	-- two animations can never fight over the same cubies. A shuffle is
	-- just a run of quick jobs, the last of which carries the callback.
	type Job = { move: string, seconds: number, done: (() -> ())? }
	local queue: { Job } = {}
	local animating = false
	local popping = false
	local destroyed = false

	local function runJob(job: Job)
		local def = Moves.get(job.move)
		if not def then
			return
		end
		local layer = layerOf(def)
		local starts: { CFrame } = {}
		for i, c in layer do
			starts[i] = c.cur
		end
		local t0 = os.clock()
		while not destroyed do
			local a = math.min(1, (os.clock() - t0) / job.seconds)
			local rot = CFrame.fromAxisAngle(def.axis, def.angle * easeOut(a))
			for i, c in layer do
				c.cur = rot * starts[i]
			end
			place()
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		local final = CFrame.fromAxisAngle(def.axis, def.angle)
		for i, c in layer do
			c.cur = snap(final * starts[i], pitch)
		end
		place()
	end

	local function pump()
		if animating then
			return
		end
		animating = true
		task.spawn(function()
			while #queue > 0 and not destroyed do
				local job = table.remove(queue, 1) :: Job
				sound("Turn")
				runJob(job)
				highlight()
				if job.done then
					job.done()
				end
			end
			animating = false
		end)
	end

	local function turn(move: string, seconds: number?)
		table.insert(queue, { move = move, seconds = seconds or Config.Cube.TurnSeconds })
		pump()
	end

	local function reset()
		queue = {}
		for _, c in live do
			c.cur = c.home
		end
		scale = 1
		shakeOffset = Vector3.zero
		place()
	end

	--[[
		Play the scramble quickly, then call `done`. The cube is busy until
		then so no swipe can slip in mid-shuffle.
	]]
	local function shuffle(moves: { string }, done: () -> ())
		if #moves == 0 then
			done()
			return
		end
		for i, move in moves do
			table.insert(queue, {
				move = move,
				seconds = Config.Cube.ShuffleTurnSeconds,
				done = if i == #moves then done else nil,
			})
		end
		pump()
	end

	local shaking = false
	local function isBusy(): boolean
		if destroyed then
			return false
		end
		return animating or popping or shaking or #queue > 0
	end

	----------------------------------------------------------------------------
	-- The arrow prompt
	----------------------------------------------------------------------------

	local A = Config.Cube.Arrow
	local arrow = Instance.new("Part")
	arrow.Name = "Arrow"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.CastShadow = false
	arrow.Transparency = 1
	-- The slab hugs the stickers of the row: three cubies long and one
	-- cubie tall, not three pitches, so the lit frame round it lands on the
	-- row's own corners and never hangs off the cube's base.
	local extent = size * 3 + Config.Cube.Gap * 2
	arrow.Size = Vector3.new(extent, size, 0.05)
	arrow.Parent = built.model

	local arrowGui = Instance.new("SurfaceGui")
	arrowGui.Face = Enum.NormalId.Back -- +Z: the front face
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	arrowGui.PixelsPerStud = 100
	arrowGui.Parent = arrow

	arrowGui.Brightness = A.Brightness

	local arrowLayout = glyphLayout(arrowGui)
	local cells: { Frame } = {}
	local glyphs: { TextLabel } = {}
	local shadows: { TextLabel } = {}
	local edges: { UIStroke } = {}
	for i = 1, 3 do
		-- One cell per sticker of the row. The glyph is centred in its cell
		-- and sized as a fraction of it, so it lands in the middle of the
		-- sticker at the same size whatever the font makes of the character.
		local cell = Instance.new("Frame")
		cell.Name = `Cell{i}`
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = i
		cell.Parent = arrowGui

		local function label(name: string, fill: number, z: number): TextLabel
			local t = Instance.new("TextLabel")
			t.Name = name
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromScale(0.5, 0.5)
			t.Size = UDim2.fromScale(fill, fill)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBlack
			t.TextScaled = true
			t.Text = ""
			t.ZIndex = z
			t.Parent = cell
			return t
		end

		-- A soft dark halo behind the glyph, so it holds on a glowing
		-- sticker as well as on a dark one.
		local shadow = label("Halo", A.Fill * A.HaloScale, 1)
		shadow.TextColor3 = A.StrokeColor
		shadow.TextTransparency = A.HaloTransparency

		local g = label("Glyph", A.Fill, 2)
		g.TextColor3 = A.Core

		-- The colour lives on the EDGE: a white-hot core beats a white
		-- sticker on brightness, and the coloured stroke keeps the hue. A
		-- real outline, not TextStroke, which is too thin to hold a shape.
		local outline = Instance.new("UIStroke")
		outline.Name = "Outline"
		outline.Color = A.Color
		outline.Thickness = A.StrokeThickness
		outline.Parent = g

		-- The dark outline sits outside the coloured edge, on the halo.
		local dark = Instance.new("UIStroke")
		dark.Name = "Dark"
		dark.Color = A.StrokeColor
		dark.Thickness = A.DarkThickness
		dark.Transparency = A.HaloTransparency
		dark.Parent = shadow

		table.insert(cells, cell)
		table.insert(glyphs, g)
		table.insert(shadows, shadow)
		table.insert(edges, outline)
	end

	-- A glowing frame round the whole row about to turn: a spotlight on
	-- the slice, instead of a hue shift on its stickers.
	local rowGui = Instance.new("SurfaceGui")
	rowGui.Name = "RowGlow"
	rowGui.Face = Enum.NormalId.Back
	rowGui.AlwaysOnTop = true
	rowGui.LightInfluence = 0
	rowGui.Brightness = A.Brightness
	rowGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	rowGui.PixelsPerStud = 100
	rowGui.Enabled = false
	rowGui.Parent = arrow
	local rowFrame = Instance.new("Frame")
	-- Inset by the stroke, so the lit edge lands ON the row and not outside it.
	rowFrame.Size = UDim2.new(1, -A.RowGlowThickness * 2, 1, -A.RowGlowThickness * 2)
	rowFrame.Position = UDim2.fromOffset(A.RowGlowThickness, A.RowGlowThickness)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = rowGui
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0.06, 0)
	rowCorner.Parent = rowFrame
	local rowEdge = Instance.new("UIStroke")
	rowEdge.Color = A.Color
	rowEdge.Thickness = A.RowGlowThickness
	rowEdge.Transparency = A.RowGlowTransparency
	rowEdge.Parent = rowFrame

	-- The first glyph is tweened; the other two copy it.
	glyphs[1]:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		glyphs[2].TextTransparency = glyphs[1].TextTransparency
		glyphs[3].TextTransparency = glyphs[1].TextTransparency
	end)

	local pulse: Tween? = nil
	local function setPulse(on: boolean)
		local running = pulse
		if running then
			running:Cancel()
			pulse = nil
		end
		glyphs[1].TextTransparency = 0
		if on then
			local info = TweenInfo.new(
				A.PulseSeconds,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)
			local tween =
				TweenService:Create(glyphs[1], info, { TextTransparency = A.PulseTransparency })
			tween:Play()
			pulse = tween
		end
	end

	-- The arrow goes red for a moment on a wrong swipe.
	local flashToken = 0
	local function flashWrong()
		flashToken += 1
		local token = flashToken
		for i, g in glyphs do
			g.TextColor3 = A.WrongColor
			edges[i].Color = A.WrongColor
		end
		task.delay(A.WrongFlashSeconds, function()
			if token == flashToken then
				for i, g in glyphs do
					g.TextColor3 = A.Core
					edges[i].Color = A.Color
				end
			end
		end)
	end

	local function prompt(move: string?)
		local def = if move and not opts.noArrow then Moves.get(move) else nil
		promptedMove = if def then move else nil
		if not def then
			for i, g in glyphs do
				g.Text = ""
				shadows[i].Text = ""
			end
			setPulse(false)
			rowGui.Enabled = false
			highlight()
			return
		end
		local glyph = ARROWS[def.direction]
		local horizontal = def.row ~= nil
		arrow.Size = if horizontal
			then Vector3.new(extent, size, 0.05)
			else Vector3.new(size, extent, 0.05)
		local offset = if horizontal
			then CFrame.new(0, (def.row :: number) * pitch, pitch * 1.5 + A.Offset)
			else CFrame.new((def.column :: number) * pitch, 0, pitch * 1.5 + A.Offset)
		arrow.CFrame = rootCF * offset
		arrowLayout.FillDirection = if horizontal
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		for i, cell in cells do
			cell.Size = if horizontal then UDim2.fromScale(1 / 3, 1) else UDim2.fromScale(1, 1 / 3)
			glyphs[i].Text = glyph
			shadows[i].Text = glyph
		end
		setPulse(true)
		rowGui.Enabled = true
		highlight()
	end

	----------------------------------------------------------------------------
	-- The rim light and the prism
	----------------------------------------------------------------------------

	-- A cool lamp behind and above the player's own cube, so its top edges
	-- catch a colour the hall's lamps do not give them. Spectator cubes go
	-- without: they are small, far, and eight of them would be eight lamps.
	local rim: Part? = nil
	if not opts.noArrow then
		local R = Config.Cube.Rim
		local holder = Instance.new("Part")
		holder.Name = "Rim"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.lookAt(rootCF:PointToWorldSpace(R.Offset), rootCF.Position)
		holder.Parent = built.model
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Color = R.Color
		spot.Brightness = R.Brightness
		spot.Range = R.Range
		spot.Angle = R.Angle
		spot.Shadows = false
		spot.Parent = holder
		rim = holder
	end

	-- A prismatic look walks every sticker round the colour wheel, slowly.
	-- The base colours are the attributes applyLook left on each sticker,
	-- so a look change simply repaints and the loop picks up the new ones.
	local prismToken = 0
	local function setPrismatic(on: boolean)
		prismToken += 1
		if not on then
			return
		end
		local token = prismToken
		task.spawn(function()
			local t0 = os.clock()
			while token == prismToken and not destroyed do
				local shift = ((os.clock() - t0) * Config.Cube.PrismCycleHz) % 1
				for _, c in live do
					for _, gui in c.part:GetChildren() do
						if gui:IsA("SurfaceGui") then
							local base = gui:GetAttribute("BaseColor")
							local fill = gui:FindFirstChild("Fill")
							if typeof(base) == "Color3" and fill and fill:IsA("Frame") then
								local h, sat, v = base:ToHSV()
								local color = Color3.fromHSV((h + shift) % 1, sat, v)
								fill.BackgroundColor3 = color
								local glow = fill:FindFirstChild("Glow")
								if glow and glow:IsA("UIStroke") then
									glow.Color = color
								end
							end
						end
					end
				end
				task.wait(Config.Cube.PrismStepSeconds)
			end
		end)
	end
	setPrismatic((opts.look or (Cubes.get(Cubes.Default) :: Cubes.Def).look).prismatic == true)

	----------------------------------------------------------------------------
	-- Pop and shake
	----------------------------------------------------------------------------

	local burst = Instance.new("Part")
	burst.Name = "Burst"
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Transparency = 1
	burst.Size = Vector3.new(1, 1, 1)
	burst.CFrame = rootCF
	burst.Parent = built.model

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.7, 1.2)
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	emitter.LightEmission = 0.6
	emitter.Parent = burst

	local function setBurstColors(stickers: { [string]: Color3 })
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, stickers.R),
			ColorSequenceKeypoint.new(0.25, stickers.D),
			ColorSequenceKeypoint.new(0.5, stickers.F),
			ColorSequenceKeypoint.new(0.75, stickers.B),
			ColorSequenceKeypoint.new(1, stickers.L),
		})
	end
	setBurstColors((opts.look or (Cubes.get(Cubes.Default) :: Cubes.Def).look).stickers)

	local function pop()
		popping = true
		sound("Solve")
		emitter:Emit(Config.Cube.Particles)
		task.spawn(function()
			local t0 = os.clock()
			local seconds = Config.Cube.PopSeconds
			while not destroyed do
				local a = math.min(1, (os.clock() - t0) / seconds)
				scale = 1 + (Config.Cube.PopScale - 1) * math.sin(a * math.pi)
				place()
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			scale = 1
			place()
			popping = false
		end)
	end

	local shakeToken = 0
	local function shake()
		sound("Wrong")
		shakeToken += 1
		local token = shakeToken
		shaking = true
		task.spawn(function()
			local t0 = os.clock()
			local seconds = Config.Cube.ShakeSeconds
			while token == shakeToken and not destroyed do
				local a = math.min(1, (os.clock() - t0) / seconds)
				shakeOffset = Vector3.new(math.sin(a * 40) * Config.Cube.ShakeStuds * (1 - a), 0, 0)
				place()
				if a >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			if token == shakeToken then
				shakeOffset = Vector3.zero
				place()
				shaking = false
			end
		end)
	end

	----------------------------------------------------------------------------
	-- Looks, visibility, teardown
	----------------------------------------------------------------------------

	local function setLook(look: Cubes.Look, turnId: string?)
		setPrismatic(false)
		CubeBuilder.applyLook(built, look)
		highlight()
		setPrismatic(look.prismatic == true)
		setBurstColors(look.stickers)
		setTurnSound(turnId)
	end

	local function setVisible(on: boolean)
		for _, c in live do
			c.part.LocalTransparencyModifier = if on then 0 else 1
			for _, gui in c.part:GetChildren() do
				if gui:IsA("SurfaceGui") then
					gui.Enabled = on
				end
			end
		end
		for _, light in built.core:GetChildren() do
			if light:IsA("Light") then
				light.Enabled = on
			end
		end
		if rim then
			local spot = rim:FindFirstChildOfClass("SpotLight")
			if spot then
				spot.Enabled = on
			end
		end
		if not on then
			prompt(nil)
		end
	end

	local function setRoot(root2: CFrame)
		rootCF = root2
		burst.CFrame = rootCF
		built.core.CFrame = rootCF
		if rim then
			rim.CFrame =
				CFrame.lookAt(rootCF:PointToWorldSpace(Config.Cube.Rim.Offset), rootCF.Position)
		end
		place()
	end

	local function destroy()
		destroyed = true
		queue = {}
		setPulse(false)
		setPrismatic(false)
		for _, s in sounds do
			s:Destroy()
		end
		if turnSound then
			turnSound:Destroy()
		end
		built.model:Destroy()
	end

	place()

	return {
		setRoot = setRoot,
		reset = reset,
		applyInstant = applyInstant,
		turn = turn,
		shuffle = shuffle,
		prompt = prompt,
		isBusy = isBusy,
		pop = pop,
		shake = shake,
		flashWrong = flashWrong,
		sound = sound,
		setLook = setLook,
		setVisible = setVisible,
		destroy = destroy,
	}
end

return CubeView
