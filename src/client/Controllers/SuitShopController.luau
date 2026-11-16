-- SuitShopController: the Suit Shop (docs/UI_STYLE_GUIDE.md section 4, the Food Shop pattern).
-- A horizontal row of tall suit cards, each filled with its tier colour: name, tier word, your
-- suit on a plain grey mannequin (turning), perks, safe zone, a "Tier N" plate and one action
-- button (price / EQUIP / EQUIPPED / LOCKED / SOON). The suit you wear has a green rim. A small
-- TRY ON button on each card swaps its mannequin for your own avatar wearing that suit.
-- Opened from the stall on every dock (SuitShopPrompt, or stepping on its glowing pad, tagged
-- SuitShopDisc), the Upgrades suit card and the Diver window. Buying is in order (the next
-- suit only); any owned suit can be worn.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local SuitArt = require(Shared.SuitArt)
local Upgrades = require(Shared.Config.Upgrades)
local Zones = require(Shared.Config.Zones)
local Rarities = require(Shared.Config.Rarities)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icon = require(script.Parent.Parent.UI.Icon)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local SuitShopController = {}
local controllers
local S

local CARD_W = 214
local scroll: ScrollingFrame
local strip: { [string]: any } = {}
local sig = ""
local scrolledFor = -1

-- turning previews: one camera per card, updated 30 times a second while on screen
local spinners: { [ViewportFrame]: { cam: Camera, center: Vector3, dist: number, yaw: number, lift: number } } = {}
local spinClock = 0
local mannequin: Model? = nil
local plainMannequin: Model? = nil
local mannequinChar: Model? = nil
local tryOn: { [number]: boolean } = {} -- card index -> show it on your own avatar
local PLAIN_SKIN = Color3.fromRGB(150, 156, 168)

function SuitShopController.Init(c)
	controllers = c
	S = c.State
end

------------------------------------------------------------------------------------------
-- Previews: your own avatar, stripped of its current suit, dressed in each tier
------------------------------------------------------------------------------------------
local function baseMannequin(plain: boolean?): Model?
	local char = player.Character
	if not char then
		return nil
	end
	if mannequinChar ~= char then
		mannequin, plainMannequin = nil, nil
	end
	if plain then
		if plainMannequin then
			return plainMannequin
		end
		local own = baseMannequin(false)
		if not own then
			return nil
		end
		-- a plain grey body: no clothes, accessories or face, so the armour is what you see
		local clone = own:Clone()
		for _, d in clone:GetDescendants() do
			if d:IsA("Accessory") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
				d:Destroy()
			elseif d:IsA("Decal") and d.Name == "face" then
				d:Destroy()
			end
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.Color = PLAIN_SKIN
				d:SetAttribute("OrigColor", PLAIN_SKIN)
			end
		end
		plainMannequin = clone
		return clone
	end
	if mannequin then
		return mannequin
	end
	local was = char.Archivable
	char.Archivable = true
	local clone = char:Clone()
	char.Archivable = was
	if not clone then
		return nil
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("ForceField") then
			d:Destroy()
		end
	end
	local old = clone:FindFirstChild("DiverSuit")
	if old then
		old:Destroy()
	end
	for _, p in clone:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	mannequin, mannequinChar = clone, char
	return clone
end

local function onScreen(vpf: ViewportFrame): boolean
	if not scroll or not scroll.Parent then
		return false
	end
	local node: Instance? = scroll
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	local a, as = vpf.AbsolutePosition, vpf.AbsoluteSize
	local b, bs = scroll.AbsolutePosition, scroll.AbsoluteSize
	return a.X < b.X + bs.X and a.X + as.X > b.X
end

local function preview(index: number, parent: GuiObject)
	local base = baseMannequin(not tryOn[index])
	if not base then
		return
	end
	local suit = Upgrades.Suit(index)
	local model = base:Clone()
	-- the base keeps OrigColor attributes, so the wetsuit recolour starts from your outfit
	SuitArt.Apply(model, index, suit.Color, {})
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		elseif p:IsA("Light") then
			p:Destroy() -- viewports ignore lights; keep the clone light
		end
	end
	local vpf = New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(160, 160, 175),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.5, -1, -0.8),
		ZIndex = 4,
		Parent = parent,
	})
	local world = New("WorldModel", { Parent = vpf })
	model.Parent = world
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cf, size = model:GetBoundingBox()
	local cam = New("Camera", { FieldOfView = 30, Parent = vpf })
	vpf.CurrentCamera = cam
	local look = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	spinners[vpf] = {
		cam = cam,
		center = cf.Position,
		dist = math.max(size.Y, size.X * 1.2) / math.tan(math.rad(15)) * 0.56,
		-- start facing the camera (front of the character), then turn
		yaw = math.atan2(look.X, look.Z) + math.rad(index * 23),
		lift = size.Y * 0.06,
	}
