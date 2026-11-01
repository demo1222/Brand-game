-- DiveService (Master Plan §5.2, §6, §10.3): oxygen, depth, zone detection, pressure damage,
-- air pockets, escapes (bag secured at your dock), death, revive in place, bag drops.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Zones = require(Shared.Config.Zones)
local World = require(Shared.Config.World)
local Economy = require(Shared.Config.Economy)
local Build = require(script.Parent.Parent.Util.Build)

local TICK = 0.1
local REVIVE_WINDOW = 10
local BAG_DROP_SECONDS = 90
local AIR_POCKET_COOLDOWN = 45

local DiveService = {}
local services
local state: { [Player]: any } = {}
local pendingDeath: { [Player]: any } = {}
local reviveSpawn: { [Player]: Vector3 } = {}
local limiter = RateLimiter.new(10, 5)

function DiveService.Init(s)
	services = s
end

local function newState()
	return {
		oxygen = 60,
		maxOxygen = 60,
		boosting = false,
		diving = false,
		deepest = 0,
		zone = 0,
		instantUsed = false,
		lowWarned = false,
		lastCause = "Unknown",
		pockets = {},
		lastDepth = 0,
	}
end

function DiveService.GetState(player: Player)
	return state[player]
end

function DiveService.IsDiving(player: Player): boolean
	local s = state[player]
	return s ~= nil and s.diving
end

function DiveService.SetCause(player: Player, cause: string)
	local s = state[player]
	if s then
		s.lastCause = cause
	end
end

function DiveService.RefillOxygen(player: Player): boolean
	local s = state[player]
	if not s then
		return false
	end
	s.oxygen = s.maxOxygen
	s.lowWarned = false
	return true
end

function DiveService.AddOxygen(player: Player, seconds: number)
	local s = state[player]
	if s then
		s.oxygen = math.clamp(s.oxygen + seconds, 0, s.maxOxygen)
	end
end

------------------------------------------------------------------------------------------
-- Dive start / escape
------------------------------------------------------------------------------------------
local function startDive(player: Player, s)
	s.diving = true
	s.deepest = 0
	s.instantUsed = false
	s.lowWarned = false
	local data = services.DataService.GetData(player)
	data.Stats.Dives += 1
	services.DataService.Replicate(player, "Stats")
	services.AnalyticsService.Funnel(player, "FirstDive")
	if data.Stats.Dives >= 2 then
		services.AnalyticsService.Funnel(player, "SecondDive")
	end
	if data.Stats.Dives == 10 and not services.MonetizationService.Owns(player, "Drone") then
		Net.Offer:FireClient(player, "Drone")
	end
	services.PredatorService.ClearHunted(player)
end

local function escape(player: Player, s)
	s.diving = false
	local data = services.DataService.GetData(player)
	local secured = services.InventoryService.SecureBag(player)
	if s.deepest > 5 then
		services.QuestService.Progress(player, "Escape", 1)
		services.QuestService.AddXp(player, Economy.Xp.Escape)
		if services.PredatorService.WasHunted(player) then
			services.QuestService.Progress(player, "LeviathanEscape", 1)
			services.AnalyticsService.Custom(player, "LeviathanEscape", 1)
			Net.Notify:FireClient(player, "You escaped the Leviathan!", "reward")
		end
	end
	if secured > 0 then
		Net.Notify:FireClient(player, `Secured {secured} relic{secured == 1 and "" or "s"} at your dock. Display them on stands!`, "reward")
	end
	if s.deepest > data.Stats.DeepestDepth then
		data.Stats.DeepestDepth = math.floor(s.deepest)
		services.DataService.Replicate(player, "Stats")
		services.CurrencyService.RefreshLeaderstats(player, data)
	end
	s.oxygen = s.maxOxygen
end

------------------------------------------------------------------------------------------
-- Death, revive, bag drop
------------------------------------------------------------------------------------------
local function bagValue(bag): number
	local v = 0
	for _, r in bag do
		v += Formulas.SellPrice(r)
	end
	return v
end

