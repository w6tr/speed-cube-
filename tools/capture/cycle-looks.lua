local RS = game:GetService("ReplicatedStorage")
local CB = require(RS.Shared.CubeBuilder)
local Cubes = require(RS.Shared.Defs.Cubes)
local live = assert(workspace:FindFirstChild("LiveCube"), "no LiveCube")
local root = live:WaitForChild("Core").CFrame
local defs = {}
for _, t in { "Common", "Rare", "Epic", "Legendary" } do
	for _, d in Cubes.ofTier(t) do
		table.insert(defs, d)
	end
end
task.wait(1)
live.Parent = nil
for i, def in defs do
	local c = CB.build(workspace, "Preview", root, def.look)
	task.wait(1.6)
	c.model:Destroy()
end
live.Parent = workspace
print("CYCLE2 DONE", #defs)
