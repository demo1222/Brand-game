-- Recurring events (Master Plan §26.2)
-- Schedules are derived from os.time() so every server agrees on what is active.
-- PeriodSeconds/DurationSeconds: active while (time - Offset) % Period < Duration.
-- Random events use a deterministic seed per period so all servers roll the same result.

return {
	List = {
		{
			Id = "BloodTide",
			Name = "Blood Tide",
			Desc = "Leviathans x2 · Mythic odds x3",
			PeriodSeconds = 2 * 3600,
			DurationSeconds = 5 * 60,
			Offset = 3600,
			Color = Color3.fromRGB(200, 20, 30),
			RarityMult = { Mythic = 3 },
			LeviathanMult = 2,
		},
		{
			Id = "GoldenCurrent",
			Name = "Golden Current",
			Desc = "Gilded mutation x5",
			PeriodSeconds = 3600,
			DurationSeconds = 3 * 60,
			Offset = 30 * 60,
			Color = Color3.fromRGB(255, 200, 40),
			MutationMult = { Gilded = 5 },
		},
		{
			Id = "BioBloom",
			Name = "Bioluminescent Bloom",
			Desc = "Bioluminescent mutation x10",
			PeriodSeconds = 3600,
			DurationSeconds = 10 * 60,
			RandomChance = 0.25, -- 25% of hours, same hours on every server
			Color = Color3.fromRGB(40, 240, 255),
			MutationMult = { Bioluminescent = 10 },
		},
		{
			Id = "StormSurge",
			Name = "Storm Surge",
			Desc = "Wet mutation active · bonus relic spawns",
			Weekends = true,
			Color = Color3.fromRGB(90, 140, 255),
			MutationAdd = { Wet = 3 },
			NodeMult = 1.3,
		},
		{
			Id = "TreasureFleet",
			Name = "Treasure Fleet",
			Desc = "Epic+ odds x2 in the Midnight Wrecks",
			PeriodSeconds = 24 * 3600,
			DurationSeconds = 20 * 60,
			Offset = 20 * 3600, -- 20:00 UTC daily
			Color = Color3.fromRGB(150, 110, 60),
			ZoneRarityMult = { Wrecks = { Epic = 2, Legendary = 2, Mythic = 2 } },
		},
	},
}
