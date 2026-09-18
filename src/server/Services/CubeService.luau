--!strict
--[[
	CubeService.luau -- the collection: boxes, hatching, equipping, and
	Robux purchases.

	The client asks to open a box BY ID and to equip a cube BY ID. This
	file checks the coins, rolls the tier from the box's odds, picks the
	cube, records the copy, equips it when it beats the one on, tells the
	player what hatched, tells everybody else what the pedestal now looks
	like, and re-syncs. Each player gets one box or equip per
	ActionCooldown; anything faster is dropped, so nobody can make the
	whole ring restyle cubes in a loop.

	Robux: MarketplaceService.ProcessReceipt lands here. A product either
	adds coins or hatches boxes for free. Purchase ids are remembered in
	the save so Roblox's retries never grant twice, a purchase counts as
	granted only once the save has been written, and nothing is granted
	to a session that cannot be saved.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boxes = require(Shared.Defs.Boxes)
local Cubes = require(Shared.Defs.Cubes)
local Remotes = require(Shared.Remotes)

local SaveService = require(script.Parent.SaveService)

local CubeService = {}

local N = Remotes.Names
local rng = Random.new()

export type Hooks = {
	sync: (player: Player) -> (),
	pedestalIndexOf: (player: Player) -> number?,
	pedestalOf: (player: Player) -> CFrame?,
}

local hooks: Hooks? = nil
local lastActionAt: { [Player]: number } = {}

local function toast(player: Player, kind: string, text: string)
	Remotes.get(N.Toast):FireClient(player, kind, text)
end

local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastActionAt[player] or 0) < Config.Timing.ActionCooldown then
		return false
	end
	lastActionAt[player] = now
	return true
end

local function rollCube(box: Boxes.Box): Cubes.Def
	local tier = Boxes.rollTier(box, rng:NextNumber())
	local pool = Boxes.pool(tier)
	if #pool == 0 then
		pool = Boxes.pool(Config.Boxes.TierOrder[1])
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function broadcastLook(player: Player, cubeId: string)
	local h = hooks
	if not h then
		return
	end
	local index = h.pedestalIndexOf(player)
	local pedestal = h.pedestalOf(player)
	if index and pedestal then
		Remotes.get(N.SpectateLook):FireAllClients(index, cubeId, pedestal)
	end
end

--[[
	Open one box. `free` skips the coin check (a Robux bundle). Returns
	the result, or nil when nothing happened.
]]
function CubeService.roll(player: Player, boxId: string, free: boolean?): Remotes.HatchResult?
	local box = Boxes.get(boxId)
	local data = SaveService.get(player)
	local h = hooks
	if not box or not data or not h then
		return nil
	end
	if not free then
		if data.coins < box.cost then
			toast(player, "bad", `{box.name} costs {box.cost} coins`)
			return nil
		end
		data.coins -= box.cost
	end

	local def = rollCube(box)
	local before = data.cubes[def.id] or 0
	data.cubes[def.id] = before + 1

	if Cubes.multOf(def.id) > Cubes.multOf(data.equipped) then
		data.equipped = def.id
		broadcastLook(player, def.id)
	end

	local result: Remotes.HatchResult = {
		boxId = box.id,
		cubeId = def.id,
		isNew = before == 0,
		count = before + 1,
		equipped = data.equipped,
		coins = data.coins,
	}
	Remotes.get(N.Hatched):FireClient(player, result)
	h.sync(player)
	return result
end

function CubeService.equip(player: Player, cubeId: string): boolean
	local data = SaveService.get(player)
	local h = hooks
	if not data or not h or not Cubes.get(cubeId) or not data.cubes[cubeId] then
		return false
	end
	if data.equipped ~= cubeId then
		data.equipped = cubeId
		broadcastLook(player, cubeId)
	end
	h.sync(player)
	return true
end

--------------------------------------------------------------------------------
-- Robux
--------------------------------------------------------------------------------

type Product = {
	key: string,
	id: number,
	kind: string,
	amount: number,
	box: string?,
	label: string,
}
local productsById: { [number]: Product } = {}
for _, product in Config.Products :: { Product } do
	if product.id > 0 then
		productsById[product.id] = product
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = productsById[receipt.ProductId]
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not product or not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = SaveService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not SaveService.canSave(player) then
		toast(player, "info", "Your purchase will arrive next time you join")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.receipts, purchaseId) then
		-- Already granted in memory (a retry). It counts only once it is
		-- on disk; until then Roblox keeps asking, which is what we want.
		return if SaveService.save(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Record first, so a retry during the grant cannot grant twice.
	table.insert(data.receipts, purchaseId)
	while #data.receipts > Config.Save.ReceiptsKept do
		table.remove(data.receipts, 1)
	end

	if product.kind == "coins" then
		data.coins += product.amount
		toast(player, "good", `+{product.amount} coins`)
		local h = hooks
		if h then
			h.sync(player)
		end
	elseif product.kind == "box" and product.box then
		for _ = 1, product.amount do
			CubeService.roll(player, product.box, true)
		end
	end

	return if SaveService.save(player)
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function CubeService.init(h: Hooks)
	hooks = h
end

function CubeService.start()
	Remotes.get(N.RollBox).OnServerEvent:Connect(function(player: Player, boxId: any)
		if type(boxId) == "string" and allowed(player) then
			CubeService.roll(player, boxId)
		end
	end)
	Remotes.get(N.Equip).OnServerEvent:Connect(function(player: Player, cubeId: any)
		if type(cubeId) == "string" and allowed(player) then
			CubeService.equip(player, cubeId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return CubeService
