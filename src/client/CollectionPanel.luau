--!strict
--[[
	CollectionPanel.luau -- the CUBES screen: boxes to buy, cubes to equip.

	Top: one card per box (name, cost, odds, BUY, and a Robux button when
	a matching product id is set). Below: one card per cube in the game;
	owned ones show their copies and an EQUIP button, unowned ones are
	greyed with a question mark. The panel only asks; the server decides.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
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

local function tierColor(tier: string): Color3
	local t = (Config.Boxes.Tiers :: any)[tier]
	return if t then t.Color else Theme.Colors.InkSoft
end

function CollectionPanel.build(parent: Instance, callbacks: Callbacks): Api
	local C = Theme.Colors
	local window = Theme.frame(
		parent,
		"Collection",
		UDim2.new(0, 900, 0, 560),
		UDim2.new(0.5, -450, 0.5, -280)
	)
	Theme.stroke(window, C.Line, 1)
	Theme.padding(window, 14)
	window.Visible = false

	Theme.label(window, "Title", "CUBES", UDim2.new(0, 300, 0, 32), UDim2.new(0, 0, 0, 0), 24, {
		font = Enum.Font.GothamBlack,
	})
	local coinsLabel =
		Theme.label(window, "Coins", "", UDim2.new(0, 300, 0, 32), UDim2.new(0.5, -150, 0, 0), 20, {
			align = Enum.TextXAlignment.Center,
			color = C.Coin,
		})
	Theme.button(
		window,
		"Close",
		"CLOSE",
		UDim2.new(0, 100, 0, 32),
		UDim2.new(1, -100, 0, 0),
		C.ButtonMuted,
		callbacks.close
	)

	----------------------------------------------------------------------------
	-- Boxes
	----------------------------------------------------------------------------

	local boxRow = Instance.new("Frame")
	boxRow.Name = "Boxes"
	boxRow.Size = UDim2.new(1, 0, 0, 150)
	boxRow.Position = UDim2.new(0, 0, 0, 42)
	boxRow.BackgroundTransparency = 1
	boxRow.Parent = window
	local boxLayout = Theme.list(boxRow, 12, true)
	boxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

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

	for i, box in Config.Boxes.List :: { Box } do
		local card = Instance.new("Frame")
		card.Name = box.id
		card.Size = UDim2.new(0, 300, 1, 0)
		card.BackgroundColor3 = C.SurfaceAlt
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = boxRow
		Theme.corner(card, 8)
		Theme.stroke(card, C.Coin, 1.5)
		Theme.padding(card, 10)

		Theme.label(card, "Name", box.name, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), 20, {
			font = Enum.Font.GothamBlack,
		})
		local oddsBits = {}
		for _, tier in Config.Boxes.TierOrder do
			local pct = box.odds[tier] or 0
			if pct > 0 then
				table.insert(oddsBits, `{tier} {pct}%`)
			end
		end
		Theme.label(
			card,
			"Odds",
			table.concat(oddsBits, "  "),
			UDim2.new(1, 0, 0, 40),
			UDim2.new(0, 0, 0, 28),
			13,
			{
				color = C.InkSoft,
				wrap = true,
				yAlign = Enum.TextYAlignment.Top,
			}
		)
		local buy = Theme.button(
			card,
			"Buy",
			`BUY  {box.cost} coins`,
			UDim2.new(1, 0, 0, 36),
			UDim2.new(0, 0, 1, -36),
			C.Button,
			function()
				callbacks.buy(box.id)
			end
		)
		buyButtons[box.id] = buy

		local product = productsByBox[box.id]
		if product then
			buy.Size = UDim2.new(0.55, -4, 0, 36)
			Theme.button(
				card,
				"Robux",
				product.label,
				UDim2.new(0.45, -4, 0, 36),
				UDim2.new(0.55, 4, 1, -36),
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
		card.Size = UDim2.new(0, 220, 1, 0)
		card.BackgroundColor3 = C.SurfaceAlt
		card.BorderSizePixel = 0
		card.LayoutOrder = 99
		card.Parent = boxRow
		Theme.corner(card, 8)
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
	-- Cubes
	----------------------------------------------------------------------------

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 1, -204)
	grid.Position = UDim2.new(0, 0, 0, 204)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = C.Line
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.Parent = window
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 200, 0, 118)
	gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	type Card = { frame: Frame, count: TextLabel, equip: TextButton, glyph: TextLabel }
	local cards: { [string]: Card } = {}

	for i, def in Cubes.List do
		local card = Instance.new("Frame")
		card.Name = def.id
		card.BackgroundColor3 = C.SurfaceAlt
		card.BorderSizePixel = 0
		card.LayoutOrder = i
		card.Parent = grid
		Theme.corner(card, 8)
		Theme.stroke(card, tierColor(def.tier), 1.5)
		Theme.padding(card, 8)

		local glyph =
			Theme.label(card, "Glyph", "", UDim2.new(0, 40, 0, 40), UDim2.new(0, 0, 0, 0), 30, {
				font = Enum.Font.GothamBlack,
				color = tierColor(def.tier),
			})
		Theme.label(card, "Name", def.name, UDim2.new(1, -46, 0, 22), UDim2.new(0, 46, 0, 0), 17, {
			font = Enum.Font.GothamBlack,
		})
		Theme.label(
			card,
			"Tier",
			`{def.tier}   x{def.mult}`,
			UDim2.new(1, -46, 0, 18),
			UDim2.new(0, 46, 0, 22),
			12,
			{
				color = tierColor(def.tier),
			}
		)
		Theme.label(card, "Blurb", def.blurb, UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0, 42), 11, {
			color = C.InkSoft,
			wrap = true,
			yAlign = Enum.TextYAlignment.Top,
		})
		local count =
			Theme.label(card, "Count", "", UDim2.new(0.4, 0, 0, 26), UDim2.new(0, 0, 1, -26), 12, {
				color = C.InkSoft,
			})
		local equip = Theme.button(
			card,
			"Equip",
			"EQUIP",
			UDim2.new(0.58, 0, 0, 26),
			UDim2.new(0.42, 0, 1, -26),
			C.Button,
			function()
				callbacks.equip(def.id)
			end
		)
		equip.TextSize = 13
		cards[def.id] = { frame = card, count = count, equip = equip, glyph = glyph }
	end

	----------------------------------------------------------------------------
	-- Setters
	----------------------------------------------------------------------------

	local function set(state: Remotes.SyncState)
		coinsLabel.Text = `{state.coins} coins`
		for _, box in Config.Boxes.List :: { Box } do
			local button = buyButtons[box.id]
			Theme.setEnabled(button, state.coins >= box.cost, C.Button)
		end
		for id, card in cards do
			local owned = state.cubes[id]
			local isOn = state.equipped == id
			if owned then
				card.glyph.Text = "■"
				card.count.Text = if owned > 1 then `x{owned}` else "owned"
				card.equip.Text = if isOn then "EQUIPPED" else "EQUIP"
				Theme.setEnabled(card.equip, not isOn, C.Button)
				card.frame.BackgroundTransparency = 0
			else
				card.glyph.Text = "?"
				card.count.Text = "not yet"
				card.equip.Text = "LOCKED"
				Theme.setEnabled(card.equip, false, C.Button)
				card.frame.BackgroundTransparency = 0.4
			end
		end
	end

	local function setBusy(busy: boolean)
		for _, button in buyButtons do
			button.Active = not busy
		end
	end

	return { frame = window, set = set, setBusy = setBusy }
end

return CollectionPanel
