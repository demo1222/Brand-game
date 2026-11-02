-- MenuController (Master Plan §18.2): Bag/Dock Manager, Upgrades, Codex, Quests & Tide Pass,
-- Rebirth, Leaderboards, Players (trade/party), Trade window and Settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Quests = require(Shared.Config.Quests)
local Economy = require(Shared.Config.Economy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)
local RelicView = require(script.Parent.Parent.UI.RelicView)
local RelicCard = require(script.Parent.Parent.UI.RelicCard)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer
local MenuController = {}
local controllers
local S -- State
local leaderboardData = {}
local tradeState = nil
local tradeSelection: { [string]: boolean } = {}
local codexZone = 1

function MenuController.Init(c)
	controllers = c
	S = c.State
end

local function row(parent: Instance, order: number, height: number?)
	return Kit.Card({
		Size = UDim2.new(1, -8, 0, height or 56),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function header(parent: Instance, order: number, text: string, color: Color3?)
	return Kit.Header(parent, order, text, color)
end

local function scrollBody(body: Frame, top: number?)
	local scroll =
		Kit.Scroll({ Position = UDim2.fromOffset(0, top or 0), Size = UDim2.new(1, 0, 1, -(top or 0)), Parent = body })
	Kit.List(6).Parent = scroll
	New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = scroll })
	return scroll
end

local function firstFreeStand(): number?
	local stands = S.Get("Stands") or {}
	for i = 1, S.Derived("StandCount") or 6 do
		if not stands[tostring(i)] then
			return i
		end
	end
	return nil
end

local function coinText(n: number): string
	return NumberFormat.short(n)
end

-- Uniform grid whose columns stretch to fill the width (no dead strip on the right)
local function fitGrid(scroll: ScrollingFrame, grid: UIGridLayout, minW: number, h: number, pad: number)
	local function fit()
		local w = scroll.AbsoluteSize.X - 14 -- padding + scrollbar
		if w <= 0 then
			return
		end
		local cols = math.max(1, math.floor((w + pad) / (minW + pad)))
		grid.CellSize = UDim2.fromOffset(math.floor((w - pad * (cols - 1)) / cols), h)
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
end

------------------------------------------------------------------------------------------
-- Bag / Dock Manager: card grid + detail panel
------------------------------------------------------------------------------------------
local realizeVisibleCards: () -> ()
local bag = {
	tab = nil :: string?,
	sort = "Value",
	selected = nil :: string?,
	sig = "",
}
local bagRefs = {}

local function bagItems(tab: string)
	local items = {}
	if tab == "Bag" then
		for _, relic in S.Get("Bag") or {} do
			table.insert(items, { relic = relic, where = "Bag", key = "B:" .. relic.uid })
		end
	elseif tab == "Storage" then
		for _, relic in S.Get("Storage") or {} do
			table.insert(items, { relic = relic, where = "Storage", key = "S:" .. relic.uid })
		end
	else
		for slot, relic in S.Get("Stands") or {} do
			table.insert(items, { relic = relic, where = "Stands", slot = slot, key = "D:" .. slot })
		end
		for slot, relic in S.Get("Vault") or {} do
			table.insert(items, { relic = relic, where = "Vault", slot = slot, key = "V:" .. slot })
		end
	end
	table.sort(items, function(a, b)
		if bag.sort == "Rarity" then
			local ta, tb = Rarities.TierOf(a.relic.rarity), Rarities.TierOf(b.relic.rarity)
			if ta ~= tb then
				return ta > tb
			end
		end
		local ca, cb = Formulas.RelicCPS(a.relic), Formulas.RelicCPS(b.relic)
		if ca ~= cb then
			return ca > cb
		end
		return a.key < b.key
	end)
	return items
end

local function bagSignature(items, mult: number): string
	local parts =
		{ bag.tab or "", bag.sort, bag.selected or "", tostring(mult), tostring(S.Derived("VaultCount") or 0) }
	for _, it in items do
		table.insert(parts, `{it.key}:{it.relic.locked and 1 or 0}:{table.concat(it.relic.mutations or {}, ",")}`)
	end
	return table.concat(parts, "|")
end

local function placeInVault(relic)
	local vault = S.Get("Vault") or {}
	for i = 1, S.Derived("VaultCount") or 0 do
		if not vault[tostring(i)] then
			Net.RequestPlaceRelic:FireServer(relic.uid, i, true)
			return
		end
	end
	controllers.UIController.Toast("Vault slots are full.", "error")
end

local function renderDetail(item, mult: number)
	local panel = bagRefs.detail
	Kit.Clear(panel)
	if not item then
		local hint = New(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), LayoutOrder = 1, Parent = panel }
		)
		Kit.IconBadge(
			"eye",
			T.Accent,
			64,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Parent = hint }
		)
		Kit.Title({
			Text = "Tap a relic\nto inspect it",
			TextSize = 18,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 104),
			Size = UDim2.new(1, 0, 0, 48),
			Parent = hint,
		})
		return
	end
	local relic = item.relic
	local def = Relics.ById[relic.id]
	local rarity = Rarities[relic.rarity]
	local rColor = Kit.RarityColor(relic.rarity, Rarities)
	local bg, seq = RelicCard.RarityBackground(relic.rarity)

	local stage = New("Frame", {
		BackgroundColor3 = bg,
		Size = UDim2.new(1, 0, 0, 170),
		LayoutOrder = 1,
		Parent = panel,
	}, { Kit.Corner(14), New("UIGradient", { Rotation = 90, Color = seq }), Kit.Stroke(rColor, 2, 0.05) })
	Kit.Glow(stage, rColor, 170)
	RelicView.new({
		Relic = relic,
		Spin = 35,
		ZIndex = 2,
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		Parent = stage,
	})
	if rarity.Tier >= 5 then
		Kit.Shine(stage, 2.5)
	end

	Kit.Title({
		Text = (if relic.size >= 1.35 then "HUGE " else "") .. def.Name,
		TextSize = 19,
		TextColor3 = Kit.Lighten(rColor, 0.2),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = panel,
	})
	local pills = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = panel,
	})
	local pl = Kit.List(4, true, Enum.HorizontalAlignment.Center)
	pl.Wraps = true
	pl.Parent = pills
	Kit.Pill(`{rarity.Icon} {relic.rarity}`, rColor, { LayoutOrder = 1, Parent = pills })
	for i, m in relic.mutations do
		local md = Mutations.ById[m]
		if md then
			Kit.Pill(`{m} x{md.Mult}`, md.Color, { LayoutOrder = 1 + i, Parent = pills })
		end
	end

	local stats = Kit.Card(
		{ Size = UDim2.new(1, 0, 0, 62), LayoutOrder = 4, Parent = panel },
		{ Kit.Padding(6), Kit.List(2) }
	)
	local cps = Formulas.RelicCPS(relic) * mult
	for i, line in
		{
			`+{NumberFormat.short(cps)} Coins/s on display`,
			`Sells for {NumberFormat.short(Formulas.SellPrice(relic, mult))}`,
			`Size {relic.size}x · Zone {def.Zone}`,
		}
	do
		Kit.Label({
			Text = line,
			TextSize = 13,
			Font = T.Bold,
			Size = UDim2.new(1, 0, 0, 16),
			LayoutOrder = i,
			TextWrapped = false,
			Parent = stats,
		})
	end
	Kit.Label({
		Text = `"{def.Lore}"`,
		TextColor3 = T.Muted,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = panel,
	})

	local actions = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = panel,
	})
	Kit.List(6, false).Parent = actions
	-- Primary action full width, the rest in a row of small buttons (UI design)
	local secondary = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2 })
	local secGrid = Kit.Grid(Vector2.new(70, 40), 6)
	secGrid.Parent = secondary
	local primaryUsed = false
	local function act(text: string, color: Color3, fn, icon: string?)
		if not primaryUsed then
			primaryUsed = true
			Kit.Button(
				text,
				color,
				fn,
				{ Size = UDim2.new(1, 0, 0, 46), TextSize = 14, Icon = icon, LayoutOrder = 1, Parent = actions }
			)
		else
			secondary.Parent = actions
			Kit.Button(text, color, fn, { TextSize = 12, Icon = icon, Parent = secondary })
		end
	end
	if item.where == "Stands" or item.where == "Vault" then
		act("Take", T.PanelLight, function()
			bag.selected = nil
			Net.RequestPickupRelic:FireServer(tonumber(item.slot), item.where == "Vault")
		end)
		return
	end
	act("Display on dock", T.Accent, function()
		local slot = firstFreeStand()
		if slot then
			bag.selected = nil
			Net.RequestPlaceRelic:FireServer(relic.uid, slot, false)
		else
			controllers.UIController.Toast("All stands are full! Upgrade Display Slots.", "error")
			if not S.Owns("ExtraSlots") then
				controllers.OfferController.Show("ExtraSlots")
			end
		end
	end)
	if (S.Derived("VaultCount") or 0) > 0 then
		act("Vault", T.PanelLight, function()
			bag.selected = nil
			placeInVault(relic)
		end)
	end
	act(if relic.locked then "Unlock" else "Lock", T.PanelLight, function()
		Net.RequestToggleLock:FireServer(relic.uid)
	end)
	if not relic.locked then
		act("Sell", T.BadDeep, function()
			bag.selected = nil
			Net.RequestSell:FireServer(relic.uid)
		end)
	end
	if table.find(relic.mutations, "Barnacled") then
		act("Clean", Color3.fromRGB(110, 96, 74), function()
			Net.RequestCleanBarnacle:FireServer(relic.uid)
		end)
	end
end

-- Build 3D models only for Bag cards that are (nearly) on screen
realizeVisibleCards = function()
	local grid = bagRefs.grid
	if not grid or not grid.Parent then
		return
	end
	local top = grid.AbsolutePosition.Y - 160
	local bottom = grid.AbsolutePosition.Y + grid.AbsoluteSize.Y + 160
	for _, card in grid:GetChildren() do
		if card:IsA("TextButton") and not RelicCard.IsRealized(card) then
			local y = card.AbsolutePosition.Y
			if y + card.AbsoluteSize.Y >= top and y <= bottom then
				RelicCard.Realize(card)
			end
		end
	end
end

