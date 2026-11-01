-- DockService (Master Plan §8): plot assignment, display stands, vault, Coins/sec income,
-- collector pad, offline earnings, laser gate, guard crab and alarm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Upgrades = require(Shared.Config.Upgrades)
local Economy = require(Shared.Config.Economy)
local Build = require(script.Parent.Parent.Util.Build)

local DockService = {}
local services
local limiter = RateLimiter.new(8, 3)
local dockOf: { [Player]: any } = {}
local pendingOffline: { [Player]: number } = {}
local gateState: { [Player]: { activeUntil: number, readyAt: number } } = {}
local alarmSeen: { [string]: number } = {}
local autoCollectBuffer: { [Player]: number } = {}
local joinedAt: { [Player]: number } = {}

function DockService.Init(s)
	services = s
end

function DockService.GetDock(player: Player)
	return dockOf[player]
end

function DockService.GetOwnerOfDock(dock): Player?
	return dock and dock.Owner
end

function DockService.JoinedAt(player: Player): number
	return joinedAt[player] or 0
end

-- §8.2 / §14 / §15 Coins multiplier stack
function DockService.GetCoinMultiplier(player: Player): number
	local data = services.DataService.GetData(player)
	if not data then
		return 1
	end
	local m = Formulas.RebirthMultiplier(data.Rebirths)
	m *= services.MonetizationService.GetCoinMultiplier(player)
	m *= services.SocialService.GetCoinMultiplier(player)
	m *= services.EventService.GetCoinMultiplier()
	return m
end

function DockService.GetBaseCPS(player: Player): number
	local data = services.DataService.GetData(player)
	if not data then
		return 0
	end
	local total = 0
	for _, relic in data.Stands do
		total += Formulas.RelicCPS(relic)
	end
	for _, relic in data.Vault do
		total += Formulas.RelicCPS(relic)
	end
	return total
end

function DockService.GetIncomePerSecond(player: Player): number
	return DockService.GetBaseCPS(player) * DockService.GetCoinMultiplier(player)
end

------------------------------------------------------------------------------------------
-- Rendering
------------------------------------------------------------------------------------------
local function clearModel(stand: BasePart)
	local m = stand:FindFirstChild("RelicModel")
	if m then
		m:Destroy()
	end
end

local function renderStand(stand: BasePart, relic, visible: boolean, mult: number, isVault: boolean)
	clearModel(stand)
	stand:SetAttribute("Visible", visible)
	stand:SetAttribute("HasRelic", visible and relic ~= nil)
	stand.Transparency = if visible then 0 else 1
	stand.CanCollide = visible
	local place = stand:FindFirstChild("Place") :: ProximityPrompt
	local steal = stand:FindFirstChild("Steal") :: ProximityPrompt?
	local info = stand:FindFirstChild("Info") :: BillboardGui
	place.Enabled = visible
	if steal then
		steal.Enabled = visible and relic ~= nil
	end
	if not visible then
		info.Label.Text = ""
		return
	end
	if relic then
		local def = Relics.ById[relic.id]
		local model = Build.RelicModel(def, Rarities[relic.rarity].Color, relic.mutations, Mutations.ById, relic.size)
		model.Name = "RelicModel"
		model:SetAttribute("Rarity", relic.rarity)
		model:SetAttribute("RelicId", relic.id)
		model:PivotTo(CFrame.new(stand.Position + Vector3.new(0, 2.8, 0)) * stand.CFrame.Rotation)
		model.Parent = stand
		local mut = if #relic.mutations > 0 then table.concat(relic.mutations, " ") .. " " else ""
		info.Label.Text = `{mut}{def.Name}\n+{NumberFormat.short(Formulas.RelicCPS(relic) * mult)}/s`
		info.Label.TextColor3 = Rarities[relic.rarity].Color
		place.ActionText = "Take back"
		place.ObjectText = def.Name
		if steal then
			steal.ObjectText = `{mut}{def.Name}`
		end
	else
		info.Label.Text = if isVault then "VAULT (safe)" else "Empty"
		info.Label.TextColor3 = Color3.new(1, 1, 1)
		place.ActionText = if isVault then "Vault" else "Display"
		place.ObjectText = if isVault then "Unstealable slot" else "Empty stand"
	end
