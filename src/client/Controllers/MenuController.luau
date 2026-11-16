-- MenuController (Master Plan §18.2): Bag/Dock Manager, Upgrades, Codex, Quests & Tide Pass,
-- Rebirth, Leaderboards, Players (trade/party), Trade window and Settings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Materials = require(Shared.Config.Materials)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Quests = require(Shared.Config.Quests)
local Economy = require(Shared.Config.Economy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)
local RelicView = require(script.Parent.Parent.UI.RelicView)
local RelicCard = require(script.Parent.Parent.UI.RelicCard)
local RelicViewer = require(script.Parent.Parent.UI.RelicViewer)

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
	local pad = New("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = scroll })
	return scroll, pad
end

-- A scrolling list inside a dark well (the clean window look), with room round its edges
local function wellScroll(body: Frame, wellColor: Color3?)
	local scroll, pad = scrollBody(Kit.Well({ BackgroundColor3 = wellColor or Kit.Clean.Well, Parent = body }))
	scroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	scroll.ScrollBarImageTransparency = 0.6
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 8)
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
	sig = "",
}
local bagRefs = {}

-- Two tabs: Bag (what you carry on this dive, lost if you die) and Storage (everything you
-- keep). Storage lists the relics on your dock stands and in the vault first, with a check.
local function bagItems(tab: string)
	local items = {}
	if tab == "Bag" then
		for _, relic in S.Get("Bag") or {} do
			table.insert(items, { relic = relic, where = "Bag", key = "B:" .. relic.uid })
		end
	else
		for slot, relic in S.Get("Stands") or {} do
			table.insert(items, { relic = relic, where = "Stands", slot = slot, key = "D:" .. slot, equipped = true })
		end
		for slot, relic in S.Get("Vault") or {} do
			table.insert(items, { relic = relic, where = "Vault", slot = slot, key = "V:" .. slot, equipped = true })
		end
		for _, relic in S.Get("Storage") or {} do
			table.insert(items, { relic = relic, where = "Storage", key = "S:" .. relic.uid })
		end
	end
	table.sort(items, function(a, b)
		if (a.equipped == true) ~= (b.equipped == true) then
			return a.equipped == true
		end
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
	local parts = { bag.tab or "", bag.sort, tostring(mult), tostring(S.Derived("VaultCount") or 0) }
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

-- The picked card gets a white edge; the old one goes back to its normal edge
local function markCard(card: Instance?, on: boolean)
	if not card or not card.Parent then
		return
	end
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if on then Color3.new(1, 1, 1) else T.Outline
		stroke.Thickness = if on then 3 else 2
	end
end

-- One relic pop-up at a time (Inventory and Codex share it)
local pop = { frame = nil :: Frame?, card = nil :: Instance?, key = nil :: string? }

local function closePopup()
	if pop.frame then
		pop.frame:Destroy()
		pop.frame = nil
	end
	markCard(pop.card, false)
	pop.card = nil
	pop.key = nil
end

local function popupLine(parent: Instance, order: number)
	New("Frame", {
		Name = "Line",
		BackgroundColor3 = Kit.Clean.RowEdge,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		LayoutOrder = order,
		Parent = parent,
	})
end

-- Small card next to a tapped relic card (reference: the owner's inventory clip, picture 2):
-- name, rarity, a few lines, a big View button, then the actions, three to a row.
--   o = { Key, Body, Card, Title, Rarity, Sub?, Lines = { { text, color } }, OnView?,
--         ViewText?, Actions? = function(act) }   act(text, colorName | Color3, fn)
local function relicPopup(o)
	closePopup()
	pop.key = o.Key
	pop.card = o.Card
	markCard(o.Card, true)
	local body: Frame, card: GuiObject = o.Body, o.Card
	local rColor = Kit.RarityColor(o.Rarity, Rarities)
	local W = 236

	local popup = New("Frame", {
		Name = "RelicPopup",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(14, 15, 20),
		Size = UDim2.fromOffset(W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 20,
		Parent = body,
	}, {
		Kit.Corner(12),
		New("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		Kit.List(6),
	})
	New("UIStroke", { Thickness = 2.5, Color = Color3.new(1, 1, 1), Parent = popup }, {
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Kit.Lighten(rColor, 0.4), rColor) }),
	})
	pop.frame = popup

	local name = Kit.Text(o.Title, 20, {
		Outline = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 1,
		Parent = popup,
	})
	New("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 11, Parent = name })
	local rarityWord = Kit.Text(o.Rarity, 16, {
		Outline = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 2,
		Parent = popup,
	})
	New("UIGradient", { Color = ColorSequence.new(Kit.Lighten(rColor, 0.45), rColor), Parent = rarityWord })
	if o.Sub then
		Kit.Label({
			Text = o.Sub,
			TextSize = 12,
			Font = T.Bold,
			TextColor3 = Kit.Clean.Sub,
			Size = UDim2.new(1, 0, 0, 14),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 3,
			Parent = popup,
		})
	end
	popupLine(popup, 4)
	for i, line in o.Lines or {} do
		Kit.Text(line[1], 15, {
			Outline = 2,
			TextColor3 = line[2] or Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 4 + i,
			Parent = popup,
		})
	end
	popupLine(popup, 20)

	if o.OnView then
		Kit.ActionButton(o.ViewText or "View", "Gold", function()
			closePopup()
			o.OnView()
		end, { Size = UDim2.new(1, 0, 0, 46), TextSize = 20, ZIndex = 21, LayoutOrder = 21, Parent = popup })
	else
		Kit.ActionButton(o.ViewText or "View", "Grey", nil, {
			Size = UDim2.new(1, 0, 0, 46),
			TextSize = 17,
			ZIndex = 21,
			LayoutOrder = 21,
			Parent = popup,
		})
	end

	if o.Actions then
		local row = New("Frame", {
			Name = "Actions",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 22,
			Parent = popup,
		})
		local grid = Kit.Grid(Vector2.new(66, 44), 5)
		grid.Parent = row
		o.Actions(function(text: string, color: string | Color3, fn)
			Kit.ActionButton(text, color, function()
				closePopup()
				fn()
			end, { TextSize = 14, ZIndex = 21, Parent = row })
		end)
	end

	-- place it beside the card (left of it when the card is on the right half), inside the body
	task.defer(function()
		if pop.frame ~= popup or not card.Parent then
			return
		end
		local bp, bs = body.AbsolutePosition, body.AbsoluteSize
		local cp, cs = card.AbsolutePosition, card.AbsoluteSize
		local h = popup.AbsoluteSize.Y
		local x = if cp.X + cs.X / 2 > bp.X + bs.X / 2 then cp.X - bp.X - W - 8 else cp.X - bp.X + cs.X + 8
		local y = math.clamp(cp.Y - bp.Y, 0, math.max(0, bs.Y - h))
		popup.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(0, bs.X - W)), y)
		Kit.Pop(popup, 0.85, 0.18)
	end)
	return popup
end

