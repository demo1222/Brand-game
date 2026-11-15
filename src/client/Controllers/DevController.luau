-- DevController: the developer test panel (Studio + admin only). A DEV button on the HUD opens
-- a window with tabs (Relics, Currency, Progress, World, Danger, Data). Every button just
-- sends (action, arg) through Net.DevAction; DevService decides everything on the server.
-- The button only shows once the server has set the DevAdmin attribute on the local player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Events = require(Shared.Config.Events)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local DevController = {}
local controllers
local pages: { [string]: ScrollingFrame } = {}
local currentTab = "Relics"
local toggles: { { button: TextButton, label: string, attr: string } } = {}
local devButton: Instance? = nil

local TABS = {
	{ id = "Relics", text = "Relics", color = T.Accent },
	{ id = "Currency", text = "Money", color = T.Gold },
	{ id = "Progress", text = "Progress", color = T.Good },
	{ id = "World", text = "World", color = Color3.fromRGB(90, 200, 255) },
	{ id = "Danger", text = "Danger", color = T.Bad },
	{ id = "Data", text = "Data", color = Color3.fromRGB(180, 140, 255) },
}

function DevController.Init(c)
	controllers = c
end

local function send(action: string, arg: any?)
	Net.DevAction:FireServer(action, arg)
end

------------------------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------------------------
local function newPage(parent: Instance, id: string): ScrollingFrame
	local page = Kit.Scroll({
		Name = id,
		Size = UDim2.new(1, 0, 1, -58),
		Position = UDim2.fromOffset(0, 56),
		ScrollBarImageColor3 = T.Accent,
		Visible = false,
		Parent = parent,
	})
	New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	New("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = page })
	pages[id] = page
	return page
end

-- Section header plus a two-column grid of buttons. Returns the grid frame.
local order = 0
local function section(page: Instance, title: string, color: Color3?): Frame
	order += 1
	Kit.Header(page, order, title, color)
	order += 1
	local grid = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = page,
	})
	New("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 50),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	return grid
end

local function action(grid: Instance, text: string, color: Color3, act: string, arg: any?)
	return Kit.Button(text, color, function()
		send(act, arg)
	end, { Size = UDim2.fromScale(1, 1), TextSize = 16, Parent = grid })
end

-- Two taps: the first arms the button for 4 seconds, the second sends the action.
local function confirmAction(grid: Instance, text: string, color: Color3, act: string)
	local armed = 0
	local button
	button = Kit.Button(text, color, function()
		if armed > 0 then
			armed = 0
			button.Text = text
			send(act, "confirm")
		else
			armed = os.clock()
			local mine = armed
			button.Text = "TAP AGAIN TO CONFIRM"
			task.delay(4, function()
				if armed == mine then
					armed = 0
					button.Text = text
				end
			end)
		end
	end, { Size = UDim2.fromScale(1, 1), TextSize = 16, Parent = grid })
	return button
end

local function paintToggle(t)
	local on = player:GetAttribute(t.attr) == true
	t.button.Text = `{t.label}: {if on then "ON" else "OFF"}`
	t.button.BackgroundColor3 = if on then T.Good else T.Slab
	t.button.TextColor3 = if on then T.DarkText else T.Text
end

local function toggle(grid: Instance, label: string, act: string, attr: string)
	local button = Kit.Button(label, T.Slab, function()
		send(act)
	end, { Size = UDim2.fromScale(1, 1), TextSize = 16, Parent = grid })
	local t = { button = button, label = label, attr = attr }
	table.insert(toggles, t)
	paintToggle(t)
	player:GetAttributeChangedSignal(attr):Connect(function()
		paintToggle(t)
	end)
end

------------------------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------------------------
local function buildRelics(page: ScrollingFrame)
	local bulk = section(page, "Bulk (goes to Storage, ignores the cap)")
	action(bulk, "Give all relics", T.Accent, "GiveAllRelics")
	action(bulk, "All relics x every mutation", Color3.fromRGB(180, 140, 255), "GiveAllMutations")

	order += 1
	Kit.Header(page, order, "Give one relic", T.Gold)
	order += 1
	local search = New("TextBox", {
		Text = "",
		PlaceholderText = "Search relics by name or rarity",
		ClearTextOnFocus = false,
		Font = T.Bold,
		TextSize = 16,
		TextColor3 = T.Text,
		PlaceholderColor3 = T.Muted,
		BackgroundColor3 = T.PanelDark,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = order,
		Parent = page,
	}, { Kit.Corner(12), Kit.Stroke(T.Outline, 2, 0), Kit.Padding(10) })

	order += 1
	local list = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = page,
	}, { Kit.List(6, false) })

	local rows = {}
	for i, def in Relics.List do
		local color = Kit.RarityColor(def.Rarity, Rarities)
		local row = Kit.Button(`{def.Name}   ·   {def.Rarity}`, color, function()
			send("GiveRelic", def.Id)
		end, { Size = UDim2.new(1, 0, 0, 40), TextSize = 15, LayoutOrder = i, Parent = list })
		row.TextXAlignment = Enum.TextXAlignment.Left
		local pad = row:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, 14)
		end
		rows[i] = { row = row, key = string.lower(`{def.Name} {def.Rarity} {def.Id}`) }
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(search.Text)
		for _, r in rows do
			r.row.Visible = q == "" or string.find(r.key, q, 1, true) ~= nil
		end
	end)
end