end

function DockService.RefreshDock(player: Player)
	local dock = dockOf[player]
	local data = services.DataService.GetData(player)
	if not dock or not data then
		return
	end
	local passes = services.MonetizationService.OwnedSet(player)
	local standCount = Formulas.StandCount(data, passes)
	local vaultCount = Formulas.VaultCount(data, passes)
	local mult = DockService.GetCoinMultiplier(player)
	for i, stand in dock.Stands do
		renderStand(stand, data.Stands[tostring(i)], i <= standCount, mult, false)
	end
	for i, stand in dock.Vault do
		renderStand(stand, data.Vault[tostring(i)], i <= vaultCount, mult, true)
	end
	dock.GatePrompt.Enabled = (data.Upgrades.Gate or 0) > 0
	local name = if data.DockName ~= "" then data.DockName else `{player.DisplayName}'s Dock`
	local vip = if services.MonetizationService.Owns(player, "VIP") then "[VIP] " else ""
	dock.Sign.Text = `{vip}{name}\n+{NumberFormat.short(DockService.GetIncomePerSecond(player))}/s`
	dock.Model:SetAttribute("OwnerUserId", player.UserId)
	services.DataService.Push(player, {
		DockIndex = dock.Index,
		IncomePerSecond = DockService.GetIncomePerSecond(player),
		DockValue = Formulas.DockValue(data),
	})
end

------------------------------------------------------------------------------------------
-- Placement
------------------------------------------------------------------------------------------
local function bestUnplaced(data)
	local best, bestCps = nil, -1
	for _, list in { data.Storage, data.Bag } do
		for _, r in list do
			local cps = Formulas.RelicCPS(r)
			if cps > bestCps then
				best, bestCps = r, cps
			end
		end
	end
	return best
end

function DockService.PlaceRelic(player: Player, uid: string, slot: number, vault: boolean): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local passes = services.MonetizationService.OwnedSet(player)
	local count = if vault then Formulas.VaultCount(data, passes) else Formulas.StandCount(data, passes)
	if slot < 1 or slot > count or slot % 1 ~= 0 then
		return false
	end
	if services.RaidService.IsBeingStolen(player, uid) then
		return false
	end
	local container = if vault then data.Vault else data.Stands
	local key = tostring(slot)
	local where = services.InventoryService.Find(data, uid)
	if where ~= "Bag" and where ~= "Storage" and where ~= "Stands" and where ~= "Vault" then
		return false
	end
	local relic = services.InventoryService.Take(data, uid)
	if not relic then
		return false
	end
	-- Swap out whatever is on the slot back to storage
	local existing = container[key]
	if existing then
		if services.RaidService.IsBeingStolen(player, existing.uid) then
			services.InventoryService.AddToStorage(player, relic)
			return false
		end
		container[key] = nil
		existing.placedAt = nil
		table.insert(data.Storage, existing)
	end
	relic.placedAt = os.time()
	container[key] = relic
	services.DataService.Replicate(player, "Bag", "Storage", "Stands", "Vault")
	DockService.RefreshDock(player)
	services.AnalyticsService.Funnel(player, "FirstDisplay")
	return true
end

function DockService.Pickup(player: Player, slot: number, vault: boolean): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local container = if vault then data.Vault else data.Stands
	local key = tostring(slot)
	local relic = container[key]
	if not relic or services.RaidService.IsBeingStolen(player, relic.uid) then
		return false
	end
	container[key] = nil
	relic.placedAt = nil
	table.insert(data.Storage, relic)
	services.DataService.Replicate(player, "Storage", "Stands", "Vault")
	DockService.RefreshDock(player)
	return true
end

-- Raid support: remove a displayed relic (stolen) without returning it to storage
function DockService.RemoveDisplayed(owner: Player, slot: number)
	local data = services.DataService.GetData(owner)
	if not data then
		return nil
	end
	local relic = data.Stands[tostring(slot)]
	data.Stands[tostring(slot)] = nil
	services.DataService.Replicate(owner, "Stands")
	DockService.RefreshDock(owner)
	return relic
end

