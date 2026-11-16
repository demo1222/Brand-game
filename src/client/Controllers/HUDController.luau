-- HUDController (Master Plan §18.1; UI design canvas "HUD · on the dock" / "HUD · diving").
--   Top-left: coin + pearl capsules · left rail: navigation · top-right: live events
--   Top-centre (diving): depth readout with a 5-zone band · centre: alerts
--   Bottom-left: bag chip + oxygen capsule · bottom-right: round action buttons
-- Each corner cluster has its own UIScale so the HUD fits phones (≈800×360) and grows a
-- little on large screens; the rail switches to two columns on short screens.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local Zones = require(Shared.Config.Zones)
local Quests = require(Shared.Config.Quests)
local Economy = require(Shared.Config.Economy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icon = require(script.Parent.Parent.UI.Icon)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local HUDController = {}
HUDController.O2Fraction = 1
local controllers
local refs = {}
local lastZone = 0 -- zone the HUD last showed (0 = surface); a change shows zoneBanner
local zoneBanner: (number) -> ()
local scales: { UIScale } = {}
local lastCoins = nil

function HUDController.Init(c)
	controllers = c
end

local function cluster(name: string, anchor: Vector2, position: UDim2, size: UDim2): Frame
	local f = New("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		Parent = controllers.UIController.Root,
	})
	table.insert(scales, New("UIScale", { Parent = f }))
	return f
end

local function bump(gui: GuiObject)
	local sc = gui:FindFirstChild("BumpScale") :: UIScale or New("UIScale", { Name = "BumpScale", Parent = gui })
	sc.Scale = 1.15
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

------------------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------------------
local RAIL_ITEMS = {
	{ "Shop", "Shop" },
	{ "Bag", "Bag" },
	{ "Upgrades", "Upgrade" },
	{ "Codex", "Codex" },
	{ "Quests", "Quests" },
	{ "Rebirth", "Rebirth" },
	{ "Leaderboards", "Top" },
	{ "Players", "Friends" },
	{ "Settings", "Settings" },
}

-- Neon tile colours (owner reference docs/reference/hud_buttons): saturated, one per button,
-- so the rail reads as a set of glowing coloured tiles. Hotkeys show as a letter on the tile.
local RAIL_COLORS = {
	Shop = Color3.fromRGB(255, 206, 40),
	Bag = Color3.fromRGB(70, 255, 110),
	Upgrades = Color3.fromRGB(255, 140, 40),
	Codex = Color3.fromRGB(170, 90, 255),
	Quests = Color3.fromRGB(40, 170, 255),
	Rebirth = Color3.fromRGB(0, 230, 255),
	Leaderboards = Color3.fromRGB(255, 70, 150),
	Players = Color3.fromRGB(150, 255, 60),
	Settings = Color3.fromRGB(150, 175, 210),
}
local RAIL_KEYS = { Bag = "B", Upgrades = "U", Shop = "M" }
local RAIL_TILE = 62
local RAIL_CELL = Vector2.new(RAIL_TILE + 10, RAIL_TILE + 4 + math.floor(math.floor(RAIL_TILE * 0.3) * 0.55))

-- Rail button = Kit.HudTile (Figma "Abyss Salvage - Game Buttons" > NeonTile): a dark tile
-- tinted by its colour, a glowing neon border, a big icon and an outlined label. SHOP gets the
-- turning light band on its border so it stays the one to notice.
local function railButton(parent: Instance, key: string, label: string, order: number)
	local tile, face = Kit.HudTile(Icons.Get(key), label, {
		Name = key,
		Size = RAIL_TILE,
		Highlight = key == "Shop",
		Color = RAIL_COLORS[key] or T.Accent,
		Key = RAIL_KEYS[key],
		LayoutOrder = order,
		Parent = parent,
	})
	tile.Activated:Connect(function()
		controllers.UIController.Toggle(key)
	end)
	return tile, face
end

-- Action button = Kit.HudTile (same neon family as the rail), in its own colour, with its
-- hotkey letter. Hold actions (Boost, Up, Down) fire onDown on press and onUp on release.
local function roundAction(
	parent: Instance,
	iconName: string,
	label: string,
	color: Color3,
	size: number,
	pos: UDim2,
	onDown,
	onUp,
	key: string?
)
	local button, _, _, text = Kit.HudTile(iconName, label, {
		Name = label ~= "" and label or iconName,
		Size = size,
		Color = color,
		Key = key,
		AnchorPoint = Vector2.new(1, 1),
		Position = pos,
		Parent = parent,
	})
	button.MouseButton1Down:Connect(onDown)
	if onUp then
		button.MouseButton1Up:Connect(onUp)
		button.MouseLeave:Connect(onUp)
	end
	return button, text