local function renderBag()
	local bagList = S.Get("Bag") or {}
	if not bag.tab then
		bag.tab = if #bagList > 0 then "Bag" else "Storage"
	end
	local items = bagItems(bag.tab)
	local mult = S.Derived("CoinMult") or 1
	local sig = bagSignature(items, mult)
	-- Tab captions change with counts even when the visible list doesn't
	local storageN = #(S.Get("Storage") or {})
	local displayN = 0
	for _ in S.Get("Stands") or {} do
		displayN += 1
	end
	for _ in S.Get("Vault") or {} do
		displayN += 1
	end
	bagRefs.tabCaption.Bag.Text = `Bag {#bagList}/{S.Derived("BagSize") or 3}`
	bagRefs.tabCaption.Storage.Text = `Storage {storageN}`
	bagRefs.tabCaption.Display.Text = `Dock {displayN}`
	bagRefs.paintTabs(bag.tab)
	bagRefs.sortButton.Text = `⇅ {bag.sort}`
	bagRefs.sellCommons.Visible = bag.tab == "Storage"
	-- Sort fills the right column when Sell Commons is hidden (no dead gap next to it)
	bagRefs.sortButton.Size = UDim2.fromOffset(if bag.tab == "Storage" then 110 else 236, 44)
	bagRefs.hint.Text = if bag.tab == "Bag"
		then "Bag relics are lost if you die. Swim home to secure them!"
		elseif bag.tab == "Display" then `Your dock earns +{NumberFormat.short(S.Get("IncomePerSecond") or 0)}/s`
		else "Display your best relics to earn Coins while you dive."
	bagRefs.hint.TextColor3 = if bag.tab == "Bag" then T.Gold else Kit.Lighten(T.Muted, 0.2)
	if sig == bag.sig then
		return
	end
	bag.sig = sig

	Kit.Clear(bagRefs.grid)
	local selectedItem = nil
	for i, it in items do
		if it.key == bag.selected then
			selectedItem = it
		end
		RelicCard.new({
			Relic = it.relic,
			Subtitle = `+{NumberFormat.short(Formulas.RelicCPS(it.relic) * mult)} / s`,
			LazyModel = true,
			Selected = it.key == bag.selected,
			LayoutOrder = i,
			OnClick = function()
				bag.selected = if bag.selected == it.key then nil else it.key
				bag.sig = ""
				renderBag()
			end,
			Parent = bagRefs.grid,
		})
	end
	-- Empty state sits over the grid (a grid cell would squash it into a 112 px column)
	bagRefs.empty.Visible = #items == 0
	if #items == 0 then
		bagRefs.emptyTitle.Text = if bag.tab == "Bag"
			then "Your dive bag is empty"
			elseif bag.tab == "Storage" then "No relics in storage yet"
			else "Nothing on display"
		bagRefs.emptyText.Text = if bag.tab == "Bag"
			then "Dive and salvage glinting relics, then swim home to keep them."
			elseif bag.tab == "Storage" then "Relics you bring home land here."
			else "Pick a relic in Storage and tap Display on dock to earn Coins."
	end
	if bag.selected and not selectedItem then
		bag.selected = nil
	end
	renderDetail(selectedItem, mult)
	task.defer(realizeVisibleCards)
end

local function buildBag(body: Frame)
	bagRefs.tabCaption = {}
	local tabsFrame, paint = Kit.Tabs(
		body,
		{
			{ id = "Bag", text = "Bag", color = Color3.fromRGB(60, 160, 255) },
			{ id = "Storage", text = "Storage", color = T.Accent },
			{ id = "Display", text = "Dock", color = T.Gold },
		},
		"Storage",
		function(id)
			bag.tab = id
			bag.selected = nil
			bag.sig = ""
			renderBag()
		end,
		{ Size = UDim2.new(1, -250, 0, 48) }
	)
	bagRefs.paintTabs = paint
	local order = {}
	for _, b in tabsFrame:GetChildren() do
		if b:IsA("TextButton") then
			order[b.LayoutOrder] = b
		end
	end
	bagRefs.tabCaption.Bag, bagRefs.tabCaption.Storage, bagRefs.tabCaption.Display = order[1], order[2], order[3]

	bagRefs.sortButton = Kit.Button("⇅ Value", T.Slab, function()
		bag.sort = if bag.sort == "Value" then "Rarity" else "Value"
		bag.sig = ""
		renderBag()
	end, { Position = UDim2.new(1, -236, 0, 2), Size = UDim2.fromOffset(110, 44), TextSize = 15, Parent = body })
	bagRefs.sellCommons = Kit.Button("Sell Commons", T.BadDeep, function()
		Net.RequestSellCommons:FireServer()
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(120, 44),
		TextSize = 14,
		Parent = body,
	})
	bagRefs.hint = Kit.Label({
		Text = "",
		TextSize = 14,
		Font = T.Bold,
		Position = UDim2.fromOffset(4, 54),
		Size = UDim2.new(1, -250, 0, 20),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = body,
	})
	bagRefs.grid = Kit.Scroll({ Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, -246, 1, -80), Parent = body })
	local grid = Kit.Grid(Vector2.new(112, 150), 10)
	grid.Parent = bagRefs.grid
	fitGrid(bagRefs.grid, grid, 112, 150, 10)
	bagRefs.empty = Kit.Card({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, -246, 0, 200),
		BackgroundColor3 = T.PanelDark,
		Visible = false,
		Parent = body,
	})
	Kit.IconBadge(
		"bag",
		Color3.fromRGB(60, 160, 255),
		72,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Parent = bagRefs.empty }
	)
	bagRefs.emptyTitle = Kit.Title({
		Text = "",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(12, 104),
		Size = UDim2.new(1, -24, 0, 28),
		Parent = bagRefs.empty,
	})
	bagRefs.emptyText = Kit.Label({
		Text = "",
		Font = T.Bold,
		TextSize = 14,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 138),
		Size = UDim2.new(1, -32, 0, 44),
		Parent = bagRefs.empty,
	})
	-- Only cards scrolled into view get their 3D model (keeps big storages smooth)
	bagRefs.grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		realizeVisibleCards()
	end)
	bagRefs.grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		realizeVisibleCards()
	end)
	New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = bagRefs.grid })
	local detailCard = Kit.Card({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 56),
		Size = UDim2.new(0, 236, 1, -56),
		BackgroundColor3 = T.PanelDark,
		Parent = body,
	})
	bagRefs.detail =
		Kit.Scroll({ Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), Parent = detailCard })
	Kit.List(6, false, Enum.HorizontalAlignment.Center).Parent = bagRefs.detail
end

------------------------------------------------------------------------------------------
-- Upgrades: suit hero card + one big pressable card per stat (the whole card is the button)
------------------------------------------------------------------------------------------
local upScroll
local upSig = ""

-- Colour per upgrade track (icon tile + level bar), grouped into sections
local TRACK_COLORS = {
	Oxygen = Color3.fromRGB(63, 214, 230),
	Fins = Color3.fromRGB(90, 160, 255),
	Bag = Color3.fromRGB(255, 150, 70),
	Sonar = Color3.fromRGB(123, 227, 160),
	Salvage = Color3.fromRGB(245, 192, 74),
	Board = Color3.fromRGB(90, 200, 255),
	Display = Color3.fromRGB(245, 192, 74),
	Offline = Color3.fromRGB(180, 140, 255),
	Gate = Color3.fromRGB(240, 90, 90),
	Crab = Color3.fromRGB(255, 120, 90),
	Alarm = Color3.fromRGB(255, 130, 180),
}
local UPGRADE_SECTIONS = {
	{
		title = "Dive gear",
		color = Color3.fromRGB(63, 214, 230),
		tracks = { "Oxygen", "Fins", "Bag", "Sonar", "Salvage", "Board" },
	},
	{ title = "Dock", color = T.Gold, tracks = { "Display", "Offline" } },
	{ title = "Dock defense", color = Color3.fromRGB(240, 90, 90), tracks = { "Gate", "Crab", "Alarm" } },
}

local function num(n: number): string
	if math.abs(n - math.round(n)) < 0.01 then
		return tostring(math.round(n))
	end
	return string.format("%.1f", n)
end

-- What one more level does, as "label", "now", "next" (current values include passes)
local function trackPreview(id: string, lvl: number): (string, string, string)
	local B = Upgrades.Base
	local D = S.Derived
	if id == "Oxygen" then
		local o = D("MaxOxygen") or (B.OxygenSeconds + lvl * B.OxygenPerLevel)
		return "Dive time", `{num(o)}s`, `{num(o + B.OxygenPerLevel)}s`
	elseif id == "Fins" then
		local s = D("SwimSpeed") or B.SwimSpeed
		return "Swim speed", num(s), num(s * (1 + (lvl + 1) * B.FinsPerLevel) / (1 + lvl * B.FinsPerLevel))
	elseif id == "Bag" then
		local n = D("BagSize") or B.BagSize
		return "Bag slots", num(n), num(n + 1)
	elseif id == "Sonar" then
		local r = D("SonarRange") or B.SonarRange
		local extra = if lvl + 1 == 5 then " + rarity" elseif lvl + 1 == 10 then " + mutations" else ""
		return "Sonar range", num(r), num(r + B.SonarPerLevel) .. extra
	elseif id == "Salvage" then
		local t = D("SalvageSeconds") or B.SalvageSeconds
		return "Salvage time", `{num(t)}s`, `{num(t * (1 - B.SalvagePerLevel))}s`
	elseif id == "Display" then
		local n = D("StandCount") or B.Stands
		return "Display stands", num(n), num(n + 1)
	elseif id == "Offline" then
		local r = D("OfflineRate") or B.OfflineRate
		return "Offline rate", `{num(r * 100)}%`, `{num((r + B.OfflineRatePerLevel) * 100)}%`
	elseif id == "Gate" then
		if lvl == 0 then
			return "Laser Gate", "Locked", "Unlock"
		end
		local s = B.GateSeconds + (lvl - 1) * 10
		return "Gate time", `{s}s`, `{s + 10}s`
	elseif id == "Crab" then
		return "Intruder slow", `{lvl * 6}%`, `{(lvl + 1) * 6}%`
	elseif id == "Alarm" then
		return "Alarm range", `{2 + lvl * 10}`, `{2 + (lvl + 1) * 10} studs`
	end
	return "Level", tostring(lvl), tostring(lvl + 1)
end

-- Effect rows as {label, now, next}. The Diving Board has two rows: its launch and its plunge.
local function effectRows(id: string, lvl: number): { { string } }
	if id == "Board" then
		local B = Upgrades.Base
		local dive = Upgrades.Dive
		local depth = S.Derived("DiveBoardDepth") or B.BoardDepth
		local launch = S.Derived("DiveLaunch") or dive.Launch
		return {
			{ "Launch", num(launch), `{num(launch + dive.LaunchPerLevel)} studs` },
			{ "Dive depth", `{num(depth)}m`, `{num(depth + B.BoardDepthPerLevel)}m` },
		}
	end
	local label, now, nxt = trackPreview(id, lvl)
	return { { label, now, nxt } }
end

local function upgradeCard(parent: Instance, track, lvl: number, coins: number, order: number)
	local maxed = lvl >= track.Max
	local cost = if maxed then 0 else Upgrades.Cost(track.Id, lvl)
	local affordable = not maxed and coins >= cost
	local color = TRACK_COLORS[track.Id] or T.Accent
	local container, face
	container, face = Kit.GameCard(
		if maxed then Kit.Darken(T.Gold, 0.55) else T.Slab,
		{ LayoutOrder = order, Parent = parent },
		function()
			if maxed then
				controllers.UIController.Toast(`{track.Name} is maxed!`, "info")
				return
			end
			Kit.Pop(face)
			Net.RequestUpgrade:FireServer(track.Id)
		end
	)
	if affordable then
		local s = face:FindFirstChildOfClass("UIStroke")
		s.Color, s.Thickness = T.Good, 3
	end
	-- Icon tile + name + level
	Kit.IconBadge(Icons.Track(track.Id), color, 50, { Position = UDim2.fromOffset(10, 10), ZIndex = 3, Parent = face })
	Kit.Title({
		Text = track.Name,
		TextSize = 19,
		Position = UDim2.fromOffset(68, 8),
		Size = UDim2.new(1, -76, 0, 24),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = face,
	})
	Kit.Label({
		Text = if maxed then `Lv {lvl} · MAX` else `Lv {lvl} / {track.Max}`,
		Font = T.Bold,
		TextSize = 13,
		TextColor3 = if maxed then T.Gold else Kit.Lighten(color, 0.35),
		Position = UDim2.fromOffset(68, 32),
		Size = UDim2.new(1, -76, 0, 16),
		TextWrapped = false,
		ZIndex = 3,
		Parent = face,
	})
	local _, setBar = Kit.Bar({
		Position = UDim2.fromOffset(68, 50),
		Size = UDim2.new(1, -80, 0, 10),
		Color = if maxed then T.Gold else color,
		Parent = face,
	})
	setBar(lvl / track.Max)

	-- Effect rows: "Dive time  60s -> 66s". The Diving Board shows two rows (launch and depth).
	local rows = effectRows(track.Id, lvl)
	local rowH = if #rows > 1 then 20 else 26
	local effect = New("Frame", {
		BackgroundColor3 = T.PanelDark,
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 0, rowH * #rows),
		ZIndex = 3,
		Parent = face,
	}, { Kit.Corner(8), New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	for i, row in rows do
		local line = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, (i - 1) * rowH),
			Size = UDim2.new(1, 0, 0, rowH),
			ZIndex = 4,
			Parent = effect,
		})
		Kit.Label({
			Text = row[1],
			Font = T.Bold,
			TextSize = 13,
			TextColor3 = T.Muted,
			Size = UDim2.fromScale(0.5, 1),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = line,
		})
		local now, nxt = row[2], row[3]
		Kit.Label({
			Text = if maxed then now else `{now}  <font color="#7BE3A0">→ {nxt}</font>`,
			RichText = true,
			Font = T.Bold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.62, 1),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = line,
		})
	end

	-- Price plate: green when you can afford it, gold MAX when done
	Kit.PricePlate(
		if maxed then "MAX LEVEL" else coinText(cost),
		if maxed then T.Gold elseif affordable then T.Good else Color3.fromRGB(58, 74, 98),
		if maxed then "check" else "coin",
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -20, 0, 40),
			TextColor3 = if affordable or maxed then T.DarkText else Kit.Lighten(T.Muted, 0.2),
			Parent = face,
		}
	)
	if affordable then
		Kit.Pill("UPGRADE!", T.Good, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, -10),
			TextSize = 11,
			Size = UDim2.fromOffset(0, 20),
			ZIndex = 6,
			Parent = face,
		})
	end
	return container
