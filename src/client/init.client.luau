--!strict
--[[
	Client entry point.

	Builds the cube, the HUD, the collection screen, the spectator cubes
	and the input, and wires them to the server. The client checks each
	swipe against the deal INSTANTLY (so the cube turns or wobbles with no
	lag) and sends the swipe to the server, which checks it again and owns
	the coins.

	Every swipe carries a sequence number and the deal id, and the server
	answers every one for the current deal with the step it is now on. The
	client keeps a list of what it predicted for each swipe still in
	flight; an answer that disagrees means the two screens have drifted,
	and the client asks for a Sync and redraws from it. The server always
	wins.

	One deal at a time. A new deal (a new `id` in Sync) waits for the cube
	to finish whatever it is animating, resets it, plays the scramble, and
	shows the first arrow. A hatch pauses input while the box opens; the
	deal underneath carries on where it was.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cubes = require(Shared.Defs.Cubes)
local Moves = require(Shared.Moves)
local Remotes = require(Shared.Remotes)

local CameraRig = require(script.CameraRig)
local CollectionPanel = require(script.CollectionPanel)
local CubeView = require(script.CubeView)
local Hatch = require(script.Hatch)
local Hud = require(script.Hud)
local Input = require(script.Input)
local Spectators = require(script.Spectators)
local Theme = require(script.Theme)
local Toasts = require(script.Toasts)

local player = Players.LocalPlayer
local N = Remotes.Names

local function fire(name: string, ...: any)
	Remotes.get(name):FireServer(...)
end

--------------------------------------------------------------------------------
-- Own the whole screen on touch
--------------------------------------------------------------------------------
--[[
	Roblox's default touch controls (the thumbstick bottom-left, the jump
	button bottom-right) would swallow swipes that start there and sit on
	top of the depth dial. The avatar cannot walk anyway, so turn them off.
]]

UserInputService.ModalEnabled = true
task.spawn(function()
	local ok, err = pcall(function()
		local scripts = player:WaitForChild("PlayerScripts", 10)
		local module = if scripts then scripts:WaitForChild("PlayerModule", 10) else nil
		if module then
			local controls = (require(module) :: any):GetControls()
			controls:Disable()
		end
	end)
	if not ok then
		warn(`[Speed Cube] could not disable the default touch controls: {err}`)
	end
end)

--------------------------------------------------------------------------------
-- Build
--------------------------------------------------------------------------------

local toasts = Toasts.build()
local gui = Theme.screen("SpeedCube", player:WaitForChild("PlayerGui"))

local collection: CollectionPanel.Api
local hud = Hud.build(gui, {
	depth = function(delta)
		fire(N.SetDepth, delta)
	end,
	collection = function()
		collection.frame.Visible = not collection.frame.Visible
	end,
})
collection = CollectionPanel.build(gui, {
	buy = function(boxId)
		fire(N.RollBox, boxId)
	end,
	equip = function(cubeId)
		fire(N.Equip, cubeId)
	end,
	close = function()
		collection.frame.Visible = false
	end,
})

local cube: CubeView.Api? = nil
local cubeRoot = CFrame.new() -- the live cube's centre, from Sync
local isTouch = Input.isTouch()

--------------------------------------------------------------------------------
-- Deal state (the client's copy)
--------------------------------------------------------------------------------

local deal: Remotes.Deal? = nil
local localStep = 0
local locked = true -- shuffling, popping, or waiting for the first Sync
local lockUntil = 0 -- after a wrong swipe
local dealToken = 0
local awaitingSolve = false
local hatching = false
local equippedId = Cubes.Default

-- Swipes sent and not yet answered: the step this screen was on AFTER
-- each one. The server's answer must land on the same step.
type Pending = { seq: number, step: number }
local pending: { Pending } = {}
local seq = 0

local lastResyncAt = 0
local function requestResync()
	local now = os.clock()
	if now - lastResyncAt < Config.Timing.SyncThrottle then
		return
	end
	lastResyncAt = now
	fire(N.RequestSync)
end

local function showPrompt()
	local current = deal
	if not cube or not current or hatching then
		return
	end
	local nextMove = current.solution[localStep + 1]
	cube.prompt(nextMove)
	local def = if nextMove then Moves.get(nextMove) else nil
	hud.setHint(if def then def.direction else nil, isTouch)
	-- The lane: this arrow and the next few, so a fast player can chain.
	local lane: { string } = {}
	for i = 1, Config.Hud.LaneSize do
		local name = current.solution[localStep + i]
		local moveDef = if name then Moves.get(name) else nil
		if moveDef then
			table.insert(lane, moveDef.direction)
		end
	end
	hud.setQueue(lane)
end

-- The first-play nudge: shown to a player with no solves until their
-- first correct swipe.
local firstPlay = false
local nudged = false

local function applyEquipped(cubeId: string)
	equippedId = cubeId
	local def = Cubes.get(cubeId)
	if cube and def then
		cube.setLook(def.look, def.sound)
	end
end

--[[
	Set the cube up for `current`. If nothing has been swiped yet, play the
	scramble; otherwise (a rejoin or a resync) jump straight to where the
	server says we are.
]]
local function startDeal(current: Remotes.Deal)
	dealToken += 1
	local token = dealToken
	locked = true
	awaitingSolve = false
	deal = current
	localStep = current.step
	pending = {}
	hud.setStep(localStep, current.depth)
	hud.resetClock()
	hud.hideCard()
	hud.setQueue({})
	if cube then
		cube.prompt(nil)
	end
	hud.setHint(nil, isTouch)

	task.spawn(function()
		local view = cube
		if not view then
			return
		end
		while view.isBusy() do
			task.wait(0.05)
		end
		if token ~= dealToken then
			return
		end
		view.reset()
		if current.step == 0 then
			view.shuffle(current.scramble, function()
				if token ~= dealToken then
					return
				end
				locked = false
				showPrompt()
			end)
		else
			for _, move in current.scramble do
				view.applyInstant(move)
			end
			for i = 1, current.step do
				view.applyInstant(current.solution[i])
			end
			locked = false
			showPrompt()
		end
	end)
end

--------------------------------------------------------------------------------
-- Swipes
--------------------------------------------------------------------------------

local function onDirection(direction: Moves.Direction)
	local current = deal
	local view = cube
	if not current or not view or locked or awaitingSolve or hatching then
		return
	end
	if os.clock() < lockUntil then
		return
	end
	local expectedName = current.solution[localStep + 1]
	local expected = if expectedName then Moves.get(expectedName) else nil
	if not expected then
		return
	end

	if expected.direction == direction then
		if localStep == 0 then
			hud.startClock()
		end
		if firstPlay then
			firstPlay = false
			hud.setTutorial(false, isTouch)
		end
		localStep += 1
		view.turn(expected.name)
		hud.setStep(localStep, current.depth)
		if localStep >= current.depth then
			awaitingSolve = true
			view.prompt(nil)
			hud.setHint(nil, isTouch)
			hud.setQueue({})
			-- If the server never confirms (a dropped packet, a desync), ask
			-- for the truth rather than sit here forever.
			task.delay(Config.Timing.ResyncAfter, function()
				if awaitingSolve and deal == current then
					requestResync()
				end
			end)
		else
			showPrompt()
		end
	else
		view.shake()
		view.flashWrong()
		lockUntil = os.clock() + Config.Timing.WrongLockSeconds
		hud.setCombo(0)
	end
	seq += 1
	table.insert(pending, { seq = seq, step = localStep })
	fire(N.Move, direction, current.id, seq)
end

--------------------------------------------------------------------------------
-- Server -> client
--------------------------------------------------------------------------------

local synced = false
local pedestalSeen = 0

Remotes.get(N.Sync).OnClientEvent:Connect(function(state: Remotes.SyncState)
	synced = true
	if pedestalSeen ~= state.pedestalIndex then
		pedestalSeen = state.pedestalIndex
		local root = state.pedestal * CFrame.new(0, Config.Cube.Height, 0)
		cubeRoot = root
		local def = Cubes.get(state.equipped) or (Cubes.get(Cubes.Default) :: Cubes.Def)
		if cube then
			cube.setRoot(root)
		else
			cube = CubeView.build(root, { look = def.look, turnSound = def.sound })
			equippedId = state.equipped
		end
		CameraRig.lockTo(state.pedestal)
	end
	hud.set(state)
	collection.set(state)
	Spectators.set(state.pedestalIndex, state.others)
	if state.equipped ~= equippedId and not hatching then
		applyEquipped(state.equipped)
	end
	if not nudged and state.solves == 0 then
		nudged = true
		firstPlay = true
		hud.setTutorial(true, isTouch)
	end

	local incoming = state.deal
	if not incoming then
		deal = nil
		locked = true
		return
	end
	-- A new deal, or (with nothing in flight) the server's step is not
	-- ours: the server wins, redraw from its step.
	local current = deal
	local isNew = not current or current.id ~= incoming.id
	local drifted = #pending == 0 and incoming.step ~= localStep
	if isNew or drifted then
		startDeal(incoming)
	end
end)

Remotes.get(N.MoveResult).OnClientEvent:Connect(function(result: Remotes.MoveResult)
	local current = deal
	if not current or result.dealId ~= current.id then
		return -- an answer for a deal we have already left
	end
	local head = table.remove(pending, 1)
	if not head or head.seq ~= result.seq or head.step ~= result.step then
		requestResync()
		return
	end
	if result.ignored then
		return -- heard but not judged; our prediction already matched its step
	end
	hud.setCombo(result.combo)
	if result.ok and result.perfect then
		toasts.show("perfect", "PERFECT")
		if cube then
			cube.sound("Perfect")
		end
	end
	if result.ok and result.combo > 0 and result.combo % Config.Hud.ComboChimeEvery == 0 then
		toasts.show("big", `{result.combo} COMBO`)
		if cube then
			cube.sound("Coin")
		end
	end
end)

Remotes.get(N.Solved).OnClientEvent:Connect(function(result: Remotes.SolveResult)
	awaitingSolve = false
	locked = true
	local view = cube
	if view then
		task.spawn(function()
			while view.isBusy() do
				task.wait(0.02)
			end
			view.pop()
		end)
	end
	hud.stopClock(result.seconds)
	hud.addCoins(result.coins)
	hud.showCard(result)
	CameraRig.punch()
end)

Remotes.get(N.Hatched).OnClientEvent:Connect(function(result: Remotes.HatchResult)
	local view = cube
	local def = Cubes.get(result.cubeId)
	if not view or not def then
		return
	end
	hud.setCoins(result.coins)
	collection.frame.Visible = false
	hatching = true
	view.prompt(nil)
	hud.setHint(nil, isTouch)
	hud.setQueue({})
	view.setVisible(false)
	local tier = (Config.Boxes.Tiers :: any)[def.tier]
	local color = if tier then tier.Color else Theme.Colors.Coin
	Hatch.play(cubeRoot, color, function()
		if result.equipped == result.cubeId then
			applyEquipped(result.cubeId)
		end
		view.setVisible(true)
		view.pop()
		local tag = if result.isNew then "NEW  " else `x{result.count}  `
		toasts.show("big", `{tag}{def.name}  ({def.tier})  coins x{def.mult}`)
	end, function()
		hatching = false
		if result.equipped ~= equippedId then
			applyEquipped(result.equipped)
		end
		showPrompt()
	end)
end)

Remotes.get(N.Toast).OnClientEvent:Connect(function(kind: string, text: string)
	toasts.show(kind, text)
end)

--------------------------------------------------------------------------------
-- Input and the handshake
--------------------------------------------------------------------------------

Spectators.start()
Input.start(onDirection)

task.spawn(function()
	local attempts = 0
	while not synced and attempts < 30 do
		fire(N.RequestSync)
		attempts += 1
		task.wait(1)
	end
	if not synced then
		warn("[Speed Cube] no Sync from the server after 30s -- is the server script running?")
	end
end)