end

------------------------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------------------------
local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local v = cam.ViewportSize
	local s = math.clamp(math.min(v.Y / 720, v.X / 1280), 0.6, 1.1)
	for _, sc in scales do
		sc.Scale = s
	end
	-- The rail sits between the currency capsules and the bottom-left cluster; pick the fewest
	-- columns that fit that gap at the current scale, so it never overflows.
	if refs.railGrid then
		local railTop = 16 + 104 * s + 12
		local bottomTop = v.Y - 20 - 150 * s
		local available = (bottomTop - railTop - 8) / s
		local n = #RAIL_ITEMS
		local cols = 3
		for c = 1, 3 do
			local rows = math.ceil(n / c)
			if rows * RAIL_CELL.Y + (rows - 1) * 6 <= available then
				cols = c
				break
			end
		end
		refs.railGrid.FillDirectionMaxCells = cols
		refs.rail.Size = UDim2.fromOffset(cols * RAIL_CELL.X + (cols - 1) * 6, 0)
		refs.railCluster.Position = UDim2.fromOffset(20, railTop)
	end
end

local function build()
	-- Currencies (top-left)
	local top = cluster("Currencies", Vector2.new(0, 0), UDim2.fromOffset(20, 16), UDim2.fromOffset(280, 110))
	-- Readouts in the reference style: a big glossy icon and a big outlined, gradient-painted
	-- number, no panel behind them (Kit.Readout)
	local _, coinIcon, coinValue = Kit.Readout(Icons.Get("Coins"), Kit.ReadoutColors.Coins, {
		Name = "Coins",
		TextSize = 34,
		IconSize = 48,
		Parent = top,
	})
	refs.coinIcon = coinIcon
	refs.coins = coinValue
	refs.income = Kit.Title({
		Text = "+0 / s",
		TextSize = 16,
		Position = UDim2.fromOffset(58, 42),
		Size = UDim2.fromOffset(200, 18),
		TextWrapped = false,
		Parent = top,
	})
	Kit.ReadoutPaint(refs.income, Kit.ReadoutColors.Good)
	local _, _, pearlValue = Kit.Readout(Icons.Get("Pearls"), Kit.ReadoutColors.Pearls, {
		Name = "Pearls",
		TextSize = 28,
		IconSize = 40,
		Position = UDim2.fromOffset(4, 64),
		Parent = top,
	})
	refs.pearls = pearlValue

	-- Navigation rail (left)
	local railCluster = cluster("Rail", Vector2.new(0, 0), UDim2.fromOffset(20, 136), UDim2.fromOffset(200, 600))
	refs.railCluster = railCluster
	refs.rail = New(
		"Frame",
		{
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(60, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = railCluster,
		}
	)
	refs.railGrid = Kit.Grid(RAIL_CELL, 6)
	refs.railGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	refs.railGrid.Parent = refs.rail
	for i, item in RAIL_ITEMS do
		local button = railButton(refs.rail, item[1], item[2], i)
		if item[1] == "Quests" then
			refs.questButton = button -- its red badge shows "!" when something can be claimed
		end
	end

	-- Live events (top-right)
	local eventsCluster = cluster("Events", Vector2.new(1, 0), UDim2.new(1, -20, 0, 16), UDim2.fromOffset(280, 240))
	refs.events = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = eventsCluster })
	Kit.List(8, false, Enum.HorizontalAlignment.Right).Parent = refs.events

	-- Depth readout (top-centre, diving only)
	local depthCluster = cluster("Depth", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 14), UDim2.fromOffset(420, 80))
	refs.depth = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = depthCluster }
	)
	local readout = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = refs.depth }, {
		Kit.List(8, true, Enum.HorizontalAlignment.Center),
	})
	readout:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.depthValue = Kit.Title({
		Text = "0",
		TextSize = 40,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 42),
		TextWrapped = false,
		LayoutOrder = 1,
		TextStrokeTransparency = 0.7,
		Parent = readout,
	})
	Kit.Title({
		Text = "m",
		TextSize = 18,
		TextColor3 = T.Muted,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = readout,
	})
	refs.depthZone = Kit.Label({
		Text = "",
		Font = T.Bold,
		TextSize = 13,
		TextColor3 = Kit.Lighten(T.Accent, 0.4),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextWrapped = false,
		LayoutOrder = 3,
		TextStrokeTransparency = 0.7,
		Parent = readout,
	})
	-- (the 5-zone band under the depth was removed at the owner's request: entering a new zone
	-- now shows a big banner instead, zoneBanner below)

	-- Bag chip + oxygen capsule (bottom-left)
	local bottom = cluster("Bottom", Vector2.new(0, 1), UDim2.new(0, 20, 1, -20), UDim2.fromOffset(380, 150))
	refs.bagChip = New("Frame", {
		Name = "BagReadout",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = bottom,
	}, { Kit.List(8, true) })
	refs.bagChip:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	local _, bagIcon, bagValue = Kit.Readout(Icons.Get("Bag"), Kit.ReadoutColors.White, {
		Name = "Bag",
		TextSize = 24,
		IconSize = 38,
		LayoutOrder = 1,
		Parent = refs.bagChip,
	})
	refs.bagIcon = bagIcon
	refs.bag = bagValue
	refs.bagHint = Kit.Title({
		Text = "",
		TextSize = 15,
		TextColor3 = T.Gold,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		TextWrapped = false,
		LayoutOrder = 3,
		Parent = refs.bagChip,
	})

	refs.o2Cap = New("Frame", {
		Name = "Oxygen",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 98),
		Size = UDim2.fromOffset(340, 48),
		Parent = bottom,
	})
	local o2Slot = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 3,
		Parent = refs.o2Cap,
	})
	refs.o2Icon = Icon.new(Icons.Get("Oxygen"), 56, T.Accent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
		Parent = o2Slot,
	})
	local track = New("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(22, 28, 40),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.new(1, -40, 0, 30),
		ClipsDescendants = false,
		Parent = refs.o2Cap,
	}, { Kit.Corner(12) })
	refs.o2Stroke = Kit.Stroke(T.Outline, 3, 0)
	refs.o2Stroke.Parent = track
	refs.o2Fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = T.Accent,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ZIndex = 2,
		Parent = track,
	}, {
		Kit.Corner(9),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(220, 220, 220)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
			}),
		}),
	})
	Kit.ShineStrip(refs.o2Fill, 0.55).ZIndex = 3
	refs.o2Text = Kit.Title({
		Text = "60s",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextWrapped = false,
		ZIndex = 4,
		Parent = track,
	})
	refs.quickRefill = Kit.Button("Refill air · 25 R$", T.Bad, function()
		Net.RequestPurchase:FireServer("Product", "OxygenRefill")
	end, {
		Size = UDim2.fromOffset(200, 44),
		Position = UDim2.fromOffset(0, 6),
		Visible = false,
		Icon = "oxygen",
		Parent = bottom,
	})

	-- Action buttons (bottom-right)
	local actions = cluster("Actions", Vector2.new(1, 1), UDim2.new(1, -24, 1, -24), UDim2.fromOffset(260, 210))
	local S = controllers.SwimController
	roundAction(actions, Icons.Get("Boost"), "Boost", Color3.fromRGB(70, 255, 110), 78, UDim2.new(1, 0, 1, 0), function()
		S.SetBoost(true)
	end, function()
		S.SetBoost(false)
	end)
	roundAction(actions, Icons.Get("Sonar"), "Sonar", Color3.fromRGB(40, 170, 255), 64, UDim2.new(1, -94, 1, 0), function()
		controllers.SonarController.Ping()
	end, nil, "Q")
	-- the flare count sits on the tile's red badge
	refs.flareButton = roundAction(
		actions,
		Icons.Get("Flare"),
		"Flare",
		Color3.fromRGB(255, 140, 40),
		58,
		UDim2.new(1, -10, 1, -100),
		function()
			Net.UseFlare:FireServer()
		end,
		nil,
		"G"
	)
	roundAction(
		actions,
		Icons.Get("Surface"),
		"Home",
		Color3.fromRGB(0, 230, 255),
		58,
		UDim2.new(1, -94, 1, -100),
		function()
			Net.RequestInstantSurface:FireServer()
		end,
		nil,
		"R"
	)
	refs.upButton = roundAction(
		actions,
		Icons.Get("Up"),
		"",
		Color3.fromRGB(150, 175, 210),
		54,
		UDim2.new(1, -176, 1, -76),
		function()
			S.SetVertical(1)
		end,
		function()
			S.SetVertical(0)
		end
	)
	refs.downButton = roundAction(
		actions,
		Icons.Get("Down"),
		"",
		Color3.fromRGB(150, 175, 210),
		54,
		UDim2.new(1, -176, 1, -4),
		function()
			S.SetVertical(-1)
		end,
		function()
			S.SetVertical(0)
		end
	)
	refs.upButton.Visible = false
	refs.downButton.Visible = false

	-- Alerts (centre)
	local function alertPill(name: string, color: Color3, anchor: Vector2, pos: UDim2)
		local f = New("Frame", {
			Name = name,
			BackgroundColor3 = Kit.Darken(color, 0.78),
			BackgroundTransparency = 0.1,
			AnchorPoint = anchor,
			Position = pos,
			Size = UDim2.fromOffset(0, 44),
			AutomaticSize = Enum.AutomaticSize.X,
			Visible = false,
			Parent = controllers.UIController.Root,
		}, {
			Kit.Round(),
			Kit.Stroke(color, 1, 0),
			New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 18) }),
			Kit.List(10, true),
		})
		Icon.new("alert", 22, Kit.Lighten(color, 0.3), { LayoutOrder = 1, Parent = f })
		local label = Kit.Title({
			Text = "",
			TextSize = 17,
			TextColor3 = Kit.Lighten(color, 0.65),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 44),
			TextWrapped = false,
			LayoutOrder = 2,
			Parent = f,
		})
		return f, label
	end
	refs.alert, refs.alertText = alertPill("Alert", T.Bad, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 150))
	refs.carry, refs.carryText = alertPill("Carry", T.Gold, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -170))
	refs.predator, refs.predatorText = alertPill("Predator", T.Bad, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 104))

	updateScale()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

