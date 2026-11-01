-- LootService (Master Plan §5.1, §7, §20.5): salvage nodes, server-side rolls, pity,
-- sonar pre-rolls, the Auto-Salvage Drone and reveal announcements.
--
-- Rolls happen on the server only. A node's result is rolled per player the first time that
-- player either pings it with sonar or salvages it, using that player's luck at that moment.
-- The cached result is what they get when they salvage — so sonar previews are honest and
-- re-pinging can't reroll.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local LootRoll = require(Shared.LootRoll)
local Formulas = require(Shared.Formulas)
local Zones = require(Shared.Config.Zones)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Config.Economy)
local Build = require(script.Parent.Parent.Util.Build)

local LootService = {}
local services
local rng = Random.new()
local nodes = {} -- [part] = {zone, preRolls = {[Player] = roll}, holdStart = {[Player] = clock}}
local sonarLimiter = RateLimiter.new(3, 1)
local lastSonar: { [Player]: number } = {}
local MAX_SALVAGE_DISTANCE = 14
local nodeFolder: Folder

function LootService.Init(s)
	services = s
end

------------------------------------------------------------------------------------------
-- Rolling
------------------------------------------------------------------------------------------
function LootService.BuildMods(player: Player, zoneIndex: number)
	local data = services.DataService.GetData(player)
	local zone = Zones.List[zoneIndex]
	local rarityMult, mutationById, mutationAdd = services.EventService.GetLootMods(zone.Id)
	local luck = services.MonetizationService.GetLuckMultiplier(player)
		* services.EventService.GetLuckMultiplier()
		* services.SocialService.GetPartyLuck(player)
		* services.InventoryService.ZoneLuckBonus(data, zoneIndex)
	return {
		luck = luck,
		pity = data.Pity[zone.Id] or 0,
		rarityMult = rarityMult,
		mutationMult = if services.BoostService.Active(player, "MutationPotion") then 3 else 1,
		mutationById = mutationById,
		mutationAdd = mutationAdd,
	}
end

-- Landmarks are points of interest (§6): relics found near one roll with extra luck
local LANDMARK_RADIUS = 70
local LANDMARK_LUCK = 1.25

function LootService.RollFor(player: Player, zoneIndex: number, position: Vector3?)
	local data = services.DataService.GetData(player)
	-- FTUE (§17): first salvage is a Rusty Anchor, second a guaranteed Rare Doubloon
	if not data.Flags.TutorialSalvage1 then
		data.Flags.TutorialSalvage1 = true
		return { id = "R001", rarity = "Common", mutations = {}, size = 1 }
	elseif not data.Flags.TutorialSalvage2 then
		data.Flags.TutorialSalvage2 = true
		return { id = "R021", rarity = "Rare", mutations = {}, size = 1.1 }
	end
	local mods = LootService.BuildMods(player, zoneIndex)
	if position and services.WorldService.IsNearLandmark(position, zoneIndex, LANDMARK_RADIUS) then
		mods.luck = (mods.luck or 1) * LANDMARK_LUCK
	end
	return LootRoll.Roll(rng, zoneIndex, mods)
end

local function updatePity(player: Player, zoneIndex: number, rarity: string)
	local data = services.DataService.GetData(player)
	local zone = Zones.List[zoneIndex]
	if Rarities.TierOf(rarity) >= Rarities.Legendary.Tier then
		data.Pity[zone.Id] = 0
	elseif zoneIndex >= Zones.PityMinZone then
		data.Pity[zone.Id] = math.min((data.Pity[zone.Id] or 0) + Zones.PityStep, Zones.PityCap)
		data.Flags.DryRolls = (data.Flags.DryRolls or 0) + 1
		if data.Flags.DryRolls == 20 then
			Net.Offer:FireClient(player, "SkipPity")
		end
	end
	if Rarities.TierOf(rarity) >= Rarities.Legendary.Tier then
		data.Flags.DryRolls = 0
	end
	services.DataService.Replicate(player, "Pity")
