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
local scales: { UIScale } = {}
local lastCoins = nil
local GLASS = 0.12 -- HUD panel transparency (design: rgba(11,22,38,0.88))

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

local function glass(props, strokeColor: Color3?, strokeT: number?)
	local p = { BackgroundColor3 = T.Panel, BackgroundTransparency = GLASS }
	for k, v in props do
		p[k] = v
	end
	local f = New("Frame", p)
	Kit.Stroke(strokeColor or T.Hairline, 1, strokeT or 0.65).Parent = f
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
	{ "Shop", "SHOP" },
	{ "Bag", "BAG" },
	{ "Upgrades", "UPGRADE" },
	{ "Codex", "CODEX" },
	{ "Quests", "QUESTS" },
	{ "Rebirth", "REBIRTH" },
	{ "Leaderboards", "TOP" },
	{ "Players", "FRIENDS" },
	{ "Settings", "SETTINGS" },
}

local RAIL_COLORS = Icons.Colors -- shared with the window title bands
local RAIL_CELL = Vector2.new(60, 62) -- button 60×58 + 4 px lip

-- Chunky game tile: dark face with a coloured icon (gold face for SHOP), pressable lip
local function railButton(parent: Instance, key: string, label: string, order: number)
	local isShop = key == "Shop"
	local accent = RAIL_COLORS[key] or T.Accent
	local container, face = Kit.GameButton(if isShop then T.Gold else T.PanelLight, Vector2.new(60, 58), {
		Name = key,
		LayoutOrder = order,
		Parent = parent,
	})
	Icon.new(Icons.Get(key), 26, if isShop then T.DarkText else accent, {
		Weight = 2.6,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		ZIndex = 3,
		Parent = face,
	})
	Kit.Label({
		Text = label,
		Font = T.Bold,
		TextSize = 10,
		TextColor3 = if isShop then T.DarkText else T.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, 0, 0, 12),
		TextWrapped = false,
		ZIndex = 3,
		Parent = face,
	})
	face.Activated:Connect(function()
		controllers.UIController.Toggle(key)
	end)
	return face
end