------------------------------------------------------------------------------------------
-- Public hooks
------------------------------------------------------------------------------------------
-- Screen position of the coin icon (FXController flies coins here)
function HUDController.CoinTarget(): Vector2?
	local b = refs.coinIcon
	if not b then
		return nil
	end
	return b.AbsolutePosition + b.AbsoluteSize / 2
end

function HUDController.BumpCoins()
	if refs.coinIcon then
		bump(refs.coinIcon)
	end
end

------------------------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------------------------
local function questDef(id: string)
	for _, list in { Quests.Daily, Quests.Weekly } do
		for _, q in list do
			if q.Id == id then
				return q
			end
		end
	end
	return nil
end

-- Red dot on QUESTS when something can be claimed
local function refreshQuestDot()
	local S = controllers.State
	local claimable = (S.Get("LastDailyClaimDay") or 0) ~= os.time() // 86400
	local q = S.Get("Quests") or {}
	for _, list in { q.Daily or {}, q.Weekly or {} } do
		for _, entry in list do
			local def = questDef(entry.Id)
			if def and not entry.Claimed and entry.Progress >= def.Goal then
				claimable = true
			end
		end
	end
	local tp = S.Get("TidePass")
	if tp then
		local tier = tp.XP // Economy.TidePass.XpPerTier
		for t = 1, math.min(tier, Economy.TidePass.Tiers) do
			if not (tp.ClaimedFree or {})[tostring(t)] then
				claimable = true
				break
			end
		end
	end
	Kit.HudTileBadge(refs.questButton, if claimable then "!" else nil)
