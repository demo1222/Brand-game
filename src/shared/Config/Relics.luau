-- Relic catalogue (Master Plan §7.2, Appendix A). 60 relics at launch.
-- Columns: id, name, zone, rarity, baseCPS, shape, lore, special
-- `shape` drives the graybox model built at runtime (Ball, Block, Cylinder, Wedge).

local ROWS = {
	-- Zone 1 · Sunlit Reef
	{ "R001", "Rusty Anchor", 1, "Common", 2, "Wedge", "An anchor from a forgotten fishing boat.", "Tutorial" },
	{ "R002", "Glass Bottle Message", 1, "Common", 3, "Cylinder", "The ink has run, but one word remains: DEEPER." },
	{ "R003", "Cracked Snorkel", 1, "Common", 1, "Cylinder", "Someone surfaced in a hurry." },
	{ "R004", "Sea Glass Shard", 1, "Common", 4, "Block", "Polished smooth by a hundred tides." },
	{ "R005", "Lost Flip-Flop", 1, "Common", 1, "Block", "Just the left one. Always the left one." },
	{ "R006", "Starfish Fossil", 1, "Common", 5, "Ball", "Older than the reef itself." },
	{ "R007", "Tin Toy Boat", 1, "Uncommon", 8, "Wedge", "It still floats, stubbornly." },
	{ "R008", "Coral Crown", 1, "Uncommon", 10, "Cylinder", "Fit for a very small king." },
	{ "R009", "Sunken Bell", 1, "Uncommon", 15, "Ball", "It rings when no one touches it." },
	{ "R010", "Pearl Clam", 1, "Uncommon", 12, "Ball", "Something inside is glowing." },
	{ "R011", "Scuba Mask '78", 1, "Rare", 40, "Block", "Signed by a famous diver." },
	{ "R012", "Mermaid Comb", 1, "Rare", 60, "Wedge", "Carved from a single whale tooth." },
	{ "R013", "Reef Idol", 1, "Epic", 220, "Block", "The fish swim around it in circles." },
	-- Zone 2 · Kelp Twilight
	{ "R014", "Kelp Lantern", 2, "Common", 3, "Cylinder", "Burns with green fire." },
	{ "R015", "Fishbone Key", 2, "Common", 4, "Wedge", "Opens something, somewhere." },
	{ "R016", "Barnacle Boot", 2, "Common", 2, "Block", "Home to three crabs." },
	{ "R017", "Seaweed Scroll", 2, "Uncommon", 14, "Cylinder", "A map written in kelp." },
	{ "R018", "Copper Diving Helmet", 2, "Uncommon", 18, "Ball", "Dented, but proud." },
	{ "R019", "Eelskin Pouch", 2, "Uncommon", 20, "Ball", "It crackles faintly." },
	{ "R020", "Silver Spoon Set", 2, "Rare", 45, "Block", "From the captain's table." },
	{ "R021", "Pirate Doubloon", 2, "Rare", 55, "Cylinder", "Stamped with a skull and a wave.", "FTUE" },
	{ "R022", "Jade Turtle", 2, "Rare", 80, "Ball", "Said to bring long life." },
	{ "R023", "Siren's Mirror", 2, "Epic", 260, "Cylinder", "Don't look too long." },
	{ "R024", "Kelp Monarch Statue", 2, "Epic", 380, "Block", "The forest's forgotten ruler." },
	{ "R025", "Golden Kelp Harp", 2, "Legendary", 1600, "Wedge", "Plays itself in the current." },
	-- Zone 3 · Midnight Wrecks
	{ "R026", "Ship's Wheel", 3, "Common", 5, "Cylinder", "Still turns to port." },
	{ "R027", "Cannonball", 3, "Common", 4, "Ball", "Heavier than it looks." },
	{ "R028", "Porthole Glass", 3, "Uncommon", 16, "Cylinder", "Something stares back." },
	{ "R029", "Rum Barrel", 3, "Uncommon", 19, "Cylinder", "Empty. Suspiciously empty." },
	{ "R030", "Brass Spyglass", 3, "Rare", 65, "Cylinder", "Shows a ship that isn't there." },
	{ "R031", "Ghost Lantern", 3, "Rare", 85, "Block", "The flame is cold." },
	{ "R032", "Treasure Chest", 3, "Rare", 90, "Block", "Finally, a classic." },
	{ "R033", "Admiral's Medal", 3, "Epic", 280, "Cylinder", "For bravery beneath the waves." },
	{ "R034", "Captain's Compass", 3, "Epic", 320, "Cylinder", "Points to a nearby rare.", "PointsToRare" },
	{ "R035", "Kraken Ink Map", 3, "Epic", 450, "Block", "Drawn in something darker than ink." },
	{ "R036", "Wreck Figurehead", 3, "Legendary", 2200, "Wedge", "She guided a thousand voyages." },
	{ "R037", "Cursed Cutlass", 3, "Legendary", 3000, "Wedge", "It hums near the Leviathan." },
	{ "R038", "Sunken Galleon Bell", 3, "Mythic", 22000, "Ball", "Its toll was heard on the surface." },
	-- Zone 4 · The Abyss
	{ "R039", "Glowing Pebble", 4, "Common", 5, "Ball", "Pretty. Useless. Pretty." },
	{ "R040", "Anglerfish Lure", 4, "Uncommon", 20, "Ball", "The lure. Hopefully without the fish." },
	{ "R041", "Lantern of the Deep", 4, "Legendary", 2800, "Cylinder", "Lights the area while displayed.", "Light" },
	{ "R042", "Abyssal Pearl", 4, "Rare", 88, "Ball", "Black as the water around it." },
	{ "R043", "Gulper Skull", 4, "Rare", 70, "Block", "Mostly mouth." },
	{ "R044", "Bioluminescent Orb", 4, "Epic", 400, "Ball", "Pulses like a heartbeat." },
	{ "R045", "Deep One Totem", 4, "Epic", 500, "Block", "Who carved this, down here?" },
	{ "R046", "Vampire Squid Cloak", 4, "Epic", 350, "Wedge", "Soft, dark and unsettling." },
	{ "R047", "Obsidian Mask", 4, "Legendary", 3500, "Block", "Warm to the touch." },
	{ "R048", "Leviathan Scale", 4, "Legendary", 4000, "Wedge", "Each one is the size of a shield." },
	{ "R049", "Starlight Coral", 4, "Mythic", 30000, "Cylinder", "Stars fell into the sea, once." },
	{ "R050", "Abyss Eye", 4, "Mythic", 40000, "Ball", "It blinks." },
	{ "R051", "Whisper Shell", 4, "Secret", 250000, "Ball", "Hold it to your ear. Don't." },
	-- Zone 5 · The Trench
	{ "R052", "Leviathan Tooth", 5, "Mythic", 35000, "Wedge", "Only the brave pry these loose.", "Leviathan" },
	{ "R053", "Vent Crystal", 5, "Uncommon", 22, "Block", "Hot enough to boil water." },
	{ "R054", "Ancient Ruin Tablet", 5, "Rare", 90, "Block", "A language no one speaks." },
	{ "R055", "Pressure Diamond", 5, "Rare", 85, "Ball", "Forged by the whole ocean's weight." },
	{ "R056", "Trench Hydra Fang", 5, "Epic", 480, "Wedge", "There were three of them." },
	{ "R057", "Red Vent Idol", 5, "Epic", 500, "Block", "Glows the colour of the vents." },
	{ "R058", "Crown of the Drowned King", 5, "Mythic", 55000, "Cylinder", "He'll want it back." },
	{ "R059", "Titan's Gauntlet", 5, "Legendary", 4000, "Block", "Built for a hand twice your size." },
	{ "R060", "Heart of the Trench", 5, "Secret", 300000, "Ball", "???", "Silhouette" },
}