local function openPopup(item, card: GuiObject, mult: number)
	local relic = item.relic
	local def = Relics.ById[relic.id]
	local muts = {}
	for _, m in relic.mutations or {} do
		local md = Mutations.ById[m]
		if md then
			table.insert(muts, `{m} x{md.Mult}`)
		end
	end
	local cps = Formulas.RelicCPS(relic) * mult
	relicPopup({
		Key = item.key,
		Body = bagRefs.body,
		Card = card,
		Title = Materials.Prefix(relic) .. def.Name,
		Rarity = relic.rarity,
		Sub = if #muts > 0 then table.concat(muts, "  ") else nil,
		Lines = {
			{ `+{NumberFormat.short(cps)} Coins/s`, Kit.Clean.Go },
			{ `Sells for {NumberFormat.short(Formulas.SellPrice(relic, mult))}`, Kit.Clean.Gold },
		},
		OnView = function()
			RelicViewer.Open({
				Id = relic.id,
				Mutations = relic.mutations,
				Info = { relic.rarity, `+{NumberFormat.short(cps)} Coins/s`, `Size {relic.size}x` },
			})
		end,
		Actions = function(act)
			if item.equipped then
				act("Take", "Blue", function()
					Net.RequestPickupRelic:FireServer(tonumber(item.slot), item.where == "Vault")
				end)
				return
			end
			if item.where == "Storage" then
				act("Display", "Green", function()
					local slot = firstFreeStand()
					if slot then
						Net.RequestPlaceRelic:FireServer(relic.uid, slot, false)
					else
						controllers.UIController.Toast("All stands are full! Upgrade Display Slots.", "error")
						if not S.Owns("ExtraSlots") then
							controllers.OfferController.Show("ExtraSlots")
						end
					end
				end)
				if (S.Derived("VaultCount") or 0) > 0 then
					act("Vault", Color3.fromRGB(150, 90, 240), function()
						placeInVault(relic)
					end)
				end
			end
			act(if relic.locked then "Unlock" else "Lock", "Blue", function()
				Net.RequestToggleLock:FireServer(relic.uid)
			end)
			if not relic.locked then
				act("Sell", "Red", function()
					Net.RequestSell:FireServer(relic.uid)
				end)
			end
			if table.find(relic.mutations, "Barnacled") then
				act("Clean", Color3.fromRGB(160, 120, 70), function()
					Net.RequestCleanBarnacle:FireServer(relic.uid)
				end)
			end
		end,
	})
end

-- Green tick in a card's top-right corner: this relic is on your dock or in the vault
local function equippedTick(card: Instance)
	local tick = New("Frame", {
		Name = "Equipped",
		BackgroundColor3 = Color3.fromRGB(60, 200, 30),
		-- sits over the corner (like the reference), clear of the name; the grid's 10 px top
		-- padding keeps it inside the scroll area
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 8,
		Parent = card,
	}, { Kit.Round(), Kit.Stroke(Kit.Clean.Ink, 2, 0) })
	Kit.IconFill("check", Color3.new(1, 1, 1), 16, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 9,
		Parent = tick,
	})
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

-- Equip Best: put your highest-earning relics (dock + storage) on the dock stands. Placing on
-- a taken stand swaps the old relic back to storage (DockService.PlaceRelic), so each move is
-- one existing RequestPlaceRelic, spaced out to stay under the dock's rate limit (8, 3/s).
local equipping = false
local function equipBest()
	if equipping then
		return
	end
	local stands = S.Get("Stands") or {}
	local n = S.Derived("StandCount") or 6
	local pool = {}
	for slot, relic in stands do
		table.insert(pool, { relic = relic, slot = tonumber(slot) })
	end
	for _, relic in S.Get("Storage") or {} do
		table.insert(pool, { relic = relic })
	end
	table.sort(pool, function(a, b)
		return Formulas.RelicCPS(a.relic) > Formulas.RelicCPS(b.relic)
	end)
	local best = {}
	for i = 1, math.min(n, #pool) do
		best[pool[i].relic.uid] = true
	end
	-- stands that are empty or hold a relic outside the best set, lowest slot first
	local free = {}
	for i = 1, n do
		local r = stands[tostring(i)]
		if not r or not best[r.uid] then
			table.insert(free, i)
		end
	end
	local moves = {}
	for i = 1, math.min(n, #pool) do
		local it = pool[i]
		if not it.slot and #free > 0 then
			table.insert(moves, { uid = it.relic.uid, slot = table.remove(free, 1) })
		end
	end
	if #moves == 0 then
		controllers.UIController.Toast("Your best relics are already on display.")
		return
	end
	equipping = true
	controllers.UIController.Toast(`Equipping {#moves} best relic{if #moves == 1 then "" else "s"}...`)
	task.spawn(function()
		for i, m in moves do
			Net.RequestPlaceRelic:FireServer(m.uid, m.slot, false)
			if i < #moves then
				task.wait(0.35)
			end
		end
		equipping = false
	end)
end

local function renderBag()
	local bagList = S.Get("Bag") or {}
	if bag.tab ~= "Bag" and bag.tab ~= "Storage" then
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
	local cap = bagRefs.tabCaption
	if cap.Bag then
		cap.Bag.Text = `Inventory {#bagList}/{S.Derived("BagSize") or 3}`
	end
	if cap.Storage then
		cap.Storage.Text = `Storage {storageN + displayN}`
	end
	bagRefs.paintTabs(bag.tab)
	bagRefs.sortLabel.Text = `Sort: {bag.sort}`
	bagRefs.sellCommons.Visible = bag.tab == "Storage"
	bagRefs.equipBest.Visible = bag.tab == "Storage"
	bagRefs.hint.Text = if bag.tab == "Bag"
		then "Inventory relics are lost if you die. Swim home to secure them!"
		else `On display {displayN}/{S.Derived("StandCount") or 6}  ·  Dock earns +{NumberFormat.short(
			S.Get("IncomePerSecond") or 0
		)}/s`
	bagRefs.hint.TextColor3 = if bag.tab == "Bag" then T.Gold else Kit.Clean.Sub
	if sig == bag.sig then
		return
	end
	bag.sig = sig

	if pop.key and string.sub(pop.key, 1, 2) ~= "C:" then
		closePopup()
	end
	Kit.Clear(bagRefs.grid)
	for i, it in items do
		local card
		card = RelicCard.new({
			Relic = it.relic,
			Subtitle = `+{NumberFormat.short(Formulas.RelicCPS(it.relic) * mult)} / s`,
			LazyModel = true,
			LayoutOrder = i,
			OnClick = function()
				if pop.key == it.key then
					closePopup()
				else
					openPopup(it, card, S.Derived("CoinMult") or 1)
				end
			end,
			Parent = bagRefs.grid,
		})
		if it.equipped then
			equippedTick(card)
		end
	end
	-- Empty state sits over the grid (a grid cell would squash it into a 112 px column)
	bagRefs.empty.Visible = #items == 0
	if #items == 0 then
		bagRefs.emptyTitle.Text = if bag.tab == "Bag" then "Your inventory is empty" else "No relics yet"
		bagRefs.emptyText.Text = if bag.tab == "Bag"
			then "Dive and salvage glinting relics, then swim home to keep them."
			else "Relics you bring home land here. Put your best on the dock to earn Coins."
	end
	task.defer(realizeVisibleCards)
end

local function buildBag(body: Frame)
	bagRefs.body = body
	bagRefs.tabCaption = {}
	local tabsFrame, paint = Kit.FlatTabs(
		body,
		{
			{ id = "Bag", text = "Inventory", color = Color3.fromRGB(60, 160, 255) },
			{ id = "Storage", text = "Storage", color = T.Accent },
		},
		"Storage",
		function(id)
			closePopup()
			bag.tab = id
			bag.sig = ""
			renderBag()
		end,
		{ Size = UDim2.new(1, -364, 0, 46) }
	)
	bagRefs.paintTabs = paint
	-- FlatTabs keeps each caption in a "Label" inside the tab button named by its id
	for _, id in { "Bag", "Storage" } do
		local b = tabsFrame:FindFirstChild(id)
		local label = b and b:FindFirstChild("Label")
		if label then
			bagRefs.tabCaption[id] = label
		end
	end

	-- Equip Best, Sort and Sell Commons: coloured buttons at the top right
	local tools = New("Frame", {
		Name = "Tools",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(360, 50),
		Parent = body,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local _, _, sortLabel = Kit.ActionButton("Sort: Value", "Green", function()
		bag.sort = if bag.sort == "Value" then "Rarity" else "Value"
		bag.sig = ""
		renderBag()
	end, { Size = UDim2.fromOffset(112, 46), TextSize = 15, LayoutOrder = 2, Parent = tools })
	bagRefs.sortLabel = sortLabel
	bagRefs.equipBest = Kit.ActionButton("Equip Best", "Blue", equipBest, {
		Size = UDim2.fromOffset(112, 46),
		TextSize = 15,
		LayoutOrder = 1,
		Parent = tools,
	})
	bagRefs.sellCommons = Kit.ActionButton("Sell Commons", "Red", function()
		Net.RequestSellCommons:FireServer()
	end, { Size = UDim2.fromOffset(120, 46), TextSize = 14, LayoutOrder = 3, Parent = tools })

	bagRefs.hint = Kit.Label({
		Text = "",
		TextSize = 14,
		Font = T.Bold,
		Position = UDim2.fromOffset(4, 54),
		Size = UDim2.new(1, -8, 0, 20),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = body,
	})
	local gridWell = Kit.Well({ Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 1, -78), Parent = body })
	bagRefs.grid = Kit.Scroll({ Size = UDim2.fromScale(1, 1), Parent = gridWell })
	bagRefs.grid.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	bagRefs.grid.ScrollBarImageTransparency = 0.6
	local grid = Kit.Grid(Vector2.new(112, 150), 10)
	grid.Parent = bagRefs.grid
	fitGrid(bagRefs.grid, grid, 112, 150, 10)
	bagRefs.empty = New("Frame", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 210),
		Visible = false,
		ZIndex = 2,
		Parent = gridWell,
	})
	local bagBlue = Color3.fromRGB(60, 160, 255)
	local emptyIcon = Kit.IconFill(
		Icons.Get("Bag"),
		bagBlue,
		64,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), ZIndex = 2, Parent = bagRefs.empty }
	)
	Kit.Glow(emptyIcon, bagBlue, 10, { Size = UDim2.fromScale(1.5, 1.5), Layers = 12, Peak = 0.35, ZIndex = 1 })
	bagRefs.emptyTitle = Kit.Text("", 24, {
		Position = UDim2.fromOffset(12, 104),
		Size = UDim2.new(1, -24, 0, 30),
		TextScaled = true,
		ZIndex = 2,
		Parent = bagRefs.empty,
	})
	bagRefs.emptyText = Kit.Label({
		Text = "",
		Font = T.Bold,
		TextSize = 14,
		ZIndex = 2,
		TextColor3 = Kit.Clean.Sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 138),
		Size = UDim2.new(1, -32, 0, 44),
		Parent = bagRefs.empty,
	})
	-- Only cards scrolled into view get their 3D model (keeps big storages smooth); the pop-up
	-- closes on scroll, since its card moves away
	bagRefs.grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		realizeVisibleCards()
		if pop.key and string.sub(pop.key, 1, 2) ~= "C:" then
			closePopup()
		end
	end)
	bagRefs.grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		realizeVisibleCards()
	end)
	New("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 6),
		Parent = bagRefs.grid,
	})
