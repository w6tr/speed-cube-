--!strict
--[[
	LobbyBuilder.luau -- the world, made from parts at boot.

	A round floor, a ring of pedestals facing OUTWARD, and a still solved
	cube on each pedestal. Every player gets one pedestal; their camera
	sits outside the ring looking in, so behind their own cube they see
	the rest of the ring and everybody else's cube across it.

	Each pedestal's CFrame has its +Z pointing outward (toward that
	player's camera) and sits at the top centre of the pedestal. That one
	CFrame is what the client positions the live cube and the camera from.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CubeBuilder = require(Shared.CubeBuilder)

local LobbyBuilder = {}

export type World = {
	folder: Folder,
	pedestals: { CFrame }, -- index = pedestal number
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function LobbyBuilder.build(): World
	-- The template place has a baseplate and a spawn; the game brings its own.
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local L = Config.Lobby
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"

	part(
		folder,
		"Floor",
		Vector3.new(L.FloorSize, 1, L.FloorSize),
		CFrame.new(0, -0.5, 0),
		L.Colors.Floor
	)
	-- A slightly raised disc inside the ring, so the middle reads as a stage.
	local disc = part(
		folder,
		"Stage",
		Vector3.new(0.4, L.Radius * 2 - 6, L.Radius * 2 - 6),
		CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		L.Colors.Ring,
		Enum.PartType.Cylinder
	)
	disc.Material = Enum.Material.Metal

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = folder

	local pedestals: { CFrame } = {}
	local n = Config.MaxPlayers
	for i = 1, n do
		local angle = (i - 1) / n * math.pi * 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = outward * L.Radius

		local model = Instance.new("Model")
		model.Name = `Pedestal{i}`
		model.Parent = folder

		local column = part(
			model,
			"Column",
			Vector3.new(L.PedestalHeight, L.PedestalRadius * 2, L.PedestalRadius * 2),
			CFrame.new(base + Vector3.new(0, L.PedestalHeight / 2, 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			L.Colors.Pedestal,
			Enum.PartType.Cylinder
		)
		column.Material = Enum.Material.Metal
		local trim = part(
			model,
			"Trim",
			Vector3.new(0.2, L.PedestalRadius * 2 + 0.3, L.PedestalRadius * 2 + 0.3),
			CFrame.new(base + Vector3.new(0, L.PedestalHeight - 0.1, 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			L.Colors.Trim,
			Enum.PartType.Cylinder
		)
		trim.Material = Enum.Material.Neon
		trim.CanCollide = false

		local top = base + Vector3.new(0, L.PedestalHeight, 0)
		-- LookVector is -Z, so looking AWAY from `outward` puts +Z on `outward`.
		local cframe = CFrame.lookAt(top, top - outward)
		pedestals[i] = cframe

		local display =
			CubeBuilder.build(model, "Display", cframe * CFrame.new(0, Config.Cube.Height, 0))
		display.model:SetAttribute("Pedestal", i)
	end

	folder.Parent = workspace
	return { folder = folder, pedestals = pedestals }
end

return LobbyBuilder
