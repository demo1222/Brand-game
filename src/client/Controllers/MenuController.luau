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

local function relicLine(relic): string
	local def = Relics.ById[relic.id]
	local mut = if #relic.mutations > 0 then table.concat(relic.mutations, " ") .. " " else ""
	local huge = if relic.size >= 1.35 then "HUGE " else ""
	return `{huge}{mut}{def.Name}`
end

local function row(parent: Instance, order: number, height: number?)
	return Kit.Card({
		Size = UDim2.new(1, -8, 0, height or 56),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function header(parent: Instance, order: number, text: string)
	return Kit.Header(parent, order, text)
end

local function scrollBody(body: Frame, top: number?)
	local scroll = Kit.Scroll({ Position = UDim2.fromOffset(0, top or 0), Size = UDim2.new(1, 0, 1, -(top or 0)), Parent = body })
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
	return `{Icons.Get("Coins")} {NumberFormat.short(n)}`
end

------------------------------------------------------------------------------------------
-- Bag / Dock Manager: card grid + detail panel
------------------------------------------------------------------------------------------
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
	local parts = { bag.tab or "", bag.sort, bag.selected or "", tostring(mult), tostring(S.Derived("VaultCount") or 0) }
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
		Kit.Label({
			Text = "Tap a relic to inspect it",
			TextColor3 = T.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = T.Bold,
			Size = UDim2.new(1, 0, 0, 60),
			LayoutOrder = 1,
			Parent = panel,
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
	RelicView.new({ Relic = relic, Spin = 35, ZIndex = 2, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), Parent = stage })
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

	local stats = Kit.Card({ Size = UDim2.new(1, 0, 0, 62), LayoutOrder = 4, Parent = panel }, { Kit.Padding(6), Kit.List(2) })
	local cps = Formulas.RelicCPS(relic) * mult
	for i, line in {
		`{Icons.Get("Income")} +{NumberFormat.short(cps)} Coins/s on display`,
		`{Icons.Get("Sell")} Sells for {NumberFormat.short(Formulas.SellPrice(relic, mult))}`,
		`📏 Size {relic.size}x · Zone {def.Zone}`,
	} do
		Kit.Label({ Text = line, TextSize = 13, Font = T.Bold, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = i, TextWrapped = false, Parent = stats })
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
	local grid = Kit.Grid(Vector2.new(104, 44), 6)
	grid.Parent = actions
	local function act(text: string, color: Color3, fn)
		Kit.Button(text, color, fn, { TextSize = 14, Parent = actions })
	end
	if item.where == "Stands" or item.where == "Vault" then
		act(`{Icons.Get("Take")} Take`, T.PanelLight, function()
			bag.selected = nil
			Net.RequestPickupRelic:FireServer(tonumber(item.slot), item.where == "Vault")
		end)
		return
	end
	act(`{Icons.Get("Display")} Display`, T.Good, function()
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
		act(`{Icons.Get("Vault")} Vault`, T.Gold, function()
			bag.selected = nil
			placeInVault(relic)
		end)
	end
	act(if relic.locked then "🔓 Unlock" else `{Icons.Get("Lock")} Lock`, T.PanelLight, function()
		Net.RequestToggleLock:FireServer(relic.uid)
	end)
	if not relic.locked then
		act(`{Icons.Get("Sell")} Sell`, T.Bad, function()
			bag.selected = nil
			Net.RequestSell:FireServer(relic.uid)
		end)
	end
	if table.find(relic.mutations, "Barnacled") then
		act(`{Icons.Get("Clean")} Clean`, Color3.fromRGB(150, 130, 100), function()
			Net.RequestCleanBarnacle:FireServer(relic.uid)
		end)
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
	bagRefs.tabCaption.Bag.Text = `{Icons.Get("Bag")} Bag {#bagList}/{S.Derived("BagSize") or 3}`
	bagRefs.tabCaption.Storage.Text = `📦 Storage {storageN}`
	bagRefs.tabCaption.Display.Text = `{Icons.Get("Display")} Dock {displayN}`
	bagRefs.paintTabs(bag.tab)
	bagRefs.sortButton.Text = `⇅ {bag.sort}`
	bagRefs.sellCommons.Visible = bag.tab == "Storage"
	bagRefs.hint.Text = if bag.tab == "Bag"
		then "⚠ Bag relics are lost if you die. Swim home to secure them!"
		elseif bag.tab == "Display" then `{Icons.Get("Income")} Your dock earns +{NumberFormat.short(S.Get("IncomePerSecond") or 0)}/s`
		else "Display your best relics to earn Coins while you dive."
	bagRefs.hint.TextColor3 = if bag.tab == "Bag" then T.Gold else T.Muted
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
			Subtitle = `+{NumberFormat.short(Formulas.RelicCPS(it.relic) * mult)}/s`,
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
	if #items == 0 then
		Kit.Label({
			Text = if bag.tab == "Bag" then "Your dive bag is empty.\nDive and salvage glinting relics!"
				elseif bag.tab == "Storage" then "No relics in storage yet."
				else "Nothing on display. Pick a relic in Storage and tap Display.",
			TextColor3 = T.Muted,
			Font = T.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(300, 60),
			Parent = bagRefs.grid,
		})
	end
	if bag.selected and not selectedItem then
		bag.selected = nil
	end
	renderDetail(selectedItem, mult)
end

local function buildBag(body: Frame)
	bagRefs.tabCaption = {}
	local tabsFrame, paint = Kit.Tabs(body, {
		{ id = "Bag", text = "Bag", color = Color3.fromRGB(60, 160, 255) },
		{ id = "Storage", text = "Storage", color = T.Accent },
		{ id = "Display", text = "Dock", color = T.Gold },
	}, "Storage", function(id)
		bag.tab = id
		bag.selected = nil
		bag.sig = ""
		renderBag()
	end, { Size = UDim2.new(1, -250, 0, 44) })
	bagRefs.paintTabs = paint
	for _, b in tabsFrame:GetChildren() do
		if b:IsA("TextButton") then
			b.TextSize = 13
		end
	end
	local order = {}
	for _, b in tabsFrame:GetChildren() do
		if b:IsA("TextButton") then
			order[b.LayoutOrder] = b
		end
	end
	bagRefs.tabCaption.Bag, bagRefs.tabCaption.Storage, bagRefs.tabCaption.Display = order[1], order[2], order[3]

	bagRefs.sortButton = Kit.Button("⇅ Value", T.PanelLight, function()
		bag.sort = if bag.sort == "Value" then "Rarity" else "Value"
		bag.sig = ""
		renderBag()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -128, 0, 0), Size = UDim2.fromOffset(110, 44), TextSize = 14, Parent = body })
	bagRefs.sellCommons = Kit.Button(`{Icons.Get("Sell")} Commons`, T.Bad, function()
		Net.RequestSellCommons:FireServer()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(122, 44), TextSize = 14, Parent = body })
	bagRefs.hint = Kit.Label({
		Text = "",
		TextSize = 13,
		Font = T.Bold,
		Position = UDim2.fromOffset(4, 48),
		Size = UDim2.new(1, -250, 0, 18),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = body,
	})
	bagRefs.grid = Kit.Scroll({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, -246, 1, -70), Parent = body })
	Kit.Grid(Vector2.new(108, 136), 8).Parent = bagRefs.grid
	New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = bagRefs.grid })
	local detailCard = Kit.Card({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 50),
		Size = UDim2.new(0, 236, 1, -50),
		BackgroundColor3 = T.PanelDark,
		Parent = body,
	})
	bagRefs.detail = Kit.Scroll({ Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), Parent = detailCard })
	Kit.List(6, false, Enum.HorizontalAlignment.Center).Parent = bagRefs.detail
