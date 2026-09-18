--!strict
--[[
	Hatch.luau -- the box-opening animation.

	A wooden box drops onto the pedestal where the cube was, rattles
	harder and harder, bursts in the tier's colour, and the cube swells
	back into place wearing its new look. Purely visual: the server has
	already rolled and paid by the time this plays.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Hatch = {}

local function block(parent: Instance, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

--[[
	Play the hatch centred on `root`. `tierColor` tints the burst.
	`reveal` is called at the burst, when the caller should show the cube
	with its new look; `done` when play may resume.
]]
function Hatch.play(root: CFrame, tierColor: Color3, reveal: () -> (), done: () -> ())
	local H = Config.Hatch
	local model = Instance.new("Model")
	model.Name = "HatchBox"
	model.Parent = workspace

	local side = Config.Cube.CubieSize * 3 + Config.Cube.Gap * 2 + 0.5
	local body = block(model, Vector3.new(side, side * 0.8, side), H.BoxColor, Enum.Material.Wood)
	local lid = block(
		model,
		Vector3.new(side + 0.2, side * 0.25, side + 0.2),
		H.LidColor,
		Enum.Material.Metal
	)
	local lidOffset = CFrame.new(0, side * 0.5, 0)

	-- A question mark on the four sides.
	for _, face in
		{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0.5
		gui.Parent = body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = tierColor
		label.Text = "?"
		label.Parent = gui
	end

	local burstPart = block(model, Vector3.new(1, 1, 1), tierColor, Enum.Material.Neon)
	burstPart.Transparency = 1
	burstPart.CFrame = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(tierColor)
	emitter.Parent = burstPart

	local function placeBox(offset: Vector3, wobble: number)
		local cf = root * CFrame.new(offset) * CFrame.Angles(0, wobble, wobble * 0.5)
		body.CFrame = cf
		lid.CFrame = cf * lidOffset
	end

	task.spawn(function()
		-- Drop
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / H.DropSeconds)
			placeBox(Vector3.new(0, H.DropHeight * (1 - a) * (1 - a), 0), 0)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		-- Rattle, harder and harder
		t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / H.ShakeSeconds)
			local amp = H.ShakeStuds * a
			placeBox(
				Vector3.new(
					math.sin(a * 70) * amp,
					math.abs(math.sin(a * 45)) * amp,
					math.cos(a * 60) * amp
				),
				math.sin(a * 80) * 0.15 * a
			)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		-- Burst
		body:Destroy()
		lid:Destroy()
		emitter:Emit(H.Particles)
		reveal()
		task.wait(H.RevealSeconds + H.HoldSeconds)
		model:Destroy()
		done()
	end)
end

return Hatch
