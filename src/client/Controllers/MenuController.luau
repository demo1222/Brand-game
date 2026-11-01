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
	return New("Frame", {
		BackgroundColor3 = T.PanelLight,
		Size = UDim2.new(1, -8, 0, height or 56),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.Corner(8) })
end

local function header(parent: Instance, order: number, text: string)
	return Kit.Label({ Text = text, Font = T.Bold, TextSize = 17, TextColor3 = T.Accent, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 26), Parent = parent })
end

local function scrollBody(body: Frame, top: number?)
	local scroll = Kit.Scroll({ Position = UDim2.fromOffset(0, top or 0), Size = UDim2.new(1, 0, 1, -(top or 0)), Parent = body })
	Kit.List(6).Parent = scroll
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

------------------------------------------------------------------------------------------
-- Bag / Dock Manager
------------------------------------------------------------------------------------------
local bagScroll
local function renderBag()
	Kit.Clear(bagScroll)
	local order = 0
	local function o()
		order += 1
		return order
	end
	local mult = S.Derived("CoinMult") or 1
	local function relicRow(relic, where: string)
		local r = row(bagScroll, o(), 60)
		local rarity = Rarities[relic.rarity]
		Kit.Label({
			Text = `{rarity.Icon} {relicLine(relic)}{relic.locked and " 🔒" or ""}`,
			TextColor3 = if relic.rarity == "Secret" then Color3.new(1, 1, 1) else rarity.Color,
			Font = T.Bold,
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.new(1, -370, 0, 26),
			Parent = r,
		})
		Kit.Label({
			Text = `{relic.rarity} · {relic.size}x · +{NumberFormat.short(Formulas.RelicCPS(relic) * mult)}/s`,
			TextColor3 = T.Muted,
			TextSize = 13,
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -370, 0, 22),
			Parent = r,
		})
		local buttons = New("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(360, 48),
			Parent = r,
		}, { Kit.List(4, true, Enum.HorizontalAlignment.Right) })
		if where == "Stands" or where == "Vault" then
			Kit.Button("Take", T.PanelLight, function()
				Net.RequestPickupRelic:FireServer(tonumber(relic._slot), where == "Vault")
			end, { Size = UDim2.fromOffset(70, 44), Parent = buttons })
			return
		end
		if table.find(relic.mutations, "Barnacled") then
			Kit.Button("Clean", Color3.fromRGB(150, 130, 100), function()
				Net.RequestCleanBarnacle:FireServer(relic.uid)
			end, { Size = UDim2.fromOffset(64, 44), TextSize = 13, Parent = buttons })
		end
		Kit.Button(relic.locked and "Unlock" or "Lock", T.PanelLight, function()
			Net.RequestToggleLock:FireServer(relic.uid)
		end, { Size = UDim2.fromOffset(64, 44), TextSize = 13, Parent = buttons })
		if not relic.locked then
			Kit.Button(`Sell {NumberFormat.short(Formulas.SellPrice(relic, mult))}`, T.Bad, function()
				Net.RequestSell:FireServer(relic.uid)
			end, { Size = UDim2.fromOffset(84, 44), TextSize = 13, Parent = buttons })
		end
		Kit.Button("Display", T.Good, function()
			local slot = firstFreeStand()
			if slot then
				Net.RequestPlaceRelic:FireServer(relic.uid, slot, false)
			else
				controllers.UIController.Toast("All stands are full! Upgrade Display Slots.", "error")
				if not S.Owns("ExtraSlots") then
					controllers.OfferController.Show("ExtraSlots")
				end
			end
		end, { Size = UDim2.fromOffset(70, 44), TextSize = 13, Parent = buttons })
		if (S.Derived("VaultCount") or 0) > 0 then
			Kit.Button("Vault", T.Gold, function()
				local vault = S.Get("Vault") or {}
				for i = 1, S.Derived("VaultCount") do
					if not vault[tostring(i)] then
						Net.RequestPlaceRelic:FireServer(relic.uid, i, true)
						return
					end
				end
				controllers.UIController.Toast("Vault slots are full.", "error")
			end, { Size = UDim2.fromOffset(60, 44), TextSize = 13, TextColor3 = Color3.fromRGB(40, 25, 0), Parent = buttons })
		end
	end

	local bag = S.Get("Bag") or {}
	header(bagScroll, o(), `DIVE BAG {#bag}/{S.Derived("BagSize") or 3} — lost if you die! Swim home to secure it.`)
	for _, relic in bag do
		relicRow(relic, "Bag")
	end
	local storage = S.Get("Storage") or {}
	local tools = row(bagScroll, o(), 52)
	tools.BackgroundTransparency = 1
	Kit.Label({ Text = `STORAGE ({#storage})`, Font = T.Bold, TextColor3 = T.Accent, Size = UDim2.new(0.5, 0, 1, 0), Parent = tools })
	Kit.Button("Sell all Commons", T.Bad, function()
		Net.RequestSellCommons:FireServer()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(160, 44), Parent = tools })
	table.sort(storage, function(a, b)
		return Formulas.RelicCPS(a) > Formulas.RelicCPS(b)
	end)
	for _, relic in storage do
		relicRow(relic, "Storage")
	end
	header(bagScroll, o(), `ON DISPLAY · +{NumberFormat.short(S.Get("IncomePerSecond") or 0)}/s`)
	for slot, relic in S.Get("Stands") or {} do
		local copy = table.clone(relic)
		copy._slot = slot
		relicRow(copy, "Stands")
	end
	for slot, relic in S.Get("Vault") or {} do
		local copy = table.clone(relic)
		copy._slot = slot
		relicRow(copy, "Vault")
	end
