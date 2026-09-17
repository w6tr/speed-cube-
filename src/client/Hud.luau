--!strict
--[[
	Hud.luau -- coins, the timer, the combo, the depth dial and the hint.

	Laid out for 1280x720 and scaled by Theme.screen. Nothing here decides
	anything; it shows what init.client tells it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local Hud = {}

export type Callbacks = {
	depth: (delta: number) -> (),
}

export type Api = {
	set: (state: Remotes.SyncState) -> (),
	setStep: (step: number, depth: number) -> (),
	setCombo: (combo: number) -> (),
	setHint: (direction: string?, isTouch: boolean) -> (),
	startClock: () -> (),
	stopClock: (seconds: number) -> (),
	resetClock: () -> (),
	addCoins: (n: number) -> (),
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

function Hud.build(parent: Instance, callbacks: Callbacks): Api
	local C = Theme.Colors

	-- Coins, top-left
	local coinBox = Theme.frame(parent, "Coins", UDim2.new(0, 200, 0, 48), UDim2.new(0, 16, 0, 12))
	Theme.padding(coinBox, 10)
	local coinLabel =
		Theme.label(coinBox, "Value", "0", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 24, {
			color = C.Coin,
		})
	local shownCoins = 0

	-- Timer, top-centre
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
	local bestLabel = Theme.label(
		parent,
		"Best",
		"",
		UDim2.new(0, 260, 0, 22),
		UDim2.new(0.5, -130, 0, 100),
		14,
		{
			align = Enum.TextXAlignment.Center,
			color = C.InkSoft,
		}
	)

	-- Combo, top-right
	local comboBox =
		Theme.frame(parent, "Combo", UDim2.new(0, 200, 0, 48), UDim2.new(1, -216, 0, 12))
	Theme.padding(comboBox, 10)
	local comboLabel =
		Theme.label(comboBox, "Value", "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 20, {
			align = Enum.TextXAlignment.Right,
			color = C.Good,
		})

	-- Hint, bottom-centre
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

	-- Depth dial, bottom-right
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

	local function setCombo(combo: number)
		if combo <= 0 then
			comboLabel.Text = ""
			return
		end
		local mult = comboMult(combo)
		comboLabel.Text = string.format("COMBO %d   x%.1f", combo, mult)
	end

	local function setStep(step: number, depth: number)
		stepLabel.Text = `{step} / {depth} moves`
	end

	local function setHint(direction: string?, isTouch: boolean)
		if not direction then
			hintLabel.Text = ""
			return
		end
		local arrow = ARROWS[direction] or ""
		hintLabel.Text = if isTouch then `SWIPE {arrow}` else `{arrow}   {KEYS[direction]}`
	end

	local function setCoins(n: number)
		shownCoins = n
		coinLabel.Text = `{n} coins`
	end

	local function addCoins(n: number)
		setCoins(shownCoins + n)
	end

	local function set(state: Remotes.SyncState)
		setCoins(state.coins)
		setCombo(state.combo)
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
		setHint = setHint,
		startClock = startClock,
		stopClock = stopClock,
		resetClock = resetClock,
		addCoins = addCoins,
	}
end

return Hud
