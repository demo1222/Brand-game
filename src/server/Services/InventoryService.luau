-- InventoryService (Master Plan §5.2, §7, §13.2, §21): relic instances with UIDs.
--   Bag      – relics carried on the current dive; lost on death (§10.3).
--   Storage  – relics secured at the dock (bag empties into it when you get home).
--   Stands / Vault – displayed relics (DockService).
-- Relics are always MOVED between containers, never copied (§23 anti-dupe).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Formulas = require(Shared.Formulas)
local LootRoll = require(Shared.LootRoll)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)

local STORAGE_MAX = 80

local InventoryService = {}
local services
local limiter = RateLimiter.new(10, 4)
local rng = Random.new()

function InventoryService.Init(s)
	services = s
end

function InventoryService.CreateRelic(player: Player?, roll): any
	return {
		uid = HttpService:GenerateGUID(false),
		id = roll.id,
		rarity = roll.rarity,
		mutations = roll.mutations or {},
		size = roll.size or 1,
		foundAt = os.time(),
		foundBy = if player then player.UserId else 0,
		locked = false,
	}
end

-- Returns container name, key/index, relic
function InventoryService.Find(data, uid: string)
	for i, r in data.Bag do
		if r.uid == uid then
			return "Bag", i, r
		end
	end
	for i, r in data.Storage do
		if r.uid == uid then
			return "Storage", i, r
		end
	end
	for k, r in data.Stands do
		if r.uid == uid then
			return "Stands", k, r
		end
	end
	for k, r in data.Vault do
		if r.uid == uid then
			return "Vault", k, r
		end
	end
	return nil, nil, nil
end

-- Removes the relic from wherever it is and returns it.
function InventoryService.Take(data, uid: string)
	local where, key, relic = InventoryService.Find(data, uid)
	if not where then
		return nil, nil
	end
	if where == "Bag" or where == "Storage" then
		table.remove(data[where], key)
	else
		data[where][key] = nil
	end
	return relic, where
end

function InventoryService.BagFull(player: Player): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return true
	end
	return #data.Bag >= Formulas.BagSize(data, services.MonetizationService.OwnedSet(player))
end

function InventoryService.AddToBag(player: Player, relic): boolean
	local data = services.DataService.GetData(player)
	if not data or InventoryService.BagFull(player) then
		return false
	end
	table.insert(data.Bag, relic)
	services.DataService.Replicate(player, "Bag")
	return true
end

function InventoryService.AddToStorage(player: Player, relic): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	if #data.Storage >= STORAGE_MAX then
		-- Storage full: auto-sell the incoming relic so nothing is silently lost
		local price = Formulas.SellPrice(relic, services.DockService.GetCoinMultiplier(player))
		services.CurrencyService.AddCoins(player, price, "AutoSell")
		Net.Notify:FireClient(player, `Storage full — sold {Relics.ById[relic.id].Name} for {NumberFormat.short(price)}`, "info")
		return true
	end
	table.insert(data.Storage, relic)
	services.DataService.Replicate(player, "Storage")
	return true
end

-- Bag → Storage when the diver gets home safely (§5.2 "Escape")
function InventoryService.SecureBag(player: Player): number
	local data = services.DataService.GetData(player)
	if not data or #data.Bag == 0 then
		return 0
	end
	local n = #data.Bag
	for _, relic in data.Bag do
		InventoryService.AddToStorage(player, relic)
	end
	table.clear(data.Bag)
	services.DataService.Replicate(player, "Bag", "Storage")
	return n
end

-- Records a discovery in the Codex (§7.6). Returns true if it's a new entry.
function InventoryService.RecordCodex(player: Player, relic): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local entry = data.Codex[relic.id]
	if not entry then
		entry = {}
		data.Codex[relic.id] = entry
	end
	local key = relic.mutations[1] or "None"
	if entry[key] then
		return false
	end
	entry[key] = true
	services.DataService.Replicate(player, "Codex")
	services.QuestService.Progress(player, "Codex", 1)
	services.QuestService.AddXp(player, 20)
	InventoryService.CheckCodexMilestones(player)
	return true
end

function InventoryService.CodexPercent(data, zoneIndex: number?): number
	local total, found = 0, 0
	for _, def in Relics.List do
		if not zoneIndex or def.Zone == zoneIndex then
			total += 1
			if data.Codex[def.Id] then
				found += 1
			end
		end
	end
	return if total > 0 then found / total * 100 else 0
end

-- Zone milestone rewards at 10/25/50/75/100% (§7.6)
local MILESTONES = {
	{ 10, { Pearls = 10 } },
	{ 25, { Pearls = 20 } },
	{ 50, { Pearls = 40 } },
	{ 75, { Pearls = 60 } },
	{ 100, { Pearls = 120 } },
}
function InventoryService.CheckCodexMilestones(player: Player)
	local data = services.DataService.GetData(player)
	for _, zone in Zones.List do
		local pct = InventoryService.CodexPercent(data, zone.Index)
		for _, m in MILESTONES do
			local flag = `Codex_{zone.Id}_{m[1]}`
			if pct >= m[1] and not data.Flags[flag] then
				data.Flags[flag] = true
				services.CurrencyService.GrantReward(player, m[2], "Codex")
				Net.Notify:FireClient(player, `Codex: {zone.Name} {m[1]}% complete! +{m[2].Pearls} Pearls`, "reward")
				services.AnalyticsService.Custom(player, "CodexMilestone", m[1], { CustomField01 = zone.Id })
			end
		end
	end
	services.DataService.Replicate(player, "Flags")
