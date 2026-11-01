-- RelicCard: collectible-style card with a live 3D render (UI/Visual Overhaul Plan, Phase 1).
--
--   RelicCard.new(props) -> TextButton
--     props.Relic      { id, rarity, mutations, size, locked }  (inventory relic)
--     props.Def        Relics.ById entry (Codex). Use with props.Discovered = false for "???"
--     props.Subtitle   small line under the name (e.g. "+12/s")
--     props.Selected   highlighted border
--     props.OnClick    callback
--     + Size, LayoutOrder, Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)
local RelicView = require(script.Parent.RelicView)

local New, T = Kit.New, Kit.Theme
local RelicCard = {}

function RelicCard.RarityBackground(rarityName: string, dim: boolean?)
	local c = Kit.RarityColor(rarityName, Rarities)
	if rarityName == "Secret" then
		return Color3.fromRGB(14, 12, 20),
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 60, 90)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 16, 30)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 8)),
			})
	end
	local base = Kit.Darken(c, if dim then 0.8 else 0.5)
	return base, ColorSequence.new(Kit.Lighten(base, 0.25), Kit.Darken(base, 0.55))
end

function RelicCard.new(props): TextButton
	local relic = props.Relic
	local def = props.Def or (relic and Relics.ById[relic.id])
	local rarityName = if relic then relic.rarity else def.Rarity
	local rarity = Rarities[rarityName]
	local discovered = props.Discovered ~= false
	local rColor = Kit.RarityColor(rarityName, Rarities)
	local tier = rarity and rarity.Tier or 1

	local bg, seq = RelicCard.RarityBackground(rarityName, not discovered)
	local card = New("TextButton", {
		Name = if relic and relic.uid then relic.uid else def.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = bg,
		Size = props.Size or UDim2.fromOffset(108, 136),
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = false,
	}, {
		Kit.Corner(14),
		New("UIGradient", { Rotation = 90, Color = seq }),
	})
	local stroke = Kit.Stroke(
		if props.Selected then Color3.new(1, 1, 1) else rColor,
		if props.Selected then 3.5 else 2,
		if discovered then 0.05 else 0.6
	)
	stroke.Parent = card
	Kit.Juice(card)

	-- Glow + model
	if discovered then
		Kit.Glow(card, rColor, 90, { Position = UDim2.new(0.5, 0, 0, 52) })
	end
	RelicView.new({
		Relic = relic or { id = def.Id },
		Silhouette = not discovered,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(1, -10, 1, -50),
		ZIndex = 2,
		Spin = props.Spin,
		Parent = card,
	})

	-- Rarity chip (icon is the colour-blind-safe indicator, §18.3)
	local chip = Kit.IconBadge(rarity and rarity.Icon or "●", rColor, 24, {
		Position = UDim2.fromOffset(4, 4),
		ZIndex = 3,
		Parent = card,
	})
	chip:FindFirstChildOfClass("TextLabel").TextColor3 = Kit.TextOn(rColor)

	-- Top-right badges
	local tr = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(70, 20),
		Parent = card,
	}, { Kit.List(3, true, Enum.HorizontalAlignment.Right) })
	if relic and relic.size and relic.size >= 1.35 then
		Kit.Pill(
			"HUGE",
			T.Bad,
			{ TextSize = 10, Size = UDim2.fromOffset(0, 18), ZIndex = 3, LayoutOrder = 1, Parent = tr }
		)
	end
	if relic and relic.locked then
		Kit.Pill(
			Icons.Get("Lock"),
			T.PanelDark,
			{ TextSize = 10, Size = UDim2.fromOffset(0, 18), ZIndex = 3, LayoutOrder = 2, Parent = tr }
		)
	end

	-- Mutation dots
	if relic and relic.mutations and #relic.mutations > 0 then
		local dots = New("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 6, 1, -54),
			Size = UDim2.fromOffset(80, 12),
			Parent = card,
		}, { Kit.List(3, true) })
		for i, m in relic.mutations do
			local md = Mutations.ById[m]
			if md then
				New("Frame", {
					BackgroundColor3 = md.Color,
					Size = UDim2.fromOffset(12, 12),
					LayoutOrder = i,
					ZIndex = 3,
					Parent = dots,
				}, { Kit.Round(), Kit.Stroke(Color3.new(1, 1, 1), 1.5, 0.1) })
			end
		end
	end

	-- Name plate
	local plate = New("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.new(1, -6, 0, if props.Subtitle then 40 else 30),
		ZIndex = 2,
		Parent = card,
	}, { Kit.Corner(11) })
	local mutPrefix = if relic and relic.mutations and #relic.mutations > 0 then relic.mutations[1] .. " " else ""
	Kit.Title({
		Text = if discovered then mutPrefix .. def.Name else "???",
		TextScaled = true,
		TextColor3 = if discovered then Color3.new(1, 1, 1) else T.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 22),
		ZIndex = 3,
		Parent = plate,
	}, nil)
	New(
		"UITextSizeConstraint",
		{ MaxTextSize = 14, MinTextSize = 8, Parent = plate:FindFirstChildOfClass("TextLabel") }
	)
	if props.Subtitle then
		Kit.Label({
			Text = props.Subtitle,
			Font = T.Bold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(130, 255, 160),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 22),
			Size = UDim2.new(1, -4, 0, 16),
			TextWrapped = false,
			ZIndex = 3,
			Parent = plate,
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
