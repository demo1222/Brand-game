-- Economy, social, raid, quest and live-ops tuning values.
-- Every number here is a STARTING value to tune in playtests (Master Plan header note).
-- Values marked [live] can be overridden at runtime via the LiveConfig DataStore key.

return {
	-- §13.2 selling
	SellSeconds = 60, -- sell price = CPS * 60

	-- §8.3 offline earnings handled in Upgrades.Base; VIP/Pass+ bonus hours:
	VipOfflineHours = 2,
	SubOfflineHours = 4,

	-- §12 rebirth
	Rebirth = {
		RequiredSuit = 4, -- Pressure Mk II
		BaseCoins = 5e6,
		Growth = 3,
		CoinMultPerRebirth = 0.5,
		LuckPerRebirth = 0.02,
		LuckCap = 0.30,
		Talents = {
			{ Id = "StartNeoprene", Name = "Head Start", Desc = "Keep the Neoprene suit after resurfacing", Max = 1, Cost = 1 },
			{ Id = "ExtraBag", Name = "Deep Pockets", Desc = "+1 bag slot per level", Max = 3, Cost = 1 },
			{ Id = "QuietDiver", Name = "Quiet Diver", Desc = "Leviathan hears you 10% less per level", Max = 3, Cost = 1 },
			{ Id = "Lungs", Name = "Iron Lungs", Desc = "+10s oxygen per level", Max = 3, Cost = 1 },
		},
	},

	-- §9.2 raid guardrails [live]
	Raid = {
		Enabled = true,
		MinLevel = 5,
		PowerBandMin = 0.33,
		PowerBandMax = 3,
		HoldSeconds = 2.5,
		RaiderCooldown = 45,
		VictimImmunity = 180,
		MaxPerVictimPerHour = 3,
		PlacedProtectSeconds = 30,
		NewPlayerShieldSeconds = 30 * 60,
		JoinLockSeconds = 90,
		CarrySpeedMult = 0.8,
		StealBackRadius = 6,
		RevengeWindow = 60,
		AllowSecretSteal = false,
		PrivateServerSteals = false,
	},

	-- §10 predator / hazards [live]
	Leviathan = {
		MinDepth = 800,
		PlayersPerExtra = 6,
		PatrolSpeed = 18,
		HuntSpeed = 34,
		LungeSpeed = 90,
		SightRange = 60,
		SightConeDeg = 60,
		HearRange = 140,
		WindUp = 1,
		HitDamage = 0.7,
		HitRadius = 9,
		CooldownSeconds = 4,
		FlareSeconds = 6,
	},

	-- §14 social
	Social = {
		FriendBoostPer = 0.10,
		FriendBoostMax = 0.40,
		PartyLuckPer = 0.10,
		PartyMax = 4,
		GroupId = 0, -- set your Roblox group id; 0 disables the group perk
		GroupBonus = 0.05,
		TradeMinLevel = 15,
		TradeCountdown = 5,
	},

	-- §15 multipliers
	VipCoinMult = 1.5,
	SubCoinBonus = 0.10,
	SubLuckBonus = 0.10,
	PremiumCoinBonus = 0.10,
	SubDailyPearls = 60,
	SubscriptionId = "", -- e.g. "EXP-1234567890"; empty disables the subscription check

	-- §17 daily login calendar (7-day streak)
	DailyRewards = {
		{ Coins = 500 },
		{ Pearls = 15 },
		{ Boost = "LuckPotion", Seconds = 600 },
		{ Relic = "Rare" },
		{ Coins = 5000, Pearls = 25 },
		{ Pearls = 50 },
		{ Relic = "Epic" },
	},

	-- §15.5 Tide Pass
	-- Event Tokens (§13 currency table): earned only by salvaging during a live event, spent
	-- in the Event shop. Not sold for Robux, so events stay fair.
	EventTokens = { Base = 1, RarePlus = 2, EpicPlus = 5 },
	EventShop = {
		{ Id = "Flares5", Name = "5 Flares", Icon = "flare", Cost = 25, Reward = { Flares = 5 } },
		{ Id = "Luck5", Name = "Luck Potion · 5 min", Icon = "potion", Cost = 40, Reward = { Boost = "LuckPotion", Seconds = 300 } },
		{ Id = "Mutation5", Name = "Mutation Potion · 5 min", Icon = "potion", Cost = 60, Reward = { Boost = "MutationPotion", Seconds = 300 } },
		{ Id = "Pearls30", Name = "30 Pearls", Icon = "pearl", Cost = 90, Reward = { Pearls = 30 } },
		{ Id = "RareRelic", Name = "Rare relic", Icon = "box", Cost = 120, Reward = { Relic = "Rare" } },
		{ Id = "EpicRelic", Name = "Epic relic", Icon = "star", Cost = 400, Reward = { Relic = "Epic" } },
	},

	TidePass = {
		SeasonId = "S1",
		Tiers = 50,
		XpPerTier = 100,
		PremiumPearlCost = 800,
	},

	-- §11.3 XP
	Xp = {
		Salvage = 5,
		RarityBonus = { Common = 0, Uncommon = 2, Rare = 6, Epic = 15, Legendary = 40, Mythic = 120, Secret = 500 },
		Escape = 10,
		Codex = 20,
		Steal = 25,
	},

	-- Crate contents (§15.3, odds MUST be shown in the UI; §16)
	Crate = {
		{ item = { Kind = "Pearls", Amount = 40 }, weight = 40, label = "40 Pearls" },
		{ item = { Kind = "Boost", Id = "LuckPotion", Seconds = 900 }, weight = 25, label = "Luck Potion (15 min)" },
		{ item = { Kind = "Relic", Rarity = "Rare" }, weight = 20, label = "Random Rare relic" },
		{ item = { Kind = "Relic", Rarity = "Epic" }, weight = 11, label = "Random Epic relic" },
		{ item = { Kind = "Relic", Rarity = "Legendary" }, weight = 3.5, label = "Random Legendary relic" },
		{ item = { Kind = "Relic", Rarity = "Mythic" }, weight = 0.5, label = "Random Mythic relic" },
	},

	-- Codes (§27.1). Rewards are granted once per player.
	Codes = {
		LAUNCH = { Coins = 2500, Pearls = 25 },
		DEEPDIVE = { Boost = "LuckPotion", Seconds = 900 },
		LEVIATHAN = { Pearls = 50 },
	},

	-- Admin whitelist (§23). The place creator is always an admin.
	AdminUserIds = {},

	-- Unprompted offers (§15.10)
	UnpromptedOfferCooldown = 10 * 60,
	StarterPackMinute = 8,

	-- Analytics A/B buckets (§25.4)
	Experiments = {
		StarterPackPrice = { "99", "149" },
	},
}