end

-- Codex zone completion gives +5% luck in that zone
function InventoryService.ZoneLuckBonus(data, zoneIndex: number): number
	return if data.Flags[`Codex_{Zones.List[zoneIndex].Id}_100`] then 1.05 else 1
end

-- Grant a random relic of a rarity (crates, daily rewards, starter pack)
function InventoryService.GrantRandomRelic(player: Player, rarity: string, source: string)
	if not Rarities[rarity] then
		return nil
	end
	local pool = Relics.ByRarity[rarity]
	if not pool then
		return nil
	end
	local id = pool[rng:NextInteger(1, #pool)].item
	local relic = InventoryService.CreateRelic(player, {
		id = id,
		rarity = rarity,
		mutations = LootRoll.RollMutations(rng),
		size = LootRoll.RollSize(rng),
	})
	InventoryService.AddToStorage(player, relic)
	InventoryService.RecordCodex(player, relic)
	Net.RevealRelic:FireClient(player, relic, source)
	services.AnalyticsService.Custom(player, "RelicGranted", 1, { CustomField01 = source })
	return relic
end

function InventoryService.Sell(player: Player, uid: string): number
	local data = services.DataService.GetData(player)
	if not data then
		return 0
	end
	local where, _, relic = InventoryService.Find(data, uid)
	if not relic or relic.locked or (where ~= "Bag" and where ~= "Storage") then
		return 0
	end
	InventoryService.Take(data, uid)
	local price = Formulas.SellPrice(relic, services.DockService.GetCoinMultiplier(player))
	services.CurrencyService.AddCoins(player, price, "SellRelic")
	services.DataService.Replicate(player, "Bag", "Storage")
	services.QuestService.Progress(player, "Sell", 1)
	return price
end

function InventoryService.CleanBarnacle(player: Player, uid: string): boolean
	local data = services.DataService.GetData(player)
	local _, _, relic = InventoryService.Find(data, uid)
	if not relic or not table.find(relic.mutations, "Barnacled") then
		return false
	end
	local new = LootRoll.RollMutations(rng)
	relic.mutations = new
	services.DataService.Replicate(player, "Bag", "Storage", "Stands", "Vault")
	services.DockService.RefreshDock(player)
	InventoryService.RecordCodex(player, relic)
	Net.RevealRelic:FireClient(player, relic, "Barnacle Clean")
	return true
end

function InventoryService.Start()
	Net.RequestSell.OnServerEvent:Connect(function(player, uid)
		if not limiter:Check(player) or typeof(uid) ~= "string" then
			return
		end
		local price = InventoryService.Sell(player, uid)
		if price > 0 then
			Net.CoinBurst:FireClient(player, price, nil, "Sold!")
		end
	end)

	Net.RequestSellCommons.OnServerEvent:Connect(function(player)
		if not limiter:Check(player) then
			return
		end
		local data = services.DataService.GetData(player)
		if not data then
			return
		end
		local total, count = 0, 0
		for _, list in { data.Bag, data.Storage } do
			for i = #list, 1, -1 do
				local r = list[i]
				if r.rarity == "Common" and not r.locked and #r.mutations == 0 then
					table.remove(list, i)
					total += Formulas.SellPrice(r, services.DockService.GetCoinMultiplier(player))
					count += 1
				end
			end
		end
		if count > 0 then
			services.CurrencyService.AddCoins(player, total, "SellCommons")
			services.QuestService.Progress(player, "Sell", count)
			services.DataService.Replicate(player, "Bag", "Storage")
			Net.CoinBurst:FireClient(player, total, nil, `Sold {count} Commons!`)
		end
	end)

	Net.RequestToggleLock.OnServerEvent:Connect(function(player, uid)
		if not limiter:Check(player) or typeof(uid) ~= "string" then
			return
		end
		local data = services.DataService.GetData(player)
		local where, _, relic = InventoryService.Find(data, uid)
		if relic then
			relic.locked = not relic.locked
			services.DataService.Replicate(player, where)
		end
	end)

	Net.RequestCleanBarnacle.OnServerEvent:Connect(function(player, uid)
		if not limiter:Check(player) or typeof(uid) ~= "string" then
			return
		end
		local data = services.DataService.GetData(player)
		local _, _, relic = InventoryService.Find(data, uid)
		if relic and table.find(relic.mutations, "Barnacled") then
			services.MonetizationService.SetPendingBarnacle(player, uid)
			Net.Offer:FireClient(player, "BarnacleClean")
		end
	end)
end

return InventoryService
