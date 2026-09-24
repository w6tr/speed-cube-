--!strict
--[[
	Hud.luau -- coins, the timer, the arrow lane, the combo, the solve
	card, the first-play nudge, the depth dial, the CUBES button.

	Laid out for 1280x720 and scaled by Theme.screen. Nothing here decides
	anything; it shows what init.client tells it.

	Top row:      coins + equipped cube (left)   timer + step (centre)   combo (right)
	Under timer:  the ARROW LANE -- the current arrow big, the next two
	              small, so a fast player can chain instead of reading one
	              at a time (the note lane of a rhythm game)
	Centre:       the solve card (between cubes) / the first-play nudge
	Bottom:       CUBES (left), the hint (centre), the depth dial (right)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cubes = require(Shared.Defs.Cubes)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local Hud = {}

export type Callbacks = {
	depth: (delta: number) -> (),
	collection: () -> (),
}

export type Api = {
	set: (state: Remotes.SyncState) -> (),
	setStep: (step: number, depth: number) -> (),
	setCombo: (combo: number) -> (),
	setQueue: (directions: { string }) -> (),
	setHint: (direction: string?, isTouch: boolean) -> (),
	setTutorial: (on: boolean, isTouch: boolean) -> (),
	showCard: (result: Remotes.SolveResult) -> (),
	hideCard: () -> (),
	startClock: () -> (),
	stopClock: (seconds: number) -> (),
	resetClock: () -> (),
	addCoins: (n: number) -> (),
	setCoins: (n: number) -> (),
	setSprint: (phase: string, seconds: number, inRace: boolean?) -> (),
}

local ARROWS: { [string]: string } = { Up = "▲", Down = "▼", Left = "◀", Right = "▶" }
local KEYS: { [string]: string } = {
	Up = "W or Up arrow",
	Down = "S or Down arrow",
	Left = "A or Left arrow",
	Right = "D or Right arrow",
}

local function comboMult(combo: number): number
	return math.min(Config.Combo.MaxMult, 1 + Config.Combo.MultPerCombo * combo)
end

-- The streak's colour climbs through tiers so a long combo LOOKS hotter.
local function comboColor(combo: number): Color3
	local tiers = Config.Hud.ComboTiers
	local color = Theme.Colors.Good
	for _, tier in tiers do
		if combo >= tier.At then
			color = tier.Color
		end
	end
	return color
end

local function tierColor(tier: string): Color3
	local t = (Config.Boxes.Tiers :: any)[tier]
	return if t then t.Color else Theme.Colors.InkSoft
end

function Hud.build(parent: Instance, callbacks: Callbacks): Api
	local C = Theme.Colors
	local H = Config.Hud

	----------------------------------------------------------------------------
	-- Top row
	----------------------------------------------------------------------------

	local coinBox = Theme.frame(parent, "Coins", UDim2.new(0, 220, 0, 66), UDim2.new(0, 16, 0, 12))
	Theme.padding(coinBox, 10)
	local coinLabel =
		Theme.label(coinBox, "Value", "0", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), 24, {
			color = C.Coin,
		})
	local cubeLabel =
		Theme.label(coinBox, "Cube", "", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 28), 13, {
			color = C.InkSoft,
		})
	local shownCoins = 0

	local timerBox =
		Theme.frame(parent, "Timer", UDim2.new(0, 260, 0, 84), UDim2.new(0.5, -130, 0, 12))
	local timerLabel =
		Theme.label(timerBox, "Time", "0.00", UDim2.new(1, 0, 0, 52), UDim2.new(0, 0, 0, 2), 40, {
			align = Enum.TextXAlignment.Center,
			font = Enum.Font.GothamBlack,
		})
	local stepLabel =
		Theme.label(timerBox, "Step", "", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 54), 15, {
			align = Enum.TextXAlignment.Center,
			color = C.InkSoft,
		})

	local comboBox =
		Theme.frame(parent, "Combo", UDim2.new(0, 220, 0, 48), UDim2.new(1, -236, 0, 12))
	Theme.padding(comboBox, 10)
	local comboStroke = Theme.stroke(comboBox, C.Good, 0)
	local comboScale = Instance.new("UIScale")
	comboScale.Parent = comboBox
	local comboLabel =
		Theme.label(comboBox, "Value", "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 20, {
			align = Enum.TextXAlignment.Right,
			color = C.Good,
		})

	----------------------------------------------------------------------------
	-- The arrow lane
	----------------------------------------------------------------------------

	local lane = Instance.new("Frame")
	lane.Name = "Lane"
	lane.Size = UDim2.new(0, 260, 0, H.LaneHeight)
	lane.Position = UDim2.new(0.5, -130, 0, 102)
	lane.BackgroundTransparency = 1
	lane.Parent = parent
	local laneLayout = Theme.list(lane, 14, true)
	laneLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	laneLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local laneGlyphs: { TextLabel } = {}
	for i = 1, H.LaneSize do
		local big = i == 1
		local g = Theme.label(
			lane,
			`Arrow{i}`,
			"",
			UDim2.new(0, if big then 56 else 34, 1, 0),
			UDim2.new(0, 0, 0, 0),
			if big then H.LaneBigSize else H.LaneSmallSize,
			{
				align = Enum.TextXAlignment.Center,
				font = Enum.Font.GothamBlack,
				color = if big then C.Ink else C.InkSoft,
			}
		)
		g.LayoutOrder = i
		table.insert(laneGlyphs, g)
	end

	local bestLabel = Theme.label(
		parent,
		"Best",
		"",
		UDim2.new(0, 300, 0, 22),
		UDim2.new(0.5, -150, 0, 102 + H.LaneHeight),
		14,
		{
			align = Enum.TextXAlignment.Center,
			color = C.InkSoft,
		}
	)
	-- A plate under HUD text. From every seat there is scenery behind this
	-- line, and HUD text printed straight over a 3D hall is unreadable.
	-- (The original offender was the leaderboard pillar, which printed
	-- through it; the pillar is gone, the rule stays.)
	bestLabel.BackgroundColor3 = C.Surface
	bestLabel.BackgroundTransparency = 0.2
	Theme.corner(bestLabel, 6)

	-- The sprint line, under the combo box: "SPRINT IN 1:40" while idle, a
	-- loud countdown, then the race clock. Hidden while fewer than two are
	-- seated. It counts down locally from the last thing the server said.
	local sprintLabel =
		Theme.label(parent, "Sprint", "", UDim2.new(0, 220, 0, 26), UDim2.new(1, -236, 0, 66), 15, {
			align = Enum.TextXAlignment.Right,
			color = C.InkSoft,
			font = Enum.Font.GothamBlack,
		})
	sprintLabel.Visible = false
	local sprintPhase = "off"
	local sprintEndsAt = 0
	local sprintInRace = false

	local function drawSprint()
		local left = math.max(0, sprintEndsAt - os.clock())
		if sprintPhase == "idle" then
			sprintLabel.Text = string.format("SPRINT IN %d:%02d", left // 60, left % 60)
			sprintLabel.TextColor3 = C.InkSoft
			sprintLabel.TextSize = 15
		elseif sprintPhase == "countdown" then
			sprintLabel.Text = `SPRINT IN {math.ceil(left)}`
			sprintLabel.TextColor3 = C.Perfect
			sprintLabel.TextSize = 22
		elseif sprintPhase == "racing" then
			-- A mid-race joiner is watching, not racing: their cube cannot win.
			sprintLabel.Text = if sprintInRace
				then `FIRST POP WINS   {math.ceil(left)}s`
				else "SPRINT ON -- you're in the next one"
			sprintLabel.TextColor3 = if sprintInRace then C.Good else C.InkSoft
			sprintLabel.TextSize = if sprintInRace then 18 else 15
		end
		sprintLabel.Visible = sprintPhase ~= "off"
	end

	local function setSprint(phase: string, seconds: number, inRace: boolean?)
		sprintPhase = phase
		sprintEndsAt = os.clock() + seconds
		sprintInRace = inRace == true
		drawSprint()
	end

	RunService.Heartbeat:Connect(drawSprint)

	----------------------------------------------------------------------------
	-- Hint, nudge, dial, CUBES
	----------------------------------------------------------------------------

	local hintLabel = Theme.label(
		parent,
		"Hint",
		"",
		UDim2.new(0, 500, 0, 40),
		UDim2.new(0.5, -250, 1, -120),
		22,
		{
			align = Enum.TextXAlignment.Center,
			font = Enum.Font.GothamBlack,
		}
	)

	local nudge =
		Theme.frame(parent, "Nudge", UDim2.new(0, 560, 0, 64), UDim2.new(0.5, -280, 1, -200))
	Theme.stroke(nudge, C.Perfect, 2)
	local nudgeLabel =
		Theme.label(nudge, "Text", "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 24, {
			align = Enum.TextXAlignment.Center,
			font = Enum.Font.GothamBlack,
			color = C.Perfect,
		})
	nudge.Visible = false

	local dial = Theme.frame(parent, "Depth", UDim2.new(0, 250, 0, 56), UDim2.new(1, -266, 1, -72))
	Theme.padding(dial, 8)
	local minus = Theme.button(
		dial,
		"Minus",
		"-",
		UDim2.new(0, 40, 0, 40),
		UDim2.new(0, 0, 0, 0),
		C.ButtonMuted,
		function()
			callbacks.depth(-1)
		end
	)
	local depthLabel =
		Theme.label(dial, "Value", "", UDim2.new(1, -96, 1, 0), UDim2.new(0, 48, 0, 0), 15, {
			align = Enum.TextXAlignment.Center,
		})
	local plus = Theme.button(
		dial,
		"Plus",
		"+",
		UDim2.new(0, 40, 0, 40),
		UDim2.new(1, -40, 0, 0),
		C.Button,
		function()
			callbacks.depth(1)
		end
	)

	local cubesButton = Theme.button(
		parent,
		"Cubes",
		"CUBES",
		UDim2.new(0, 150, 0, 48),
		UDim2.new(0, 16, 1, -68),
		C.Coin,
		callbacks.collection
	)
	cubesButton.TextColor3 = C.Surface

	----------------------------------------------------------------------------
	-- The solve card
	----------------------------------------------------------------------------

	local card =
		Theme.frame(parent, "Card", UDim2.new(0, 360, 0, 150), UDim2.new(0.5, -180, 0.5, -160))
	Theme.stroke(card, C.Coin, 2)
	Theme.padding(card, 12)
	local cardTime =
		Theme.label(card, "Time", "", UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 0), 46, {
			align = Enum.TextXAlignment.Center,
			font = Enum.Font.GothamBlack,
		})
	local cardCoins =
		Theme.label(card, "Coins", "", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 56), 26, {
			align = Enum.TextXAlignment.Center,
			font = Enum.Font.GothamBlack,
			color = C.Coin,
		})
	local cardLine =
		Theme.label(card, "Line", "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 92), 16, {
			align = Enum.TextXAlignment.Center,
			color = C.InkSoft,
		})
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	card.Visible = false

	----------------------------------------------------------------------------
	-- The clock
	----------------------------------------------------------------------------

	local clockStart: number? = nil
	local clockConnection: RBXScriptConnection? = nil

	local function stopTicking()
		if clockConnection then
			clockConnection:Disconnect()
			clockConnection = nil
		end
	end

	local function startClock()
		clockStart = os.clock()
		stopTicking()
		clockConnection = RunService.RenderStepped:Connect(function()
			if clockStart then
				timerLabel.Text = string.format("%.2f", os.clock() - clockStart)
			end
		end)
	end

	local function stopClock(seconds: number)
		stopTicking()
		clockStart = nil
		timerLabel.Text = string.format("%.2f", seconds)
	end

	local function resetClock()
		stopTicking()
		clockStart = nil
		timerLabel.Text = "0.00"
	end

	----------------------------------------------------------------------------
	-- Setters
	----------------------------------------------------------------------------

	local lastCombo = 0
	local function setCombo(combo: number)
		local color = comboColor(combo)
		comboLabel.TextColor3 = color
		comboStroke.Color = color
		comboStroke.Thickness = if combo > 0
			then math.min(H.ComboStrokeMax, combo / H.ComboStrokePer)
			else 0
		if combo <= 0 then
			comboLabel.Text = ""
		else
			comboLabel.Text = string.format("COMBO %d   x%.1f", combo, comboMult(combo))
		end
		if combo > lastCombo then
			-- a little punch on every hit, so the streak is felt
			comboScale.Scale = H.ComboPunch
			TweenService
				:Create(comboScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = 1 })
				:Play()
		end
		lastCombo = combo
	end

	local function setStep(step: number, depth: number)
		stepLabel.Text = `{step} / {depth} moves`
	end

	local function setQueue(directions: { string })
		for i, g in laneGlyphs do
			g.Text = ARROWS[directions[i] or ""] or ""
		end
	end

	local function setHint(direction: string?, isTouch: boolean)
		if not direction then
			hintLabel.Text = ""
			return
		end
		local arrow = ARROWS[direction] or ""
		hintLabel.Text = if isTouch then `SWIPE {arrow}` else `{arrow}   {KEYS[direction]}`
	end

	local function setTutorial(on: boolean, isTouch: boolean)
		nudge.Visible = on
		nudgeLabel.Text = if isTouch
			then "SWIPE THE WAY THE ARROW POINTS"
			else "PRESS THE ARROW KEY THE ARROW POINTS"
	end

	local function setCoins(n: number)
		shownCoins = n
		coinLabel.Text = `{n} coins`
	end

	local function addCoins(n: number)
		setCoins(shownCoins + n)
	end

	local function showCard(result: Remotes.SolveResult)
		cardTime.Text = string.format("%.2fs", result.seconds)
		cardTime.TextColor3 = if result.isBest then C.Perfect else C.Ink
		cardCoins.Text = `+{result.coins} coins`
		local bits = {}
		if result.isBest then
			table.insert(bits, "NEW BEST")
		end
		if result.fast then
			table.insert(bits, "FAST")
		end
		if result.perfects > 0 then
			table.insert(bits, `{result.perfects} PERFECT`)
		end
		if result.mult > 1 then
			table.insert(bits, string.format("x%.2f", result.mult))
		end
		cardLine.Text = table.concat(bits, "   ")
		card.Visible = true
		cardScale.Scale = 0.7
		TweenService:Create(cardScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end

	local function hideCard()
		card.Visible = false
	end

	local function set(state: Remotes.SyncState)
		setCoins(state.coins)
		setCombo(state.combo)
		local def = Cubes.get(state.equipped)
		if def then
			cubeLabel.Text = `{def.name}   x{def.mult}`
			cubeLabel.TextColor3 = tierColor(def.tier)
		end
		depthLabel.Text = `DEPTH {state.depth}  (max {state.unlockedDepth})`
		Theme.setEnabled(minus, state.depth > Config.Depth.Min, C.ButtonMuted)
		Theme.setEnabled(plus, state.depth < state.unlockedDepth, C.Button)
		bestLabel.Text = if state.best > 0
			then string.format("BEST %.2fs at depth %d", state.best, state.depth)
			else `no best yet at depth {state.depth}`
		if state.deal then
			setStep(state.deal.step, state.deal.depth)
		end
	end

	return {
		set = set,
		setStep = setStep,
		setCombo = setCombo,
		setQueue = setQueue,
		setHint = setHint,
		setTutorial = setTutorial,
		showCard = showCard,
		hideCard = hideCard,
		startClock = startClock,
		stopClock = stopClock,
		resetClock = resetClock,
		addCoins = addCoins,
		setCoins = setCoins,
		setSprint = setSprint,
	}
end

return Hud