end

local function stepSpinners(dt: number)
	spinClock += dt
	if spinClock < 1 / 30 then
		return
	end
	dt, spinClock = spinClock, 0
	for vpf, s in spinners do
		if vpf.Parent == nil then
			spinners[vpf] = nil
		elseif onScreen(vpf) then
			s.yaw += dt * 0.6
			local dir = Vector3.new(math.sin(s.yaw), 0, math.cos(s.yaw))
			s.cam.CFrame = CFrame.lookAt(s.center + dir * s.dist + Vector3.new(0, s.lift, 0), s.center)
		end
	end
end

------------------------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------------------------
local function pct(x: number): string
	return `+{math.floor(x * 100 + 0.5)}%`
end

-- the money perks (coins, luck): the headline line on a card
local function moneyText(suit): string
	local bits = {}
	if (suit.Income or 0) > 0 then
		table.insert(bits, `x{math.floor((1 + suit.Income) * 100 + 0.5) / 100} coins`)
	end
	if (suit.Luck or 0) > 0 then
		table.insert(bits, `{pct(suit.Luck)} luck`)
	end
	return table.concat(bits, "  ")
end

local function perkText(suit): string
	local bits = {}
	if suit.Air > 0 then
		table.insert(bits, `+{math.floor(suit.Air * 100 + 0.5)}% air`)
	end
	if suit.Swim > 0 then
		table.insert(bits, `+{math.floor(suit.Swim * 100 + 0.5)}% swim`)
	end
	return if #bits > 0 then table.concat(bits, "  ") else "Starter suit"
end

-- Kit.ActionButton (Figma "Game Buttons" > ActionButton): Green buy, Blue equip, Dark equipped,
-- Grey locked or can't afford
local function actionButton(parent: GuiObject, text: string, colorName: string | Color3, onClick: (() -> ())?, icon: string?)
	local holder = Kit.ActionButton(text, colorName, onClick, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 54),
		TextSize = 24,
		ZIndex = 5,
		Icon = icon,
		Parent = parent,
	})
	return holder
end

local render: () -> ()