function DockService.PlacedRecently(owner: Player, slot: number, seconds: number): boolean
	local data = services.DataService.GetData(owner)
	local relic = data and data.Stands[tostring(slot)]
	return relic ~= nil and relic.placedAt ~= nil and os.time() - relic.placedAt < seconds
end

-- Put a relic on the first free stand, else storage (used for successful raids)
function DockService.AddRelicToDock(player: Player, relic)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	local count = Formulas.StandCount(data, services.MonetizationService.OwnedSet(player))
	for i = 1, count do
		if not data.Stands[tostring(i)] then
			relic.placedAt = os.time()
			data.Stands[tostring(i)] = relic
			services.DataService.Replicate(player, "Stands")
			DockService.RefreshDock(player)
			return
		end
	end
	services.InventoryService.AddToStorage(player, relic)
end

------------------------------------------------------------------------------------------
-- Collector pad & offline earnings
------------------------------------------------------------------------------------------
function DockService.Collect(player: Player)
	local data = services.DataService.GetData(player)
	if not data or data.Uncollected < 1 then
		return
	end
	local amount = math.floor(data.Uncollected)
	data.Uncollected = 0
	services.CurrencyService.AddCoins(player, amount, "DockIncome")
	services.QuestService.Progress(player, "Collect", 1)
	local dock = dockOf[player]
	Net.CoinBurst:FireClient(player, amount, dock and dock.Pad.Position, "Collected!")
	data.Flags.Collects = (data.Flags.Collects or 0) + 1
	if data.Flags.Collects == 5 and not services.MonetizationService.Owns(player, "AutoCollect") then
		Net.Offer:FireClient(player, "AutoCollect")
	end
end

-- Appendix D
function DockService.ComputeOffline(player: Player): number
	local data = services.DataService.GetData(player)
	if not data or data.LastLogout == 0 then
		return 0
	end
	local elapsed = math.max(0, os.time() - data.LastLogout)
	local capHours = Formulas.OfflineCapHours(
		data,
		services.MonetizationService.OwnedSet(player),
		services.MonetizationService.HasActiveSubscription(player)
	)
	local seconds = math.min(elapsed, capHours * 3600)
	return math.floor(DockService.GetIncomePerSecond(player) * Formulas.OfflineRate(data) * seconds), elapsed, capHours
end

function DockService.ResetGateCooldown(player: Player)
	local g = gateState[player]
	if g then
		g.readyAt = 0
	end
end

function DockService.GateActive(owner: Player): boolean
	local g = gateState[owner]
	return g ~= nil and g.activeUntil > os.clock()
end

local function activateGate(player: Player)
	local data = services.DataService.GetData(player)
	local dock = dockOf[player]
	if not data or not dock then
		return
	end
	local level = data.Upgrades.Gate or 0
	if level < 1 then
		Net.Notify:FireClient(player, "Buy the Laser Gate upgrade first.", "error")
		return
	end
	local g = gateState[player]
	local now = os.clock()
	if g.readyAt > now then
		Net.Notify:FireClient(player, `Gate recharging: {NumberFormat.time(g.readyAt - now)}`, "error")
		Net.Offer:FireClient(player, "GateRecharge")
		return
	end
	local duration = Upgrades.Base.GateSeconds + (level - 1) * 10
	g.activeUntil = now + duration
	g.readyAt = now + duration + Upgrades.Base.GateCooldown
	dock.Gate.Transparency = 0.6
	Net.Notify:FireClient(player, `Laser Gate active for {duration}s`, "info")
	task.delay(duration, function()
		if dock.Owner == player and gateState[player] and gateState[player].activeUntil <= os.clock() + 0.1 then
			dock.Gate.Transparency = 1
		end
	end)
end

------------------------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------------------------
local function assignDock(player: Player)
	for _, dock in services.WorldService.GetDocks() do
		if not dock.Owner then
			dock.Owner = player
			dockOf[player] = dock
			return dock
		end
	end
	return nil
end

local function spawnAtDock(player: Player, character: Model)
	local dock = dockOf[player]
	if not dock then
		return
	end
	if services.DiveService.ConsumeReviveSpawn(player, character) then
		return
	end
	task.defer(function()
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if hrp then
			services.SecurityService.AllowTeleport(player)
			character:PivotTo(dock.SpawnCFrame)
		end
	end)