end

------------------------------------------------------------------------------------------
-- Upgrades: suit hero card + one big pressable card per stat (the whole card is the button)
------------------------------------------------------------------------------------------
local upScroll
local upSig = ""
local upCoins: TextLabel? = nil -- your coins, in the window's title band

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
		title = "Dive Gear",
		color = Color3.fromRGB(63, 214, 230),
		tracks = { "Oxygen", "Fins", "Bag", "Sonar", "Salvage", "Board" },
	},
	{ title = "Dock", color = T.Gold, tracks = { "Display", "Offline" } },
	{ title = "Dock Defense", color = Color3.fromRGB(240, 90, 90), tracks = { "Gate", "Crab", "Alarm" } },
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

-- One upgrade: a gradient card in the track's colour (Kit.NeonCard). Icon, name, level and a
-- thin level bar on top; what the next level does in the dark strip; the price along the bottom
-- (green = you can pay, grey = not yet, gold MAX = done). The whole card is the button.
local function upgradeCard(parent: Instance, track, lvl: number, coins: number, order: number)
	local maxed = lvl >= track.Max
	local cost = if maxed then 0 else Upgrades.Cost(track.Id, lvl)
	local affordable = not maxed and coins >= cost
	local color = TRACK_COLORS[track.Id] or T.Accent
	local C = Kit.Clean
	local container, face = Kit.NeonCard(color, { Name = track.Id, LayoutOrder = order, Parent = parent }, function()
		if maxed then
			controllers.UIController.Toast(`{track.Name} is maxed!`, "info")
			return
		end
		Net.RequestUpgrade:FireServer(track.Id)
	end)
	local icon = Kit.IconFill(Icons.Track(track.Id), Kit.Lighten(color, 0.55), 60, {
		Position = UDim2.fromOffset(12, 9),
		ZIndex = 2,
		Parent = face,
	})
	Kit.Glow(icon, Kit.Lighten(color, 0.45), 10, {
		Size = UDim2.fromScale(1.35, 1.35),
		Layers = 12,
		Peak = 0.42,
		ZIndex = 2,
	})
	Kit.Text(track.Name, 18, {
		Name = "Name",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(82, 7),
		Size = UDim2.new(1, -90, 0, 24),
		ZIndex = 3,
		Parent = face,
	})
	Kit.Label({
		Text = if maxed then `Lv {lvl} · MAX` else `Lv {lvl} / {track.Max}`,
		Font = T.Bold,
		TextSize = 13,
		TextColor3 = if maxed then C.Gold else Kit.Lighten(color, 0.55),
		Position = UDim2.fromOffset(82, 32),
		Size = UDim2.new(1, -90, 0, 16),
		TextWrapped = false,
		ZIndex = 3,
		Parent = face,
	})
	local bar = New("Frame", {
		Name = "Level",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		Position = UDim2.fromOffset(82, 54),
		Size = UDim2.new(1, -94, 0, 8),
		ZIndex = 3,
		Parent = face,
	}, { Kit.Round() })
	if lvl > 0 then
		New("Frame", {
			Name = "Fill",
			BackgroundColor3 = if maxed then C.Gold else Kit.Lighten(color, 0.35),
			Size = UDim2.fromScale(math.clamp(lvl / track.Max, 0.06, 1), 1),
			ZIndex = 3,
			Parent = bar,
		}, { Kit.Round() })
	end

	-- Effect rows: "Dive time  60s -> 66s". The Diving Board shows two rows (launch and depth).
	local rows = effectRows(track.Id, lvl)
	local rowH = if #rows > 1 then 18 else 26
	local effect = New("Frame", {
		Name = "Effect",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.62,
		Position = UDim2.fromOffset(12, 74),
		Size = UDim2.new(1, -24, 0, rowH * #rows),
		ZIndex = 3,
		Parent = face,
	}, { Kit.Corner(8), New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }) })
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
			TextColor3 = Color3.fromRGB(214, 219, 230),
			Size = UDim2.fromScale(0.5, 1),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
			Parent = line,
		})
		local now, nxt = row[2], row[3]
		Kit.Label({
			Text = if maxed then now else `{now}  <font color="#7CFF4D">→ {nxt}</font>`,
			RichText = true,
			Font = T.Bold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
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

	-- Price: a coin and a big number, centred along the bottom
	local price = New("Frame", {
		Name = "Price",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -24, 0, 30),
		ZIndex = 3,
		Parent = face,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	if not maxed then
		Kit.IconFill(Icons.Get("Coins"), C.Gold, 24, { LayoutOrder = 1, ZIndex = 3, Parent = price })
	end
	Kit.Text(if maxed then "MAX" else coinText(cost), 24, {
		TextColor3 = if maxed then C.Gold elseif affordable then C.Go else C.Off,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = price,
	})
	if affordable then
		Kit.CardTag(face, "Upgrade!", C.Go, {
			OutlineColor = C.Ink,
			Outline = 3,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0, -3),
			Size = UDim2.fromOffset(100, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
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
	if upCoins then
		upCoins.Text = coinText(coins)
	end

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

	-- Suit card: suits are bought in the Suit Shop now (stall on the dock, or this card)
	local C = Kit.Clean
	local suitZone = Upgrades.SuitZone(suitIndex)
	local suitAffordable = nextSuit ~= nil and not nextSuit.ComingSoon and coins >= nextSuit.Cost
	local function openSuits()
		controllers.UIController.Open("Suits")
	end
	local _, sr = Kit.NeonCard(
		suit.Color,
		{ Name = "Suit", Size = UDim2.new(1, -8, 0, 132), LayoutOrder = o(), Sideways = true, Parent = upScroll },
		openSuits
	)
	local stage = New("Frame", {
		Name = "Stage",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.6,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(96, 96),
		ZIndex = 3,
		Parent = sr,
	}, { Kit.Corner(14) })
	Kit.Glow(stage, Kit.Lighten(suit.Color, 0.3), 96)
	RelicView.Archetype(
		"helmet",
		{ main = suit.Color, accent = Color3.fromRGB(255, 196, 64) },
		{ Spin = 30, ZIndex = 4, Parent = stage }
	)
	Kit.Button("Customize", T.Accent, function()
		controllers.UIController.Open("Diver")
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 14),
		Size = UDim2.fromOffset(104, 28),
		TextSize = 12,
		ZIndex = 6,
		Parent = stage,
	})
	Kit.Text(suit.Name, 25, {
		Name = "Name",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(122, 8),
		Size = UDim2.new(1, -322, 0, 30),
		ZIndex = 3,
		Parent = sr,
	})
	Kit.Label({
		Text = `Safe down to {Zones.List[math.min(suitZone, #Zones.List)].Name}`,
		Font = T.Bold,
		TextColor3 = Kit.Lighten(suit.Color, 0.55),
		TextSize = 14,
		Position = UDim2.fromOffset(122, 40),
		Size = UDim2.new(1, -322, 0, 18),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = sr,
	})
	-- Zone ladder: unlocked zones lit, the next one outlined, the rest dim with a lock
	local pips = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(122, 68),
		Size = UDim2.new(1, -322, 0, 44),
		ZIndex = 3,
		Parent = sr,
	}, { Kit.List(6, true) })
	for i, zone in Zones.List do
		local ok = i <= suitZone
		local zc = Kit.Lighten(zone.FogColor, 0.35)
		local badge = Kit.IconBadge(
			Icons.Get(zone.Id),
			if ok then zc else Color3.fromRGB(70, 74, 88),
			40,
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
		if i == suitZone + 1 then
			local st = badge:FindFirstChildOfClass("UIStroke")
			st.Color, st.Transparency = C.Gold, 0
		end
	end
	local right = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(180, 116),
		ZIndex = 3,
		Parent = sr,
	})
	Kit.Label({
		Text = if nextSuit then "NEXT SUIT" else "ALL SUITS OWNED",
		Font = T.Bold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(214, 219, 230),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 3,
		Parent = right,
	})
	Kit.Text(if nextSuit then nextSuit.Name else suit.Name, 21, {
		TextColor3 = Kit.Lighten((nextSuit or suit).Color, 0.45),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 3,
		Parent = right,
	})
	Kit.Label({
		Text = if not nextSuit then ""
			elseif nextSuit.ComingSoon then `Coming soon · {coinText(nextSuit.Cost)}`
			else `{coinText(nextSuit.Cost)} Coins`,
		Font = T.Bold,
		TextSize = 13,
		TextColor3 = if suitAffordable then C.Go else Color3.fromRGB(214, 219, 230),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 45),
		Size = UDim2.new(1, 0, 0, 16),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = right,
	})
	local shopButton = Kit.Button("SUIT SHOP", if suitAffordable then T.Good else T.Accent, openSuits, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 21,
		ZIndex = 4,
		Parent = right,
	})
	if suitAffordable then
		Kit.Pulse(shopButton)
	end

	-- One card per stat, grouped by what it improves
	for _, section in UPGRADE_SECTIONS do
		Kit.SectionTitle(upScroll, o(), section.title)
		local grid = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = o(),
			Parent = upScroll,
		}, {
			-- room for the "Upgrade!" tags, which sit over a card's top edge
			New("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4) }),
		})
		New("UIGridLayout", {
			CellSize = UDim2.new(1 / cols, -math.ceil(10 * (cols - 1) / cols), 0, 146),
			CellPadding = UDim2.fromOffset(10, 16),
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
			local red = Color3.fromRGB(240, 70, 80)
			local _, gf = Kit.NeonCard(
				if gateLvl > 0 then red else Color3.fromRGB(110, 116, 132),
				{ Name = "ActivateGate", LayoutOrder = 99, Parent = grid },
				function()
					if gateLvl > 0 then
						Net.ActivateGate:FireServer()
					else
						controllers.UIController.Toast("Buy the Laser Gate upgrade first.", "error")
					end
				end
			)
			Kit.IconFill(Icons.Get("Gate"), Kit.Lighten(red, 0.5), 60, {
				Position = UDim2.fromOffset(12, 9),
				ZIndex = 2,
				Parent = gf,
			})
			Kit.Text("Activate Gate", 18, {
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(82, 7),
				Size = UDim2.new(1, -90, 0, 24),
				ZIndex = 3,
				Parent = gf,
			})
			Kit.Label({
				Text = "Blocks raids on your dock for a while",
				Font = T.Bold,
				TextSize = 13,
				TextColor3 = Color3.fromRGB(230, 232, 240),
				Position = UDim2.fromOffset(82, 32),
				Size = UDim2.new(1, -90, 0, 50),
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 3,
				Parent = gf,
			})
			Kit.Text(if gateLvl > 0 then "ACTIVATE" else "LOCKED", 24, {
				TextColor3 = if gateLvl > 0 then C.Go else C.Off,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -24, 0, 30),
				ZIndex = 3,
				Parent = gf,
			})
		end
	end
end

------------------------------------------------------------------------------------------
-- Codex: zone tabs + 3D card grid (silhouettes for undiscovered relics)
------------------------------------------------------------------------------------------
local codexScroll, codexTitle, codexSetBar, codexPaintTabs
local codexSig = ""
local codexBody: Frame? = nil

local function variantCount(entry): number
	local n = 0
	if entry then
		for _ in entry do
			n += 1
		end
	end
	return n
end

-- Tapping a card opens the shared relic pop-up: facts and a View button that opens the
-- full-screen viewer (RelicViewer). Undiscovered relics show "???" and where to search.
local function openCodexPopup(def, card: GuiObject)
	local entry = (S.Get("Codex") or {})[def.Id]
	local found = entry ~= nil
	local zone = Zones.List[def.Zone]
	local variants = variantCount(entry)
	local total = #Mutations.List + 1
	relicPopup({
		Key = "C:" .. def.Id,
		Body = codexBody,
		Card = card,
		Title = if found then def.Name else "???",
		Rarity = def.Rarity,
		Sub = if found then `"{def.Lore}"` else `Search {zone.Name} to discover it.`,
		Lines = {
			if found then { `Variants {variants}/{total}`, Color3.new(1, 1, 1) } else { "Not found yet", Kit.Clean.Off },
			{ `+{NumberFormat.short(def.BaseCPS)} Coins/s base`, Kit.Clean.Go },
			{ `Found in {zone.Name}`, Kit.Clean.Sub },
		},
		ViewText = if found then "View" else "Find it to view",
		OnView = if found
			then function()
				RelicViewer.Open({
					Id = def.Id,
					Info = { def.Rarity, zone.Name, `+{NumberFormat.short(def.BaseCPS)}/s base`, `Variants {variants}/{total}` },
				})
			end
			else nil,
	})
end

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
		table.insert(parts, `{def.Id}:{if entry then variantCount(entry) else -1}`)
	end
	local sig = table.concat(parts, "|")
	if sig == codexSig then
		return
	end
	codexSig = sig

	if pop.key and string.sub(pop.key, 1, 2) == "C:" then
		closePopup()
	end
	Kit.Clear(codexScroll)
	for i, def in defs do
		local entry = codex[def.Id]
		local card
		card = RelicCard.new({
			Def = def,
			Discovered = entry ~= nil,
			Subtitle = if entry then `Variants {variantCount(entry)}/{#Mutations.List + 1}` else def.Rarity,
			LayoutOrder = i,
			OnClick = function()
				if pop.key == "C:" .. def.Id then
					closePopup()
				else
					openCodexPopup(def, card)
				end
			end,
			Parent = codexScroll,
		})
	end
end

local function buildCodex(body: Frame)
	codexBody = body
	local items = {}
	for i, zone in Zones.List do
		table.insert(items, { id = tostring(i), text = zone.Name, color = Kit.Lighten(zone.FogColor, 0.3) })
	end
	local tabScroll = Kit.Scroll({
		Size = UDim2.new(1, 0, 0, 46),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		Parent = body,
	})
	local tabs
	tabs, codexPaintTabs = Kit.FlatTabs(tabScroll, items, tostring(codexZone), function(id)
		closePopup()
		codexZone = tonumber(id) or 1
		codexSig = ""
		renderCodex()
	end, { Size = UDim2.new(0, 0, 0, 42), AutomaticSize = Enum.AutomaticSize.X })
	tabs.Name = "ZoneTabs"
	-- Zone progress: a dark row with the count, a wide bar, and the completion reward
	local strip = New("Frame", {
		Name = "Progress",
		BackgroundColor3 = Kit.Clean.Row,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = body,
	}, { Kit.Corner(12), Kit.Stroke(Kit.Clean.RowEdge, 1.5, 0) })
	codexTitle = Kit.Text("", 19, {
		Outline = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(0.42, -14, 0, 24),
		Parent = strip,
	})
	Kit.Label({
		Text = "relics found",
		Font = T.Bold,
		TextSize = 12,
		TextColor3 = Kit.Clean.Sub,
		Position = UDim2.fromOffset(14, 31),
		Size = UDim2.new(0.42, -14, 0, 16),
		TextWrapped = false,
		Parent = strip,
	})
	local _, setBar = Kit.Bar({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.42, 0, 0.5, 0),
		Size = UDim2.new(0.58, -176, 0, 24),
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
	local well = Kit.Well({ Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 1, -114), Parent = body })
	codexScroll = Kit.Scroll({ Size = UDim2.fromScale(1, 1), Parent = well })
	codexScroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	codexScroll.ScrollBarImageTransparency = 0.6
	local grid = Kit.Grid(Vector2.new(112, 150), 10)
	grid.Parent = codexScroll
	fitGrid(codexScroll, grid, 112, 150, 10)
	New("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 6),
		Parent = codexScroll,
	})
	codexScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if pop.key and string.sub(pop.key, 1, 2) == "C:" then
			closePopup()
		end
	end)
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
		return "star", `{reward.Relic} relic`, Kit.RarityColor(reward.Relic, Rarities)
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