end

-- Called whenever a player obtains a relic from the ocean
function LootService.OnRelicFound(player: Player, relic, zoneIndex: number)
	local data = services.DataService.GetData(player)
	local def = Relics.ById[relic.id]
	data.Stats.Salvaged += 1
	if relic.rarity == "Mythic" or relic.rarity == "Secret" then
		data.Stats.MythicsFound += 1
	end
	services.DataService.Replicate(player, "Stats")
	services.InventoryService.RecordCodex(player, relic)
	services.EventService.AwardTokens(player, relic)

	local tier = Rarities.TierOf(relic.rarity)
	services.QuestService.Progress(player, "Salvage", 1)
	if tier >= 3 then
		services.QuestService.Progress(player, "RarePlus", 1)
		services.AnalyticsService.Funnel(player, "FirstRare")
	end
	if tier >= 4 then
		services.QuestService.Progress(player, "EpicPlus", 1)
	end
	if #relic.mutations > 0 then
		services.QuestService.Progress(player, "Mutated", 1)
		for _, m in relic.mutations do
			services.QuestService.Progress(player, "Mut_" .. m, 1)
		end
	end
	services.QuestService.AddXp(player, Economy.Xp.Salvage + (Economy.Xp.RarityBonus[relic.rarity] or 0))
	services.AnalyticsService.Funnel(player, "FirstSalvage")

	Net.RevealRelic:FireClient(player, relic, "Salvage")

	local mut = if #relic.mutations > 0 then table.concat(relic.mutations, " ") .. " " else ""
	local huge = if relic.size >= 1.35 then "HUGE " else ""
	local label = `{huge}{mut}{def.Name}`
	local announce = Rarities[relic.rarity].Announce
	if announce == "local" then
		services.AnnouncementService.Near(player, `{player.DisplayName} found a LEGENDARY {label}!`, relic.rarity)
		if not services.MonetizationService.Owns(player, "LuckySonar") and rng:NextNumber() < 0.35 then
			task.delay(4, function()
				Net.Offer:FireClient(player, "LuckySonar")
			end)
		end
		if not data.Flags.LikePrompted then
			data.Flags.LikePrompted = true
			Net.Notify:FireClient(player, "Enjoying Abyss Salvage? Give it a 👍 and ⭐ to support new zones!", "info")
		end
	elseif announce == "server" then
		services.AnnouncementService.Server(`{player.DisplayName} found a MYTHIC {label}!`, relic.rarity)
	elseif announce == "global" then
		services.AnnouncementService.Global(`{player.DisplayName} found a SECRET {label}!`, relic.rarity)
	end
	services.AnalyticsService.Custom(player, "RelicFound", tier, { CustomField01 = relic.rarity, CustomField02 = Zones.List[zoneIndex].Id })
end

-- SkipPity product: an instant roll on the Legendary table (§15.3)
function LootService.GrantLegendaryRoll(player: Player): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local zoneIndex = math.clamp(data.Suit, 2, 5)
	local relic = services.InventoryService.CreateRelic(player, {
		id = LootRoll.RollRelicId(rng, zoneIndex, "Legendary"),
		rarity = "Legendary",
		mutations = LootRoll.RollMutations(rng, LootService.BuildMods(player, zoneIndex)),
		size = LootRoll.RollSize(rng),
	})
	services.InventoryService.AddToStorage(player, relic)
	data.Pity[Zones.List[zoneIndex].Id] = 0
	data.Flags.DryRolls = 0
	LootService.OnRelicFound(player, relic, zoneIndex)
	return true
end

------------------------------------------------------------------------------------------
-- Nodes
------------------------------------------------------------------------------------------
local spawnNode

