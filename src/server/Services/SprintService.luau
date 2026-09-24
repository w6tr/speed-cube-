--!strict
--[[
	SprintService.luau -- the sprint, bound to Roblox.

	Shared/Sprint.luau decides; this file does. Every quarter second it
	ticks the machine with the server clock and the seat count, and turns
	the events into deals (SolveService.dealAll), remotes (Sprint, Toast),
	coins (SolveService.award) and the lit station (Arena.setStationCrown).
	SolveService calls back in on every correct swipe and every finish of a
	sprint deal, and on leave, through the hooks registered in start().

	Nothing here trusts a client: the swipes and finishes it hears about
	have already been judged by SolveService, and the clock is the
	server's. The full rules and their reasons are in DESIGN-M3.md.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sprint = require(Shared.Sprint)

local Arena = require(script.Parent.Parent.Arena)
local SolveService = require(script.Parent.SolveService)

local SprintService = {}

local N = Remotes.Names
local cfg: Sprint.Config = Config.Sprint
local s = Sprint.new()

local function broadcast(phase: string, seconds: number)
	Remotes.get(N.Sprint):FireAllClients(phase, seconds)
end

local function toastAll(kind: string, text: string)
	Remotes.get(N.Toast):FireAllClients(kind, text)
end

local function crown(player: Player?, on: boolean)
	local index = if player then SolveService.pedestalIndexFor(player) else nil
	if index then
		Arena.setStationCrown(index, on)
	end
end

local function act(event: Sprint.Event)
	if event.kind == "go" then
		local ids = SolveService.dealAll(cfg.Depth)
		Sprint.dealt(s, ids)
		broadcast("racing", event.seconds)
		toastAll("big", "GO!")
	elseif event.kind == "countdown" then
		broadcast("countdown", event.seconds)
		toastAll("info", `Sprint in {cfg.Countdown} -- same cube, first pop wins`)
	elseif event.kind == "cancel" then
		toastAll("info", "Sprint cancelled -- not enough players")
	elseif event.kind == "nobody" then
		crown(event.crown, false)
		broadcast("idle", cfg.Every)
		toastAll("info", "Nobody popped -- no winner this sprint")
	else -- "idle" | "off"
		broadcast(event.kind, event.seconds)
	end
end

--------------------------------------------------------------------------------
-- What SolveService calls back with
--------------------------------------------------------------------------------

local function onSwipe(player: Player, dealId: number)
	Sprint.swipe(s, player, dealId)
end

local function onFinish(player: Player, dealId: number, seconds: number, depth: number)
	local verdict, previous = Sprint.pop(s, cfg, os.clock(), player, dealId, seconds, depth)
	if verdict ~= "won" then
		return
	end
	-- Set before clear, so a repeat winner's station never blinks.
	crown(player, true)
	if previous and previous ~= player then
		crown(previous, false)
	end
	SolveService.award(player, Config.Sprint.WinBonus) -- coins are the service's business, not the rules'
	broadcast("idle", cfg.Every)
	Remotes.get(N.Sprint):FireAllClients("won", 0, player.Name, seconds)
	toastAll("big", string.format("%s wins the sprint -- %.2fs", player.Name, seconds))
end

local function onLeave(player: Player, index: number)
	if Sprint.leave(s, player) then
		Arena.setStationCrown(index, false)
	end
end

local function stateFor(): Remotes.SprintState
	return { phase = s.phase, seconds = Sprint.remaining(s, os.clock()) }
end

--------------------------------------------------------------------------------

function SprintService.start()
	SolveService.setSprintHooks({
		swipe = onSwipe,
		finish = onFinish,
		leave = onLeave,
		state = stateFor,
	})
	task.spawn(function()
		while true do
			local joined = 0
			for _, player in Players:GetPlayers() do
				if SolveService.isJoined(player) then
					joined += 1
				end
			end
			for _, event in Sprint.tick(s, cfg, os.clock(), joined) do
				act(event)
			end
			task.wait(0.25)
		end
	end)
end

return SprintService
