-- ShopController (Master Plan §15, §18.2): tabs for Passes, Boosts, Coins, Pearls, Crates and
-- Abyss Pass+. VIP banner always on top. Every prompt previews its benefit first (§18.3).
-- Crate odds are displayed from the exact table the server rolls (§16).

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
local ShopController = {}
local controllers
local content: ScrollingFrame
local currentTab = "Passes"
local vipPrice: TextLabel? = nil

local PASS_ORDER = {
	"VIP",
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

function ShopController.Init(c)
	controllers = c
end

-- §18.3 concrete previews
local function preview(key: string): string?
	local S = controllers.State
	if key == "DoubleOxygen" then
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

-- Shop tile: the whole card is the buy button. Big icon, outlined name, what you get, and a
-- price plate along the bottom (green = buy, gold check = owned). 3 per row.
local function card(
	order: number,
	title: string,
	desc: string,
	priceText: string,
	owned: boolean,
	onBuy,
	highlight: Color3?,
	icon: string?,
	tag: string?
)
	local accent = highlight or T.Accent
	local _, f = Kit.GameCard(
		if highlight then Kit.Darken(highlight, 0.62) else T.Slab,
		{ LayoutOrder = order, Parent = content },
		function()
			if owned then
				controllers.UIController.Toast(`You own {title}!`, "info")
			elseif onBuy then
				onBuy()
			end
		end
	)
	if highlight then
		local s = f:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = highlight
			s.Thickness = 3
		end
		Kit.Pill(tag or "BEST", highlight, {
			Icon = "star",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			TextSize = 12,
			ZIndex = 5,
			Parent = f,
		})
		Kit.Shine(f, 3)
	end
	Kit.Glow(f, accent, 110, { Position = UDim2.new(0.5, 0, 0, 46), ZIndex = 2 })
	Kit.IconBadge(
		icon or "star",
		accent,
		68,
		{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), ZIndex = 3, Parent = f }
	)
	local t = Kit.Title({
		Text = title,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(8, 86),
		Size = UDim2.new(1, -16, 0, 24),
		TextScaled = true,
		ZIndex = 3,
		Parent = f,
	})
	New("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12, Parent = t })
	Kit.Label({
		Text = desc,
		Font = T.Bold,
		TextColor3 = Kit.Lighten(T.Muted, 0.25),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(10, 114),
		Size = UDim2.new(1, -20, 1, -170),
		ZIndex = 3,
		Parent = f,
	})
	Kit.PricePlate(
		if owned then "OWNED" else priceText,
		if owned then T.Gold else T.Good,
		if owned then "check" else nil,
		{
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 44),
			TextSize = 21,
			Parent = f,
		}
	)
	return f
end

local function buy(kind: string, key: string)
	Net.RequestPurchase:FireServer(kind, key)
end

local paintTabs: ((string) -> ())? = nil -- set in build(); declared before render() uses it