local function nodeZoneColor(zoneIndex: number): Color3
	return ({
		Color3.fromRGB(255, 240, 180),
		Color3.fromRGB(180, 255, 200),
		Color3.fromRGB(150, 200, 255),
		Color3.fromRGB(120, 255, 255),
		Color3.fromRGB(255, 120, 90),
	})[zoneIndex]
end

local function getPreRoll(player: Player, node)
	local roll = node.preRolls[player]
	if not roll then
		roll = LootService.RollFor(player, node.zone, node.pos)
		node.preRolls[player] = roll
	end
	return roll
end

local function salvage(player: Player, part: BasePart, skipHold: boolean?): boolean
	local node = nodes[part]
	if not node or node.taken then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return false
	end
	-- §23 distance check
	if (hrp.Position - part.Position).Magnitude > MAX_SALVAGE_DISTANCE + (if skipHold then 10 else 0) then
		return false
	end
	-- §23 server-timed hold
	if not skipHold then
		local started = node.holdStart[player]
		local data = services.DataService.GetData(player)
		local required = Formulas.SalvageSeconds(data) * 0.8 - 0.15
		if not started or os.clock() - started < required then
			return false
		end
	end
	if services.InventoryService.BagFull(player) then
		Net.Notify:FireClient(player, "Bag full! Head back to your dock.", "error")
		if not services.MonetizationService.Owns(player, "BigBag") then
			Net.Offer:FireClient(player, "BigBag")
		end
		return false
	end

	local roll = getPreRoll(player, node)
	node.taken = true
	local relic = services.InventoryService.CreateRelic(player, roll)
	services.InventoryService.AddToBag(player, relic)
	updatePity(player, node.zone, relic.rarity)
	LootService.OnRelicFound(player, relic, node.zone)

	local zoneIndex = node.zone
	nodes[part] = nil
	part:Destroy()
	task.delay(rng:NextNumber(15, 30), function()
		spawnNode(zoneIndex)
	end)
	return true
end

-- Visible node (UI/Visual Overhaul Plan, Phase 2): a sand mound with a glinting relic edge
-- poking out, plus sparkles. Every node looks the same, so the look gives away nothing
-- about the server-side roll; sonar reveals rarity.
local function decorateNode(part: BasePart, zoneIndex: number)
	local glint = nodeZoneColor(zoneIndex)
	local cf = part.CFrame
	Build.Part({
		Name = "Mound",
		Size = Vector3.new(3.4, 1.1, 3.0),
		CFrame = cf * CFrame.new(0, -0.7, 0),
		Color = Color3.fromRGB(150, 135, 105):Lerp(glint, 0.15),
		Material = Enum.Material.Sand,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Children = { Build.Instance("SpecialMesh", { MeshType = Enum.MeshType.Sphere }) },
		Parent = part,
	})
	Build.Part({
		Name = "Edge",
		Size = Vector3.new(1.5, 1.1, 0.35),
		CFrame = cf * CFrame.new(-0.2, 0.05, 0.1) * CFrame.Angles(math.rad(-15), 0, math.rad(22)),
		Color = Color3.fromRGB(230, 190, 90),
		Material = Enum.Material.Foil,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = part,
	})
	Build.Part({
		Name = "Gem",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.55,
		CFrame = cf * CFrame.new(0.55, 0.15, 0.35),
		Color = glint,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = part,
	})
	local attach = Build.Instance("Attachment", { Name = "SparkleAttachment", Position = Vector3.new(0, 0.4, 0), Parent = part })
	Build.Instance("ParticleEmitter", {
		Name = "Sparkles",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(glint),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 6,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Parent = attach,
	})
end

