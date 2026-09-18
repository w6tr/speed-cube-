--!strict
--[[
	Remotes.luau -- one place that knows the wire format.

	The server creates these on boot; the client waits for them. Nothing
	else in the codebase should call Instance.new("RemoteEvent").

	The client never sends a number the server trusts. It sends the
	DIRECTION it swiped, the ID of a box or a cube; the server knows what
	those mean, what they cost and whether they are allowed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local NAMES: { [string]: string } = {
	-- client -> server (asks; the server decides)
	RequestSync = "RequestSync", -- ()                       "send me my state"
	Move = "Move", -- (direction, dealId: number, seq: number)  the player swiped
	SetDepth = "SetDepth", -- (delta: number)                +1 / -1 on the depth dial
	RollBox = "RollBox", -- (boxId: string)                  buy and hatch one box with coins
	Equip = "Equip", -- (cubeId: string)                     put an owned cube on

	-- server -> client (facts; the client displays)
	Sync = "Sync", -- (state: SyncState)                      the whole player state
	MoveResult = "MoveResult", -- (result: MoveResult)        the answer to one swipe
	Solved = "Solved", -- (result: SolveResult)               the deal is done; pop
	Hatched = "Hatched", -- (result: HatchResult)             a box opened
	Toast = "Toast", -- (kind: string, text: string)

	-- server -> ALL clients: what is happening on other pedestals. Each
	-- client ignores its own pedestal index.
	SpectateDeal = "SpectateDeal", -- (index, dealId: number, scramble: {string})
	SpectateMove = "SpectateMove", -- (index, move: string)
	SpectatePop = "SpectatePop", -- (index)
	SpectateLook = "SpectateLook", -- (index, cubeId: string, pedestal: CFrame)
	SpectateLeave = "SpectateLeave", -- (index)
}

--------------------------------------------------------------------------------
-- Payload shapes, so both sides agree on the field names.
--------------------------------------------------------------------------------

export type Deal = {
	id: number, -- bumps every deal; the client uses it to notice a new one
	depth: number,
	scramble: { string }, -- move names, applied to a solved cube to set the deal up
	solution: { string }, -- move names the player has to perform, in order
	step: number, -- how many of the solution's moves are done
}

-- Another player's pedestal, for drawing their cube on join.
export type Other = {
	index: number,
	pedestal: CFrame, -- that pedestal's top centre, from the server
	cubeId: string,
	dealId: number, -- 0 when they have no deal
	scramble: { string },
	solution: { string },
	step: number,
}

export type SyncState = {
	coins: number,
	solves: number,
	best: number, -- best solve seconds at any depth, 0 = none yet
	depth: number, -- the dial
	unlockedDepth: number, -- the dial's ceiling
	combo: number,
	pedestal: CFrame, -- the top centre of the player's pedestal; +Z is toward the camera
	pedestalIndex: number, -- which Pedestal<N> model in workspace.Lobby is theirs
	deal: Deal?,
	cubes: { [string]: number }, -- owned cube id -> copies
	equipped: string, -- cube id
	others: { Other },
}

export type MoveResult = {
	ok: boolean, -- it was the expected move
	ignored: boolean, -- heard but not judged (too fast, or during a lockout)
	perfect: boolean,
	step: number, -- the server's step after this swipe
	combo: number,
	dealId: number,
	seq: number, -- echoes the client's sequence number
}

export type SolveResult = {
	coins: number,
	seconds: number,
	isBest: boolean,
	combo: number,
	mult: number, -- combo multiplier x cube multiplier
	cubeMult: number,
	perfects: number,
	fast: boolean,
}

export type HatchResult = {
	boxId: string,
	cubeId: string,
	isNew: boolean,
	count: number, -- copies owned after this one
	equipped: string, -- the cube on after the hatch (may be the new one)
	coins: number, -- coins after paying
}

local Remotes = {}

local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = ReplicatedStorage
		folder = made
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
end

--[[
	Fetch a remote by name. Yields on the client until the server has made it.
]]
function Remotes.get(name: string): RemoteEvent
	assert(NAMES[name], `Remotes.get: unknown remote "{name}"`)
	local remote = folder:WaitForChild(name, 30)
	assert(remote, `Remotes.get: "{name}" never appeared -- is the server script running?`)
	return remote :: RemoteEvent
end

Remotes.Names = NAMES

return Remotes