end

local function refreshCurrencies(keys)
	local S = controllers.State
	local coins = S.Get("Coins") or 0
	refs.coins.Text = NumberFormat.short(coins)
	if lastCoins and coins > lastCoins then
		bump(refs.coinIcon)
	end
	lastCoins = coins
	refs.pearls.Text = NumberFormat.commas(S.Get("Pearls") or 0)
	refs.income.Text = `+{NumberFormat.short(S.Get("IncomePerSecond") or 0)} / s`
	local bag = S.Get("Bag") or {}
	local size = S.Derived("BagSize") or 3
	local full = #bag >= size
	refs.bag.Text = `{#bag} / {size}`
	local diving = controllers.SwimController.IsSwimming()
	refs.bagHint.Text = if full then "Bag full" elseif #bag > 0 and diving then "Swim home to secure" else ""
	local chipColor = if full then T.Bad elseif #bag > 0 then T.Gold else T.Accent
	Kit.ReadoutPaint(
		refs.bag,
		if full then Kit.ReadoutColors.Bad elseif #bag > 0 then Kit.ReadoutColors.Coins else Kit.ReadoutColors.White
	)
	refs.bagHint.TextColor3 = chipColor
	if refs.flareButton then
		Kit.HudTileBadge(refs.flareButton, S.Get("Flares") or 0)
	end
	if not keys or keys.Quests or keys.TidePass or keys.LastDailyClaimDay then
		refreshQuestDot()
	end