end

------------------------------------------------------------------------------------------
-- Upgrades
------------------------------------------------------------------------------------------
local upScroll
local function renderUpgrades()
	Kit.Clear(upScroll)
	local order = 0
	local function o()
		order += 1
		return order
	end
	local levels = S.Get("Upgrades") or {}
	local coins = S.Get("Coins") or 0
	local suitIndex = S.Get("Suit") or 1
	local suit = Upgrades.Suits[suitIndex]
	local nextSuit = Upgrades.Suits[suitIndex + 1]

	-- Suit card with a 3D helmet in the suit's colour
	local sr = row(upScroll, o(), 120)
	local stage = New("Frame", {
		BackgroundColor3 = Kit.Darken(suit.Color, 0.6),
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(104, 104),
		Parent = sr,
	}, { Kit.Corner(14), Kit.Sheen(0.5), Kit.Stroke(suit.Color, 2, 0.05) })
	Kit.Glow(stage, suit.Color, 100)
	RelicView.Archetype("helmet", { main = suit.Color, accent = Color3.fromRGB(255, 196, 64) }, { Spin = 30, ZIndex = 2, Parent = stage })
	Kit.Title({ Text = suit.Name, TextSize = 22, Position = UDim2.fromOffset(124, 8), Size = UDim2.new(1, -290, 0, 26), TextWrapped = false, Parent = sr })
	Kit.Label({
		Text = `Safe down to: {Zones.List[math.min(suitIndex, #Zones.List)].Name}`,
		TextColor3 = T.Muted,
		TextSize = 14,
		Position = UDim2.fromOffset(124, 36),
		Size = UDim2.new(1, -290, 0, 18),
		Parent = sr,
	})
	local pips = New("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(124, 62), Size = UDim2.new(1, -290, 0, 44), Parent = sr }, { Kit.List(6, true) })
	for i, zone in Zones.List do
		local ok = i <= suitIndex
		local badge = Kit.IconBadge(Icons.Get(zone.Id), if ok then Kit.Lighten(zone.FogColor, 0.3) else T.PanelDark, 38, { LayoutOrder = i, Parent = pips })
		if not ok then
			badge.BackgroundTransparency = 0.4
			badge:FindFirstChildOfClass("TextLabel").TextTransparency = 0.6
		end
	end
	if nextSuit then
		local affordable = coins >= nextSuit.Cost and not nextSuit.ComingSoon
		Kit.Label({
			Text = `Next: {nextSuit.Name}{nextSuit.ComingSoon and " (soon)" or ""}`,
			TextColor3 = T.Muted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 14),
			Size = UDim2.fromOffset(150, 34),
			Parent = sr,
		})
		Kit.Button(coinText(nextSuit.Cost), if affordable then T.Good else T.PanelLight, function()
			Net.RequestBuySuit:FireServer()
		end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 54), Size = UDim2.fromOffset(150, 52), TextSize = 18, Parent = sr })
	else
		Kit.Pill("MAX SUIT", T.Gold, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), TextSize = 16, Size = UDim2.fromOffset(0, 32), Parent = sr })
	end

	Kit.Header(upScroll, o(), "UPGRADES")
	for _, track in Upgrades.Tracks do
		local lvl = levels[track.Id] or 0
		local r = row(upScroll, o(), 74)
		Kit.IconBadge(Icons.Track(track.Id), T.AccentDeep, 54, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Parent = r })
		Kit.Title({ Text = track.Name, TextSize = 18, Position = UDim2.fromOffset(74, 6), Size = UDim2.new(1, -250, 0, 22), TextWrapped = false, Parent = r })
		Kit.Pill(`Lv {lvl}/{track.Max}`, if lvl >= track.Max then T.Gold else T.Accent, { Position = UDim2.new(1, -236, 0, 8), Parent = r })
		Kit.Label({ Text = track.Desc, TextColor3 = T.Muted, TextSize = 13, Position = UDim2.fromOffset(74, 30), Size = UDim2.new(1, -250, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = r })
		local _, setBar = Kit.Bar({ Position = UDim2.fromOffset(74, 52), Size = UDim2.new(1, -250, 0, 10), Color = if lvl >= track.Max then T.Gold else T.Accent, Parent = r })
		setBar(lvl / track.Max)
		if lvl >= track.Max then
			Kit.Pill("MAX", T.Gold, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), TextSize = 16, Size = UDim2.fromOffset(0, 32), Parent = r })
		else
			local cost = Upgrades.Cost(track.Id, lvl)
			Kit.Button(coinText(cost), if coins >= cost then T.Good else T.PanelLight, function()
				Net.RequestUpgrade:FireServer(track.Id)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 50), Parent = r })
		end
	end
	local g = row(upScroll, o(), 64)
	Kit.IconBadge(Icons.Get("Gate"), T.Bad, 46, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Parent = g })
	Kit.Title({ Text = "Laser Gate", TextSize = 18, Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -230, 0, 22), Parent = g })
	Kit.Label({ Text = "Blocks raids on your dock for a while", TextColor3 = T.Muted, TextSize = 13, Position = UDim2.fromOffset(74, 32), Size = UDim2.new(1, -230, 0, 18), Parent = g })
	Kit.Button("⚡ Activate", T.Bad, function()
		Net.ActivateGate:FireServer()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 48), Parent = g })
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
	codexTitle.Text = `{Icons.Get(zone.Id)} {zone.Name}: {found}/{total} found · 100% = +5% luck here`
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
		table.insert(items, { id = tostring(i), text = zone.Name, icon = Icons.Get(zone.Id), color = Kit.Lighten(zone.FogColor, 0.3) })
	end
	local tabScroll = Kit.Scroll({
		Size = UDim2.new(1, 0, 0, 50),
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
	end, { Size = UDim2.new(0, 0, 0, 44), AutomaticSize = Enum.AutomaticSize.X, TabWidth = 150 })
	tabs.Name = "ZoneTabs"
	codexTitle = Kit.Label({ Text = "", Font = T.Bold, TextSize = 14, Position = UDim2.fromOffset(2, 54), Size = UDim2.new(1, -150, 0, 22), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = body })
	local _, setBar = Kit.Bar({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 56), Size = UDim2.fromOffset(140, 18), TextSize = 12, Parent = body })
	codexSetBar = setBar
	codexScroll = Kit.Scroll({ Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 1, -82), Parent = body })
	Kit.Grid(Vector2.new(112, 140), 8).Parent = codexScroll
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
	header(questScroll, o(), `DAILY LOGIN · streak {streak} day{streak == 1 and "" or "s"}`)
	local cal = row(questScroll, o(), 70)
	cal.BackgroundTransparency = 1
	Kit.List(4, true).Parent = cal
	local dayInCycle = ((streak - 1) % #Economy.DailyRewards) + 1
	for i, reward in Economy.DailyRewards do
		local label = if reward.Coins and reward.Pearls
			then `{NumberFormat.short(reward.Coins)}🪙\n{reward.Pearls}🫧`
			elseif reward.Coins then `{NumberFormat.short(reward.Coins)}🪙`
			elseif reward.Pearls then `{reward.Pearls}🫧`
			elseif reward.Relic then `{reward.Relic}\nrelic`
			else "Luck\npotion"
		local isToday = i == dayInCycle
		Kit.Button(`Day {i}\n{label}`, if isToday and not claimedToday then T.Gold elseif i < dayInCycle or (isToday and claimedToday) then T.Good else T.PanelLight, function()
			if isToday and not claimedToday then
				Net.RequestClaimDaily:FireServer()
			end
		end, { Size = UDim2.fromOffset(82, 66), TextSize = 12, LayoutOrder = i, Parent = cal })
	end

	local q = S.Get("Quests") or {}
	for _, section in { { "DAILY QUESTS", q.Daily or {} }, { "WEEKLY QUESTS", q.Weekly or {} } } do
		header(questScroll, o(), section[1])
		for _, entry in section[2] do
			local def = questDef(entry.Id)
			if def then
				local r = row(questScroll, o(), 54)
				local reward = (def.Coins and `{NumberFormat.short(def.Coins)} Coins` or "") .. (def.Pearls and `{def.Pearls} Pearls` or "")
				Kit.Label({ Text = def.Text, Font = T.Bold, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 24), Parent = r })
				Kit.Label({
					Text = `{entry.Progress}/{def.Goal} · {reward} · +{def.Xp} Tide XP`,
					TextColor3 = T.Muted,
					TextSize = 13,
					Position = UDim2.fromOffset(10, 28),
					Size = UDim2.new(1, -150, 0, 22),
					Parent = r,
				})
				local done = entry.Progress >= def.Goal
				Kit.Button(if entry.Claimed then "Claimed" elseif done then "Claim" else "…", if done and not entry.Claimed then T.Gold else T.PanelLight, function()
					if done and not entry.Claimed then
						Net.RequestClaimQuest:FireServer(entry.Id)
					end
				end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 44), Parent = r })
			end
		end
	end

	-- Tide Pass
	local tp = S.Get("TidePass") or { XP = 0, Premium = false, ClaimedFree = {}, ClaimedPremium = {} }
	local tier = tp.XP // Economy.TidePass.XpPerTier
	header(questScroll, o(), `TIDE PASS {Economy.TidePass.SeasonId} · Tier {tier}/{Economy.TidePass.Tiers} ({tp.XP % Economy.TidePass.XpPerTier}/{Economy.TidePass.XpPerTier} XP)`)
	if not tp.Premium then
		local r = row(questScroll, o(), 56)
		r.BackgroundTransparency = 1
		Kit.List(6, true).Parent = r
		Kit.Button("Premium · 499 R$", T.Gold, function()
			Net.RequestPurchase:FireServer("Product", "TidePassPremium")
		end, { Size = UDim2.fromOffset(170, 48), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = r })
		Kit.Button(`Premium · {Economy.TidePass.PremiumPearlCost} Pearls`, T.Accent, function()
			Net.RequestBuyTidePassPearls:FireServer()
		end, { Size = UDim2.fromOffset(200, 48), Parent = r })
	end
	for t = 1, Economy.TidePass.Tiers do
		local r = row(questScroll, o(), 48)
		Kit.Label({ Text = `Tier {t}`, Font = T.Bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 70, 1, 0), Parent = r })
		local reached = tier >= t
		local function claimButton(premium: boolean, x: number)
			local claimed = (if premium then tp.ClaimedPremium else tp.ClaimedFree)[tostring(t)]
			local text = if premium then "Premium" else "Free"
			Kit.Button(
				if claimed then `{text} ✓` elseif reached then `Claim {text}` else text,
				if claimed then T.Good elseif reached and (not premium or tp.Premium) then T.Gold else T.PanelLight,
				function()
					if reached and not claimed then
						Net.RequestClaimTier:FireServer(t, premium)
					end
				end,
				{ Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(140, 40), TextSize = 13, Parent = r }
			)
		end
		claimButton(false, 90)
		claimButton(true, 240)
		if not reached and t > tier + 3 then
			break -- keep the list short; reveal as you progress
		end
	end
