-- UI Kit v4: chunky game UI. Pressable buttons with a darker bottom lip, thick dark outlines,
-- outlined display text (FredokaOne), colour-coded slabs and drawn vector icons (UI/Icon)
-- instead of emoji. No dependencies, mobile-first (>= 44 px touch targets). The v1-v3 API is
-- unchanged, so every screen picks up the style.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Icon = require(script.Parent.Icon)

local Kit = {}

Kit.Theme = {
	Bg = Color3.fromRGB(13, 26, 44),
	Panel = Color3.fromRGB(13, 26, 44),
	PanelLight = Color3.fromRGB(22, 38, 61),
	PanelDark = Color3.fromRGB(8, 18, 31),
	Accent = Color3.fromRGB(63, 214, 230),
	AccentDeep = Color3.fromRGB(26, 92, 120),
	Gold = Color3.fromRGB(245, 192, 74),
	Good = Color3.fromRGB(123, 227, 160),
	Bad = Color3.fromRGB(240, 90, 90),
	BadDeep = Color3.fromRGB(90, 36, 48),
	Pearl = Color3.fromRGB(191, 216, 255),
	Text = Color3.fromRGB(234, 244, 255),
	Muted = Color3.fromRGB(169, 189, 214),
	DarkText = Color3.fromRGB(6, 32, 41),
	Hairline = Color3.fromRGB(63, 214, 230),
	Outline = Color3.fromRGB(4, 11, 22), -- thick dark outline around slabs, buttons and text
	Slab = Color3.fromRGB(30, 50, 78), -- raised tile on a window body
	Font = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Title = Enum.Font.FredokaOne,
}
local T = Kit.Theme
Kit.Icon = Icon

------------------------------------------------------------------------------------------
-- Colour helpers
------------------------------------------------------------------------------------------
function Kit.Darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

function Kit.Lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

-- Dark text on bright fills (gold, teal, white), white text otherwise
function Kit.TextOn(c: Color3): Color3
	local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return if l > 0.6 then T.DarkText else Color3.new(1, 1, 1)
end

-- Display colour for a rarity (Secret is black in config; shown as silver on dark UI)
function Kit.RarityColor(rarityName: string?, rarities): Color3
	if rarityName == "Secret" then
		return Color3.fromRGB(225, 225, 240)
	end
	local r = rarities and rarities[rarityName or ""]
	return if type(r) == "table" and r.Color then r.Color else T.Muted
end

------------------------------------------------------------------------------------------
-- Instances
------------------------------------------------------------------------------------------
function Kit.New(className: string, props, children)
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local New = Kit.New

