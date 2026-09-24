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

-- `inRace` is true only for the GO broadcast: everyone seated at that
-- instant was dealt the cube. A later joiner gets theirs from Sync.
local function broadcast(phase: string, seconds: number, inRace: boolean?)
	Remotes.get(N.Sprint):FireAllClients(phase, seconds, inRace == true)
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
		broadcast("racing", event.seconds, true)
		toastAll("big", "GO!")
	elseif event.kind == "countdown" then
		broadcast("countdown", event.seconds)
		toastAll("info", `Sprint in {cfg.Countdown} -- same cube, first pop wins`)
	elseif event.kind == "cancel" then
		toastAll("info", "Sprint cancelled -- not enough players")
	elseif event.kind == "nobody" then
		-- The "idle" that follows in the same tick does the broadcast.
		crown(event.crown, false)
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
	local verdict, previous, sinceGo =
		Sprint.pop(s, cfg, os.clock(), player, dealId, seconds, depth)
	if verdict ~= "won" then
		return
	end
	-- Set before clear, so a repeat winner's station never blinks.
	crown(player, true)
	if previous and previous ~= player then
		crown(previous, false)
	end
	local bonus = Config.Sprint.WinBonus -- coins are the service's business, not the rules'
	SolveService.award(player, bonus)
	broadcast("idle", cfg.Every)
	-- The room hears the name and the time since GO -- the race it watched,
	-- not the solve's own seconds, which can contradict the pop order. The
	-- winner alone hears the money.
	toastAll("big", string.format("%s wins the sprint -- %.1fs", player.Name, sinceGo))
	Remotes.get(N.Toast):FireClient(player, "coins", `+{bonus} coins -- sprint win`)
end

local function onLeave(player: Player, index: number)
	if Sprint.leave(s, player) then
		Arena.setStationCrown(index, false)
	end
end

local function liveFor(player: Player, dealId: number): boolean
	return Sprint.live(s, player, dealId)
end

local function stateFor(player: Player): Remotes.SprintState
	return {
		phase = s.phase,
		seconds = Sprint.remaining(s, os.clock()),
		inRace = s.phase == "racing" and s.dealIds[player] ~= nil,
	}
end

--------------------------------------------------------------------------------

function SprintService.start()
	SolveService.setSprintHooks({
		swipe = onSwipe,
		finish = onFinish,
		leave = onLeave,
		live = liveFor,
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
				-- Guarded, because an error here would unwind this thread and
				-- take every future sprint with it, silently, while every HUD
				-- sat on "FIRST POP WINS 0s". The machine has already moved
				-- on, so a failed GO resolves itself at the cap as "nobody".
				-- (The inner function returns a string only so Luau's typed pcall
				-- hands back a second value to catch the error in.)
				local ok, err = pcall(function(): string
					act(event)
					return ""
				end)
				if not ok then
					warn(`[SprintService] {event.kind} failed: {err}`)
				end
			end
			task.wait(0.25)
		end
	end)
end

return SprintService