end

------------------------------------------------------------------------------------------
-- Rebirth
------------------------------------------------------------------------------------------
local rebirthScroll
local function renderRebirth()
	Kit.Clear(rebirthScroll)
	local n = S.Get("Rebirths") or 0
	local need = S.Derived("RebirthRequirement") or Formulas.RebirthRequirement(n)
	local lifetime = S.Get("LifetimeCoins") or 0
	local suitOk = (S.Get("Suit") or 1) >= Economy.Rebirth.RequiredSuit
	local coinOk = lifetime >= need
	local lines = {
		`Resurfaces: {n}  ·  Rebirth Tokens: {S.Get("RebirthTokens") or 0}`,
		"",
		`Requirements:`,
		`{suitOk and "✅" or "❌"} Own the {Upgrades.Suits[Economy.Rebirth.RequiredSuit].Name} suit`,
		`{coinOk and "✅" or "❌"} {NumberFormat.short(lifetime)} / {NumberFormat.short(need)} lifetime Coins`,
		"",
		`You gain: Coins x{Formulas.RebirthMultiplier(n)} → x{Formulas.RebirthMultiplier(n + 1)}, +2% luck (max 30%), +1 Rebirth Token, a new helmet trim.`,
		"You keep: relics on stands, storage, Codex, Pearls, passes, level, Display Slots.",
		"Resets: Coins, upgrades, suit, dive bag.",
	}
	Kit.Label({ Text = table.concat(lines, "\n"), TextSize = 15, LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 200), TextYAlignment = Enum.TextYAlignment.Top, Parent = rebirthScroll })
	Kit.Button("RESURFACE", if suitOk and coinOk then T.Gold else T.PanelLight, function()
		Net.RequestRebirth:FireServer()
	end, { LayoutOrder = 2, Size = UDim2.fromOffset(220, 52), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = rebirthScroll })
	header(rebirthScroll, 3, "TALENT TREE")
	local talents = S.Get("Talents") or {}
	for i, t in Economy.Rebirth.Talents do
		local r = row(rebirthScroll, 3 + i, 56)
		local lvl = talents[t.Id] or 0
		Kit.Label({ Text = `{t.Name}  {lvl}/{t.Max}`, Font = T.Bold, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 24), Parent = r })
		Kit.Label({ Text = t.Desc, TextColor3 = T.Muted, TextSize = 13, Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -150, 0, 22), Parent = r })
		Kit.Button(if lvl >= t.Max then "MAX" else `{t.Cost} Token`, T.Accent, function()
			Net.RequestTalent:FireServer(t.Id)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 44), Parent = r })
	end
