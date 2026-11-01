-- Unit tests for the pure shared modules (Master Plan §30.1). Run from the repo root:
--   lune run tests/run

local process = require("@lune/process")
local H = require("./harness")
local test, describe, expect, near = H.test, H.describe, H.expect, H.near

local WeightedRandom = H.require("src/shared/WeightedRandom")
local NumberFormat = H.require("src/shared/NumberFormat")
local LootRoll = H.require("src/shared/LootRoll")
local Formulas = H.require("src/shared/Formulas")
local Zones = H.require("src/shared/Config/Zones")
local Relics = H.require("src/shared/Config/Relics")
local Rarities = H.require("src/shared/Config/Rarities")
local Mutations = H.require("src/shared/Config/Mutations")
local Upgrades = H.require("src/shared/Config/Upgrades")
local Economy = H.require("src/shared/Config/Economy")
local Passes = H.require("src/shared/Config/Passes")
local Products = H.require("src/shared/Config/Products")
local RelicArt = H.require("src/shared/RelicArt")

describe("WeightedRandom", function()
	test("100k rolls match configured weights within ±0.5%", function()
		local entries = { { item = "a", weight = 60 }, { item = "b", weight = 25 }, { item = "c", weight = 10 }, { item = "d", weight = 5 } }
		local rng = H.Random.new(42)
		local counts = { a = 0, b = 0, c = 0, d = 0 }
		local N = 100000
		for _ = 1, N do
			local k = WeightedRandom.pick(entries, rng)
			counts[k] += 1
		end
		near(counts.a / N * 100, 60, 0.5, "a")
		near(counts.b / N * 100, 25, 0.5, "b")
		near(counts.c / N * 100, 10, 0.5, "c")
		near(counts.d / N * 100, 5, 0.5, "d")
	end)
	test("zero-weight entries are never picked", function()
		local rng = H.Random.new(7)
		for _ = 1, 5000 do
			expect(WeightedRandom.pick({ { item = "x", weight = 0 }, { item = "y", weight = 1 } }, rng) == "y")
		end
	end)
	test("percentages sum to 100", function()
		local total = 0
		for _, e in WeightedRandom.percentages(Economy.Crate) do
			total += e.percent
		end
		near(total, 100, 1e-6, "crate odds total")
	end)
end)

describe("NumberFormat", function()
	test("short suffixes", function()
		expect(NumberFormat.short(0) == "0")
		expect(NumberFormat.short(999) == "999")
		expect(NumberFormat.short(1000) == "1.00K", NumberFormat.short(1000))
		expect(NumberFormat.short(12400) == "12.4K", NumberFormat.short(12400))
		expect(NumberFormat.short(1.5e6) == "1.50M", NumberFormat.short(1.5e6))
		expect(NumberFormat.short(999999) == "1.00M", NumberFormat.short(999999))
		expect(NumberFormat.short(2.5e15) == "2.50Qa", NumberFormat.short(2.5e15))
	end)
	test("commas", function()
		expect(NumberFormat.commas(48210) == "48,210", NumberFormat.commas(48210))
		expect(NumberFormat.commas(123) == "123")
		expect(NumberFormat.commas(1234567) == "1,234,567")
	end)
	test("time", function()
		expect(NumberFormat.time(59) == "59s")
		expect(NumberFormat.time(125) == "2m 05s")
		expect(NumberFormat.time(3700) == "1h 01m")
	end)
end)

