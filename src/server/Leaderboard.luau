--!strict
--[[
	Leaderboard.luau -- the pillar in the middle of the ring.

	Four faces, the same text on each: the fastest time per depth on this
	server (deepest first) and who has solved the most since the server
	started. Server-side text on a SurfaceGui replicates on its own; the
	client does nothing.

	Nothing here is saved: a server's records live as long as the server.
	The global weekly board is M3.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Leaderboard = {}

type Record = { name: string, seconds: number }

local bests: { [number]: Record } = {}
local solves: { [string]: number } = {}
local labels: { TextLabel } = {}

local function render()
	local B = Config.Board
	local lines = { "<b>FASTEST ON THIS SERVER</b>" }
	local depths: { number } = {}
	for depth, _ in bests do
		table.insert(depths, depth)
	end
	table.sort(depths, function(a, b)
		return a > b
	end)
	for i, depth in depths do
		if i > B.Lines then
			break
		end
		local r = bests[depth]
		table.insert(lines, string.format("depth %d   %.2fs   %s", depth, r.seconds, r.name))
	end
	if #depths == 0 then
		table.insert(lines, "no solves yet")
	end

	local names: { string } = {}
	for name, _ in solves do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		return solves[a] > solves[b]
	end)
	if #names > 0 then
		table.insert(lines, "")
		table.insert(lines, "<b>MOST SOLVES</b>")
		for i, name in names do
			if i > B.SolverLines then
				break
			end
			table.insert(lines, `{solves[name]}   {name}`)
		end
	end

	local text = table.concat(lines, "\n")
	for _, label in labels do
		label.Text = text
	end
end

function Leaderboard.build(parent: Instance)
	local B = Config.Board
	local pillar = Instance.new("Part")
	pillar.Name = "Board"
	pillar.Size = Vector3.new(B.Width, B.Height, B.Width)
	pillar.CFrame = CFrame.new(0, B.Height / 2 + 0.4, 0)
	pillar.Color = B.Color
	pillar.Material = Enum.Material.SmoothPlastic
	pillar.Anchored = true
	pillar.TopSurface = Enum.SurfaceType.Smooth
	pillar.BottomSurface = Enum.SurfaceType.Smooth
	pillar.Parent = parent

	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(B.Width + 0.4, 0.3, B.Width + 0.4)
	cap.CFrame = CFrame.new(0, B.Height + 0.55, 0)
	cap.Color = B.TrimColor
	cap.Material = Enum.Material.Neon
	cap.Anchored = true
	cap.CanCollide = false
	cap.Parent = parent

	for _, face in
		{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
	do
		local gui = Instance.new("SurfaceGui")
		gui.Name = `Face_{face.Name}`
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = pillar

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 18)
		pad.PaddingRight = UDim.new(0, 18)
		pad.PaddingTop = UDim.new(0, 18)
		pad.Parent = gui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = B.TextSize
		label.TextColor3 = Color3.fromRGB(236, 239, 243)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextWrapped = true
		label.RichText = true
		label.Text = ""
		label.Parent = gui
		table.insert(labels, label)
	end
	render()
end

function Leaderboard.recordSolve(name: string, depth: number, seconds: number)
	local current = bests[depth]
	if not current or seconds < current.seconds then
		bests[depth] = { name = name, seconds = seconds }
	end
	solves[name] = (solves[name] or 0) + 1
	render()
end

return Leaderboard