end

------------------------------------------------------------------------------------------
-- Upgrades
------------------------------------------------------------------------------------------
local upScroll
local function renderUpgrades()
	Kit.Clear(upScroll)
	local order = 0
	local levels = S.Get("Upgrades") or {}
	local coins = S.Get("Coins") or 0
	local suitIndex = S.Get("Suit") or 1
	local nextSuit = Upgrades.Suits[suitIndex + 1]
	order += 1
	local sr = row(upScroll, order, 64)
	Kit.Label({
		Text = `Suit: {Upgrades.Suits[suitIndex].Name} (safe to zone {suitIndex}: {Zones.List[math.min(suitIndex, 5)].Name})`,
		Font = T.Bold,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -170, 0, 24),
		Parent = sr,
	})
	Kit.Label({
		Text = if nextSuit then `Next: {nextSuit.Name}{nextSuit.ComingSoon and " (coming soon)" or ""}` else "Max suit!",
		TextColor3 = T.Muted,
		TextSize = 14,
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -170, 0, 22),
		Parent = sr,
	})
	if nextSuit then
		Kit.Button(NumberFormat.short(nextSuit.Cost), if coins >= nextSuit.Cost then T.Good else T.PanelLight, function()
			Net.RequestBuySuit:FireServer()
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 48), Parent = sr })
	end
	for _, track in Upgrades.Tracks do
		order += 1
		local lvl = levels[track.Id] or 0
		local r = row(upScroll, order, 58)
		Kit.Label({ Text = `{track.Name}  Lv {lvl}/{track.Max}`, Font = T.Bold, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -170, 0, 24), Parent = r })
		Kit.Label({ Text = track.Desc, TextColor3 = T.Muted, TextSize = 14, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -170, 0, 22), Parent = r })
		if lvl >= track.Max then
			Kit.Label({ Text = "MAX", Font = T.Bold, TextColor3 = T.Gold, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(80, 30), Parent = r })
		else
			local cost = Upgrades.Cost(track.Id, lvl)
			Kit.Button(NumberFormat.short(cost), if coins >= cost then T.Good else T.PanelLight, function()
				Net.RequestUpgrade:FireServer(track.Id)
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 46), Parent = r })
		end
	end
	order += 1
	local g = row(upScroll, order, 58)
	Kit.Label({ Text = "Laser Gate: blocks raids on your dock", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -170, 1, 0), Parent = g })
	Kit.Button("Activate", T.Bad, function()
		Net.ActivateGate:FireServer()
	end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(140, 46), Parent = g })
end

------------------------------------------------------------------------------------------
-- Codex
------------------------------------------------------------------------------------------
local codexScroll, codexTitle
local function renderCodex()
	Kit.Clear(codexScroll)
	local codex = S.Get("Codex") or {}
	local total, found = 0, 0
	for _, def in Relics.List do
		if def.Zone == codexZone then
			total += 1
			local entry = codex[def.Id]
			if entry then
				found += 1
			end
			local rarity = Rarities[def.Rarity]
			local cell = New("Frame", {
				BackgroundColor3 = if entry then T.PanelLight else Color3.fromRGB(15, 20, 30),
				Size = UDim2.fromOffset(150, 90),
				Parent = codexScroll,
			}, { Kit.Corner(8), Kit.Padding(6) })
			if entry then
				Kit.Stroke(rarity.Color, 1.5).Parent = cell
				local muts = 0
				for _ in entry do
					muts += 1
				end
				Kit.Label({ Text = def.Name, Font = T.Bold, TextSize = 14, TextColor3 = rarity.Color, Size = UDim2.new(1, 0, 0, 34), Parent = cell })
				Kit.Label({
					Text = `{def.Rarity}\nVariants: {muts}/{#Mutations.List + 1}`,
					TextSize = 12,
					TextColor3 = T.Muted,
					Position = UDim2.fromOffset(0, 36),
					Size = UDim2.new(1, 0, 0, 34),
					Parent = cell,
				})
			else
				Kit.Label({ Text = "???", Font = T.Bold, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 0.6), Parent = cell })
				Kit.Label({
					Text = def.Rarity,
					TextSize = 12,
					TextColor3 = T.Muted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromScale(0, 0.6),
					Size = UDim2.fromScale(1, 0.4),
					Parent = cell,
				})
			end
		end
	end
	codexTitle.Text = `{Zones.List[codexZone].Name}: {found}/{total} ({math.floor(found / math.max(total, 1) * 100)}%) · 100% = +5% luck in this zone`
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
	UI.RegisterWindow("Bag", "Bag & Dock", function(body)
		bagScroll = scrollBody(body)
	end, renderBag)
	UI.RegisterWindow("Upgrades", "Upgrades", function(body)
		upScroll = scrollBody(body)
	end, renderUpgrades)
	UI.RegisterWindow("Codex", "Codex", function(body)
		local tabs = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = body }, { Kit.List(6, true) })
		for i, zone in Zones.List do
			Kit.Button(zone.Name, T.PanelLight, function()
				codexZone = i
				renderCodex()
			end, { Size = UDim2.fromOffset(130, 40), TextSize = 13, LayoutOrder = i, Parent = tabs })
		end
		codexTitle = Kit.Label({ Text = "", Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 24), Parent = body })
		codexScroll = Kit.Scroll({ Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76), Parent = body })
		New("UIGridLayout", { CellSize = UDim2.fromOffset(150, 90), CellPadding = UDim2.fromOffset(6, 6), Parent = codexScroll })
	end, renderCodex)
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
