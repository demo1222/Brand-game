-- AnalyticsService wrapper (Master Plan §25): funnels, economy events, custom events, and
-- deterministic A/B buckets. All Roblox calls are pcall-wrapped so analytics can never break
-- gameplay.

local RobloxAnalytics = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local Analytics = {}

local FTUE_STEPS = {
	"Join",
	"FirstDive",
	"FirstSalvage",
	"FirstRare",
	"FirstDisplay",
	"FirstUpgrade",
	"SecondDive",
	"KelpSuit",
	"RaidTutorial",
	"Session10min",
}
local services

function Analytics.Init(s)
	services = s
end

-- §25.4 deterministic bucket: hash(UserId) % 100
function Analytics.Bucket(player: Player, experiment: string): string
	local variants = Economy.Experiments[experiment]
	if not variants then
		return "control"
	end
	local h = 0
	local s = tostring(player.UserId) .. experiment
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return variants[(h % 100) % #variants + 1]
end

function Analytics.Funnel(player: Player, step: string)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	if data.Flags["F_" .. step] then
		return
	end
	data.Flags["F_" .. step] = true
	services.DataService.Replicate(player, "Flags")
	local index = table.find(FTUE_STEPS, step)
	if index then
		pcall(function()
			RobloxAnalytics:LogOnboardingFunnelStepEvent(player, index, step)
		end)
	end
end

function Analytics.Economy(player: Player, flowIn: boolean, currency: string, amount: number, balance: number, txType: string, sku: string)
	if amount <= 0 then
		return
	end
	pcall(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			if flowIn then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
			currency,
			math.floor(amount),
			math.floor(balance),
			txType,
			sku
		)
	end)
end

function Analytics.Custom(player: Player, name: string, value: number?, fields: { [string]: any }?)
	pcall(function()
		RobloxAnalytics:LogCustomEvent(player, name, value or 1, fields)
	end)
end

function Analytics.LogPurchase(player: Player, kind: string, key: string, robux: number?)
	Analytics.Custom(player, "Purchase_" .. kind, robux or 0, {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = key,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = Analytics.Bucket(player, "StarterPackPrice"),
	})
end

return Analytics
