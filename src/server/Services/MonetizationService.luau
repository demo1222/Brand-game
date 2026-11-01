-- MonetizationService (Master Plan §15, §22): game passes (incl. bundles), developer products
-- with idempotent ProcessReceipt, Abyss Pass+ subscription, Premium perks, Starter Pack timer,
-- policy-gated crates.
--
-- ProcessReceipt rules (§22.2): this is the ONLY script that sets ProcessReceipt; return
-- NotProcessedYet on any failure; never grant a PurchaseId twice; only return PurchaseGranted
-- after the grant is saved (DataService.SaveNow).
--
-- Studio testing: items whose id is still 0 are granted instantly in Studio when "bought",
-- so every handler can be exercised before real IDs exist. In a live server they are refused.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)
local RateLimiter = require(Shared.RateLimiter)
local Passes = require(Shared.Config.Passes)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Config.Economy)
local Formulas = require(Shared.Formulas)
local WeightedRandom = require(Shared.WeightedRandom)

local MonetizationService = {}
MonetizationService.PassGranted = Signal.new() -- (player, key)

local services
local ownedCache: { [Player]: { [string]: boolean } } = {}
local subCache: { [Player]: boolean } = {}
local passIdToKey: { [number]: string } = {}
local productIdToKey: { [number]: string } = {}
local pendingBarnacle: { [Player]: string } = {}
local limiter = RateLimiter.new(4, 0.5)
local rng = Random.new()

for key, p in Passes do
	if p.id ~= 0 then
		passIdToKey[p.id] = key
	end
end
for key, p in Products do
	if p.id ~= 0 then
		productIdToKey[p.id] = key
	end
end

function MonetizationService.Init(s)
	services = s
end

function MonetizationService.Owns(player: Player, key: string): boolean
	local cache = ownedCache[player]
	return cache ~= nil and cache[key] == true
end

function MonetizationService.OwnedSet(player: Player): { [string]: boolean }
	return ownedCache[player] or {}
end

function MonetizationService.HasActiveSubscription(player: Player): boolean
	return subCache[player] == true
end

function MonetizationService.IsPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

function MonetizationService.PushOwnership(player: Player)
	services.DataService.Push(player, {
		Passes = ownedCache[player] or {},
		Subscribed = subCache[player] == true,
		Premium = MonetizationService.IsPremium(player),
	})
end

local function grantPassKey(player: Player, key: string)
	local cache = ownedCache[player]
	if not cache then
		return
	end
	local def = Passes[key]
	if def and def.grants then
		for _, sub in def.grants do
			cache[sub] = true
		end
	end
	cache[key] = true
	MonetizationService.PushOwnership(player)
	MonetizationService.PassGranted:Fire(player, key)
end
MonetizationService.GrantPassKey = grantPassKey -- admin/testing

local function loadOwnership(player: Player)
	ownedCache[player] = ownedCache[player] or {}
	for key, def in Passes do
		if def.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
			if ok and owns then
				grantPassKey(player, key)
			end
		end
	end
	MonetizationService.PushOwnership(player)
end

function MonetizationService.RefreshSubscription(player: Player)
	if Economy.SubscriptionId == "" then
		subCache[player] = false
		return
	end
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, Economy.SubscriptionId)
	end)
	subCache[player] = ok and status ~= nil and status.IsSubscribed == true
	MonetizationService.PushOwnership(player)
end

-- §22.2 luck stack: passes, potions, subscription, rebirth (events applied by LootService)
function MonetizationService.GetLuckMultiplier(player: Player): number
	local data = services.DataService.GetData(player)
	local m = 1
	if MonetizationService.Owns(player, "LuckySonar") then
		m *= 1.25
	end
	if MonetizationService.HasActiveSubscription(player) then
		m *= 1 + Economy.SubLuckBonus
	end
	if services.BoostService.Active(player, "LuckPotion") then
		m *= 2
	end
	if data then
		m *= Formulas.RebirthLuck(data.Rebirths)
	end
	return m
end