local function buildCurrency(page: ScrollingFrame)
	local coins = section(page, "Coins", T.Gold)
	action(coins, "+1M Coins", T.Gold, "Coins1M")
	action(coins, "+1B Coins", T.Gold, "Coins1B")
	action(coins, "Set Coins to 1Qa", T.Gold, "CoinsHuge")
	toggle(coins, "Infinite money", "ToggleInfiniteMoney", "DevInfiniteMoney")

	local other = section(page, "Other currencies", T.Pearl)
	action(other, "+1,000 Pearls", T.Pearl, "Pearls1K")
	action(other, "+100,000 Pearls", T.Pearl, "Pearls100K")
	action(other, "+1,000 Event Tokens", Color3.fromRGB(255, 150, 70), "Tokens1K")
	action(other, "+10 Flares", Color3.fromRGB(245, 154, 90), "Flares10")
	action(other, "+5 Resurface tokens", Color3.fromRGB(90, 200, 255), "RebirthTokens")
end

local function buildProgress(page: ScrollingFrame)
	local up = section(page, "Upgrades", Color3.fromRGB(255, 150, 70))
	action(up, "Max all upgrades", Color3.fromRGB(255, 150, 70), "MaxUpgrades")
	action(up, "Max suit", Color3.fromRGB(255, 150, 70), "MaxSuit")
	action(up, "Max diving board", Color3.fromRGB(255, 150, 70), "MaxBoard")
	action(up, "Level 50", T.Good, "Level50")

	local prog = section(page, "Collection", T.Good)
	action(prog, "Complete all quests", T.Good, "CompleteQuests")
	action(prog, "Unlock whole Codex", Color3.fromRGB(180, 140, 255), "UnlockCodex")
end

local function buildWorld(page: ScrollingFrame)
	local tp = section(page, "Teleport", Color3.fromRGB(90, 200, 255))
	for _, zone in Zones.List do
		action(tp, zone.Name, Kit.Lighten(zone.FogColor, 0.25), "TeleportZone", zone.Id)
	end
	action(tp, "Back to my dock", T.Good, "TeleportDock")

	local ev = section(page, "Events (10 min)", T.Gold)
	for _, def in Events.List do
		action(ev, def.Name, def.Color or T.Accent, "StartEvent", def.Id)
	end
	action(ev, "Server luck x5", T.Gold, "ServerLuck")
end

local function buildDanger(page: ScrollingFrame)
	local god = section(page, "Survival", T.Bad)
	toggle(god, "God mode", "ToggleGod", "DevGod")
	toggle(god, "Infinite oxygen", "ToggleInfiniteO2", "DevInfiniteO2")
	action(god, "Refill oxygen now", T.Accent, "RefillOxygen")
	action(god, "Reset gate cooldown", T.Good, "ResetGate")

	local lev = section(page, "Leviathan", T.Bad)
	action(lev, "Spawn Leviathan near me", T.Bad, "SpawnLeviathan")
	action(lev, "Remove all Leviathans", T.Slab, "ClearLeviathans")
	action(lev, "Restore normal Leviathans", T.Slab, "RestoreLeviathans")

	local loot = section(page, "Loot luck", Color3.fromRGB(255, 50, 70))
	action(loot, "Max pity (all zones)", T.Gold, "SkipPity")
	action(loot, "Force next: Mythic", Rarities.Mythic.Color, "ForceRarity", "Mythic")
	action(loot, "Force next: Legendary", Rarities.Legendary.Color, "ForceRarity", "Legendary")
	action(loot, "Force next: Epic", Rarities.Epic.Color, "ForceRarity", "Epic")
	action(loot, "Clear forced rarity", T.Slab, "ForceRarity", "")
end

local function buildData(page: ScrollingFrame)
	local d = section(page, "Save data", Color3.fromRGB(180, 140, 255))
	action(d, "Save now", T.Good, "SaveNow")
	confirmAction(d, "Clear Bag + Storage", T.Bad, "ClearRelics")
	confirmAction(d, "RESET MY DATA", T.Bad, "ResetData")
end

------------------------------------------------------------------------------------------
-- Window + HUD button
------------------------------------------------------------------------------------------
local function build(body: Frame)
	local tabs = Kit.Tabs(body, TABS, currentTab, function(id)
		currentTab = id
		for pageId, page in pages do
			page.Visible = pageId == id
		end
	end, { Position = UDim2.fromOffset(0, 0) })
	buildRelics(newPage(body, "Relics"))
	buildCurrency(newPage(body, "Currency"))
	buildProgress(newPage(body, "Progress"))
	buildWorld(newPage(body, "World"))
	buildDanger(newPage(body, "Danger"))
	buildData(newPage(body, "Data"))
	pages[currentTab].Visible = true
	tabs.ZIndex = 2
end

local function makeButton()
	if devButton then
		return
	end
	local holder, face = Kit.GameButton(Color3.fromRGB(255, 110, 190), Vector2.new(84, 40), {
		Name = "DevButton",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Parent = controllers.UIController.Root,
	})
	Kit.Title({
		Text = "DEV",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = face,
	})
	face.Activated:Connect(function()
		controllers.UIController.Toggle("Dev")
	end)
	devButton = holder
end

function DevController.Start()
	controllers.UIController.RegisterWindow("Dev", "Dev Tools", build)
	local function check()
		if player:GetAttribute("DevAdmin") == true then
			makeButton()
		end
	end
	check()
	player:GetAttributeChangedSignal("DevAdmin"):Connect(check)
end

return DevController
