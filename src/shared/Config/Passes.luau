-- Game passes (Master Plan §15.2, §22.1)
-- Replace id = 0 with real Game Pass IDs from Creator Hub before launch (§32).
-- Passes with id = 0 are skipped when checking ownership; in Studio you can grant them
-- with the admin command `/as pass <Key>`.

return {
	VIP = { id = 0, price = 249, name = "VIP Diver", desc = "1.5x Coins, [VIP] tag, +2h offline cap, daily VIP chest" },
	DoubleOxygen = { id = 0, price = 199, name = "2x Oxygen", desc = "Twice the base tank" },
	Drone = { id = 0, price = 399, name = "Auto-Salvage Drone", desc = "Collects Common & Uncommon relics within 20 studs" },
	LuckySonar = { id = 0, price = 349, name = "Lucky Sonar", desc = "+25% luck" },
	VaultLock = { id = 0, price = 299, name = "Vault Lock", desc = "2 unstealable vault slots + keep 1 relic on death" },
	ExtraSlots = { id = 0, price = 149, name = "+4 Display Slots", desc = "+4 display stands" },
	BigBag = { id = 0, price = 179, name = "Big Bag", desc = "+4 bag slots" },
	InstantSurface = { id = 0, price = 99, name = "Instant Resurface", desc = "Teleport to your dock once per dive" },
	SpeedFins = { id = 0, price = 149, name = "Speed Fins", desc = "+30% swim speed" },
	AutoCollect = { id = 0, price = 129, name = "Auto-Collect", desc = "Dock Coins collect themselves" },
	MutationScan = { id = 0, price = 249, name = "Mutation Scanner", desc = "Sonar shows mutations before you salvage" },
	Radio = { id = 0, price = 99, name = "Radio", desc = "Play approved audio at your dock" },
	-- Bundles grant multiple keys (the grant logic checks bundle OR individual ownership)
	DeepDiverBundle = {
		id = 0,
		price = 499,
		name = "Deep Diver Bundle",
		desc = "VIP + 2x Oxygen + Big Bag (save 20%)",
		grants = { "VIP", "DoubleOxygen", "BigBag" },
	},
	CollectorBundle = {
		id = 0,
		price = 699,
		name = "Collector Bundle",
		desc = "Lucky Sonar + Mutation Scanner + Vault Lock",
		grants = { "LuckySonar", "MutationScan", "VaultLock" },
	},
}
