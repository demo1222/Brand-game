-- Mutations (Master Plan §7.4)
-- Chance is the base probability per relic (percent). Event-only mutations have Chance = 0
-- and only appear while an event multiplies them (EventService).

local Mutations = {
	List = {
		{ Id = "Gilded", Chance = 6, Mult = 2, Color = Color3.fromRGB(255, 200, 60), Material = "Foil" },
		{ Id = "Barnacled", Chance = 4, Mult = 1.5, Color = Color3.fromRGB(150, 130, 100), Material = "Slate" },
		{ Id = "Bioluminescent", Chance = 2.5, Mult = 3, Color = Color3.fromRGB(40, 240, 255), Material = "Neon" },
		{ Id = "Frozen", Chance = 1, Mult = 4, Color = Color3.fromRGB(190, 230, 255), Material = "Ice" },
		{ Id = "Cursed", Chance = 0.8, Mult = 6, Color = Color3.fromRGB(140, 40, 200), Material = "Neon", Noisy = true },
		{ Id = "Ancient", Chance = 0.5, Mult = 8, Color = Color3.fromRGB(200, 170, 110), Material = "Sandstone" },
		{ Id = "Prismatic", Chance = 0.15, Mult = 15, Color = Color3.fromRGB(255, 120, 230), Material = "Glass" },
		{ Id = "Void", Chance = 0.05, Mult = 30, Color = Color3.fromRGB(10, 0, 20), Material = "ForceField" },
		{ Id = "Wet", Chance = 0, Mult = 1.5, Color = Color3.fromRGB(90, 160, 255), Material = "Glass", EventOnly = true },
		{
			Id = "KrakenTouched",
			Chance = 0,
			Mult = 10,
			Color = Color3.fromRGB(60, 0, 90),
			Material = "Neon",
			EventOnly = true,
		},
	},
	ById = {},
	-- Percent of mutated relics that roll a second, different mutation
	DoubleChance = 1,
	-- Barnacled relics can be cleaned (dev product) for a reroll
}

for _, m in Mutations.List do
	Mutations.ById[m.Id] = m
end

function Mutations.MultiplierOf(list: { string }?): number
	local m = 1
	if list then
		for _, id in list do
			local def = Mutations.ById[id]
			if def then
				m *= def.Mult
			end
		end
	end
	return m
end

return Mutations
