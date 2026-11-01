-- QuestService (Master Plan §11.3, §15.5, §17): player level/XP, daily & weekly quests,
-- Tide Pass season track, 7-day login calendar, and onboarding timers (Starter Pack at
-- minute 8, Session10min funnel step).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Formulas = require(Shared.Formulas)
local Quests = require(Shared.Config.Quests)
local Economy = require(Shared.Config.Economy)

local TP = Economy.TidePass
local QuestService = {}
local services
local limiter = RateLimiter.new(8, 3)

function QuestService.Init(s)
	services = s
end

local function dayIndex(): number
	return os.time() // 86400
end

local function weekIndex(): number
	return (os.time() + 3 * 86400) // (7 * 86400) -- weeks start Monday 00:00 UTC
end

local function pick(pool, count: number, seed: number)
	local r = Random.new(seed)
	local copy = table.clone(pool)
	local out = {}
	for _ = 1, math.min(count, #copy) do
		local i = r:NextInteger(1, #copy)
		local q = table.remove(copy, i)
		table.insert(out, { Id = q.Id, Progress = 0, Claimed = false })
	end
	return out
end

local function findDef(id: string)
	for _, list in { Quests.Daily, Quests.Weekly } do
		for _, q in list do
			if q.Id == id then
				return q
			end
		end
	end
	return nil
end

local function ensureQuests(player: Player, data)
	local q = data.Quests
	local d, w = dayIndex(), weekIndex()
	local changed = false
	if q.Day ~= d then
		q.Day = d
		q.Daily = pick(Quests.Daily, Quests.DailyCount, d * 7919 + player.UserId)
		changed = true
	end
	if q.Week ~= w then
		q.Week = w
		q.Weekly = pick(Quests.Weekly, Quests.WeeklyCount, w * 104729 + player.UserId)
		changed = true
	end
	if data.TidePass.SeasonId ~= TP.SeasonId then
		data.TidePass = { SeasonId = TP.SeasonId, XP = 0, Premium = false, ClaimedFree = {}, ClaimedPremium = {} }
		changed = true
	end
	if changed then
		services.DataService.Replicate(player, "Quests", "TidePass")
	end
end

function QuestService.Progress(player: Player, stat: string, amount: number)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	local changed = false
	for _, list in { data.Quests.Daily, data.Quests.Weekly } do
		for _, entry in list do
			local def = findDef(entry.Id)
			if def and def.Stat == stat and not entry.Claimed and entry.Progress < def.Goal then
				entry.Progress = math.min(def.Goal, entry.Progress + amount)
				changed = true
				if entry.Progress >= def.Goal then
					Net.Notify:FireClient(player, `Quest complete: {def.Text}! Claim it in Quests.`, "reward")
				end
			end
		end
	end
	if changed then
		services.DataService.Replicate(player, "Quests")
	end
end

function QuestService.AddXp(player: Player, amount: number)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	data.XP += amount
	local leveled = false
	while data.XP >= Formulas.LevelXp(data.Level) do
		data.XP -= Formulas.LevelXp(data.Level)
		data.Level += 1
		leveled = true
		services.CurrencyService.AddPearls(player, 5, "LevelUp")
		local extra = ""
		if data.Level == Economy.Raid.MinLevel then
			extra = " Raiding unlocked!"
		elseif data.Level == Economy.Social.TradeMinLevel then
			extra = " Trading unlocked!"
		end
		Net.Notify:FireClient(player, `Level {data.Level}! +5 Pearls.{extra}`, "upgrade")
	end
	services.DataService.Replicate(player, "XP", "Level")
	if leveled then
		services.AnnouncementService.UpdateTitle(player)
	end
end

function QuestService.AddSeasonXp(player: Player, amount: number): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	ensureQuests(player, data)
	local before = data.TidePass.XP // TP.XpPerTier
	data.TidePass.XP = math.min(data.TidePass.XP + amount, TP.Tiers * TP.XpPerTier)
	local after = data.TidePass.XP // TP.XpPerTier
	if after > before then
		Net.Notify:FireClient(player, `Tide Pass tier {after} reached!`, "reward")
	end
	services.DataService.Replicate(player, "TidePass")
	return true
end

function QuestService.UnlockPremium(player: Player): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	ensureQuests(player, data)
	data.TidePass.Premium = true
	services.DataService.Replicate(player, "TidePass")
	Net.Notify:FireClient(player, "Tide Pass Premium unlocked!", "reward")
	return true
end

-- Tier rewards (§15.5) live in shared Formulas so the Tide Pass UI can preview them
function QuestService.TierReward(tier: number, premium: boolean)
	return Formulas.TierReward(tier, premium)
end

local function claimTier(player: Player, tier: number, premium: boolean)
	local data = services.DataService.GetData(player)
	if not data or tier % 1 ~= 0 or tier < 1 or tier > TP.Tiers then
		return
	end
	ensureQuests(player, data)
	local tp = data.TidePass
	if tp.XP // TP.XpPerTier < tier then
		return
	end
	if premium and not tp.Premium then
		Net.Offer:FireClient(player, "TidePassPremium")
		return
	end
	local claimed = if premium then tp.ClaimedPremium else tp.ClaimedFree
	if claimed[tostring(tier)] then
		return
	end
	claimed[tostring(tier)] = true
	local lines = services.CurrencyService.GrantReward(player, QuestService.TierReward(tier, premium), "TidePass")
	services.DataService.Replicate(player, "TidePass")
	Net.Notify:FireClient(player, `Tier {tier}: {table.concat(lines, ", ")}`, "reward")
end

local function claimQuest(player: Player, id: string)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	for _, list in { data.Quests.Daily, data.Quests.Weekly } do
		for _, entry in list do
			if entry.Id == id then
				local def = findDef(id)
				if def and not entry.Claimed and entry.Progress >= def.Goal then
					entry.Claimed = true
					local lines = services.CurrencyService.GrantReward(player, { Coins = def.Coins, Pearls = def.Pearls }, "Quest")
					QuestService.AddSeasonXp(player, def.Xp)
					services.DataService.Replicate(player, "Quests")
					Net.Notify:FireClient(player, `{def.Text}: {table.concat(lines, ", ")} +{def.Xp} Tide XP`, "reward")
				end
				return
			end
		end
	end
end

-- 7-day login calendar (§17). Streak breaks if a day is missed (Pass+ keeps it).
local function updateLoginStreak(player: Player, data)
	local d = dayIndex()
	if data.LastLoginDay == d then
		return
	end
	if data.LastLoginDay == d - 1 or services.MonetizationService.HasActiveSubscription(player) then
		data.LoginStreak += 1
	else
		data.LoginStreak = 1
	end
	data.LastLoginDay = d
	services.DataService.Replicate(player, "LoginStreak", "LastLoginDay", "LastDailyClaimDay")
end

local function claimDaily(player: Player)
	local data = services.DataService.GetData(player)
	if not data or data.LastDailyClaimDay == dayIndex() then
		return
	end
	data.LastDailyClaimDay = dayIndex()
	local dayInCycle = ((data.LoginStreak - 1) % #Economy.DailyRewards) + 1
	local lines = services.CurrencyService.GrantReward(player, Economy.DailyRewards[dayInCycle], "DailyLogin")
	services.DataService.Replicate(player, "LastDailyClaimDay")
	Net.Notify:FireClient(player, `Day {dayInCycle} reward: {table.concat(lines, ", ")}`, "reward")
end

function QuestService.Start()
	services.DataService.ProfileLoaded:Connect(function(player, profile)
		ensureQuests(player, profile.Data)
		updateLoginStreak(player, profile.Data)
		services.AnalyticsService.Funnel(player, "Join")
	end)

	Net.RequestClaimQuest.OnServerEvent:Connect(function(player, id)
		if limiter:Check(player) and typeof(id) == "string" then
			claimQuest(player, id)
		end
	end)
	Net.RequestClaimDaily.OnServerEvent:Connect(function(player)
		if limiter:Check(player) then
			claimDaily(player)
		end
	end)
	Net.RequestClaimTier.OnServerEvent:Connect(function(player, tier, premium)
		if limiter:Check(player) and typeof(tier) == "number" then
			claimTier(player, tier, premium == true)
		end
	end)
	Net.RequestBuyTidePassPearls.OnServerEvent:Connect(function(player)
		local data = services.DataService.GetData(player)
		if not limiter:Check(player) or not data or data.TidePass.Premium then
			return
		end
		if services.CurrencyService.SpendPearls(player, TP.PremiumPearlCost, "TidePassPremium") then
			QuestService.UnlockPremium(player)
		else
			Net.Notify:FireClient(player, `Need {TP.PremiumPearlCost} Pearls`, "error")
		end
	end)

	-- Onboarding timers: Starter Pack at minute 8 (§15.10), Session10min funnel, day rollover
	task.spawn(function()
		local sessionStart: { [Player]: number } = {}
		while true do
			task.wait(15)
			for _, player in Players:GetPlayers() do
				local data = services.DataService.GetData(player)
				if data then
					sessionStart[player] = sessionStart[player] or os.time()
					local sessionSeconds = os.time() - sessionStart[player]
					if
						data.StarterPackShownAt == 0
						and not data.StarterPackBought
						and data.PlayTime >= Economy.StarterPackMinute * 60
					then
						data.StarterPackShownAt = os.time()
						services.DataService.Replicate(player, "StarterPackShownAt")
						services.UpgradeService.PushDerived(player)
						Net.Offer:FireClient(player, "StarterPack")
					end
					if sessionSeconds >= 600 then
						services.AnalyticsService.Funnel(player, "Session10min")
					end
					ensureQuests(player, data)
					updateLoginStreak(player, data)
				end
			end
			for p in sessionStart do
				if not p.Parent then
					sessionStart[p] = nil
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return QuestService
