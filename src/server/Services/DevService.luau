-- DevService: server side of the developer test panel (client: DevController).
-- Studio only: every action re-checks RunService:IsStudio() and AdminService.IsAdmin (plus the
-- "unpublished place" case, where game.CreatorId is 0), is rate limited, and validates its
-- argument. The client only sends (action, arg); it never sends amounts or ids it can invent.
--
-- Player attributes (set here, read by the UI for toggle state):
--   DevAdmin, DevGod, DevInfiniteO2, DevInfiniteMoney (bool), DevForceRarity (string)
--
-- Hook for LootService (not installed, see report): at the top of LootService.RollFor, after
-- `local data = ...`:
--   local dev = services.DevService.ForcedRoll(player, zoneIndex); if dev then return dev end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local LootRoll = require(Shared.LootRoll)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Events = require(Shared.Config.Events)
local Quests = require(Shared.Config.Quests)

local HUGE_COINS = 1e15
local MONEY_FLOOR = 1e14 -- infinite money tops up below this

local DevService = {}
local services
local limiter = RateLimiter.new(10, 5)
local rng = Random.new()
local flags: { [Player]: { god: boolean?, o2: boolean?, money: boolean? } } = {}

function DevService.Init(s)
	services = s
end

-- Studio + admin. An unpublished place has CreatorId 0, which no player matches, so Studio
-- testers there are allowed too (this can never be true on a live server: IsStudio is false).
function DevService.IsAllowed(player: Player): boolean
	if not RunService:IsStudio() then
		return false
	end
	if game.CreatorId == 0 then
		return true
	end
	return services.AdminService.IsAdmin(player)
end

local function notify(player: Player, text: string, kind: string?)
	Net.Notify:FireClient(player, text, kind or "info")
end

local function setFlag(player: Player, key: string, attr: string, value: boolean)
	local f = flags[player]
	if not f then
		f = {}
		flags[player] = f
	end
	f[key] = value
	player:SetAttribute(attr, value)
end

