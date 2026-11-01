-- RaidService (Master Plan §9, Appendix E): steal validation, carry state, steal-back,
-- fairness guardrails, revenge teleport and the raid tutorial ghost (§17 step 11).
--
-- Anti-dupe: while a relic is being carried it stays in the OWNER's profile (flagged as being
-- stolen). It only moves to the raider in one server step when the raider reaches their dock.

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
local Economy = require(Shared.Config.Economy)
local Build = require(script.Parent.Parent.Util.Build)

local R = Economy.Raid

local RaidService = {}
local services
local limiter = RateLimiter.new(4, 1)
local holdStart: { [Player]: { dock: any, slot: number, t: number } } = {}
local carrying: { [Player]: any } = {}
local beingStolen: { [Player]: { [string]: Player } } = {}
local raiderCooldown: { [Player]: number } = {}
local victimImmuneUntil: { [Player]: number } = {}
local victimLog: { [Player]: { number } } = {}
local revenge: { [Player]: { thief: Player, untilTime: number } } = {}

function RaidService.Init(s)
	services = s
end

function RaidService.IsBeingStolen(owner: Player, uid: string): boolean
	return beingStolen[owner] ~= nil and beingStolen[owner][uid] ~= nil
end

function RaidService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

local function stealsEnabled(): boolean
	if not R.Enabled then
		return false
	end
	if game.PrivateServerId ~= "" and not R.PrivateServerSteals then
		return false
	end
	return true
end

function RaidService.IsShielded(owner: Player): (boolean, string?)
	local data = services.DataService.GetData(owner)
	if not data then
		return true, "loading"
	end
	if data.PlayTime < R.NewPlayerShieldSeconds then
		return true, "New player shield"
	end
	if (victimImmuneUntil[owner] or 0) > os.time() then
		return true, "Recently robbed"
	end
	if os.time() - services.DockService.JoinedAt(owner) < R.JoinLockSeconds then
		return true, "Dock Lock"
	end
	if services.DockService.GateActive(owner) then
		return true, "Laser Gate"
	end
	local log = victimLog[owner]
	if log then
		local recent = 0
		for _, t in log do
			if os.time() - t < 3600 then
				recent += 1
			end
		end
		if recent >= R.MaxPerVictimPerHour then
			return true, "Hourly limit"
		end
	end
	return false, nil
end

function RaidService.InPowerBand(raider: Player, owner: Player): boolean
	local rv = math.max(Formulas.DockValue(services.DataService.GetData(raider)), 50)
	local ov = math.max(Formulas.DockValue(services.DataService.GetData(owner)), 1)
	local ratio = ov / rv
	return ratio >= R.PowerBandMin and ratio <= R.PowerBandMax
end

------------------------------------------------------------------------------------------
-- Carry visuals
------------------------------------------------------------------------------------------
local function attachCarryVisual(raider: Player, relic)
	local char = raider.Character
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not torso then
		return
	end
	local def = Relics.ById[relic.id]
	local model = Build.RelicModel(def, Rarities[relic.rarity].Color, relic.mutations, Mutations.ById, relic.size)
	model.Name = "CarriedRelic"
	model:PivotTo(torso.CFrame * CFrame.new(0, 0.5, 1.6))
	local root = model.PrimaryPart :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = if part == root then torso else root, part
			weld.Parent = part
		end
	end
	model.Parent = char
	local hl = Instance.new("Highlight")
	hl.Name = "ThiefHighlight"
	hl.FillColor = Color3.fromRGB(255, 50, 50)
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.FillTransparency = 0.6
	hl.Parent = char
	local bb = Build.Billboard(torso, "THIEF!", UDim2.fromOffset(120, 40), Vector3.new(0, 4, 0), Color3.fromRGB(255, 70, 70))
	bb.Name = "ThiefTag"
	bb.AlwaysOnTop = true
	bb.MaxDistance = 300
	char:SetAttribute("CarrySlow", R.CarrySpeedMult)
end