end

local function renderUpgrades()
	local levels = S.Get("Upgrades") or {}
	local coins = S.Get("Coins") or 0
	local suitIndex = S.Get("Suit") or 1
	local suit = Upgrades.Suits[suitIndex]
	local nextSuit = Upgrades.Suits[suitIndex + 1]
	local width = upScroll.AbsoluteSize.X
	local cols = if width >= 700 then 3 elseif width >= 420 or width == 0 then 2 else 1

	-- Coins tick every second: rebuild only when something on screen would change, so a card
	-- is never replaced under the player's finger mid-press
	local sigParts = { tostring(suitIndex), tostring(cols), tostring(nextSuit and coins >= nextSuit.Cost) }
	for _, key in
		{
			"MaxOxygen",
			"SwimSpeed",
			"BagSize",
			"SonarRange",
			"SalvageSeconds",
			"DiveBoardDepth",
			"DiveLaunch",
			"DiveOut",
			"StandCount",
			"OfflineRate",
		}
	do
		table.insert(sigParts, tostring(S.Derived(key)))
	end
	for _, track in Upgrades.Tracks do
		local lvl = levels[track.Id] or 0
		table.insert(sigParts, `{track.Id}{lvl}{lvl < track.Max and coins >= Upgrades.Cost(track.Id, lvl)}`)
	end
	local sig = table.concat(sigParts, "|")
	if sig == upSig then
		return
	end
	upSig = sig

	Kit.Clear(upScroll)
	local order = 0
	local function o()
		order += 1
		return order
	end

	-- Suit hero card: tap anywhere on it to buy the next suit
	local suitAffordable = nextSuit ~= nil and not nextSuit.ComingSoon and coins >= nextSuit.Cost
	local _, sr = Kit.GameCard(
		Kit.Darken(suit.Color, 0.72),
		{ Size = UDim2.new(1, -8, 0, 146), LayoutOrder = o(), Parent = upScroll },
		function()
			if nextSuit then
				Net.RequestBuySuit:FireServer()
			else
				controllers.UIController.Open("Diver")
			end
		end
	)
	local srStroke = sr:FindFirstChildOfClass("UIStroke")
	if suitAffordable then
		srStroke.Color, srStroke.Thickness = T.Good, 3
	end
	local stage = New("Frame", {
		BackgroundColor3 = Kit.Darken(suit.Color, 0.45),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(112, 112),
		ZIndex = 3,
		Parent = sr,
	}, { Kit.Corner(16), Kit.Stroke(T.Outline, 2, 0) })
	Kit.Glow(stage, suit.Color, 110)
	RelicView.Archetype(
		"helmet",
		{ main = suit.Color, accent = Color3.fromRGB(255, 196, 64) },
		{ Spin = 30, ZIndex = 4, Parent = stage }
	)
	Kit.Button("Customize", T.Accent, function()
		controllers.UIController.Open("Diver")
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 10),
		Size = UDim2.fromOffset(104, 30),
		TextSize = 12,
		ZIndex = 6,
		Parent = stage,
	})
	Kit.Title({
		Text = suit.Name,
		TextSize = 26,
		Position = UDim2.fromOffset(136, 10),
		Size = UDim2.new(1, -330, 0, 30),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = sr,
	})
	Kit.Label({
		Text = `Safe down to {Zones.List[math.min(suitIndex, #Zones.List)].Name}`,
		Font = T.Bold,
		TextColor3 = Kit.Lighten(suit.Color, 0.4),
		TextSize = 14,
		Position = UDim2.fromOffset(136, 42),
		Size = UDim2.new(1, -330, 0, 18),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = sr,
	})
	-- Zone ladder: unlocked zones lit, the next one outlined, the rest dim with a lock
	local pips = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(136, 70),
		Size = UDim2.new(1, -330, 0, 46),
		ZIndex = 3,
		Parent = sr,
	}, { Kit.List(6, true) })
	for i, zone in Zones.List do
		local ok = i <= suitIndex
		local zc = Kit.Lighten(zone.FogColor, 0.35)
		local badge = Kit.IconBadge(
			Icons.Get(zone.Id),
			if ok then zc else Color3.fromRGB(70, 84, 104),
			42,
			{ LayoutOrder = i, ZIndex = 3, Parent = pips }
		)
		if not ok then
			badge.BackgroundTransparency = 0.35
			Kit.IconBadge(
				"lock",
				T.PanelDark,
				18,
				{ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 1, 4), ZIndex = 5, Parent = badge }
			)
		end
		if i == suitIndex + 1 then
			local st = badge:FindFirstChildOfClass("UIStroke")
			st.Color, st.Transparency = T.Gold, 0
		end
	end
	if nextSuit then
		local right = New("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(176, 116),
			ZIndex = 3,
			Parent = sr,
		})
		Kit.Label({
			Text = "NEXT SUIT",
			Font = T.Bold,
			TextSize = 12,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 3,
			Parent = right,
		})
		Kit.Title({
			Text = nextSuit.Name,
			TextSize = 20,
			TextColor3 = Kit.Lighten(nextSuit.Color, 0.35),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 18),
			Size = UDim2.new(1, 0, 0, 24),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = right,
		})
		Kit.Label({
			Text = if nextSuit.ComingSoon
				then "Coming soon"
				else `Unlocks {Zones.List[math.min(suitIndex + 1, #Zones.List)].Name}`,
			Font = T.Bold,
			TextSize = 12,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 16),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = right,
		})
		Kit.PricePlate(
			if nextSuit.ComingSoon then "SOON" else coinText(nextSuit.Cost),
			if suitAffordable then T.Good else Color3.fromRGB(58, 74, 98),
			"coin",
			{
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 46),
				TextSize = 22,
				TextColor3 = if suitAffordable then T.DarkText else Kit.Lighten(T.Muted, 0.2),
				Parent = right,
			}
		)
	else
		Kit.Pill("MAX SUIT", T.Gold, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.5, 0),
			TextSize = 18,
			Size = UDim2.fromOffset(0, 40),
			ZIndex = 3,
			Parent = sr,
		})
	end

	-- One card per stat, grouped by what it improves
	for _, section in UPGRADE_SECTIONS do
		Kit.Header(upScroll, o(), section.title, section.color)
		local grid = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = o(),
			Parent = upScroll,
		})
		New("UIGridLayout", {
			CellSize = UDim2.new(1 / cols, -math.ceil(10 * (cols - 1) / cols), 0, 164),
			CellPadding = UDim2.fromOffset(10, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		for i, id in section.tracks do
			local track = Upgrades.ById[id]
			if track then
				upgradeCard(grid, track, levels[id] or 0, coins, i)
			end
		end
		if section.tracks[1] == "Gate" then
			-- Laser Gate activation lives with the defense upgrades
			local gateLvl = levels.Gate or 0
			local _, gf = Kit.GameCard(
				if gateLvl > 0 then Color3.fromRGB(120, 36, 48) else T.Slab,
				{ LayoutOrder = 99, Parent = grid },
				function()
					if gateLvl > 0 then
						Net.ActivateGate:FireServer()
					else
						controllers.UIController.Toast("Buy the Laser Gate upgrade first.", "error")
					end
				end
			)
			Kit.IconBadge(
				Icons.Get("Gate"),
				T.Bad,
				50,
				{ Position = UDim2.fromOffset(10, 10), ZIndex = 3, Parent = gf }
			)
			Kit.Title({
				Text = "Activate Gate",
				TextSize = 19,
				Position = UDim2.fromOffset(68, 8),
				Size = UDim2.new(1, -76, 0, 24),
				TextWrapped = false,
				ZIndex = 3,
				Parent = gf,
			})
			Kit.Label({
				Text = "Blocks raids on your dock for a while",
				Font = T.Bold,
				TextSize = 13,
				TextColor3 = T.Muted,
				Position = UDim2.fromOffset(68, 34),
				Size = UDim2.new(1, -76, 0, 34),
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 3,
				Parent = gf,
			})
			Kit.PricePlate(
				if gateLvl > 0 then "ACTIVATE" else "LOCKED",
				if gateLvl > 0 then T.Bad else Color3.fromRGB(58, 74, 98),
				if gateLvl > 0 then "gate" else "lock",
				{
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(1, -20, 0, 40),
					Parent = gf,
				}
			)
		end
	end
end

------------------------------------------------------------------------------------------
-- Codex: zone tabs + 3D card grid (silhouettes for undiscovered relics)
------------------------------------------------------------------------------------------
local codexScroll, codexTitle, codexSetBar, codexPaintTabs
local codexSig = ""
local function renderCodex()
	local codex = S.Get("Codex") or {}
	local total, found = 0, 0
	local defs = {}
	for _, def in Relics.List do
		if def.Zone == codexZone then
			total += 1
			if codex[def.Id] then
				found += 1
			end
			table.insert(defs, def)
		end
	end
	table.sort(defs, function(a, b)
		local ta, tb = Rarities.TierOf(a.Rarity), Rarities.TierOf(b.Rarity)
		if ta ~= tb then
			return ta < tb
		end
		return a.Id < b.Id
	end)
	local zone = Zones.List[codexZone]
	local pct = math.floor(found / math.max(total, 1) * 100)
	codexTitle.Text = `{zone.Name}  {found}/{total}`
	codexSetBar(found / math.max(total, 1), if pct >= 100 then T.Gold else Kit.Lighten(zone.FogColor, 0.35), `{pct}%`)
	codexPaintTabs(tostring(codexZone))

	local parts = { tostring(codexZone) }
	for _, def in defs do
		local entry = codex[def.Id]
		local n = 0
		if entry then
			for _ in entry do
				n += 1
			end
		end
		table.insert(parts, `{def.Id}:{entry and n or -1}`)
	end
	local sig = table.concat(parts, "|")
	if sig == codexSig then
		return
	end
	codexSig = sig

	Kit.Clear(codexScroll)
	for i, def in defs do
		local entry = codex[def.Id]
		local variants = 0
		if entry then
			for _ in entry do
				variants += 1
			end
		end
		RelicCard.new({
			Def = def,
			Discovered = entry ~= nil,
			Subtitle = if entry then `Variants {variants}/{#Mutations.List + 1}` else def.Rarity,
			LayoutOrder = i,
			OnClick = function()
				if entry then
					controllers.UIController.Toast(`{def.Name}: "{def.Lore}"`, "info")
				else
					controllers.UIController.Toast(`Undiscovered {def.Rarity} relic. Search {zone.Name}!`, "info")
				end
			end,
			Parent = codexScroll,
		})
	end
end

local function buildCodex(body: Frame)
	local items = {}
	for i, zone in Zones.List do
		table.insert(
			items,
			{ id = tostring(i), text = zone.Name, icon = Icons.Get(zone.Id), color = Kit.Lighten(zone.FogColor, 0.3) }
		)
	end
	local tabScroll = Kit.Scroll({
		Size = UDim2.new(1, 0, 0, 54),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		Parent = body,
	})
	local tabs
	tabs, codexPaintTabs = Kit.Tabs(tabScroll, items, tostring(codexZone), function(id)
		codexZone = tonumber(id) or 1
		codexSig = ""
		renderCodex()
	end, { Size = UDim2.new(0, 0, 0, 48), AutomaticSize = Enum.AutomaticSize.X, TabWidth = 148 })
	tabs.Name = "ZoneTabs"
	-- Zone progress strip: big count, wide bar, and the completion reward as a pill
	local strip = Kit.Card({
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = T.PanelDark,
		Parent = body,
	})
	codexTitle = Kit.Title({
		Text = "",
		TextSize = 20,
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(0.45, -14, 0, 26),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = strip,
	})
	Kit.Label({
		Text = "relics found",
		Font = T.Bold,
		TextSize = 12,
		TextColor3 = T.Muted,
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(0.45, -14, 0, 16),
		TextWrapped = false,
		Parent = strip,
	})
	local _, setBar = Kit.Bar({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.45, 0, 0.5, 0),
		Size = UDim2.new(0.55, -170, 0, 24),
		TextSize = 13,
		Parent = strip,
	})
	codexSetBar = setBar
	Kit.Pill("100% = +5% luck", T.Gold, {
		Icon = "star",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		TextSize = 13,
		Size = UDim2.fromOffset(0, 30),
		Parent = strip,
	})
	codexScroll = Kit.Scroll({ Position = UDim2.fromOffset(0, 124), Size = UDim2.new(1, 0, 1, -124), Parent = body })
	local grid = Kit.Grid(Vector2.new(112, 150), 10)
	grid.Parent = codexScroll
	fitGrid(codexScroll, grid, 112, 150, 10)
	New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = codexScroll })
