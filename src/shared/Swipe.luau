--!strict
--[[
	Swipe.luau -- turns a moving finger (or a held mouse) into directions.

	Pure maths, no Roblox services, so `tools/test-swipe.luau` can drive it
	with scripted finger paths under Lune.

	The rules:
	  * The FIRST swipe of a press commits after MinPixels of travel, in
	    whichever axis it moved most. It does not wait for the finger to
	    lift, so a quick flick registers before it is over.
	  * After a commit the anchor moves to the commit point, so ONE press
	    can carry many swipes: right, then left, then up, without lifting.
	  * A CHAINED swipe (same press, after a commit) needs ChainPixels of
	    travel and nothing counts for ChainCooldown seconds after the last
	    commit. That is where the "tail" of a real swipe lives: the hand
	    slowing down and curling, which would otherwise read as a second,
	    wrong swipe.
	  * Carrying on in the SAME direction never fires again: the anchor
	    rides along with the finger, so a long swipe is still one swipe.
	    The same direction twice in a row needs a lift, because winding
	    back to repeat it would read as the opposite swipe.
	  * A move only counts when it is clearly one axis: the bigger axis
	    must be at least AxisRatio times the other. Diagonals wait.
]]

local Swipe = {}

export type Direction = "Up" | "Down" | "Left" | "Right"

export type Options = {
	minPixels: number,
	chainPixels: number,
	chainCooldown: number,
	axisRatio: number,
}

export type Tracker = {
	anchor: Vector3,
	lastDir: Direction?,
	lastCommitAt: number,
	options: Options,
}

-- Screen space: +X right, +Y DOWN.
local AXIS: { [string]: Vector3 } = {
	Right = Vector3.new(1, 0, 0),
	Left = Vector3.new(-1, 0, 0),
	Down = Vector3.new(0, 1, 0),
	Up = Vector3.new(0, -1, 0),
}

function Swipe.begin(position: Vector3, options: Options): Tracker
	return { anchor = position, lastDir = nil, lastCommitAt = -math.huge, options = options }
end

--[[
	Feed the finger's new position at time `now`. Returns the direction
	that just committed, or nil.
]]
function Swipe.move(t: Tracker, position: Vector3, now: number): Direction?
	local o = t.options
	local lastDir = t.lastDir
	if lastDir then
		-- Ride along the last direction: any further travel that way just
		-- moves the anchor, so over-travel never fires twice.
		local axis = AXIS[lastDir]
		local along = (position - t.anchor):Dot(axis)
		if along > 0 then
			t.anchor = t.anchor + axis * along
		end
		if now - t.lastCommitAt < o.chainCooldown then
			-- The tail of the last swipe. Keep the anchor with the finger so
			-- the curl does not pile up into a fake swipe.
			t.anchor = position
			return nil
		end
	end
	local delta = position - t.anchor
	local needed = if lastDir then o.chainPixels else o.minPixels
	if delta.Magnitude < needed then
		return nil
	end
	local ax, ay = math.abs(delta.X), math.abs(delta.Y)
	local dir: Direction
	if ax >= ay * o.axisRatio then
		if delta.X > 0 then
			dir = "Right"
		else
			dir = "Left"
		end
	elseif ay >= ax * o.axisRatio then
		if delta.Y > 0 then
			dir = "Down"
		else
			dir = "Up"
		end
	else
		return nil -- a diagonal: wait for it to resolve
	end
	t.anchor = position
	t.lastDir = dir
	t.lastCommitAt = now
	return dir
end

return Swipe
