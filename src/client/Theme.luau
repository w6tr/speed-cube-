--!strict
--[[
	Theme.luau -- the UI kit.

	Colours, and a handful of constructors so every panel builds the
	same-looking widgets without repeating twenty property lines each time.
]]

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(240, 242, 246),
	InkSoft = Color3.fromRGB(160, 168, 180),
	Surface = Color3.fromRGB(22, 24, 30),
	SurfaceAlt = Color3.fromRGB(36, 40, 48),
	Line = Color3.fromRGB(56, 62, 72),
	Coin = Color3.fromRGB(231, 174, 58),
	Good = Color3.fromRGB(111, 196, 156),
	Bad = Color3.fromRGB(224, 122, 107),
	Info = Color3.fromRGB(86, 156, 236),
	Perfect = Color3.fromRGB(255, 226, 120),
	Button = Color3.fromRGB(86, 156, 236),
	ButtonMuted = Color3.fromRGB(62, 68, 78),
}

function Theme.corner(inst: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

function Theme.padding(inst: Instance, px: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, px)
	pad.PaddingRight = UDim.new(0, px)
	pad.PaddingTop = UDim.new(0, px)
	pad.PaddingBottom = UDim.new(0, px)
	pad.Parent = inst
end

function Theme.stroke(inst: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = inst
	return stroke
end

function Theme.frame(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	color: Color3?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or Theme.Colors.Surface
	frame.BackgroundTransparency = if color then 0 else 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, 10)
	return frame
end

export type LabelOptions = {
	color: Color3?,
	font: Enum.Font?,
	align: Enum.TextXAlignment?,
	wrap: boolean?,
	yAlign: Enum.TextYAlignment?,
}

function Theme.label(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	textSize: number,
	options: LabelOptions?
): TextLabel
	local opts: LabelOptions = options or {}
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = opts.font or Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = opts.color or Theme.Colors.Ink
	label.TextXAlignment = opts.align or Enum.TextXAlignment.Left
	label.TextYAlignment = opts.yAlign or Enum.TextYAlignment.Center
	label.TextWrapped = opts.wrap == true
	label.Text = text
	label.Parent = parent
	return label
end

function Theme.button(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3,
	onClick: () -> ()
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.TextColor3 = Theme.Colors.Ink
	button.Text = text
	button.Parent = parent
	Theme.corner(button, 8)
	button.Activated:Connect(onClick)
	return button
end

--[[
	Grey a button out (still clickable -- the server says no politely) or
	light it up.
]]
function Theme.setEnabled(button: TextButton, enabled: boolean, color: Color3)
	button.BackgroundColor3 = if enabled then color else Theme.Colors.ButtonMuted
	button.TextColor3 = if enabled then Theme.Colors.Ink else Theme.Colors.InkSoft
end

function Theme.list(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

--[[
	A ScreenGui with a UIScale that shrinks the whole layout on small screens
	(phones) and grows it slightly on big ones. Everything is laid out for a
	1280x720 reference.
]]
function Theme.screen(name: string, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent

	local scale = Instance.new("UIScale")
	scale.Parent = gui

	local camera = workspace.CurrentCamera
	local function fit()
		if not camera then
			return
		end
		local v = camera.ViewportSize
		local s = math.min(v.X / 1280, v.Y / 720)
		scale.Scale = math.clamp(s, 0.55, 1.15)
	end
	fit()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return gui
end

return Theme