end

local function onStatus(status)
	local frac = status.O2 / math.max(status.Max, 1)
	HUDController.O2Fraction = frac
	local color = if frac < 0.25 then T.Bad elseif frac < 0.5 then T.Gold else T.Accent
	refs.o2Fill.Size = UDim2.new(math.clamp(frac, 0, 1), -6, 1, -6)
	refs.o2Fill.Visible = frac > 0.005
	refs.o2Fill.BackgroundColor3 = Kit.ButtonFill(color)
	refs.o2Text.Text = `{math.floor(status.O2)}s`
	local critical = frac < 0.25 and status.Zone > 0
	-- the outline flashes red when air is critical
	refs.o2Stroke.Color = if critical and (os.clock() * 4) % 2 < 1 then Kit.ButtonFill(T.Bad) else T.Outline
	refs.o2Stroke.Transparency = 0
	refs.quickRefill.Visible = frac < 0.15 and status.Zone > 0 and not controllers.State.Owns("DoubleOxygen")

	local diving = status.Zone > 0
	refs.upButton.Visible = diving
	refs.downButton.Visible = diving
	refs.depth.Visible = diving
	if diving then
		local zone = Zones.List[status.Zone]
		refs.depthValue.Text = tostring(math.floor(status.Depth))
		refs.depthZone.Text = if status.Pressure then "PRESSURE! UPGRADE YOUR SUIT" else string.upper(zone.Name)
		refs.depthZone.TextColor3 = if status.Pressure then T.Bad else Kit.Lighten(zone.FogColor, 0.5)
	end
	if status.Zone ~= lastZone then
		if status.Zone > 0 then
			zoneBanner(status.Zone)
		end
		lastZone = status.Zone
	end
end

-- Big zone banner (the reference: a huge outlined biome title across the top of the screen).
-- Pops in with an overshoot, holds, then floats up and fades. Shown when you enter a zone.
local bannerToken = 0
zoneBanner = function(zoneIndex: number)
	local zone = Zones.List[zoneIndex]
	local root = controllers.UIController.Root
	if not zone or not root then
		return
	end
	bannerToken += 1
	local token = bannerToken
	local old = root:FindFirstChild("ZoneBanner")
	if old then
		old:Destroy()
	end
	local color = Kit.Lighten(zone.FogColor, 0.35)
	local holder = New("Frame", {
		Name = "ZoneBanner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(760, 120),
		ZIndex = 40,
		Parent = root,
	})
	local scale = New("UIScale", { Scale = 0.55, Parent = holder })
	-- a soft dark band behind the title so it reads over bright water
	local back = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 14, 24),
		BackgroundTransparency = 0.45,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1.2, 0, 0, 74),
		ZIndex = 40,
		Parent = holder,
	}, {
		New("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0),
				NumberSequenceKeypoint.new(0.75, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local row = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, 0, 0, 84),
		ZIndex = 41,
		Parent = holder,
	}, { Kit.List(14, true, Enum.HorizontalAlignment.Center) })
	row:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
	Icon.new(Icons.Get(zone.Id), 72, color, { LayoutOrder = 1, ZIndex = 42, Parent = row })
	local title = Kit.Title({
		Text = zone.Name,
		TextSize = 64,
		TextColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 80),
		TextWrapped = false,
		LayoutOrder = 2,
		ZIndex = 42,
		Parent = row,
	})
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), color), Parent = title })
	local sub = Kit.Title({
		Text = `{zone.MinDepth} - {zone.MaxDepth} m`,
		TextSize = 20,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.45, 44),
		Size = UDim2.fromOffset(400, 24),
		ZIndex = 42,
		Parent = holder,
	})
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if token ~= bannerToken or not holder.Parent then
			return
		end
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, info, { Position = UDim2.fromScale(0.5, 0.17) }):Play()
		TweenService:Create(back, info, { BackgroundTransparency = 1 }):Play()
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.55, function()
			if holder.Parent then
				holder:Destroy()
			end
		end)
	end)
	local _ = sub
end

