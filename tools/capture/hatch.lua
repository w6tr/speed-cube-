local P = game:GetService("Players").LocalPlayer
local H = require(P.PlayerScripts.Client.Hatch)
local live = assert(workspace:FindFirstChild("LiveCube"), "no LiveCube")
local root = live:WaitForChild("Core").CFrame
local arrow = live:FindFirstChild("Arrow")
local function arrows(on)
	if arrow then
		for _, g in arrow:GetChildren() do
			if g:IsA("SurfaceGui") and (on == false or g.Name ~= "RowGlow") then
				g.Enabled = on
			end
		end
	end
end
task.wait(0.8)
live.Parent = nil
arrows(false)
H.play(root, Color3.fromRGB(190, 90, 255), function()
	live.Parent = workspace
end, function()
	arrows(true)
	print("HATCH DONE")
end)