end

------------------------------------------------------------------------------------------
-- Quests, login calendar, Tide Pass
------------------------------------------------------------------------------------------
local questScroll
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

local QUEST_ICONS = {
	Salvage = "wrench",
	Escape = "home",
	RarePlus = "sparkle",
	Mutated = "sparkle",
	Collect = "coin",
	Upgrade = "upgrade",
	ReachZone3 = "anchor",
	Sell = "coin",
	LeviathanEscape = "eye",
	Steal = "lock",
	Mut_Bioluminescent = "sparkle",
	EpicPlus = "star",
}

-- Icon, short text and colour for a reward table ({Coins}, {Pearls}, {Relic}, {Boost})
local function rewardInfo(reward): (string, string, Color3)
	if reward.Relic then
		local r = Rarities[reward.Relic]
		return (if type(r) == "table" then r.Icon else "◆"),
			`{reward.Relic} relic`,
			Kit.RarityColor(reward.Relic, Rarities)
	elseif reward.Boost then
		return Icons.Get(reward.Boost),
			if reward.Boost == "LuckPotion" then "Luck potion" else "Mutation potion",
			Color3.fromRGB(170, 100, 255)
	elseif reward.Coins and reward.Pearls then
		return Icons.Get("Coins"), `{NumberFormat.short(reward.Coins)} + {reward.Pearls} pearls`, T.Gold
	elseif reward.Pearls then
		return Icons.Get("Pearls"), `{reward.Pearls} Pearls`, T.Pearl
	end
	return Icons.Get("Coins"), NumberFormat.short(reward.Coins or 0), T.Gold
end

local function rewardTile(parent: Instance, reward, state: string, order: number, onClick, labelTop: string?)
	-- state: "claimable" | "claimed" | "locked" | "future"
	local icon, text, color = rewardInfo(reward)
	local claimable = state == "claimable"
	local tile = Kit.Button("", if claimable then Kit.Darken(T.Gold, 0.1) else Kit.Darken(color, 0.65), onClick, {
		Size = UDim2.fromOffset(88, 100),
		LayoutOrder = order,
		Parent = parent,
	})
	tile:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 14)
	local stroke = tile:FindFirstChildOfClass("UIStroke")
	stroke.Color = if claimable then Color3.new(1, 1, 1) else color
	stroke.Transparency = if state == "future" or state == "locked" then 0.6 else 0.05
	if labelTop then
		Kit.Title({
			Text = labelTop,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 3),
			Size = UDim2.new(1, 0, 0, 16),
			TextWrapped = false,
			Parent = tile,
		})
	end
	local badge = Kit.IconBadge(
		icon,
		color,
		42,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Parent = tile }
	)
	Kit.Label({
		Text = text,
		Font = T.Bold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if claimable then T.DarkText else T.Text,
		Position = UDim2.new(0, 3, 1, -32),
		Size = UDim2.new(1, -6, 0, 28),
		Parent = tile,
	})
	if state == "claimed" then
		Kit.IconBadge(
			"check",
			T.Good,
			30,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), ZIndex = 4, Parent = tile }
		)
		tile.BackgroundTransparency = 0.4
	elseif state == "locked" then
		badge.BackgroundTransparency = 0.5
		Kit.IconBadge(
			Icons.Get("Lock"),
			T.PanelDark,
			26,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -2), Parent = tile }
		)
	elseif state == "future" then
		tile.BackgroundTransparency = 0.35
	elseif claimable then
		Kit.Shine(tile, 1.2)
		Kit.Pill("CLAIM!", T.Good, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, 0),
			TextSize = 12,
			Size = UDim2.fromOffset(0, 22),
			ZIndex = 6,
			Parent = tile,
		})
		Kit.Pulse(tile, 0.03)
	end
	return tile
end

local tideTrackScroll = nil
local function renderQuests()
	Kit.Clear(questScroll)
	local order = 0
	local function o()
		order += 1
		return order
	end
	-- Login calendar
	local streak = S.Get("LoginStreak") or 1
	local claimedToday = (S.Get("LastDailyClaimDay") or 0) == os.time() // 86400
	header(questScroll, o(), `Daily login · {streak} day streak`, T.Gold)
	local cal = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 118), LayoutOrder = o(), Parent = questScroll },
		{ Kit.List(8, true) }
	)
	local dayInCycle = ((streak - 1) % #Economy.DailyRewards) + 1
	for i, reward in Economy.DailyRewards do
		local isToday = i == dayInCycle
		local state = if isToday and not claimedToday
			then "claimable"
			elseif i < dayInCycle or (isToday and claimedToday) then "claimed"
			else "future"
		rewardTile(cal, reward, state, i, function()
			if state == "claimable" then
				Net.RequestClaimDaily:FireServer()
			end
		end, `Day {i}`)
	end

	local q = S.Get("Quests") or {}
	for _, section in
		{
			{ "Daily quests", q.Daily or {}, T.Accent },
			{ "Weekly quests", q.Weekly or {}, Color3.fromRGB(180, 140, 255) },
		}
	do
		header(questScroll, o(), section[1], section[3])
		for _, entry in section[2] do
			local def = questDef(entry.Id)
			if def then
				local done = entry.Progress >= def.Goal
				local claimable = done and not entry.Claimed
				local claim = function()
					if claimable then
						Net.RequestClaimQuest:FireServer(entry.Id)
					end
				end
				-- The whole row is the claim button once the quest is complete
				local _, r = Kit.GameCard(
					if claimable
						then Kit.Darken(T.Gold, 0.55)
						elseif entry.Claimed then Kit.Darken(T.Good, 0.7)
						else T.Slab,
					{ Size = UDim2.new(1, -8, 0, 88), LayoutOrder = o(), Parent = questScroll },
					if claimable then claim else nil
				)
				if claimable then
					local st = r:FindFirstChildOfClass("UIStroke")
					st.Color, st.Thickness = T.Gold, 3
				end
				Kit.IconBadge(
					QUEST_ICONS[def.Stat] or "quests",
					if done then T.Good else section[3],
					56,
					{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 3, Parent = r }
				)
				Kit.Title({
					Text = def.Text,
					TextSize = 19,
					Position = UDim2.fromOffset(80, 8),
					Size = UDim2.new(1, -230, 0, 24),
					TextWrapped = false,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 3,
					Parent = r,
				})
				local _, setBar = Kit.Bar({
					Position = UDim2.fromOffset(80, 36),
					Size = UDim2.new(1, -230, 0, 18),
					TextSize = 12,
					Color = if done then T.Good else section[3],
					Parent = r,
				})
				setBar(entry.Progress / def.Goal, nil, `{math.min(entry.Progress, def.Goal)} / {def.Goal}`)
				local pills = New("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(80, 60),
					Size = UDim2.new(1, -230, 0, 22),
					ZIndex = 3,
					Parent = r,
				}, { Kit.List(6, true) })
				if def.Coins then
					Kit.Pill(
						NumberFormat.short(def.Coins),
						Kit.Darken(T.Gold, 0.65),
						{ TextColor3 = T.Gold, Icon = "coin", LayoutOrder = 1, ZIndex = 3, Parent = pills }
					)
				end
				if def.Pearls then
					Kit.Pill(
						tostring(def.Pearls),
						Kit.Darken(T.Pearl, 0.65),
						{ TextColor3 = T.Pearl, Icon = "pearl", LayoutOrder = 2, ZIndex = 3, Parent = pills }
					)
				end
				Kit.Pill(
					`+{def.Xp} XP`,
					Kit.Darken(T.Accent, 0.65),
					{ TextColor3 = T.Accent, LayoutOrder = 3, ZIndex = 3, Parent = pills }
				)
				-- Right side: a real button only when there is something to press
				local side = {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(128, 50),
					ZIndex = 3,
					Parent = r,
				}
				if claimable then
					local b = Kit.Button("CLAIM!", T.Gold, claim, {
						TextSize = 19,
						Font = T.Title,
						ZIndex = 4,
						AnchorPoint = side.AnchorPoint,
						Position = side.Position,
						Size = side.Size,
						Parent = r,
					})
					Kit.Shine(b, 1)
					Kit.Pulse(b, 0.04)
				elseif entry.Claimed then
					Kit.PricePlate("DONE", T.Good, "check", side)
				else
					local pct = math.floor(math.min(entry.Progress / def.Goal, 1) * 100)
					local chip = Kit.Title({
						Text = `{pct}%`,
						TextSize = 24,
						TextColor3 = Kit.Lighten(section[3], 0.3),
						TextXAlignment = Enum.TextXAlignment.Center,
						Size = UDim2.fromOffset(128, 28),
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -12, 0, 14),
						ZIndex = 3,
						Parent = r,
					})
					chip.Name = "Percent"
					Kit.Label({
						Text = "IN PROGRESS",
						Font = T.Bold,
						TextSize = 11,
						TextColor3 = T.Muted,
						TextXAlignment = Enum.TextXAlignment.Center,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -12, 0, 46),
						Size = UDim2.fromOffset(128, 14),
						TextWrapped = false,
						ZIndex = 3,
						Parent = r,
					})
				end
			end
		end
	end

	-- Tide Pass: horizontal reward track
	local tp = S.Get("TidePass") or { XP = 0, Premium = false, ClaimedFree = {}, ClaimedPremium = {} }
	local TPc = Economy.TidePass
	local tier = tp.XP // TPc.XpPerTier
	header(questScroll, o(), `Tide Pass {TPc.SeasonId} · Tier {tier}/{TPc.Tiers}`, T.Gold)
	local top = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 50), LayoutOrder = o(), Parent = questScroll }
	)
	local _, setTp = Kit.Bar({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, if tp.Premium then 0 else -390, 0, 24),
		Color = T.Gold,
		Parent = top,
	})
	setTp((tp.XP % TPc.XpPerTier) / TPc.XpPerTier, nil, `{tp.XP % TPc.XpPerTier}/{TPc.XpPerTier} XP to tier {tier + 1}`)
	if not tp.Premium then
		Kit.Button("Premium · 499 R$", T.Gold, function()
			Net.RequestPurchase:FireServer("Product", "TidePassPremium")
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -196, 0, 2),
			Size = UDim2.fromOffset(186, 46),
			TextSize = 14,
			Icon = "ticket",
			Parent = top,
		})
		Kit.Button(`{TPc.PremiumPearlCost} Pearls`, T.PanelLight, function()
			Net.RequestBuyTidePassPearls:FireServer()
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 2),
			Size = UDim2.fromOffset(186, 46),
			TextSize = 14,
			Icon = "pearl",
			Parent = top,
		})
	end
	local track = Kit.Card({
		Size = UDim2.new(1, -8, 0, 270),
		LayoutOrder = o(),
		BackgroundColor3 = T.PanelDark,
		Parent = questScroll,
	})
	Kit.Label({
		Text = "FREE",
		Font = T.Title,
		TextSize = 14,
		TextColor3 = T.Muted,
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.fromOffset(60, 20),
		Parent = track,
	})
	Kit.Label({
		Text = "PREMIUM",
		Font = T.Title,
		TextSize = 14,
		TextColor3 = T.Gold,
		Position = UDim2.fromOffset(10, 152),
		Size = UDim2.fromOffset(70, 20),
		Parent = track,
	})
	tideTrackScroll = Kit.Scroll({
		Position = UDim2.fromOffset(84, 6),
		Size = UDim2.new(1, -90, 1, -12),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 4,
		Parent = track,
	})
	Kit.List(8, true).Parent = tideTrackScroll
	for t = 1, TPc.Tiers do
		local col = New(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.fromOffset(92, 246), LayoutOrder = t, Parent = tideTrackScroll }
		)
		local reached = tier >= t
		Kit.Pill(`Tier {t}`, if reached then T.Gold else T.PanelLight, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			TextSize = 12,
			Size = UDim2.fromOffset(0, 22),
			Parent = col,
		})
		local function tile(premium: boolean, y: number)
			local claimed = (if premium then tp.ClaimedPremium else tp.ClaimedFree)[tostring(t)]
			local state = if claimed
				then "claimed"
				elseif premium and not tp.Premium then "locked"
				elseif reached then "claimable"
				else "future"
			local holder = New("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(2, y),
				Size = UDim2.fromOffset(88, 100),
				Parent = col,
			})
			rewardTile(holder, Formulas.TierReward(t, premium), state, 1, function()
				if reached and not claimed and (not premium or tp.Premium) then
					Net.RequestClaimTier:FireServer(t, premium)
				end
			end)
		end
		tile(false, 30)
		tile(true, 140)
	end
	task.defer(function()
		if tideTrackScroll then
			tideTrackScroll.CanvasPosition = Vector2.new(math.max(0, (tier - 1) * 100), 0)
		end
	end)
