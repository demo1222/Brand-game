-- DataService (Master Plan §21): session-locked profiles on DataStoreService, autosave,
-- schema migrations, and state replication to the owning client.
--
-- Session lock: each record stores {Data, Lock = {JobId, Time}}. A server only loads a
-- profile whose lock is absent, its own, or stale (> LOCK_STALE seconds without refresh).
-- Autosave refreshes the lock; release clears it. If another server steals the lock, this
-- server stops saving and kicks the player so items can never be duplicated (§23).
--
-- In Studio without API access the profile runs in memory only (nothing is saved).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local STORE_NAME = "AbyssSalvage_Profiles_v1"
local LOCK_STALE = 180
local AUTOSAVE_SECONDS = 90
local LOAD_ATTEMPTS = 7
local PURCHASE_HISTORY_MAX = 500
local CURRENT_VERSION = 2

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, profile)
DataService.SettingsChanged = Signal.new() -- (player, settings)

local profiles: { [Player]: any } = {}
local releaseHooks: { (Player, any) -> () } = {}
local store: DataStore? = nil
local services

local TEMPLATE = {
	Version = CURRENT_VERSION,
	Coins = 0,
	Pearls = 0,
	LifetimeCoins = 0,
	Uncollected = 0,
	Level = 1,
	XP = 0,
	Rebirths = 0,
	RebirthTokens = 0,
	EventTokens = 0,
	Talents = {},
	Upgrades = {},
	Suit = 1,
	Bag = {},
	Storage = {},
	Stands = {},
	Vault = {},
	Codex = {},
	Pity = {},
	Flares = 3,
	LastLogout = 0,
	PlayTime = 0,
	LoginStreak = 0,
	LastLoginDay = 0,
	LastDailyClaimDay = 0,
	Quests = {},
	TidePass = { SeasonId = "", XP = 0, Premium = false, ClaimedFree = {}, ClaimedPremium = {} },
	PurchaseHistory = {},
	ProductCounts = {},
	ActiveBoosts = {},
	RedeemedCodes = {},
	TradeLog = {},
	StarterPackShownAt = 0,
	StarterPackBought = false,
	LastFreeRevive = 0,
	LastSubPearlsDay = 0,
	LastVipChestDay = 0,
	LastPremiumChest = 0,
	DockName = "",
	RenameTokens = 0,
	Settings = { Music = 0.6, SFX = 0.8, LowScare = false },
	Stats = {
		Dives = 0,
		Deaths = 0,
		Steals = 0,
		TimesRobbed = 0,
		DeepestDepth = 0,
		MythicsFound = 0,
		Salvaged = 0,
	},
	Flags = {},
}

-- Migrations keyed by the version they upgrade FROM (§21.2)
local MIGRATIONS = {
	[1] = function(data)
		-- v1 stored Stands as an array; v2 uses string keys for DataStore safety
		if data.Stands and data.Stands[1] ~= nil then
			local map = {}
			for i, relic in data.Stands do
				map[tostring(i)] = relic
			end
			data.Stands = map
		end
	end,
}

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function migrate(data)
	local v = data.Version or 1
	while v < CURRENT_VERSION do
		local m = MIGRATIONS[v]
		if m then
			m(data)
		end
		v += 1
	end
	data.Version = CURRENT_VERSION
end

local function keyFor(userId: number): string
	return "Player_" .. userId
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	end
	return store
end

local function tryLoad(key: string, force: boolean)
	local ds = getStore()
	if not ds then
		return false, nil, "no datastore"
	end
	local loadedData, lockedBy
	local ok, err = pcall(function()
		ds:UpdateAsync(key, function(record)
			record = record or {}
			local lock = record.Lock
			if
				not force
				and lock
				and lock.JobId ~= game.JobId
				and os.time() - (lock.Time or 0) < LOCK_STALE
			then
				lockedBy = lock
				return nil -- cancel write
			end
			lockedBy = nil
			record.Lock = { JobId = game.JobId, Time = os.time() }
			loadedData = record.Data
			return record
		end)
	end)
	if not ok then
		return false, nil, err
	end
	if lockedBy then
		return false, nil, "locked"
	end
	return true, loadedData, nil
end

local function writeRecord(profile, release: boolean): boolean
	if profile.Offline or profile.LockLost then
		return profile.Offline == true
	end
	local ds = getStore()
	if not ds then
		return false
	end
	local lost = false
	local ok, err = pcall(function()
		ds:UpdateAsync(profile.Key, function(record)
			record = record or {}
			local lock = record.Lock
			if lock and lock.JobId ~= game.JobId then
				lost = true
				return nil
			end
			record.Data = profile.Data
			record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
			return record
		end)
	end)
	if lost then
		profile.LockLost = true
		warn(`[DataService] session lock lost for {profile.Key}; refusing to save`)
		local player = profile.Player
		if player and player.Parent then
			player:Kick("Your data was opened in another server. Please rejoin.")
		end
		return false
	end
	if not ok then
		warn(`[DataService] save failed for {profile.Key}: {err}`)
		return false
	end
	profile.LastSave = os.clock()
	return true
end

local function trimPurchaseHistory(data)
	local count = 0
	for _ in data.PurchaseHistory do
		count += 1
	end
	if count <= PURCHASE_HISTORY_MAX then
		return
	end
	local list = {}
	for id, t in data.PurchaseHistory do
		table.insert(list, { id = id, t = t })
	end
	table.sort(list, function(a, b)
		return a.t < b.t
	end)
	for i = 1, count - PURCHASE_HISTORY_MAX do
		data.PurchaseHistory[list[i].id] = nil
	end
