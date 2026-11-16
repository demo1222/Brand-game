-- ShopController (Master Plan §15, §18.2): tabs for Passes, Boosts, Coins, Pearls, Crates and
-- Abyss Pass+. VIP is always one tap away: its button sits in the title band. Every prompt
-- previews its benefit first (§18.3). Crate odds are displayed from the exact table the server
-- rolls (§16).
-- Look (owner reference docs/reference/shop_upgrades): flat coloured tabs, a dark well, and
-- gradient cards with a thin bright border. The whole card is the buy button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local WeightedRandom = require(Shared.WeightedRandom)
local Passes = require(Shared.Config.Passes)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Config.Economy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local C = Kit.Clean
local ShopController = {}
local controllers
local content: ScrollingFrame
local grid: UIGridLayout
local note: TextLabel
local currentTab = "Passes"
local vipButton: TextButton? = nil
-- the current tab's card shape: wide cards (icon left, text right) or small ones (icon in the
-- middle), and how tall a card is
local shape = { wide = true, height = 138 }

local PASS_ORDER = {
	"VIP",
	"AutoRefill",
	"DoubleOxygen",
	"Drone",
	"LuckySonar",
	"VaultLock",
	"ExtraSlots",
	"BigBag",
	"InstantSurface",
	"SpeedFins",
	"AutoCollect",
	"MutationScan",
	"Radio",
	"DeepDiverBundle",
	"CollectorBundle",
}
local BOOSTS =
	{ "LuckPotion", "MutationPotion", "ServerLuck", "Flares5", "OxygenRefill", "SkipPity", "TierSkip", "RenameDock" }
local COINS = { "CoinsS", "CoinsM", "CoinsL", "CoinsXL", "CoinsXXL" }
local PEARLS = { "Pearls100", "Pearls550", "Pearls1200", "Pearls2600", "Pearls7000" }

-- card colours: passes and boosts take the next one in turn, so a tab reads as a row of
-- different things; the best deal is always gold
local PALETTE = {
	Color3.fromRGB(53, 214, 245),
	Color3.fromRGB(75, 139, 255),
	Color3.fromRGB(180, 123, 255),
	Color3.fromRGB(75, 224, 106),
	Color3.fromRGB(255, 92, 108),
	Color3.fromRGB(108, 125, 255),
	Color3.fromRGB(255, 138, 61),
	Color3.fromRGB(57, 184, 255),
	Color3.fromRGB(255, 111, 181),
	Color3.fromRGB(53, 224, 176),
}
local GOLD = Color3.fromRGB(255, 190, 46)
local SKY = Color3.fromRGB(92, 200, 255)
local PINK = Color3.fromRGB(255, 111, 181)
-- Event shop pictures: the uploaded image of what you get (the config only names a drawn icon)
local EVENT_ICONS = {
	Flares5 = "Flares5",
	Luck5 = "LuckPotion",
	Mutation5 = "MutationPotion",
	Pearls30 = "Pearls",
	RareRelic = "CrateSingle",
	EpicRelic = "CrateTriple",
}

function ShopController.Init(c)
	controllers = c
end

-- §18.3 concrete previews
local function preview(key: string): string?
	local S = controllers.State
	if key == "AutoRefill" then
		return "No more walking to the tank rack"
	elseif key == "DoubleOxygen" then
		local o = S.Derived("MaxOxygen") or 60
		return `Dive time {math.floor(o)}s → {math.floor(o + 60)}s`
	elseif key == "BigBag" then
		local b = S.Derived("BagSize") or 3
		return `Bag {b} → {b + 4} slots`
	elseif key == "ExtraSlots" then
		local n = S.Derived("StandCount") or 6
		return `Stands {n} → {n + 4}`
	elseif key == "VIP" then
		local inc = S.Get("IncomePerSecond") or 0
		return `Income +{NumberFormat.short(inc)}/s → +{NumberFormat.short(inc * 1.5)}/s`
	elseif key == "SpeedFins" then
		local s = S.Derived("SwimSpeed") or 24
		return `Swim speed {math.floor(s)} → {math.floor(s * 1.3)}`
	end
	return nil
end