local function render()
	Kit.Clear(content)
	if paintTabs then
		paintTabs(currentTab)
	end
	local S = controllers.State
	if vipPrice then
		vipPrice.Text = if S.Owns("VIP") then "OWNED" else "249 R$"
		vipPrice.BackgroundColor3 = if S.Owns("VIP") then Color3.fromRGB(70, 34, 0) else T.Good
		vipPrice.TextColor3 = if S.Owns("VIP") then T.Gold else T.DarkText
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	if currentTab == "Passes" then
		for _, key in PASS_ORDER do
			local def = Passes[key]
			local extra = preview(key)
			local desc = def.desc .. (if extra then "\n" .. extra else "")
			card(nextOrder(), def.name, desc, `{def.price} R$`, S.Owns(key), function()
				buy("Pass", key)
			end, if key == "VIP" or def.grants then T.Gold else nil, Icons.Get(key))
		end
	elseif currentTab == "Boosts" then
		for _, key in BOOSTS do
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
			card(nextOrder(), def.name, desc, `{def.price} R$`, false, function()
				buy("Product", key)
			end, if key == "ServerLuck" then T.Accent else nil, Icons.Get(key))
		end
	elseif currentTab == "Coins" then
		local income = S.Get("IncomePerSecond") or 0
		for _, key in COINS do
			local def = Products[key]
			local amount = math.max(income * def.incomeMinutes * 60, def.floor)
			card(
				nextOrder(),
				`{NumberFormat.short(amount)} Coins`,
				`{NumberFormat.time(def.incomeMinutes * 60)} of your current income`,
				`{def.price} R$`,
				false,
				function()
					buy("Product", key)
				end,
				if key == "CoinsXL" then T.Gold else nil,
				Icons.Get("Coins")
			)
		end
	elseif currentTab == "Pearls" then
		for _, key in PEARLS do
			local def = Products[key]
			card(
				nextOrder(),
				def.name,
				"Premium currency for cosmetics, crates and the Tide Pass",
				`{def.price} R$`,
				false,
				function()
					buy("Product", key)
				end,
				if key == "Pearls2600" then T.Gold else nil,
				Icons.Get("Pearls")
			)
		end
	elseif currentTab == "Crates" then
		if S.Derived("CanBuyRandom") == false then
			Kit.Label({
				Text = "Mystery Crates aren't available in your region. Every item is also sold directly in the other tabs.",
				TextSize = 16,
				Size = UDim2.new(1, -8, 0, 60),
				Parent = content,
			})
			return
		end
		local odds = WeightedRandom.percentages(Economy.Crate)
		local lines = {}
		for i, e in odds do
			table.insert(lines, `{Economy.Crate[i].label}: {NumberFormat.percent(e.percent)}`)
		end
		card(
			nextOrder(),
			Products.CrateSingle.name,
			"One random reward from the odds table",
			`{Products.CrateSingle.price} R$`,
			false,
			function()
				buy("Product", "CrateSingle")
			end,
			nil,
			Icons.Get("CrateSingle")
		)
		card(
			nextOrder(),
			Products.CrateTriple.name,
			"Three rolls on the odds table",
			`{Products.CrateTriple.price} R$`,
			false,
			function()
				buy("Product", "CrateTriple")
			end,
			T.Gold,
			Icons.Get("CrateTriple")
		)
		local oddsCard = Kit.Card({ LayoutOrder = nextOrder(), Parent = content }, { Kit.Padding(10) })
		Kit.Title({ Text = "Exact odds", TextSize = 16, Size = UDim2.new(1, 0, 0, 20), Parent = oddsCard })
		Kit.Label({
			Text = table.concat(lines, "\n"),
			TextSize = 12,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 1, -24),
			TextScaled = #lines > 9,
			Parent = oddsCard,
		})
	elseif currentTab == "Event" then
		-- Event shop: Event Tokens are earned only by salvaging during live events
		local tokens = S.Get("EventTokens") or 0
		local info = Kit.Card(
			{ LayoutOrder = nextOrder(), BackgroundColor3 = T.PanelDark, Parent = content },
			{ Kit.Padding(14) }
		)
		Kit.Icon.new("event", 40, T.Gold, { Parent = info })
		Kit.Title({
			Text = tostring(tokens),
			TextSize = 34,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 38),
			Parent = info,
		})
		Kit.Label({
			Text = "Event Tokens",
			Font = T.Bold,
			TextSize = 13,
			TextColor3 = T.Gold,
			Position = UDim2.fromOffset(0, 88),
			Size = UDim2.new(1, 0, 0, 16),
			Parent = info,
		})
		Kit.Label({
			Text = "Earn them by salvaging while an event is live: +1 per relic, +2 Rare+, +5 Epic+. Never sold for Robux.",
			TextSize = 11,
			TextColor3 = T.Muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 110),
			Size = UDim2.new(1, 0, 1, -110),
			Parent = info,
		})
		for _, item in Economy.EventShop do
			card(nextOrder(), item.Name, `{item.Cost} Event Tokens`, `{item.Cost} tokens`, false, function()
				Net.RequestEventShopBuy:FireServer(item.Id)
			end, if tokens >= item.Cost then T.Gold else nil, item.Icon, "CAN BUY")
		end
	elseif currentTab == "Pass+" then
		card(
			nextOrder(),
			"Abyss Pass+ (monthly)",
			"60 Pearls/day · +10% Coins · +10% luck · 1 free revive/day · +4h offline cap · 2x offline claim · keeps your login streak",
			"Subscribe",
			S.Get("Subscribed") == true,
			function()
				buy("Subscription", "PassPlus")
			end,
			T.Accent,
			Icons.Get("PassPlus")
		)
		card(
			nextOrder(),
			"Roblox Premium",
			"+10% Coins and a Premium Chest every 24h",
			"Get Premium",
			S.Get("Premium") == true,
			function()
				buy("Premium", "Premium")
			end,
			nil,
			Icons.Get("Premium")
		)
		if S.Derived("StarterPackAvailable") then
			local remaining = Products.StarterPack.offerHours * 3600
				- (os.time() - (S.Derived("StarterPackShownAt") or os.time()))
			card(
				nextOrder(),
				"Starter Pack",
				`10K Coins · 100 Pearls · Neoprene suit · Rare relic\nOffer ends in {NumberFormat.time(remaining)}`,
				`{Products.StarterPack.price} R$`,
				false,
				function()
					buy("Product", "StarterPack")
				end,
				T.Gold,
				Icons.Get("StarterPack")
			)
		end
	end
