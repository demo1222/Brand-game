-- Economy simulation (Master Plan §30.3). Simulates virtual players over 30 days with
-- different play patterns and prints median time-to-milestone, to compare with §13.3.
-- Uses the REAL configs and loot tables from src/shared, so tuning a config and re-running
-- shows the effect immediately.
--
--   lune run tools/economy_sim            (defaults: 300 players per profile)
--   lune run tools/economy_sim 1000
--
-- Model (deliberately simple): a dive lasts the oxygen time; the player salvages one relic
-- every ~9s (faster with Salvage upgrades), dives in the deepest zone their suit allows,
-- displays the best relics, sells the rest, then greedily buys the cheapest useful upgrade or
-- the next suit. Offline income is 25% of CPS, capped at 4h (plus upgrades).

local process = require("@lune/process")
local H = require("../tests/harness")

local LootRoll = H.require("src/shared/LootRoll")
local Formulas = H.require("src/shared/Formulas")
local Upgrades = H.require("src/shared/Config/Upgrades")

local PLAYERS = tonumber(process.args[1]) or 300
local DAYS = 30

local PROFILES = {
	{ Name = "Casual (20 min/day)", MinutesPerDay = 20, Passes = {} },
	{ Name = "Core (2 h/day)", MinutesPerDay = 120, Passes = {} },
	{ Name = "Payer (VIP+2xO2+Drone, 2 h/day)", MinutesPerDay = 120, Passes = { VIP = true, DoubleOxygen = true, Drone = true } },
}

local MILESTONES = {
	{ Id = "FirstUpgrade", Label = "First upgrade" },
	{ Id = "Suit2", Label = "Kelp suit" },
	{ Id = "Suit3", Label = "Wrecks suit" },
	{ Id = "Suit4", Label = "Abyss suit" },
	{ Id = "Rebirth", Label = "First Resurface" },
	{ Id = "Suit5", Label = "Trench suit" },
	{ Id = "Mythic", Label = "First Mythic" },
}

local function simulate(profile, seed: number)
	local rng = H.Random.new(seed)
	local data = { Upgrades = {}, Talents = {}, Rebirths = 0, Stands = {}, Vault = {}, Suit = 1 }
	local displayed = {}
	local coins, lifetime = 0, 0
	local playSeconds = 0
	local reached = {}
	local coinMult = if profile.Passes.VIP then 1.5 else 1

	local function cps(): number
		local total = 0
		for _, r in displayed do
			total += Formulas.RelicCPS(r)
		end
		return total * Formulas.RebirthMultiplier(data.Rebirths) * coinMult
	end
	local function earn(amount: number)
		coins += amount
		lifetime += amount
	end
	local function mark(id: string)
		if not reached[id] then
			reached[id] = playSeconds
		end
	end

	local function spend()
		-- next suit first when affordable, else cheapest upgrade among core tracks
		local nextSuit = Upgrades.Suits[data.Suit + 1]
		if nextSuit and not nextSuit.ComingSoon and coins >= nextSuit.Cost then
			coins -= nextSuit.Cost
			data.Suit += 1
			mark("Suit" .. data.Suit)
			return true
		end
		local best, bestCost = nil, math.huge
		for _, id in { "Oxygen", "Bag", "Display", "Fins", "Salvage" } do
			local lvl = data.Upgrades[id] or 0
			if lvl < Upgrades.ById[id].Max then
				local cost = Upgrades.Cost(id, lvl)
				if cost < bestCost then
					best, bestCost = id, cost
				end
			end
		end
		-- save up for the suit when it's within 3 minutes of income
		if nextSuit and not nextSuit.ComingSoon and nextSuit.Cost - coins < cps() * 180 then
			return false
		end
		if best and coins >= bestCost then
			coins -= bestCost
			data.Upgrades[best] = (data.Upgrades[best] or 0) + 1
			mark("FirstUpgrade")
			return true
		end
		return false
	end

	local function dive()
		local oxygen = Formulas.MaxOxygen(data, profile.Passes)
		local zone = math.min(data.Suit, 5)
		local perRelic = 9 * (Formulas.SalvageSeconds(data) / Upgrades.Base.SalvageSeconds)
		local travel = 8 + zone * 6
		local relicCount = math.clamp(math.floor((oxygen - travel) / perRelic), 1, Formulas.BagSize(data, profile.Passes))
		if profile.Passes.Drone then
			relicCount = math.min(relicCount + 1, Formulas.BagSize(data, profile.Passes))
		end
		local duration = math.max(oxygen * 0.8, 30) + 20 -- dive + time at the dock
		for _ = 1, relicCount do
			local relic = LootRoll.Roll(rng, zone, {})
			if relic.rarity == "Mythic" or relic.rarity == "Secret" then
				mark("Mythic")
			end
			-- display if better than the weakest stand, else sell
			local stands = Formulas.StandCount(data, profile.Passes)
			if #displayed < stands then
				table.insert(displayed, relic)
			else
				table.sort(displayed, function(a, b)
					return Formulas.RelicCPS(a) < Formulas.RelicCPS(b)
				end)
				if Formulas.RelicCPS(relic) > Formulas.RelicCPS(displayed[1]) then
					earn(Formulas.SellPrice(displayed[1], coinMult))
					displayed[1] = relic
				else
					earn(Formulas.SellPrice(relic, coinMult))
				end
			end
		end
		earn(cps() * duration)
		playSeconds += duration
		while spend() do
		end
		-- Resurface as soon as allowed
		if data.Suit >= 4 and lifetime >= Formulas.RebirthRequirement(data.Rebirths) then
			data.Rebirths += 1
			mark("Rebirth")
			coins = 0
			data.Upgrades = { Display = data.Upgrades.Display }
			data.Suit = 1
		end
	end

	for _ = 1, DAYS do
		local sessionEnd = playSeconds + profile.MinutesPerDay * 60
		while playSeconds < sessionEnd do
			dive()
		end
		-- 22+ hours offline, capped
		local capH = Formulas.OfflineCapHours(data, profile.Passes, false)
		earn(cps() * Formulas.OfflineRate(data) * capH * 3600)
		while spend() do
		end
	end
	return reached
end

local function median(list)
	if #list == 0 then
		return nil
	end
	table.sort(list)
	return list[math.ceil(#list / 2)]
end

local function fmt(seconds: number?): string
	if not seconds then
		return "not reached"
	end
	if seconds < 3600 then
		return string.format("%.0f min", seconds / 60)
	end
	return string.format("%.1f h", seconds / 3600)
end

print(`Abyss Salvage economy simulation · {PLAYERS} players/profile · {DAYS} days\n`)
for pi, profile in PROFILES do
	local times = {}
	local counts = {}
	for _, m in MILESTONES do
		times[m.Id] = {}
		counts[m.Id] = 0
	end
	for i = 1, PLAYERS do
		local reached = simulate(profile, pi * 100000 + i)
		for _, m in MILESTONES do
			if reached[m.Id] then
				table.insert(times[m.Id], reached[m.Id])
				counts[m.Id] += 1
			end
		end
	end
	print(profile.Name)
	for _, m in MILESTONES do
		print(string.format("  %-16s median %-12s (%d%% reached) — playtime", m.Label, fmt(median(times[m.Id])), math.floor(counts[m.Id] / PLAYERS * 100)))
	end
	print("")
end
print("Targets (§13.3): first upgrade 2 min · Kelp 12 min · Wrecks 1.5 h · Abyss 6 h · Resurface 10–12 h · Trench 25 h · Mythic 8–15 h")