end

------------------------------------------------------------------------------------------
-- Rebirth: before/after preview, requirements, talents
------------------------------------------------------------------------------------------
local rebirthScroll
local rebirthSig = ""

-- Wrapping row of pills (what you keep / what resets)
local function pillCloud(parent: Instance, items, color: Color3)
	local cloud = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
		Parent = parent,
	})
	local l = Kit.List(6, true)
	l.Wraps = true
	l.Parent = cloud
	for i, text in items do
		Kit.Pill(text, Kit.Darken(color, 0.62), {
			TextColor3 = Kit.Lighten(color, 0.3),
			TextSize = 13,
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = i,
			ZIndex = 3,
			Parent = cloud,
		})
	end
end

local function renderRebirth()
	local n = S.Get("Rebirths") or 0
	local need = S.Derived("RebirthRequirement") or Formulas.RebirthRequirement(n)
	local lifetime = S.Get("LifetimeCoins") or 0
	local suitOk = (S.Get("Suit") or 1) >= Economy.Rebirth.RequiredSuit
	local coinOk = lifetime >= need
	local ready = suitOk and coinOk
	local tokens = S.Get("RebirthTokens") or 0
	local talents = S.Get("Talents") or {}

	-- LifetimeCoins ticks every second: rebuild only when what's shown changes
	local sigParts = {
		tostring(n),
		tostring(need),
		NumberFormat.short(lifetime),
		tostring(ready),
		tostring(suitOk),
		tostring(tokens),
	}
	for _, t in Economy.Rebirth.Talents do
		table.insert(sigParts, `{t.Id}{talents[t.Id] or 0}`)
	end
	local sig = table.concat(sigParts, "|")
	if sig == rebirthSig then
		return
	end
	rebirthSig = sig
	Kit.Clear(rebirthScroll)

	-- Before -> after: two big stat slabs with an arrow between
	local compare = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 150), LayoutOrder = 1, Parent = rebirthScroll }
	)
	local function statCard(x: UDim, title: string, color: Color3, lines)
		local _, c = Kit.GameCard(
			Kit.Darken(color, 0.62),
			{ Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.5, -34, 1, 0), Parent = compare }
		)
		local st = c:FindFirstChildOfClass("UIStroke")
		st.Color, st.Thickness = color, 3
		Kit.Label({
			Text = title,
			Font = T.Bold,
			TextSize = 13,
			TextColor3 = Kit.Lighten(color, 0.45),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 3,
			Parent = c,
		})
		Kit.Title({
			Text = lines[1],
			TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 40),
			TextWrapped = false,
			ZIndex = 3,
			Parent = c,
		})
		local chips = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 82),
			Size = UDim2.new(1, 0, 0, 52),
			ZIndex = 3,
			Parent = c,
		})
		Kit.List(6, false, Enum.HorizontalAlignment.Center).Parent = chips
		Kit.Pill(
			lines[2],
			Kit.Darken(T.Good, 0.6),
			{ Icon = "sparkle", TextColor3 = T.Good, TextSize = 13, LayoutOrder = 1, ZIndex = 3, Parent = chips }
		)
		Kit.Pill(
			lines[3],
			Kit.Darken(T.Gold, 0.6),
			{ Icon = "token", TextColor3 = T.Gold, TextSize = 13, LayoutOrder = 2, ZIndex = 3, Parent = chips }
		)
	end
	statCard(UDim.new(0, 0), "NOW", T.Accent, {
		`x{Formulas.RebirthMultiplier(n)} Coins`,
		`+{math.min(n * 2, 30)}% luck`,
		`{tokens} tokens`,
	})
	statCard(UDim.new(0.5, 34), "AFTER RESURFACING", T.Gold, {
		`x{Formulas.RebirthMultiplier(n + 1)} Coins`,
		`+{math.min((n + 1) * 2, 30)}% luck`,
		`{tokens + 1} tokens`,
	})
	Kit.IconBadge(
		"arrow",
		T.Gold,
		52,
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4, Parent = compare }
	)

	-- Requirements: a tick or cross tile per requirement (drawn icons, no glyphs)
	local _, req = Kit.GameCard(T.Slab, { Size = UDim2.new(1, -8, 0, 128), LayoutOrder = 2, Parent = rebirthScroll })
	Kit.Title({
		Text = "Requirements",
		TextSize = 19,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.5, 0, 0, 24),
		TextWrapped = false,
		ZIndex = 3,
		Parent = req,
	})
	Kit.Pill(
		`Resurfaced {n}x`,
		T.PanelDark,
		{
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 10),
			TextSize = 13,
			ZIndex = 3,
			Parent = req,
		}
	)
	local function check(y: number, ok: boolean, text: string)
		Kit.IconBadge(
			if ok then "check" else "close",
			if ok then T.Good else T.Bad,
			30,
			{ Position = UDim2.fromOffset(14, y), ZIndex = 3, Parent = req }
		)
		Kit.Label({
			Text = text,
			Font = T.Bold,
			TextSize = 15,
			TextColor3 = if ok then T.Text else Kit.Lighten(T.Muted, 0.2),
			Position = UDim2.fromOffset(54, y),
			Size = UDim2.new(0, 260, 0, 30),
			TextWrapped = false,
			ZIndex = 3,
			Parent = req,
		})
	end
	check(40, suitOk, `Own the {Upgrades.Suits[Economy.Rebirth.RequiredSuit].Name} suit`)
	check(78, coinOk, "Earn lifetime Coins")
	local _, setReq = Kit.Bar({
		Position = UDim2.new(0, 230, 0, 81),
		Size = UDim2.new(1, -246, 0, 24),
		Color = if coinOk then T.Good else T.Gold,
		Parent = req,
	})
	setReq(lifetime / math.max(need, 1), nil, `{NumberFormat.short(lifetime)} / {NumberFormat.short(need)}`)

	-- The big button: gold and shining when ready, locked slate otherwise
	local _, btn = Kit.GameCard(
		if ready then T.Gold else Color3.fromRGB(46, 60, 82),
		{ Size = UDim2.new(1, -8, 0, 70), LayoutOrder = 3, Parent = rebirthScroll },
		function()
			Net.RequestRebirth:FireServer()
		end
	)
	local label = Kit.Title({
		Text = if ready then "RESURFACE!" else "RESURFACE",
		TextSize = 30,
		TextColor3 = if ready then Color3.new(1, 1, 1) else Kit.Lighten(T.Muted, 0.1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = btn,
	})
	Kit.AttachIcon(label, if ready then "rebirth" else "lock", label.TextColor3, 30)
	if ready then
		Kit.Shine(btn, 1)
	end

	-- Keep / resets
	local keep = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 116), LayoutOrder = 4, Parent = rebirthScroll }
	)
	local function chipCard(x: UDim, title: string, color: Color3, items)
		local _, c = Kit.GameCard(
			Kit.Darken(color, 0.78),
			{ Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.5, -5, 1, 0), Parent = keep }
		)
		Kit.Title({
			Text = title,
			TextSize = 16,
			TextColor3 = color,
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 22),
			ZIndex = 3,
			Parent = c,
		})
		pillCloud(c, items, color)
	end
	chipCard(
		UDim.new(0, 0),
		"YOU KEEP",
		T.Good,
		{ "Relics on stands", "Storage", "Codex", "Pearls", "Passes", "Level", "Display Slots" }
	)
	chipCard(UDim.new(0.5, 5), "RESETS", T.Bad, { "Coins", "Upgrades", "Suit", "Dive bag" })

	-- Talent tree: whole-card buttons like Upgrades
	header(rebirthScroll, 5, `Talent tree · {tokens} token{tokens == 1 and "" or "s"}`, T.Gold)
	local grid = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = rebirthScroll,
	})
	New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0, 132),
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local TALENT_ICONS = { StartNeoprene = "diver", ExtraBag = "bag", QuietDiver = "sonar", Lungs = "oxygen" }
	local purple = Color3.fromRGB(180, 140, 255)
	for i, t in Economy.Rebirth.Talents do
		local lvl = talents[t.Id] or 0
		local maxed = lvl >= t.Max
		local affordable = not maxed and tokens >= t.Cost
		local _, f = Kit.GameCard(
			if maxed then Kit.Darken(T.Gold, 0.55) else T.Slab,
			{ LayoutOrder = i, Parent = grid },
			function()
				Net.RequestTalent:FireServer(t.Id)
			end
		)
		if affordable then
			local st = f:FindFirstChildOfClass("UIStroke")
			st.Color, st.Thickness = T.Good, 3
		end
		Kit.IconBadge(
			TALENT_ICONS[t.Id] or "star",
			purple,
			50,
			{ Position = UDim2.fromOffset(10, 10), ZIndex = 3, Parent = f }
		)
		Kit.Title({
			Text = t.Name,
			TextSize = 18,
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -76, 0, 22),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = f,
		})
		Kit.Label({
			Text = t.Desc,
			Font = T.Bold,
			TextSize = 12,
			TextColor3 = T.Muted,
			Position = UDim2.fromOffset(68, 30),
			Size = UDim2.new(1, -76, 0, 30),
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
			Parent = f,
		})
		local pips = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 66),
			Size = UDim2.new(1, -24, 0, 12),
			ZIndex = 3,
			Parent = f,
		}, { Kit.List(4, true) })
		for p = 1, t.Max do
			New("Frame", {
				BackgroundColor3 = if p <= lvl then purple else T.PanelDark,
				Size = UDim2.new(1 / t.Max, -4, 1, 0),
				LayoutOrder = p,
				ZIndex = 3,
				Parent = pips,
			}, { Kit.Round(), Kit.Stroke(T.Outline, 1.5, 0) })
		end
		Kit.PricePlate(
			if maxed then "MAX" else `{t.Cost} token{t.Cost == 1 and "" or "s"}`,
			if maxed then T.Gold elseif affordable then T.Good else Color3.fromRGB(58, 74, 98),
			if maxed then "check" else "token",
			{
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 38),
				TextSize = 18,
				TextColor3 = if affordable or maxed then T.DarkText else Kit.Lighten(T.Muted, 0.2),
				Parent = f,
			}
		)
	end
