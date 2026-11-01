-- HUDController (Master Plan §18.1, UI/Visual Overhaul Plan): currency pills, menu tiles,
-- depth/zone meter, oxygen bar, bag chip, round mobile action buttons, events list,
-- intruder/carry/predator alerts and the low-oxygen quick buy.
-- Each corner cluster carries its own UIScale so the HUD fits phones (≈800×360) and scales
-- up a little on large screens.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local Zones = require(Shared.Config.Zones)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local HUDController = {}
HUDController.O2Fraction = 1
local controllers
local refs = {}
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

local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local v = cam.ViewportSize
	local s = math.clamp(math.min(v.Y / 700, v.X / 1100), 0.55, 1.1)
	for _, sc in scales do
		sc.Scale = s
	end
end

local function bump(gui: GuiObject)
	local sc = gui:FindFirstChild("BumpScale") :: UIScale or New("UIScale", { Name = "BumpScale", Parent = gui })
	sc.Scale = 1.18
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Currency pill: badge overlapping the left edge, big value, optional sub-line
local function currencyPill(parent: Instance, icon: string, color: Color3, size: Vector2, y: number)
	local pill = New("Frame", {
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.12,
		Position = UDim2.fromOffset(size.Y * 0.5, y),
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = parent,
	}, { Kit.Round(), Kit.Stroke(color, 2, 0.15), Kit.Sheen(0.3) })
	local badge = Kit.IconBadge(icon, color, size.Y + 6, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		ZIndex = 2,
		Parent = pill,
	})
	return pill, badge
end

local function menuTile(parent: Instance, key: string, label: string, order: number)
	local color = Icons.Colors[key] or T.PanelLight
	local tile = Kit.Button("", Kit.Darken(color, 0.15), function()
		controllers.UIController.Toggle(key)
	end, { Size = UDim2.fromOffset(60, 60), LayoutOrder = order, Parent = parent })
	tile:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 16)
	New("TextLabel", {
		BackgroundTransparency = 1,
		Text = Icons.Get(key),
		TextScaled = true,
		Font = T.Bold,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 5),
		Size = UDim2.fromOffset(34, 34),
		Parent = tile,
	})
	Kit.Title({
		Text = label,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 16),
		TextWrapped = false,
		Parent = tile,
	})
	if key == "Shop" then
		Kit.Shine(tile, 2.5)
	end
	return tile
end

local function roundAction(
	parent: Instance,
	icon: string,
	keyHint: string,
	color: Color3,
	size: number,
	pos: UDim2,
	onDown,
	onUp
)
	local b = Kit.Button("", color, nil, { Size = UDim2.fromOffset(size, size), Position = pos, Parent = parent })
	b:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	New("TextLabel", {
		BackgroundTransparency = 1,
		Text = icon,
		TextScaled = true,
		Font = T.Bold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.5, 0.5),
		Parent = b,
	})
	local hint = Kit.Title({
		Text = keyHint,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 14),
		TextWrapped = false,
		Parent = b,
	})
	b.MouseButton1Down:Connect(onDown)
	if onUp then
		b.MouseButton1Up:Connect(onUp)
		b.MouseLeave:Connect(onUp)
	end
	return b, hint
end

local function alertLabel(name: string, color: Color3, anchor: Vector2, pos: UDim2, height: number)
	local l = Kit.Title({
		Name = name,
		Text = "",
		Visible = false,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = Kit.Darken(color, 0.65),
		BackgroundTransparency = 0.15,
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.new(0.8, 0, 0, height),
		Parent = controllers.UIController.Root,
	})
	l.TextColor3 = Kit.Lighten(color, 0.35)
	Kit.Round().Parent = l
	Kit.Stroke(color, 2, 0.05).Parent = l
	New("UISizeConstraint", { MaxSize = Vector2.new(560, height), Parent = l })
	New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = l })
	return l
end