function Kit.Corner(r: number?)
	return New("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

function Kit.Round()
	return New("UICorner", { CornerRadius = UDim.new(0.5, 0) })
end

-- Border stroke (never strokes text: ApplyStrokeMode = Border)
function Kit.Stroke(color: Color3?, thickness: number?, transparency: number?)
	return New("UIStroke", {
		Color = color or T.Hairline,
		Thickness = thickness or 1,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Flat design: kept for API compatibility, renders no visible gradient
function Kit.Sheen(_strength: number?, rotation: number?)
	return New(
		"UIGradient",
		{ Name = "Flat", Rotation = rotation or 90, Color = ColorSequence.new(Color3.new(1, 1, 1)) }
	)
end

function Kit.Gradient(c1: Color3, c2: Color3, rotation: number?)
	return New("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(c1, c2) })
end

function Kit.Padding(px: number)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Kit.List(padding: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

function Kit.Grid(cell: Vector2, pad: number?)
	return New("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(pad or 8, pad or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.Label(props)
	local p = {
		BackgroundTransparency = 1,
		TextColor3 = T.Text,
		Font = T.Font,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
	}
	for k, v in props do
		p[k] = v
	end
	return New("TextLabel", p)
end

-- Display text (titles, numbers) with a dark outline, like most Roblox game UI. Pass
-- Outline = false for text on bright plates where the outline would muddy dark lettering.
function Kit.Title(props)
	local p = {
		Font = T.Title,
		TextSize = 22,
		TextStrokeTransparency = 1,
	}
	local outline = true
	for k, v in props do
		if k == "Outline" then
			outline = v
		else
			p[k] = v
		end
	end
	local label = Kit.Label(p)
	local c = label.TextColor3
	local dark = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B < 0.35
	if outline and not dark then
		New("UIStroke", {
			Name = "TextOutline",
			Color = T.Outline,
			Thickness = math.clamp(label.TextSize / 11, 1, 3),
			Transparency = 0.1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
end

-- Shading that makes a flat fill read as a raised block: slightly lighter top, and a darker
-- band along the bottom edge (the "lip"). Multiplies BackgroundColor3, so recolouring the
-- object later keeps the effect. `lipPx` is the lip height for an object `heightPx` tall.
function Kit.Bevel(gui: GuiObject, heightPx: number?, lipPx: number?)
	local h = math.max(heightPx or 44, 8)
	local lip = math.clamp((lipPx or 5) / h, 0.04, 0.3)
	local old = gui:FindFirstChild("Bevel")
	if old then
		old:Destroy()
	end
	return New("UIGradient", {
		Name = "Bevel",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1 - lip - 0.002, Color3.fromRGB(222, 222, 222)),
			ColorSequenceKeypoint.new(1 - lip, Color3.fromRGB(150, 150, 150)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
		}),
		Parent = gui,
	})
end

------------------------------------------------------------------------------------------
-- Motion
------------------------------------------------------------------------------------------
local function scaleOf(gui: GuiObject): UIScale
	return gui:FindFirstChild("KitScale") :: UIScale or New("UIScale", { Name = "KitScale", Parent = gui })
end

function Kit.Pop(gui: GuiObject)
	local scale = scaleOf(gui)
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Subtle press/hover feedback for any GuiButton
function Kit.Juice(button: GuiButton)
	local scale = scaleOf(button)
	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(scale, quick, { Scale = 1.02 }):Play()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, quick, { Scale = 0.96 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, quick, { Scale = if hovering then 1.02 else 1 }):Play()
	end)
end

-- Soft light sweep (claimable rewards, Legendary+ cards, the VIP banner)
function Kit.Shine(gui: GuiObject, period: number?)
	local corner = gui:FindFirstChildOfClass("UICorner")
	local shine = New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = gui.ZIndex + 5,
		Active = false,
		Parent = gui,
	}, {
		New("UICorner", { CornerRadius = if corner then corner.CornerRadius else UDim.new(0, 10) }),
	})
	local g = New("UIGradient", {
		Rotation = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.78),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = shine,
	})
	TweenService:Create(
		g,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, period or 2.2),
		{ Offset = Vector2.new(1, 0) }
	):Play()
	return shine
end

-- Soft radial glow: stacked circles with falling opacity
function Kit.Glow(parent: Instance, color: Color3, size: number, props)
	local holder = New("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	for k, v in props or {} do
		(holder :: any)[k] = v
	end
	for i, t in { 0.93, 0.88, 0.82, 0.76 } do
		local s = 1 - (i - 1) * 0.22
		New("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = t,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(s, s),
			ZIndex = holder.ZIndex,
			Parent = holder,
		}, { Kit.Round() })
	end
	return holder
end

-- Gentle pulse (alerts, claimable dots)
function Kit.Pulse(gui: GuiObject, amount: number?)
	local scale = scaleOf(gui)
	local a = amount or 0.05
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not gui.Parent then
			conn:Disconnect()
			return
		end
		scale.Scale = 1 + math.sin(os.clock() * 5) * a
	end)
	return conn
end

------------------------------------------------------------------------------------------
-- Icons inside text controls
------------------------------------------------------------------------------------------
-- Pins a drawn icon just left of a control's (centred or left-aligned) text. The control gets
-- left padding for it; position follows TextBounds so icon + text stay together.
function Kit.AttachIcon(control: TextLabel | TextButton, iconName: string, color: Color3?, size: number?)
	local s = size or math.floor(control.TextSize * 1.15)
	local gap = 6
	local pad = control:FindFirstChildOfClass("UIPadding") or New("UIPadding", { Parent = control })
	pad.PaddingLeft = UDim.new(0, pad.PaddingLeft.Offset + s + gap)
	local icon = Icon.new(iconName, s, color or control.TextColor3, {
		Name = "LeadIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = control.ZIndex + 1,
		Parent = control,
	})
	local function place()
		-- child positions are relative to the padded content box
		local contentW = control.AbsoluteSize.X - pad.PaddingLeft.Offset - pad.PaddingRight.Offset
		local textW = math.min(control.TextBounds.X, contentW)
		local textLeft = if control.TextXAlignment == Enum.TextXAlignment.Center then (contentW - textW) / 2 else 0
		icon.Position = UDim2.new(0, textLeft - gap - s, 0.5, 0)
	end
	control:GetPropertyChangedSignal("TextBounds"):Connect(place)
	control:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	task.defer(place)
	return icon
