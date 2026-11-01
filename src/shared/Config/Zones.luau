-- Depth zones (Master Plan §6, §7.3)
-- Depth is measured in studs below the water surface (WATER_SURFACE_Y in World config).
-- RarityWeights are percentages; every odd shown to players must come from this table.

local Zones = {
	List = {
		{
			Id = "Reef",
			Index = 1,
			Name = "Sunlit Reef",
			MinDepth = 0,
			MaxDepth = 150,
			SuitIndex = 1,
			OxygenDrain = 1,
			FogColor = Color3.fromRGB(70, 200, 210),
			FogEnd = 420,
			Ambient = Color3.fromRGB(140, 200, 210),
			RarityWeights = { Common = 75, Uncommon = 20, Rare = 4.5, Epic = 0.5 },
			NodeCount = 45,
		},
		{
			Id = "Kelp",
			Index = 2,
			Name = "Kelp Twilight",
			MinDepth = 150,
			MaxDepth = 400,
			SuitIndex = 2,
			OxygenDrain = 1.25,
			FogColor = Color3.fromRGB(30, 110, 100),
			FogEnd = 300,
			Ambient = Color3.fromRGB(80, 140, 120),
			RarityWeights = { Common = 55, Uncommon = 30, Rare = 12, Epic = 2.7, Legendary = 0.3 },
			NodeCount = 45,
		},
		{
			Id = "Wrecks",
			Index = 3,
			Name = "Midnight Wrecks",
			MinDepth = 400,
			MaxDepth = 800,
			SuitIndex = 3,
			OxygenDrain = 1.5,
			FogColor = Color3.fromRGB(10, 25, 60),
			FogEnd = 220,
			Ambient = Color3.fromRGB(40, 60, 110),
			RarityWeights = { Common = 35, Uncommon = 33, Rare = 22, Epic = 8.5, Legendary = 1.4, Mythic = 0.1 },
			NodeCount = 40,
		},
		{
			Id = "Abyss",
			Index = 4,
			Name = "The Abyss",
			MinDepth = 800,
			MaxDepth = 1400,
			SuitIndex = 4,
			OxygenDrain = 2,
			FogColor = Color3.fromRGB(5, 8, 20),
			FogEnd = 160,
			Ambient = Color3.fromRGB(20, 25, 50),
			RarityWeights = {
				Common = 15,
				Uncommon = 30,
				Rare = 30,
				Epic = 18,
				Legendary = 6.5,
				Mythic = 0.49,
				Secret = 0.01,
			},
			NodeCount = 35,
		},
		{
			Id = "Trench",
			Index = 5,
			Name = "The Trench",
			MinDepth = 1400,
			MaxDepth = 2200,
			SuitIndex = 5,
			OxygenDrain = 3,
			FogColor = Color3.fromRGB(25, 2, 2),
			FogEnd = 120,
			Ambient = Color3.fromRGB(45, 10, 10),
			RarityWeights = { Uncommon = 20, Rare = 35, Epic = 28, Legendary = 14.5, Mythic = 2.45, Secret = 0.05 },
			NodeCount = 30,
		},
	},
	ById = {},

	-- Pressure damage per second (fraction of MaxHealth) when the suit is too weak (§6 zone access rule)
	PressureDamagePerSec = 0.05,
	-- Pity (§7.3): +0.1 Legendary weight per dry dive in zone 4+, capped at +5
	PityStep = 0.1,
	PityCap = 5,
	PityMinZone = 4,
}

for _, z in Zones.List do
	Zones.ById[z.Id] = z
end

function Zones.ForDepth(depth: number)
	if depth < 0 then
		return nil
	end
	for _, z in Zones.List do
		if depth < z.MaxDepth then
			return z
		end
	end
	return Zones.List[#Zones.List]
end

return Zones