-- Multiplier from purchases/membership on Coins income
function MonetizationService.GetCoinMultiplier(player: Player): number
	local m = 1
	if MonetizationService.Owns(player, "VIP") then
		m *= Economy.VipCoinMult
	end
	local bonus = 0
	if MonetizationService.HasActiveSubscription(player) then
		bonus += Economy.SubCoinBonus
	end
	if MonetizationService.IsPremium(player) then
		bonus += Economy.PremiumCoinBonus
	end
	return m * (1 + bonus)
end

------------------------------------------------------------------------------------------
-- Product handlers: return true on success. They must not yield for long.
------------------------------------------------------------------------------------------
local function rollCrate(player: Player)
	local item = WeightedRandom.pick(Economy.Crate, rng)
	if item.Kind == "Pearls" then
		services.CurrencyService.AddPearls(player, item.Amount, "Crate")
	elseif item.Kind == "Boost" then
		services.BoostService.Add(player, item.Id, item.Seconds)
	elseif item.Kind == "Relic" then
		services.InventoryService.GrantRandomRelic(player, item.Rarity, "Crate")
	end
	return item
end

local handlers: { [string]: (Player, any) -> boolean } = {
	OxygenRefill = function(player)
		return services.DiveService.RefillOxygen(player)
	end,
	Revive = function(player)
		return services.DiveService.ReviveInPlace(player)
	end,
	Flares5 = function(player)
		local data = services.DataService.GetData(player)
		data.Flares += Products.Flares5.flares
		services.DataService.Replicate(player, "Flares")
		return true
	end,
	GateRecharge = function(player)
		services.DockService.ResetGateCooldown(player)
		return true
	end,
	ServerLuck = function(player)
		services.EventService.StartServerBoost("Luck", 2, Products.ServerLuck.seconds, player)
		services.AnnouncementService.Server(
			`{player.DisplayName} activated a SERVER LUCK BOOST! 2x luck for 15 minutes!`,
			"Mythic"
		)
		return true
	end,
	LuckPotion = function(player)
		return services.BoostService.Add(player, "LuckPotion", Products.LuckPotion.seconds)
	end,
	MutationPotion = function(player)
		return services.BoostService.Add(player, "MutationPotion", Products.MutationPotion.seconds)
	end,
	StarterPack = function(player)
		local data = services.DataService.GetData(player)
		data.StarterPackBought = true
		services.CurrencyService.AddCoins(player, Products.StarterPack.coins, "StarterPack")
		services.CurrencyService.AddPearls(player, Products.StarterPack.pearls, "StarterPack")
		if data.Suit < 2 then
			data.Suit = 2
			services.DataService.Replicate(player, "Suit")
			services.UpgradeService.PushDerived(player)
			services.UpgradeService.ApplySuitVisual(player)
		end
		services.InventoryService.GrantRandomRelic(player, "Rare", "StarterPack")
		services.DataService.Replicate(player, "StarterPackBought")
		return true
	end,
	SkipPity = function(player)
		return services.LootService.GrantLegendaryRoll(player)
	end,
	BarnacleClean = function(player)
		local uid = pendingBarnacle[player]
		pendingBarnacle[player] = nil
		if uid and services.InventoryService.CleanBarnacle(player, uid) then
			return true
		end
		-- Nothing to clean any more: compensate instead of retrying forever
		return services.CurrencyService.AddPearls(player, 40, "BarnacleRefund")
	end,
	TierSkip = function(player)
		return services.QuestService.AddSeasonXp(player, Economy.TidePass.XpPerTier)
	end,
	TidePassPremium = function(player)
		return services.QuestService.UnlockPremium(player)
	end,
	CrateSingle = function(player)
		local item = rollCrate(player)
		Net.Notify:FireClient(player, "Crate: " .. item.label, "reward")
		return true
	end,
	CrateTriple = function(player)
		local labels = {}
		for _ = 1, 3 do
			table.insert(labels, rollCrate(player).label)
		end
		Net.Notify:FireClient(player, "Crates: " .. table.concat(labels, ", "), "reward")
		return true
	end,
	RenameDock = function(player)
		local data = services.DataService.GetData(player)
		data.RenameTokens += 1
		services.DataService.Replicate(player, "RenameTokens")
		return true
	end,
}