local function suitCard(index: number, suitIndex: number, wearing: number, coins: number)
	local suit = Upgrades.Suits[index]
	local owned = index <= suitIndex
	local isNext = index == suitIndex + 1
	local isWorn = index == wearing
	local tierColor = Kit.RarityColor(suit.Tier, Rarities)
	local fill = Kit.Darken(Kit.Lighten(tierColor, 0.12), if owned or isNext then 0.05 else 0.35)

	local holder = New("Frame", {
		Name = suit.Id,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, CARD_W, 1, -8),
		LayoutOrder = index,
		Parent = scroll,
	})
	-- lip under the card (raised slab)
	New("Frame", {
		Name = "Lip",
		BackgroundColor3 = Kit.Darken(fill, 0.55),
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 1, -6),
		Parent = holder,
	}, { Kit.Corner(18), Kit.Stroke(T.Outline, 3, 0) })
	local card = New("Frame", {
		Name = "Card",
		BackgroundColor3 = fill,
		Size = UDim2.new(1, 0, 1, -6),
		ZIndex = 2,
		Parent = holder,
	}, {
		Kit.Corner(18),
		Kit.Stroke(if isWorn then T.Good else T.Outline, if isWorn then 4 else 3, 0),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(215, 215, 220)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 160)),
			}),
		}),
	})
	-- soft light rays behind the model
	Kit.Glow(card, Kit.Lighten(tierColor, 0.55), 150, { Position = UDim2.new(0.5, 0, 0.44, 0) })

	local name = Kit.Title({
		Text = suit.Name,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 30),
		TextScaled = true,
		TextWrapped = false,
		ZIndex = 5,
		Parent = card,
	})
	New("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 14, Parent = name })
	Kit.Title({
		Text = suit.Tier,
		TextSize = 17,
		TextColor3 = Kit.Lighten(tierColor, 0.65),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(8, 38),
		Size = UDim2.new(1, -16, 0, 20),
		TextWrapped = false,
		ZIndex = 5,
		Parent = card,
	})

	-- the diver
	local stage = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 60),
		Size = UDim2.new(1, -12, 1, -230),
		ZIndex = 3,
		Parent = card,
	})
	preview(index, stage)
	-- small TRY ON toggle: show this suit on your own avatar instead of the plain mannequin
	Kit.ActionButton(if tryOn[index] then "PLAIN" else "TRY ON", if tryOn[index] then "Dark" else "Blue", function()
		tryOn[index] = not tryOn[index]
		local keep = scroll.CanvasPosition
		sig = "" -- rebuild the row; keep where it was scrolled
		render()
		scroll.CanvasPosition = keep
	end, {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(80, 32),
		TextSize = 13,
		ZIndex = 6,
		Parent = stage,
	})
	if not owned and not isNext then
		Kit.IconBadge("lock", T.PanelDark, 34, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			ZIndex = 6,
			Parent = stage,
		})
	end

	-- perks and zone: coins and luck in gold (the big ones), then air and swim
	local money = moneyText(suit)
	if money ~= "" then
		Kit.Title({
			Text = money,
			TextSize = 16,
			TextColor3 = Color3.fromRGB(255, 220, 90),
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -152),
			Size = UDim2.new(1, -16, 0, 20),
			TextWrapped = false,
			ZIndex = 5,
			Parent = card,
		})
	end
	Kit.Title({
		Text = perkText(suit),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 255, 170),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -132),
		Size = UDim2.new(1, -16, 0, 18),
		TextWrapped = false,
		ZIndex = 5,
		Parent = card,
	})
	local zone = Zones.List[suit.Zone]
	local zoneRow = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -108),
		Size = UDim2.new(1, -16, 0, 22),
		ZIndex = 5,
		Parent = card,
	}, { Kit.List(4, true, Enum.HorizontalAlignment.Center) })
	Kit.Pill(`Safe: {zone and zone.Name or "?"}`, Kit.Lighten(zone and zone.FogColor or T.Accent, 0.3), {
		Icon = zone and Icons.Get(zone.Id) or nil,
		TextSize = 12,
		Font = T.Title,
		Size = UDim2.fromOffset(0, 22),
		ZIndex = 6,
		Parent = zoneRow,
	})

	-- "Tier N" plate: dark, translucent, green text
	New("TextLabel", {
		Text = `Tier {index}`,
		Font = T.Title,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(150, 255, 90),
		TextStrokeColor3 = T.Outline,
		TextStrokeTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		BackgroundTransparency = 0.45,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.new(1, -20, 0, 36),
		ZIndex = 5,
		Parent = card,
	}, { Kit.Corner(12), Kit.Stroke(T.Outline, 2, 0) })

	-- the one action
	if isWorn then
		actionButton(card, "EQUIPPED", "Dark", nil)
	elseif owned then
		actionButton(card, "EQUIP", "Blue", function()
			Net.RequestEquipSuit:FireServer(index)
		end)
	elseif suit.ComingSoon then
		actionButton(card, "SOON", "Grey", nil)
	elseif isNext then
		local can = coins >= suit.Cost
		local b = actionButton(card, NumberFormat.short(suit.Cost), if can then "Green" else "Grey", function()
			if coins >= suit.Cost then
				Net.RequestBuySuit:FireServer()
			else
				controllers.UIController.Toast(`Need {NumberFormat.short(suit.Cost - coins)} more Coins`, "error")
			end
		end, "coin")
		if can then
			Kit.Pulse(b, 0.035)
		end
	else
		actionButton(card, NumberFormat.short(suit.Cost), "Grey", function()
			controllers.UIController.Toast(`Buy the {Upgrades.Suits[suitIndex + 1].Name} first`, "info")
		end, "lock")
	end
	if suit.Tier == "Legendary" or suit.Tier == "Mythic" then
		Kit.Shine(card, if suit.Tier == "Mythic" then 2.5 else 3.5)
	end
end

