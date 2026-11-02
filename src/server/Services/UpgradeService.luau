-- UpgradeService (Master Plan §11): Coin upgrade tracks and suit tiers.
-- Also pushes derived stats (oxygen, speed, bag size…) to the client for display and sets
-- character attributes the client SwimController reads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Upgrades = require(Shared.Config.Upgrades)
local SuitArt = require(Shared.SuitArt)

local UpgradeService = {}
local services
local limiter = RateLimiter.new(8, 4)

function UpgradeService.Init(s)
	services = s
end

function UpgradeService.Derived(player: Player)
	local data = services.DataService.GetData(player)
	if not data then
		return nil
	end
	local passes = services.MonetizationService.OwnedSet(player)
	local subscribed = services.MonetizationService.HasActiveSubscription(player)
	return {
		MaxOxygen = Formulas.MaxOxygen(data, passes),
		SwimSpeed = Formulas.SwimSpeed(data, passes),
		DiveBoardDepth = Formulas.DiveBoardDepth(data),
		DiveLaunch = Formulas.DiveLaunch(data),
		DiveOut = Formulas.DiveOut(data),
		BagSize = Formulas.BagSize(data, passes),
		StandCount = Formulas.StandCount(data, passes),
		VaultCount = Formulas.VaultCount(data, passes),
		SalvageSeconds = Formulas.SalvageSeconds(data),
		SonarRange = Formulas.SonarRange(data),
		SonarCooldown = Formulas.SonarCooldown(data),
		OfflineRate = Formulas.OfflineRate(data),
		OfflineCapHours = Formulas.OfflineCapHours(data, passes, subscribed),
		CoinMult = services.DockService.GetCoinMultiplier(player),
		Luck = services.MonetizationService.GetLuckMultiplier(player) * services.EventService.GetLuckMultiplier(),
		RebirthRequirement = Formulas.RebirthRequirement(data.Rebirths),
		StarterPackAvailable = services.MonetizationService.StarterPackAvailable(player),
		StarterPackShownAt = data.StarterPackShownAt,
		CanBuyRandom = services.PolicyWrapper.CanBuyRandomItems(player),
	}
end

function UpgradeService.PushDerived(player: Player)
	local d = UpgradeService.Derived(player)
	if not d then
		return
	end
	services.DataService.Push(player, { Derived = d })
	local char = player.Character
	if char then
		char:SetAttribute("SwimSpeed", d.SwimSpeed)
		char:SetAttribute("SalvageSeconds", d.SalvageSeconds)
		char:SetAttribute("DiveBoardDepth", d.DiveBoardDepth)
		char:SetAttribute("DiveLaunch", d.DiveLaunch)
		char:SetAttribute("DiveOut", d.DiveOut)
	end
end

function UpgradeService.Purchase(player: Player, trackId: string): boolean
	local data = services.DataService.GetData(player)
	local track = Upgrades.ById[trackId]
	if not data or not track then
		return false
	end
	local level = data.Upgrades[trackId] or 0
	if level >= track.Max then
		Net.Notify:FireClient(player, `{track.Name} is maxed!`, "info")
		return false
	end
	local cost = Upgrades.Cost(trackId, level)
	if not services.CurrencyService.SpendCoins(player, cost, "Upgrade_" .. trackId) then
		Net.Notify:FireClient(player, `Need {NumberFormat.short(cost)} Coins`, "error")
		return false
	end
	data.Upgrades[trackId] = level + 1
	services.DataService.Replicate(player, "Upgrades")
	UpgradeService.PushDerived(player)
	if trackId == "Display" or trackId == "Gate" then
		services.DockService.RefreshDock(player)
	end
	services.QuestService.Progress(player, "Upgrade", 1)
	services.AnalyticsService.Funnel(player, "FirstUpgrade")
	Net.Notify:FireClient(player, `{track.Name} → Lv {level + 1}`, "upgrade")
	return true
end

function UpgradeService.BuySuit(player: Player): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local nextIndex = data.Suit + 1
	local suit = Upgrades.Suits[nextIndex]
	if not suit then
		return false
	end
	if suit.ComingSoon then
		Net.Notify:FireClient(player, `{suit.Name} arrives with The Sunken Throne update!`, "info")
		return false
	end
	if not services.CurrencyService.SpendCoins(player, suit.Cost, "Suit_" .. suit.Id) then
		Net.Notify:FireClient(player, `Need {NumberFormat.short(suit.Cost)} Coins`, "error")
		return false
	end
	data.Suit = nextIndex
	services.DataService.Replicate(player, "Suit")
	UpgradeService.PushDerived(player)
	UpgradeService.ApplySuitVisual(player)
	services.AnalyticsService.Custom(player, "ZoneUnlocked", nextIndex)
	if nextIndex == 2 then
		services.AnalyticsService.Funnel(player, "KelpSuit")
	end
	Net.Notify:FireClient(player, `New suit: {suit.Name}! You can now dive safely to zone {nextIndex}.`, "upgrade")
	return true
end

-- Dresses the character in the suit tier's gear (shared/SuitArt), honouring the player's
-- visibility settings from the Diver window.
function UpgradeService.ApplySuitVisual(player: Player)
	local data = services.DataService.GetData(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local suit = Upgrades.Suits[data.Suit]
	SuitArt.Apply(char, data.Suit, suit.Color, data.Settings)
end

function UpgradeService.Start()
	Net.RequestUpgrade.OnServerEvent:Connect(function(player, trackId)
		if limiter:Check(player) and typeof(trackId) == "string" then
			UpgradeService.Purchase(player, trackId)
		end
	end)
	Net.RequestBuySuit.OnServerEvent:Connect(function(player)
		if limiter:Check(player) then
			UpgradeService.BuySuit(player)
		end
	end)
	services.DataService.ProfileLoaded:Connect(function(player)
		local function onChar(char)
			char:WaitForChild("Humanoid", 5)
			task.wait(0.5)
			UpgradeService.PushDerived(player)
			UpgradeService.ApplySuitVisual(player)
		end
		player.CharacterAdded:Connect(onChar)
		if player.Character then
			task.spawn(onChar, player.Character)
		end
		UpgradeService.PushDerived(player)
	end)
	services.DataService.SettingsChanged:Connect(function(player)
		UpgradeService.ApplySuitVisual(player)
	end)
	services.MonetizationService.PassGranted:Connect(function(player)
		UpgradeService.PushDerived(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
	-- Periodic refresh (boost expiry, events, friend count changes)
	task.spawn(function()
		while true do
			task.wait(15)
			for _, p in Players:GetPlayers() do
				UpgradeService.PushDerived(p)
			end
		end
	end)
end

return UpgradeService
