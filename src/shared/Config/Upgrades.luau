-- Upgrade tracks and suits (Master Plan §11)
-- Cost(L) = Base * Growth^L where L is the CURRENT level (cost of going L -> L+1).

-- Economy scheme: docs/ECONOMY.md (income sources, sinks, pacing targets per zone).
local Upgrades = {
	-- Steep on purpose: each level should feel earned. Cheap early levels, then each one costs
	-- Growth times the last, so the late levels need the next zone's income.
	Tracks = {
		{ Id = "Oxygen", Name = "Oxygen Tank", Max = 25, Base = 100, Growth = 1.65, Desc = "+6s dive time" },
		{ Id = "Fins", Name = "Fins", Max = 20, Base = 80, Growth = 1.75, Desc = "+4% swim speed" },
		{ Id = "Bag", Name = "Bag Size", Max = 10, Base = 500, Growth = 2.3, Desc = "+1 bag slot" },
		{ Id = "Sonar", Name = "Sonar", Max = 15, Base = 300, Growth = 1.8, Desc = "+range; rarity at L5, mutations at L10" },
		{ Id = "Salvage", Name = "Salvage Speed", Max = 10, Base = 250, Growth = 2.0, Desc = "-8% hold time" },
		{ Id = "Display", Name = "Display Slots", Max = 24, Base = 750, Growth = 1.62, Desc = "+1 stand" },
		{ Id = "Offline", Name = "Offline Earnings", Max = 10, Base = 2500, Growth = 2.0, Desc = "+2.5% rate, +48 min cap" },
		{ Id = "Gate", Name = "Laser Gate", Max = 5, Base = 5000, Growth = 2.6, Desc = "Unlock / +10s gate duration" },
		{ Id = "Crab", Name = "Guard Crab", Max = 5, Base = 5000, Growth = 2.6, Desc = "Slows intruders (6% per level)" },
		{ Id = "Alarm", Name = "Alarm Range", Max = 5, Base = 5000, Growth = 2.6, Desc = "+10 studs alert range" },
		{ Id = "Board", Name = "Diving Board", Max = 10, Base = 600, Growth = 1.9, Desc = "Higher jump, +15m plunge off your dock's board" },
	},
	ById = {},

	-- Suits (Suit Shop). Bought in order; the newest one you own sets how deep you can dive
	-- safely (Zone = the deepest Zones.List index without pressure damage) and its perks:
	--   Air    = +max oxygen     Swim   = +swim speed
	--   Luck   = x(1 + Luck) on Epic-and-up weights     Income = x(1 + Income) on all coins
	-- (fractions). Three suits per zone (Titan waits for the next zone), each a real jump: the
	-- last suit of a zone roughly doubles the first one's income perk. Cost is ~5-20 minutes
	-- of that zone's income (docs/ECONOMY.md). Any owned suit can be worn (data.SuitLook), but
	-- perks and depth always come from the newest one. Tier is the shop card's rarity word.
	Suits = {
		{ Id = "Basic", Name = "Basic Wetsuit", Tier = "Common", Zone = 1, Cost = 0, Air = 0, Swim = 0, Luck = 0, Income = 0, Desc = "Mask, snorkel and short fins.", Color = Color3.fromRGB(240, 200, 40) },
		{ Id = "Snorkeler", Name = "Snorkeler", Tier = "Common", Zone = 1, Cost = 1500, Air = 0.1, Swim = 0.05, Luck = 0, Income = 0.05, Desc = "A bright snorkel set and a spare mask.", Color = Color3.fromRGB(80, 200, 255) },
		{ Id = "ReefRunner", Name = "Reef Runner", Tier = "Common", Zone = 1, Cost = 6000, Air = 0.15, Swim = 0.15, Luck = 0.05, Income = 0.1, Desc = "Coral tank and quick fins for the reef.", Color = Color3.fromRGB(255, 120, 90) },
		{ Id = "Neoprene", Name = "Neoprene", Tier = "Uncommon", Zone = 2, Cost = 25e3, Air = 0.3, Swim = 0.2, Luck = 0.1, Income = 0.25, Desc = "Single tank, long fins and a dive computer.", Color = Color3.fromRGB(40, 90, 220) },
		{ Id = "KelpStalker", Name = "Kelp Stalker", Tier = "Uncommon", Zone = 2, Cost = 100e3, Air = 0.4, Swim = 0.3, Luck = 0.15, Income = 0.4, Desc = "Kelp camo with a fin crest. Slips through the forest.", Color = Color3.fromRGB(90, 200, 90) },
		{ Id = "Tidecaller", Name = "Tidecaller", Tier = "Uncommon", Zone = 2, Cost = 400e3, Air = 0.55, Swim = 0.35, Luck = 0.25, Income = 0.6, Desc = "Sea-glass trim and a twin-jet harness.", Color = Color3.fromRGB(60, 220, 230) },
		{ Id = "PressureMk1", Name = "Pressure Mk I", Tier = "Rare", Zone = 3, Cost = 1.5e6, Air = 0.75, Swim = 0.4, Luck = 0.35, Income = 1, Desc = "Brass helmet, twin tanks and a chest plate.", Color = Color3.fromRGB(190, 140, 60) },
		{ Id = "WreckDiver", Name = "Wreck Diver", Tier = "Rare", Zone = 3, Cost = 6e6, Air = 0.9, Swim = 0.45, Luck = 0.45, Income = 1.5, Desc = "Rusty copper dome with head lamps for the wrecks.", Color = Color3.fromRGB(215, 95, 50) },
		{ Id = "SalvageMaster", Name = "Salvage Master", Tier = "Rare", Zone = 3, Cost = 20e6, Air = 1.1, Swim = 0.5, Luck = 0.6, Income = 2.2, Desc = "Hazard-stripe armour and a salvage winch rig.", Color = Color3.fromRGB(255, 170, 30) },
		{ Id = "PressureMk2", Name = "Pressure Mk II", Tier = "Epic", Zone = 4, Cost = 60e6, Air = 1.3, Swim = 0.55, Luck = 0.75, Income = 3, Desc = "Steel helmet, armour and weighted boots.", Color = Color3.fromRGB(150, 160, 175) },
		{ Id = "LanternRig", Name = "Lantern Rig", Tier = "Epic", Zone = 4, Cost = 180e6, Air = 1.5, Swim = 0.6, Luck = 0.9, Income = 4, Desc = "Glowing rebreather rig that lights the dark.", Color = Color3.fromRGB(60, 230, 200) },
		{ Id = "Anglerlight", Name = "Anglerlight", Tier = "Epic", Zone = 4, Cost = 550e6, Air = 1.75, Swim = 0.65, Luck = 1.1, Income = 5.5, Desc = "Deep-sea armour with a lure lamp and jets.", Color = Color3.fromRGB(255, 220, 90) },
		{ Id = "AbyssalRig", Name = "Abyssal Rig", Tier = "Legendary", Zone = 5, Cost = 2e9, Air = 2, Swim = 0.7, Luck = 1.3, Income = 7.5, Desc = "Armoured rig with a glowing visor and headlamps.", Color = Color3.fromRGB(20, 20, 25) },
		{ Id = "LeviathanHide", Name = "Leviathan Hide", Tier = "Legendary", Zone = 5, Cost = 8e9, Air = 2.4, Swim = 0.8, Luck = 1.6, Income = 10, Desc = "Spiked violet armour with thrusters and a crest.", Color = Color3.fromRGB(170, 90, 255) },
		{ Id = "CoralEmperor", Name = "Coral Emperor", Tier = "Mythic", Zone = 5, Cost = 30e9, Air = 2.8, Swim = 0.9, Luck = 2, Income = 14, Desc = "Gold armour for the ruler of the reef. Pink glow, thrusters.", Color = Color3.fromRGB(255, 110, 170) },
		{ Id = "Titan", Name = "Titan Suit", Tier = "Mythic", Zone = 5, Cost = 120e9, Air = 3.5, Swim = 1, Luck = 2.5, Income = 20, Desc = "Gold heavy suit for the Sunken Throne. Coming soon.", Color = Color3.fromRGB(255, 200, 40), ComingSoon = true },
	},
	SuitIndex = {},
	-- Old save index (12-suit list, data v3) -> index in this 16-suit list (DataService v4)
	SuitRemapV4 = { 1, 3, 4, 5, 7, 8, 10, 11, 13, 14, 15, 16 },

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

-- The suit at a data.Suit index (clamped, so old or bad saves still resolve)
function Upgrades.Suit(index: number?)
	return Upgrades.Suits[math.clamp(math.floor(index or 1), 1, #Upgrades.Suits)]
end

-- Deepest zone a suit index dives safely
function Upgrades.SuitZone(index: number?): number
	return Upgrades.Suit(index).Zone
end

-- First suit index that is safe in a zone (tutorial hints, rebirth checks)
function Upgrades.FirstSuitFor(zone: number): number
	for i, s in Upgrades.Suits do
		if s.Zone >= zone then
			return i
		end
	end
	return #Upgrades.Suits
end

function Upgrades.Cost(trackId: string, level: number): number
	local t = Upgrades.ById[trackId]
	if not t then
		return math.huge
	end
	return math.floor(t.Base * t.Growth ^ level)
end

return Upgrades