local Relics = {
	List = {},
	ById = {},
	-- ByZoneAndRarity[zoneIndex][rarity] = { {item = id, weight = 1}, ... }
	ByZoneAndRarity = {},
	ByRarity = {},
}

for _, row in ROWS do
	local def = {
		Id = row[1],
		Name = row[2],
		Zone = row[3],
		Rarity = row[4],
		BaseCPS = row[5],
		Shape = row[6],
		Lore = row[7],
		Special = row[8],
	}
	table.insert(Relics.List, def)
	Relics.ById[def.Id] = def

	Relics.ByZoneAndRarity[def.Zone] = Relics.ByZoneAndRarity[def.Zone] or {}
	local bucket = Relics.ByZoneAndRarity[def.Zone]
	bucket[def.Rarity] = bucket[def.Rarity] or {}
	table.insert(bucket[def.Rarity], { item = def.Id, weight = 1 })

	Relics.ByRarity[def.Rarity] = Relics.ByRarity[def.Rarity] or {}
	table.insert(Relics.ByRarity[def.Rarity], { item = def.Id, weight = 1 })
end

-- Pick table for a (zone, rarity) pair. Falls back to the nearest zone that has that rarity,
-- so a rarity with non-zero weight can always produce a relic.
function Relics.PoolFor(zoneIndex: number, rarity: string)
	for offset = 0, 5 do
		for _, z in { zoneIndex - offset, zoneIndex + offset } do
			local bucket = Relics.ByZoneAndRarity[z]
			if bucket and bucket[rarity] and #bucket[rarity] > 0 then
				return bucket[rarity]
			end
		end
	end
	return Relics.ByRarity[rarity] or Relics.ByRarity.Common
end

return Relics