local function build()
	-- Currencies (top-left)
	local top = cluster("Currencies", Vector2.new(0, 0), UDim2.fromOffset(12, 10), UDim2.fromOffset(270, 110))
	local coinPill, coinBadge = currencyPill(top, Icons.Get("Coins"), T.Gold, Vector2.new(214, 50), 4)
	refs.coinBadge = coinBadge
	refs.coins = Kit.Title({
		Text = "0",
		TextSize = 26,
		Position = UDim2.fromOffset(34, 2),
		Size = UDim2.new(1, -40, 0, 28),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = coinPill,
	})
	refs.income = Kit.Label({
		Text = "+0/s",
		Font = T.Bold,
		TextColor3 = Color3.fromRGB(120, 255, 150),
		TextSize = 13,
		Position = UDim2.fromOffset(35, 29),
		Size = UDim2.new(1, -40, 0, 16),
		TextWrapped = false,
		Parent = coinPill,
	})
	local pearlPill = currencyPill(top, Icons.Get("Pearls"), T.Pearl, Vector2.new(170, 36), 64)
	refs.pearls = Kit.Title({
		Text = "0",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(215, 235, 255),
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -34, 1, 0),
		TextWrapped = false,
		Parent = pearlPill,
	})

	-- Menu tiles (left-middle, two columns)
	local menu = cluster("Menu", Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 10), UDim2.fromOffset(128, 330))
	local grid = Kit.Grid(Vector2.new(60, 60), 6)
	grid.FillDirectionMaxCells = 2
	grid.Parent = menu
	for i, item in
		{
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
	do
		menuTile(menu, item[1], item[2], i)
	end

	-- Depth / zone meter (top-centre)
	local depthCluster =
		cluster("DepthCluster", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 8), UDim2.fromOffset(330, 54))
	refs.depth = New("Frame", {
		Name = "Depth",
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = depthCluster,
	}, { Kit.Round(), Kit.Sheen(0.3) })
	refs.depthStroke = Kit.Stroke(T.Accent, 2.5, 0.05)
	refs.depthStroke.Parent = refs.depth
	refs.depthBadgeHolder = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		Size = UDim2.fromOffset(60, 60),
		ZIndex = 2,
		Parent = refs.depth,
	})
	refs.depthValue = Kit.Title({
		Text = "0m",
		TextSize = 26,
		Position = UDim2.fromOffset(62, 2),
		Size = UDim2.new(0, 110, 1, -4),
		TextWrapped = false,
		Parent = refs.depth,
	})
	refs.depthZone = Kit.Label({
		Text = "",
		Font = T.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(0, 170, 0, 0),
		Size = UDim2.new(1, -186, 1, 0),
		TextWrapped = true,
		Parent = refs.depth,
	})
	refs.lastZoneIndex = 0

	-- Oxygen + bag (bottom-left)
	local bottom = cluster("Bottom", Vector2.new(0, 1), UDim2.new(0, 12, 1, -12), UDim2.fromOffset(330, 124))
	local o2Frame, setO2 = Kit.Bar({
		Size = UDim2.fromOffset(280, 30),
		Position = UDim2.fromOffset(30, 88),
		Text = "O₂ 100%",
		TextSize = 15,
		Parent = bottom,
	})
	refs.o2Frame, refs.setO2 = o2Frame, setO2
	Kit.IconBadge(Icons.Get("Oxygen"), T.Accent, 44, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		ZIndex = 4,
		Parent = o2Frame,
	})
	refs.bag = Kit.Pill(`{Icons.Get("Bag")} 0/3`, T.PanelLight, {
		TextSize = 16,
		Size = UDim2.fromOffset(0, 30),
		Position = UDim2.fromOffset(30, 50),
		Parent = bottom,
	})
	refs.bagStroke = Kit.Stroke(T.Accent, 2, 0.2)
	refs.bagStroke.Parent = refs.bag
	refs.quickRefill = Kit.Button(`{Icons.Get("Oxygen")} Refill O₂ · 25 R$`, T.Bad, function()
		Net.RequestPurchase:FireServer("Product", "OxygenRefill")
	end, { Size = UDim2.fromOffset(200, 42), Position = UDim2.fromOffset(30, 2), Visible = false, Parent = bottom })

	-- Action buttons (bottom-right)
	local actions = cluster("Actions", Vector2.new(1, 1), UDim2.new(1, -12, 1, -12), UDim2.fromOffset(260, 200))
	local S = controllers.SwimController
	roundAction(actions, Icons.Get("Up"), "Space", T.PanelLight, 58, UDim2.fromOffset(0, 66), function()
		S.SetVertical(1)
	end, function()
		S.SetVertical(0)
	end)
	roundAction(actions, Icons.Get("Down"), "Ctrl", T.PanelLight, 58, UDim2.fromOffset(0, 136), function()
		S.SetVertical(-1)
	end, function()
		S.SetVertical(0)
	end)
	roundAction(actions, Icons.Get("Sonar"), "Q", T.AccentDeep, 70, UDim2.fromOffset(72, 120), function()
		controllers.SonarController.Ping()
	end)
	local flare
	flare, refs.flareHint = roundAction(
		actions,
		Icons.Get("Flare"),
		"G · 3",
		Color3.fromRGB(230, 90, 40),
		60,
		UDim2.fromOffset(110, 40),
		function()
			Net.UseFlare:FireServer()
		end
	)
	refs.flare = flare
	roundAction(
		actions,
		Icons.Get("Surface"),
		"R",
		Color3.fromRGB(90, 120, 230),
		60,
		UDim2.fromOffset(190, 4),
		function()
			Net.RequestInstantSurface:FireServer()
		end
	)
	roundAction(actions, Icons.Get("Boost"), "Shift", T.Good, 84, UDim2.fromOffset(160, 100), function()
		S.SetBoost(true)
	end, function()
		S.SetBoost(false)
	end)

	-- Events list (top-right)
	local eventsCluster = cluster("Events", Vector2.new(1, 0), UDim2.new(1, -12, 0, 10), UDim2.fromOffset(250, 220))
	refs.events = New("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = eventsCluster })
	Kit.List(6, false, Enum.HorizontalAlignment.Right).Parent = refs.events

	-- Alerts (centre)
	refs.alert = alertLabel("Alert", T.Bad, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 150), 54)
	refs.carry = alertLabel("Carry", T.Gold, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -150), 42)
	refs.predator =
		alertLabel("Predator", Color3.fromRGB(255, 60, 60), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 70), 34)
	refs.predator.TextSize = 18

	updateScale()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

