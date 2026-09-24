--!strict
--[[
	CollectionPanel.luau -- the CUBES screen: boxes to buy, cubes to equip.

	The critic's first pass (2026-09-24, art/critic-log.md) scored this a
	4: the thing being sold was never shown -- blank box cards and a grid
	of question marks. So every card now shows the product: a slowly
	turning 3D cube in its real colours on a tile in its tier colour, or a
	dark silhouette of the one you have not earned; the boxes are drawn as
	the sealed cases the hatch opens, the Pro box visibly the premium one;
	and the hall goes dark behind the panel so the shop is the only lit
	thing on screen. The panel only asks; the server decides.

	Viewports draw parts and nothing else, so the previews are built by
	CubeBuilder.buildPreview (thin sticker parts, not painted faces).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CubeBuilder = require(Shared.CubeBuilder)
local Cubes = require(Shared.Defs.Cubes)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local CollectionPanel = {}

export type Callbacks = {
	buy: (boxId: string) -> (),
	equip: (cubeId: string) -> (),
	close: () -> (),
}

export type Api = {
	frame: Frame,
	set: (state: Remotes.SyncState) -> (),
	setBusy: (busy: boolean) -> (),
}

type Box = { id: string, name: string, cost: number, odds: { [string]: number } }
type Product = { key: string, id: number, kind: string, amount: number, box: string?, label: string }

local C = Theme.Colors
local P = Config.Panel
local INK_DARK = Color3.fromRGB(20, 22, 28)

local function tierColor(tier: string): Color3
	local t = (Config.Boxes.Tiers :: any)[tier]
	return if t then t.Color else C.InkSoft
end

-- A card's tile: the tier colour, pulled most of the way to the panel's
-- surface, so the grid reads as a rarity map at any size.
local function tileColor(tier: string): Color3
	return tierColor(tier):Lerp(C.Surface, P.TileMix)
end

-- A small rounded label in a solid colour: the tier pill, the count badge.
local function pill(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3,
	textSize: number
): TextLabel
	local label = Theme.label(parent, name, text, size, position, textSize, {
		align = Enum.TextXAlignment.Center,
		font = Enum.Font.GothamBlack,
		color = INK_DARK,
	})
	label.BackgroundTransparency = 0
	label.BackgroundColor3 = color
	Theme.corner(label, 999)
	return label
end

--------------------------------------------------------------------------------
-- Viewports
--------------------------------------------------------------------------------

type Spinner = { viewport: ViewportFrame, camera: Camera, distance: number, height: number }

local function viewport(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	distance: number,
	height: number
): Spinner
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.Size = size
	vp.Position = position
	vp.BackgroundTransparency = 1
	vp.Ambient = P.ViewportAmbient
	vp.LightColor = Color3.new(1, 1, 1)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = P.ViewportFov
	camera.CFrame = CFrame.lookAt(Vector3.new(distance, height, distance), Vector3.zero)
	camera.Parent = vp
	vp.CurrentCamera = camera
	return { viewport = vp, camera = camera, distance = distance, height = height }
end

-- The sealed case the hatch opens, in miniature, for a box card.
local function casePreview(parent: Instance, bodyColor: Color3, lidColor: Color3, seamColor: Color3)
	local model = Instance.new("Model")
	model.Name = "Case"
	local function block(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.Parent = model
		return p
	end
	local side = 3.2
	local bodyH = side * 0.78
	local lidH = side * 0.22
	block(
		Vector3.new(side, bodyH, side),
		CFrame.new(0, -0.3, 0),
		bodyColor,
		Enum.Material.SmoothPlastic
	)
	block(
		Vector3.new(side + 0.06, 0.16, side + 0.06),
		CFrame.new(0, -0.3 + bodyH / 2 + 0.08, 0),
		seamColor,
		Enum.Material.Neon
	)
	block(
		Vector3.new(side + 0.24, lidH, side + 0.24),
		CFrame.new(0, -0.3 + bodyH / 2 + 0.16 + lidH / 2, 0),
		lidColor,
		Enum.Material.Metal
	)
	block(
		Vector3.new(side + 0.34, 0.07, side + 0.34),
		CFrame.new(0, -0.3 + bodyH / 2 + 0.16 + lidH - 0.035, 0),
		seamColor,
		Enum.Material.Neon
	)
	model.Parent = parent
end

--------------------------------------------------------------------------------

function CollectionPanel.build(parent: Instance, callbacks: Callbacks): Api
	-- The stage: everything behind the shop goes dark. The client toggles
	-- this frame, and the window sits inside it.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Collection"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Position = UDim2.fromScale(0, 0)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = P.BackdropTransparency
	backdrop.BorderSizePixel = 0
	backdrop.Visible = false
	backdrop.Parent = parent

	local window = Theme.frame(
		backdrop,
		"Window",
		UDim2.new(0, P.Width, 0, P.Height),
		UDim2.new(0.5, -P.Width / 2, 0.5, -P.Height / 2)
	)
	window.BackgroundTransparency = 0
	Theme.stroke(window, P.EdgeColor, 2)
	Theme.padding(window, 14)

	----------------------------------------------------------------------------
	-- Header: the wordmark, the balance as a coin pill, a close cross.
	----------------------------------------------------------------------------
	Theme.label(window, "Title", "CUBES", UDim2.new(0, 220, 0, 36), UDim2.new(0, 0, 0, 0), 26, {
		font = Enum.Font.GothamBlack,
	})
	local coinPill = Theme.frame(
		window,
		"CoinPill",
		UDim2.new(0, 150, 0, 34),
		UDim2.new(1, -206, 0, 1),
		C.SurfaceAlt
	)
	Theme.corner(coinPill, 999)
	local coinDot = Instance.new("Frame")
	coinDot.Name = "Dot"
	coinDot.Size = UDim2.new(0, 20, 0, 20)
	coinDot.Position = UDim2.new(0, 9, 0.5, -10)
	coinDot.BackgroundColor3 = C.Coin
	coinDot.BorderSizePixel = 0
	coinDot.Parent = coinPill
	Theme.corner(coinDot, 999)
	Theme.stroke(coinDot, Color3.fromRGB(255, 220, 130), 2)
	local coinsLabel =
		Theme.label(coinPill, "Coins", "", UDim2.new(1, -40, 1, 0), UDim2.new(0, 36, 0, 0), 18, {
			font = Enum.Font.GothamBlack,
			color = C.Coin,
		})
	local close = Theme.button(
		window,
		"Close",
		"X",
		UDim2.new(0, 36, 0, 36),
		UDim2.new(1, -36, 0, 0),
		C.ButtonMuted,
		callbacks.close
	)
	close.TextSize = 20
	close.Font = Enum.Font.GothamBlack

	----------------------------------------------------------------------------
	-- Boxes: the sealed cases, the Pro one visibly the premium one.
	----------------------------------------------------------------------------
	local boxRow = Instance.new("Frame")
	boxRow.Name = "Boxes"
	boxRow.Size = UDim2.new(1, 0, 0, P.BoxRowHeight)
	boxRow.Position = UDim2.new(0, 0, 0, 46)
	boxRow.BackgroundTransparency = 1
	boxRow.Parent = window
	local boxLayout = Theme.list(boxRow, 16, true)
	boxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	boxLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local buyButtons: { [string]: TextButton } = {}
	local productsByBox: { [string]: Product } = {}
	local coinProducts: { Product } = {}
	for _, product in Config.Products :: { Product } do
		if product.id > 0 then
			if product.kind == "box" and product.box then
				productsByBox[product.box] = product
			elseif product.kind == "coins" then
				table.insert(coinProducts, product)
			end
		end
	end

	local function prompt(product: Product)
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.id)
	end

	local spinners: { Spinner } = {}

	for i, box in Config.Boxes.List :: { Box } do
		local premium = (box.odds.Legendary or 0) > 0
		local style = if premium then P.ProBox else P.BasicBox
		local card = Instance.new("Frame")
		card.Name = box.id
		card.Size = UDim2.new(0, style.Width, 0, style.Height)
		card.BackgroundColor3 = style.Tile
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = boxRow
		Theme.corner(card, 12)
		Theme.stroke(card, style.Edge, if premium then 2.5 else 1.5)
		if premium then
			-- A halo: a second, softer edge outside the first.
			local halo = Instance.new("UIStroke")
			halo.Color = style.Edge
			halo.Thickness = 8
			halo.Transparency = 0.8
			halo.Parent = card
		end
		Theme.padding(card, 12)

		local spinner = viewport(
			card,
			UDim2.new(0, style.Height - 24, 0, style.Height - 24),
			UDim2.new(0, 0, 0, 0),
			5.2,
			3.4
		)
		casePreview(spinner.viewport, style.Body, style.Lid, style.Seam)
		table.insert(spinners, spinner)
		local mark = Theme.label(
			spinner.viewport,
			"Mark",
			"?",
			UDim2.new(1, 0, 1, 0),
			UDim2.new(0, 0, 0, 6),
			style.MarkSize,
			{
				align = Enum.TextXAlignment.Center,
				font = Enum.Font.GothamBlack,
				color = Color3.new(1, 1, 1),
			}
		)
		Theme.stroke(mark, style.Seam, 3)

		local left = style.Height - 12
		Theme.label(
			card,
			"Name",
			box.name,
			UDim2.new(1, -left, 0, 30),
			UDim2.new(0, left, 0, 0),
			if premium then 24 else 20,
			{
				font = Enum.Font.GothamBlack,
			}
		)
		local oddsBits = {}
		for _, tier in Config.Boxes.TierOrder do
			local pct = box.odds[tier] or 0
			if pct > 0 and not (premium and tier == "Legendary") then
				table.insert(oddsBits, `{tier} {pct}%`)
			end
		end
		Theme.label(
			card,
			"Odds",
			table.concat(oddsBits, "   "),
			UDim2.new(1, -left, 0, 18),
			UDim2.new(0, left, 0, 32),
			12,
			{
				color = C.InkSoft,
			}
		)
		if premium then
			pill(
				card,
				"Badge",
				`LEGENDARY {box.odds.Legendary}%`,
				UDim2.new(0, 150, 0, 24),
				UDim2.new(0, left, 0, 54),
				tierColor("Legendary"),
				13
			)
		end
		local buy = Theme.button(
			card,
			"Buy",
			`BUY   {box.cost} coins`,
			UDim2.new(1, -left, 0, 40),
			UDim2.new(0, left, 1, -40),
			C.Coin,
			function()
				callbacks.buy(box.id)
			end
		)
		buy.TextColor3 = INK_DARK
		buy.Font = Enum.Font.GothamBlack
		buyButtons[box.id] = buy

		local product = productsByBox[box.id]
		if product then
			buy.Size = UDim2.new(0.55, -left / 2 - 4, 0, 40)
			Theme.button(
				card,
				"Robux",
				product.label,
				UDim2.new(0.45, -left / 2 - 4, 0, 40),
				UDim2.new(0.55, left / 2 + 4, 1, -40),
				C.Good,
				function()
					prompt(product)
				end
			)
		end
	end

	if #coinProducts > 0 then
		local card = Instance.new("Frame")
		card.Name = "Coins"
		card.Size = UDim2.new(0, 200, 0, P.BasicBox.Height)
		card.BackgroundColor3 = C.SurfaceAlt
		card.BorderSizePixel = 0
		card.LayoutOrder = 99
		card.Parent = boxRow
		Theme.corner(card, 12)
		Theme.stroke(card, C.Good, 1.5)
		Theme.padding(card, 10)
		Theme.label(card, "Name", "COIN PACKS", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), 18, {
			font = Enum.Font.GothamBlack,
		})
		for i, product in coinProducts do
			Theme.button(
				card,
				product.key,
				product.label,
				UDim2.new(1, 0, 0, 32),
				UDim2.new(0, 0, 0, 30 + (i - 1) * 38),
				C.Good,
				function()
					prompt(product)
				end
			)
		end
	end

	----------------------------------------------------------------------------
	-- Cubes: one card per look, the cube itself on a tier-coloured tile.
	----------------------------------------------------------------------------
	local gridTop = 46 + P.BoxRowHeight + 12
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 1, -gridTop)
	grid.Position = UDim2.new(0, 0, 0, gridTop)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = P.EdgeColor
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = window
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingBottom = UDim.new(0, 14)
	gridPad.PaddingTop = UDim.new(0, 2)
	gridPad.Parent = grid
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, P.Card.Width, 0, P.Card.Height)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	type Card = {
		frame: Frame,
		edge: UIStroke,
		tint: Frame,
		count: TextLabel,
		equipped: TextLabel,
		lock: TextLabel,
		equip: TextButton,
		lit: Model,
		dark: Model,
		spinner: Spinner,
		order: number,
	}
	local cards: { [string]: Card } = {}

	for i, def in Cubes.List do
		local card = Instance.new("Frame")
		card.Name = def.id
		card.BackgroundColor3 = tileColor(def.tier)
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = grid
		Theme.corner(card, 12)
		local edge = Theme.stroke(card, tierColor(def.tier), 1.5)
		Theme.padding(card, 8)

		local art = P.Card.Height - 16
		local spinner = viewport(card, UDim2.new(0, art, 0, art), UDim2.new(0, 0, 0, 0), 4.6, 3.4)
		local lit = CubeBuilder.buildPreview(spinner.viewport, def.look, false)
		local dark = CubeBuilder.buildPreview(spinner.viewport, def.look, true)
		dark.Parent = nil
		table.insert(spinners, spinner)

		-- A tint over the art for a locked cube, so the silhouette reads as
		-- "not yet" and not as "broken".
		local tint = Instance.new("Frame")
		tint.Name = "Tint"
		tint.Size = UDim2.fromScale(1, 1)
		tint.BackgroundColor3 = Color3.new(0, 0, 0)
		tint.BackgroundTransparency = 0.55
		tint.BorderSizePixel = 0
		tint.ZIndex = 2
		tint.Parent = spinner.viewport
		Theme.corner(tint, 10)
		local lock = pill(
			spinner.viewport,
			"Lock",
			"LOCKED",
			UDim2.new(0, 70, 0, 20),
			UDim2.new(0.5, -35, 1, -26),
			C.ButtonMuted,
			11
		)
		lock.TextColor3 = C.Ink
		lock.ZIndex = 3
		local count = pill(
			spinner.viewport,
			"Count",
			"",
			UDim2.new(0, 34, 0, 20),
			UDim2.new(1, -36, 0, 2),
			tierColor(def.tier),
			12
		)
		count.ZIndex = 3
		count.Visible = false

		local left = art + 10
		Theme.label(
			card,
			"Name",
			def.name,
			UDim2.new(1, -left, 0, 24),
			UDim2.new(0, left, 0, 0),
			18,
			{
				font = Enum.Font.GothamBlack,
			}
		)
		pill(
			card,
			"Tier",
			string.upper(def.tier),
			UDim2.new(0, 78, 0, 20),
			UDim2.new(0, left, 0, 28),
			tierColor(def.tier),
			11
		)
		Theme.label(
			card,
			"Mult",
			`coins x{def.mult}`,
			UDim2.new(1, -left, 0, 18),
			UDim2.new(0, left, 0, 52),
			12,
			{
				color = C.InkSoft,
			}
		)
		local equipped = pill(
			card,
			"Equipped",
			"EQUIPPED",
			UDim2.new(1, -left, 0, 22),
			UDim2.new(0, left, 1, -24),
			tierColor(def.tier),
			12
		)
		equipped.Visible = false
		local equip = Theme.button(
			card,
			"Equip",
			"EQUIP",
			UDim2.new(1, -left, 0, 30),
			UDim2.new(0, left, 1, -30),
			C.Button,
			function()
				callbacks.equip(def.id)
			end
		)
		equip.TextSize = 14
		cards[def.id] = {
			frame = card,
			edge = edge,
			tint = tint,
			count = count,
			equipped = equipped,
			lock = lock,
			equip = equip,
			lit = lit,
			dark = dark,
			spinner = spinner,
			order = i,
		}
	end

	----------------------------------------------------------------------------
	-- The spin, and scrolling the equipped cube into view when opened.
	----------------------------------------------------------------------------
	local angle = 0
	local spinning: RBXScriptConnection? = nil
	local equippedId: string? = nil

	local function place()
		for _, s in spinners do
			s.camera.CFrame = CFrame.lookAt(
				Vector3.new(
					math.cos(angle) * s.distance * 1.3,
					s.height,
					math.sin(angle) * s.distance * 1.3
				),
				Vector3.zero
			)
		end
	end

	local function setSpinning(on: boolean)
		if on and not spinning then
			spinning = RunService.RenderStepped:Connect(function(dt: number)
				angle += dt * P.SpinRadiansPerSecond
				place()
			end)
		elseif not on and spinning then
			spinning:Disconnect()
			spinning = nil
		end
	end
	place()

	local function scrollToEquipped()
		local card = if equippedId then cards[equippedId] else nil
		if not card then
			return
		end
		local columns = math.max(1, math.floor((grid.AbsoluteSize.X + 10) / (P.Card.Width + 10)))
		local row = math.floor((card.order - 1) / columns)
		grid.CanvasPosition = Vector2.new(0, row * (P.Card.Height + 10))
	end

	backdrop:GetPropertyChangedSignal("Visible"):Connect(function()
		setSpinning(backdrop.Visible)
		if backdrop.Visible then
			task.defer(scrollToEquipped)
		end
	end)

	----------------------------------------------------------------------------
	-- Setters
	----------------------------------------------------------------------------

	local function set(state: Remotes.SyncState)
		coinsLabel.Text = tostring(state.coins)
		equippedId = state.equipped
		for _, box in Config.Boxes.List :: { Box } do
			local button = buyButtons[box.id]
			Theme.setEnabled(button, state.coins >= box.cost, C.Coin)
			button.TextColor3 = if state.coins >= box.cost then INK_DARK else C.InkSoft
		end
		for id, card in cards do
			local owned = state.cubes[id]
			local isOn = state.equipped == id
			if owned then
				card.lit.Parent = card.spinner.viewport
				card.dark.Parent = nil
				card.tint.Visible = false
				card.lock.Visible = false
				card.count.Visible = owned > 1
				card.count.Text = `x{owned}`
				card.equipped.Visible = isOn
				card.equip.Visible = not isOn
				card.edge.Thickness = if isOn then 3 else 1.5
				card.frame.BackgroundTransparency = 0
			else
				card.lit.Parent = nil
				card.dark.Parent = card.spinner.viewport
				card.tint.Visible = true
				card.lock.Visible = true
				card.count.Visible = false
				card.equipped.Visible = false
				card.equip.Visible = false
				card.edge.Thickness = 1.5
				card.frame.BackgroundTransparency = 0.35
			end
		end
	end

	local function setBusy(busy: boolean)
		for _, button in buyButtons do
			button.Active = not busy
		end
	end

	return { frame = backdrop, set = set, setBusy = setBusy }
end

return CollectionPanel