end

local function onProfileLoaded(player: Player, profile)
	local dock = assignDock(player)
	joinedAt[player] = os.time()
	gateState[player] = { activeUntil = 0, readyAt = 0 }
	if not dock then
		warn("[DockService] no free dock for " .. player.Name)
		return
	end
	player.CharacterAdded:Connect(function(char)
		spawnAtDock(player, char)
	end)
	if player.Character then
		spawnAtDock(player, player.Character)
	end
	-- 90s Dock Lock on join (§8.4)
	dock.Gate.Transparency = 0.8
	task.delay(Economy.Raid.JoinLockSeconds, function()
		if dock.Owner == player and not DockService.GateActive(player) then
			dock.Gate.Transparency = 1
		end
	end)
	DockService.RefreshDock(player)

	local amount, elapsed, capHours = DockService.ComputeOffline(player)
	if amount and amount > 0 then
		pendingOffline[player] = amount
		Net.OfflineEarnings:FireClient(player, {
			Amount = amount,
			Elapsed = elapsed,
			CapHours = capHours,
			CanDouble = services.MonetizationService.HasActiveSubscription(player),
		})
	end
end

local function onRelease(player: Player, profile)
	local pending = pendingOffline[player]
	if pending then
		profile.Data.Coins += pending
		profile.Data.LifetimeCoins += pending
		pendingOffline[player] = nil
	end
	local buffered = autoCollectBuffer[player]
	if buffered and buffered > 0 then
		profile.Data.Coins += math.floor(buffered)
		profile.Data.LifetimeCoins += math.floor(buffered)
	end
	autoCollectBuffer[player] = nil
	local dock = dockOf[player]
	if dock then
		dock.Owner = nil
		dock.Model:SetAttribute("OwnerUserId", nil)
		for _, stand in dock.Stands do
			renderStand(stand, nil, false, 1, false)
		end
		for _, stand in dock.Vault do
			renderStand(stand, nil, false, 1, true)
		end
		dock.Sign.Text = "Empty Dock"
		dock.PadLabel.Text = ""
		dock.Gate.Transparency = 1
		dock.GatePrompt.Enabled = false
	end
	dockOf[player] = nil
	gateState[player] = nil
	joinedAt[player] = nil
end