local function refreshEvents(list)
	Kit.Clear(refs.events)
	for i, e in list do
		local color = e.Color or T.Accent
		local fill = Kit.Darken(Kit.ButtonFill(color), 0.15)
		local card = New("Frame", {
			Name = "Event",
			BackgroundColor3 = fill,
			Size = UDim2.fromOffset(280, 56),
			LayoutOrder = i,
			Parent = refs.events,
		}, {
			Kit.Corner(14),
			Kit.Stroke(T.Outline, 3, 0),
			New("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 160, 170)),
			}),
		})
		Kit.ShineStrip(card, 0.7)
		local slot = New("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -6, 0.5, 0),
			Size = UDim2.fromOffset(52, 52),
			ZIndex = 3,
			Parent = card,
		})
		Icon.new(Icons.Get("Event"), 60, Color3.new(1, 1, 1), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 3,
			Parent = slot,
		})
		Kit.Title({
			Text = e.Name,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(52, 6),
			Size = UDim2.new(1, -140, 0, 22),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = card,
		})
		Kit.Title({
			Text = e.Desc,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(230, 236, 248),
			Position = UDim2.fromOffset(52, 30),
			Size = UDim2.new(1, -140, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			ZIndex = 3,
			Parent = card,
		})
		Kit.Pill(NumberFormat.time(e.Remaining), Color3.fromRGB(26, 30, 42), {
			Icon = "clock",
			TextSize = 14,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(0, 28),
			ZIndex = 3,
			Parent = card,
		})
	end
end

function HUDController.Start()
	build()
	controllers.State.Changed:Connect(refreshCurrencies)
	Net.DiveStatus.OnClientEvent:Connect(onStatus)
	Net.EventsChanged.OnClientEvent:Connect(refreshEvents)

	local alertToken = 0
	local function alert(text: string, seconds: number)
		alertToken += 1
		local my = alertToken
		refs.alertText.Text = text
		refs.alert.Visible = true
		Kit.Pop(refs.alert)
		task.delay(seconds, function()
			if alertToken == my then
				refs.alert.Visible = false
			end
		end)
	end
	Net.Intruder.OnClientEvent:Connect(function(info)
		if info.Stealing then
			alert(`{info.Name} is stealing your {info.Stealing}! Tag them!`, 6)
		else
			alert(`{info.Name} entered your dock`, 3)
		end
	end)
	Net.CarryChanged.OnClientEvent:Connect(function(info)
		if info then
			refs.carryText.Text = `Stolen from {info.Owner}: get to YOUR dock!`
			refs.carry.Visible = true
			Kit.Pop(refs.carry)
		else
			refs.carry.Visible = false
		end
	end)
	Net.PredatorHint.OnClientEvent:Connect(function(hint)
		local lowScare = (controllers.State.Get("Settings") or {}).LowScare
		if hint.State == "WindUp" and hint.Guardian then
			-- a zone guardian is about to lunge (GuardianService); hide the banner shortly after
			refs.predatorText.Text = if lowScare then `{hint.Guardian} lunging: dodge!` else `{string.upper(hint.Guardian)} LUNGING. DODGE!`
			refs.predator.Visible = true
			task.delay(1.6, function()
				if refs.predatorText.Text:find(string.upper(hint.Guardian), 1, true) or refs.predatorText.Text:find(hint.Guardian, 1, true) then
					refs.predator.Visible = false
				end
			end)
		elseif hint.State == "WindUp" then
			refs.predatorText.Text = if lowScare then "Leviathan lunging: turn!" else "IT'S LUNGING. TURN NOW!"
			refs.predator.Visible = true
		elseif hint.Distance and hint.Distance < 120 then
			refs.predatorText.Text = if hint.State == "Hunt"
				then "The Leviathan is hunting you!"
				else "Something huge is nearby…"
			refs.predator.Visible = true
		else
			refs.predator.Visible = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Q then
			controllers.SonarController.Ping()
		elseif k == Enum.KeyCode.G then
			Net.UseFlare:FireServer()
		elseif k == Enum.KeyCode.R then
			Net.RequestInstantSurface:FireServer()
		elseif k == Enum.KeyCode.B then
			controllers.UIController.Toggle("Bag")
		elseif k == Enum.KeyCode.U then
			controllers.UIController.Toggle("Upgrades")
		elseif k == Enum.KeyCode.M then
			controllers.UIController.Toggle("Shop")
		end
	end)
	player.CharacterAdded:Connect(function()
		refs.predator.Visible = false
		refs.carry.Visible = false
	end)
end

return HUDController
