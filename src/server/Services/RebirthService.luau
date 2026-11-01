-- RebirthService — "Resurface" (Master Plan §12).
-- Requirement: Pressure Mk II suit + LifetimeCoins >= 5M * 3^n.
-- Resets Coins, upgrades (Display slots are kept so displayed relics stay put), suit and bag.
-- Keeps relics, Codex, Pearls, passes, cosmetics, level. Grants +50% Coins, +2% luck (cap 30%)
-- and a Rebirth Token for the talent tree.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Economy = require(Shared.Config.Economy)

local RB = Economy.Rebirth
local RebirthService = {}
local services
local limiter = RateLimiter.new(3, 0.5)

function RebirthService.Init(s)
	services = s
end

function RebirthService.CanRebirth(data): (boolean, string?)
	if data.Suit < RB.RequiredSuit then
		return false, "Requires the Pressure Mk II suit"
	end
	local need = Formulas.RebirthRequirement(data.Rebirths)
	if data.LifetimeCoins < need then
		return false, `Requires {NumberFormat.short(need)} lifetime Coins`
	end
	return true, nil
end

local function rebirth(player: Player)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	local ok, why = RebirthService.CanRebirth(data)
	if not ok then
		Net.Notify:FireClient(player, why, "error")
		return
	end
	if services.RaidService.IsCarrying(player) or services.DiveService.IsDiving(player) then
		Net.Notify:FireClient(player, "Return to your dock first.", "error")
		return
	end
	local keepDisplay = data.Upgrades.Display
	data.Coins = 0
	data.Uncollected = 0
	data.Upgrades = { Display = keepDisplay }
	data.Suit = if (data.Talents.StartNeoprene or 0) > 0 then 2 else 1
	for _, relic in data.Bag do
		table.insert(data.Storage, relic)
	end
	data.Bag = {}
	data.Rebirths += 1
	data.RebirthTokens += 1
	services.DataService.Replicate(player, "Coins", "Uncollected", "Upgrades", "Suit", "Bag", "Storage", "Rebirths", "RebirthTokens")
	services.CurrencyService.RefreshLeaderstats(player, data)
	services.UpgradeService.PushDerived(player)
	services.UpgradeService.ApplySuitVisual(player)
	services.DockService.RefreshDock(player)
	services.AnalyticsService.Custom(player, "Rebirth", data.Rebirths)
	services.AnnouncementService.Server(`{player.DisplayName} RESURFACED (x{data.Rebirths})!`, "Epic")
	services.AnnouncementService.UpdateTitle(player)
	Net.Notify:FireClient(
		player,
		`Resurfaced! Coins x{Formulas.RebirthMultiplier(data.Rebirths)}, +1 Rebirth Token.`,
		"upgrade"
	)
end

local function buyTalent(player: Player, id: string)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	for _, t in RB.Talents do
		if t.Id == id then
			local level = data.Talents[id] or 0
			if level >= t.Max then
				return Net.Notify:FireClient(player, `{t.Name} is maxed.`, "info")
			end
			if data.RebirthTokens < t.Cost then
				return Net.Notify:FireClient(player, "Not enough Rebirth Tokens.", "error")
			end
			data.RebirthTokens -= t.Cost
			data.Talents[id] = level + 1
			services.DataService.Replicate(player, "Talents", "RebirthTokens")
			services.UpgradeService.PushDerived(player)
			Net.Notify:FireClient(player, `Talent: {t.Name} Lv {level + 1}`, "upgrade")
			return
		end
	end
end

function RebirthService.Start()
	Net.RequestRebirth.OnServerEvent:Connect(function(player)
		if limiter:Check(player) then
			rebirth(player)
		end
	end)
	Net.RequestTalent.OnServerEvent:Connect(function(player, id)
		if limiter:Check(player) and typeof(id) == "string" then
			buyTalent(player, id)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return RebirthService