end

------------------------------------------------------------------------------------------
-- Controls
------------------------------------------------------------------------------------------
-- Solid button. props.Icon = drawn icon name shown before the text.
function Kit.Button(text: string, color: Color3?, onClick: (() -> ())?, props)
	local c = color or T.Accent
	local p = {
		Text = text,
		BackgroundColor3 = c,
		TextColor3 = Kit.TextOn(c),
		Font = T.Bold,
		TextSize = 15,
		Size = UDim2.fromOffset(120, 46),
		AutoButtonColor = false,
		TextStrokeTransparency = 1,
	}
	local iconName = nil
	for k, v in props or {} do
		if k == "Icon" then
			iconName = v
		else
			p[k] = v
		end
	end
	local b = New("TextButton", p, {
		Kit.Corner(12),
		Kit.Stroke(T.Outline, 2, 0),
	})
	-- Raised block: darker bottom lip, text centred on the face above it
	local h = if b.Size.Y.Scale == 0 then b.Size.Y.Offset else 44
	local lip = math.clamp(math.floor(h * 0.12), 3, 6)
	Kit.Bevel(b, h, lip)
	New("UIPadding", { PaddingBottom = UDim.new(0, lip), Parent = b })
	if Kit.TextOn(c) ~= T.DarkText then
		b.TextStrokeColor3 = T.Outline
		b.TextStrokeTransparency = 0.45
	end
	if iconName and Icon.Has(iconName) then
		Kit.AttachIcon(b, iconName)
	end
	Kit.Juice(b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Game-style button: a solid face over a darker "lip" that presses down on click (HUD rail,
-- action buttons). Returns container (layout/position this), face (the TextButton).
function Kit.GameButton(color: Color3, size: Vector2, props, round: boolean?)
	local lip = 4
	local container = New("Frame", {
		Name = "GameButton",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y + lip),
	})
	for k, v in props or {} do
		(container :: any)[k] = v
	end
	local corner = if round then UDim.new(0.5, 0) else UDim.new(0, 14)
	New("Frame", {
		Name = "Lip",
		BackgroundColor3 = Kit.Darken(color, 0.5),
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = container,
	}, { New("UICorner", { CornerRadius = corner }) })
	local face = New("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 2,
		Parent = container,
	}, { New("UICorner", { CornerRadius = corner }), Kit.Stroke(Kit.Lighten(color, 0.35), 1, 0.6) })
	local quick = TweenInfo.new(0.06, Enum.EasingStyle.Quad)
	face.MouseButton1Down:Connect(function()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, lip - 1) }):Play()
	end)
	local function release()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, 0) }):Play()
	end
	face.MouseButton1Up:Connect(release)
	face.MouseLeave:Connect(release)
	return container, face
end

-- Big raised slab that is itself the button (upgrade cards, shop tiles, quest rows). Sizes
-- by UDim2, so it works inside grids and lists. Returns container (size/position/parent this)
-- and face (put content in it). With onClick the whole face presses down onto its lip.
--   props: Size, Position, AnchorPoint, LayoutOrder, Parent, Lip (px), Corner (px),
--          Outline (Color3), Stroke (thickness)
function Kit.GameCard(color: Color3, props, onClick: (() -> ())?)
	props = props or {}
	local lip = props.Lip or 6
	local radius = UDim.new(0, props.Corner or 16)
	local container = New("Frame", {
		Name = "GameCard",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, 80),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	})
	New("Frame", {
		Name = "Lip",
		BackgroundColor3 = Kit.Darken(color, 0.55),
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 1, -lip),
		Parent = container,
	}, { New("UICorner", { CornerRadius = radius }), Kit.Stroke(props.Outline or T.Outline, props.Stroke or 2, 0) })
	local face = New(if onClick then "TextButton" else "Frame", {
		Name = "Face",
		BackgroundColor3 = color,
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = 2,
		Parent = container,
	}, {
		New("UICorner", { CornerRadius = radius }),
		Kit.Stroke(props.Outline or T.Outline, props.Stroke or 2, 0),
		New("UIGradient", {
			Name = "Bevel",
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		}),
	})
	if onClick then
		local b = face :: TextButton
		b.Text = ""
		b.AutoButtonColor = false
		local quick = TweenInfo.new(0.06, Enum.EasingStyle.Quad)
		local function release()
			TweenService:Create(b, quick, { Position = UDim2.fromOffset(0, 0) }):Play()
		end
		b.MouseButton1Down:Connect(function()
			TweenService:Create(b, quick, { Position = UDim2.fromOffset(0, lip - 2) }):Play()
		end)
		b.MouseButton1Up:Connect(release)
		b.MouseLeave:Connect(release)
		b.Activated:Connect(onClick)
	end
	if props.Parent then
		container.Parent = props.Parent
	end
	return container, face