local function clearCarryVisual(raider: Player)
	local char = raider.Character
	if not char then
		return
	end
	for _, name in { "CarriedRelic", "ThiefHighlight" } do
		local x = char:FindFirstChild(name)
		if x then
			x:Destroy()
		end
	end
	for _, d in char:GetDescendants() do
		if d.Name == "ThiefTag" then
			d:Destroy()
		end
	end
	char:SetAttribute("CarrySlow", nil)
end

local function endCarry(raider: Player, success: boolean, recoveredBy: Player?)
	local c = carrying[raider]
	if not c then
		return
	end
	carrying[raider] = nil
	clearCarryVisual(raider)
	Net.CarryChanged:FireClient(raider, nil)
	local owner = c.owner
	if beingStolen[owner] then
		beingStolen[owner][c.uid] = nil
	end
	raiderCooldown[raider] = os.clock() + R.RaiderCooldown
	local def = Relics.ById[c.relicId]

	if not success then
		if raider.Parent then
			Net.Notify:FireClient(raider, `The {def.Name} was knocked loose!`, "error")
		end
		if owner.Parent then
			services.DockService.RefreshDock(owner)
			Net.Notify:FireClient(owner, `Your {def.Name} is back on its stand!`, "reward")
		end
		if recoveredBy and recoveredBy ~= owner and recoveredBy.Parent then
			-- Bounty for anyone who stops a thief (§9.1)
			local relic = services.DataService.GetData(owner).Stands[tostring(c.slot)]
			local bounty = relic and math.floor(Formulas.SellPrice(relic) * 0.1) or 100
			services.CurrencyService.AddCoins(recoveredBy, math.max(bounty, 100), "Bounty")
			Net.Notify:FireClient(recoveredBy, `Thief stopped! Bounty +{NumberFormat.short(math.max(bounty, 100))}`, "coins")
		end
		services.AnalyticsService.Custom(raider, "RaidFail", 1)
		return
	end

	-- Success: move the relic in one step
	local ownerData = services.DataService.GetData(owner)
	local relic = ownerData and ownerData.Stands[tostring(c.slot)]
	if not relic or relic.uid ~= c.uid then
		return
	end
	services.DockService.RemoveDisplayed(owner, c.slot)
	relic.placedAt = nil
	services.DockService.AddRelicToDock(raider, relic)

	local raiderData = services.DataService.GetData(raider)
	raiderData.Stats.Steals += 1
	ownerData.Stats.TimesRobbed += 1
	services.DataService.Replicate(raider, "Stats")
	services.DataService.Replicate(owner, "Stats")
	victimImmuneUntil[owner] = os.time() + R.VictimImmunity
	victimLog[owner] = victimLog[owner] or {}
	table.insert(victimLog[owner], os.time())
	revenge[owner] = { thief = raider, untilTime = os.clock() + R.RevengeWindow }

	services.QuestService.Progress(raider, "Steal", 1)
	services.QuestService.AddXp(raider, Economy.Xp.Steal)
	services.AnalyticsService.Custom(raider, "RaidSuccess", 1, { CustomField01 = relic.rarity })
	services.AnalyticsService.Custom(owner, "Robbed", 1, { CustomField01 = relic.rarity })
	Net.Notify:FireClient(raider, `You stole a {def.Name}!`, "reward")
	Net.Robbed:FireClient(owner, {
		Thief = raider.DisplayName,
		Relic = def.Name,
		Rarity = relic.rarity,
		RevengeSeconds = R.RevengeWindow,
		HasVault = services.MonetizationService.Owns(owner, "VaultLock"),
	})
	if Rarities.TierOf(relic.rarity) >= Rarities.Legendary.Tier then
		services.AnnouncementService.Server(`{raider.DisplayName} stole a {relic.rarity} {def.Name} from {owner.DisplayName}!`, relic.rarity)
	end
end

function RaidService.OnCarrierDied(player: Player)
	endCarry(player, false, nil)
end

