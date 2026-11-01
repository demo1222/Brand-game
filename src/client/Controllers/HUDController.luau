-- HUDController (Master Plan §18.1): currencies, depth/zone meter, oxygen bar, bag count,
-- menu buttons, mobile action buttons, events list, intruder/carry/predator alerts and the
-- low-oxygen quick buy.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local Zones = require(Shared.Config.Zones)
local Kit = require(script.Parent.Parent.UI.Kit)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local HUDController = {}
HUDController.O2Fraction = 1
local controllers
local refs = {}
local lastStatus = nil

function HUDController.Init(c)
	controllers = c
end

local function iconButton(parent, text: string, color: Color3, onClick, order: number)
	return Kit.Button(text, color, onClick, {
		Size = UDim2.fromOffset(56, 56),
		TextSize = 22,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function build()
	local root = controllers.UIController.Root
	local UI = controllers.UIController

	-- Currencies (top-left)
	local top = Kit.Panel({
		Name = "Currencies",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(260, 74),
		Parent = root,
	}, { Kit.Padding(8), Kit.List(2) })
	refs.coins = Kit.Label({ Text = "🪙 0", Font = T.Bold, TextSize = 22, Size = UDim2.new(1, 0, 0, 28), Parent = top })
	refs.income = Kit.Label({ Text = "+0/s", TextColor3 = T.Good, TextSize = 14, Size = UDim2.new(1, 0, 0, 16), Parent = top })
	refs.pearls = Kit.Label({ Text = "🫧 0 Pearls", TextColor3 = Color3.fromRGB(200, 230, 255), TextSize = 16, Size = UDim2.new(1, 0, 0, 18), Parent = top })

	-- Menu buttons (right column)
	local menu = New("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(56, 600),
		Parent = root,
	}, { Kit.List(6) })
	local shop = iconButton(menu, "🛒", T.Gold, function()
		UI.Toggle("Shop")
	end, 1)
	shop.TextColor3 = Color3.fromRGB(40, 25, 0)
	iconButton(menu, "🎒", T.PanelLight, function()
		UI.Toggle("Bag")
	end, 2)
	iconButton(menu, "⬆️", T.PanelLight, function()
		UI.Toggle("Upgrades")
	end, 3)
	iconButton(menu, "📖", T.PanelLight, function()
		UI.Toggle("Codex")
	end, 4)
	iconButton(menu, "📜", T.PanelLight, function()
		UI.Toggle("Quests")
	end, 5)
	iconButton(menu, "🔄", T.PanelLight, function()
		UI.Toggle("Rebirth")
	end, 6)
	iconButton(menu, "🏆", T.PanelLight, function()
		UI.Toggle("Leaderboards")
	end, 7)
	iconButton(menu, "👥", T.PanelLight, function()
		UI.Toggle("Players")
	end, 8)
	iconButton(menu, "⚙️", T.PanelLight, function()
		UI.Toggle("Settings")
	end, 9)

	-- Depth / zone meter (top-centre)
	refs.depth = Kit.Panel({
		Name = "Depth",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 40),
		Visible = false,
		Parent = root,
	})
	refs.depthLabel = Kit.Label({
		Text = "",
		Font = T.Bold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = refs.depth,
	})

	-- Oxygen + bag (bottom-left)
	local bottom = New("Frame", {
		Name = "Bottom",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(300, 120),
		Parent = root,
	})
	local o2Frame, setO2 = Kit.Bar({ Size = UDim2.fromOffset(280, 28), Position = UDim2.fromOffset(0, 60), Text = "O₂ 100%", Parent = bottom })
	refs.o2Frame, refs.setO2 = o2Frame, setO2
	refs.bag = Kit.Label({ Text = "🎒 0/3", Font = T.Bold, TextSize = 18, Position = UDim2.fromOffset(0, 94), Size = UDim2.fromOffset(280, 24), Parent = bottom })
	refs.quickRefill = Kit.Button("Refill O₂ · 25 R$", T.Bad, function()
		Net.RequestPurchase:FireServer("Product", "OxygenRefill")
	end, { Size = UDim2.fromOffset(180, 44), Position = UDim2.fromOffset(0, 10), Visible = false, Parent = bottom })

	-- Action buttons (bottom-right)
	local actions = New("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(250, 190),
		Parent = root,
	})
	local function action(text, color, pos, onDown, onUp)
		local b = Kit.Button(text, color, nil, { Size = UDim2.fromOffset(72, 56), Position = pos, TextSize = 14, Parent = actions })
		b.MouseButton1Down:Connect(onDown)
		if onUp then
			b.MouseButton1Up:Connect(onUp)
			b.MouseLeave:Connect(onUp)
		end
		return b
	end
	action("Sonar\n[Q]", T.Accent, UDim2.fromOffset(0, 0), function()
		controllers.SonarController.Ping()
	end)
	refs.flare = action("Flare\n[G] 3", Color3.fromRGB(230, 90, 40), UDim2.fromOffset(88, 0), function()
		Net.UseFlare:FireServer()
	end)
	action("Surface\n[R]", Color3.fromRGB(90, 120, 220), UDim2.fromOffset(176, 0), function()
		Net.RequestInstantSurface:FireServer()
	end)
	action("▲ Up", T.PanelLight, UDim2.fromOffset(0, 66), function()
		controllers.SwimController.SetVertical(1)
	end, function()
		controllers.SwimController.SetVertical(0)
	end)
	action("▼ Down", T.PanelLight, UDim2.fromOffset(0, 130), function()
		controllers.SwimController.SetVertical(-1)
	end, function()
		controllers.SwimController.SetVertical(0)
	end)
	action("Boost\n⇧", T.Good, UDim2.fromOffset(88, 98), function()
		controllers.SwimController.SetBoost(true)
	end, function()
		controllers.SwimController.SetBoost(false)
	end)
	actions.Visible = true

	-- Events list (left)
	refs.events = New("Frame", {
		Name = "Events",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.fromOffset(240, 200),
		Parent = root,
	}, { Kit.List(4) })

	-- Alerts (centre)
	refs.alert = Kit.Label({
		Name = "Alert",
		Text = "",
		Visible = false,
		Font = T.Bold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Bad,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(520, 60),
		Parent = root,
	})
	refs.carry = Kit.Label({
		Name = "Carry",
		Text = "",
		Visible = false,
		Font = T.Bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = T.Gold,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(520, 40),
		Parent = root,
	})
	refs.predator = Kit.Label({
		Name = "Predator",
		Text = "",
		Visible = false,
		Font = T.Bold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(255, 90, 90),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(420, 26),
		Parent = root,
	})