end

-- Price / action plate inside a GameCard: a solid rounded strip with an icon and a number
-- (the "Buy" part of a whole-card button). Not a button itself: the card is.
function Kit.PricePlate(text: string, color: Color3, iconName: string?, props)
	local plate = New("TextLabel", {
		Name = "Price",
		Text = text,
		Font = T.Title,
		TextSize = 20,
		TextColor3 = Kit.TextOn(color),
		BackgroundColor3 = color,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		ZIndex = 3,
	}, { Kit.Corner(12), Kit.Stroke(T.Outline, 2, 0) })
	local lip = 4
	Kit.Bevel(plate, 40, lip)
	New("UIPadding", { PaddingBottom = UDim.new(0, lip), Parent = plate })
	-- one UIStroke per object (the border), so light text gets the legacy text stroke
	if Kit.TextOn(color) ~= T.DarkText then
		plate.TextStrokeColor3 = T.Outline
		plate.TextStrokeTransparency = 0.35
	end
	for k, v in props or {} do
		(plate :: any)[k] = v
	end
	if iconName and Icon.Has(iconName) then
		Kit.AttachIcon(plate, iconName, nil, math.floor(plate.TextSize * 1.1))
	end
	return plate
end

-- Small rounded tag that sizes to its text. props.Icon = drawn icon name.
function Kit.Pill(text: string, color: Color3, props)
	local p = {
		Text = text,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		TextColor3 = Kit.TextOn(color),
		Font = T.Bold,
		TextSize = 12,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	local iconName = nil
	for k, v in props or {} do
		if k == "Icon" then
			iconName = v
		else
			p[k] = v
		end
	end
	local l = New("TextLabel", p, {
		New("UICorner", { CornerRadius = UDim.new(0, 8) }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
		Kit.Stroke(T.Outline, 1.5, 0.2),
	})
	if iconName and Icon.Has(iconName) then
		Kit.AttachIcon(l, iconName, l.TextColor3, math.floor(l.TextSize * 1.2))
	end
	return l
end

-- Rounded-square tile holding a drawn icon (or a text glyph such as a rarity symbol)
function Kit.IconBadge(icon: string, color: Color3, size: number, props)
	local badge = New("Frame", {
		Name = "IconBadge",
		BackgroundColor3 = Kit.Darken(color, 0.5),
		Size = UDim2.fromOffset(size, size),
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, math.floor(size * 0.3)) }),
		Kit.Stroke(color, if size >= 40 then 2 else 1.5, 0.15),
		New(
			"UIGradient",
			{ Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)) }
		),
	})
	for k, v in props or {} do
		(badge :: any)[k] = v
	end
	local fg = Kit.Lighten(color, 0.15)
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			ZIndex = badge.ZIndex + 1,
			Parent = badge,
		})
	elseif Icon.Has(icon) then
		local s = math.floor(size * 0.62)
		Icon.new(icon, s, fg, {
			Weight = 2.5,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = badge.ZIndex + 1,
			Parent = badge,
		})
	else
		New("TextLabel", {
			BackgroundTransparency = 1,
			Text = icon,
			TextScaled = true,
			Font = T.Title,
			TextColor3 = fg,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			ZIndex = badge.ZIndex + 1,
			Parent = badge,
		})
	end
	return badge
end

