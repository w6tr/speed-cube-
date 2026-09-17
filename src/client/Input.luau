--!strict
--[[
	Input.luau -- turns touches, mouse drags and keys into four directions.

	The swipe rules live in Shared/Swipe.luau (pure maths, tested under
	Lune). This file only wires Roblox's input events to it:

	  * A touch or a held mouse button starts a tracker at that point.
	  * Every movement while it is down is fed to the tracker; each
	    direction it commits is handed to the game. One press can carry
	    many swipes: right, then left, then up, without lifting.
	  * Lifting ends the tracker.

	On a keyboard the arrow keys and WASD do the same thing. Nothing here
	knows about the cube; it only says "Up" / "Down" / "Left" / "Right".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Moves = require(Shared.Moves)
local Swipe = require(Shared.Swipe)

local Input = {}

type Active = {
	input: InputObject,
	tracker: Swipe.Tracker,
}

local active: Active? = nil

local swipeOptions: Swipe.Options = {
	minPixels = Config.Input.SwipeMinPixels,
	chainPixels = Config.Input.ChainPixels,
	chainCooldown = Config.Input.ChainCooldown,
	axisRatio = Config.Input.AxisRatio,
}

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
			-- Roblox's own character controls claim WASD and the arrows first
			-- and mark them "processed"; we want them anyway. The only time
			-- to step aside is when the player is typing in a text box.
			if UserInputService:GetFocusedTextBox() then
				return
			end
			local direction: Moves.Direction? = keyToDirection[input.KeyCode]
			if direction then
				onDirection(direction)
			end
			return
		end
		if isPointer(input) and not gameProcessed then
			active = {
				input = input,
				tracker = Swipe.begin(input.Position, swipeOptions),
			}
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		local current = active
		if not current or not belongsToActive(input) then
			return
		end
		local direction = Swipe.move(current.tracker, input.Position, os.clock())
		if direction then
			onDirection(direction :: Moves.Direction)
		end
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