end

local function refreshCurrencies()
	local S = controllers.State
	refs.coins.Text = "🪙 " .. NumberFormat.short(S.Get("Coins") or 0)
	refs.pearls.Text = "🫧 " .. NumberFormat.commas(S.Get("Pearls") or 0) .. " Pearls"
	refs.income.Text = "+" .. NumberFormat.short(S.Get("IncomePerSecond") or 0) .. "/s"
	local bag = S.Get("Bag") or {}
	local size = S.Derived("BagSize") or 3
	refs.bag.Text = `🎒 {#bag}/{size}`
	refs.bag.TextColor3 = if #bag >= size then T.Bad else T.Text
	refs.flare.Text = `Flare\n[G] {S.Get("Flares") or 0}`
end

local function onStatus(status)
	lastStatus = status
	local frac = status.O2 / math.max(status.Max, 1)
	HUDController.O2Fraction = frac
	local color = if frac < 0.25 then T.Bad elseif frac < 0.5 then T.Gold else T.Accent
	refs.setO2(frac, color, `O₂ {math.floor(frac * 100)}%  ({math.floor(status.O2)}s)`)
	if frac < 0.25 and status.Zone > 0 then
		-- pulse
		refs.o2Frame.BackgroundColor3 = if (os.clock() * 4) % 2 < 1 then Color3.fromRGB(80, 0, 0) else Color3.fromRGB(10, 15, 25)
	else
		refs.o2Frame.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
	end
	refs.quickRefill.Visible = frac < 0.15 and status.Zone > 0 and not controllers.State.Owns("DoubleOxygen")
	if status.Zone > 0 then
		local zone = Zones.List[status.Zone]
		refs.depth.Visible = true
		local warn = if status.Pressure then "  ⚠ PRESSURE" else ""
		refs.depthLabel.Text = `Depth {math.floor(status.Depth)}m ▼  {zone.Name}{warn}`
		refs.depthLabel.TextColor3 = if status.Pressure then T.Bad else T.Text
	else
		refs.depth.Visible = false
	end
end

local function refreshEvents(list)
	Kit.Clear(refs.events)
	for i, e in list do
		Kit.Label({
			Text = `⚡ {e.Name} · {NumberFormat.time(e.Remaining)}\n{e.Desc}`,
			TextSize = 13,
			Font = T.Bold,
			TextColor3 = e.Color or T.Accent,
			TextStrokeTransparency = 0.4,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = i,
			Parent = refs.events,
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
			refs.carry.Text = `Carrying a stolen relic from {info.Owner} — get to YOUR dock!`
			refs.carry.Visible = true
		else
			refs.carry.Visible = false
		end
	end)
	Net.PredatorHint.OnClientEvent:Connect(function(hint)
		local lowScare = (controllers.State.Get("Settings") or {}).LowScare
		if hint.State == "WindUp" then
			refs.predator.Text = if lowScare then "Leviathan lunging — turn!" else "⚠ IT'S LUNGING — TURN NOW! ⚠"
			refs.predator.Visible = true
		elseif hint.Distance and hint.Distance < 120 then
			refs.predator.Text = if hint.State == "Hunt" then "The Leviathan is hunting you!" else "Something huge is nearby…"
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