------------------------------------------------------------------------------------------
-- Steal request (Appendix E)
------------------------------------------------------------------------------------------
local function trySteal(raider: Player, dock, slot: number)
	if not limiter:Check(raider) then
		return
	end
	local owner = dock.Owner
	local deny = function(msg: string)
		Net.Notify:FireClient(raider, msg, "error")
	end
	if not owner or owner == raider then
		return
	end
	if not stealsEnabled() then
		return deny("Stealing is disabled in this server.")
	end
	local rData, oData = services.DataService.GetData(raider), services.DataService.GetData(owner)
	if not (rData and oData) then
		return
	end
	if rData.Level < R.MinLevel then
		return deny(`Raiding unlocks at level {R.MinLevel}.`)
	end
	if carrying[raider] then
		return deny("You're already carrying a relic!")
	end
	local shielded, why = RaidService.IsShielded(owner)
	if shielded then
		return deny(`This dock is protected ({why}).`)
	end
	if not RaidService.InPowerBand(raider, owner) then
		return deny("That dock is outside your power band.")
	end
	if (raiderCooldown[raider] or 0) > os.clock() then
		return deny(`Steal cooldown: {math.ceil(raiderCooldown[raider] - os.clock())}s`)
	end
	local hrp = raider.Character and raider.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not services.WorldService.IsInsideDock(dock, hrp.Position) then
		return
	end
	local relic = oData.Stands[tostring(slot)]
	if not relic then
		return
	end
	if relic.rarity == "Secret" and not R.AllowSecretSteal then
		return deny("Secret relics can't be stolen.")
	end
	if services.DockService.PlacedRecently(owner, slot, R.PlacedProtectSeconds) then
		return deny("That relic was just placed — it's protected for a moment.")
	end
	if RaidService.IsBeingStolen(owner, relic.uid) then
		return
	end
	-- Server-timed hold (§23)
	local h = holdStart[raider]
	if not h or h.dock ~= dock or h.slot ~= slot or os.clock() - h.t < R.HoldSeconds - 0.3 then
		return
	end
	holdStart[raider] = nil

	beingStolen[owner] = beingStolen[owner] or {}
	beingStolen[owner][relic.uid] = raider
	carrying[raider] = { owner = owner, slot = slot, uid = relic.uid, relicId = relic.id, start = os.clock() }
	attachCarryVisual(raider, relic)
	-- hide the relic on the stand while it's carried
	local stand = dock.Stands[slot]
	local m = stand:FindFirstChild("RelicModel")
	if m then
		for _, part in m:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "Root" then
				part.Transparency = math.max(part.Transparency, 0.85)
			end
		end
	end
	Net.CarryChanged:FireClient(raider, { Relic = relic.id, Owner = owner.DisplayName })
	Net.Intruder:FireClient(owner, { Name = raider.DisplayName, UserId = raider.UserId, Stealing = Relics.ById[relic.id].Name })
	Net.Notify:FireClient(raider, "Got it! Run back to YOUR dock before someone tags you!", "info")
end

------------------------------------------------------------------------------------------
-- Raid tutorial ghost (§17 step 11)
------------------------------------------------------------------------------------------
local function runRaidTutorial(player: Player)
	local data = services.DataService.GetData(player)
	local dock = services.DockService.GetDock(player)
	if not data or not dock or data.Flags.RaidTutorialDone then
		return
	end
	local slot, relic
	for k, r in data.Stands do
		if not relic or Formulas.RelicCPS(r) < Formulas.RelicCPS(relic) then
			slot, relic = tonumber(k), r
		end
	end
	if not relic then
		return
	end
	local stand = dock.Stands[slot]
	local ghost = Build.Part({
		Name = "TutorialGhost",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 4,
		CFrame = CFrame.new(stand.Position + Vector3.new(0, 4, 0)),
		Color = Color3.fromRGB(200, 230, 255),
		Material = Enum.Material.ForceField,
		CanCollide = false,
		Parent = services.WorldService.Root(),
	})
	Build.Billboard(ghost, "Ghost Thief", UDim2.fromOffset(140, 36), Vector3.new(0, 3, 0), Color3.fromRGB(200, 230, 255))
	Net.Notify:FireClient(player, "A ghost is stealing your relic! Touch it to get it back!", "error")
	Net.Intruder:FireClient(player, { Name = "Ghost Thief", UserId = 0, Stealing = Relics.ById[relic.id].Name, Tutorial = true })
	local target = Vector3.new(0, ghost.Position.Y, 0)
	local started = os.clock()
	task.spawn(function()
		while ghost.Parent and os.clock() - started < 45 do
			local dt = task.wait(0.1)
			local dir = target - ghost.Position
			if dir.Magnitude > 1 then
				ghost.Position += dir.Unit * 6 * dt
			end
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - ghost.Position).Magnitude < 7 then
				data.Flags.RaidTutorialDone = true
				services.AnalyticsService.Funnel(player, "RaidTutorial")
				Net.Notify:FireClient(
					player,
					"Recovered! Real thieves carry relics to their dock — tag them first. Laser Gates and Vault slots keep you safe.",
					"reward"
				)
				services.CurrencyService.AddPearls(player, 10, "RaidTutorial")
				break
			end
		end
		if ghost.Parent then
			ghost:Destroy()
		end
		data.Flags.RaidTutorialDone = true
	end)