for _, key in { "CoinsS", "CoinsM", "CoinsL", "CoinsXL", "CoinsXXL" } do
	handlers[key] = function(player)
		local def = Products[key]
		return services.CurrencyService.GrantIncomeMinutes(player, def.incomeMinutes, def.floor)
	end
end
for _, key in { "Pearls100", "Pearls550", "Pearls1200", "Pearls2600", "Pearls7000" } do
	handlers[key] = function(player)
		return services.CurrencyService.AddPearls(player, Products[key].pearls, "PearlPack")
	end
end

local function grantProduct(player: Player, key: string, purchaseId: string, robux: number?): boolean
	local profile = services.DataService.Get(player)
	if not profile then
		return false
	end
	if profile.Data.PurchaseHistory[purchaseId] then
		return true -- already handled (idempotent)
	end
	local handler = handlers[key]
	if not handler then
		warn("[Monetization] no handler for product " .. key)
		return false
	end
	local ok, result = pcall(handler, player)
	if not ok or result ~= true then
		warn(`[Monetization] handler {key} failed: {result}`)
		return false
	end
	profile.Data.PurchaseHistory[purchaseId] = os.time()
	profile.Data.ProductCounts[key] = (profile.Data.ProductCounts[key] or 0) + 1
	if not services.DataService.SaveNow(player) then
		-- Grant stays in memory; Roblox retries and the PurchaseId check prevents a double grant.
		return false
	end
	services.AnalyticsService.LogPurchase(player, "product", key, robux)
	return true
end