------------------------------------------------------------------------------------------
-- Forced rarity (hook for LootService.RollFor)
------------------------------------------------------------------------------------------
-- Returns a roll table {id, rarity, mutations, size} when a one-shot forced rarity is armed for
-- the player (and consumes it), else nil. Pick from the zone's pool, falling back like a normal roll.
function DevService.ForcedRoll(player: Player, zoneIndex: number)
	local rarity = player:GetAttribute("DevForceRarity")
	if typeof(rarity) ~= "string" or rarity == "" or not Rarities[rarity] then
		return nil
	end
	player:SetAttribute("DevForceRarity", "")
	local pool = Relics.PoolFor(zoneIndex, rarity)
	if not pool or #pool == 0 then
		return nil
	end
	return {
		id = pool[rng:NextInteger(1, #pool)].item,
		rarity = rarity,
		mutations = LootRoll.RollMutations(rng),
		size = LootRoll.RollSize(rng),
	}
end

------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------
local function setCoins(player: Player, data, amount: number)
	data.Coins = amount
	data.LifetimeCoins = math.max(data.LifetimeCoins, amount)
	services.DataService.Replicate(player, "Coins", "LifetimeCoins")
	services.CurrencyService.RefreshLeaderstats(player, data)
end

-- One relic into Storage through InventoryService (cap ignored), then the Codex entry.
local function giveRelic(player: Player, id: string, mutation: string?)
	local def = Relics.ById[id]
	local relic = services.InventoryService.CreateRelic(player, {
		id = id,
		rarity = def.Rarity,
		mutations = if mutation then { mutation } else {},
		size = 1,
	})
	services.InventoryService.DevAddToStorage(player, relic)
	services.InventoryService.RecordCodex(player, relic)
end

local function teleport(player: Player, cf: CFrame)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return false
	end
	services.SecurityService.AllowTeleport(player)
	char:PivotTo(cf)
	hrp.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function maxTrack(data, id: string)
	local track = Upgrades.ById[id]
	if track then
		data.Upgrades[id] = track.Max
	end
end

local function afterUpgrades(player: Player)
	services.DataService.Replicate(player, "Upgrades", "Suit")
	services.UpgradeService.PushDerived(player)
	services.UpgradeService.ApplySuitVisual(player)
	services.DockService.RefreshDock(player)
end

------------------------------------------------------------------------------------------
-- Actions: ACTIONS[name] = function(player, data, arg) -> string? (toast text)
------------------------------------------------------------------------------------------
local ACTIONS = {}

-- Relics -------------------------------------------------------------------------------
ACTIONS.GiveAllRelics = function(player, data)
	for _, def in Relics.List do
		giveRelic(player, def.Id, nil)
	end
	services.DataService.Replicate(player, "Storage")
	return `Added {#Relics.List} relics to Storage`
end

ACTIONS.GiveAllMutations = function(player, data)
	local n = 0
	for _, def in Relics.List do
		for _, m in Mutations.List do
			giveRelic(player, def.Id, m.Id)
			n += 1
		end
	end
	services.DataService.Replicate(player, "Storage")
	return `Added {n} mutated relics to Storage`
end

ACTIONS.GiveRelic = function(player, data, arg)
	if typeof(arg) ~= "string" or not Relics.ById[arg] then
		return nil
	end
	giveRelic(player, arg, nil)
	services.DataService.Replicate(player, "Storage")
	return `Added {Relics.ById[arg].Name} to Storage`
end

-- Currency -----------------------------------------------------------------------------
ACTIONS.Coins1M = function(player)
	services.CurrencyService.AddCoins(player, 1e6, "Dev")
	return "+1M Coins"
end
ACTIONS.Coins1B = function(player)
	services.CurrencyService.AddCoins(player, 1e9, "Dev")
	return "+1B Coins"
end
ACTIONS.CoinsHuge = function(player, data)
	setCoins(player, data, HUGE_COINS)
	return `Coins set to {NumberFormat.short(HUGE_COINS)}`
end
ACTIONS.Pearls1K = function(player)
	services.CurrencyService.AddPearls(player, 1000, "Dev")
	return "+1,000 Pearls"
end
ACTIONS.Pearls100K = function(player)
	services.CurrencyService.AddPearls(player, 100000, "Dev")
	return "+100,000 Pearls"
end
ACTIONS.Tokens1K = function(player, data)
	data.EventTokens = (data.EventTokens or 0) + 1000
	services.DataService.Replicate(player, "EventTokens")
	return "+1,000 Event Tokens"
end
ACTIONS.Flares10 = function(player, data)
	data.Flares += 10
	services.DataService.Replicate(player, "Flares")
	return "+10 Flares"
end
ACTIONS.RebirthTokens = function(player, data)
	data.RebirthTokens += 5
	services.DataService.Replicate(player, "RebirthTokens")
	return "+5 Resurface tokens"
end
ACTIONS.ToggleInfiniteMoney = function(player, data)
	local on = not (flags[player] and flags[player].money)
	setFlag(player, "money", "DevInfiniteMoney", on)
	if on then
		setCoins(player, data, HUGE_COINS)
	end
	return if on then "Infinite money ON" else "Infinite money OFF"
end

-- Progress -----------------------------------------------------------------------------
ACTIONS.MaxUpgrades = function(player, data)
	for _, track in Upgrades.Tracks do
		maxTrack(data, track.Id)
	end
	afterUpgrades(player)
	return "All upgrades maxed"
end
ACTIONS.MaxSuit = function(player, data)
	local top = 1
	for i, suit in Upgrades.Suits do
		if not suit.ComingSoon then
			top = i
		end
	end
	data.Suit = top
	afterUpgrades(player)
	return `Suit: {Upgrades.Suits[top].Name}`
end
ACTIONS.MaxBoard = function(player, data)
	maxTrack(data, "Board")
	afterUpgrades(player)
	return "Diving board maxed"
end
ACTIONS.Level50 = function(player, data)
	data.Level = 50
	data.XP = 0
	services.DataService.Replicate(player, "Level", "XP")
	return "Level 50"
end
ACTIONS.CompleteQuests = function(player, data)
	services.QuestService.Progress(player, "DevEnsure", 0) -- makes sure today's quests exist
	local goals = {}
	for _, list in { Quests.Daily, Quests.Weekly } do
		for _, q in list do
			goals[q.Id] = q.Goal
		end
	end
	local n = 0
	for _, list in { data.Quests.Daily or {}, data.Quests.Weekly or {} } do
		for _, entry in list do
			if goals[entry.Id] and not entry.Claimed then
				entry.Progress = goals[entry.Id]
				n += 1
			end
		end
	end
	services.DataService.Replicate(player, "Quests")
	return `{n} quests completed (claim them in Quests)`
end
ACTIONS.UnlockCodex = function(player, data)
	for _, def in Relics.List do
		local entry = data.Codex[def.Id]
		if not entry then
			entry = {}
			data.Codex[def.Id] = entry
		end
		entry.None = true
		for _, m in Mutations.List do
			entry[m.Id] = true
		end
	end
	services.DataService.Replicate(player, "Codex")
	services.InventoryService.CheckCodexMilestones(player)
	return "Codex fully unlocked"
end

-- World --------------------------------------------------------------------------------
ACTIONS.TeleportZone = function(player, data, arg)
	local zone = nil
	for _, z in Zones.List do
		if z.Id == arg then
			zone = z
		end
	end
	if not zone then
		return nil
	end
	local pos = services.WorldService.RandomPointInZone(zone.Index, nil, false)
	if not teleport(player, CFrame.new(pos)) then
		return "No character to teleport"
	end
	return `Teleported to {zone.Name}`
end
ACTIONS.TeleportDock = function(player)
	local dock = services.DockService.GetDock(player)
	if not dock or not teleport(player, dock.SpawnCFrame) then
		return "No dock or character"
	end
	return "Back at your dock"
end
ACTIONS.StartEvent = function(player, data, arg)
	if typeof(arg) ~= "string" then
		return nil
	end
	if services.EventService.StartAdminEvent(arg, 600) then
		return `Event {arg} started (10 min)`
	end
	return nil
end
ACTIONS.ServerLuck = function(player)
	services.EventService.StartServerBoost("Luck", 5, 600, player)
	return "Server luck x5 for 10 min"
end

-- Danger -------------------------------------------------------------------------------
ACTIONS.ToggleGod = function(player)
	local on = not (flags[player] and flags[player].god)
	setFlag(player, "god", "DevGod", on)
	return if on then "God mode ON" else "God mode OFF"
end
ACTIONS.ToggleInfiniteO2 = function(player)
	local on = not (flags[player] and flags[player].o2)
	setFlag(player, "o2", "DevInfiniteO2", on)
	return if on then "Infinite oxygen ON" else "Infinite oxygen OFF"
end
ACTIONS.RefillOxygen = function(player)
	services.DiveService.RefillOxygen(player)
	return "Oxygen refilled"
end
ACTIONS.SpawnLeviathan = function(player)
	if services.PredatorService.DevSpawnNear(player) then
		return "Leviathan spawned near you (it only hunts below 780 m)"
	end
	return "No character"
end
ACTIONS.ClearLeviathans = function()
	services.PredatorService.DevClear(true)
	return "All Leviathans removed (paused)"
end
ACTIONS.RestoreLeviathans = function()
	services.PredatorService.DevClear(false)
	return "Leviathans back to normal"
end
ACTIONS.SkipPity = function(player, data)
	for _, zone in Zones.List do
		data.Pity[zone.Id] = Zones.PityCap
	end
	services.DataService.Replicate(player, "Pity")
	return "Pity maxed in every zone"
end
ACTIONS.ForceRarity = function(player, data, arg)
	if arg == "" or arg == nil then
		player:SetAttribute("DevForceRarity", "")
		return "Forced rarity cleared"
	end
	if typeof(arg) ~= "string" or typeof(Rarities[arg]) ~= "table" then
		return nil
	end
	player:SetAttribute("DevForceRarity", arg)
	return `Next salvage is forced to {arg} (needs the LootService hook)`
end
ACTIONS.ResetGate = function(player)
	services.DockService.ResetGateCooldown(player)
	return "Gate cooldown reset"
end

-- Data ---------------------------------------------------------------------------------
ACTIONS.ClearRelics = function(player, data, arg)
	if arg ~= "confirm" then
		return nil
	end
	table.clear(data.Bag)
	table.clear(data.Storage)
	services.DataService.Replicate(player, "Bag", "Storage")
	return "Bag and Storage cleared"
end
ACTIONS.ResetData = function(player, data, arg)
	if arg ~= "confirm" then
		return nil
	end
	local fresh = services.DataService.Template()
	for k in data do
		data[k] = nil
	end
	for k, v in fresh do
		data[k] = v
	end
	for _, key in { "god", "o2", "money" } do
		if flags[player] then
			flags[player][key] = false
		end
	end
	player:SetAttribute("DevGod", false)
	player:SetAttribute("DevInfiniteO2", false)
	player:SetAttribute("DevInfiniteMoney", false)
	services.DataService.FullSnapshot(player)
	services.CurrencyService.RefreshLeaderstats(player, data)
	services.UpgradeService.PushDerived(player)
	services.UpgradeService.ApplySuitVisual(player)
	services.DockService.RefreshDock(player)
	return "Profile reset to a fresh start"
end
ACTIONS.SaveNow = function(player)
	local ok = services.DataService.SaveNow(player)
	return if ok then "Saved" else "Save failed (Studio without API access?)"
end

------------------------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------------------------
local function onAction(player: Player, action, arg)
	if typeof(action) ~= "string" or not limiter:Check(player) then
		return
	end
	if arg ~= nil and typeof(arg) ~= "string" and typeof(arg) ~= "number" then
		return
	end
	if not DevService.IsAllowed(player) then
		return
	end
	local fn = ACTIONS[action]
	local data = services.DataService.GetData(player)
	if not fn or not data then
		return
	end
	print(`[Dev] {player.Name}: {action} {arg or ""}`)
	local ok, result = pcall(fn, player, data, arg)
	if not ok then
		warn(`[Dev] {action} failed: {result}`)
		notify(player, `Dev action failed: {action}`, "error")
	elseif result then
		notify(player, result, "info")
	end
end

function DevService.Start()
	Net.DevAction.OnServerEvent:Connect(onAction)

	local function hook(player: Player)
		task.spawn(function()
			if DevService.IsAllowed(player) then
				player:SetAttribute("DevAdmin", true)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		flags[p] = nil
		limiter:Remove(p)
	end)

	-- Toggles: god mode restores health every frame (covers Leviathan, hazards, pressure and
	-- drowning without touching those services); infinite oxygen refills the dive state;
	-- infinite money tops coins up once a second.
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		local moneyTick = clock >= 1
		if moneyTick then
			clock = 0
		end
		for player, f in flags do
			if f.god then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
					hum.Health = hum.MaxHealth
				end
			end
			if f.o2 then
				services.DiveService.RefillOxygen(player)
			end
			if f.money and moneyTick then
				local data = services.DataService.GetData(player)
				if data and data.Coins < MONEY_FLOOR then
					setCoins(player, data, HUGE_COINS)
				end
			end
		end
	end)
end

return DevService
