-- Developer products (Master Plan §15.3, §22.1)
-- Replace id = 0 with real Developer Product IDs. Products with id = 0 can still be
-- exercised in Studio through the admin command `/as product <Key>` (simulated receipt).

return {
	OxygenRefill = { id = 0, price = 25, name = "Oxygen Refill" },
	Revive = { id = 0, price = 35, name = "Revive in Place" },
	Flares5 = { id = 0, price = 19, name = "Flare x5", flares = 5 },
	GateRecharge = { id = 0, price = 29, name = "Laser Gate Recharge" },
	ServerLuck = { id = 0, price = 199, name = "Server Luck Boost (15 min)", seconds = 15 * 60 },
	LuckPotion = { id = 0, price = 49, name = "Luck Potion (10 min)", seconds = 10 * 60 },
	MutationPotion = { id = 0, price = 79, name = "Mutation Potion (10 min)", seconds = 10 * 60 },
	CoinsS = { id = 0, price = 49, name = "Coins S", incomeMinutes = 20, floor = 2500 },
	CoinsM = { id = 0, price = 149, name = "Coins M", incomeMinutes = 90, floor = 10000 },
	CoinsL = { id = 0, price = 399, name = "Coins L", incomeMinutes = 300, floor = 40000 },
	CoinsXL = { id = 0, price = 999, name = "Coins XL", incomeMinutes = 900, floor = 150000 },
	CoinsXXL = { id = 0, price = 1999, name = "Coins XXL", incomeMinutes = 2160, floor = 400000 },
	Pearls100 = { id = 0, price = 49, name = "100 Pearls", pearls = 100 },
	Pearls550 = { id = 0, price = 249, name = "550 Pearls", pearls = 550 },
	Pearls1200 = { id = 0, price = 499, name = "1,200 Pearls", pearls = 1200 },
	Pearls2600 = { id = 0, price = 999, name = "2,600 Pearls", pearls = 2600 },
	Pearls7000 = { id = 0, price = 2499, name = "7,000 Pearls", pearls = 7000 },
	StarterPack = { id = 0, price = 99, name = "Starter Pack", coins = 10000, pearls = 100, offerHours = 48 },
	SkipPity = { id = 0, price = 149, name = "Skip Pity (Legendary roll)" },
	BarnacleClean = { id = 0, price = 39, name = "Barnacle Clean" },
	TierSkip = { id = 0, price = 49, name = "Tide Pass Tier Skip" },
	TidePassPremium = { id = 0, price = 499, name = "Tide Pass Premium" },
	CrateSingle = { id = 0, price = 99, name = "Mystery Crate", paidRandom = true, rolls = 1 },
	CrateTriple = { id = 0, price = 299, name = "Mystery Crate x3", paidRandom = true, rolls = 3 },
	RenameDock = { id = 0, price = 25, name = "Rename Dock" },
}
