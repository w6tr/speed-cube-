--!strict
--[[
	Toasts.luau -- short messages that appear over the cube and fade.

	Kinds: "info" (blue), "good" (green), "bad" (red), "big" (green, larger,
	stays longer), "perfect" (yellow, tiny, gone in half a second), "coins"
	(gold, large).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Toasts = {}

export type Api = {
	show: (kind: string, text: string) -> (),
}

type Style = { color: Color3, seconds: number, size: number, height: number }

local STYLES: { [string]: Style } = {
	info = { color = Theme.Colors.Info, seconds = 2.2, size = 15, height = 32 },
	good = { color = Theme.Colors.Good, seconds = 2.2, size = 15, height = 32 },
	bad = { color = Theme.Colors.Bad, seconds = 1.6, size = 15, height = 32 },
	big = { color = Theme.Colors.Good, seconds = 3.2, size = 20, height = 42 },
	perfect = { color = Theme.Colors.Perfect, seconds = 0.45, size = 16, height = 28 },
	coins = { color = Theme.Colors.Coin, seconds = 1.4, size = 24, height = 46 },
}

function Toasts.build(): Api
	local gui = Theme.screen("Toasts", Players.LocalPlayer:WaitForChild("PlayerGui"))
	gui.DisplayOrder = 50

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.Size = UDim2.new(0, 460, 0, 220)
	column.Position = UDim2.new(0.5, -230, 0, 96)
	column.BackgroundTransparency = 1
	column.Parent = gui
	local layout = Theme.list(column, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function show(kind: string, text: string)
		local style = STYLES[kind] or STYLES.info
		local toast = Instance.new("TextLabel")
		toast.AutomaticSize = Enum.AutomaticSize.X
		toast.Size = UDim2.new(0, 0, 0, style.height)
		toast.BackgroundColor3 = Theme.Colors.Surface
		toast.BackgroundTransparency = 0.1
		toast.BorderSizePixel = 0
		toast.Font = Enum.Font.GothamBlack
		toast.TextSize = style.size
		toast.TextColor3 = style.color
		toast.Text = text
		toast.Parent = column
		Theme.corner(toast, 8)
		Theme.stroke(toast, style.color, 1)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)
		pad.Parent = toast
		task.delay(style.seconds, function()
			TweenService
				:Create(
					toast,
					TweenInfo.new(0.3),
					{ TextTransparency = 1, BackgroundTransparency = 1 }
				)
				:Play()
			task.wait(0.3)
			toast:Destroy()
		end)
	end

	return { show = show }
end

return Toasts
