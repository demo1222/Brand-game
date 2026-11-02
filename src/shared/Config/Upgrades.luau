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
		{ Id = "Board", Name = "Diving Board", Max = 10, Base = 300, Growth = 1.7, Desc = "Higher jump, +15m plunge off your dock's board" },
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

	-- Diving board jump (SwimController). Every Board level adds to the jump, and the plunge
	-- depth still comes from Base.BoardDepth (+BoardDepthPerLevel).
	--   Launch:  upward speed off the board, in studs/s. Height gained = Launch^2 / (2 * Gravity).
	--   Out:     horizontal speed out to sea, in studs/s. Out-distance = Out x time in the air.
	--   Gravity: studs/s^2 during the arc.
	-- Level 0 is the original jump: Launch 34, Out 20. Level 10 is Launch 64 and Out 50.
	-- The skin steps every SkinEvery levels through Skins (level 0-1 Plank, 2-3 Varnish,
	-- 4-5 Brass, 6-7 Copper, 8-9 Gold, 10 Pearl).
	Dive = {
		Gravity = 85,
		Launch = 34,
		LaunchPerLevel = 3,
		Out = 20,
		OutPerLevel = 3,
		SkinEvery = 2,
		Skins = {
			{ Name = "Plank", Color = Color3.fromRGB(120, 92, 64), Material = "WoodPlanks" },
			{ Name = "Varnish", Color = Color3.fromRGB(165, 118, 70), Material = "WoodPlanks" },
			{ Name = "Brass", Color = Color3.fromRGB(200, 150, 80), Material = "Metal" },
			{ Name = "Copper", Color = Color3.fromRGB(205, 128, 84), Material = "Metal" },
			{ Name = "Gold", Color = Color3.fromRGB(245, 192, 74), Material = "Metal" },
			{ Name = "Pearl", Color = Color3.fromRGB(236, 238, 246), Material = "Marble" },
		},
	},

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