local function refreshCurrencies()
	local S = controllers.State
	local coins = S.Get("Coins") or 0
	refs.coins.Text = NumberFormat.short(coins)
	if lastCoins and coins > lastCoins then
		bump(refs.coinBadge)
	end
	lastCoins = coins
	refs.pearls.Text = NumberFormat.commas(S.Get("Pearls") or 0)
	refs.income.Text = `{Icons.Get("Income")} +{NumberFormat.short(S.Get("IncomePerSecond") or 0)}/s`
	local bag = S.Get("Bag") or {}
	local size = S.Derived("BagSize") or 3
	local full = #bag >= size
	refs.bag.Text = `{Icons.Get("Bag")} {#bag}/{size}{if full then "  FULL" else ""}`
	refs.bag.BackgroundColor3 = if full then Kit.Darken(T.Bad, 0.2) else T.PanelLight
	refs.bag.TextColor3 = Color3.new(1, 1, 1)
	refs.bagStroke.Color = if full then T.Bad else T.Accent
	refs.flareHint.Text = `G · {S.Get("Flares") or 0}`
end

local function onStatus(status)
	local frac = status.O2 / math.max(status.Max, 1)
	HUDController.O2Fraction = frac
	local color = if frac < 0.25 then T.Bad elseif frac < 0.5 then T.Gold else T.Accent
	refs.setO2(frac, color, `O₂ {math.floor(frac * 100)}%  ·  {math.floor(status.O2)}s`)
	if frac < 0.25 and status.Zone > 0 then
		refs.o2Frame.BackgroundColor3 = if (os.clock() * 4) % 2 < 1
			then Color3.fromRGB(90, 0, 0)
			else Color3.fromRGB(6, 12, 22)
	else
		refs.o2Frame.BackgroundColor3 = Color3.fromRGB(6, 12, 22)
	end
	refs.quickRefill.Visible = frac < 0.15 and status.Zone > 0 and not controllers.State.Owns("DoubleOxygen")
	if status.Zone > 0 then
		local zone = Zones.List[status.Zone]
		refs.depth.Visible = true
		local zoneColor = Kit.Lighten(zone.FogColor, 0.35)
		if refs.lastZoneIndex ~= status.Zone then
			refs.lastZoneIndex = status.Zone
			Kit.Clear(refs.depthBadgeHolder)
			Kit.IconBadge(Icons.Get(zone.Id), zoneColor, 56, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 3,
				Parent = refs.depthBadgeHolder,
			})
			Kit.Pop(refs.depth)
		end
		refs.depthValue.Text = `{math.floor(status.Depth)}m`
		refs.depthZone.Text = if status.Pressure then "⚠ PRESSURE!\nUpgrade your suit" else zone.Name
		refs.depthZone.TextColor3 = if status.Pressure then T.Bad else zoneColor
		refs.depthStroke.Color = if status.Pressure then T.Bad else zoneColor
	else
		refs.depth.Visible = false
		refs.lastZoneIndex = 0
	end