end

------------------------------------------------------------------------------------------
-- Leaderboards
------------------------------------------------------------------------------------------
local lbScroll
local function renderLeaderboards()
	Kit.Clear(lbScroll)
	local order = 0
	for _, id in { "Deepest", "TotalValue", "Rebirths", "Steals", "Codex" } do
		local board = leaderboardData[id]
		if board then
			order += 1
			header(lbScroll, order, board.Title:upper())
			local lines = {}
			for _, r in board.Rows do
				table.insert(lines, `{r.Rank}. {r.Name} — {r.Value}`)
			end
			order += 1
			Kit.Label({ Text = if #lines > 0 then table.concat(lines, "\n") else "No entries yet", TextSize = 14, LayoutOrder = order, Size = UDim2.new(1, -8, 0, math.max(1, #lines) * 18 + 6), Parent = lbScroll })
		end
	end
	if order == 0 then
		Kit.Label({ Text = "Loading leaderboards…", Parent = lbScroll })
	end
end

------------------------------------------------------------------------------------------
-- Players (trade / party)
------------------------------------------------------------------------------------------
local playersScroll
local function renderPlayers()
	Kit.Clear(playersScroll)
	local order = 0
	Kit.Button("Leave party", T.PanelLight, function()
		Net.PartyLeave:FireServer()
	end, { LayoutOrder = 0, Size = UDim2.fromOffset(160, 44), Parent = playersScroll })
	for _, other in Players:GetPlayers() do
		if other ~= player then
			order += 1
			local r = row(playersScroll, order, 56)
			Kit.Label({ Text = other.DisplayName, Font = T.Bold, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -280, 1, 0), Parent = r })
			Kit.Button("Party", T.Accent, function()
				Net.PartyInvite:FireServer(other.UserId)
				controllers.UIController.Toast(`Party invite sent to {other.DisplayName}`, "info")
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -140, 0.5, 0), Size = UDim2.fromOffset(120, 44), Parent = r })
			Kit.Button("Trade", T.Gold, function()
				Net.TradeRequest:FireServer(other.UserId)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(120, 44), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = r })
		end
	end
	if order == 0 then
		Kit.Label({ Text = "Nobody else is here yet — invite friends for +10% Coins each!", LayoutOrder = 1, Size = UDim2.new(1, -8, 0, 40), Parent = playersScroll })
	end
