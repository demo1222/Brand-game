-- Derived stats & economy formulas shared by server (authoritative) and client (display).
-- Master Plan §8.2, §11, §12, §13.

local Config = script.Parent.Config
local Upgrades = require(Config.Upgrades)
local Economy = require(Config.Economy)
local Relics = require(Config.Relics)
local Mutations = require(Config.Mutations)

local B = Upgrades.Base
local Formulas = {}

local function lvl(data, id: string): number
	return (data.Upgrades and data.Upgrades[id]) or 0
end

local function talent(data, id: string): number
	return (data.Talents and data.Talents[id]) or 0
end

-- passes: {[key]=true}
function Formulas.MaxOxygen(data, passes): number
	local o = B.OxygenSeconds
	if passes and passes.DoubleOxygen then
		o *= 2
	end
	return o + lvl(data, "Oxygen") * B.OxygenPerLevel + talent(data, "Lungs") * 10
end

-- Diving board: how deep a jump off your dock's board plunges you (UI/Visual plan, Phase 4)
function Formulas.DiveBoardDepth(data): number
	return B.BoardDepth + lvl(data, "Board") * B.BoardDepthPerLevel
end

function Formulas.SwimSpeed(data, passes): number
	local s = B.SwimSpeed * (1 + lvl(data, "Fins") * B.FinsPerLevel)
	if passes and passes.SpeedFins then
		s *= 1.3
	end
	return s
end

function Formulas.BagSize(data, passes): number
	local n = B.BagSize + lvl(data, "Bag") + talent(data, "ExtraBag")
	if passes and passes.BigBag then
		n += 4
	end
	return n
end

function Formulas.StandCount(data, passes): number
	local n = B.Stands + lvl(data, "Display")
	if passes and passes.ExtraSlots then
		n += 4
	end
	return n
end

function Formulas.VaultCount(_data, passes): number
	return if passes and passes.VaultLock then 2 else 0
end

function Formulas.SalvageSeconds(data): number
	return B.SalvageSeconds * (1 - B.SalvagePerLevel) ^ lvl(data, "Salvage")
end

function Formulas.SonarRange(data): number
	return B.SonarRange + lvl(data, "Sonar") * B.SonarPerLevel
end

function Formulas.SonarCooldown(data): number
	return math.max(2, B.SonarCooldown - lvl(data, "Sonar") * 0.2)
end

function Formulas.OfflineRate(data): number
	return B.OfflineRate + lvl(data, "Offline") * B.OfflineRatePerLevel
end

function Formulas.OfflineCapHours(data, passes, subscribed: boolean?): number
	local h = B.OfflineCapHours + lvl(data, "Offline") * B.OfflineCapPerLevelHours
	if passes and passes.VIP then
		h += Economy.VipOfflineHours
	end
	if subscribed then
		h += Economy.SubOfflineHours
	end
	return h
end

function Formulas.NoiseMultiplier(data): number
	return math.max(0.4, 1 - talent(data, "QuietDiver") * 0.1)
end

-- §8.2 per-relic CPS before player-level multipliers
function Formulas.RelicCPS(relic): number
	local def = Relics.ById[relic.id]
	if not def then
		return 0
	end
	return def.BaseCPS * (relic.size or 1) * Mutations.MultiplierOf(relic.mutations)
end

function Formulas.SellPrice(relic, coinMult: number?): number
	return math.floor(Formulas.RelicCPS(relic) * Economy.SellSeconds * (coinMult or 1))
end

function Formulas.RebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Economy.Rebirth.CoinMultPerRebirth
end

function Formulas.RebirthLuck(rebirths: number): number
	return 1 + math.min(rebirths * Economy.Rebirth.LuckPerRebirth, Economy.Rebirth.LuckCap)
end

function Formulas.RebirthRequirement(rebirths: number): number
	return Economy.Rebirth.BaseCoins * Economy.Rebirth.Growth ^ rebirths
end

function Formulas.UpgradeCost(trackId: string, level: number): number
	return Upgrades.Cost(trackId, level)
end

-- Sum of displayed relic CPS (no player multipliers). Used for the raid power band (§9.2).
function Formulas.DockValue(data): number
	local total = 0
	for _, relic in (data.Stands or {}) do
		total += Formulas.RelicCPS(relic)
	end
	for _, relic in (data.Vault or {}) do
		total += Formulas.RelicCPS(relic)
	end
	return total
end

function Formulas.LevelXp(level: number): number
	return math.floor(100 * level ^ 1.5)
end

-- Tide Pass tier rewards (§15.5). Shared so the client can preview exactly what the server grants.
function Formulas.TierReward(tier: number, premium: boolean)
	if premium then
		if tier == Economy.TidePass.Tiers then
			return { Relic = "Mythic" }
		elseif tier % 10 == 0 then
			return { Relic = "Epic" }
		elseif tier % 5 == 0 then
			return { Boost = "MutationPotion", Seconds = 600 }
		end
		return { Pearls = 10 }
	end
	if tier % 10 == 0 then
		return { Relic = "Rare" }
	elseif tier % 5 == 0 then
		return { Pearls = 20 }
	end
	return { Coins = 500 * tier }
end

return Formulas