end

local TABS = {
	{ id = "Passes", text = "Passes", icon = "ticket", color = T.Gold },
	{ id = "Boosts", text = "Boosts", icon = "potion", color = Color3.fromRGB(180, 140, 255) },
	{ id = "Coins", text = "Coins", icon = "coin", color = T.Gold },
	{ id = "Pearls", text = "Pearls", icon = "pearl", color = T.Pearl },
	{ id = "Crates", text = "Crates", icon = "box", color = Color3.fromRGB(255, 150, 70) },
	{ id = "Pass+", text = "Pass+", icon = "star", color = T.Accent },
	{ id = "Event", text = "Event", icon = "event", color = Color3.fromRGB(255, 130, 180) },
}

local function build(body: Frame)
	-- VIP banner: one big gold slab, name + perks on two lines, price plate on the right
	local _, banner = Kit.GameCard(
		Color3.fromRGB(255, 176, 50),
		{ Size = UDim2.new(1, 0, 0, 70), Parent = body },
		function()
			buy("Pass", "VIP")
		end
	)
	New("UIGradient", {
		Name = "Bevel",
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 130, 40)),
		}),
		Parent = banner,
	}):SetAttribute("Keep", true)
	for _, g in banner:GetChildren() do
		if g:IsA("UIGradient") and not g:GetAttribute("Keep") then
			g:Destroy() -- one gradient per object: keep the gold sweep
		end
	end
	Kit.IconBadge(
		Icons.Get("VIP"),
		Color3.fromRGB(255, 120, 40),
		50,
		{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 3, Parent = banner }
	)
	Kit.Title({
		Text = "VIP DIVER",
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(72, 6),
		Size = UDim2.new(1, -220, 0, 30),
		TextWrapped = false,
		ZIndex = 3,
		Parent = banner,
	})
	Kit.Label({
		Text = "1.5x Coins  ·  VIP lounge  ·  daily chest",
		Font = T.Bold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(70, 34, 0),
		Position = UDim2.fromOffset(72, 38),
		Size = UDim2.new(1, -220, 0, 18),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = banner,
	})
	vipPrice = Kit.PricePlate("249 R$", T.Good, nil, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(124, 46),
		TextSize = 22,
		Parent = banner,
	})
	Kit.Shine(banner, 1.8)

	local tabScroll = Kit.Scroll({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 54),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 3,
		Parent = body,
	})
	local _, paint = Kit.Tabs(tabScroll, TABS, currentTab, function(id)
		currentTab = id
		render()
	end, { Size = UDim2.new(0, 0, 0, 48), AutomaticSize = Enum.AutomaticSize.X, TabWidth = 104 })
	paintTabs = paint
	content = Kit.Scroll({ Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 1, -140), Parent = body })
	New("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -10, 0, 232),
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})
	New(
		"UIPadding",
		{ PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), Parent = content }
	)
end

function ShopController.OpenTab(tab: string)
	currentTab = tab
	controllers.UIController.Open("Shop")
end

function ShopController.Start()
	controllers.UIController.RegisterWindow("Shop", "Shop", build, render)
	controllers.State.Changed:Connect(function(keys)
		if keys.Passes or keys.Derived or keys.Subscribed or keys.EventTokens then
			controllers.UIController.Refresh("Shop")
		end
	end)
end

return ShopController
