-- Relic materials and size tiers (docs/ECONOMY.md section 7). A material is what a relic is
-- made of: rolled once when it's found, at most one per relic, and it stacks with mutations
-- and size: CPS = BaseCPS x size x mutation multiplier x material multiplier.
--
-- Materials share the mutation look pipeline: RelicArt reads the first entry of the look list
-- for its colour and material, so `Materials.LookList(relic)` puts the material first and
-- `Materials.LookDefs` holds both mutation and material defs.

local Mutations = require(script.Parent.Mutations)

local Materials = {
	-- Chance is percent per relic. Luck (suits, potions, passes) multiplies it: see LootRoll.
	List = {
		{ Id = "Gold", Name = "Gold", Chance = 4, Mult = 3, Color = Color3.fromRGB(255, 196, 40), Material = "Foil", Glow = Color3.fromRGB(255, 220, 120) },
		{ Id = "Emerald", Name = "Emerald", Chance = 1, Mult = 6, Color = Color3.fromRGB(40, 220, 110), Material = "Glass", Glow = Color3.fromRGB(120, 255, 170) },
		{ Id = "Diamond", Name = "Diamond", Chance = 0.25, Mult = 12, Color = Color3.fromRGB(200, 245, 255), Material = "Glass", Glow = Color3.fromRGB(230, 250, 255) },
		{ Id = "Rainbow", Name = "Rainbow", Chance = 0.03, Mult = 30, Color = Color3.fromRGB(255, 120, 230), Material = "Neon", Glow = Color3.fromRGB(255, 160, 240) },
	},
	ById = {},

	-- Size tiers by the relic's size factor (LootRoll.RollSize: 0.8 to 1.5, mean 1.05).
	-- The size factor already multiplies CPS; the tier is the name and the model scale shown.
	SizeTiers = {
		{ Id = "Tiny", Min = 0, Label = "Tiny", Color = Color3.fromRGB(170, 180, 200) },
		{ Id = "Normal", Min = 0.9, Label = nil, Color = Color3.fromRGB(255, 255, 255) },
		{ Id = "Big", Min = 1.2, Label = "Big", Color = Color3.fromRGB(120, 210, 255) },
		{ Id = "Huge", Min = 1.35, Label = "HUGE", Color = Color3.fromRGB(255, 120, 90) },
		{ Id = "Titanic", Min = 1.5, Label = "TITANIC", Color = Color3.fromRGB(255, 80, 200) },
	},
}

for _, m in Materials.List do
	Materials.ById[m.Id] = m
end

-- Mutation and material defs in one lookup (for RelicArt's look)
Materials.LookDefs = setmetatable({}, { __index = Mutations.ById })
for id, m in Materials.ById do
	Materials.LookDefs[id] = m
end

function Materials.MultiplierOf(id: string?): number
	local def = id and Materials.ById[id]
	return if def then def.Mult else 1
end

-- The list RelicArt should use for the look: the material (if any) first, then mutations
function Materials.LookList(relic): { string }
	local out = {}
	if relic.material and Materials.ById[relic.material] then
		table.insert(out, relic.material)
	end
	for _, m in relic.mutations or {} do
		table.insert(out, m)
	end
	return out
end

function Materials.SizeTier(size: number?)
	local s = size or 1
	local tier = Materials.SizeTiers[1]
	for _, t in Materials.SizeTiers do
		if s >= t.Min then
			tier = t
		end
	end
	return tier
end

-- "HUGE Gold Cursed Ship's Wheel": the size word (if any), the material, the mutations
function Materials.Prefix(relic): string
	local bits = {}
	local tier = Materials.SizeTier(relic.size)
	if tier.Label then
		table.insert(bits, tier.Label)
	end
	if relic.material and Materials.ById[relic.material] then
		table.insert(bits, Materials.ById[relic.material].Name)
	end
	for _, m in relic.mutations or {} do
		table.insert(bits, m)
	end
	return if #bits > 0 then table.concat(bits, " ") .. " " else ""
end

return Materials
