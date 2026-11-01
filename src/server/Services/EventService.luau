-- EventService (Master Plan §26.2): os.time()-scheduled events that every server agrees on,
-- purchasable Server Luck Boosts (§15.3) and admin-triggered events (Admin Abuse Hour).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Events = require(Shared.Config.Events)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local RateLimiter = require(Shared.RateLimiter)

local EventService = {}
local services
local serverBoosts = {} -- {kind, mult, untilTime, by}
local adminEvents: { [string]: number } = {} -- id -> until os.time()
local lastSignature = ""

function EventService.Init(s)
	services = s
end

local function hash01(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return (h % 100000) / 100000
end

local function isWeekend(t: number): boolean
	local wday = tonumber(os.date("!%w", t)) -- 0 = Sunday
	return wday == 0 or wday == 6
end

local function scheduledActive(def, t: number): (boolean, number)
	if adminEvents[def.Id] and adminEvents[def.Id] > t then
		return true, adminEvents[def.Id] - t
	end
	if def.Weekends then
		if isWeekend(t) then
			local secsToday = t % 86400
			return true, 86400 - secsToday
		end
		return false, 0
	end
	if not def.PeriodSeconds then
		return false, 0
	end
	local shifted = t - (def.Offset or 0)
	local period = shifted // def.PeriodSeconds
	local into = shifted % def.PeriodSeconds
	if into >= def.DurationSeconds then
		return false, 0
	end
	if def.RandomChance then
		-- Same seed on every server; random start minute inside the hour
		if hash01(def.Id .. period) > def.RandomChance then
			return false, 0
		end
		local start = math.floor(hash01(def.Id .. "s" .. period) * (def.PeriodSeconds - def.DurationSeconds))
		if into < start or into >= start + def.DurationSeconds then
			return false, 0
		end
		return true, start + def.DurationSeconds - into
	end
	return true, def.DurationSeconds - into
end

function EventService.GetActive()
	local t = os.time()
	local out = {}
	for _, def in Events.List do
		local active, remaining = scheduledActive(def, t)
		if active then
			table.insert(out, { def = def, remaining = remaining })
		end
	end
	return out
end

function EventService.IsActive(id: string): boolean
	for _, e in EventService.GetActive() do
		if e.def.Id == id then
			return true
		end
	end
	return false
end

function EventService.GetLuckMultiplier(): number
	local m = 1
	local now = os.time()
	for _, b in serverBoosts do
		if b.kind == "Luck" and b.untilTime > now then
			m *= b.mult
		end
	end
	return m
end

function EventService.GetCoinMultiplier(): number
	local m = 1
	local now = os.time()
	for _, b in serverBoosts do
		if b.kind == "Coins" and b.untilTime > now then
			m *= b.mult
		end
	end
	return m
end

-- Modifiers merged into LootRoll for a given zone
function EventService.GetLootMods(zoneId: string)
	local rarityMult = {}
	local mutationById = {}
	local mutationAdd = {}
	for _, e in EventService.GetActive() do
		local def = e.def
		if def.RarityMult then
			for k, v in def.RarityMult do
				rarityMult[k] = (rarityMult[k] or 1) * v
			end
		end
		if def.ZoneRarityMult and def.ZoneRarityMult[zoneId] then
			for k, v in def.ZoneRarityMult[zoneId] do
				rarityMult[k] = (rarityMult[k] or 1) * v
			end
		end
		if def.MutationMult then
			for k, v in def.MutationMult do
				mutationById[k] = (mutationById[k] or 1) * v
			end
		end
		if def.MutationAdd then
			for k, v in def.MutationAdd do
				mutationAdd[k] = (mutationAdd[k] or 0) + v
			end
		end
	end
	return rarityMult, mutationById, mutationAdd
end

function EventService.LeviathanMult(): number
	local m = 1
	for _, e in EventService.GetActive() do
		m *= e.def.LeviathanMult or 1
	end
	return m
end

function EventService.NodeMult(): number
	local m = 1
	for _, e in EventService.GetActive() do
		m *= e.def.NodeMult or 1
	end
	return m
end

function EventService.StartServerBoost(kind: string, mult: number, seconds: number, by: Player?)
	-- Stacking purchases extend the duration rather than multiplying further
	for _, b in serverBoosts do
		if b.kind == kind and b.mult == mult and b.untilTime > os.time() then
			b.untilTime += seconds
			EventService.Broadcast(true)
			return
		end
	end
	table.insert(serverBoosts, {
		kind = kind,
		mult = mult,
		untilTime = os.time() + seconds,
		by = by and by.DisplayName or "Admin",
	})
	EventService.Broadcast(true)
end

function EventService.StartAdminEvent(id: string, seconds: number): boolean
	for _, def in Events.List do
		if def.Id == id then
			adminEvents[id] = os.time() + seconds
			EventService.Broadcast(true)
			return true
		end
	end
	return false
end

function EventService.Snapshot()
	local list = {}
	for _, e in EventService.GetActive() do
		table.insert(list, { Id = e.def.Id, Name = e.def.Name, Desc = e.def.Desc, Remaining = e.remaining, Color = e.def.Color })
	end
	local now = os.time()
	for _, b in serverBoosts do
		if b.untilTime > now then
			table.insert(list, {
				Id = "Server" .. b.kind,
				Name = `Server {b.kind} x{b.mult}`,
				Desc = `Thanks, {b.by}!`,
				Remaining = b.untilTime - now,
				Color = Color3.fromRGB(80, 255, 140),
			})
		end
	end
	return list
end

function EventService.Broadcast(force: boolean?)
	local snap = EventService.Snapshot()
	local sig = ""
	for _, e in snap do
		sig ..= e.Id .. ","
	end
	if force or sig ~= lastSignature then
		local started = {}
		for _, e in snap do
			if not string.find(lastSignature, e.Id .. ",", 1, true) then
				table.insert(started, e.Name)
			end
		end
		lastSignature = sig
		Net.EventsChanged:FireAllClients(snap)
		for _, name in started do
			services.AnnouncementService.Server(`EVENT: {name} has started!`, "Legendary")
		end
	end
end

function EventService.Start()
	task.spawn(function()
		while true do
			EventService.Broadcast(false)
			-- prune expired boosts
			local now = os.time()
			for i = #serverBoosts, 1, -1 do
				if serverBoosts[i].untilTime <= now then
					table.remove(serverBoosts, i)
				end
			end
			task.wait(5)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.wait(3)
		Net.EventsChanged:FireClient(p, EventService.Snapshot())
	end)
end

------------------------------------------------------------------------------------------
-- Event Tokens + event shop
------------------------------------------------------------------------------------------
-- Called for every salvaged relic: tokens only while an event is live
function EventService.AwardTokens(player: Player, relic)
	if #EventService.GetActive() == 0 then
		return
	end
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	local tier = Rarities.TierOf(relic.rarity)
	local cfg = Economy.EventTokens
	local amount = if tier >= Rarities.Epic.Tier then cfg.EpicPlus elseif tier >= Rarities.Rare.Tier then cfg.RarePlus else cfg.Base
	data.EventTokens = (data.EventTokens or 0) + amount
	services.DataService.Replicate(player, "EventTokens")
end

local shopLimiter = RateLimiter.new(4, 1)
local function buyFromEventShop(player: Player, itemId: string)
	local item = nil
	for _, it in Economy.EventShop do
		if it.Id == itemId then
			item = it
		end
	end
	local data = services.DataService.GetData(player)
	if not item or not data then
		return
	end
	if (data.EventTokens or 0) < item.Cost then
		Net.Notify:FireClient(player, "Not enough Event Tokens. Salvage during live events to earn more!", "error")
		return
	end
	data.EventTokens -= item.Cost
	services.DataService.Replicate(player, "EventTokens")
	local lines = services.CurrencyService.GrantReward(player, item.Reward, "EventShop")
	services.AnalyticsService.Custom(player, "EventShopBuy", item.Cost, { CustomField01 = item.Id })
	Net.Notify:FireClient(player, `{item.Name}: {table.concat(lines, ", ")}`, "reward")
end

local startEventService = EventService.Start
function EventService.Start()
	startEventService()
	Net.RequestEventShopBuy.OnServerEvent:Connect(function(player, itemId)
		if shopLimiter:Check(player) and typeof(itemId) == "string" then
			buyFromEventShop(player, itemId)
		end
	end)
end

return EventService