-- Reward tile in the clean card look: label on top, glowing icon, what you get at the bottom.
-- Claimable = gold card with a green "Claim!"; claimed = dimmed with a green tick; locked =
-- dimmed with a lock; future = a little dimmed.
local function rewardTile(parent: Instance, reward, state: string, order: number, onClick, labelTop: string?)
	-- state: "claimable" | "claimed" | "locked" | "future"
	local icon, text, color = rewardInfo(reward)
	local claimable = state == "claimable"
	local container, card = Kit.NeonCard(if claimable then T.Gold else color, {
		Name = "Reward",
		Size = UDim2.fromOffset(88, 100),
		Corner = 14,
		LayoutOrder = order,
		Parent = parent,
	}, onClick)
	if labelTop then
		Kit.Text(labelTop, 14, {
			Outline = 2,
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 3,
			Parent = card,
		})
	end
	local holder = Kit.IconFill(icon, color:Lerp(Color3.new(1, 1, 1), 0.4), 38, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 2,
		Parent = card,
	})
	Kit.Glow(holder, color:Lerp(Color3.new(1, 1, 1), 0.4), 10, {
		Size = UDim2.fromScale(1.5, 1.5),
		Layers = 12,
		Peak = 0.35,
		ZIndex = holder.ZIndex,
	})
	local bottom = Kit.Text(if claimable then "Claim!" else text, if claimable then 18 else 12, {
		Outline = 2,
		TextColor3 = if claimable then Kit.Clean.Go else Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -8, 0, 26),
		ZIndex = 3,
		Parent = card,
	})
	New("UITextSizeConstraint", { MaxTextSize = if claimable then 18 else 12, MinTextSize = 8, Parent = bottom })
	if state ~= "claimable" then
		New("Frame", {
			Name = "Dim",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = if state == "future" then 0.55 else 0.4,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = card,
		}, { Kit.Corner(14) })
	end
	if state == "claimed" then
		equippedTick(card)
	elseif state == "locked" then
		Kit.IconFill(Icons.Get("Lock"), Color3.new(1, 1, 1), 22, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 26),
			ZIndex = 9,
			Parent = card,
		})
	elseif claimable then
		Kit.Shine(card, 1.2)
	end
	return container
