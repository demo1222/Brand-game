-- Zone guardians (GuardianService / GuardianController / MonsterArt). Every zone has its own
-- monster, and each one deeper is bigger, faster, hits harder and looks scarier. A guardian
-- lives at a lair: a small cluster of guarded relic nodes that roll with extra luck. It circles
-- the lair, chases divers who come close (never further than Leash from the lair), winds up
-- for a short telegraphed lunge, bites, then backs off. A flare scares guardians away.
--
--   Count       guardians (lairs) in the zone
--   Nodes       guarded relic nodes per lair
--   Luck        luck multiplier on guarded nodes (Epic+ odds, materials)
--   Length      body length in studs (MonsterArt scales the model to it)
--   Patrol/Chase/Lunge   speeds in studs/s
--   Sight       studs at which it notices a diver
--   Leash       studs from the lair it will chase before giving up
--   WindUp      seconds of telegraph before a lunge
--   Damage      fraction of max health per bite
--   Cooldown    seconds after a bite before it can lunge again

local Monsters = {
	List = {
		{
			Id = "ReefShark",
			Zone = 1,
			Name = "Reef Shark",
			Art = "shark",
			Count = 5,
			Nodes = 3,
			Luck = 1.5,
			Length = 9,
			Patrol = 9,
			Chase = 19,
			Lunge = 42,
			Sight = 34,
			Leash = 70,
			WindUp = 0.7,
			Damage = 0.15,
			Cooldown = 2.5,
			Colors = { Body = Color3.fromRGB(110, 140, 165), Belly = Color3.fromRGB(235, 238, 240), Accent = Color3.fromRGB(70, 90, 110), Eye = Color3.fromRGB(20, 20, 24) },
		},
		{
			Id = "Barracuda",
			Zone = 2,
			Name = "Kelp Barracuda",
			Art = "barracuda",
			Count = 5,
			Nodes = 3,
			Luck = 1.6,
			Length = 11,
			Patrol = 11,
			Chase = 25,
			Lunge = 60,
			Sight = 40,
			Leash = 80,
			WindUp = 0.55,
			Damage = 0.2,
			Cooldown = 2.2,
			Colors = { Body = Color3.fromRGB(150, 175, 160), Belly = Color3.fromRGB(220, 230, 215), Accent = Color3.fromRGB(60, 110, 70), Eye = Color3.fromRGB(240, 210, 60) },
		},
		{
			Id = "WreckShark",
			Zone = 3,
			Name = "Wreck Shark",
			Art = "shark",
			Scars = true,
			Count = 4,
			Nodes = 4,
			Luck = 1.8,
			Length = 16,
			Patrol = 11,
			Chase = 24,
			Lunge = 55,
			Sight = 46,
			Leash = 90,
			WindUp = 0.7,
			Damage = 0.3,
			Cooldown = 2.5,
			Colors = { Body = Color3.fromRGB(58, 66, 80), Belly = Color3.fromRGB(190, 190, 185), Accent = Color3.fromRGB(150, 40, 40), Eye = Color3.fromRGB(255, 50, 40), EyeGlow = true },
		},
		{
			Id = "AbyssAngler",
			Zone = 4,
			Name = "Abyss Angler",
			Art = "angler",
			Count = 4,
			Nodes = 4,
			Luck = 2,
			Length = 14,
			Patrol = 7,
			Chase = 20,
			Lunge = 52,
			Sight = 52,
			Leash = 90,
			WindUp = 0.8,
			Damage = 0.4,
			Cooldown = 3,
			Colors = { Body = Color3.fromRGB(34, 30, 46), Belly = Color3.fromRGB(60, 50, 70), Accent = Color3.fromRGB(80, 240, 255), Eye = Color3.fromRGB(220, 240, 255), EyeGlow = true },
		},
		{
			Id = "TrenchSerpent",
			Zone = 5,
			Name = "Magma Serpent",
			Art = "serpent",
			Count = 3,
			Nodes = 5,
			Luck = 2.5,
			Length = 34,
			Patrol = 10,
			Chase = 26,
			Lunge = 62,
			Sight = 60,
			Leash = 110,
			WindUp = 0.9,
			Damage = 0.55,
			Cooldown = 3,
			Colors = { Body = Color3.fromRGB(40, 22, 20), Belly = Color3.fromRGB(70, 34, 26), Accent = Color3.fromRGB(255, 110, 30), Eye = Color3.fromRGB(255, 230, 90), EyeGlow = true },
		},
	},
	ById = {},
	ByZone = {},
	-- Seconds a flare keeps guardians away, and its reach
	FlareSeconds = 6,
	FlareRange = 90,
	-- Guardians only simulate when a diver is this close to their lair
	WakeRange = 260,
}

for _, m in Monsters.List do
	Monsters.ById[m.Id] = m
	Monsters.ByZone[m.Zone] = m
end

return Monsters
