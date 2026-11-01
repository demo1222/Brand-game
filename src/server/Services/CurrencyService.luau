-- CurrencyService (Master Plan §13.1): the single source of truth for Coins and Pearls.
-- Every add/spend goes through here so analytics and leaderstats stay consistent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local CurrencyService = {}
local services

function CurrencyService.Init(s)
	services = s
end

local function refreshLeaderstats(player: Player, data)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local coins = ls:FindFirstChild("Coins")
	if coins then
		coins.Value = NumberFormat.short(data.Coins)
	end
	local rebirths = ls:FindFirstChild("Resurfaces")
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	local deepest = ls:FindFirstChild("Deepest")
	if deepest then
		deepest.Value = math.floor(data.Stats.DeepestDepth)
	end
end
CurrencyService.RefreshLeaderstats = refreshLeaderstats

function CurrencyService.AddCoins(player: Player, amount: number, source: string): boolean
	local data = services.DataService.GetData(player)
	if not data or amount ~= amount or amount <= 0 or amount == math.huge then
		return false
	end
	amount = math.floor(amount)
	data.Coins += amount
	data.LifetimeCoins += amount
	services.AnalyticsService.Economy(player, true, "Coins", amount, data.Coins, source, source)
	services.DataService.Replicate(player, "Coins", "LifetimeCoins")
	refreshLeaderstats(player, data)
	return true
end

function CurrencyService.SpendCoins(player: Player, amount: number, sink: string): boolean
	local data = services.DataService.GetData(player)
	if not data or amount ~= amount or amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	services.AnalyticsService.Economy(player, false, "Coins", amount, data.Coins, sink, sink)
	services.DataService.Replicate(player, "Coins")
	refreshLeaderstats(player, data)
	return true
end

function CurrencyService.AddPearls(player: Player, amount: number, source: string): boolean
	local data = services.DataService.GetData(player)
	if not data or amount ~= amount or amount <= 0 then
		return false
	end
	amount = math.floor(amount)
	data.Pearls += amount
	services.AnalyticsService.Economy(player, true, "Pearls", amount, data.Pearls, source, source)
	services.DataService.Replicate(player, "Pearls")
	return true
end

function CurrencyService.SpendPearls(player: Player, amount: number, sink: string): boolean
	local data = services.DataService.GetData(player)
	if not data or amount ~= amount or amount < 0 or data.Pearls < amount then
		return false
	end
	data.Pearls -= amount
	services.AnalyticsService.Economy(player, false, "Pearls", amount, data.Pearls, sink, sink)
	services.DataService.Replicate(player, "Pearls")
	return true
end

-- §15.3 Coin packs scale with the player's current income ("X minutes of your income").
function CurrencyService.GrantIncomeMinutes(player: Player, minutes: number, floor: number?): boolean
	local cps = services.DockService.GetIncomePerSecond(player)
	local amount = math.max(cps * minutes * 60, floor or 0)
	return CurrencyService.AddCoins(player, amount, "CoinPack")
end

-- Generic reward table: {Coins, Pearls, Boost, Seconds, Relic (rarity), Flares, TidePassXp}
function CurrencyService.GrantReward(player: Player, reward, source: string): { string }
	local lines = {}
	if reward.Coins then
		CurrencyService.AddCoins(player, reward.Coins, source)
		table.insert(lines, `+{NumberFormat.short(reward.Coins)} Coins`)
	end
	if reward.Pearls then
		CurrencyService.AddPearls(player, reward.Pearls, source)
		table.insert(lines, `+{reward.Pearls} Pearls`)
	end
	if reward.Boost then
		services.BoostService.Add(player, reward.Boost, reward.Seconds or 600)
		table.insert(lines, `{reward.Boost} ({NumberFormat.time(reward.Seconds or 600)})`)
	end
	if reward.Flares then
		local data = services.DataService.GetData(player)
		if data then
			data.Flares += reward.Flares
			services.DataService.Replicate(player, "Flares")
			table.insert(lines, `+{reward.Flares} Flares`)
		end
	end
	if reward.Relic then
		local relic = services.InventoryService.GrantRandomRelic(player, reward.Relic, source)
		if relic then
			table.insert(lines, `{reward.Relic} relic!`)
		end
	end
	if reward.TidePassXp then
		services.QuestService.AddSeasonXp(player, reward.TidePassXp)
	end
	return lines
end

function CurrencyService.Start()
	services.DataService.ProfileLoaded:Connect(function(player, profile)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local coins = Instance.new("StringValue")
		coins.Name = "Coins"
		coins.Parent = ls
		local deepest = Instance.new("IntValue")
		deepest.Name = "Deepest"
		deepest.Parent = ls
		local rebirths = Instance.new("IntValue")
		rebirths.Name = "Resurfaces"
		rebirths.Parent = ls
		ls.Parent = player
		refreshLeaderstats(player, profile.Data)
	end)
end

return CurrencyService