describe("Config integrity", function()
	test("60 relics with unique ids", function()
		expect(#Relics.List == 60, "relic count " .. #Relics.List)
		local seen = {}
		for _, r in Relics.List do
			expect(not seen[r.Id], "duplicate " .. r.Id)
			seen[r.Id] = true
			expect(Rarities[r.Rarity] ~= nil, "bad rarity " .. r.Rarity)
		end
	end)
	test("zone rarity weights sum to 100%", function()
		for _, z in Zones.List do
			local total = 0
			for _, w in z.RarityWeights do
				total += w
			end
			near(total, 100, 1e-6, z.Id)
		end
	end)
	test("every rarity a zone can roll has a relic pool in that zone", function()
		for _, z in Zones.List do
			for rarity, w in z.RarityWeights do
				if w > 0 then
					local bucket = Relics.ByZoneAndRarity[z.Index]
					expect(bucket and bucket[rarity] and #bucket[rarity] > 0, `{z.Id} has no {rarity} relics`)
				end
			end
		end
	end)
	test("mutation base chances leave room for None", function()
		local total = 0
		for _, m in Mutations.List do
			total += m.Chance
		end
		expect(total < 100)
		near(100 - total, 85, 0.01, "None chance (§7.4)")
	end)
	test("every product and pass has a price", function()
		for key, p in Passes do
			expect(type(p.price) == "number" and p.price > 0, key)
		end
		for key, p in Products do
			expect(type(p.price) == "number" and p.price > 0, key)
		end
	end)
end)

describe("LootRoll", function()
	test("rarity distribution in the Reef matches §7.3", function()
		local rng = H.Random.new(1)
		local counts = {}
		local N = 100000
		for _ = 1, N do
			local r = LootRoll.RollRarity(rng, 1, nil)
			counts[r] = (counts[r] or 0) + 1
		end
		near((counts.Common or 0) / N * 100, 75, 0.5, "Common")
		near((counts.Uncommon or 0) / N * 100, 20, 0.5, "Uncommon")
		expect((counts.Legendary or 0) == 0, "Reef must never roll Legendary")
	end)
	test("luck multiplies Epic+ weights only", function()
		local base = LootRoll.RarityTable(4, nil)
		local lucky = LootRoll.RarityTable(4, { luck = 2 })
		for i, e in base do
			local tier = Rarities[e.item].Tier
			local expected = if tier >= Rarities.Epic.Tier then e.weight * 2 else e.weight
			near(lucky[i].weight, expected, 1e-9, e.item)
		end
	end)
	test("pity adds to Legendary weight", function()
		local t = LootRoll.RarityTable(4, { pity = 5 })
		for _, e in t do
			if e.item == "Legendary" then
				near(e.weight, 6.5 + 5, 1e-9, "Legendary with pity")
			end
		end
	end)
	test("mutation 'None' is ~85% and sizes stay in 0.8–1.5", function()
		local rng = H.Random.new(99)
		local none, N = 0, 50000
		for _ = 1, N do
			if #LootRoll.RollMutations(rng, nil) == 0 then
				none += 1
			end
			local s = LootRoll.RollSize(rng)
			expect(s >= 0.8 and s <= 1.5, "size " .. s)
		end
		near(none / N * 100, 85, 0.6, "None")
	end)
	test("event-only mutations appear only when added", function()
		local rng = H.Random.new(5)
		for _ = 1, 20000 do
			for _, m in LootRoll.RollMutations(rng, nil) do
				expect(m ~= "Wet" and m ~= "KrakenTouched", "event mutation without event")
			end
		end
	end)
end)

describe("Formulas", function()
	local data = { Upgrades = {}, Talents = {}, Rebirths = 0, Stands = {}, Vault = {} }
	test("base stats", function()
		expect(Formulas.MaxOxygen(data, {}) == 60)
		expect(Formulas.BagSize(data, {}) == 3)
		expect(Formulas.StandCount(data, {}) == 6)
	end)
	test("passes", function()
		expect(Formulas.MaxOxygen(data, { DoubleOxygen = true }) == 120)
		expect(Formulas.BagSize(data, { BigBag = true }) == 7)
		expect(Formulas.StandCount(data, { ExtraSlots = true }) == 10)
		expect(Formulas.VaultCount(data, { VaultLock = true }) == 2)
	end)
	test("upgrade cost curve (§11.1)", function()
		expect(Upgrades.Cost("Oxygen", 0) == 50)
		expect(Upgrades.Cost("Oxygen", 1) == math.floor(50 * 1.45))
		expect(Upgrades.Cost("Bag", 3) == math.floor(200 * 1.8 ^ 3))
	end)
	test("rebirth multipliers (§12)", function()
		expect(Formulas.RebirthMultiplier(0) == 1)
		expect(Formulas.RebirthMultiplier(3) == 2.5)
		near(Formulas.RebirthLuck(50), 1.30, 1e-9, "luck cap")
		expect(Formulas.RebirthRequirement(1) == 15e6)
	end)
	test("relic CPS and sell price (§8.2, §13.2)", function()
		local relic = { id = "R021", size = 1.2, mutations = { "Gilded" } }
		near(Formulas.RelicCPS(relic), 55 * 1.2 * 2, 1e-9, "CPS")
		expect(Formulas.SellPrice(relic) == math.floor(55 * 1.2 * 2 * 60))
	end)
end)

describe("RelicArt (UI overhaul)", function()
	test("every relic has art with an existing recipe and a main colour", function()
		for _, def in Relics.List do
			local art = RelicArt.Map[def.Id]
			expect(art ~= nil, `no art for {def.Id}`)
			expect(type(RelicArt.Recipes[art[1]]) == "function", `{def.Id}: unknown archetype '{tostring(art[1])}'`)
			expect(type(art.main) == "table", `{def.Id}: missing main colour`)
		end
	end)
	test("no art entries for relics that don't exist", function()
		for id in RelicArt.Map do
			expect(Relics.ById[id] ~= nil, `art for unknown relic {id}`)
		end
	end)
	test("fallback shapes cover every Shape used in the catalogue", function()
		for _, def in Relics.List do
			expect(type(RelicArt.Recipes[def.Shape]) == "function", `no fallback recipe for shape {def.Shape}`)
		end
	end)
	test("at least 40 distinct archetypes are used", function()
		local used = {}
		local n = 0
		for _, art in RelicArt.Map do
			if not used[art[1]] then
				used[art[1]] = true
				n += 1
			end
		end
		expect(n >= 40, `only {n} archetypes`)
	end)
end)

local r = H.results()
print(`\n{r.passed} passed, {r.failed} failed`)
if r.failed > 0 then
	process.exit(1)
end
