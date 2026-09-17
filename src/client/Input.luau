--!strict
--[[
	Input.luau -- turns touches, mouse drags and keys into four directions.

	A swipe COMMITS as soon as the finger has moved SwipeMinPixels, not
	when it lifts, so a fast flick registers before it is over. Once a
	touch has committed it cannot commit again until it lifts: one touch,
	one swipe, no accidental doubles from a wobbly thumb. The direction is
	whichever axis the finger moved most along.

	On a keyboard the arrow keys and WASD do the same thing. Nothing here
	knows about the cube; it only says "Up" / "Down" / "Left" / "Right".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Moves = require(Shared.Moves)

local Input = {}

type Active = {
	input: InputObject,
	start: Vector3,
	consumed: boolean,
}

local active: Active? = nil

local keyToDirection: { [Enum.KeyCode]: Moves.Direction } = {}
local function bind(direction: Moves.Direction, keys: { Enum.KeyCode })
	for _, key in keys do
		keyToDirection[key] = direction
	end
end
bind("Up", Config.Input.Keys.Up)
bind("Down", Config.Input.Keys.Down)
bind("Left", Config.Input.Keys.Left)
bind("Right", Config.Input.Keys.Right)

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function belongsToActive(input: InputObject): boolean
	local current = active
	if not current then
		return false
	end
	if current.input.UserInputType == Enum.UserInputType.Touch then
		return input == current.input
	end
	-- A mouse drag reports movement as a different InputObject.
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

function Input.start(onDirection: (Moves.Direction) -> ())
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if gameProcessed then
				return -- typing in chat
			end
			local direction: Moves.Direction? = keyToDirection[input.KeyCode]
			if direction then
				onDirection(direction)
			end
			return
		end
		if isPointer(input) and not gameProcessed then
			active = { input = input, start = input.Position, consumed = false }
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		local current = active
		if not current or current.consumed or not belongsToActive(input) then
			return
		end
		local delta = input.Position - current.start
		if delta.Magnitude < Config.Input.SwipeMinPixels then
			return
		end
		current.consumed = true
		local direction: Moves.Direction
		if math.abs(delta.X) > math.abs(delta.Y) then
			direction = if delta.X > 0 then "Right" else "Left"
		else
			direction = if delta.Y > 0 then "Down" else "Up" -- screen Y grows downward
		end
		onDirection(direction)
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if active and isPointer(input) then
			active = nil
		end
	end)
end

function Input.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

return Input