end

------------------------------------------------------------------------------------------
-- Trade window
------------------------------------------------------------------------------------------
local tradeScroll
local function renderTrade()
	Kit.Clear(tradeScroll)
	local st = tradeState
	if not st then
		Kit.Label({ Text = "No active trade.", Parent = tradeScroll })
		return
	end
	local order = 0
	local function o()
		order += 1
		return order
	end
	header(tradeScroll, o(), `Trading with {st.Partner}` .. (if st.Countdown then ` · completing in {math.ceil(st.Countdown)}s` else ""))
	local function list(title: string, relics)
		header(tradeScroll, o(), title)
		if #relics == 0 then
			Kit.Label({ Text = "(nothing)", TextColor3 = T.Muted, LayoutOrder = o(), Parent = tradeScroll })
		end
		for _, relic in relics do
			Kit.Label({ Text = `{Rarities[relic.rarity].Icon} {relicLine(relic)} (+{NumberFormat.short(Formulas.RelicCPS(relic))}/s)`, TextColor3 = Rarities[relic.rarity].Color, LayoutOrder = o(), Parent = tradeScroll })
		end
	end
	list(`Your offer {st.MyConfirm and "✅" or ""}`, st.MyOffer)
	list(`Their offer {st.TheirConfirm and "✅" or ""}`, st.TheirOffer)
	local actions = row(tradeScroll, o(), 54)
	actions.BackgroundTransparency = 1
	Kit.List(6, true).Parent = actions
	Kit.Button("Confirm", T.Good, function()
		Net.TradeConfirm:FireServer()
	end, { Size = UDim2.fromOffset(140, 48), Parent = actions })
	Kit.Button("Cancel", T.Bad, function()
		Net.TradeCancel:FireServer()
	end, { Size = UDim2.fromOffset(140, 48), Parent = actions })
	header(tradeScroll, o(), "Pick from your storage (max 8) — changing the offer resets confirmations")
	for _, relic in S.Get("Storage") or {} do
		if not relic.locked then
			local selected = tradeSelection[relic.uid] == true
			Kit.Button(`{selected and "☑" or "☐"} {relicLine(relic)} ({relic.rarity})`, if selected then T.Accent else T.PanelLight, function()
				tradeSelection[relic.uid] = not selected or nil
				local uids = {}
				for uid in tradeSelection do
					table.insert(uids, uid)
				end
				Net.TradeSetOffer:FireServer(uids)
			end, { Size = UDim2.new(1, -8, 0, 44), TextSize = 14, LayoutOrder = o(), TextXAlignment = Enum.TextXAlignment.Left, Parent = tradeScroll })
		end
	end