-- Chunky tab strip: a dark tray of raised tabs; the selected one lights up in its colour.
-- items = { {id=, text=, icon=?, color=?} }. Returns frame, setSelected(id).
-- props.TabWidth fixes each tab's width (for scrolling tab strips).
function Kit.Tabs(parent: Instance, items, selected: string, onSelect: (string) -> (), props)
	local frame = New("Frame", {
		Name = "Tabs",
		BackgroundColor3 = T.PanelDark,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = parent,
	}, { Kit.Corner(14), Kit.Padding(4), Kit.List(5, true), Kit.Stroke(T.Outline, 2, 0) })
	local width = nil
	for k, v in props or {} do
		if k == "TabWidth" then
			width = v
		else
			(frame :: any)[k] = v
		end
	end
	local buttons = {}
	local function paint(id: string)
		for itemId, b in buttons do
			local on = itemId == id
			local c = b.item.color or T.Accent
			b.button.BackgroundColor3 = if on then c else T.Slab
			b.button.TextColor3 = if on then Kit.TextOn(c) else T.Muted
			b.button.TextStrokeTransparency = if on and Kit.TextOn(c) ~= T.DarkText then 0.45 else 1
			b.stroke.Color = if on then T.Outline else Kit.Darken(T.Slab, 0.4)
			if b.icon then
				Icon.SetColor(b.icon, b.button.TextColor3)
			end
		end
	end
	for i, item in items do
		local hasIcon = item.icon and Icon.Has(item.icon)
		local b = New("TextButton", {
			Text = if item.icon and not hasIcon then `{item.icon} {item.text}` else item.text,
			Font = T.Bold,
			TextSize = 14,
			AutoButtonColor = false,
			BackgroundColor3 = T.Slab,
			TextStrokeColor3 = T.Outline,
			Size = if width then UDim2.new(0, width, 1, 0) else UDim2.new(1 / #items, -5, 1, 0),
			LayoutOrder = i,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		}, { Kit.Corner(10), New("UIPadding", { PaddingBottom = UDim.new(0, 3) }) })
		local stroke = Kit.Stroke(T.Outline, 2, 0)
		stroke.Parent = b
		Kit.Bevel(b, 40, 4)
		local icon = if hasIcon then Kit.AttachIcon(b, item.icon, T.Muted, 17) else nil
		Kit.Juice(b)
		buttons[item.id] = { button = b, item = item, icon = icon, stroke = stroke }
		b.Activated:Connect(function()
			paint(item.id)
			onSelect(item.id)
		end)
	end
	paint(selected)
	return frame, paint
end

-- Window / HUD panel: deep navy body with a thick border (UIController colours it per window)
function Kit.Panel(props, children)
	local p = {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.02,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = New("Frame", p, children)
	Kit.Corner(20).Parent = f
	Kit.Stroke(T.Hairline, 3, 0.1).Parent = f
	return f
end

-- Inner card (rows inside windows): a slab with a thick dark outline. Screens recolour its
-- UIStroke to highlight it (claimable quest, selected item).
function Kit.Card(props, children)
	local p = {
		BackgroundColor3 = T.PanelLight,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = New("Frame", p, children)
	Kit.Corner(14).Parent = f
	Kit.Stroke(T.Outline, 2, 0).Parent = f
	return f
end

-- Section label: outlined display caps in the section colour
function Kit.Header(parent: Instance, order: number, text: string, color: Color3?)
	return Kit.Title({
		Text = string.upper(text),
		TextSize = 17,
		TextColor3 = color or Kit.Lighten(T.Accent, 0.35),
		Size = UDim2.new(1, -8, 0, 30),
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		LayoutOrder = order,
		Parent = parent,
	})
end

function Kit.Scroll(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Accent,
		ScrollBarImageTransparency = 0.4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in props do
		p[k] = v
	end
	return New("ScrollingFrame", p)
end

function Kit.Clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIGridStyleLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

-- Flat progress bar; returns frame and a setter(fraction, color?, text?)
function Kit.Bar(props)
	local frame = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(6, 16, 25),
		Size = props.Size or UDim2.fromOffset(240, 22),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}, { Kit.Round(), Kit.Stroke(T.Outline, 2, 0) })
	-- Fill with a light top half (glossy "liquid" bar)
	local fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or T.Accent,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, {
		Kit.Round(),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(215, 215, 215)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
			}),
		}),
	})
	local label = Kit.Label({
		Text = props.Text or "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 13,
		Font = T.Bold,
		TextStrokeTransparency = 0.25,
		TextStrokeColor3 = T.Outline,
		ZIndex = 3,
		Parent = frame,
	})
	return frame,
		function(fraction: number, color: Color3?, text: string?)
			local f = math.clamp(fraction, 0, 1)
			fill.Visible = f > 0.001
			fill.Size = UDim2.fromScale(f, 1)
			if color then
				fill.BackgroundColor3 = color
			end
			if text then
				label.Text = text
			end
		end
end

return Kit