end

function RaidService.Start()
	for _, dock in services.WorldService.GetDocks() do
		for i, stand in dock.Stands do
			local prompt = stand:FindFirstChild("Steal") :: ProximityPrompt
			prompt.HoldDuration = R.HoldSeconds
			prompt.PromptButtonHoldBegan:Connect(function(player)
				holdStart[player] = { dock = dock, slot = i, t = os.clock() }
			end)
			prompt.Triggered:Connect(function(player)
				trySteal(player, dock, i)
			end)
		end
	end

	Net.RequestRevenge.OnServerEvent:Connect(function(player)
		local r = revenge[player]
		revenge[player] = nil
		if not r or r.untilTime < os.clock() or not r.thief.Parent then
			return
		end
		local thiefDock = services.DockService.GetDock(r.thief)
		local char = player.Character
		if thiefDock and char then
			services.SecurityService.AllowTeleport(player)
			char:PivotTo(thiefDock.CFrame * CFrame.new(0, 4, 32))
		end
	end)

	-- Carry loop: success at own dock, steal-back by touch
	task.spawn(function()
		while true do
			task.wait(0.1)
			for raider, c in carrying do
				local char = raider.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not raider.Parent or not hrp or not c.owner.Parent then
					endCarry(raider, false, nil)
					continue
				end
				local myDock = services.DockService.GetDock(raider)
				if myDock and services.WorldService.IsInsideDock(myDock, hrp.Position) then
					endCarry(raider, true, nil)
					continue
				end
				for _, other in Players:GetPlayers() do
					if other ~= raider then
						local ohrp = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
						local ohum = other.Character and other.Character:FindFirstChildOfClass("Humanoid")
						if ohrp and ohum and ohum.Health > 0 and (ohrp.Position - hrp.Position).Magnitude < R.StealBackRadius then
							endCarry(raider, false, other)
							break
						end
					end
				end
			end
		end
	end)

	-- Raid tutorial trigger at ~10 minutes of playtime
	task.spawn(function()
		while true do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				local data = services.DataService.GetData(player)
				if
					data
					and not data.Flags.RaidTutorialDone
					and not data.Flags.RaidTutorialStarted
					and data.PlayTime >= 600
					and next(data.Stands)
				then
					data.Flags.RaidTutorialStarted = true -- only offer once
					runRaidTutorial(player)
				end
			end
		end
	end)

	services.DataService.OnRelease(function(player)
		-- Leaving while carrying: relic stays with the owner
		endCarry(player, false, nil)
		-- Owner leaving while being robbed: cancel the raid so the relic saves with them
		for raider, c in carrying do
			if c.owner == player then
				endCarry(raider, false, nil)
			end
		end
		beingStolen[player] = nil
		raiderCooldown[player] = nil
		victimImmuneUntil[player] = nil
		victimLog[player] = nil
		revenge[player] = nil
		holdStart[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return RaidService