end

-- A quest row: a gold neon card you can press when it's ready to claim, else a dark row
local function questRow(parent: Instance, order: number, claimable: boolean, onClaim)
	if claimable then
		local _, card = Kit.NeonCard(T.Gold, {
			Name = "Quest",
			Sideways = true,
			Corner = 12,
			Size = UDim2.new(1, -8, 0, 84),
			LayoutOrder = order,
			Parent = parent,
		}, onClaim)
		return card
	end
	return New("Frame", {
		Name = "Quest",
		BackgroundColor3 = Kit.Clean.Row,
		Size = UDim2.new(1, -8, 0, 84),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.Corner(12), Kit.Stroke(Kit.Clean.RowEdge, 1.5, 0) })
end

local tideTrackScroll = nil
local questSig = ""
local function renderQuests()
	local streak = S.Get("LoginStreak") or 1
	local claimedToday = (S.Get("LastDailyClaimDay") or 0) == os.time() // 86400
	local q = S.Get("Quests") or {}
	local tp = S.Get("TidePass") or { XP = 0, Premium = false, ClaimedFree = {}, ClaimedPremium = {} }
	-- rebuild only when something visible changed (this window refreshes every second)
	local ok, sig = pcall(function()
		return HttpService:JSONEncode({ streak, claimedToday, q, tp })
	end)
	sig = if ok then sig else tostring(os.clock())
	if sig == questSig then
		return
	end
	questSig = sig

	local keepX = if tideTrackScroll and tideTrackScroll.Parent then tideTrackScroll.CanvasPosition.X else nil
	Kit.Clear(questScroll)
	local order = 0
	local function o()
		order += 1
		return order
	end
	-- Login calendar
	Kit.SectionTitle(questScroll, o(), `Daily login - {streak} day streak`)
	local cal = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 106), LayoutOrder = o(), Parent = questScroll },
		{ Kit.List(8, true, Enum.HorizontalAlignment.Center) }
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

	for _, section in
		{
			{ "Daily quests", q.Daily or {}, T.Accent },
			{ "Weekly quests", q.Weekly or {}, Color3.fromRGB(180, 140, 255) },
		}
	do
		Kit.SectionTitle(questScroll, o(), section[1])
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
				local accent: Color3 = if done then T.Good else section[3]
				local r = questRow(questScroll, o(), claimable, claim)
				local icon = Kit.IconFill(QUEST_ICONS[def.Stat] or "quests", accent, 40, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 16, 0.5, 0),
					Size = UDim2.fromOffset(46, 46),
					ZIndex = 3,
					Parent = r,
				})
				Kit.Glow(icon, accent, 10, { Size = UDim2.fromScale(1.5, 1.5), Layers = 12, Peak = 0.3, ZIndex = 2 })
				Kit.Text(def.Text, 18, {
					Outline = 2,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Position = UDim2.fromOffset(76, 7),
					Size = UDim2.new(1, -220, 0, 24),
					ZIndex = 3,
					Parent = r,
				})
				local _, setBar = Kit.Bar({
					Position = UDim2.fromOffset(76, 35),
					Size = UDim2.new(1, -220, 0, 18),
					TextSize = 12,
					Color = accent,
					Parent = r,
				})
				setBar(entry.Progress / def.Goal, nil, `{math.min(entry.Progress, def.Goal)} / {def.Goal}`)
				-- rewards as coloured words: coins gold, pearls pearl, XP cyan
				local rewards = New("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(76, 58),
					Size = UDim2.new(1, -220, 0, 18),
					ZIndex = 3,
					Parent = r,
				}, { Kit.List(12, true) })
				local function word(text: string, color: Color3, n: number)
					Kit.Text(text, 14, {
						Outline = 2,
						TextColor3 = color,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 18),
						LayoutOrder = n,
						ZIndex = 3,
						Parent = rewards,
					})
				end
				if def.Coins then
					word(`{NumberFormat.short(def.Coins)} Coins`, Kit.Clean.Gold, 1)
				end
				if def.Pearls then
					word(`{def.Pearls} Pearls`, T.Pearl, 2)
				end
				word(`+{def.Xp} XP`, T.Accent, 3)
				-- Right side: a real button only when there is something to press
				if claimable then
					local b = Kit.ActionButton("Claim!", "Green", claim, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(124, 52),
						TextSize = 20,
						ZIndex = 4,
						Parent = r,
					})
					Kit.Pulse(b, 0.04)
				elseif entry.Claimed then
					Kit.Text("Done!", 26, {
						TextColor3 = Kit.Clean.Go,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -12, 0.5, 0),
						Size = UDim2.fromOffset(124, 32),
						ZIndex = 3,
						Parent = r,
					})
				else
					local pct = math.floor(math.min(entry.Progress / def.Goal, 1) * 100)
					local chip = Kit.Text(`{pct}%`, 26, {
						TextColor3 = Kit.Clean.Off,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -12, 0, 14),
						Size = UDim2.fromOffset(124, 30),
						ZIndex = 3,
						Parent = r,
					})
					chip.Name = "Percent"
					Kit.Label({
						Text = "In progress",
						Font = T.Bold,
						TextSize = 12,
						TextColor3 = Kit.Clean.Sub,
						TextXAlignment = Enum.TextXAlignment.Center,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -12, 0, 48),
						Size = UDim2.fromOffset(124, 14),
						TextWrapped = false,
						ZIndex = 3,
						Parent = r,
					})
				end
			end
		end
	end

	-- Tide Pass: horizontal reward track
	local TPc = Economy.TidePass
	local tier = tp.XP // TPc.XpPerTier
	Kit.SectionTitle(questScroll, o(), `Tide Pass {TPc.SeasonId} - Tier {tier}/{TPc.Tiers}`)
	local top = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 54), LayoutOrder = o(), Parent = questScroll }
	)
	local _, setTp = Kit.Bar({
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, if tp.Premium then 0 else -372, 0, 24),
		Color = T.Gold,
		Parent = top,
	})
	setTp((tp.XP % TPc.XpPerTier) / TPc.XpPerTier, nil, `{tp.XP % TPc.XpPerTier}/{TPc.XpPerTier} XP to tier {tier + 1}`)
	if not tp.Premium then
		Kit.ActionButton("Premium 499 R$", "Gold", function()
			Net.RequestPurchase:FireServer("Product", "TidePassPremium")
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -186, 0, 0),
			Size = UDim2.fromOffset(176, 52),
			TextSize = 16,
			Icon = "ticket",
			Parent = top,
		})
		Kit.ActionButton(`{TPc.PremiumPearlCost} Pearls`, "Blue", function()
			Net.RequestBuyTidePassPearls:FireServer()
		end, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(176, 52),
			TextSize = 16,
			Icon = "pearl",
			Parent = top,
		})
	end
	local track = New("Frame", {
		Name = "TideTrack",
		BackgroundColor3 = Kit.Clean.Row,
		Size = UDim2.new(1, -8, 0, 270),
		LayoutOrder = o(),
		Parent = questScroll,
	}, { Kit.Corner(12), Kit.Stroke(Kit.Clean.RowEdge, 1.5, 0) })
	Kit.Text("FREE", 16, {
		Outline = 2,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(6, 70),
		Size = UDim2.fromOffset(74, 20),
		Parent = track,
	})
	Kit.Text("PREMIUM", 15, {
		Outline = 2,
		TextColor3 = Kit.Clean.Gold,
		Position = UDim2.fromOffset(6, 180),
		Size = UDim2.fromOffset(74, 20),
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
	tideTrackScroll.ScrollBarImageColor3 = Color3.new(1, 1, 1)
	tideTrackScroll.ScrollBarImageTransparency = 0.6
	Kit.List(8, true).Parent = tideTrackScroll
	for t = 1, TPc.Tiers do
		local col = New(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.fromOffset(92, 246), LayoutOrder = t, Parent = tideTrackScroll }
		)
		local reached = tier >= t
		Kit.Text(`Tier {t}`, 15, {
			Outline = 2,
			TextColor3 = if reached then Kit.Clean.Gold else Kit.Clean.Off,
			Size = UDim2.new(1, 0, 0, 22),
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
	-- first build: scroll to your tier; later rebuilds keep where you had scrolled
	task.defer(function()
		if tideTrackScroll then
			tideTrackScroll.CanvasPosition = Vector2.new(keepX or math.max(0, (tier - 1) * 100), 0)
		end
	end)
end

------------------------------------------------------------------------------------------
-- Rebirth: before/after preview, requirements, talents
------------------------------------------------------------------------------------------
local rebirthScroll
local rebirthSig = ""

-- Wrapping row of coloured words (what you keep / what resets)
local function wordCloud(parent: Instance, items, color: Color3)
	local cloud = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
		Parent = parent,
	})
	local l = Kit.List(6, true)
	l.Wraps = true
	l.Parent = cloud
	for i, text in items do
		local chip = New("Frame", {
			BackgroundColor3 = Kit.Clean.Well,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = i,
			ZIndex = 3,
			Parent = cloud,
		}, {
			Kit.Corner(8),
			Kit.Stroke(Kit.Darken(color, 0.35), 1.5, 0),
			New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
		})
		Kit.Text(text, 14, {
			Outline = 2,
			TextColor3 = Kit.Lighten(color, 0.25),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			ZIndex = 3,
			Parent = chip,
		})
	end
end

-- A dark row in the Settings-row style
local function darkRow(props)
	local p = { BackgroundColor3 = Kit.Clean.Row }
	for k, v in props do
		p[k] = v
	end
	return New("Frame", p, { Kit.Corner(12), Kit.Stroke(Kit.Clean.RowEdge, 1.5, 0) })
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

	-- Before -> after: two neon cards with a glowing arrow between
	local compare = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 150), LayoutOrder = 1, Parent = rebirthScroll }
	)
	local function statCard(x: UDim, title: string, color: Color3, lines)
		local _, c = Kit.NeonCard(color, {
			Position = UDim2.new(x, 0, 0, 0),
			Size = UDim2.new(0.5, -34, 1, 0),
			Parent = compare,
		})
		Kit.Text(title, 16, {
			Outline = 2,
			TextColor3 = Kit.Lighten(color, 0.5),
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 20),
			ZIndex = 3,
			Parent = c,
		})
		local big = Kit.Text(lines[1], 36, {
			Position = UDim2.fromOffset(8, 34),
			Size = UDim2.new(1, -16, 0, 44),
			TextScaled = true,
			ZIndex = 3,
			Parent = c,
		})
		New("UITextSizeConstraint", { MaxTextSize = 36, MinTextSize = 16, Parent = big })
		Kit.Text(lines[2], 17, {
			TextColor3 = Kit.Clean.Go,
			Position = UDim2.fromOffset(0, 86),
			Size = UDim2.new(1, 0, 0, 22),
			ZIndex = 3,
			Parent = c,
		})
		Kit.Text(lines[3], 17, {
			TextColor3 = Kit.Clean.Gold,
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 0, 22),
			ZIndex = 3,
			Parent = c,
		})
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
	local arrow = Kit.IconFill("arrow", Kit.Clean.Gold, 40, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 5,
		Parent = compare,
	})
	Kit.Glow(arrow, Kit.Clean.Gold, 10, { Size = UDim2.fromScale(1.6, 1.6), Layers = 12, Peak = 0.4, ZIndex = 4 })

	-- Requirements: a green tick or red cross per requirement (drawn icons, no glyphs)
	local req = darkRow({ Size = UDim2.new(1, -8, 0, 124), LayoutOrder = 2, Parent = rebirthScroll })
	Kit.Text("Requirements", 20, {
		Outline = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.5, 0, 0, 26),
		ZIndex = 3,
		Parent = req,
	})
	Kit.Text(`Resurfaced {n}x`, 15, {
		Outline = 2,
		TextColor3 = Kit.Clean.Sub,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(200, 22),
		ZIndex = 3,
		Parent = req,
	})
	local function check(y: number, ok: boolean, text: string)
		local dot = New("Frame", {
			BackgroundColor3 = if ok then Color3.fromRGB(60, 200, 30) else Color3.fromRGB(224, 43, 60),
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.fromOffset(30, 30),
			ZIndex = 3,
			Parent = req,
		}, { Kit.Round(), Kit.Stroke(Kit.Clean.Ink, 2, 0) })
		Kit.IconFill(if ok then "check" else "close", Color3.new(1, 1, 1), 16, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 4,
			Parent = dot,
		})
		Kit.Text(text, 16, {
			Outline = 2,
			TextColor3 = if ok then Color3.new(1, 1, 1) else Kit.Clean.Off,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(54, y),
			Size = UDim2.new(0, 260, 0, 30),
			ZIndex = 3,
			Parent = req,
		})
	end
	check(42, suitOk, `Own the {Upgrades.Suits[Economy.Rebirth.RequiredSuit].Name} suit`)
	check(80, coinOk, "Earn lifetime Coins")
	local _, setReq = Kit.Bar({
		Position = UDim2.new(0, 230, 0, 83),
		Size = UDim2.new(1, -246, 0, 24),
		Color = if coinOk then T.Good else T.Gold,
		Parent = req,
	})
	setReq(lifetime / math.max(need, 1), nil, `{NumberFormat.short(lifetime)} / {NumberFormat.short(need)}`)

	-- The big button: gold and pulsing when ready, grey with a lock otherwise
	local btn = Kit.ActionButton(if ready then "Resurface!" else "Resurface", if ready then "Gold" else "Grey", function()
		Net.RequestRebirth:FireServer()
	end, {
		Size = UDim2.new(1, -8, 0, 66),
		TextSize = 30,
		Icon = if ready then "rebirth" else "lock",
		LayoutOrder = 3,
		Parent = rebirthScroll,
	})
	if ready then
		Kit.Pulse(btn, 0.02)
	end

	-- Keep / resets
	local keep = New(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 116), LayoutOrder = 4, Parent = rebirthScroll }
	)
	local function chipCard(x: UDim, title: string, color: Color3, items)
		local c = darkRow({ Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.5, -5, 1, 0), Parent = keep })
		Kit.Text(title, 18, {
			Outline = 2,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 24),
			ZIndex = 3,
			Parent = c,
		})
		wordCloud(c, items, color)
	end
	chipCard(
		UDim.new(0, 0),
		"YOU KEEP",
		Kit.Clean.Go,
		{ "Relics on stands", "Storage", "Codex", "Pearls", "Passes", "Level", "Display Slots" }
	)
	chipCard(UDim.new(0.5, 5), "RESETS", T.Bad, { "Coins", "Upgrades", "Suit", "Dive bag" })

	-- Talent tree: whole-card buttons like Upgrades
	Kit.SectionTitle(rebirthScroll, 5, `Talent tree - {tokens} token{tokens == 1 and "" or "s"}`)
	local grid = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
		Parent = rebirthScroll,
	}, { New("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
	New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 132),
		CellPadding = UDim2.fromOffset(12, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local TALENT_ICONS = { StartNeoprene = "diver", ExtraBag = "bag", QuietDiver = "sonar", Lungs = "oxygen" }
	local purple = Color3.fromRGB(180, 140, 255)
	for i, t in Economy.Rebirth.Talents do
		local lvl = talents[t.Id] or 0
		local maxed = lvl >= t.Max
		local affordable = not maxed and tokens >= t.Cost
		local color = if maxed then T.Gold else purple
		local _, f = Kit.NeonCard(color, { Sideways = true, Corner = 14, LayoutOrder = i, Parent = grid }, function()
			Net.RequestTalent:FireServer(t.Id)
		end)
		local icon = Kit.IconFill(TALENT_ICONS[t.Id] or "star", color:Lerp(Color3.new(1, 1, 1), 0.4), 44, {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(48, 48),
			ZIndex = 3,
			Parent = f,
		})
		Kit.Glow(icon, color, 10, { Size = UDim2.fromScale(1.5, 1.5), Layers = 12, Peak = 0.35, ZIndex = 2 })
		Kit.Text(t.Name, 18, {
			Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(70, 8),
			Size = UDim2.new(1, -78, 0, 24),
			ZIndex = 3,
			Parent = f,
		})
		Kit.Label({
			Text = t.Desc,
			Font = T.Bold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(220, 222, 232),
			Position = UDim2.fromOffset(70, 33),
			Size = UDim2.new(1, -78, 0, 30),
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
			Parent = f,
		})
		local pips = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 68),
			Size = UDim2.new(1, -24, 0, 12),
			ZIndex = 3,
			Parent = f,
		}, { Kit.List(4, true) })
		for p = 1, t.Max do
			New("Frame", {
				BackgroundColor3 = if p <= lvl then Kit.Lighten(color, 0.2) else Kit.Clean.Well,
				Size = UDim2.new(1 / t.Max, -4, 1, 0),
				LayoutOrder = p,
				ZIndex = 3,
				Parent = pips,
			}, { Kit.Round(), Kit.Stroke(Kit.Clean.Ink, 1.5, 0) })
		end
		Kit.Text(
			if maxed then "MAX" else `{t.Cost} token{t.Cost == 1 and "" or "s"}`,
			24,
			{
				TextColor3 = if maxed then Kit.Clean.Gold elseif affordable then Kit.Clean.Go else Kit.Clean.Off,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 32),
				ZIndex = 3,
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

-- On/off switch (Settings, Diver window): the green pill switch
local function toggle(parent: Instance, on: boolean, onChange: (boolean) -> (), props)
	local track = Kit.Toggle(on, onChange, props)
	track.Parent = parent
	return track
end

-- A dark rounded row: a bold title, a small grey line under it, controls on the right.
-- `reserve` is the width kept free on the right for those controls. (The icon and colour of the
-- older look are still accepted, and ignored: the clean rows carry no icon tile.)
local function settingRow(
	parent: Instance,
	order: number,
	title: string?,
	subtitle: string?,
	_icon: string?,
	_color: Color3?,
	reserve: number?
)
	return Kit.SettingRow(parent, order, title, subtitle, reserve)
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
	local C = Kit.Clean
	local settings = table.clone(S.Get("Settings") or { Music = 0.6, SFX = 0.8, LowScare = false })
	local function save()
		Net.UpdateSettings:FireServer(settings)
	end
	Kit.SectionTitle(settingsScroll, 1, "Sound")
	-- Volume: a slider and a percent readout. The readout follows the knob while you drag; the
	-- new volume is sent once, when you let go.
	local function volume(order: number, label: string, desc: string, key: string)
		local r = settingRow(settingsScroll, order, label, desc)
		local value = math.clamp(settings[key] or 0, 0, 1)
		local readout = Kit.Label({
			Text = `{math.round(value * 100)}%`,
			Font = T.Bold,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(196, 199, 212),
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(44, 20),
			TextWrapped = false,
			Parent = r,
		})
		Kit.Slider(value, function(v)
			settings[key] = v
			save()
		end, function(v)
			readout.Text = `{math.round(v * 100)}%`
		end, {
			Width = 170,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -56, 0.5, 0),
			Parent = r,
		})
	end
	volume(2, "Music", "Adjust music volume.", "Music")
	volume(3, "Sound effects", "Adjust game sound volume.", "SFX")

	Kit.SectionTitle(settingsScroll, 4, "Gameplay")
	local ls = settingRow(settingsScroll, 5, "Lower jump scares", "Softer Leviathan warnings and effects.", nil, nil, 100)
	toggle(ls, settings.LowScare == true, function(v)
		settings.LowScare = v
		save()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0) })
	local diverRow =
		settingRow(settingsScroll, 6, "Diver appearance", "Show or hide helmet, tank, fins and gear.", nil, nil, 160)
	Kit.Button("Customize", T.Accent, function()
		controllers.UIController.Open("Diver")
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(132, 40),
		TextSize = 16,
		Parent = diverRow,
	})

	Kit.SectionTitle(settingsScroll, 7, "Codes & Dock")
	local function inputRow(order: number, placeholder: string, buttonText: string, buttonColor: Color3, onSubmit: (string) -> ())
		local r = settingRow(settingsScroll, order, nil, nil)
		local box = New("TextBox", {
			PlaceholderText = placeholder,
			PlaceholderColor3 = Color3.fromRGB(120, 123, 138),
			Text = "",
			ClearTextOnFocus = false,
			BackgroundColor3 = Color3.fromRGB(11, 11, 15),
			TextColor3 = T.Text,
			Font = T.Bold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.new(1, -170, 0, 40),
			Parent = r,
		}, {
			Kit.Corner(10),
			Kit.Stroke(C.RowEdge, 1.5, 0),
			New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8) }),
		})
		Kit.Button(buttonText, buttonColor, function()
			onSubmit(box.Text)
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(132, 40),
			TextSize = 16,
			Parent = r,
		})
	end
	inputRow(8, "Enter code", "Redeem", T.Good, function(text)
		Net.RequestRedeemCode:FireServer(text)
	end)
	inputRow(9, `Dock name ({S.Get("RenameTokens") or 0} rename tokens)`, "Rename", T.Gold, function(text)
		Net.RenameDock:FireServer(text)
	end)

	-- Controls: a key cap and what it does, five to a row
	Kit.SectionTitle(settingsScroll, 10, "Controls")
	local keys = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 11,
		Parent = settingsScroll,
	})
	New("UIGridLayout", {
		CellSize = UDim2.new(0.2, -6, 0, 60),
		CellPadding = UDim2.fromOffset(7, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = keys,
	})
	for i, c in CONTROLS do
		local cell = New("Frame", {
			BackgroundColor3 = C.Row,
			LayoutOrder = i,
			Parent = keys,
		}, {
			Kit.Corner(10),
			New("UIStroke", { Color = C.RowEdge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		Kit.Text(c[1], 16, {
			Outline = 2,
			Position = UDim2.fromOffset(0, 7),
			Size = UDim2.new(1, 0, 0, 22),
			TextScaled = true,
			Parent = cell,
		})
		Kit.Label({
			Text = c[2],
			Font = T.Bold,
			TextSize = 13,
			TextColor3 = C.Sub,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 33),
			Size = UDim2.new(1, 0, 0, 18),
			TextWrapped = false,
			Parent = cell,
		})
	end
	Kit.Label({
		Text = "Graphics quality follows your Roblox settings (Esc, then Settings).",
		Font = T.Bold,
		TextColor3 = C.Sub,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
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
	local look = S.Get("SuitLook") or 0
	local wearing = if look >= 1 and look <= suitIndex then look else suitIndex
	local settings = table.clone(S.Get("Settings") or {})
	local worn = Upgrades.Suit(wearing)
	diver.suitName.Text = worn.Name
	diver.suitDesc.Text = `{worn.Desc or ""} Safe down to {Zones.List[math.min(Upgrades.SuitZone(suitIndex), #Zones.List)].Name}.`

	-- Suits are bought and swapped in the Suit Shop
	header(list, 1, "Suits")
	local _, face = Kit.GameCard(T.Gold, { Size = UDim2.new(1, -8, 0, 70), LayoutOrder = 2, Parent = list }, function()
		controllers.UIController.Open("Suits")
	end)
	Kit.IconBadge(Icons.Get("Diver"), Kit.Darken(T.Gold, 0.35), 48, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		ZIndex = 3,
		Parent = face,
	})
	Kit.Title({
		Text = "SUIT SHOP",
		TextSize = 24,
		Position = UDim2.fromOffset(70, 6),
		Size = UDim2.new(1, -80, 0, 30),
		ZIndex = 3,
		Parent = face,
	})
	Kit.Title({
		Text = `{suitIndex}/{#Upgrades.Suits} suits owned · tap to buy or swap`,
		TextSize = 13,
		Position = UDim2.fromOffset(70, 36),
		Size = UDim2.new(1, -80, 0, 18),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = face,
	})

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
	local key = `{suitIndex}:{wearing}`
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
	UI.RegisterWindow("Bag", "Inventory", buildBag, renderBag)
	UI.RegisterWindow("Upgrades", "Upgrades", function(body)
		upScroll = wellScroll(body)
		upScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			UI.Refresh("Upgrades") -- column count follows the window width
		end)
	end, renderUpgrades, {
		-- your coins in the title band, so you can see what you can afford
		Header = function(holder)
			local _, _, label = Kit.Readout(Icons.Get("Coins"), Kit.ReadoutColors.Coins, {
				TextSize = 24,
				IconSize = 30,
				Text = coinText(S.Get("Coins") or 0),
				Parent = holder,
			})
			upCoins = label
		end,
	})
	UI.RegisterWindow("Codex", "Codex", buildCodex, renderCodex)
	UI.RegisterWindow("Quests", "Quests & Tide Pass", function(body)
		questScroll = wellScroll(body)
		questSig = ""
	end, renderQuests)
	UI.RegisterWindow("Rebirth", "Resurface", function(body)
		rebirthScroll = wellScroll(body)
		rebirthSig = ""
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
		settingsScroll = wellScroll(body, Color3.fromRGB(16, 17, 22))
	end, renderSettings, { Plain = true, MaxSize = Vector2.new(580, 580) })

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
		if keys.Settings or keys.Suit or keys.SuitLook then
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
