-- Pure loot-rolling logic (Master Plan §7). Shared so the client's odds display uses the
-- exact same table the server rolls from (§16 "displayed odds must match").

local Config = script.Parent.Config
local Rarities = require(Config.Rarities)
local Mutations = require(Config.Mutations)
local Relics = require(Config.Relics)
local Zones = require(Config.Zones)
local WeightedRandom = require(script.Parent.WeightedRandom)

local LootRoll = {}

export type Modifiers = {
	luck: number?, -- multiplies weights of Epic and above
	pity: number?, -- added to Legendary weight
	rarityMult: { [string]: number }?, -- event multipliers per rarity
	mutationMult: number?, -- global mutation-chance multiplier (potions)
	mutationById: { [string]: number }?, -- per-mutation multipliers (events)
	mutationAdd: { [string]: number }?, -- flat chance added (event-only mutations)
}

function LootRoll.RarityTable(zoneIndex: number, mods: Modifiers?)
	local zone = Zones.List[zoneIndex]
	local m = mods or {}
	local luck = m.luck or 1
	local out = {}
	for _, name in Rarities.Order do
		local w = zone.RarityWeights[name] or 0
		if w > 0 then
			if Rarities[name].Tier >= Rarities.Epic.Tier then
				w *= luck
			end
			if m.rarityMult and m.rarityMult[name] then
				w *= m.rarityMult[name]
			end
			if name == "Legendary" and m.pity then
				w += m.pity
			end
			table.insert(out, { item = name, weight = w })
		end
	end
	return out
end

function LootRoll.MutationTable(mods: Modifiers?)
	local m = mods or {}
	local mult = m.mutationMult or 1
	local entries = {}
	local mutatedTotal = 0
	for _, def in Mutations.List do
		local c = def.Chance * mult
		if m.mutationById and m.mutationById[def.Id] then
			c *= m.mutationById[def.Id]
		end
		if m.mutationAdd and m.mutationAdd[def.Id] then
			c += m.mutationAdd[def.Id]
		end
		if c > 0 then
			table.insert(entries, { item = def.Id, weight = c })
			mutatedTotal += c
		end
	end
	-- Cap total mutated chance at 95% so "None" always exists
	if mutatedTotal > 95 then
		local scale = 95 / mutatedTotal
		for _, e in entries do
			e.weight *= scale
		end
		mutatedTotal = 95
	end
	table.insert(entries, 1, { item = "None", weight = 100 - mutatedTotal })
	return entries
end

function LootRoll.RollMutations(rng: Random, mods: Modifiers?): { string }
	local tbl = LootRoll.MutationTable(mods)
	local first = WeightedRandom.pick(tbl, rng)
	if first == "None" then
		return {}
	end
	local result = { first }
	if rng:NextNumber() * 100 < Mutations.DoubleChance then
		local rest = {}
		for _, e in tbl do
			if e.item ~= "None" and e.item ~= first then
				table.insert(rest, e)
			end
		end
		if #rest > 0 then
			table.insert(result, WeightedRandom.pick(rest, rng))
		end
	end
	return result
end

-- §7.5 size 0.8–1.5, approximately normal (Box–Muller), "Huge" above 1.35
function LootRoll.RollSize(rng: Random): number
	local u1 = math.max(rng:NextNumber(), 1e-9)
	local u2 = rng:NextNumber()
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	local size = 1.05 + z * 0.12
	return math.floor(math.clamp(size, 0.8, 1.5) * 100 + 0.5) / 100
end

function LootRoll.RollRarity(rng: Random, zoneIndex: number, mods: Modifiers?): string
	return WeightedRandom.pick(LootRoll.RarityTable(zoneIndex, mods), rng)
end

function LootRoll.RollRelicId(rng: Random, zoneIndex: number, rarity: string): string
	return WeightedRandom.pick(Relics.PoolFor(zoneIndex, rarity), rng)
end

-- Full roll: returns a plain table (no uid; InventoryService assigns it)
function LootRoll.Roll(rng: Random, zoneIndex: number, mods: Modifiers?)
	local rarity = LootRoll.RollRarity(rng, zoneIndex, mods)
	return {
		id = LootRoll.RollRelicId(rng, zoneIndex, rarity),
		rarity = rarity,
		mutations = LootRoll.RollMutations(rng, mods),
		size = LootRoll.RollSize(rng),
	}
end

return LootRoll