end

local function refreshEvents(list)
	Kit.Clear(refs.events)
	for i, e in list do
		local color = e.Color or T.Accent
		local card = New("Frame", {
			BackgroundColor3 = T.PanelDark,
			BackgroundTransparency = 0.15,
			Size = UDim2.fromOffset(240, 44),
			LayoutOrder = i,
			Parent = refs.events,
		}, { Kit.Corner(12), Kit.Stroke(color, 2, 0.1) })
		Kit.IconBadge(Icons.Get("Event"), color, 32, { Position = UDim2.fromOffset(6, 6), Parent = card })
		Kit.Title({
			Text = `{e.Name}  ·  {NumberFormat.time(e.Remaining)}`,
			TextSize = 14,
			TextColor3 = Kit.Lighten(color, 0.3),
			Position = UDim2.fromOffset(44, 3),
			Size = UDim2.new(1, -50, 0, 18),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		Kit.Label({
			Text = e.Desc,
			TextSize = 11,
			TextColor3 = T.Muted,
			Position = UDim2.fromOffset(44, 21),
			Size = UDim2.new(1, -50, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
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
		refs.alert.Text = text
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
			alert(`🚨 {info.Name} is STEALING your {info.Stealing}! Tag them!`, 6)
		else
			alert(`🔔 {info.Name} entered your dock`, 3)
		end
	end)
	Net.CarryChanged.OnClientEvent:Connect(function(info)
		if info then
			refs.carry.Text = `💰 Stolen from {info.Owner}: get to YOUR dock!`
			refs.carry.Visible = true
			Kit.Pop(refs.carry)
		else
			refs.carry.Visible = false
		end
	end)
	Net.PredatorHint.OnClientEvent:Connect(function(hint)
		local lowScare = (controllers.State.Get("Settings") or {}).LowScare
		if hint.State == "WindUp" then
			refs.predator.Text = if lowScare then "Leviathan lunging: turn!" else "⚠ IT'S LUNGING. TURN NOW! ⚠"
			refs.predator.Visible = true
		elseif hint.Distance and hint.Distance < 120 then
			refs.predator.Text = if hint.State == "Hunt"
				then "👁 The Leviathan is hunting you!"
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