-- One shop card. The whole card is the buy button; an owned card says so instead.
local function card(o: {
	order: number,
	title: string,
	desc: string?,
	sub: string?,
	price: string,
	priceColor: Color3?,
	owned: boolean?,
	onBuy: (() -> ())?,
	color: Color3?,
	icon: string?,
	tag: string?,
	tagColor: Color3?,
})
	return Kit.ShopCard({
		Name = o.title,
		Desc = o.desc,
		Sub = o.sub,
		Price = o.price,
		PriceColor = o.priceColor,
		Icon = o.icon,
		Color = o.color or PALETTE[(o.order - 1) % #PALETTE + 1],
		Tag = o.tag,
		TagColor = o.tagColor,
		Owned = o.owned,
		Wide = shape.wide,
		LayoutOrder = o.order,
		Parent = content,
		OnClick = function()
			if o.owned then
				controllers.UIController.Toast(`You own {o.title}!`, "info")
			elseif o.onBuy then
				o.onBuy()
			end
		end,
	})
end

local function buy(kind: string, key: string)
	Net.RequestPurchase:FireServer(kind, key)
end

-- Columns stretch to fill the width: up to 3 wide cards or 5 small ones, fewer on a phone
local function fit()
	local w = content.AbsoluteSize.X - 20 -- side padding and the scroll bar
	if w <= 0 then
		return
	end
	local pad = 10
	local minW = if shape.wide then 216 else 122
	local cols = math.clamp(math.floor((w + pad) / (minW + pad)), 1, if shape.wide then 3 else 5)
	grid.CellSize = UDim2.fromOffset(math.floor((w - pad * (cols - 1)) / cols), shape.height)
end

local function setShape(wide: boolean, height: number)
	shape.wide, shape.height = wide, height
	fit()
end

-- A line of text across the top of the well (the Event tab's token count, region notices)
local function setNote(text: string?)
	note.Visible = text ~= nil
	note.Text = text or ""
	local top = if text then 50 else 0
	content.Position = UDim2.fromOffset(0, top)
	content.Size = UDim2.new(1, 0, 1, -top)
end

local paintTabs: ((string) -> ())? = nil -- set in build(); declared before render() uses it

local function render()
	Kit.Clear(content)
	if paintTabs then
		paintTabs(currentTab)
	end
	local S = controllers.State
	if vipButton then
		vipButton.Text = if S.Owns("VIP") then "VIP owned" else "VIP  249 R$"
	end
	setNote(nil)
	if currentTab == "Passes" then
		setShape(true, 138)
		for i, key in PASS_ORDER do
			local def = Passes[key]
			local extra = preview(key)
			local best = key == "VIP" or def.grants ~= nil
			card({
				order = i,
				title = def.name,
				desc = def.desc .. (if extra then "\n" .. extra else ""),
				price = `{def.price} R$`,
				owned = S.Owns(key),
				onBuy = function()
					buy("Pass", key)
				end,
				color = if best then GOLD else nil,
				icon = Icons.Get(key),
				tag = if key == "VIP" then "Best value!" elseif def.grants then "Bundle!" else nil,
			})
		end
	elseif currentTab == "Boosts" then
		setShape(true, 138)
		for i, key in BOOSTS do
			local def = Products[key]
			local desc = ({
				LuckPotion = "2x luck for 10 minutes",
				MutationPotion = "3x mutation chance for 10 minutes",
				ServerLuck = "2x rare odds for EVERYONE in the server for 15 minutes. Your name is announced!",
				Flares5 = "Distract the Leviathan for 6 seconds",
				OxygenRefill = "Full tank instantly",
				SkipPity = "Instant roll on the Legendary table",
				TierSkip = "+1 Tide Pass tier",
				RenameDock = "Custom dock sign (filtered)",
			})[key] or ""
			card({
				order = i,
				title = def.name,
				desc = desc,
				price = `{def.price} R$`,
				onBuy = function()
					buy("Product", key)
				end,
				color = if key == "ServerLuck" then GOLD else nil,
				icon = Icons.Get(key),
				tag = if key == "ServerLuck" then "Whole server!" else nil,
			})
		end
	elseif currentTab == "Coins" then
		setShape(false, 190)
		local income = S.Get("IncomePerSecond") or 0
		for i, key in COINS do
			local def = Products[key]
			local amount = math.max(income * def.incomeMinutes * 60, def.floor)
			card({
				order = i,
				title = `{NumberFormat.short(amount)} Coins`,
				sub = `{NumberFormat.time(def.incomeMinutes * 60)} of income`,
				price = `{def.price} R$`,
				onBuy = function()
					buy("Product", key)
				end,
				color = GOLD,
				icon = Icons.Get("Coins"),
				tag = if key == "CoinsXL" then "Best value!" else nil,
			})
		end
	elseif currentTab == "Pearls" then
		setShape(false, 190)
		for i, key in PEARLS do
			local def = Products[key]
			card({
				order = i,
				title = def.name,
				price = `{def.price} R$`,
				onBuy = function()
					buy("Product", key)
				end,
				color = SKY,
				icon = Icons.Get("Pearls"),
				tag = if key == "Pearls2600" then "Best value!" else nil,
			})
		end
	elseif currentTab == "Crates" then
		if S.Derived("CanBuyRandom") == false then
			setNote(
				"Mystery Crates aren't available in your region. Every item is also sold directly in the other tabs."
			)
			return
		end
		setShape(true, 160)
		local odds = WeightedRandom.percentages(Economy.Crate)
		local lines = {}
		for i, e in odds do
			table.insert(lines, `{Economy.Crate[i].label}: {NumberFormat.percent(e.percent)}`)
		end
		card({
			order = 1,
			title = Products.CrateSingle.name,
			desc = "One random reward from the odds table",
			price = `{Products.CrateSingle.price} R$`,
			onBuy = function()
				buy("Product", "CrateSingle")
			end,
			color = Color3.fromRGB(255, 138, 61),
			icon = Icons.Get("CrateSingle"),
		})
		card({
			order = 2,
			title = Products.CrateTriple.name,
			desc = "Three rolls on the odds table",
			price = `{Products.CrateTriple.price} R$`,
			onBuy = function()
				buy("Product", "CrateTriple")
			end,
			color = GOLD,
			icon = Icons.Get("CrateTriple"),
			tag = "Best value!",
		})
		-- the exact odds, as the third card in the row
		local oddsCard = New("Frame", {
			Name = "Odds",
			BackgroundColor3 = C.Row,
			LayoutOrder = 3,
			Parent = content,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 18) }),
			New("UIStroke", { Color = C.RowEdge, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		})
		Kit.Text("Exact odds", 18, {
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = oddsCard,
		})
		local list = New("TextLabel", {
			BackgroundTransparency = 1,
			Text = table.concat(lines, "\n"),
			Font = T.Bold,
			TextColor3 = Color3.fromRGB(214, 219, 230),
			TextScaled = true,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(12, 38),
			Size = UDim2.new(1, -24, 1, -48),
			Parent = oddsCard,
		})
		New("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8, Parent = list })
	elseif currentTab == "Event" then
		-- Event shop: Event Tokens are earned only by salvaging during live events
		setShape(false, 190)
		local tokens = S.Get("EventTokens") or 0
		setNote(
			`You have {tokens} Event Tokens. Earn them by salvaging while an event is live: +1 per relic, +2 Rare+, +5 Epic+. Never sold for Robux.`
		)
		for i, item in Economy.EventShop do
			local can = tokens >= item.Cost
			card({
				order = i,
				title = item.Name,
				price = `{item.Cost} tokens`,
				priceColor = if can then C.Go else C.Off,
				onBuy = function()
					Net.RequestEventShopBuy:FireServer(item.Id)
				end,
				color = PINK,
				icon = if EVENT_ICONS[item.Id] then Icons.Get(EVENT_ICONS[item.Id]) else item.Icon,
				tag = if can then "Can buy!" else nil,
				tagColor = C.Go,
			})
		end
	elseif currentTab == "Pass+" then
		setShape(true, 176)
		card({
			order = 1,
			title = "Abyss Pass+ (monthly)",
			desc = "60 Pearls/day · +10% Coins · +10% luck · 1 free revive/day · +4h offline cap · 2x offline claim · keeps your login streak",
			price = "Subscribe",
			owned = S.Get("Subscribed") == true,
			onBuy = function()
				buy("Subscription", "PassPlus")
			end,
			color = Color3.fromRGB(53, 224, 224),
			icon = Icons.Get("PassPlus"),
		})
		card({
			order = 2,
			title = "Roblox Premium",
			desc = "+10% Coins and a Premium Chest every 24h",
			price = "Get Premium",
			owned = S.Get("Premium") == true,
			onBuy = function()
				buy("Premium", "Premium")
			end,
			icon = Icons.Get("Premium"),
		})
		if S.Derived("StarterPackAvailable") then
			local remaining = Products.StarterPack.offerHours * 3600
				- (os.time() - (S.Derived("StarterPackShownAt") or os.time()))
			card({
				order = 3,
				title = "Starter Pack",
				desc = `10K Coins · 100 Pearls · Neoprene suit · Rare relic\nOffer ends in {NumberFormat.time(remaining)}`,
				price = `{Products.StarterPack.price} R$`,
				onBuy = function()
					buy("Product", "StarterPack")
				end,
				color = GOLD,
				icon = Icons.Get("StarterPack"),
				tag = "Limited!",
			})
		end
	end
end

local TABS = {
	{ id = "Passes", text = "Passes", color = Color3.fromRGB(255, 181, 46) },
	{ id = "Boosts", text = "Boosts", color = Color3.fromRGB(180, 123, 255) },
	{ id = "Coins", text = "Coins", color = Color3.fromRGB(255, 205, 50) },
	{ id = "Pearls", text = "Pearls", color = Color3.fromRGB(70, 180, 255) },
	{ id = "Crates", text = "Crates", color = Color3.fromRGB(255, 138, 61) },
	{ id = "Pass+", text = "Pass+", color = Color3.fromRGB(40, 214, 214) },
	{ id = "Event", text = "Event", color = Color3.fromRGB(255, 111, 181) },
}

local function build(body: Frame)
	-- the tab strip scrolls sideways when the window is too narrow for all seven
	local tabScroll = Kit.Scroll({
		Size = UDim2.new(1, 0, 0, 44),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		Parent = body,
	})
	local _, paint = Kit.FlatTabs(tabScroll, TABS, currentTab, function(id)
		currentTab = id
		render()
	end, { Size = UDim2.new(0, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.X })
	paintTabs = paint

	local well = Kit.Well({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), Parent = body })
	note = New("TextLabel", {
		Name = "Note",
		BackgroundTransparency = 1,
		Text = "",
		Font = T.Bold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(214, 219, 230),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 40),
		Visible = false,
		Parent = well,
	})
	content = Kit.Scroll({
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = 0.6,
		Parent = well,
	})
	grid = New("UIGridLayout", {
		CellSize = UDim2.fromOffset(240, shape.height),
		CellPadding = UDim2.fromOffset(10, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	-- room above the first row for the "Best value!" tags, which sit over a card's top edge
	New("UIPadding", {
		PaddingTop = UDim.new(0, 18),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 12),
		Parent = content,
	})
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end

function ShopController.OpenTab(tab: string)
	currentTab = tab
	controllers.UIController.Open("Shop")
end

function ShopController.Start()
	controllers.UIController.RegisterWindow("Shop", "Shop", build, render, {
		-- VIP, always one tap away
		Header = function(holder)
			vipButton = Kit.Button("VIP  249 R$", Color3.fromRGB(112, 66, 255), function()
				if controllers.State.Owns("VIP") then
					controllers.UIController.Toast("You own VIP Diver!", "info")
				else
					buy("Pass", "VIP")
				end
			end, { Size = UDim2.fromOffset(164, 38), TextSize = 17, Parent = holder })
			-- the crown image has a wide empty margin, so it is drawn larger than the text
			Kit.AttachIcon(vipButton :: TextButton, Icons.Get("VIP"), Color3.new(1, 1, 1), 34)
		end,
	})
	controllers.State.Changed:Connect(function(keys)
		if keys.Passes or keys.Derived or keys.Subscribed or keys.EventTokens then
			controllers.UIController.Refresh("Shop")
		end
	end)
end

return ShopController
