--!strict
--[[
	Server entry point.

	Builds the lobby, starts the services, and runs the join/leave
	sequence. Both live HERE, in order, so "why did X not happen for a new
	player" has exactly one place to look.

	Read order for anyone new to this codebase:
	  Config.luau           the numbers, and what each one does
	  DESIGN.md             why the game is shaped like this
	  Moves.luau            what a move is, and the direction each one prompts
	  SolveService.luau     the deal / swipe / solve loop
	  CubeView.luau         how the client draws and turns the cube
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local LobbyBuilder = require(script.LobbyBuilder)
local SaveService = require(script.Services.SaveService)
local SolveService = require(script.Services.SolveService)

--------------------------------------------------------------------------------
-- World and services
--------------------------------------------------------------------------------

local world = LobbyBuilder.build()
SolveService.init(world.pedestals)
SaveService.start()
SolveService.start()

--------------------------------------------------------------------------------
-- The handshake
--------------------------------------------------------------------------------
--[[
	A RemoteEvent fired before the client's script has connected its
	listener is silently dropped, and the client can start seconds after
	the server loaded the player's data, or seconds before. So the client
	ASKS (RequestSync) and the server answers with everything the first
	frame needs. If the ask arrives before the data is loaded, the load
	remembers to answer when it is done.
]]

local askedEarly: { [Player]: boolean } = {}
local lastAnswerAt: { [Player]: number } = {}

local function answerSync(player: Player)
	if not SolveService.isJoined(player) then
		askedEarly[player] = true
		return
	end
	local now = os.clock()
	if now - (lastAnswerAt[player] or 0) < Config.Timing.SyncThrottle then
		return
	end
	lastAnswerAt[player] = now
	SolveService.sync(player)
end

Remotes.get(Remotes.Names.RequestSync).OnServerEvent:Connect(answerSync)

--------------------------------------------------------------------------------
-- Standing at the pedestal
--------------------------------------------------------------------------------
--[[
	The avatar stands on the floor just behind its cube, facing outward
	toward its own camera, so from the player's view their character is
	looking at the cube with them. Walking and jumping are off (StarterPlayer
	in default.project.json), so they stay put.
]]

local function standAtPedestal(player: Player, character: Model)
	local pedestal = SolveService.pedestalFor(player)
	if not pedestal then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local L = Config.Lobby
	-- Pedestal top -> down to the floor, up to the hip, back toward the
	-- ring centre, and turned to face +Z (an avatar faces its -Z).
	local stand = pedestal
		* CFrame.new(0, -L.PedestalHeight + L.HipHeight, -L.StandBack)
		* CFrame.Angles(0, math.pi, 0)
	-- Roblox may still be placing the character at the spawn this frame;
	-- one heartbeat later our placement is the last word.
	RunService.Heartbeat:Wait()
	if character.Parent then
		character:PivotTo(stand)
	end
end

--------------------------------------------------------------------------------
-- Join / leave
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	SaveService.load(player)
	if not player.Parent then
		return
	end
	if not SolveService.join(player) then
		player:Kick(`This ring is full ({Config.MaxPlayers} cubers). Try another server!`)
		return
	end
	player.CharacterAdded:Connect(function(character)
		standAtPedestal(player, character)
	end)
	if player.Character then
		standAtPedestal(player, player.Character)
	end
	if askedEarly[player] then
		askedEarly[player] = nil
		answerSync(player)
	end
end

local function onPlayerRemoving(player: Player)
	SolveService.leave(player)
	askedEarly[player] = nil
	lastAnswerAt[player] = nil
	SaveService.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("[Speed Cube] server ready")
