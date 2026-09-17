--!strict
--[[
	CameraRig.luau -- a fixed three-quarter view of the player's cube.

	The camera sits outside the ring (pedestal +Z) a little above and to
	the right of the cube, looking at its centre, so three faces show: the
	front (where the arrows are), the top and the right. It is re-applied
	every frame because Roblox likes to take the camera back when the
	character respawns.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CameraRig = {}

local target: CFrame? = nil
local connection: RBXScriptConnection? = nil

local function apply()
	local camera = workspace.CurrentCamera
	if not camera or not target then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	camera.FieldOfView = Config.Camera.FieldOfView
	camera.CFrame = target
end

--[[
	`pedestal` is the pedestal-top CFrame from Sync (+Z toward the camera).
]]
function CameraRig.lockTo(pedestal: CFrame)
	local centre = pedestal * CFrame.new(0, Config.Cube.Height, 0)
	local eye = centre:PointToWorldSpace(Config.Camera.Offset)
	target = CFrame.lookAt(eye, centre.Position)
	apply()
	if not connection then
		connection = RunService.RenderStepped:Connect(apply)
	end
end

return CameraRig
