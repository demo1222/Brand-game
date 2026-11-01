-- RelicCard: collectible card with a live 3D render (UI design canvas "Bag & Dock window").
-- Flat rarity-tinted card, rarity name in small caps (+ its symbol, colour-blind safe §18.3),
-- 3D model over a soft glow, name and income at the bottom.
--
--   RelicCard.new(props) -> TextButton
--     props.Relic      { id, rarity, mutations, size, locked }  (inventory relic)
--     props.Def        Relics.ById entry (Codex). With props.Discovered = false shows "???"
--     props.Subtitle   small line under the name (e.g. "+12 / s")
--     props.Selected   white border
--     props.OnClick    callback
--     props.LazyModel  defer the 3D render until RelicCard.Realize(card) is called
--     + Size, LayoutOrder, Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Kit = require(script.Parent.Kit)
local Icon = require(script.Parent.Icon)
local RelicView = require(script.Parent.RelicView)

local New, T = Kit.New, Kit.Theme
local RelicCard = {}

-- Card background for a rarity: base colour + gradient (used by the Bag detail stage too)
function RelicCard.RarityBackground(rarityName: string, dim: boolean?)
	if rarityName == "Secret" then
		return Color3.fromRGB(16, 14, 24), ColorSequence.new(Color3.fromRGB(30, 26, 44), Color3.fromRGB(10, 9, 16))
	end
	local c = Kit.RarityColor(rarityName, Rarities)
	local base = Kit.Darken(c, if dim then 0.86 else 0.74)
	return base, ColorSequence.new(base, base)
end

local pending: { [TextButton]: any } = setmetatable({}, { __mode = "k" }) :: any

local function mountModel(card: TextButton, args)
	RelicView.new({
		Relic = args.relic,
		Silhouette = args.silhouette,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.new(1, -16, 1, -66),
		ZIndex = 2,
		Spin = args.spin,
		Parent = card,
	})
end

-- Create the 3D view for a card built with LazyModel (Bag grid, only when scrolled into view)
function RelicCard.Realize(card: TextButton)
	local args = pending[card]
	if args then
		pending[card] = nil
		mountModel(card, args)
	end
end

function RelicCard.IsRealized(card: TextButton): boolean
	return pending[card] == nil
end

function RelicCard.new(props): TextButton
	local relic = props.Relic
	local def = props.Def or (relic and Relics.ById[relic.id])
	local rarityName = if relic then relic.rarity else def.Rarity
	local rarity = Rarities[rarityName]
	local discovered = props.Discovered ~= false
	local rColor = Kit.RarityColor(rarityName, Rarities)
	local tier = rarity and rarity.Tier or 1

	local bg = RelicCard.RarityBackground(rarityName, not discovered)
	local card = New("TextButton", {
		Name = if relic and relic.uid then relic.uid else def.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = bg,
		Size = props.Size or UDim2.fromOffset(112, 150),
		LayoutOrder = props.LayoutOrder or 0,
	}, { Kit.Corner(14) })
	Kit.Stroke(
		if props.Selected then Color3.new(1, 1, 1) else rColor,
		if props.Selected then 2 else 1,
		if props.Selected then 0 elseif discovered then 0.35 else 0.75
	).Parent =
		card
	Kit.Juice(card)

	if discovered then
		Kit.Glow(card, rColor, 84, { Position = UDim2.new(0.5, 0, 0, 58) })
	end
	local args = { relic = relic or { id = def.Id }, silhouette = not discovered, spin = props.Spin }
	if props.LazyModel then
		pending[card] = args
	else
		mountModel(card, args)
	end

	-- Rarity in small caps, top-left (symbol keeps it readable for colour-blind players)
	Kit.Label({
		Text = `{rarity and rarity.Icon or ""} {string.upper(rarityName)}`,
		Font = T.Bold,
		TextSize = 10,
		TextColor3 = Kit.Lighten(rColor, 0.45),
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 14),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = card,
	})

	-- Top-right: HUGE tag, lock
	local tr = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 22),
		Size = UDim2.fromOffset(80, 18),
		ZIndex = 3,
		Parent = card,
	}, { Kit.List(3, true, Enum.HorizontalAlignment.Right) })
	if relic and relic.size and relic.size >= 1.35 then
		Kit.Pill(
			"HUGE",
			T.Bad,
			{ TextSize = 9, Size = UDim2.fromOffset(0, 16), ZIndex = 3, LayoutOrder = 1, Parent = tr }
		)
	end
	if relic and relic.locked then
		local lock = New(
			"Frame",
			{ BackgroundColor3 = T.PanelDark, Size = UDim2.fromOffset(18, 18), LayoutOrder = 2, ZIndex = 3, Parent = tr },
			{ Kit.Corner(5) }
		)
		Icon.new(
			"lock",
			12,
			T.Text,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4, Parent = lock }
		)
	end

	-- Mutation dots
	if relic and relic.mutations and #relic.mutations > 0 then
		local dots = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 1, -54),
			Size = UDim2.fromOffset(80, 10),
			ZIndex = 3,
			Parent = card,
		}, { Kit.List(3, true) })
		for i, m in relic.mutations do
			local md = Mutations.ById[m]
			if md then
				New("Frame", {
					BackgroundColor3 = md.Color,
					Size = UDim2.fromOffset(10, 10),
					LayoutOrder = i,
					ZIndex = 3,
					Parent = dots,
				}, { Kit.Round(), Kit.Stroke(Color3.new(1, 1, 1), 1, 0.2) })
			end
		end
	end

	-- Name + subtitle
	local mutPrefix = if relic and relic.mutations and #relic.mutations > 0 then relic.mutations[1] .. " " else ""
	local name = Kit.Title({
		Text = if discovered then mutPrefix .. def.Name else "???",
		TextSize = 13,
		TextColor3 = if discovered then T.Text else T.Muted,
		Position = UDim2.new(0, 8, 1, -40),
		Size = UDim2.new(1, -16, 0, 18),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = card,
	})
	New("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 9, Parent = name })
	if props.Subtitle then
		Kit.Label({
			Text = props.Subtitle,
			Font = T.Bold,
			TextSize = 11,
			TextColor3 = if discovered then T.Good else T.Muted,
			Position = UDim2.new(0, 8, 1, -22),
			Size = UDim2.new(1, -16, 0, 14),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = card,
		})
	end

	if discovered and tier >= 5 then
		Kit.Shine(card, 3 + (7 - tier))
	end
	if props.OnClick then
		card.Activated:Connect(props.OnClick)
	end
	if props.Parent then
		card.Parent = props.Parent
	end
	return card
end

return RelicCard
