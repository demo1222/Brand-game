-- Upgrade tracks and suits (Master Plan §11)
-- Cost(L) = Base * Growth^L where L is the CURRENT level (cost of going L -> L+1).

local Upgrades = {
	Tracks = {
		{ Id = "Oxygen", Name = "Oxygen Tank", Max = 25, Base = 50, Growth = 1.45, Desc = "+6s dive time" },
		{ Id = "Fins", Name = "Fins", Max = 20, Base = 40, Growth = 1.42, Desc = "+4% swim speed" },
		{ Id = "Bag", Name = "Bag Size", Max = 10, Base = 200, Growth = 1.8, Desc = "+1 bag slot" },
		{ Id = "Sonar", Name = "Sonar", Max = 15, Base = 150, Growth = 1.5, Desc = "+range; rarity at L5, mutations at L10" },
		{ Id = "Salvage", Name = "Salvage Speed", Max = 10, Base = 100, Growth = 1.5, Desc = "-8% hold time" },
		{ Id = "Display", Name = "Display Slots", Max = 24, Base = 500, Growth = 1.35, Desc = "+1 stand" },
		{ Id = "Offline", Name = "Offline Earnings", Max = 10, Base = 1000, Growth = 1.6, Desc = "+2.5% rate, +48 min cap" },
		{ Id = "Gate", Name = "Laser Gate", Max = 5, Base = 2000, Growth = 2, Desc = "Unlock / +10s gate duration" },
		{ Id = "Crab", Name = "Guard Crab", Max = 5, Base = 2000, Growth = 2, Desc = "Slows intruders (6% per level)" },
		{ Id = "Alarm", Name = "Alarm Range", Max = 5, Base = 2000, Growth = 2, Desc = "+10 studs alert range" },
		{ Id = "Board", Name = "Diving Board", Max = 10, Base = 300, Growth = 1.7, Desc = "+15m launch depth off your dock's board" },
	},
	ById = {},

	Suits = {
		{ Id = "Basic", Name = "Basic Wetsuit", Cost = 0, Color = Color3.fromRGB(240, 200, 40) },
		{ Id = "Neoprene", Name = "Neoprene", Cost = 2500, Color = Color3.fromRGB(40, 90, 220) },
		{ Id = "PressureMk1", Name = "Pressure Mk I", Cost = 60000, Color = Color3.fromRGB(190, 140, 60) },
		{ Id = "PressureMk2", Name = "Pressure Mk II", Cost = 1.2e6, Color = Color3.fromRGB(150, 160, 175) },
		{ Id = "AbyssalRig", Name = "Abyssal Rig", Cost = 25e6, Color = Color3.fromRGB(20, 20, 25) },
		{ Id = "Titan", Name = "Titan Suit", Cost = 600e6, Color = Color3.fromRGB(255, 200, 40), ComingSoon = true },
	},
	SuitIndex = {},

	-- Base stats before upgrades/passes
	Base = {
		OxygenSeconds = 60,
		OxygenPerLevel = 6,
		SwimSpeed = 24,
		FinsPerLevel = 0.04,
		BoostMult = 1.6,
		BagSize = 3,
		Stands = 6,
		SalvageSeconds = 1.6,
		SalvagePerLevel = 0.08,
		SonarRange = 80,
		SonarPerLevel = 12,
		SonarCooldown = 6,
		OfflineRate = 0.25,
		OfflineRatePerLevel = 0.025,
		OfflineCapHours = 4,
		OfflineCapPerLevelHours = 0.8,
		GateSeconds = 60,
		BoardDepth = 20, -- metres a jump off the diving board plunges you to
		BoardDepthPerLevel = 15,
		GateCooldown = 300,
	},
}

for _, t in Upgrades.Tracks do
	Upgrades.ById[t.Id] = t
end
for i, s in Upgrades.Suits do
	Upgrades.SuitIndex[s.Id] = i
end

function Upgrades.Cost(trackId: string, level: number): number
	local t = Upgrades.ById[trackId]
	if not t then
		return math.huge
	end
	return math.floor(t.Base * t.Growth ^ level)
end

return Upgrades
