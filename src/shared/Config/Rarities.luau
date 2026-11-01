-- Rarity tiers (Master Plan §7.1)
-- Tier order matters: luck multiplies the weight of every tier >= Epic.

local Rarities = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },

	Common = { Tier = 1, Color = Color3.fromRGB(170, 170, 170), Icon = "●", Reveal = "none" },
	Uncommon = { Tier = 2, Color = Color3.fromRGB(85, 200, 90), Icon = "▲", Reveal = "sparkle" },
	Rare = { Tier = 3, Color = Color3.fromRGB(60, 140, 255), Icon = "◆", Reveal = "beam" },
	Epic = { Tier = 4, Color = Color3.fromRGB(170, 80, 255), Icon = "★", Reveal = "glow" },
	Legendary = { Tier = 5, Color = Color3.fromRGB(255, 190, 40), Icon = "✦", Reveal = "slowmo", Announce = "local" },
	Mythic = { Tier = 6, Color = Color3.fromRGB(255, 50, 70), Icon = "✹", Reveal = "fanfare", Announce = "server" },
	Secret = { Tier = 7, Color = Color3.fromRGB(20, 20, 20), Icon = "✪", Reveal = "fanfare", Announce = "global" },
}

function Rarities.TierOf(name: string): number
	local r = Rarities[name]
	return if type(r) == "table" and r.Tier then r.Tier else 0
end

return Rarities