local function processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = productIdToKey[receiptInfo.ProductId]
	if not key then
		warn("[Monetization] unknown product id", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if grantProduct(player, key, receiptInfo.PurchaseId, receiptInfo.CurrencySpent) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Simulated receipt for Studio / admin testing
function MonetizationService.SimulateProduct(player: Player, key: string): boolean
	return grantProduct(player, key, "SIM-" .. HttpService:GenerateGUID(false), 0)
end

------------------------------------------------------------------------------------------
-- Purchase requests (server owns every prompt, so policy gates can't be bypassed: §22.4)
------------------------------------------------------------------------------------------
function MonetizationService.StarterPackAvailable(player: Player): boolean
	local data = services.DataService.GetData(player)
	if not data or data.StarterPackBought or (data.StarterPackShownAt or 0) == 0 then
		return false
	end
	return os.time() - data.StarterPackShownAt < Products.StarterPack.offerHours * 3600
end

function MonetizationService.SetPendingBarnacle(player: Player, uid: string)
	pendingBarnacle[player] = uid
end

local function promptPass(player: Player, key: string)
	local def = Passes[key]
	if not def or MonetizationService.Owns(player, key) then
		return
	end
	services.AnalyticsService.Custom(player, "PromptShown", def.price, { CustomField01 = key })
	if def.id == 0 then
		if RunService:IsStudio() then
			grantPassKey(player, key)
			Net.Notify:FireClient(player, `[Studio] Granted pass {def.name}`, "info")
		else
			Net.Notify:FireClient(player, "This item isn't on sale yet.", "error")
		end
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, def.id)
end

local function promptProduct(player: Player, key: string)
	local def = Products[key]
	if not def then
		return
	end
	if def.paidRandom and not services.PolicyWrapper.CanBuyRandomItems(player) then
		Net.Notify:FireClient(player, "Mystery Crates aren't available in your region.", "error")
		return
	end
	if key == "StarterPack" and not MonetizationService.StarterPackAvailable(player) then
		return
	end
	if key == "Revive" and not services.DiveService.CanRevive(player) then
		return
	end
	if key == "TidePassPremium" then
		local data = services.DataService.GetData(player)
		if data and data.TidePass.Premium then
			return
		end
	end
	services.AnalyticsService.Custom(player, "PromptShown", def.price, { CustomField01 = key })
	if def.id == 0 then
		if RunService:IsStudio() then
			local ok = MonetizationService.SimulateProduct(player, key)
			Net.Notify:FireClient(player, `[Studio] Simulated {def.name}: {ok and "granted" or "failed"}`, "info")
		else
			Net.Notify:FireClient(player, "This item isn't on sale yet.", "error")
		end
		return
	end
	MarketplaceService:PromptProductPurchase(player, def.id)
end

local function onRequestPurchase(player: Player, kind: any, key: any)
	if not limiter:Check(player) then
		return
	end
	if typeof(kind) ~= "string" or typeof(key) ~= "string" then
		return
	end
	if kind == "Pass" then
		promptPass(player, key)
	elseif kind == "Product" then
		promptProduct(player, key)
	elseif kind == "Subscription" then
		if Economy.SubscriptionId ~= "" then
			pcall(function()
				MarketplaceService:PromptSubscriptionPurchase(player, Economy.SubscriptionId)
			end)
		elseif RunService:IsStudio() then
			subCache[player] = not subCache[player]
			MonetizationService.PushOwnership(player)
			Net.Notify:FireClient(player, `[Studio] Pass+ {subCache[player] and "ON" or "OFF"}`, "info")
		end
	elseif kind == "Premium" then
		pcall(function()
			MarketplaceService:PromptPremiumPurchase(player)
		end)
	end
end

------------------------------------------------------------------------------------------
-- Daily perks (§15.1 VIP chest, §15.4 Pass+ pearls, §15.7 Premium chest)
------------------------------------------------------------------------------------------
local function today(): number
	return os.time() // 86400
end

function MonetizationService.GrantDailyPerks(player: Player)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	local d = today()
	if MonetizationService.Owns(player, "VIP") and data.LastVipChestDay ~= d then
		data.LastVipChestDay = d
		services.CurrencyService.AddPearls(player, 20, "VipChest")
		services.CurrencyService.GrantIncomeMinutes(player, 10, 1000)
		Net.Notify:FireClient(player, "VIP Chest: +20 Pearls and 10 minutes of income!", "reward")
	end
	if MonetizationService.HasActiveSubscription(player) and data.LastSubPearlsDay ~= d then
		data.LastSubPearlsDay = d
		services.CurrencyService.AddPearls(player, Economy.SubDailyPearls, "SubDaily")
		Net.Notify:FireClient(player, `Abyss Pass+: +{Economy.SubDailyPearls} Pearls`, "reward")
	end
	if MonetizationService.IsPremium(player) and os.time() - data.LastPremiumChest >= 86400 then
		data.LastPremiumChest = os.time()
		services.CurrencyService.AddPearls(player, 15, "PremiumChest")
		services.BoostService.Add(player, "LuckPotion", 300)
		Net.Notify:FireClient(player, "Premium Chest: +15 Pearls and a 5-minute Luck Potion!", "reward")
	end
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	services.DataService.ProfileLoaded:Connect(function(player)
		loadOwnership(player)
		MonetizationService.RefreshSubscription(player)
		MonetizationService.GrantDailyPerks(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		ownedCache[p] = nil
		subCache[p] = nil
		pendingBarnacle[p] = nil
		limiter:Remove(p)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passIdToKey[passId]
		if purchased and key then
			grantPassKey(player, key)
			services.AnalyticsService.LogPurchase(player, "pass", key, Passes[key].price)
			Net.Notify:FireClient(player, `Thanks! {Passes[key].name} unlocked.`, "reward")
		end
	end)

	pcall(function()
		Players.UserSubscriptionStatusChanged:Connect(function(player, subscriptionId)
			if subscriptionId == Economy.SubscriptionId then
				MonetizationService.RefreshSubscription(player)
			end
		end)
	end)
	Players.PlayerMembershipChanged:Connect(function(player)
		MonetizationService.PushOwnership(player)
	end)

	Net.RequestPurchase.OnServerEvent:Connect(onRequestPurchase)
	Net.OfferShown.OnServerEvent:Connect(function(player, key)
		if typeof(key) == "string" and limiter:Check(player) then
			services.AnalyticsService.Custom(player, "OfferShown", 1, { CustomField01 = key })
		end
	end)

	-- Hourly re-check for players who stay past midnight UTC
	task.spawn(function()
		while true do
			task.wait(600)
			for _, p in Players:GetPlayers() do
				MonetizationService.GrantDailyPerks(p)
			end
		end
	end)
end

return MonetizationService
