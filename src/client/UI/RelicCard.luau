-- RelicCard: collectible card with a live 3D render (docs/UI_STYLE_GUIDE.md, "Animal Index").
-- A slab filled with the rarity colour (lighter top), thick dark outline, the name outlined at
-- the top, the 3D model turning slowly in the middle, the rarity word and a subtitle at the
-- bottom. Undiscovered entries are grey slabs with a black silhouette.
--
--   RelicCard.new(props) -> TextButton
--     props.Relic      { id, rarity, mutations, size, locked }  (inventory relic)
--     props.Def        Relics.ById entry (Codex). With props.Discovered = false shows "???"
--     props.Subtitle   small line under the name (e.g. "+12 / s")
--     props.Selected   white border
--     props.OnClick    callback
--     props.LazyModel  defer the 3D render until RelicCard.Realize(card) is called
--     props.Still      don't turn the model (default: slow turntable, random start angle)
--     + Size, LayoutOrder, Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Materials = require(Shared.Config.Materials)
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

-- The card fill for a rarity: bright, like the reference index cards
local GREY = Color3.fromRGB(120, 128, 142)
function RelicCard.Fill(rarityName: string, discovered: boolean): Color3
	if not discovered then
		return GREY
	end
	if rarityName == "Secret" then
		return Color3.fromRGB(40, 34, 58)
	end
	return Kit.Darken(Kit.RarityColor(rarityName, Rarities), 0.12)
end

local function mountModel(card: TextButton, args)
	RelicView.new({
		Relic = args.relic,
		Silhouette = args.silhouette,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.new(1, -14, 1, -64),
		ZIndex = 2,
		Spin = args.spin,
		Bob = args.spin ~= nil,
		Angle = args.angle,
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

	local fill = RelicCard.Fill(rarityName, discovered)
	local card = New("TextButton", {
		Name = if relic and relic.uid then relic.uid else def.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = fill,
		Size = props.Size or UDim2.fromOffset(112, 150),
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Kit.Corner(14),
		-- lighter top, darker bottom band: reads as a raised slab
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(225, 225, 225)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 165)),
			}),
		}),
	})
	Kit.Stroke(
		if props.Selected then Color3.new(1, 1, 1) else T.Outline,
		if props.Selected then 3 else 2,
		0
	).Parent =
		card
	-- inner rim in a lighter tint of the fill
	New("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 1,
		Parent = card,
	}, { Kit.Corner(12), Kit.Stroke(Kit.Lighten(fill, 0.45), 2, 0.35) })
	Kit.Juice(card)

	if discovered then
		Kit.Glow(card, Kit.Lighten(rColor, 0.4), 84, { Position = UDim2.new(0.5, 0, 0, 66) })
	end
	local spin = props.Spin
	if spin == nil and not props.Still then
		spin = 24
	end
	local args = {
		relic = relic or { id = def.Id },
		silhouette = not discovered,
		spin = spin,
		angle = math.random(0, 359),
	}
	if props.LazyModel then
		pending[card] = args
	else
		mountModel(card, args)
	end

	-- Rarity word at the bottom (the word, not the glyph: rarity glyphs render as boxes)
	Kit.Title({
		Text = if discovered then rarityName else "???",
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 6, 1, if props.Subtitle then -36 else -24),
		Size = UDim2.new(1, -12, 0, 16),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = card,
	})

	-- Top-right: HUGE tag, lock
	local tr = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 26),
		Size = UDim2.fromOffset(80, 18),
		ZIndex = 3,
		Parent = card,
	}, { Kit.List(3, true, Enum.HorizontalAlignment.Right) })
	local sizeTier = relic and Materials.SizeTier(relic.size)
	if sizeTier and sizeTier.Label and sizeTier.Id ~= "Tiny" then
		Kit.Pill(
			sizeTier.Label,
			sizeTier.Color,
			{ TextSize = 9, Size = UDim2.fromOffset(0, 16), ZIndex = 3, LayoutOrder = 1, Parent = tr }
		)
	end
	local matDef = relic and relic.material and Materials.ById[relic.material]
	if matDef then
		Kit.Pill(
			matDef.Name,
			matDef.Color,
			{ TextSize = 9, Size = UDim2.fromOffset(0, 16), ZIndex = 3, LayoutOrder = 0, Parent = tr }
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
			Position = UDim2.new(0, 8, 0, 28),
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
	local mutPrefix = if relic and relic.material and Materials.ById[relic.material]
		then relic.material .. " "
		elseif relic and relic.mutations and #relic.mutations > 0 then relic.mutations[1] .. " "
		else ""
	local name = Kit.Title({
		Text = if discovered then mutPrefix .. def.Name else "???",
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 6, 0, 6),
		Size = UDim2.new(1, -12, 0, 18),
		TextScaled = true,
		TextWrapped = false,
		ZIndex = 3,
		Parent = card,
	})
	New("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9, Parent = name })
	if props.Subtitle then
		Kit.Title({
			Text = props.Subtitle,
			TextSize = 12,
			TextColor3 = if discovered then Color3.fromRGB(200, 255, 170) else Color3.fromRGB(225, 230, 240),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 6, 1, -21),
			Size = UDim2.new(1, -12, 0, 15),
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
