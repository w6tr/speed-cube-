--!strict
--[[
	SaveService.luau -- one save table per player.

	Coins, solves, best times per depth, the depth dial, the cube
	collection, the equipped cube and the last purchase receipts. The
	rules are the ones that keep progress safe (the same ones Drop & Roll
	and Squadrun use):

	1. ONE key per player, ONE table holding everything.
	2. Load inside pcall with retries. If every retry fails, hand out
	   defaults BUT flag the session and NEVER save it.
	3. Save on PlayerRemoving AND in game:BindToClose.
	4. Autosave on a fixed clock, staggered.
	5. `version` field + migration by filling defaults, never wiping.
	6. Save with UpdateAsync and use the old value: a newer lastSeen from
	   another server wins.
	7. Studio testing needs Game Settings -> Security -> "Enable Studio
	   Access to API Services" and a published place.

	No other file touches DataStoreService.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cubes = require(Shared.Defs.Cubes)

export type PlayerData = {
	version: number,
	coins: number,
	solves: number,
	best: { [string]: number }, -- best seconds, keyed by depth as a string
	depth: number, -- the dial
	cubes: { [string]: number }, -- cube id -> copies owned
	equipped: string, -- cube id
	receipts: { string }, -- Robux purchase ids already granted
	lastSeen: number,
}

type Session = {
	data: PlayerData,
	loadFailed: boolean,
	storedLastSeen: number,
	lastAutosave: number,
	saving: boolean,
	conflicted: boolean,
}

local SaveService = {}

local store: DataStore? = nil
local sessions: { [Player]: Session } = {}

function SaveService.defaultData(): PlayerData
	return {
		version = Config.Save.SchemaVersion,
		coins = 0,
		solves = 0,
		best = {},
		depth = Config.Depth.Start,
		cubes = { [Cubes.Default] = 1 },
		equipped = Cubes.Default,
		receipts = {},
		lastSeen = 0,
	}
end

local function migrate(raw: any): PlayerData
	local defaults = SaveService.defaultData()
	if type(raw) ~= "table" then
		return defaults
	end
	local data = raw :: { [string]: any }
	for key, value in defaults :: any do
		if data[key] == nil or type(data[key]) ~= type(value) then
			data[key] = value
		end
	end
	data.version = Config.Save.SchemaVersion
	return data :: PlayerData
end

-- Repair what a bad save or an old schema could leave behind.
local function sanitise(data: PlayerData)
	for key, value in data.best :: { [string]: any } do
		if type(value) ~= "number" or value <= 0 then
			data.best[key] = nil
		end
	end
	for id, count in data.cubes :: { [string]: any } do
		if not Cubes.get(id) or type(count) ~= "number" or count < 1 then
			data.cubes[id] = nil
		end
	end
	if not data.cubes[Cubes.Default] then
		data.cubes[Cubes.Default] = 1
	end
	if not data.cubes[data.equipped] then
		data.equipped = Cubes.Default
	end
end

local function keyFor(player: Player): string
	return Config.Save.KeyPrefix .. player.UserId
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.DataStoreName)
	end)
	if ok then
		store = result
		return result
	end
	warn(`[SaveService] DataStore unavailable: {result}`)
	return nil
end

--[[
	Yields. Returns the data and whether the load FAILED (defaults that
	must never be saved).
]]
function SaveService.load(player: Player): (PlayerData, boolean)
	local existing = sessions[player]
	if existing then
		return existing.data, existing.loadFailed
	end

	local dataStore = getStore()
	local loaded: any = nil
	local failed = true
	if dataStore then
		-- In Studio without API access every attempt fails instantly, so
		-- one is enough; retrying would only delay the first deal.
		local attempts = if RunService:IsStudio() then 1 else Config.Save.LoadRetries
		for attempt = 1, attempts do
			local ok, result = pcall(function()
				return dataStore:GetAsync(keyFor(player))
			end)
			if ok then
				loaded = result
				failed = false
				break
			end
			warn(`[SaveService] load attempt {attempt} failed for {player.Name}: {result}`)
			if attempt < attempts then
				task.wait(Config.Save.RetryDelay)
			end
		end
	end
	if failed and RunService:IsStudio() then
		warn("[SaveService] Studio: no DataStore access, playing without saving")
	end

	local data = migrate(loaded)
	sanitise(data)
	if not player.Parent then
		-- They left during the retries. Registering a session now would
		-- autosave a ghost forever; hand the data back and forget it.
		return data, failed
	end
	sessions[player] = {
		data = data,
		loadFailed = failed,
		storedLastSeen = data.lastSeen,
		lastAutosave = os.clock() - Config.Save.AutosaveSeconds + 20 + (player.UserId % 10),
		saving = false,
		conflicted = false,
	}
	return data, failed
end

function SaveService.get(player: Player): PlayerData?
	local session = sessions[player]
	return if session then session.data else nil
end

--[[
	Can this session be written back? False after a failed load or a
	conflict; a purchase must not be granted to a session that cannot
	keep it.
]]
function SaveService.canSave(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and not session.loadFailed and not session.conflicted
end

--[[
	Yields. Returns true if the data is now safely stored.
]]
function SaveService.save(player: Player): boolean
	local session = sessions[player]
	if not session or session.loadFailed or session.conflicted then
		return false
	end
	local dataStore = getStore()
	if not dataStore then
		return false
	end
	while session.saving do
		task.wait(0.1)
	end
	if sessions[player] ~= session then
		return false
	end
	session.saving = true

	local data = session.data
	local skipped = false
	local ok, err = pcall(function()
		dataStore:UpdateAsync(keyFor(player), function(old: any)
			if
				type(old) == "table"
				and type(old.lastSeen) == "number"
				and old.lastSeen > session.storedLastSeen
			then
				skipped = true
				return nil
			end
			data.lastSeen = os.time()
			return data
		end)
	end)
	session.saving = false

	if not ok then
		warn(`[SaveService] save failed for {player.Name}: {err}`)
		return false
	end
	if skipped then
		warn(`[SaveService] skipped save for {player.Name}: a newer copy exists elsewhere`)
		session.conflicted = true
		return false
	end
	session.storedLastSeen = data.lastSeen
	return true
end

--[[
	Save and forget. Called last on PlayerRemoving.
]]
function SaveService.release(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if not session.loadFailed then
		for attempt = 1, 3 do
			if SaveService.save(player) or session.conflicted then
				break
			end
			if attempt < 3 then
				task.wait(attempt * 2)
			end
		end
	end
	sessions[player] = nil
end

function SaveService.start()
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for player, session in sessions do
				if now - session.lastAutosave >= Config.Save.AutosaveSeconds then
					session.lastAutosave = now
					task.spawn(SaveService.save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, _ in sessions do
			pending += 1
			task.spawn(function()
				SaveService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + (if RunService:IsStudio() then 8 else 25)
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.delay(1, function()
			if sessions[player] then
				SaveService.release(player)
			end
		end)
	end)
end

return SaveService