end

local function loadProfile(player: Player)
	local key = keyFor(player.UserId)
	local data, offline = nil, false
	local loaded = false
	for attempt = 1, LOAD_ATTEMPTS do
		local ok, result, err = tryLoad(key, attempt == LOAD_ATTEMPTS)
		if ok then
			data = result
			loaded = true
			break
		end
		if err ~= "locked" then
			-- API not enabled (Studio) or DataStore outage
			if RunService:IsStudio() then
				warn(`[DataService] DataStore unavailable in Studio ({err}); using in-memory profile`)
				offline = true
				loaded = true
				break
			end
			warn(`[DataService] load attempt {attempt} failed: {err}`)
		end
		if not player.Parent then
			return nil
		end
		task.wait(if err == "locked" then 5 else 2)
	end
	if not loaded then
		player:Kick("Could not load your data. Please rejoin in a minute.")
		return nil
	end
	if not player.Parent then
		-- left while loading: release the lock we just took
		if not offline then
			writeRecord({ Key = key, Data = data or deepCopy(TEMPLATE) }, true)
		end
		return nil
	end

	data = data or deepCopy(TEMPLATE)
	migrate(data)
	reconcile(data, TEMPLATE)

	local profile = {
		Player = player,
		Key = key,
		Data = data,
		Offline = offline,
		LockLost = false,
		LastSave = os.clock(),
		JoinedAt = os.time(),
		IsNew = data.LastLogout == 0,
	}
	profiles[player] = profile
	return profile
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile or profile.Releasing then
		return
	end
	profile.Releasing = true
	for _, hook in releaseHooks do
		local ok, err = pcall(hook, player, profile)
		if not ok then
			warn("[DataService] release hook error: " .. tostring(err))
		end
	end
	profile.Data.LastLogout = os.time()
	trimPurchaseHistory(profile.Data)
	writeRecord(profile, true)
	profiles[player] = nil
end

function DataService.Init(s)
	services = s
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.GetData(player: Player)
	local p = profiles[player]
	return p and p.Data
end

function DataService.All()
	return profiles
end

-- Register a synchronous hook that runs just before a profile is saved & released.
function DataService.OnRelease(fn: (Player, any) -> ())
	table.insert(releaseHooks, fn)
end

-- Yields. Returns true when the profile is persisted (or when running offline in Studio).
function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	trimPurchaseHistory(profile.Data)
	return writeRecord(profile, false)
end

-- Send selected top-level keys of the profile to the owning client.
function DataService.Replicate(player: Player, ...: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	local payload = {}
	for _, key in { ... } do
		payload[key] = profile.Data[key]
	end
	Net.StateUpdated:FireClient(player, payload)
end

-- Send arbitrary derived values (passes, stats, timers…)
function DataService.Push(player: Player, payload)
	if profiles[player] then
		Net.StateUpdated:FireClient(player, payload)
	end
end

function DataService.FullSnapshot(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local payload = table.clone(profile.Data)
	payload.PurchaseHistory = nil
	payload.UserId = player.UserId
	Net.StateUpdated:FireClient(player, payload)
end

function DataService.Template()
	return deepCopy(TEMPLATE)
end

function DataService.Start()
	local function onAdded(player: Player)
		local profile = loadProfile(player)
		if profile then
			DataService.ProfileLoaded:Fire(player, profile)
		end
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onAdded, p)
	end
	Players.PlayerRemoving:Connect(releaseProfile)

	Net.ClientReady.OnServerEvent:Connect(function(player)
		-- Client UI is up: send the full snapshot (profile may still be loading)
		for _ = 1, 60 do
			if profiles[player] then
				break
			end
			task.wait(0.5)
		end
		DataService.FullSnapshot(player)
		if services.MonetizationService then
			services.MonetizationService.PushOwnership(player)
		end
		if services.UpgradeService then
			services.UpgradeService.PushDerived(player)
		end
	end)

	Net.UpdateSettings.OnServerEvent:Connect(function(player, settings)
		local profile = profiles[player]
		if not profile or typeof(settings) ~= "table" then
			return
		end
		local s = profile.Data.Settings
		if typeof(settings.Music) == "number" then
			s.Music = math.clamp(settings.Music, 0, 1)
		end
		if typeof(settings.SFX) == "number" then
			s.SFX = math.clamp(settings.SFX, 0, 1)
		end
		if typeof(settings.LowScare) == "boolean" then
			s.LowScare = settings.LowScare
		end
		-- Diver appearance toggles (Diver window); missing keys mean "shown"
		for _, key in { "SuitHelmet", "SuitTank", "SuitFins", "SuitGear", "SuitColors" } do
			if typeof(settings[key]) == "boolean" then
				s[key] = settings[key]
			end
		end
		DataService.Replicate(player, "Settings")
		DataService.SettingsChanged:Fire(player, s)
	end)

	-- Autosave loop + playtime tracking
	task.spawn(function()
		while true do
			task.wait(10)
			for player, profile in profiles do
				profile.Data.PlayTime += 10
				if os.clock() - profile.LastSave >= AUTOSAVE_SECONDS then
					task.spawn(writeRecord, profile, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local threads = {}
		for player in profiles do
			table.insert(
				threads,
				task.spawn(function()
					releaseProfile(player)
				end)
			)
		end
		local deadline = os.clock() + 25
		while next(profiles) and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
end

return DataService