------------------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------------------
function render()
	if not scroll then
		return
	end
	local suitIndex = S.Get("Suit") or 1
	local look = S.Get("SuitLook") or 0
	local wearing = if look >= 1 and look <= suitIndex then look else suitIndex
	local coins = S.Get("Coins") or 0
	local nextSuit = Upgrades.Suits[suitIndex + 1]
	local canBuy = nextSuit ~= nil and not nextSuit.ComingSoon and coins >= nextSuit.Cost

	-- header strip (Throw Power pattern): what you wear, how deep you're safe, owned count
	local worn = Upgrades.Suit(wearing)
	local zone = Zones.List[Upgrades.SuitZone(suitIndex)]
	strip.title.Text = worn.Name
	local best = Upgrades.Suit(suitIndex)
	local money = moneyText(best)
	strip.sub.Text = `Safe down to {zone and zone.Name or "?"}  ·  {if money ~= "" then money .. "  " else ""}{perkText(best)}`
	strip.count.Text = `{suitIndex}/{#Upgrades.Suits}`

	-- Coins tick every second: rebuild only when a card would change
	local key = `{suitIndex}|{wearing}|{canBuy}|{player.Character}`
	if key == sig then
		return
	end
	sig = key
	Kit.Clear(scroll) -- keeps the list layout and padding
	for i = 1, #Upgrades.Suits do
		suitCard(i, suitIndex, wearing, coins)
	end
	-- bring the next suit (or the worn one) into view once per unlock
	if scrolledFor ~= suitIndex then
		scrolledFor = suitIndex
		task.defer(function()
			local focus = math.min(suitIndex + 1, #Upgrades.Suits)
			local x = (focus - 1) * (CARD_W + 14) - (scroll.AbsoluteSize.X - CARD_W) / 2
			scroll.CanvasPosition = Vector2.new(math.max(x, 0), 0)
		end)
	end
end

local function build(body: Frame)
	-- header strip: icon chip, worn suit, safe zone and perks, owned counter
	local head = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 33, 42),
		Size = UDim2.new(1, 0, 0, 62),
		Parent = body,
	}, { Kit.Corner(16), Kit.Stroke(T.Outline, 3, 0) })
	Kit.IconBadge(Icons.Get("Suits"), Icons.Colors.Suits, 46, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Parent = head,
	})
	Kit.Label({
		Text = "WEARING",
		Font = T.Title,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(150, 160, 180),
		Position = UDim2.fromOffset(64, 6),
		Size = UDim2.new(1, -170, 0, 14),
		Parent = head,
	})
	strip.title = Kit.Title({
		Text = "",
		TextSize = 22,
		Position = UDim2.fromOffset(64, 18),
		Size = UDim2.new(1, -170, 0, 24),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	strip.sub = Kit.Title({
		Text = "",
		TextSize = 13,
		TextColor3 = Color3.fromRGB(110, 200, 255),
		Position = UDim2.fromOffset(64, 41),
		Size = UDim2.new(1, -170, 0, 16),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	})
	local counter = New("Frame", {
		BackgroundColor3 = T.PanelDark,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(92, 42),
		Parent = head,
	}, { Kit.Corner(12), Kit.Stroke(T.Outline, 2, 0) })
	Icon.new(Icons.Get("Suits"), 22, T.Gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Parent = counter,
	})
	strip.count = Kit.Title({
		Text = "",
		TextSize = 20,
		TextColor3 = T.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -10, 1, 0),
		TextWrapped = false,
		Parent = counter,
	})
	-- the card row sits in a dark well
	local well = New("Frame", {
		BackgroundColor3 = T.PanelDark,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 1, -72),
		Parent = body,
	}, { Kit.Corner(16), Kit.Stroke(T.Outline, 3, 0) })
	scroll = Kit.Scroll({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 1, -12),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.fromScale(0, 1),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Icons.Colors.Suits,
		Parent = well,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 14),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = scroll,
	})
	New("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		Parent = scroll,
	})
end

function SuitShopController.Start()
	local UI = controllers.UIController
	UI.RegisterWindow("Suits", "Suit Shop", build, render)
	RunService.RenderStepped:Connect(stepSpinners)
	S.Changed:Connect(function(keys)
		if keys.Suit or keys.SuitLook or keys.Coins then
			UI.Refresh("Suits")
		end
	end)
	player.CharacterAdded:Connect(function()
		mannequin, plainMannequin, mannequinChar, sig = nil, nil, nil, ""
	end)
	-- the stall on every dock
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "SuitShopPrompt" then
			UI.Open("Suits")
		end
	end)
	-- stepping onto a stall's glowing pad opens the shop once; step off and on to open again
	task.spawn(function()
		local onPad = false
		while true do
			task.wait(0.15)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local now = false
			if hrp then
				for _, disc in CollectionService:GetTagged("SuitShopDisc") do
					if disc:IsA("BasePart") then
						local d = hrp.Position - disc.Position
						if math.abs(d.Y) < 5 and d.X * d.X + d.Z * d.Z < 2.9 * 2.9 then
							now = true
							break
						end
					end
				end
			end
			if now and not onPad and not UI.IsOpen("Suits") then
				UI.Open("Suits")
			end
			onPad = now
		end
	end)
end

return SuitShopController
