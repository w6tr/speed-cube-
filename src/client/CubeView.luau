--!strict
--[[
	CubeView.luau -- the player's live cube: drawing, turning, prompting.

	The cube's truth on the client is a list of 26 "current" positions
	relative to the cube's centre (one per cubie). A turn picks the nine
	cubies in a layer and rotates their current positions a quarter turn
	about that layer's axis. Turns are queued and animated one after
	another by a single worker, so a fast player who swipes ahead of the
	animation sees the cube catch up rather than lose moves.

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
local Moves = require(Shared.Moves)

local CubeView = {}

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

function CubeView.build(root: CFrame): Api
	local size = Config.Cube.CubieSize
	local built = CubeBuilder.build(workspace, "LiveCube", root)
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
	for _, name in { "Turn", "Perfect", "Wrong", "Solve", "Coin" } do
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

	local function sound(name: string)
		local s = sounds[name]
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

	type Job = { move: string, seconds: number }
	local queue: { Job } = {}
	local animating = false
	local popping = false
	local shuffling = false

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
		while true do
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
			while #queue > 0 do
				local job = table.remove(queue, 1) :: Job
				runJob(job)
			end
			animating = false
		end)
	end

	local function turn(move: string, seconds: number?)
		table.insert(queue, { move = move, seconds = seconds or Config.Cube.TurnSeconds })
		sound("Turn")
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
		shuffling = true
		task.spawn(function()
			for _, move in moves do
				runJob({ move = move, seconds = Config.Cube.ShuffleTurnSeconds })
				sound("Turn")
			end
			shuffling = false
			done()
		end)
	end

	local shaking = false
	local function isBusy(): boolean
		return animating or shuffling or popping or shaking or #queue > 0
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
	arrow.Size = Vector3.new(pitch * 3, pitch, 0.05)
	arrow.Parent = built.model

	local arrowGui = Instance.new("SurfaceGui")
	arrowGui.Face = Enum.NormalId.Back -- +Z: the front face
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	arrowGui.PixelsPerStud = 100
	arrowGui.Parent = arrow

	local arrowLayout = glyphLayout(arrowGui)
	local glyphs: { TextLabel } = {}
	for i = 1, 3 do
		local g = Instance.new("TextLabel")
		g.Name = `Glyph{i}`
		g.BackgroundTransparency = 1
		g.Font = Enum.Font.GothamBlack
		g.TextSize = A.TextSize
		g.TextColor3 = A.Color
		g.TextStrokeTransparency = 0.2
		g.TextStrokeColor3 = Color3.new(0, 0, 0)
		g.Text = ""
		g.LayoutOrder = i
		g.Parent = arrowGui
		table.insert(glyphs, g)
	end

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
			local tween = TweenService:Create(glyphs[1], info, { TextTransparency = 0.55 })
			tween:Play()
			pulse = tween
		end
	end

	-- The arrow goes red for a moment on a wrong swipe.
	local flashToken = 0
	local function flashWrong()
		flashToken += 1
		local token = flashToken
		for _, g in glyphs do
			g.TextColor3 = A.WrongColor
		end
		task.delay(A.WrongFlashSeconds, function()
			if token == flashToken then
				for _, g in glyphs do
					g.TextColor3 = A.Color
				end
			end
		end)
	end

	local function prompt(move: string?)
		local def = if move then Moves.get(move) else nil
		if not def then
			arrow.Transparency = 1
			for _, g in glyphs do
				g.Text = ""
			end
			setPulse(false)
			return
		end
		local glyph = ARROWS[def.direction]
		local horizontal = def.row ~= nil
		arrow.Size = if horizontal
			then Vector3.new(pitch * 3, pitch, 0.05)
			else Vector3.new(pitch, pitch * 3, 0.05)
		local local_ = if horizontal
			then CFrame.new(0, (def.row :: number) * pitch, pitch * 1.5 + A.Offset)
			else CFrame.new((def.column :: number) * pitch, 0, pitch * 1.5 + A.Offset)
		arrow.CFrame = rootCF * local_
		arrowLayout.FillDirection = if horizontal
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		for _, g in glyphs do
			g.Text = glyph
			g.Size = if horizontal then UDim2.fromScale(1 / 3, 1) else UDim2.fromScale(1, 1 / 3)
		end
		setPulse(true)
	end

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
	local S = Config.Cube.Stickers
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, S.R),
		ColorSequenceKeypoint.new(0.25, S.D),
		ColorSequenceKeypoint.new(0.5, S.F),
		ColorSequenceKeypoint.new(0.75, S.B),
		ColorSequenceKeypoint.new(1, S.L),
	})
	emitter.Parent = burst

	local function pop()
		popping = true
		sound("Solve")
		emitter:Emit(Config.Cube.Particles)
		task.spawn(function()
			local t0 = os.clock()
			local seconds = Config.Cube.PopSeconds
			while true do
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
			while token == shakeToken do
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

	local function setRoot(root2: CFrame)
		rootCF = root2
		burst.CFrame = rootCF
		place()
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
	}
end

return CubeView