end

------------------------------------------------------------------------------------------
-- Leaderboards: board tabs + podium + list
------------------------------------------------------------------------------------------
local lbScroll, lbPaintTabs
local lbBoard = "TotalValue"
local LB_TABS = {
	{ id = "TotalValue", text = "Dock", icon = "display", color = T.Gold },
	{ id = "Deepest", text = "Deepest", icon = "down", color = T.Accent },
	{ id = "Rebirths", text = "Resurface", icon = "rebirth", color = T.Accent },
	{ id = "Steals", text = "Steals", icon = "lock", color = T.Accent },
	{ id = "Codex", text = "Codex", icon = "codex", color = T.Accent },
}
local function renderLeaderboards()
	Kit.Clear(lbScroll)
	if lbPaintTabs then
		lbPaintTabs(lbBoard)
	end
	local board = leaderboardData[lbBoard]
	if not board then
		Kit.Label({
			Text = "Loading leaderboards…",
			TextColor3 = T.Muted,
			Font = T.Bold,
			LayoutOrder = 1,
			Parent = lbScroll,
		})
		return
	end
	local rows = board.Rows or {}
	-- Podium (2nd, 1st, 3rd)
	-- tall enough for the 1st-place medal above the highest block (it was clipped at 190)
	local podium = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 236), LayoutOrder = 1, Parent = lbScroll }
	)
	local spots = {
		{ rank = 2, x = 0, h = 110, color = Color3.fromRGB(200, 210, 225), medal = "2" },
		{ rank = 1, x = 1, h = 140, color = T.Gold, medal = "1" },
		{ rank = 3, x = 2, h = 90, color = Color3.fromRGB(215, 140, 80), medal = "3" },
	}
	for _, spot in spots do
		local r = rows[spot.rank]
		local col = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(spot.x / 3, 4, 0, 0),
			Size = UDim2.new(1 / 3, -8, 1, 0),
			Parent = podium,
		})
		local _, block = Kit.GameCard(Kit.Darken(spot.color, 0.2), {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, spot.h + 6),
			Lip = 8,
			Parent = col,
		})
		Kit.Title({
			Text = tostring(spot.rank),
			TextSize = 44,
			TextTransparency = 0.5,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 50),
			Parent = block,
		})
		Kit.Title({
			Text = if r then r.Value else "—",
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 8),
			Size = UDim2.new(1, -8, 0, 22),
			TextScaled = true,
			Parent = block,
		})
		local medal = Kit.IconBadge(
			if spot.rank == 1 then "crown" else spot.medal,
			spot.color,
			if spot.rank == 1 then 54 else 46,
			{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -spot.h - 24), Parent = col }
		)
		medal:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
		Kit.Title({
			Text = if r then r.Name else "Open spot",
			TextSize = 15,
			TextColor3 = if r then T.Text else T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -spot.h - 2),
			Size = UDim2.new(1, 0, 0, 20),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = col,
		})
	end
	-- Ranks 4-10 always show (open spots dimmed), so the board never looks empty
	for i = 4, math.max(#rows, 10) do
		local r = rows[i] or { Rank = i, Name = "Open spot", Value = "—", Open = true }
		local _, card = Kit.GameCard(if r.Open then Color3.fromRGB(22, 36, 56) else T.Slab, {
			Size = UDim2.new(1, -8, 0, 50),
			Lip = 4,
			LayoutOrder = i,
			Parent = lbScroll,
		})
		if r.Name == player.Name or r.Name == player.DisplayName then
			local st = card:FindFirstChildOfClass("UIStroke")
			st.Color, st.Thickness = T.Accent, 3
		end
		Kit.Pill(`#{r.Rank}`, T.PanelDark, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			TextSize = 14,
			Size = UDim2.fromOffset(0, 26),
			Parent = card,
		})
		Kit.Title({
			Text = r.Name,
			TextSize = 17,
			TextColor3 = if r.Open then T.Muted else T.Text,
			Position = UDim2.fromOffset(70, 0),
			Size = UDim2.new(1, -200, 1, 0),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		Kit.Title({
			Text = r.Value,
			TextSize = 16,
			TextColor3 = T.Gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.fromOffset(130, 46),
			Parent = card,
		})
	end
end

local function buildLeaderboards(body: Frame)
	local tabScroll = Kit.Scroll({
		Size = UDim2.new(1, 0, 0, 50),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		Parent = body,
	})
	local _, paint = Kit.Tabs(tabScroll, LB_TABS, lbBoard, function(id)
		lbBoard = id
		renderLeaderboards()
	end, { Size = UDim2.new(0, 0, 0, 48), AutomaticSize = Enum.AutomaticSize.X, TabWidth = 150 })
	lbPaintTabs = paint
	lbScroll = scrollBody(body, 60)
	local pad = lbScroll:FindFirstChildOfClass("UIPadding") :: UIPadding
	pad.PaddingTop, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
end

------------------------------------------------------------------------------------------
-- Players (trade / party)
------------------------------------------------------------------------------------------
local function avatar(userId: number, size: number, props)
	local img = New("ImageLabel", {
		BackgroundColor3 = T.PanelDark,
		Image = `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`,
		Size = UDim2.fromOffset(size, size),
	}, { Kit.Round(), Kit.Stroke(T.Accent, 2, 0.1) })
	for k, v in props or {} do
		(img :: any)[k] = v
	end
	return img
end

local playersScroll
local partyNames: { string } = {}

-- Roblox's own "invite friends" sheet (fails quietly where invites aren't allowed)
local function inviteFriends()
	local SocialService = game:GetService("SocialService")
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		controllers.UIController.Toast("Invites aren't available right now.", "error")
	end
end

local function renderPlayers()
	Kit.Clear(playersScroll)
	local order = 0
	-- Perks strip: what friends and parties give, and the party controls
	local _, top = Kit.GameCard(
		Kit.Darken(Icons.Colors.Players, 0.72),
		{ Size = UDim2.new(1, -8, 0, 74), LayoutOrder = 0, Parent = playersScroll }
	)
	local perks = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -200, 1, 0),
		ZIndex = 3,
		Parent = top,
	})
	local pl = Kit.List(6, false)
	pl.VerticalAlignment = Enum.VerticalAlignment.Center
	pl.Parent = perks
	Kit.Pill("+10% Coins per friend here", Kit.Darken(T.Gold, 0.6), {
		Icon = "coin",
		TextColor3 = T.Gold,
		TextSize = 13,
		Size = UDim2.fromOffset(0, 26),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = perks,
	})
	Kit.Pill("Party: shared sonar + 10% luck", Kit.Darken(T.Accent, 0.6), {
		Icon = "sonar",
		TextColor3 = T.Accent,
		TextSize = 13,
		Size = UDim2.fromOffset(0, 26),
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = perks,
	})
	if #partyNames > 0 then
		Kit.Button("Leave party", T.Bad, function()
			Net.PartyLeave:FireServer()
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(160, 46),
			TextSize = 15,
			ZIndex = 3,
			Parent = top,
		})
	else
		Kit.Button("Invite friends", T.Good, inviteFriends, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 46),
			TextSize = 15,
			Icon = "plus",
			ZIndex = 3,
			Parent = top,
		})
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			order += 1
			local inParty = table.find(partyNames, other.DisplayName) ~= nil
				or table.find(partyNames, other.Name) ~= nil
			local _, r =
				Kit.GameCard(T.Slab, { Size = UDim2.new(1, -8, 0, 76), LayoutOrder = order, Parent = playersScroll })
			if inParty then
				local st = r:FindFirstChildOfClass("UIStroke")
				st.Color, st.Thickness = T.Accent, 3
			end
			avatar(
				other.UserId,
				54,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 3, Parent = r }
			)
			Kit.Title({
				Text = other.DisplayName,
				TextSize = 19,
				Position = UDim2.fromOffset(76, 12),
				Size = UDim2.new(1, -350, 0, 24),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
				Parent = r,
			})
			Kit.Label({
				Text = if inParty then "In your party" else `@{other.Name}`,
				Font = T.Bold,
				TextColor3 = if inParty then T.Accent else T.Muted,
				TextSize = 13,
				Position = UDim2.fromOffset(76, 38),
				Size = UDim2.new(1, -350, 0, 16),
				TextWrapped = false,
				ZIndex = 3,
				Parent = r,
			})
			if not inParty then
				Kit.Button("Party", T.Accent, function()
					Net.PartyInvite:FireServer(other.UserId)
					controllers.UIController.Toast(`Party invite sent to {other.DisplayName}`, "info")
				end, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -144, 0.5, 0),
					Size = UDim2.fromOffset(122, 48),
					Icon = "friends",
					ZIndex = 3,
					Parent = r,
				})
			end
			Kit.Button("Trade", T.Gold, function()
				Net.TradeRequest:FireServer(other.UserId)
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(122, 48),
				Icon = "trade",
				ZIndex = 3,
				Parent = r,
			})
		end
	end
	if order == 0 then
		local _, empty =
			Kit.GameCard(T.PanelDark, { Size = UDim2.new(1, -8, 0, 250), LayoutOrder = 1, Parent = playersScroll })
		Kit.IconBadge(
			"friends",
			Icons.Colors.Players,
			84,
			{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), ZIndex = 3, Parent = empty }
		)
		Kit.Title({
			Text = "Nobody else is here yet",
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 118),
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 3,
			Parent = empty,
		})
		Kit.Label({
			Text = "Bring your friends: each one in the server gives you +10% Coins, and you can party up to share sonar pings.",
			Font = T.Bold,
			TextSize = 14,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0.5, -230, 0, 152),
			Size = UDim2.fromOffset(460, 36),
			ZIndex = 3,
			Parent = empty,
		})
		Kit.Button("Invite friends", T.Good, inviteFriends, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 192),
			Size = UDim2.fromOffset(210, 46),
			TextSize = 16,
			Icon = "plus",
			ZIndex = 3,
			Parent = empty,
		})
	end
end