end

------------------------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------------------------
local settingsScroll
local function renderSettings()
	Kit.Clear(settingsScroll)
	local settings = table.clone(S.Get("Settings") or { Music = 0.6, SFX = 0.8, LowScare = false })
	local function stepper(order: number, label: string, key: string)
		local r = row(settingsScroll, order, 54)
		Kit.Label({ Text = `{label}: {math.floor(settings[key] * 100)}%`, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -140, 1, 0), Parent = r })
		Kit.Button("−", T.PanelLight, function()
			settings[key] = math.max(0, settings[key] - 0.1)
			Net.UpdateSettings:FireServer(settings)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.fromOffset(52, 44), Parent = r })
		Kit.Button("+", T.PanelLight, function()
			settings[key] = math.min(1, settings[key] + 0.1)
			Net.UpdateSettings:FireServer(settings)
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(52, 44), Parent = r })
	end
	stepper(1, "Music", "Music")
	stepper(2, "Sound effects", "SFX")
	local ls = row(settingsScroll, 3, 54)
	Kit.Label({ Text = "Lower jump scares", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -140, 1, 0), Parent = ls })
	Kit.Button(settings.LowScare and "ON" or "OFF", settings.LowScare and T.Good or T.PanelLight, function()
		settings.LowScare = not settings.LowScare
		Net.UpdateSettings:FireServer(settings)
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 44), Parent = ls })

	local codeRow = row(settingsScroll, 4, 54)
	local box = New("TextBox", {
		PlaceholderText = "Enter code",
		Text = "",
		ClearTextOnFocus = false,
		BackgroundColor3 = T.Bg,
		TextColor3 = T.Text,
		Font = T.Font,
		TextSize = 16,
		Position = UDim2.fromOffset(8, 7),
		Size = UDim2.new(1, -140, 0, 40),
		Parent = codeRow,
	}, { Kit.Corner(8) })
	Kit.Button("Redeem", T.Accent, function()
		Net.RequestRedeemCode:FireServer(box.Text)
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 44), Parent = codeRow })

	local nameRow = row(settingsScroll, 5, 54)
	local nameBox = New("TextBox", {
		PlaceholderText = `Dock name ({S.Get("RenameTokens") or 0} rename tokens)`,
		Text = "",
		ClearTextOnFocus = false,
		BackgroundColor3 = T.Bg,
		TextColor3 = T.Text,
		Font = T.Font,
		TextSize = 16,
		Position = UDim2.fromOffset(8, 7),
		Size = UDim2.new(1, -140, 0, 40),
		Parent = nameRow,
	}, { Kit.Corner(8) })
	Kit.Button("Rename", T.Gold, function()
		Net.RenameDock:FireServer(nameBox.Text)
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 44), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = nameRow })

	Kit.Label({
		Text = "Graphics quality follows your Roblox settings (Esc → Settings). Controls: WASD swim · Space up · Ctrl/C down · Shift boost · Q sonar · G flare · R instant surface · B bag · U upgrades · M shop",
		TextColor3 = T.Muted,
		TextSize = 13,
		LayoutOrder = 6,
		Size = UDim2.new(1, -8, 0, 60),
		Parent = settingsScroll,
	})