-- Round game button: solid colour, white chunky icon, pressable lip
local function roundAction(
	parent: Instance,
	iconName: string,
	label: string,
	color: Color3,
	size: number,
	pos: UDim2,
	onDown,
	onUp
)
	local container, b =
		Kit.GameButton(Kit.Darken(color, 0.12), Vector2.new(size, size), { Position = pos, Parent = parent }, true)
	local iconSize = math.floor(size * 0.4)
	local fg = Kit.TextOn(color)
	Icon.new(iconName, iconSize, fg, {
		Weight = 2.6,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, if label ~= "" then -6 else 0),
		ZIndex = 3,
		Parent = b,
	})
	local text = nil
	if label ~= "" then
		text = Kit.Label({
			Text = label,
			Font = T.Bold,
			TextSize = 10,
			TextColor3 = fg,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, iconSize / 2 + 5),
			Size = UDim2.new(1, -6, 0, 12),
			TextWrapped = false,
			ZIndex = 3,
			Parent = b,
		})
	end
	b.MouseButton1Down:Connect(onDown)
	if onUp then
		b.MouseButton1Up:Connect(onUp)
		b.MouseLeave:Connect(onUp)
	end
	return container, text
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
	local coinCap = glass({ Size = UDim2.fromOffset(220, 52), Parent = top }, T.Gold, 0.5)
	Kit.Round().Parent = coinCap
	refs.coinIcon = Icon.new("coin", 40, T.Gold, { Position = UDim2.fromOffset(6, 6), Parent = coinCap })
	refs.coins = Kit.Title({
		Text = "0",
		TextSize = 24,
		Position = UDim2.fromOffset(56, 5),
		Size = UDim2.new(1, -66, 0, 26),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = coinCap,
	})
	refs.income = Kit.Label({
		Text = "+0 / s",
		Font = T.Bold,
		TextSize = 12,
		TextColor3 = T.Good,
		Position = UDim2.fromOffset(57, 30),
		Size = UDim2.new(1, -66, 0, 14),
		TextWrapped = false,
		Parent = coinCap,
	})
	local pearlCap =
		glass({ Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(150, 40), Parent = top }, T.Pearl, 0.55)
	Kit.Round().Parent = pearlCap
	Icon.new("pearl", 30, T.Pearl, { Position = UDim2.fromOffset(5, 5), Parent = pearlCap })
	refs.pearls = Kit.Title({
		Text = "0",
		TextSize = 19,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -52, 1, 0),
		TextWrapped = false,
		Parent = pearlCap,
	})

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
		local b = railButton(refs.rail, item[1], item[2], i)
		if item[1] == "Quests" then
			refs.questDot = New("Frame", {
				BackgroundColor3 = T.Bad,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 6),
				Size = UDim2.fromOffset(10, 10),
				Visible = false,
				ZIndex = 3,
				Parent = b,
			}, { Kit.Round(), Kit.Stroke(T.Panel, 2, 0) })
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
	local band = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 10),
		Parent = refs.depth,
	})
	local bandList = Kit.List(3, true)
	bandList.Parent = band
	refs.bandSegments = {}
	for i, zone in Zones.List do
		refs.bandSegments[i] = New("Frame", {
			BackgroundColor3 = Kit.Lighten(zone.FogColor, 0.2),
			Size = UDim2.new(0.2, -3, 1, 0),
			LayoutOrder = i,
			Parent = band,
		}, { Kit.Corner(3) })
	end
	refs.bandMarker = New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(4, 20),
		ZIndex = 3,
		Parent = band,
	}, { Kit.Round() })
	local labels = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = refs.depth,
	})
	Kit.List(3, true).Parent = labels
	refs.bandLabels = {}
	for i, zone in Zones.List do
		refs.bandLabels[i] = Kit.Label({
			Text = string.upper(zone.Id),
			Font = T.Bold,
			TextSize = 10,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.7,
			Size = UDim2.new(0.2, -3, 1, 0),
			LayoutOrder = i,
			Parent = labels,
		})
	end

	-- Bag chip + oxygen capsule (bottom-left)
	local bottom = cluster("Bottom", Vector2.new(0, 1), UDim2.new(0, 20, 1, -20), UDim2.fromOffset(380, 150))
	refs.bagChip = glass({
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = bottom,
	})
	Kit.Round().Parent = refs.bagChip
	New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14), Parent = refs.bagChip })
	Kit.List(8, true).Parent = refs.bagChip
	refs.bagIcon = Icon.new("bag", 18, T.Accent, { LayoutOrder = 1, Parent = refs.bagChip })
	refs.bag = Kit.Title({
		Text = "0 / 3",
		TextSize = 16,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = refs.bagChip,
	})
	refs.bagHint = Kit.Label({
		Text = "",
		Font = T.Bold,
		TextSize = 11,
		TextColor3 = T.Gold,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
		TextWrapped = false,
		LayoutOrder = 3,
		Parent = refs.bagChip,
	})

	refs.o2Cap = glass({ Position = UDim2.fromOffset(0, 100), Size = UDim2.fromOffset(340, 44), Parent = bottom })
	Kit.Round().Parent = refs.o2Cap
	refs.o2Stroke = refs.o2Cap:FindFirstChildOfClass("UIStroke")
	refs.o2Icon = Icon.new(
		"oxygen",
		26,
		T.Accent,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = refs.o2Cap }
	)
	local track = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(6, 16, 25),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.new(1, -110, 0, 14),
		Parent = refs.o2Cap,
	}, { Kit.Round() })
	refs.o2Fill = New(
		"Frame",
		{ BackgroundColor3 = T.Accent, Size = UDim2.fromScale(1, 1), Parent = track },
		{ Kit.Round() }
	)
	refs.o2Text = Kit.Title({
		Text = "60s",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(52, 24),
		TextWrapped = false,
		Parent = refs.o2Cap,
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
	roundAction(actions, "boost", "BOOST", T.Good, 88, UDim2.new(1, -88, 1, -88), function()
		S.SetBoost(true)
	end, function()
		S.SetBoost(false)
	end)
	roundAction(actions, "sonar", "SONAR · Q", T.Accent, 72, UDim2.new(1, -176, 1, -78), function()
		controllers.SonarController.Ping()
	end)
	local _, flareText = roundAction(
		actions,
		"flare",
		"FLARE 3",
		Color3.fromRGB(245, 154, 90),
		60,
		UDim2.new(1, -74, 1, -164),
		function()
			Net.UseFlare:FireServer()
		end
	)
	refs.flareText = flareText
	roundAction(actions, "home", "HOME · R", Color3.fromRGB(143, 180, 255), 60, UDim2.new(1, -150, 1, -160), function()
		Net.RequestInstantSurface:FireServer()
	end)
	refs.upButton = roundAction(
		actions,
		"up",
		"",
		Color3.fromRGB(70, 92, 124),
		56,
		UDim2.new(1, -246, 1, -132),
		function()
			S.SetVertical(1)
		end,
		function()
			S.SetVertical(0)
		end
	)
	refs.downButton = roundAction(
		actions,
		"down",
		"",
		Color3.fromRGB(70, 92, 124),
		56,
		UDim2.new(1, -246, 1, -66),
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
	refs.questDot.Visible = claimable
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
	refs.bagChip:FindFirstChildOfClass("UIStroke").Color = chipColor
	refs.bagChip:FindFirstChildOfClass("UIStroke").Transparency = if #bag > 0 then 0.3 else 0.65
	Icon.SetColor(refs.bagIcon, chipColor)
	refs.bagHint.TextColor3 = chipColor
	if refs.flareText then
		refs.flareText.Text = `FLARE {S.Get("Flares") or 0}`
	end
	if not keys or keys.Quests or keys.TidePass or keys.LastDailyClaimDay then
		refreshQuestDot()
	end
end

local function onStatus(status)
	local frac = status.O2 / math.max(status.Max, 1)
	HUDController.O2Fraction = frac
	local color = if frac < 0.25 then T.Bad elseif frac < 0.5 then T.Gold else T.Accent
	refs.o2Fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	refs.o2Fill.Visible = frac > 0.005
	refs.o2Fill.BackgroundColor3 = color
	refs.o2Text.Text = `{math.floor(status.O2)}s`
	Icon.SetColor(refs.o2Icon, color)
	local critical = frac < 0.25 and status.Zone > 0
	refs.o2Stroke.Color = color
	refs.o2Stroke.Transparency = if critical and (os.clock() * 4) % 2 < 1 then 0 else if frac < 0.5 then 0.35 else 0.65
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
		local within = math.clamp((status.Depth - zone.MinDepth) / (zone.MaxDepth - zone.MinDepth), 0, 1)
		refs.bandMarker.Position = UDim2.new(((status.Zone - 1) + within) / #Zones.List, 0, 0.5, 0)
		for i, l in refs.bandLabels do
			l.TextColor3 = if i == status.Zone then T.Text else T.Muted
		end
	end
end

local function refreshEvents(list)
	Kit.Clear(refs.events)
	for i, e in list do
		local color = e.Color or T.Accent
		local card = glass({ Size = UDim2.fromOffset(280, 52), LayoutOrder = i, Parent = refs.events }, color, 0.55)
		Kit.Corner(14).Parent = card
		Icon.new(
			"event",
			26,
			color,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Parent = card }
		)
		Kit.Title({
			Text = e.Name,
			TextSize = 15,
			Position = UDim2.fromOffset(48, 8),
			Size = UDim2.new(1, -130, 0, 18),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		Kit.Label({
			Text = e.Desc,
			TextSize = 11,
			TextColor3 = T.Muted,
			Position = UDim2.fromOffset(48, 27),
			Size = UDim2.new(1, -130, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Parent = card,
		})
		Kit.Title({
			Text = NumberFormat.time(e.Remaining),
			TextSize = 14,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(76, 20),
			TextWrapped = false,
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
		if hint.State == "WindUp" then
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
