--!strict
--[[
	Swipe.luau -- turns a moving finger (or a held mouse) into directions.

	Pure maths, no Roblox services, so `tools/test-swipe.luau` can drive it
	with scripted finger paths under Lune.

	The rules:
	  * A swipe COMMITS as soon as the finger has moved MinPixels from the
	    anchor, in whichever axis it moved most. It does not wait for the
	    finger to lift, so a quick flick registers before it is over.
	  * After a commit the anchor moves to the commit point, so ONE press
	    can carry many swipes: right, then left, then up, without lifting.
	  * Carrying on in the SAME direction never fires again: the anchor
	    rides along with the finger, so a long swipe is still one swipe.
	    Only a reversal or a sideways move (MinPixels from the ridden
	    anchor) commits the next one. The same direction twice in a row
	    needs a lift, because winding back to repeat it would read as the
	    opposite swipe.
]]

local Swipe = {}

export type Direction = "Up" | "Down" | "Left" | "Right"

export type Tracker = {
	anchor: Vector3,
	lastDir: Direction?,
	minPixels: number,
}

-- Screen space: +X right, +Y DOWN.
local AXIS: { [string]: Vector3 } = {
	Right = Vector3.new(1, 0, 0),
	Left = Vector3.new(-1, 0, 0),
	Down = Vector3.new(0, 1, 0),
	Up = Vector3.new(0, -1, 0),
}

function Swipe.begin(position: Vector3, minPixels: number): Tracker
	return { anchor = position, lastDir = nil, minPixels = minPixels }
end

--[[
	Feed the finger's new position. Returns the direction that just
	committed, or nil.
]]
function Swipe.move(t: Tracker, position: Vector3): Direction?
	local lastDir = t.lastDir
	if lastDir then
		-- Ride along the last direction: any further travel that way just
		-- moves the anchor, so over-travel never fires twice.
		local axis = AXIS[lastDir]
		local along = (position - t.anchor):Dot(axis)
		if along > 0 then
			t.anchor = t.anchor + axis * along
		end
	end
	local delta = position - t.anchor
	if delta.Magnitude < t.minPixels then
		return nil
	end
	local dir: Direction
	if math.abs(delta.X) > math.abs(delta.Y) then
		if delta.X > 0 then
			dir = "Right"
		else
			dir = "Left"
		end
	elseif delta.Y > 0 then
		dir = "Down"
	else
		dir = "Up"
	end
	t.anchor = position
	t.lastDir = dir
	return dir
end

return Swipe