end

------------------------------------------------------------------------------------------
function MenuController.Start()
	local UI = controllers.UIController
	UI.RegisterWindow("Bag", "Bag & Dock", buildBag, renderBag)
	UI.RegisterWindow("Upgrades", "Upgrades", function(body)
		upScroll = scrollBody(body)
	end, renderUpgrades)
	UI.RegisterWindow("Codex", "Codex", buildCodex, renderCodex)
	UI.RegisterWindow("Quests", "Quests & Tide Pass", function(body)
		questScroll = scrollBody(body)
	end, renderQuests)
	UI.RegisterWindow("Rebirth", "Resurface", function(body)
		rebirthScroll = scrollBody(body)
	end, renderRebirth)
	UI.RegisterWindow("Leaderboards", "Leaderboards", function(body)
		lbScroll = scrollBody(body)
	end, renderLeaderboards)
	UI.RegisterWindow("Players", "Players", function(body)
		playersScroll = scrollBody(body)
	end, renderPlayers)
	UI.RegisterWindow("Trade", "Trade", function(body)
		tradeScroll = scrollBody(body)
	end, renderTrade)
	UI.RegisterWindow("Settings", "Settings", function(body)
		settingsScroll = scrollBody(body)
	end, renderSettings)

	S.Changed:Connect(function(keys)
		if keys.Bag or keys.Storage or keys.Stands or keys.Vault or keys.Derived or keys.IncomePerSecond then
			UI.Refresh("Bag")
		end
		if keys.Upgrades or keys.Coins or keys.Suit then
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
			controllers.OfferController.Confirm(`{info.Invite} invited you to a Dive Party (+10% luck each).`, "Join", function(accepted)
				Net.PartyRespond:FireServer(accepted)
			end)
		elseif info.Members then
			local names = {}
			for _, m in info.Members do
				table.insert(names, m.Name)
			end
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