------------------------------------------------------------------------------------------
-- Trade window: side-by-side offers as relic cards, storage picker grid
------------------------------------------------------------------------------------------
local tradeScroll
local function tradeGrid(parent: Instance, order: number, cell: Vector2?)
	local f = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.Grid(cell or Vector2.new(96, 122), 6).Parent = f
	return f
end

local function renderTrade()
	Kit.Clear(tradeScroll)
	local st = tradeState
	if not st then
		Kit.Label({ Text = "No active trade.", TextColor3 = T.Muted, Parent = tradeScroll })
		return
	end
	local order = 0
	local function o()
		order += 1
		return order
	end
	local banner = row(tradeScroll, o(), 50)
	Kit.Title({
		Text = `Trading with {st.Partner}`,
		TextSize = 18,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -200, 1, 0),
		TextWrapped = false,
		Parent = banner,
	})
	if st.Countdown then
		Kit.Pill(`Completing in {math.ceil(st.Countdown)}s`, T.Good, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			TextSize = 15,
			Size = UDim2.fromOffset(0, 30),
			Parent = banner,
		})
	end

	local sides = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = o(),
		Parent = tradeScroll,
	})
	local function side(x: UDim, title: string, relics, confirmed: boolean)
		local c = Kit.Card({
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.new(0.5, -4, 0, 170),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = T.PanelDark,
			Parent = sides,
		})
		local s = c:FindFirstChildOfClass("UIStroke")
		s.Color, s.Transparency, s.Thickness = if confirmed then T.Good else T.PanelLight, 0.05, 2
		Kit.Title({
			Text = title,
			TextSize = 15,
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -110, 0, 20),
			Parent = c,
		})
		Kit.Pill(
			if confirmed then "✓ Ready" else "Not ready",
			if confirmed then T.Good else T.PanelLight,
			{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Parent = c }
		)
		local g = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 32),
			Size = UDim2.new(1, -16, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = c,
		}, { New("UIPadding", { PaddingBottom = UDim.new(0, 8) }) })
		Kit.Grid(Vector2.new(84, 108), 6).Parent = g
		for i, relic in relics do
			RelicCard.new({ Relic = relic, Size = UDim2.fromOffset(84, 108), LayoutOrder = i, Parent = g })
		end
		if #relics == 0 then
			Kit.Label({ Text = "Nothing offered yet", TextColor3 = T.Muted, TextSize = 13, Parent = g })
		end
	end
	side(UDim.new(0, 0), "Your offer", st.MyOffer, st.MyConfirm == true)
	side(UDim.new(0.5, 4), `{st.Partner}'s offer`, st.TheirOffer, st.TheirConfirm == true)

	local actions = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 52), LayoutOrder = o(), Parent = tradeScroll },
		{ Kit.List(8, true, Enum.HorizontalAlignment.Center) }
	)
	Kit.Button("Confirm", T.Good, function()
		Net.TradeConfirm:FireServer()
	end, { Size = UDim2.fromOffset(160, 48), Icon = "check", Parent = actions })
	Kit.Button("Cancel", T.BadDeep, function()
		Net.TradeCancel:FireServer()
	end, { Size = UDim2.fromOffset(160, 48), Parent = actions })

	header(tradeScroll, o(), "Tap relics to offer (max 8). Changing the offer resets both confirmations.")
	local picker = tradeGrid(tradeScroll, o())
	local i = 0
	for _, relic in S.Get("Storage") or {} do
		if not relic.locked then
			i += 1
			local selected = tradeSelection[relic.uid] == true
			RelicCard.new({
				Relic = relic,
				Size = UDim2.fromOffset(96, 122),
				Selected = selected,
				LayoutOrder = if selected then i else i + 1000,
				OnClick = function()
					tradeSelection[relic.uid] = not selected or nil
					local uids = {}
					for uid in tradeSelection do
						table.insert(uids, uid)
					end
					Net.TradeSetOffer:FireServer(uids)
				end,
				Parent = picker,
			})
		end
	end
	if i == 0 then
		Kit.Label({ Text = "No unlocked relics in storage.", TextColor3 = T.Muted, Parent = picker })
	end
end

------------------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------------------
local settingsScroll

-- On/off switch (Settings, Diver window)
-- Chunky ON/OFF switch: a raised pill with a knob and the state written on it
local function toggle(parent: Instance, on: boolean, onChange: (boolean) -> (), props)
	local track = New("TextButton", {
		Text = if on then "ON" else "OFF",
		Font = T.Title,
		TextSize = 16,
		TextColor3 = if on then T.DarkText else T.Muted,
		TextXAlignment = if on then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		AutoButtonColor = false,
		BackgroundColor3 = if on then T.Good else Color3.fromRGB(40, 54, 76),
		Size = UDim2.fromOffset(88, 40),
		ZIndex = 3,
		Parent = parent,
	}, {
		Kit.Round(),
		Kit.Stroke(T.Outline, 2, 0),
		New("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 12) }),
	})
	Kit.Bevel(track, 40, 4)
	for k, v in props or {} do
		(track :: any)[k] = v
	end
	New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(if on then 1 else 0, if on then -8 else -6, 0.5, -1),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 4,
		Parent = track,
	}, { Kit.Round(), Kit.Stroke(T.Outline, 2, 0) })
	Kit.Juice(track)
	track.Activated:Connect(function()
		onChange(not on)
	end)
	return track
end

-- Raised row: coloured icon tile, title and subtitle, controls on the right
local function settingRow(
	parent: Instance,
	order: number,
	title: string,
	subtitle: string?,
	icon: string?,
	color: Color3?,
	reserve: number? -- width kept free on the right for controls
)
	local right = reserve or 250
	local _, r = Kit.GameCard(T.Slab, { Size = UDim2.new(1, -8, 0, 66), Lip = 4, LayoutOrder = order, Parent = parent })
	local x = 14
	if icon then
		Kit.IconBadge(
			icon,
			color or T.Accent,
			44,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 3, Parent = r }
		)
		x = 66
	end
	Kit.Title({
		Text = title,
		TextSize = 18,
		Position = UDim2.fromOffset(x, if subtitle then 9 else 0),
		Size = UDim2.new(1, -(x + right), 0, if subtitle then 24 else 62),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = r,
	})
	if subtitle then
		Kit.Label({
			Text = subtitle,
			Font = T.Bold,
			TextSize = 12,
			TextColor3 = T.Muted,
			Position = UDim2.fromOffset(x, 35),
			Size = UDim2.new(1, -(x + right), 0, 16),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = r,
		})
	end
	return r
end

local CONTROLS = {
	{ "WASD", "Swim" },
	{ "Space", "Up" },
	{ "Ctrl / C", "Down" },
	{ "Shift", "Boost" },
	{ "Q", "Sonar" },
	{ "G", "Flare" },
	{ "R", "Home" },
	{ "B", "Bag" },
	{ "U", "Upgrades" },
	{ "M", "Shop" },
}

local function renderSettings()
	Kit.Clear(settingsScroll)
	local settings = table.clone(S.Get("Settings") or { Music = 0.6, SFX = 0.8, LowScare = false })
	local function save()
		Net.UpdateSettings:FireServer(settings)
	end
	header(settingsScroll, 1, "Sound", T.Accent)
	-- Volume: -/+ buttons around a 10-segment meter and a percent readout
	local function volume(order: number, label: string, key: string, icon: string)
		local r = settingRow(settingsScroll, order, label, nil, icon, T.Accent)
		local level = math.round((settings[key] or 0) * 10)
		local meter = New("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -112, 0.5, 0),
			Size = UDim2.fromOffset(150, 26),
			ZIndex = 3,
			Parent = r,
		}, { Kit.List(3, true) })
		for i = 1, 10 do
			New("Frame", {
				BackgroundColor3 = if i <= level then T.Accent else T.PanelDark,
				Size = UDim2.fromOffset(12, 10 + i * 1.6),
				LayoutOrder = i,
				ZIndex = 3,
				Parent = meter,
			}, { Kit.Corner(3), Kit.Stroke(T.Outline, 1.5, 0) })
		end
		Kit.Title({
			Text = `{level * 10}%`,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -270, 0.5, 0),
			Size = UDim2.fromOffset(50, 24),
			ZIndex = 3,
			Parent = r,
		})
		Kit.Button("−", T.Slab, function()
			settings[key] = math.max(0, (level - 1) / 10)
			save()
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -60, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			TextSize = 24,
			Font = T.Title,
			ZIndex = 3,
			Parent = r,
		})
		Kit.Button("+", T.Accent, function()
			settings[key] = math.min(1, (level + 1) / 10)
			save()
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(44, 44),
			TextSize = 24,
			Font = T.Title,
			ZIndex = 3,
			Parent = r,
		})
	end
	volume(2, "Music", "Music", "music")
	volume(3, "Sound effects", "SFX", "bell")

	header(settingsScroll, 4, "Gameplay", T.Good)
	local ls =
		settingRow(settingsScroll, 5, "Lower jump scares", "Softer Leviathan warnings and effects", "eye", T.Good)
	toggle(ls, settings.LowScare == true, function(v)
		settings.LowScare = v
		save()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0) })
	local diverRow =
		settingRow(settingsScroll, 6, "Diver appearance", "Show or hide helmet, tank, fins and gear", "diver", T.Good)
	Kit.Button("Customize", T.Accent, function()
		controllers.UIController.Open("Diver")
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(140, 44),
		Icon = "diver",
		ZIndex = 3,
		Parent = diverRow,
	})

	header(settingsScroll, 7, "Codes & dock", T.Gold)
	local function inputRow(
		order: number,
		placeholder: string,
		buttonText: string,
		buttonColor: Color3,
		icon: string,
		onSubmit: (string) -> ()
	)
		local _, r = Kit.GameCard(
			T.Slab,
			{ Size = UDim2.new(1, -8, 0, 66), Lip = 4, LayoutOrder = order, Parent = settingsScroll }
		)
		Kit.IconBadge(
			icon,
			buttonColor,
			44,
			{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 3, Parent = r }
		)
		local box = New("TextBox", {
			PlaceholderText = placeholder,
			PlaceholderColor3 = T.Muted,
			Text = "",
			ClearTextOnFocus = false,
			BackgroundColor3 = T.PanelDark,
			TextColor3 = T.Text,
			Font = T.Bold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 66, 0.5, 0),
			Size = UDim2.new(1, -220, 0, 44),
			ZIndex = 3,
			Parent = r,
		}, { Kit.Corner(10), Kit.Stroke(T.Outline, 2, 0), New("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
		Kit.Button(buttonText, buttonColor, function()
			onSubmit(box.Text)
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(128, 44),
			TextSize = 16,
			ZIndex = 3,
			Parent = r,
		})
	end
	inputRow(8, "Enter code", "Redeem", T.Accent, "gift", function(text)
		Net.RequestRedeemCode:FireServer(text)
	end)
	inputRow(9, `Dock name ({S.Get("RenameTokens") or 0} rename tokens)`, "Rename", T.Gold, "sign", function(text)
		Net.RenameDock:FireServer(text)
	end)

	-- Controls as key caps instead of one long sentence
	header(settingsScroll, 10, "Controls", Color3.fromRGB(180, 140, 255))
	local keys = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 11,
		Parent = settingsScroll,
	})
	New("UIGridLayout", {
		CellSize = UDim2.new(0.2, -6, 0, 58),
		CellPadding = UDim2.fromOffset(7, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = keys,
	})
	for i, c in CONTROLS do
		local cell = New("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = keys })
		Kit.Pill(c[1], Color3.fromRGB(225, 232, 245), {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			TextSize = 14,
			Size = UDim2.fromOffset(0, 28),
			Parent = cell,
		})
		Kit.Label({
			Text = c[2],
			Font = T.Bold,
			TextSize = 13,
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 18),
			Parent = cell,
		})
	end
	Kit.Label({
		Text = "Graphics quality follows your Roblox settings (Esc, then Settings).",
		Font = T.Bold,
		TextColor3 = T.Muted,
		TextSize = 12,
		LayoutOrder = 12,
		Size = UDim2.new(1, -8, 0, 30),
		Parent = settingsScroll,
	})
end

------------------------------------------------------------------------------------------
-- Diver window: suit tiers, live avatar preview, show/hide each part (UI design "Diver")
------------------------------------------------------------------------------------------
local diver = {
	body = nil :: Frame?,
	stage = nil :: Frame?,
	list = nil :: ScrollingFrame?,
	spin = nil :: RBXScriptConnection?,
	previewToken = 0,
	previewKey = "",
	suitName = nil :: TextLabel?,
	suitDesc = nil :: TextLabel?,
}

local SUIT_DESC = {
	"Mask, snorkel and short fins.",
	"Single tank, long fins and a dive computer.",
	"Brass helmet, twin tanks and a chest plate.",
	"Steel helmet, armour and weighted boots.",
	"Armoured rig with a glowing visor and headlamps.",
	"Gold heavy suit. Coming soon.",
}

local PART_TOGGLES = {
	{ "SuitHelmet", "Helmet", nil },
	{ "SuitTank", "Air tank", nil },
	{ "SuitFins", "Fins & boots", nil },
	{ "SuitGear", "Gloves & armour", nil },
	{ "SuitColors", "Wetsuit colours", "Off keeps your own avatar outfit" },
}

-- Clone the local character into a viewport (shows exactly what others see)
local function refreshDiverPreview()
	local stage = diver.stage
	if not stage then
		return
	end
	diver.previewToken += 1
	local token = diver.previewToken
	task.delay(0.6, function() -- let the server finish re-dressing after a change
		if token ~= diver.previewToken or not stage.Parent then
			return
		end
		Kit.Clear(stage)
		local char = player.Character
		if not char then
			return
		end
		local was = char.Archivable
		char.Archivable = true
		local clone = char:Clone()
		char.Archivable = was
		if not clone then
			return
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
				d:Destroy()
			end
		end
		local vpf = New("ViewportFrame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(150, 155, 170),
			LightColor = Color3.fromRGB(255, 250, 240),
			LightDirection = Vector3.new(-0.5, -1, -0.8),
			Parent = stage,
		})
		local world = New("WorldModel", { Parent = vpf })
		clone.Parent = world
		local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
		local base = if root then root.CFrame else clone:GetPivot()
		local cf, size = clone:GetBoundingBox()
		local cam = New("Camera", { FieldOfView = 30, Parent = vpf })
		vpf.CurrentCamera = cam
		local dist = math.max(size.Y, size.X) / math.tan(math.rad(15)) * 0.62
		local center = cf.Position
		if diver.spin then
			diver.spin:Disconnect()
		end
		local t0 = os.clock()
		diver.spin = game:GetService("RunService").RenderStepped:Connect(function()
			if not vpf.Parent then
				diver.spin:Disconnect()
				return
			end
			local a = (os.clock() - t0) * 0.6 + math.pi
			local dir = (base.LookVector * math.cos(a) + base.RightVector * math.sin(a)).Unit
			cam.CFrame = CFrame.lookAt(center + dir * dist + Vector3.new(0, size.Y * 0.08, 0), center)
		end)
	end)
