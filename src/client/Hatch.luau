--!strict
--[[
	Hatch.luau -- the box-opening animation.

	The hall goes dark and a soft pillar of the tier's light stands on the
	station, motes drifting up through it. Into that light drops a sealed
	competition cube case in the tier's colour with a gold lid; a white
	line burns round its seam and widens with every rattle while sparks
	spit out of it; then the lid blows off in a flash that starts at the
	seam, confetti in the six cube colours bursts from the centre, a ring
	rolls across the floor, and the cube swells back into place wearing
	its new look. Purely visual: the server has already rolled and paid by
	the time this plays.

	Two critic rounds shaped this (2026-09-24, art/critic-log.md): the old
	wooden crate was the darkest object in a dark hall (4); the first case
	had an unlit black lid and a beam with hard edges (6). So the lid is
	the brightest face now, the beam is three soft layers, the rattle has
	its anticipation, the burst has a centre, and the HUD and Roblox's
	player list go away for the length of it.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Hatch = {}

local H = Config.Hatch
local WHITE = Color3.new(1, 1, 1)

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

local function cylinder(
	parent: Instance,
	height: number,
	diameter: number,
	color: Color3,
	transparency: number
): Part
	local p = block(parent, Vector3.new(height, diameter, diameter), color, Enum.Material.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = transparency
	return p
end

local function tween(target: Instance, seconds: number, props: { [string]: any }): Tween
	local t = TweenService:Create(
		target,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function emitter(parent: Instance, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.LightEmission = 1
	e.Color = ColorSequence.new(color)
	e.Parent = parent
	return e
end

-- A glowing "?" on a face of the case; on the front, the sealed tag too.
local function faceGui(
	part: Part,
	face: Enum.NormalId,
	tierColor: Color3,
	glyphScale: number,
	tagged: boolean
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = H.GlyphBrightness
	gui.Parent = part

	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, if tagged then 0.42 else 0.5)
	glyph.Size = UDim2.fromScale(glyphScale, glyphScale)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextScaled = true
	glyph.TextColor3 = WHITE
	glyph.Text = "?"
	glyph.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = tierColor
	stroke.Thickness = 5
	stroke.Parent = glyph

	if tagged then
		local plate = Instance.new("TextLabel")
		plate.Name = "Tag"
		plate.AnchorPoint = Vector2.new(0.5, 1)
		plate.Position = UDim2.fromScale(0.5, 0.94)
		plate.Size = UDim2.fromScale(0.82, 0.13)
		plate.BackgroundColor3 = WHITE
		plate.BorderSizePixel = 0
		plate.Font = Enum.Font.GothamBold
		plate.TextScaled = true
		plate.TextColor3 = Color3.fromRGB(20, 20, 24)
		plate.Text = "SPEED CUBE OPEN  -  SEALED"
		plate.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = plate
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.PaddingTop = UDim.new(0.18, 0)
		pad.PaddingBottom = UDim.new(0.18, 0)
		pad.Parent = plate
	end
	return gui
end

-- The play HUD and Roblox's player list leave the screen for the hatch,
-- so the case, the cube and the tier colour are all there is. Toasts
-- live in their own screen and stay: the name card is the fourth beat.
local function stageHud(on: boolean)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild(Config.HudScreenName)
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = on
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, on)
	end)
end

-- The station's timer pads take the tier colour for the hatch instead
-- of sitting under the cube as two black holes. Found by position: the
-- mat's paint canvas that shares the cube's spot on the floor.
local function padsNear(root: CFrame): ({ Frame }, { TextLabel })
	local out: { Frame } = {}
	local text: { TextLabel } = {}
	local lobby = workspace:FindFirstChild("Lobby")
	local stations = lobby and lobby:FindFirstChild("Stations")
	if not stations then
		return out, text
	end
	for _, station in stations:GetChildren() do
		local canvas = station:FindFirstChild("MatFace")
		if canvas and canvas:IsA("BasePart") then
			local d = canvas.Position - root.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude < 1 then
				local paint = canvas:FindFirstChild("Paint")
				if paint then
					for _, child in paint:GetChildren() do
						if child:IsA("Frame") and string.sub(child.Name, 1, 3) == "Pad" then
							table.insert(out, child)
						elseif child:IsA("TextLabel") then
							table.insert(text, child)
						end
					end
				end
			end
		end
	end
	return out, text
end

--[[
	Play the hatch centred on `root`. `tierColor` is the case's colour and
	the burst's. `reveal` is called at the burst, when the caller should
	show the cube with its new look; `done` when play may resume.
]]
function Hatch.play(root: CFrame, tierColor: Color3, reveal: () -> (), done: () -> ())
	local model = Instance.new("Model")
	model.Name = "HatchBox"
	model.Parent = workspace

	----------------------------------------------------------------------------
	-- The stage: the hall dims, and a soft pillar of the tier's light
	-- stands on the station with motes drifting up through it. (Roblox
	-- lights cast no visible beam, so the pillar is three neon cylinders,
	-- each wider and fainter than the last, that bloom into one.)
	----------------------------------------------------------------------------
	local dim = Instance.new("ColorCorrectionEffect")
	dim.Name = "HatchDim"
	dim.Parent = Lighting
	tween(dim, H.DimSeconds, { Brightness = H.DimBrightness, Saturation = H.DimSaturation })

	local beamCF = root
		* CFrame.new(0, H.BeamHeight / 2 - 1.2, 0)
		* CFrame.Angles(0, 0, math.pi / 2)
	local beams: { Part } = {}
	for i = 1, H.BeamLayerCount do
		local t = (i - 1) / (H.BeamLayerCount - 1)
		local diameter = H.BeamCoreDiameter + (H.BeamOuterDiameter - H.BeamCoreDiameter) * t
		-- Eased, so the layers thin faster toward the outside and the
		-- outermost is nearly nothing: no edge to see.
		local transparency = H.BeamCoreTransparency
			+ (H.BeamOuterTransparency - H.BeamCoreTransparency) * math.sqrt(t)
		local b = cylinder(model, H.BeamHeight, diameter, tierColor, 1)
		b.CFrame = beamCF
		tween(b, H.DimSeconds, { Transparency = transparency })
		table.insert(beams, b)
	end
	-- Brightest where it meets the station.
	local base = cylinder(model, H.BeamBaseHeight, H.BeamCoreDiameter * 2.6, tierColor, 1)
	base.CFrame = root
		* CFrame.new(0, -Config.Cube.Height + H.BeamBaseHeight / 2, 0)
		* CFrame.Angles(0, 0, math.pi / 2)
	tween(base, H.DimSeconds, { Transparency = H.BeamBaseTransparency })

	local moteBox = block(
		model,
		Vector3.new(H.BeamOuterDiameter * 0.5, H.BeamHeight, H.BeamOuterDiameter * 0.5),
		tierColor,
		Enum.Material.SmoothPlastic
	)
	moteBox.Transparency = 1
	moteBox.CFrame = root * CFrame.new(0, H.BeamHeight / 2 - 1.2, 0)
	local motes = emitter(moteBox, tierColor)
	motes.Rate = H.MoteRate
	motes.Lifetime = NumberRange.new(2.5, 4.5)
	motes.Speed = NumberRange.new(0.6, 1.4)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new(0.3)

	local pads, matText = padsNear(root)
	local padColours: { Color3 } = {}
	for i, pad in pads do
		padColours[i] = pad.BackgroundColor3
		pad.BackgroundColor3 = tierColor:Lerp(Color3.new(0, 0, 0), 0.35)
	end
	for _, label in matText do
		label.Visible = false
	end

	stageHud(false)

	----------------------------------------------------------------------------
	-- The case: a tier-coloured body, a lit seam, a gold lid with a lit
	-- rim and the biggest "?" on top, where the locked camera looks.
	----------------------------------------------------------------------------
	local side = Config.Cube.CubieSize * 3 + Config.Cube.Gap * 2 + 0.5
	local bodyHeight = side * 0.78
	local lidHeight = side * 0.22
	local body = block(
		model,
		Vector3.new(side, bodyHeight, side),
		tierColor:Lerp(Color3.new(0, 0, 0), H.BodyDarken),
		Enum.Material.SmoothPlastic
	)
	local seam = block(
		model,
		Vector3.new(side + 0.06, H.SeamHeight, side + 0.06),
		tierColor,
		Enum.Material.Neon
	)
	local lid = block(
		model,
		Vector3.new(side + 0.24, lidHeight, side + 0.24),
		H.LidColor,
		Enum.Material.Metal
	)
	local rim =
		block(model, Vector3.new(side + 0.34, 0.07, side + 0.34), H.RimColor, Enum.Material.Neon)

	local faces = {
		faceGui(body, Enum.NormalId.Back, tierColor, 0.6, true), -- +Z faces the player
		faceGui(body, Enum.NormalId.Front, tierColor, 0.6, false),
		faceGui(body, Enum.NormalId.Left, tierColor, 0.6, false),
		faceGui(body, Enum.NormalId.Right, tierColor, 0.6, false),
	}
	-- The top face is the biggest face from the locked camera: it stays
	-- gold whatever the lamps do, with the "?" lit like the front ones,
	-- and it is left out of the rattle's brightening so it never blows out.
	local crown = faceGui(lid, Enum.NormalId.Top, tierColor, 0.8, false)
	local goldFace = Instance.new("Frame")
	goldFace.Name = "Gold"
	goldFace.Size = UDim2.fromScale(1, 1)
	goldFace.BackgroundColor3 = H.LidColor
	goldFace.BorderSizePixel = 0
	goldFace.ZIndex = 0
	goldFace.Parent = crown
	local goldGrad = Instance.new("UIGradient")
	goldGrad.Rotation = 35
	goldGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, H.LidColor),
		ColorSequenceKeypoint.new(0.45, H.LidBandColor),
		ColorSequenceKeypoint.new(0.55, H.LidBandColor),
		ColorSequenceKeypoint.new(1, H.LidColor:Lerp(Color3.new(0, 0, 0), 0.25)),
	})
	goldGrad.Parent = goldFace
	crown.Brightness = 1.1
	local band = block(
		model,
		Vector3.new(side + 0.26, 0.05, side + 0.26),
		H.LidBandColor,
		Enum.Material.Neon
	)

	local lamp = Instance.new("PointLight")
	lamp.Color = tierColor
	lamp.Brightness = 0
	lamp.Range = H.LampRange
	lamp.Shadows = false
	lamp.Parent = body

	-- Sparks leak from the seam as the rattle builds.
	local sparks = emitter(seam, tierColor)
	sparks.Lifetime = NumberRange.new(0.7, 1.2)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparks.Acceleration = Vector3.new(0, -6, 0)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})

	local function placeBox(offset: Vector3, wobble: number, seamHeight: number, lidLift: number)
		local cf = root * CFrame.new(offset) * CFrame.Angles(0, wobble, wobble * 0.5)
		body.CFrame = cf
		seam.Size = Vector3.new(side + 0.06, seamHeight, side + 0.06)
		seam.CFrame = cf * CFrame.new(0, bodyHeight / 2 + seamHeight / 2, 0)
		local lidCF = cf * CFrame.new(0, bodyHeight / 2 + seamHeight + lidHeight / 2 + lidLift, 0)
		lid.CFrame = lidCF
		rim.CFrame = lidCF * CFrame.new(0, lidHeight / 2 - 0.035, 0)
		band.CFrame = lidCF * CFrame.new(0, -lidHeight * 0.1, 0)
	end

	----------------------------------------------------------------------------
	-- The burst: a flash that starts at the seam, confetti in the six cube
	-- colours from the centre, a ring across the floor.
	----------------------------------------------------------------------------
	local burstPart = block(model, Vector3.new(1, 1, 1), tierColor, Enum.Material.Neon)
	burstPart.Transparency = 1
	burstPart.CFrame = root
	-- The confetti is the cube's own stickers flying off the box: little
	-- glowing squares in the six cube colours, thrown from the centre and
	-- left to physics, so the near ones are big and the far ones small.
	local rng = Random.new()
	local function throwChips()
		local folder = Instance.new("Folder")
		folder.Name = "Chips"
		folder.Parent = workspace
		for i = 1, H.ChipCount do
			local chip = Instance.new("Part")
			chip.Size = Vector3.new(H.ChipSize, H.ChipSize, 0.06)
			chip.Color = H.ChipColors[(i - 1) % #H.ChipColors + 1]
			chip.Material = Enum.Material.Neon
			chip.CanCollide = false
			chip.CanQuery = false
			chip.CanTouch = false
			chip.CastShadow = false
			chip.Massless = true
			local dir = rng:NextUnitVector()
			dir = Vector3.new(dir.X, math.abs(dir.Y) * 0.8 + 0.3, dir.Z).Unit
			chip.CFrame = root
				* CFrame.new(dir * 0.6)
				* CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), 0)
			chip.Parent = folder
			chip.AssemblyLinearVelocity = dir * rng:NextNumber(H.ChipSpeed[1], H.ChipSpeed[2])
			chip.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(6, 14)
		end
		task.delay(H.ChipSeconds, function()
			folder:Destroy()
		end)
	end
	local sparksOut = emitter(burstPart, tierColor)
	sparksOut.Lifetime = NumberRange.new(0.6, 1.1)
	sparksOut.Speed = NumberRange.new(16, 28)
	sparksOut.SpreadAngle = Vector2.new(180, 180)
	sparksOut.Acceleration = Vector3.new(0, -30, 0)
	sparksOut.Drag = 2
	sparksOut.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparksOut.Color = ColorSequence.new(WHITE, tierColor)

	local ring = cylinder(model, 0.12, 1, tierColor, 1)
	ring.CFrame = root
		* CFrame.new(0, -Config.Cube.Height + 0.16, 0)
		* CFrame.Angles(0, 0, math.pi / 2)

	local flashBall = block(model, Vector3.new(0.6, 0.6, 0.6), WHITE, Enum.Material.Neon)
	flashBall.Shape = Enum.PartType.Ball
	flashBall.Transparency = 1

	local flash = Instance.new("ScreenGui")
	flash.Name = "HatchFlash"
	flash.IgnoreGuiInset = true
	flash.DisplayOrder = 60
	flash.ResetOnSpawn = false
	local flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = WHITE
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = flash
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		flash.Parent = playerGui
	end

	----------------------------------------------------------------------------
	-- The beats.
	----------------------------------------------------------------------------
	task.spawn(function()
		-- The stage lands first; the case drops into a dark hall.
		placeBox(Vector3.new(0, H.DropHeight * 3, 0), 0, H.SeamHeight, 0)
		task.wait(H.StageSeconds)
		-- Drop.
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / H.DropSeconds)
			placeBox(Vector3.new(0, H.DropHeight * (1 - a) * (1 - a), 0), 0, H.SeamHeight, 0)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		-- Rattle, harder and harder: the seam widens and whitens, sparks
		-- leak from it, the lid lifts and slams, the lamp inside builds.
		t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / H.ShakeSeconds)
			local amp = H.ShakeStuds * a
			local seamHeight = H.SeamHeight + (H.SeamHeightEnd - H.SeamHeight) * a
			local lift = math.abs(math.sin(a * 32)) * H.LidLift * a
			placeBox(
				Vector3.new(
					math.sin(a * 70) * amp,
					math.abs(math.sin(a * 45)) * amp,
					math.cos(a * 60) * amp
				),
				math.sin(a * 80) * 0.15 * a,
				seamHeight,
				lift
			)
			lamp.Brightness = H.LampPeak * a
			seam.Color = tierColor:Lerp(WHITE, 0.7 * a)
			sparks.Rate = H.SparkRate * a
			for _, gui in faces do
				gui.Brightness = H.GlyphBrightness * (1 + a)
			end
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		-- Burst.
		sparks.Rate = 0
		flashBall.CFrame = seam.CFrame
		flashBall.Transparency = H.FlashBallTransparency
		tween(flashBall, H.FlashSeconds, { Size = Vector3.one * H.FlashDiameter, Transparency = 1 })
		flashFrame.BackgroundTransparency = H.FlashTransparency
		tween(flashFrame, H.FlashSeconds, { BackgroundTransparency = 1 })
		ring.Transparency = 0.35
		tween(ring, H.RingSeconds, {
			Size = Vector3.new(0.12, H.RingDiameter, H.RingDiameter),
			Transparency = 1,
		})
		throwChips()
		sparksOut:Emit(H.Particles)
		for _, gui in faces do
			gui.Enabled = false
		end
		crown.Enabled = false
		local fly = lid.CFrame * CFrame.new(0, 8, 0) * CFrame.Angles(0.7, 0.5, 0)
		tween(lid, H.RevealSeconds, { CFrame = fly, Transparency = 1 })
		tween(
			rim,
			H.RevealSeconds,
			{ CFrame = fly * CFrame.new(0, lidHeight / 2, 0), Transparency = 1 }
		)
		tween(band, H.RevealSeconds, { CFrame = fly, Transparency = 1 })
		tween(body, H.RevealSeconds, { Transparency = 1 })
		tween(seam, H.RevealSeconds, { Transparency = 1 })
		tween(lamp, H.RevealSeconds + H.HoldSeconds, { Brightness = 0 })
		-- The stage lights come back up under the flash, so the new cube is
		-- revealed in full colour and full brightness, not through the dim.
		tween(dim, H.RevealSeconds, { Brightness = 0, Saturation = 0 })
		reveal()
		task.wait(H.RevealSeconds + H.HoldSeconds)
		for _, b in beams do
			tween(b, H.DimSeconds, { Transparency = 1 })
		end
		tween(base, H.DimSeconds, { Transparency = 1 })
		motes.Rate = 0
		task.wait(H.DimSeconds)
		for i, pad in pads do
			pad.BackgroundColor3 = padColours[i]
		end
		for _, label in matText do
			label.Visible = true
		end
		stageHud(true)
		dim:Destroy()
		flash:Destroy()
		model:Destroy()
		done()
	end)
end

return Hatch
