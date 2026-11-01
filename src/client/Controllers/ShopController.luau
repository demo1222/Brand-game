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

local New, T = Kit.New, Kit.Theme
local ShopController = {}
local controllers
local content: ScrollingFrame
local currentTab = "Passes"

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
local BOOSTS = { "LuckPotion", "MutationPotion", "ServerLuck", "Flares5", "OxygenRefill", "SkipPity", "TierSkip", "RenameDock" }
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

local function card(order: number, title: string, desc: string, priceText: string, owned: boolean, onBuy, highlight: Color3?)
	local f = New("Frame", {
		BackgroundColor3 = T.PanelLight,
		Size = UDim2.new(1, -8, 0, 78),
		LayoutOrder = order,
		Parent = content,
	}, { Kit.Corner(10) })
	if highlight then
		Kit.Stroke(highlight, 2).Parent = f
	end
	Kit.Label({ Text = title, Font = T.Bold, TextSize = 18, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -160, 0, 24), Parent = f })
	Kit.Label({
		Text = desc,
		TextColor3 = T.Muted,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -160, 0, 44),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = f,
	})
	local b = Kit.Button(if owned then "Owned ✓" else priceText, if owned then T.Good else T.Gold, if owned then nil else onBuy, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(130, 50),
		TextColor3 = if owned then Color3.new(1, 1, 1) else Color3.fromRGB(40, 25, 0),
		Parent = f,
	})
	b.AutoButtonColor = not owned
	return f
end

local function buy(kind: string, key: string)
	Net.RequestPurchase:FireServer(kind, key)
end

local function render()
	Kit.Clear(content)
	local S = controllers.State
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
			end, if key == "VIP" then T.Gold else nil)
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
			end)
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
				end
			)
		end
	elseif currentTab == "Pearls" then
		for _, key in PEARLS do
			local def = Products[key]
			card(nextOrder(), def.name, "Premium currency for cosmetics, crates and the Tide Pass", `{def.price} R$`, false, function()
				buy("Product", key)
			end)
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
		Kit.Label({
			Text = "ODDS (exact):\n" .. table.concat(lines, "\n"),
			TextSize = 14,
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, -8, 0, 22 + #lines * 18),
			Parent = content,
		})
		card(nextOrder(), Products.CrateSingle.name, "One random reward from the table above", `{Products.CrateSingle.price} R$`, false, function()
			buy("Product", "CrateSingle")
		end)
		card(nextOrder(), Products.CrateTriple.name, "Three rolls on the table above", `{Products.CrateTriple.price} R$`, false, function()
			buy("Product", "CrateTriple")
		end)
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
			T.Accent
		)
		card(nextOrder(), "Roblox Premium", "+10% Coins and a Premium Chest every 24h", "Get Premium", S.Get("Premium") == true, function()
			buy("Premium", "Premium")
		end)
		if S.Derived("StarterPackAvailable") then
			local remaining = Products.StarterPack.offerHours * 3600 - (os.time() - (S.Derived("StarterPackShownAt") or os.time()))
			card(
				nextOrder(),
				"Starter Pack",
				`10K Coins · 100 Pearls · Neoprene suit · Rare relic\nOffer ends in {NumberFormat.time(remaining)}`,
				`{Products.StarterPack.price} R$`,
				false,
				function()
					buy("Product", "StarterPack")
				end,
				T.Gold
			)
		end
	end
end

local function build(body: Frame)
	local banner = Kit.Button("👑 VIP DIVER — 1.5x Coins, VIP lounge, daily chest · 249 R$", T.Gold, function()
		buy("Pass", "VIP")
	end, {
		Size = UDim2.new(1, 0, 0, 44),
		TextColor3 = Color3.fromRGB(40, 25, 0),
		TextScaled = true,
		Parent = body,
	})
	New("UITextSizeConstraint", { MaxTextSize = 18, Parent = banner })
	local tabs = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = body,
	}, { Kit.List(6, true) })
	for i, name in { "Passes", "Boosts", "Coins", "Pearls", "Crates", "Pass+" } do
		Kit.Button(name, T.PanelLight, function()
			currentTab = name
			render()
		end, { Size = UDim2.fromOffset(92, 40), LayoutOrder = i, TextSize = 14, Parent = tabs })
	end
	content = Kit.Scroll({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 1, -100), Parent = body })
	Kit.List(8).Parent = content
end

function ShopController.OpenTab(tab: string)
	currentTab = tab
	controllers.UIController.Open("Shop")
end

function ShopController.Start()
	controllers.UIController.RegisterWindow("Shop", "Shop", build, render)
	controllers.State.Changed:Connect(function(keys)
		if keys.Passes or keys.Derived or keys.Subscribed then
			controllers.UIController.Refresh("Shop")
		end
	end)
end

return ShopController