end

local function renderDiver()
	local list = diver.list
	if not list then
		return
	end
	Kit.Clear(list)
	local suitIndex = S.Get("Suit") or 1
	local coins = S.Get("Coins") or 0
	local settings = table.clone(S.Get("Settings") or {})
	diver.suitName.Text = Upgrades.Suits[suitIndex].Name
	diver.suitDesc.Text =
		`{SUIT_DESC[suitIndex] or ""} Safe down to {Zones.List[math.min(suitIndex, #Zones.List)].Name}.`

	header(list, 1, "Suits")
	local tiles =
		New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 84), LayoutOrder = 2, Parent = list })
	local g = New("UIGridLayout", {
		CellSize = UDim2.new(1 / 6, -7, 0, 80),
		CellPadding = UDim2.fromOffset(8, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tiles,
	})
	g.FillDirectionMaxCells = 6
	for i, suit in Upgrades.Suits do
		local owned = i <= suitIndex
		local isNext = i == suitIndex + 1
		local tile = New("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if owned then T.PanelLight else T.PanelDark,
			LayoutOrder = i,
			Parent = tiles,
		}, { Kit.Corner(12) })
		Kit.Stroke(
			if i == suitIndex then T.Accent else T.Text,
			if i == suitIndex then 2 else 1,
			if i == suitIndex then 0 else 0.85
		).Parent =
			tile
		New("Frame", {
			BackgroundColor3 = suit.Color,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.fromOffset(26, 26),
		}, { Kit.Round() }).Parent =
			tile
		Kit.Label({
			Text = if owned
				then suit.Name:gsub("Pressure ", "")
				elseif suit.ComingSoon then "Soon"
				else NumberFormat.short(suit.Cost),
			Font = T.Bold,
			TextSize = 10,
			TextColor3 = if owned then T.Text elseif isNext and coins >= suit.Cost then T.Gold else T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 2, 1, -28),
			Size = UDim2.new(1, -4, 0, 22),
			TextWrapped = true,
			Parent = tile,
		})
		Kit.Juice(tile)
		tile.Activated:Connect(function()
			if isNext and not suit.ComingSoon then
				Net.RequestBuySuit:FireServer()
			elseif not owned then
				controllers.UIController.Toast("Buy the suits in order: the next one unlocks first.", "info")
			end
		end)
	end

	header(list, 3, "Show on my diver")
	for i, entry in PART_TOGGLES do
		local key, label, sub = entry[1], entry[2], entry[3]
		local r = settingRow(list, 3 + i, label, sub, nil, nil, 112)
		toggle(r, settings[key] ~= false, function(v)
			settings[key] = v
			Net.UpdateSettings:FireServer(settings)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
	end
	-- Re-clone the avatar only when what it wears changed (or the stage is empty)
	local key = tostring(suitIndex)
	for _, entry in PART_TOGGLES do
		key ..= if settings[entry[1]] == false then "0" else "1"
	end
	if key ~= diver.previewKey or #diver.stage:GetChildren() <= 2 then
		diver.previewKey = key
		refreshDiverPreview()
	end
end

local function buildDiver(body: Frame)
	diver.body = body
	local left = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 280, 1, 0), Parent = body })
	diver.stage = Kit.Card({
		BackgroundColor3 = T.PanelDark,
		Size = UDim2.new(1, 0, 1, -76),
		ClipsDescendants = true,
		Parent = left,
	})
	Kit.Label({
		Text = "CURRENT SUIT",
		Font = T.Bold,
		TextSize = 11,
		TextColor3 = Kit.Lighten(T.Accent, 0.35),
		Position = UDim2.new(0, 2, 1, -70),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = left,
	})
	diver.suitName = Kit.Title({
		Text = "",
		TextSize = 22,
		Position = UDim2.new(0, 2, 1, -54),
		Size = UDim2.new(1, 0, 0, 26),
		TextWrapped = false,
		Parent = left,
	})
	diver.suitDesc = Kit.Label({
		Text = "",
		TextSize = 12,
		TextColor3 = T.Muted,
		Position = UDim2.new(0, 2, 1, -28),
		Size = UDim2.new(1, 0, 0, 30),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = left,
	})
	diver.list = Kit.Scroll({ Position = UDim2.fromOffset(296, 0), Size = UDim2.new(1, -296, 1, 0), Parent = body })
	Kit.List(6).Parent = diver.list
end

------------------------------------------------------------------------------------------
function MenuController.Start()
	local UI = controllers.UIController
	UI.RegisterWindow("Bag", "Bag & Dock", buildBag, renderBag)
	UI.RegisterWindow("Upgrades", "Upgrades", function(body)
		upScroll = scrollBody(body)
		local pad = upScroll:FindFirstChildOfClass("UIPadding") :: UIPadding
		pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 4), UDim.new(0, 6)
		upScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			UI.Refresh("Upgrades") -- column count follows the window width
		end)
	end, renderUpgrades)
	UI.RegisterWindow("Codex", "Codex", buildCodex, renderCodex)
	UI.RegisterWindow("Quests", "Quests & Tide Pass", function(body)
		questScroll = scrollBody(body)
	end, renderQuests)
	UI.RegisterWindow("Rebirth", "Resurface", function(body)
		rebirthScroll = scrollBody(body)
	end, renderRebirth)
	UI.RegisterWindow("Leaderboards", "Leaderboards", buildLeaderboards, renderLeaderboards)
	UI.RegisterWindow("Players", "Players", function(body)
		playersScroll = scrollBody(body)
	end, renderPlayers)
	UI.RegisterWindow("Trade", "Trade", function(body)
		tradeScroll = scrollBody(body)
	end, renderTrade)
	UI.RegisterWindow("Diver", "Diver", buildDiver, renderDiver)
	UI.RegisterWindow("Settings", "Settings", function(body)
		settingsScroll = scrollBody(body)
	end, renderSettings)

	S.Changed:Connect(function(keys)
		if keys.Bag or keys.Storage or keys.Stands or keys.Vault or keys.Derived or keys.IncomePerSecond then
			UI.Refresh("Bag")
		end
		if keys.Upgrades or keys.Coins or keys.Suit or keys.Derived then
			UI.Refresh("Upgrades")
		end
		if keys.Codex then
			UI.Refresh("Codex")
		end
		if keys.Quests or keys.TidePass or keys.LastDailyClaimDay then
			UI.Refresh("Quests")
		end
		if keys.Rebirths or keys.Talents or keys.RebirthTokens or keys.LifetimeCoins then
			UI.Refresh("Rebirth")
		end
		if keys.Settings or keys.RenameTokens then
			UI.Refresh("Settings")
		end
		if keys.Settings or keys.Suit then
			UI.Refresh("Diver")
		end
		if keys.Storage then
			UI.Refresh("Trade")
		end
	end)
	Net.Leaderboards.OnClientEvent:Connect(function(data)
		leaderboardData = data
		UI.Refresh("Leaderboards")
	end)
	Net.TradeUpdated.OnClientEvent:Connect(function(st)
		if st.Kind == "Invite" then
			controllers.OfferController.Confirm(`{st.From} wants to trade with you.`, "Accept", function(accepted)
				Net.TradeRespond:FireServer(st.FromUserId, accepted)
			end)
		elseif st.Kind == "Session" then
			tradeState = st
			if not UI.IsOpen("Trade") then
				tradeSelection = {}
				UI.Open("Trade")
			else
				renderTrade()
			end
		elseif st.Kind == "Closed" then
			tradeState = nil
			tradeSelection = {}
			UI.Toast(st.Reason, "info")
			if UI.IsOpen("Trade") then
				UI.Close()
			end
		end
	end)
	Net.PartyUpdated.OnClientEvent:Connect(function(info)
		if info.Invite then
			controllers.OfferController.Confirm(
				`{info.Invite} invited you to a Dive Party (+10% luck each).`,
				"Join",
				function(accepted)
					Net.PartyRespond:FireServer(accepted)
				end
			)
		elseif info.Members then
			local names = {}
			for _, m in info.Members do
				table.insert(names, m.Name)
			end
			partyNames = names
			UI.Refresh("Players")
			UI.Toast(if #names > 0 then "Party: " .. table.concat(names, ", ") else "You left the party.", "info")
		end
	end)
	Players.PlayerAdded:Connect(function()
		UI.Refresh("Players")
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(UI.Refresh, "Players")
	end)
end

return MenuController