spawnNode = function(zoneIndex: number)
	local pos = services.WorldService.RandomPointInZone(zoneIndex, rng)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local part = Build.Part({
		Name = "Node",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.2,
		CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0),
		Color = nodeZoneColor(zoneIndex),
		Material = Enum.Material.Neon,
		Transparency = 1, -- invisible hitbox; the visible "buried relic" is decoration below
		CanCollide = false,
		Parent = nodeFolder,
	})
	part:SetAttribute("Zone", zoneIndex)
	decorateNode(part, zoneIndex)
	Build.Instance("PointLight", { Range = 14, Brightness = 2, Color = part.Color, Parent = part })
	local prompt = Build.Prompt(part, "Salvage", "Glinting relic", Formulas.SalvageSeconds({}), "Salvage")
	prompt.MaxActivationDistance = MAX_SALVAGE_DISTANCE
	local node = { zone = zoneIndex, pos = pos, preRolls = {}, holdStart = {}, taken = false }
	nodes[part] = node
	prompt.PromptButtonHoldBegan:Connect(function(player)
		node.holdStart[player] = os.clock()
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		task.delay(0.1, function()
			node.holdStart[player] = nil
		end)
	end)
	prompt.Triggered:Connect(function(player)
		salvage(player, part)
	end)
end

function LootService.NodesNear(position: Vector3, range: number)
	local out = {}
	for part, node in nodes do
		if not node.taken and (part.Position - position).Magnitude <= range then
			table.insert(out, { part = part, node = node })
		end
	end
	return out
end

local function onSonar(player: Player)
	if not sonarLimiter:Check(player) then
		return
	end
	local data = services.DataService.GetData(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not data or not hrp then
		return
	end
	local now = os.clock()
	if (lastSonar[player] or 0) + Formulas.SonarCooldown(data) > now then
		return
	end
	lastSonar[player] = now
	services.PredatorService.AddNoise(player, 35)

	local sonarLevel = data.Upgrades.Sonar or 0
	local showRarity = sonarLevel >= 5
	local showMutation = sonarLevel >= 10 or services.MonetizationService.Owns(player, "MutationScan")
	local results = {}
	for _, entry in LootService.NodesNear(hrp.Position, Formulas.SonarRange(data)) do
		local info = { Position = entry.part.Position }
		if showRarity or showMutation then
			local roll = getPreRoll(player, entry.node)
			if showRarity then
				info.Rarity = roll.rarity
			end
			if showMutation then
				info.Mutations = roll.mutations
			end
		end
		table.insert(results, info)
		if #results >= 40 then
			break
		end
	end
	Net.SonarResult:FireClient(player, results, Formulas.SonarRange(data))
	-- Dive Party: share ping positions (not previews) with nearby members (§14)
	local party = services.SocialService.GetParty(player)
	if party then
		local shared = {}
		for _, info in results do
			table.insert(shared, { Position = info.Position })
		end
		for _, member in party do
			local mhrp = member ~= player and member.Character and member.Character:FindFirstChild("HumanoidRootPart")
			if mhrp and (mhrp.Position - hrp.Position).Magnitude < 300 then
				Net.SonarResult:FireClient(member, shared, Formulas.SonarRange(data), player.DisplayName)
			end
		end
	end
end

function LootService.Start()
	nodeFolder = services.WorldService.Root():FindFirstChild("Nodes")
	for _, zone in Zones.List do
		for _ = 1, zone.NodeCount do
			spawnNode(zone.Index)
		end
	end

	Net.UseSonar.OnServerEvent:Connect(onSonar)

	-- Auto-Salvage Drone pass (§15.2): Common/Uncommon within 20 studs, every 2s
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if services.MonetizationService.Owns(player, "Drone") then
					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp and hrp.Position.Y < 0 and not services.InventoryService.BagFull(player) then
						for _, entry in LootService.NodesNear(hrp.Position, 20) do
							local roll = getPreRoll(player, entry.node)
							if Rarities.TierOf(roll.rarity) <= 2 then
								salvage(player, entry.part, true)
								break
							end
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastSonar[p] = nil
		sonarLimiter:Remove(p)
		for _, node in nodes do
			node.preRolls[p] = nil
			node.holdStart[p] = nil
		end
	end)
end

return LootService