local function createBagDrop(position: Vector3, relics, ownerName: string)
	if #relics == 0 then
		return
	end
	local root = services.WorldService.Root():FindFirstChild("Drops")
	local part = Build.Part({
		Name = "LostBag",
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(position),
		Color = Color3.fromRGB(200, 160, 60),
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = root,
	})
	Build.Instance("PointLight", { Range = 20, Brightness = 3, Color = Color3.fromRGB(255, 200, 80), Parent = part })
	Build.Billboard(part, `{ownerName}'s lost bag ({#relics})`, UDim2.fromOffset(200, 40), Vector3.new(0, 3, 0), Color3.fromRGB(255, 220, 120))
	local prompt = Build.Prompt(part, "Loot bag", `{#relics} relics`, 1, "Loot")
	prompt.Triggered:Connect(function(player)
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp or (hrp.Position - part.Position).Magnitude > 16 then
			return
		end
		local taken = 0
		while #relics > 0 and not services.InventoryService.BagFull(player) do
			local relic = table.remove(relics, 1)
			services.InventoryService.AddToBag(player, relic)
			taken += 1
		end
		if taken > 0 then
			Net.Notify:FireClient(player, `Looted {taken} relic{taken == 1 and "" or "s"}!`, "reward")
		elseif #relics > 0 then
			Net.Notify:FireClient(player, "Your bag is full.", "error")
		end
		if #relics == 0 then
			part:Destroy()
		else
			prompt.ObjectText = `{#relics} relics`
		end
	end)
	task.delay(BAG_DROP_SECONDS, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

local function onDied(player: Player, character: Model)
	local s = state[player]
	local data = services.DataService.GetData(player)
	if not s or not data then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = if hrp then hrp.Position else Vector3.zero
	local depth = World.WaterSurfaceY - position.Y
	local zone = Zones.ForDepth(depth)
	data.Stats.Deaths += 1
	services.DataService.Replicate(player, "Stats")
	services.AnalyticsService.Custom(player, "Death", 1, { CustomField01 = s.lastCause, CustomField02 = zone and zone.Id or "Surface" })
	services.RaidService.OnCarrierDied(player)

	local bag = data.Bag
	data.Bag = {}
	-- Insurance (Vault Lock): keep the single most valuable relic (§10.3)
	local kept = nil
	if #bag > 0 and services.MonetizationService.Owns(player, "VaultLock") then
		table.sort(bag, function(a, b)
			return Formulas.RelicCPS(a) > Formulas.RelicCPS(b)
		end)
		kept = table.remove(bag, 1)
		services.InventoryService.AddToStorage(player, kept)
	end
	services.DataService.Replicate(player, "Bag")

	local subscribed = services.MonetizationService.HasActiveSubscription(player)
	local freeRevive = subscribed and (data.LastFreeRevive // 86400) ~= (os.time() // 86400)
	local pending = {
		bag = bag,
		position = position,
		expires = os.clock() + REVIVE_WINDOW,
		revived = false,
	}
	pendingDeath[player] = pending
	s.diving = false
	Net.PlayerDied:FireClient(player, {
		BagCount = #bag,
		BagValue = bagValue(bag),
		Kept = kept and kept.id or nil,
		Timer = REVIVE_WINDOW,
		FreeRevive = freeRevive,
		Cause = s.lastCause,
		Underwater = depth > 2,
	})
	if zone and zone.Index >= 3 and not services.MonetizationService.Owns(player, "InstantSurface") then
		data.Flags.DeepDeaths = (data.Flags.DeepDeaths or 0) + 1
		if data.Flags.DeepDeaths == 1 or data.Flags.DeepDeaths == 2 then
			task.delay(REVIVE_WINDOW + 1, function()
				Net.Offer:FireClient(player, "InstantSurface")
			end)
		end
	end
	task.delay(REVIVE_WINDOW, function()
		if pendingDeath[player] == pending and not pending.revived then
			pendingDeath[player] = nil
			createBagDrop(position, pending.bag, player.DisplayName)
		end
	end)
end

function DiveService.CanRevive(player: Player): boolean
	local p = pendingDeath[player]
	return p ~= nil and not p.revived and os.clock() < p.expires + 3 -- grace for purchase latency
end

function DiveService.ReviveInPlace(player: Player): boolean
	local p = pendingDeath[player]
	if not p or p.revived then
		return false
	end
	p.revived = true
	pendingDeath[player] = nil
	local data = services.DataService.GetData(player)
	for _, relic in p.bag do
		table.insert(data.Bag, relic)
	end
	services.DataService.Replicate(player, "Bag")
	reviveSpawn[player] = p.position
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		-- Already respawned at the dock: send them back down
		DiveService.ConsumeReviveSpawn(player, char)
	else
		player:LoadCharacter()
	end
	Net.Revived:FireClient(player)
	return true
end

-- Called by DockService on CharacterAdded; returns true if it handled positioning.
function DiveService.ConsumeReviveSpawn(player: Player, character: Model): boolean
	local pos = reviveSpawn[player]
	if not pos then
		return false
	end
	reviveSpawn[player] = nil
	task.defer(function()
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if hrp then
			services.SecurityService.AllowTeleport(player)
			character:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
			local s = state[player]
			if s then
				s.oxygen = s.maxOxygen
				s.diving = true
			end
			-- brief invulnerability against the Leviathan
			character:SetAttribute("SpawnShield", os.clock() + 4)
		end
	end)
	return true
end

------------------------------------------------------------------------------------------
-- Tick
------------------------------------------------------------------------------------------
local function tickPlayer(player: Player, s, dt: number, sendStatus: boolean)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local data = services.DataService.GetData(player)
	if not hrp or not hum or hum.Health <= 0 or not data then
		return
	end
	s.maxOxygen = Formulas.MaxOxygen(data, services.MonetizationService.OwnedSet(player))
	local depth = World.WaterSurfaceY - hrp.Position.Y
	s.lastDepth = depth
	local underwater = depth > 1.5
	local zone = Zones.ForDepth(depth)

	if underwater and zone then
		if not s.diving then
			startDive(player, s)
		end
		s.deepest = math.max(s.deepest, depth)
		if zone.Index ~= s.zone then
			s.zone = zone.Index
			if zone.Index >= 3 then
				services.QuestService.Progress(player, "ReachZone3", 1)
			end
		end
		local drain = zone.OxygenDrain * (if s.boosting then 2 else 1)
		s.oxygen = math.max(0, s.oxygen - drain * dt)
		if s.oxygen <= 0 then
			s.lastCause = "Oxygen"
			hum:TakeDamage(hum.MaxHealth * 0.2 * dt)
			if not data.Flags.OxygenOfferShown and not services.MonetizationService.Owns(player, "DoubleOxygen") then
				data.Flags.OxygenOfferShown = true
				Net.Offer:FireClient(player, "DoubleOxygen")
			end
		end
		if data.Suit < zone.SuitIndex then
			s.lastCause = "Pressure"
			hum:TakeDamage(hum.MaxHealth * Zones.PressureDamagePerSec * dt)
		end
		-- Air pockets
		for _, pocket in services.WorldService.GetAirPockets() do
			if (pocket.Position - hrp.Position).Magnitude < 8 then
				local last = s.pockets[pocket] or 0
				if os.clock() - last > AIR_POCKET_COOLDOWN then
					s.pockets[pocket] = os.clock()
					DiveService.AddOxygen(player, s.maxOxygen * 0.5)
					Net.Notify:FireClient(player, "Air pocket! +50% oxygen", "info")
				end
			end
		end
	else
		s.oxygen = math.min(s.maxOxygen, s.oxygen + s.maxOxygen * 0.35 * dt)
		s.zone = 0
		if s.diving then
			local dock = services.DockService.GetDock(player)
			if dock and services.WorldService.IsInsideDock(dock, hrp.Position) then
				escape(player, s)
			elseif depth < -1 then
				-- Climbed out somewhere else (plaza, another dock): still counts as surfaced
				-- but the bag is only secured at your own dock.
				if #data.Bag == 0 then
					escape(player, s)
				end
			end
		elseif #data.Bag > 0 then
			local dock = services.DockService.GetDock(player)
			if dock and services.WorldService.IsInsideDock(dock, hrp.Position) then
				escape(player, s)
			end
		end
	end

	if sendStatus then
		Net.DiveStatus:FireClient(player, {
			O2 = s.oxygen,
			Max = s.maxOxygen,
			Depth = depth,
			Zone = if underwater and zone then zone.Index else 0,
			Pressure = underwater and zone ~= nil and data.Suit < zone.SuitIndex,
			Diving = s.diving,
		})
	end
end

function DiveService.Start()
	services.DataService.ProfileLoaded:Connect(function(player)
		state[player] = newState()
		local function onChar(char: Model)
			local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
			if hum then
				hum.Died:Connect(function()
					onDied(player, char)
				end)
			end
		end
		player.CharacterAdded:Connect(onChar)
		if player.Character then
			task.spawn(onChar, player.Character)
		end
	end)
	services.DataService.OnRelease(function(player)
		local p = pendingDeath[player]
		if p and not p.revived then
			createBagDrop(p.position, p.bag, player.DisplayName)
		end
		pendingDeath[player] = nil
		reviveSpawn[player] = nil
		state[player] = nil
	end)

	Net.SetBoost.OnServerEvent:Connect(function(player, on)
		local s = state[player]
		if s and limiter:Check(player) then
			s.boosting = on == true
			if s.boosting then
				services.PredatorService.AddNoise(player, 4)
			end
		end
	end)

	Net.RequestFreeRevive.OnServerEvent:Connect(function(player)
		local data = services.DataService.GetData(player)
		if not data or not services.MonetizationService.HasActiveSubscription(player) then
			return
		end
		if (data.LastFreeRevive // 86400) == (os.time() // 86400) then
			return
		end
		if DiveService.ReviveInPlace(player) then
			data.LastFreeRevive = os.time()
			Net.Notify:FireClient(player, "Free Pass+ revive used", "info")
		end
	end)

	Net.RequestInstantSurface.OnServerEvent:Connect(function(player)
		local s = state[player]
		local dock = services.DockService.GetDock(player)
		if not s or not dock or not limiter:Check(player) then
			return
		end
		if not services.MonetizationService.Owns(player, "InstantSurface") then
			Net.Offer:FireClient(player, "InstantSurface")
			return
		end
		if not s.diving or s.instantUsed then
			Net.Notify:FireClient(player, "Instant Resurface works once per dive.", "error")
			return
		end
		if services.RaidService.IsCarrying(player) then
			Net.Notify:FireClient(player, "Can't teleport while carrying a stolen relic!", "error")
			return
		end
		s.instantUsed = true
		local char = player.Character
		if char then
			services.SecurityService.AllowTeleport(player)
			char:PivotTo(dock.SpawnCFrame)
		end
	end)

	task.spawn(function()
		local n = 0
		while true do
			local dt = task.wait(TICK)
			n += 1
			local send = n % 2 == 0
			for player, s in state do
				local ok, err = pcall(tickPlayer, player, s, dt, send)
				if not ok then
					warn("[DiveService] tick error: " .. tostring(err))
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return DiveService