function DockService.Start()
	services.DataService.ProfileLoaded:Connect(onProfileLoaded)
	services.DataService.OnRelease(onRelease)
	services.MonetizationService.PassGranted:Connect(function(player)
		DockService.RefreshDock(player)
	end)

	-- Stand prompts (server-side Triggered). Client hides irrelevant prompts locally.
	for _, dock in services.WorldService.GetDocks() do
		for i, stand in dock.Stands do
			(stand:FindFirstChild("Place") :: ProximityPrompt).Triggered:Connect(function(player)
				if dock.Owner ~= player or not limiter:Check(player) then
					return
				end
				local data = services.DataService.GetData(player)
				if data.Stands[tostring(i)] then
					DockService.Pickup(player, i, false)
				else
					local best = bestUnplaced(data)
					if best then
						DockService.PlaceRelic(player, best.uid, i, false)
					else
						Net.Notify:FireClient(player, "No relics to display. Go dive!", "info")
					end
				end
			end)
		end
		for i, stand in dock.Vault do
			(stand:FindFirstChild("Place") :: ProximityPrompt).Triggered:Connect(function(player)
				if dock.Owner ~= player or not limiter:Check(player) then
					return
				end
				local data = services.DataService.GetData(player)
				if data.Vault[tostring(i)] then
					DockService.Pickup(player, i, true)
				else
					local best = bestUnplaced(data)
					if best then
						DockService.PlaceRelic(player, best.uid, i, true)
					end
				end
			end)
		end
		dock.Pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and dock.Owner == player then
				DockService.Collect(player)
			end
		end)
		dock.GatePrompt.Triggered:Connect(function(player)
			if dock.Owner == player then
				activateGate(player)
			end
		end)
	end

	Net.RequestPlaceRelic.OnServerEvent:Connect(function(player, uid, slot, vault)
		if not limiter:Check(player) or typeof(uid) ~= "string" or typeof(slot) ~= "number" then
			return
		end
		DockService.PlaceRelic(player, uid, slot, vault == true)
	end)
	Net.RequestPickupRelic.OnServerEvent:Connect(function(player, slot, vault)
		if not limiter:Check(player) or typeof(slot) ~= "number" then
			return
		end
		DockService.Pickup(player, slot, vault == true)
	end)
	Net.RequestCollect.OnServerEvent:Connect(function(player)
		if limiter:Check(player) then
			-- Remote collect only works while standing on your own dock
			local dock = dockOf[player]
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if dock and hrp and services.WorldService.IsInsideDock(dock, hrp.Position) then
				DockService.Collect(player)
			end
		end
	end)
	Net.RequestClaimOffline.OnServerEvent:Connect(function(player, double)
		local amount = pendingOffline[player]
		if not amount then
			return
		end
		pendingOffline[player] = nil
		if double == true and services.MonetizationService.HasActiveSubscription(player) then
			amount *= 2
		end
		services.CurrencyService.AddCoins(player, amount, "Offline")
		Net.CoinBurst:FireClient(player, amount, nil, "Welcome back!")
	end)
	Net.ActivateGate.OnServerEvent:Connect(function(player)
		if limiter:Check(player) then
			activateGate(player)
		end
	end)
	Net.RenameDock.OnServerEvent:Connect(function(player, text)
		if not limiter:Check(player) or typeof(text) ~= "string" then
			return
		end
		local data = services.DataService.GetData(player)
		if not data or data.RenameTokens < 1 then
			Net.Offer:FireClient(player, "RenameDock")
			return
		end
		text = text:sub(1, 24)
		local filtered = services.SecurityService.FilterForBroadcast(player, text)
		if not filtered then
			Net.Notify:FireClient(player, "That name couldn't be used.", "error")
			return
		end
		data.RenameTokens -= 1
		data.DockName = filtered
		services.DataService.Replicate(player, "RenameTokens", "DockName")
		DockService.RefreshDock(player)
	end)

	-- Income tick (1 Hz)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for player, dock in dockOf do
				local data = services.DataService.GetData(player)
				if data then
					local income = DockService.GetIncomePerSecond(player)
					if services.MonetizationService.Owns(player, "AutoCollect") then
						autoCollectBuffer[player] = (autoCollectBuffer[player] or 0) + income
						if tick % 5 == 0 and autoCollectBuffer[player] >= 1 then
							local amt = math.floor(autoCollectBuffer[player])
							autoCollectBuffer[player] -= amt
							services.CurrencyService.AddCoins(player, amt, "DockIncome")
						end
						dock.PadLabel.Text = "AUTO"
					else
						data.Uncollected += income
						dock.PadLabel.Text = NumberFormat.short(data.Uncollected)
					end
					if tick % 15 == 0 then
						dock.Sign.Text = dock.Sign.Text:gsub("\n.*$", "") .. `\n+{NumberFormat.short(income)}/s`
					end
				end
			end
		end
	end)

	-- Intruder detection: alarm, guard crab slow (§8.4)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, intruder in Players:GetPlayers() do
				local char = intruder.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local slow = 1
					for owner, dock in dockOf do
						local data = services.DataService.GetData(owner)
						local alarmMargin = 2 + (data and data.Upgrades.Alarm or 0) * 10
						if owner ~= intruder and services.WorldService.IsInsideDock(dock, hrp.Position, alarmMargin) then
							local crab = data and data.Upgrades.Crab or 0
							if crab > 0 and services.WorldService.IsInsideDock(dock, hrp.Position) then
								slow = math.min(slow, 1 - 0.06 * crab)
							end
							local key = owner.UserId .. ":" .. intruder.UserId
							if (alarmSeen[key] or 0) + 20 < os.clock() then
								alarmSeen[key] = os.clock()
								Net.Intruder:FireClient(owner, { Name = intruder.DisplayName, UserId = intruder.UserId })
							end
						end
					end
					char:SetAttribute("DockSlow", slow)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return DockService
