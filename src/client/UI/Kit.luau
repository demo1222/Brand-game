-- UI Kit v4: chunky game UI. Pressable buttons with a darker bottom lip, thick dark outlines,
-- outlined display text (FredokaOne), colour-coded slabs and drawn vector icons (UI/Icon)
-- instead of emoji. No dependencies, mobile-first (>= 44 px touch targets). The v1-v3 API is
-- unchanged, so every screen picks up the style.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Icon = require(script.Parent.Icon)
local Icons = require(script.Parent.Icons)

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
		-- glossy face (full colour at the top easing darker) over a darker lip band
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(236, 236, 236)),
			ColorSequenceKeypoint.new(1 - lip - 0.002, Color3.fromRGB(200, 200, 200)),
			ColorSequenceKeypoint.new(1 - lip, Color3.fromRGB(130, 130, 130)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 130, 130)),
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

function Kit.Pop(gui: GuiObject, from: number?, seconds: number?)
	local scale = scaleOf(gui)
	scale.Scale = from or 0.92
	TweenService:Create(scale, TweenInfo.new(seconds or 0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Reverse of Pop: shrink a little (Back in), then run `done` (hide or destroy the object).
-- Windows and modals always leave this way instead of vanishing (docs/UI_STYLE_GUIDE.md).
function Kit.PopOut(gui: GuiObject, done: (() -> ())?, to: number?)
	local scale = scaleOf(gui)
	local info = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(scale, info, { Scale = to or 0.85 })
	tween:Play()
	tween.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed then
			return -- a new Pop took over
		end
		if done then
			done()
		end
		scale.Scale = 1
	end)
end

-- Diagonal stripes over a coloured band (Animal Index title bar). A CanvasGroup clips the
-- rotated stripes to the band's rounded shape. Returns the CanvasGroup.
function Kit.Stripes(parent: GuiObject, props)
	props = props or {}
	local group = New("CanvasGroup", {
		Name = "Stripes",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		GroupTransparency = props.Transparency or 0.86,
		ZIndex = props.ZIndex or parent.ZIndex,
		Parent = parent,
	}, { New("UICorner", { CornerRadius = UDim.new(0, props.Corner or 20) }) })
	local width = props.Width or 22
	local gap = props.Gap or 30
	for i = 0, 60 do
		New("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, i * (width + gap) - 40, 0.5, 0),
			Size = UDim2.new(0, width, 3, 0),
			Rotation = 30,
			Parent = group,
		})
	end
	return group
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

-- Opacity of each layer in a soft glow built from stacked shapes. Layer k is the k-th smallest
-- and covers everything inside it, so what you see in ring k is layers k..n added up. This
-- solves for the layer opacities that make that sum fall smoothly from `peak` in the middle to
-- nothing at the edge. With enough thin layers no step shows; three or four big ones read as a
-- bullseye, not a glow.
local function glowLayers(n: number, peak: number, power: number?): { number }
	local want = table.create(n + 1, 0)
	for k = 1, n do
		want[k] = peak * (1 - (k - 0.5) / n) ^ (power or 2)
	end
	local layers = table.create(n, 0)
	for k = 1, n do
		layers[k] = 1 - (1 - want[k]) / (1 - want[k + 1])
	end
	return layers
end
Kit.GlowLayers = glowLayers

-- Soft radial glow: many thin discs whose opacities add up to a smooth falloff.
-- props.Layers (count) and props.Peak (opacity in the middle, default 0.5) tune it; the other
-- props go on the holder.
function Kit.Glow(parent: Instance, color: Color3, size: number, props)
	local holder = New("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local n, peak = math.clamp(math.floor(size / 9), 8, 18), 0.5
	for k, v in props or {} do
		if k == "Layers" then
			n = v
		elseif k == "Peak" then
			peak = v
		else
			(holder :: any)[k] = v
		end
	end
	for k, alpha in glowLayers(n, peak) do
		New("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 1 - alpha,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(k / n, k / n),
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
-- Button fills: the soft theme colours become the saturated button palette from the Figma
-- "Game Buttons" file (pale mint green -> real green, etc). Text colours keep the theme.
local BUTTON_FILL = {
	{ T.Good, Color3.fromRGB(72, 206, 40) },
	{ T.Bad, Color3.fromRGB(226, 52, 66) },
	{ T.Gold, Color3.fromRGB(255, 178, 32) },
	{ T.Accent, Color3.fromRGB(40, 170, 240) },
}
function Kit.ButtonFill(c: Color3): Color3
	for _, pair in BUTTON_FILL do
		if pair[1] == c then -- Color3 compares by value
			return pair[2]
		end
	end
	return c
end

-- Solid button. props.Icon = drawn icon name shown before the text.
function Kit.Button(text: string, color: Color3?, onClick: (() -> ())?, props)
	local c = Kit.ButtonFill(color or T.Accent)
	local p = {
		Text = text,
		BackgroundColor3 = c,
		TextColor3 = Color3.new(1, 1, 1),
		Font = T.Title,
		TextSize = 17,
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
		Kit.Stroke(T.Outline, 2.5, 0),
	})
	-- Raised block: darker bottom lip, text centred on the face above it
	local h = if b.Size.Y.Scale == 0 then b.Size.Y.Offset else 44
	local lip = math.clamp(math.floor(h * 0.12), 3, 6)
	Kit.Bevel(b, h, lip)
	New("UIPadding", { PaddingBottom = UDim.new(0, lip), Parent = b })
	-- Figma ActionButton look: shine strip + white text with a heavy outline
	Kit.ShineStrip(b)
	Kit.OutlineText(b)
	if iconName and Icon.Has(iconName) then
		Kit.AttachIcon(b, iconName, Color3.new(1, 1, 1))
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
	color = Kit.ButtonFill(color)
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
	}, { New("UICorner", { CornerRadius = corner }), Kit.Stroke(T.Outline, 3, 0) })
	-- face: full colour at the top easing darker, a thick outline and a shine strip
	-- (Figma "Game Buttons" > ActionButton)
	local face = New("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 2,
		Parent = container,
	}, {
		New("UICorner", { CornerRadius = corner }),
		Kit.Stroke(T.Outline, 3, 0),
		New("UIGradient", {
			Name = "Gloss",
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 196)),
		}),
	})
	if not round then
		Kit.ShineStrip(face)
	end
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

-- Thick outlined text on any TextLabel / TextButton (the reference look: white or coloured
-- Fredoka with a heavy black outline). A control can carry only one UIStroke, and its border
-- uses it, so the text is mirrored into a child label that has its own contextual stroke. The
-- control's own text turns invisible but keeps its TextBounds (Kit.AttachIcon reads them).
-- Later changes to Text, TextSize, Font, TextColor3 or alignment follow automatically. Dark
-- "text on bright fill" colours become white: the outline carries the contrast now.
function Kit.OutlineText(control: TextLabel | TextButton, thickness: number?)
	local old = control:FindFirstChild("OutlinedText")
	if old then
		return old :: TextLabel
	end
	local function colorOf(): Color3
		local c = control.TextColor3
		return if c == T.DarkText then Color3.new(1, 1, 1) else c
	end
	local stroke = New("UIStroke", {
		Color = T.Outline,
		Thickness = thickness or math.clamp(control.TextSize / 8, 1.5, 3.5),
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
	local label = New("TextLabel", {
		Name = "OutlinedText",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = control.Text,
		Font = control.Font,
		TextSize = control.TextSize,
		TextScaled = control.TextScaled,
		TextWrapped = control.TextWrapped,
		RichText = control.RichText,
		TextColor3 = colorOf(),
		TextXAlignment = control.TextXAlignment,
		TextYAlignment = control.TextYAlignment,
		TextTruncate = control.TextTruncate,
		ZIndex = control.ZIndex,
		Interactable = false,
		Parent = control,
	}, { stroke })
	control.TextTransparency = 1
	control.TextStrokeTransparency = 1
	for _, prop in { "Text", "Font", "TextScaled", "TextWrapped", "TextXAlignment", "TextYAlignment", "ZIndex" } do
		control:GetPropertyChangedSignal(prop):Connect(function()
			(label :: any)[prop] = (control :: any)[prop]
		end)
	end
	control:GetPropertyChangedSignal("TextSize"):Connect(function()
		label.TextSize = control.TextSize
		if not thickness then
			stroke.Thickness = math.clamp(control.TextSize / 8, 1.5, 3.5)
		end
	end)
	control:GetPropertyChangedSignal("TextColor3"):Connect(function()
		label.TextColor3 = colorOf()
	end)
	-- a caller fading the control's text fades the outlined copy instead
	control:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		if control.TextTransparency < 1 then
			label.TextTransparency = control.TextTransparency
			stroke.Transparency = control.TextTransparency
			control.TextTransparency = 1
		end
	end)
	return label
end

-- White shine strip across the top of a button face (Figma ActionButton "Shine")
function Kit.ShineStrip(gui: GuiObject, transparency: number?)
	local old = gui:FindFirstChild("ShineStrip")
	if old then
		old:Destroy()
	end
	return New("Frame", {
		Name = "ShineStrip",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = transparency or 0.65,
		Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -16, 0.18, 0),
		ZIndex = gui.ZIndex,
		Interactable = false,
		Parent = gui,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

-- Currency / stat readout (reference: icon + big coloured number, no panel). A big glossy
-- icon, then a Fredoka number painted with a light-to-dark gradient and a heavy outline.
--   Kit.Readout(iconName, palette, { IconSize, TextSize, Text, Parent, Position, LayoutOrder,
--                                   AnchorPoint })
--   palette: a Kit.ReadoutColors entry ({ top, bottom }) or a Color3
--   returns frame, icon, label
Kit.ReadoutColors = {
	Coins = { Color3.fromRGB(255, 240, 110), Color3.fromRGB(255, 186, 30) },
	Pearls = { Color3.fromRGB(175, 240, 255), Color3.fromRGB(60, 176, 255) },
	Tokens = { Color3.fromRGB(236, 180, 255), Color3.fromRGB(178, 96, 255) },
	Money = { Color3.fromRGB(236, 255, 90), Color3.fromRGB(176, 238, 40) },
	Good = { Color3.fromRGB(200, 255, 130), Color3.fromRGB(110, 226, 70) },
	White = { Color3.new(1, 1, 1), Color3.fromRGB(220, 228, 240) },
	Bad = { Color3.fromRGB(255, 150, 140), Color3.fromRGB(240, 70, 70) },
}
function Kit.ReadoutPaint(label: TextLabel, palette)
	local top, bottom
	if typeof(palette) == "Color3" then
		top, bottom = Kit.Lighten(palette, 0.35), palette
	else
		top, bottom = palette[1], palette[2]
	end
	local g = label:FindFirstChild("Paint") :: UIGradient?
		or New("UIGradient", { Name = "Paint", Rotation = 90, Parent = label })
	g.Color = ColorSequence.new(top, bottom)
	label.TextColor3 = Color3.new(1, 1, 1)
end
function Kit.Readout(iconName: string, palette, props)
	props = props or {}
	local textSize = props.TextSize or 30
	local iconSize = props.IconSize or math.floor(textSize * 1.45)
	local frame = New("Frame", {
		Name = props.Name or "Readout",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, iconSize),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, math.floor(textSize * 0.25)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- uploaded icon images carry transparent padding, so draw them larger than the slot
	local drawn = if string.sub(iconName, 1, 13) == "rbxassetid://" then math.floor(iconSize * 1.3) else iconSize
	local slot = New("Frame", {
		Name = "IconSlot",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(iconSize, iconSize),
		LayoutOrder = 1,
		Parent = frame,
	})
	local icon = Icon.new(iconName, drawn, props.IconColor or Color3.new(1, 1, 1), {
		Weight = 2.8,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = slot,
	})
	local label = New("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Text = props.Text or "0",
		Font = T.Title,
		TextSize = textSize,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, iconSize),
		LayoutOrder = 2,
		Parent = frame,
	}, {
		New("UIStroke", {
			Color = T.Outline,
			Thickness = math.max(2, textSize / 8),
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
	Kit.ReadoutPaint(label, palette)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame, icon, label
end

-- HUD tile, neon style (Figma "Abyss Salvage - Game Buttons" > NeonTile; owner reference
-- docs/reference/hud_buttons, 2026-11-16): a dark rounded tile tinted by its colour, a thick
-- neon border in that colour (light top, darker bottom) with a soft glow round it and a thin
-- dark ring outside, a big icon, and a white Fredoka label with a heavy outline sitting on the
-- tile's lower edge. Extras: a hotkey letter at the top right (keyboard only), a red count badge
-- at the top left, and a tilted red "New!" style tag. Highlight = a light band turns slowly
-- round the border (the one button to notice, e.g. Shop). The whole thing is the button: it
-- grows on hover (the glow brightens), squashes on press and bounces back on release.
--   Kit.HudTile(iconName, label, { Size = 64, Color = Color3?, Highlight = bool, IconColor = Color3?,
--                                  Key = "B"?, Badge = "3"?, Tag = "New!"?,
--                                  LayoutOrder, Position, AnchorPoint, Parent, Name })
--   returns button (TextButton), tile (Frame: put extras here), icon, label
--   Kit.HudTileBadge(button, value?) shows a count ("3", "!") on the badge, or hides it (nil)
Kit.HudTileColors = {
	Default = Color3.fromRGB(150, 175, 210),
	Ring = Color3.fromRGB(14, 11, 26),
	Badge = Color3.fromRGB(235, 30, 45),
	Tag = Color3.fromRGB(255, 40, 70),
}
local UserInputService = game:GetService("UserInputService")
function Kit.HudTile(iconName: string, label: string, props)
	props = props or {}
	local size = props.Size or 64
	local C = Kit.HudTileColors
	local color: Color3 = props.Color or props.IconColor or C.Default
	local labelSize = math.floor(size * 0.3)
	local overlap = math.floor(labelSize * 0.55) -- room under the tile for the label's lower half
	local border = math.max(3, math.floor(size / 15))
	local button = New("TextButton", {
		Name = props.Name or label,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size + 10, size + overlap + 4),
		LayoutOrder = props.LayoutOrder or 0,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
	})
	local press = New("UIScale", { Name = "Press", Parent = button })
	local black = Color3.new(0, 0, 0)
	local white = Color3.new(1, 1, 1)
	-- the glow: the neon border's light spilling outwards. Thin rounded layers, one pixel apart,
	-- starting just outside the dark ring; their opacities add up to a smooth falloff (two big
	-- see-through squares looked like a second, blocky border). `lit` holds every glow layer and
	-- its resting opacity, so hover can brighten them all.
	local lit: { { frame: Frame, alpha: number } } = {}
	local HALO, RING = 7, 2
	for k, alpha in glowLayers(HALO, 0.5, 1.5) do
		local grow = RING + k -- layer 1 is the smallest: every layer covers it, so it is the brightest ring
		local halo = New("Frame", {
			Name = "Glow" .. k,
			BackgroundColor3 = color:Lerp(white, 0.1),
			BackgroundTransparency = 1 - alpha,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 4 + size / 2),
			Size = UDim2.fromOffset(size + grow * 2, size + grow * 2),
			ZIndex = 1,
			Parent = button,
		}, { New("UICorner", { CornerRadius = UDim.new(0, math.floor(size * 0.2) + grow) }) })
		table.insert(lit, { frame = halo, alpha = alpha })
	end
	local tile = New("Frame", {
		Name = "Tile",
		BackgroundColor3 = white,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 2,
		Parent = button,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
		-- dark body tinted with the colour, a little lighter at the top
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(black, 0.72), color:Lerp(black, 0.9)) }),
		-- the thin dark ring outside the neon border
		New("UIStroke", { Color = C.Ring, Thickness = 2 }),
	})
	-- the neon border: a frame just inside the tile carrying a thick gradient stroke
	local rim = New("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(border / 2, border / 2),
		Size = UDim2.new(1, -border, 1, -border),
		ZIndex = 2,
		Parent = tile,
	}, { New("UICorner", { CornerRadius = UDim.new(0.18, 0) }) })
	local rimStroke = New("UIStroke", { Color = white, Thickness = border, LineJoinMode = Enum.LineJoinMode.Round, Parent = rim })
	local rimGradient = New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(white, 0.45)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, color:Lerp(black, 0.25)),
		}),
		Parent = rimStroke,
	})
	if props.Highlight then
		rimGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(black, 0.2)),
			ColorSequenceKeypoint.new(0.42, color),
			ColorSequenceKeypoint.new(0.5, white),
			ColorSequenceKeypoint.new(0.58, color),
			ColorSequenceKeypoint.new(1, color:Lerp(black, 0.2)),
		})
		TweenService:Create(rimGradient, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 450 }):Play()
	end
	-- the icon: every image icon gets the same visible size (ICON_ART of the tile), and its art,
	-- not its image, is centred in the space above the label. Icons.ArtBox holds each image's
	-- measured art box; drawn vector icons have no padding and sit at 62%.
	local isImage = string.sub(iconName, 1, 13) == "rbxassetid://"
	local ICON_ART, ICON_Y = 0.66, 0.42
	local box = if isImage then Icons.ArtBox[iconName] else nil
	local iconPx = if isImage then size * ICON_ART / (if box then box[3] else 0.62) else size * 0.62
	local ox = if box then -box[1] * iconPx else 0
	local oy = if box then -box[2] * iconPx else 0
	-- the border's light spilling inwards too: a few one-pixel lines just inside it, fading out
	local inset = math.ceil(border / 2) -- the border's inner edge
	for j, alpha in { 0.34, 0.2, 0.1, 0.04 } do
		New("Frame", {
			Name = "InnerGlow" .. j,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(inset + j, inset + j),
			Size = UDim2.new(1, -(inset + j) * 2, 1, -(inset + j) * 2),
			ZIndex = 2,
			Parent = tile,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(size * 0.18) - inset - j)) }),
			New("UIStroke", { Color = color:Lerp(white, 0.1), Thickness = 1, Transparency = 1 - alpha }),
		})
	end
	-- a soft light in the tile's colour behind the icon: thin discs that add up to a smooth
	-- falloff, bright behind the icon and gone before the border
	local glowImg = New("Frame", {
		Name = "IconGlow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, ICON_Y),
		Size = UDim2.fromOffset(size * 0.92, size * 0.92),
		ZIndex = 2,
		Parent = tile,
	})
	local DISCS = 10
	for k, alpha in glowLayers(DISCS, 0.5) do
		local disc = New("Frame", {
			Name = "Disc" .. k,
			BackgroundColor3 = color:Lerp(white, 0.3),
			BackgroundTransparency = 1 - alpha,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(k / DISCS, k / DISCS),
			ZIndex = 2,
			Parent = glowImg,
		}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		table.insert(lit, { frame = disc, alpha = alpha })
	end
	local icon = Icon.new(iconName, math.floor(iconPx), props.IconColor or color, {
		Weight = 2.8,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, ox, ICON_Y, oy),
		ZIndex = 3,
		Parent = tile,
	})
	local function outlined(name: string, str: string, textSize: number, textColor: Color3, extra)
		local l = New("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Text = str,
			Font = T.Title,
			TextSize = textSize,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.fromOffset(textSize * 2, textSize + 4),
			ZIndex = 7,
			Parent = button,
		}, {
			New("UIStroke", {
				Color = C.Ring,
				Thickness = math.max(2, textSize / 6),
				LineJoinMode = Enum.LineJoinMode.Round,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		})
		for k, v in extra do
			(l :: any)[k] = v
		end
		return l
	end
	local text = outlined("Label", label, labelSize, white, {
		ZIndex = 5,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 4 + size + math.floor(labelSize * 0.3)),
		Size = UDim2.new(1, 16, 0, labelSize + 4),
	})
	-- the hotkey letter, hanging off the top-right corner (keyboard players only)
	if props.Key and UserInputService.KeyboardEnabled then
		outlined("Key", props.Key, math.floor(size * 0.3), white, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, size / 2 - 1, 0, 6),
		})
	end
	-- the tilted tag ("New!")
	if props.Tag then
		outlined("Tag", props.Tag, math.floor(size * 0.24), C.Tag, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 4 + size * 0.2),
			Rotation = 8,
		})
	end
	-- the count badge at the top-left corner (Kit.HudTileBadge shows or hides it)
	local bs = math.max(16, math.floor(size * 0.3))
	local badge = New("Frame", {
		Name = "Badge",
		BackgroundColor3 = C.Badge,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -size / 2 + 3, 0, 7),
		Size = UDim2.fromOffset(bs, bs),
		Visible = false,
		ZIndex = 8,
		Parent = button,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = white, Thickness = 2 }),
		New("TextLabel", {
			Name = "Count",
			BackgroundTransparency = 1,
			Text = "",
			Font = T.Title,
			TextSize = math.floor(bs * 0.7),
			TextColor3 = white,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
		}),
	})
	if props.Badge then
		Kit.HudTileBadge(button, props.Badge)
	end
	-- hover: grow and brighten the glow; press: squash; release: bounce back with an overshoot
	local down = TweenInfo.new(0.07, Enum.EasingStyle.Quad)
	local up = TweenInfo.new(0.28, Enum.EasingStyle.Back)
	local hovering = false
	local function glow(on: boolean)
		local boost = if on then 1.7 else 1
		for _, l in lit do
			TweenService:Create(l.frame, down, { BackgroundTransparency = 1 - math.min(l.alpha * boost, 0.9) }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		hovering = true
		glow(true)
		TweenService:Create(press, down, { Scale = 1.06 }):Play()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		glow(false)
		TweenService:Create(press, up, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(press, down, { Scale = 0.88 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(press, up, { Scale = if hovering then 1.06 else 1 }):Play()
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button, tile, icon, text
end

function Kit.HudTileBadge(button: Instance, value: (string | number)?)
	local badge = button:FindFirstChild("Badge")
	if not badge or not badge:IsA("Frame") then
		return
	end
	if value == nil then
		badge.Visible = false
		return
	end
	local count = badge:FindFirstChild("Count")
	if count and count:IsA("TextLabel") then
		count.Text = tostring(value)
	end
	if not badge.Visible then
		badge.Visible = true
		Kit.Pop(badge, 0.3, 0.25)
	end
end

-- Action / price button (Figma "Abyss Salvage - Game Buttons" > ActionButton): gradient face
-- (lighter top), 3 px outline, a white shine strip, a darker lip under it, an optional icon and
-- a Fredoka value with an outline. Colours: Green (buy/go), Blue (equip/info), Red (close/
-- danger), Gold (price highlight), Grey (locked), Dark (done/equipped).
--   Kit.ActionButton(text, colorName, onClick?, { Size, Icon, TextSize, Position, AnchorPoint,
--                                                LayoutOrder, ZIndex, Parent })
--   returns container (Frame), face (TextButton), label
Kit.ActionColors = {
	Green = { Color3.fromRGB(155, 255, 60), Color3.fromRGB(60, 200, 30), Color3.fromRGB(34, 122, 18) },
	Blue = { Color3.fromRGB(95, 208, 255), Color3.fromRGB(45, 123, 239), Color3.fromRGB(26, 74, 153) },
	Red = { Color3.fromRGB(255, 107, 107), Color3.fromRGB(224, 43, 60), Color3.fromRGB(138, 21, 34) },
	Gold = { Color3.fromRGB(255, 228, 92), Color3.fromRGB(255, 164, 27), Color3.fromRGB(168, 95, 6) },
	Grey = { Color3.fromRGB(154, 163, 178), Color3.fromRGB(94, 102, 117), Color3.fromRGB(54, 60, 71) },
	Dark = { Color3.fromRGB(70, 76, 90), Color3.fromRGB(44, 48, 58), Color3.fromRGB(24, 26, 32) },
}
function Kit.ActionButton(text: string, colorName: string | Color3, onClick: (() -> ())?, props)
	props = props or {}
	-- a named palette, or any Color3 (lighter top, the colour, a dark lip)
	local pal = if typeof(colorName) == "Color3"
		then { Kit.Lighten(colorName, 0.3), colorName, Kit.Darken(colorName, 0.45) }
		else Kit.ActionColors[colorName] or Kit.ActionColors.Grey
	local lip = 6
	local z = props.ZIndex or 3
	local container = New("Frame", {
		Name = "ActionButton",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(200, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = z,
	})
	New("Frame", {
		Name = "Lip",
		BackgroundColor3 = pal[3],
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = z,
		Parent = container,
	}, { Kit.Corner(14), Kit.Stroke(T.Outline, 3, 0) })
	local face = New("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = z + 1,
		Parent = container,
	}, {
		Kit.Corner(14),
		Kit.Stroke(T.Outline, 3, 0),
		New("UIGradient", { Rotation = 90, Color = ColorSequence.new(pal[1], pal[2]) }),
	})
	New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.62,
		Position = UDim2.new(0, 10, 0, 5),
		Size = UDim2.new(1, -20, 0.2, 0),
		ZIndex = z + 2,
		Parent = face,
	}, { Kit.Round() })
	local row = New("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = face,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local textSize = props.TextSize or 24
	if props.Icon and Icon.Has(props.Icon) then
		Icon.new(props.Icon, math.floor(textSize * 1.15), Color3.new(1, 1, 1), {
			Weight = 3,
			LayoutOrder = 1,
			ZIndex = z + 3,
			Parent = row,
		})
	end
	local label = New("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Text = text,
		Font = T.Title,
		TextSize = textSize,
		TextColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		ZIndex = z + 3,
		Parent = row,
	}, {
		New("UIStroke", {
			Color = T.Outline,
			Thickness = math.max(2, textSize / 9),
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),
	})
	local quick = TweenInfo.new(0.06, Enum.EasingStyle.Quad)
	local function release()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, 0) }):Play()
	end
	face.MouseButton1Down:Connect(function()
		TweenService:Create(face, quick, { Position = UDim2.fromOffset(0, lip - 1) }):Play()
	end)
	face.MouseButton1Up:Connect(release)
	face.MouseLeave:Connect(release)
	if onClick then
		face.Activated:Connect(onClick)
	else
		face.Active = false
	end
	if props.Parent then
		container.Parent = props.Parent
	end
	return container, face, label
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
	color = Kit.ButtonFill(color)
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
	plate.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props or {} do
		(plate :: any)[k] = v
	end
	-- Figma ActionButton look: shine strip + white text with a heavy outline (a dark text
	-- colour from older callers turns white; muted greys stay grey)
	Kit.ShineStrip(plate)
	Kit.OutlineText(plate)
	if iconName and Icon.Has(iconName) then
		Kit.AttachIcon(plate, iconName, Color3.new(1, 1, 1), math.floor(plate.TextSize * 1.1))
	end
	return plate
end

-- Small rounded tag that sizes to its text. props.Icon = drawn icon name.
function Kit.Pill(text: string, color: Color3, props)
	local p = {
		Text = text,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		TextColor3 = Color3.new(1, 1, 1),
		Font = T.Title,
		TextSize = 13,
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
		Kit.Stroke(T.Outline, 2, 0),
		-- glossy: full colour at the top easing a little darker
		New("UIGradient", {
			Name = "Gloss",
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		}),
	})
	-- reference look: white text with a heavy outline (dark text from older callers turns white)
	Kit.OutlineText(l)
	if iconName and Icon.Has(iconName) then
		Kit.AttachIcon(l, iconName, Color3.new(1, 1, 1), math.floor(l.TextSize * 1.25))
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

-- Tab strip in the reference (Animal Index) style: a dark outlined tray of chunky tabs. The
-- selected tab is a bright glossy slab in its colour with a shine strip and white outlined
-- text, and it bounces when picked; the others are dark slate with dimmer outlined text and
-- their icon in its own colour, so the colour coding stays readable.
-- items = { {id=, text=, icon=?, color=?} }. Returns frame, setSelected(id).
-- props.TabWidth fixes each tab's width (for scrolling tab strips).
local TAB_IDLE = Color3.fromRGB(44, 50, 66)
local TAB_IDLE_TEXT = Color3.fromRGB(196, 206, 224)
function Kit.Tabs(parent: Instance, items, selected: string, onSelect: (string) -> (), props)
	local frame = New("Frame", {
		Name = "Tabs",
		BackgroundColor3 = T.PanelDark,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = parent,
	}, { Kit.Corner(14), Kit.Padding(4), Kit.List(5, true), Kit.Stroke(T.Outline, 3, 0) })
	local width = nil
	for k, v in props or {} do
		if k == "TabWidth" then
			width = v
		else
			(frame :: any)[k] = v
		end
	end
	local buttons = {}
	local current: string? = nil
	local function paint(id: string)
		for itemId, b in buttons do
			local on = itemId == id
			local c = Kit.ButtonFill(b.item.color or T.Accent)
			b.button.BackgroundColor3 = if on then c else TAB_IDLE
			b.button.TextColor3 = if on then Color3.new(1, 1, 1) else TAB_IDLE_TEXT
			b.shine.Visible = on
			if b.icon then
				Icon.SetColor(b.icon, if on then Color3.new(1, 1, 1) else Kit.Lighten(c, 0.15))
			end
			if on and current ~= id then
				Kit.Pop(b.button, 0.88, 0.25)
			end
		end
		current = id
	end
	for i, item in items do
		local hasIcon = item.icon and Icon.Has(item.icon)
		local b = New("TextButton", {
			Text = if item.icon and not hasIcon then `{item.icon} {item.text}` else item.text,
			Font = T.Title,
			TextSize = 15,
			AutoButtonColor = false,
			BackgroundColor3 = TAB_IDLE,
			Size = if width then UDim2.new(0, width, 1, 0) else UDim2.new(1 / #items, -5, 1, 0),
			LayoutOrder = i,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		}, { Kit.Corner(10), New("UIPadding", { PaddingBottom = UDim.new(0, 4) }) })
		Kit.Stroke(T.Outline, 2.5, 0).Parent = b
		Kit.Bevel(b, 40, 5)
		local shine = Kit.ShineStrip(b, 0.6)
		Kit.OutlineText(b)
		local icon = if hasIcon then Kit.AttachIcon(b, item.icon, T.Muted, 20) else nil
		Kit.Juice(b)
		buttons[item.id] = { button = b, item = item, icon = icon, shine = shine }
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

------------------------------------------------------------------------------------------
-- Clean window kit (owner reference: docs/reference/shop_upgrades, 2026-11-16)
-- Black panels with one bright colour per window, flat tabs, and gradient cards with a thin
-- bright border: the name on top, a big icon, the price along the bottom. The whole card is
-- the button. Nothing here is rotated: rotated objects ignore a ScrollingFrame's clipping.
------------------------------------------------------------------------------------------
Kit.Clean = {
	Panel = Color3.fromRGB(15, 16, 20), -- window body
	PanelPlain = Color3.fromRGB(23, 24, 29), -- window body with no colour band (Settings)
	Well = Color3.fromRGB(25, 26, 33), -- the area lists and grids sit in
	Row = Color3.fromRGB(31, 32, 39), -- a row inside a well
	RowEdge = Color3.fromRGB(45, 46, 56),
	Ink = Color3.fromRGB(11, 11, 16), -- text and button outlines
	Sub = Color3.fromRGB(150, 153, 168), -- the small grey line under a title
	Go = Color3.fromRGB(124, 255, 77), -- a price you can pay, "Owned!", "Upgrade!"
	Off = Color3.fromRGB(169, 177, 194), -- a price you can't pay yet
	Tag = Color3.fromRGB(255, 45, 70), -- "Best value!" tags
	Gold = Color3.fromRGB(255, 210, 63),
}
local CL = Kit.Clean
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

-- Fredoka text with a heavy outline (no box behind it). props.Outline = thickness, or false for
-- none; props.OutlineColor; every other prop goes on the label.
function Kit.Text(text: string, size: number, props)
	local p = {
		Name = "Text",
		BackgroundTransparency = 1,
		Text = text,
		Font = T.Title,
		TextSize = size,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
		Size = UDim2.new(1, 0, 0, size + 6),
	}
	local outline: any, outlineColor = nil, CL.Ink
	for k, v in props or {} do
		if k == "Outline" then
			outline = v
		elseif k == "OutlineColor" then
			outlineColor = v
		else
			p[k] = v
		end
	end
	local label = New("TextLabel", p)
	if outline ~= false then
		New("UIStroke", {
			Color = outlineColor,
			Thickness = outline or math.clamp(size / 7, 2, 4),
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	return label
end

-- An icon that fills its holder. Uploaded images scale with the holder; drawn icons can't, so
-- they are built at `px` and centred. Returns the holder (props go on it).
function Kit.IconFill(icon: string, color: Color3, px: number, props)
	local holder = New("Frame", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(px, px) })
	for k, v in props or {} do
		if k ~= "Parent" then
			(holder :: any)[k] = v
		end
	end
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		-- the images carry different amounts of empty margin: size and place each one by its
		-- measured art (Icons.ArtBox), so every icon's visible art fills the holder
		local box = Icons.ArtBox[icon]
		local k = 0.94 / (if box then box[3] else 0.62)
		New("ImageLabel", {
			Name = "Image",
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 - (if box then box[1] else 0) * k, 0.5 - (if box then box[2] else 0) * k),
			Size = UDim2.fromScale(k, k),
			ZIndex = holder.ZIndex + 1,
			Parent = holder,
		})
	elseif Icon.Has(icon) then
		Icon.new(icon, px, color, {
			Weight = 2.6,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = holder.ZIndex + 1,
			Parent = holder,
		})
	end
	if props and props.Parent then
		holder.Parent = props.Parent
	end
	return holder
end

-- Title band whose right end is cut on a slant (its top edge runs further than its bottom
-- edge). A dark copy behind is the outline and the lip under the band; the face on top carries
-- the colours, left to right. The slanted end is its own piece: its gradient turns see-through
-- across its diagonal. props: Position, Size (X any, Y = height), Colors { c1, c2, c3 },
-- Height, Slant, ZIndex, Parent. Returns the holder (put the title in it).
function Kit.SlantBand(parent: Instance, props)
	local h = props.Height or 58
	local slant = props.Slant or 28
	local z = props.ZIndex or 3
	local colors = props.Colors
	local holder = New("Frame", {
		Name = "TitleBand",
		BackgroundTransparency = 1,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.new(1, 0, 0, h),
		ZIndex = z,
		Parent = parent,
	})
	local angle = math.deg(math.atan2(slant, h))
	local cut = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.49, 0),
		NumberSequenceKeypoint.new(0.51, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- one layer: a rounded body, a filler that squares off its right corners, and the slanted
	-- end. `top` and `height` place it; the slant meets the bottom edge at `xb` and the top edge
	-- at `xt` (both measured from the holder's right edge).
	local function layer(name: string, left: number, top: number, height: number, xb: number, xt: number, radius: number, endColor: Color3, paint: ColorSequence?)
		local body = New("Frame", {
			Name = name,
			BackgroundColor3 = if paint then WHITE else endColor,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(left, top),
			Size = UDim2.new(1, xb - left, 0, height),
			ZIndex = z,
			Parent = holder,
		}, { New("UICorner", { CornerRadius = UDim.new(0, radius) }) })
		if paint then
			New("UIGradient", { Color = paint, Parent = body })
		end
		New("Frame", {
			Name = name .. "Square",
			BackgroundColor3 = endColor,
			BorderSizePixel = 0,
			Position = UDim2.new(1, xb - radius - 2, 0, top),
			Size = UDim2.fromOffset(radius + 2, height),
			ZIndex = z,
			Parent = holder,
		})
		New("Frame", {
			Name = name .. "End",
			BackgroundColor3 = endColor,
			BorderSizePixel = 0,
			Position = UDim2.new(1, xb, 0, top),
			Size = UDim2.fromOffset(xt - xb, height),
			ZIndex = z,
			Parent = holder,
		}, { New("UIGradient", { Rotation = angle, Transparency = cut }) })
	end
	-- the outline: 3 px bigger all round, 4 px more below (the lip), its slant pushed out to match
	local o, lip = 3, 4
	local tall = h + o * 2 + lip
	local xt = math.round(o * math.sqrt(1 + (slant / h) ^ 2) + (slant / h) * o)
	local wide = math.round((slant / h) * tall)
	layer("Outline", -o, -o, tall, xt - wide, xt, 13, CL.Ink, nil)
	layer(
		"Face",
		0,
		0,
		h,
		-slant,
		0,
		10,
		colors[3],
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(0.5, colors[2]),
			ColorSequenceKeypoint.new(0.94, colors[3]),
			ColorSequenceKeypoint.new(1, colors[3]),
		})
	)
	return holder
end

-- Three colours for a window's title band from its one colour: a neighbour hue on each side,
-- pushed to full brightness, so every window gets a lively left-to-right sweep.
function Kit.BandColors(color: Color3): { Color3 }
	local hue, sat, _ = color:ToHSV()
	sat = math.max(sat, 0.72)
	return {
		Color3.fromHSV((hue + 0.05) % 1, sat * 0.9, 1),
		Color3.fromHSV(hue, sat, 1),
		Color3.fromHSV((hue - 0.11) % 1, sat, 1),
	}
end

-- Gradient card with a thin bright border (the reference shop tile): dark at the top, its
-- colour at the bottom. With onClick the whole card is the button: it grows a little on hover
-- and squashes on press. Returns container (size, position and parent this) and card (put the
-- content in it).
--   props: Size, Position, AnchorPoint, LayoutOrder, Parent, Corner, Sideways (the colour runs
--          left to right instead: wide hero cards), Name
function Kit.NeonCard(color: Color3, props, onClick: (() -> ())?)
	props = props or {}
	local container = New("Frame", {
		Name = props.Name or "NeonCard",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(160, 180),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	})
	local fill = if props.Sideways
		then ColorSequence.new(color:Lerp(BLACK, 0.5), color:Lerp(BLACK, 0.82))
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(BLACK, 0.8)),
			ColorSequenceKeypoint.new(0.5, color:Lerp(BLACK, 0.55)),
			ColorSequenceKeypoint.new(1, color:Lerp(BLACK, 0.12)),
		})
	local card = New(if onClick then "TextButton" else "Frame", {
		Name = "Card",
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = container,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, props.Corner or 18) }),
		New("UIGradient", { Name = "Fill", Rotation = if props.Sideways then 0 else 90, Color = fill }),
	})
	New("UIStroke", {
		Name = "Edge",
		Color = WHITE,
		Thickness = 2.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = card,
	}, { New("UIGradient", { Rotation = 90, Color = ColorSequence.new(color:Lerp(WHITE, 0.5), color) }) })
	if onClick then
		local b = card :: TextButton
		b.Text = ""
		b.AutoButtonColor = false
		local press = New("UIScale", { Name = "Press", Parent = b })
		local down = TweenInfo.new(0.07, Enum.EasingStyle.Quad)
		local up = TweenInfo.new(0.24, Enum.EasingStyle.Back)
		local hovering = false
		b.MouseEnter:Connect(function()
			hovering = true
			TweenService:Create(press, down, { Scale = 1.03 }):Play()
		end)
		b.MouseLeave:Connect(function()
			hovering = false
			TweenService:Create(press, up, { Scale = 1 }):Play()
		end)
		b.MouseButton1Down:Connect(function()
			TweenService:Create(press, down, { Scale = 0.95 }):Play()
		end)
		b.MouseButton1Up:Connect(function()
			TweenService:Create(press, up, { Scale = if hovering then 1.03 else 1 }):Play()
		end)
		b.Activated:Connect(onClick)
	end
	if props.Parent then
		container.Parent = props.Parent
	end
	return container, card
end

-- A word above a card's top edge ("Best value!"): bright text with a white outline.
function Kit.CardTag(card: Instance, text: string, color: Color3?, props)
	local p = {
		Name = "Tag",
		TextColor3 = color or CL.Tag,
		OutlineColor = WHITE,
		Outline = 2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -3),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 6,
		Parent = card,
	}
	for k, v in props or {} do
		p[k] = v
	end
	return Kit.Text(text, 17, p)
end

-- Shop card. Small (default): name, big icon, price. Wide: icon on the left, name and what you
-- get beside it, price along the bottom. Sizes come from the grid cell.
--   Kit.ShopCard({ Name, Sub?, Desc?, Icon, Price, Color, PriceColor?, Tag?, TagColor?, Owned?,
--                  Wide?, OnClick, LayoutOrder, Parent })
--   returns container, card
function Kit.ShopCard(o)
	local color: Color3 = o.Color
	local container, card = Kit.NeonCard(color, { Name = o.Name, LayoutOrder = o.LayoutOrder, Parent = o.Parent }, o.OnClick)
	local iconColor = color:Lerp(WHITE, 0.55)
	local function icon(props)
		local holder = Kit.IconFill(o.Icon or "star", iconColor, if o.Wide then 64 else 84, props)
		Kit.Glow(holder, color:Lerp(WHITE, 0.45), 10, {
			Size = UDim2.fromScale(1.35, 1.35),
			Layers = 12,
			Peak = 0.42,
			ZIndex = holder.ZIndex,
		})
		return holder
	end
	if o.Wide then
		icon({ Position = UDim2.fromOffset(9, 10), Size = UDim2.fromOffset(78, 78), ZIndex = 2, Parent = card })
		local name = Kit.Text(o.Name, 18, {
			Name = "Name",
			Position = UDim2.fromOffset(90, 8),
			Size = UDim2.new(1, -98, 0, 24),
			TextScaled = true,
			ZIndex = 3,
			Parent = card,
		})
		New("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11, Parent = name })
		local desc = New("TextLabel", {
			Name = "Desc",
			BackgroundTransparency = 1,
			Text = o.Desc or "",
			Font = T.Font,
			TextColor3 = WHITE,
			TextTransparency = 0.08,
			TextScaled = true,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(90, 34),
			Size = UDim2.new(1, -98, 1, -76),
			ZIndex = 3,
			Parent = card,
		})
		New("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 9, Parent = desc })
	else
		local name = Kit.Text(o.Name, 17, {
			Name = "Name",
			Position = UDim2.fromOffset(6, 7),
			Size = UDim2.new(1, -12, 0, if o.Sub then 22 else 38),
			TextScaled = true,
			TextWrapped = true,
			ZIndex = 3,
			Parent = card,
		})
		New("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 10, Parent = name })
		if o.Sub then
			New("TextLabel", {
				Name = "Sub",
				BackgroundTransparency = 1,
				Text = o.Sub,
				Font = T.Bold,
				TextSize = 11,
				TextColor3 = color:Lerp(WHITE, 0.7),
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(6, 29),
				Size = UDim2.new(1, -12, 0, 14),
				ZIndex = 3,
				Parent = card,
			})
		end
		local holder = icon({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 4),
			Size = UDim2.new(1, -40, 1, -92),
			ZIndex = 2,
			Parent = card,
		})
		New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = holder })
	end
	local price = Kit.Text(o.Price, 25, {
		Name = "Price",
		TextColor3 = o.PriceColor or WHITE,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 32),
		TextScaled = true,
		ZIndex = 3,
		Parent = card,
	})
	New("UITextSizeConstraint", { MaxTextSize = 25, MinTextSize = 12, Parent = price })
	if o.Tag then
		Kit.CardTag(card, o.Tag, o.TagColor)
	end
	if o.Owned then
		local cover = New("Frame", {
			Name = "Owned",
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.38,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 7,
			Parent = card,
		}, { New("UICorner", { CornerRadius = UDim.new(0, 18) }) })
		local word = Kit.Text("Owned!", 34, {
			TextColor3 = CL.Go,
			Outline = 4,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -10, 0, 44),
			TextScaled = true,
			ZIndex = 8,
			Parent = cover,
		})
		New("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 16, Parent = word })
	end
	return container, card
end

-- Flat tab strip: small coloured slabs, the picked one bright with a white edge, the others
-- dark versions of their own colour. items = { { id, text, color } }. Returns frame, paint(id).
function Kit.FlatTabs(parent: Instance, items, selected: string, onSelect: (string) -> (), props)
	local frame = New("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 38),
		Parent = parent,
	}, {
		New("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		New("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }),
	})
	for k, v in props or {} do
		(frame :: any)[k] = v
	end
	local tabs = {}
	local current: string? = nil
	local function paint(id: string)
		for itemId, t in tabs do
			local on = itemId == id
			local c: Color3 = t.color
			t.gradient.Color = if on
				then ColorSequence.new(c:Lerp(WHITE, 0.35), c)
				else ColorSequence.new(c:Lerp(BLACK, 0.36), c:Lerp(BLACK, 0.55))
			t.stroke.Color = if on then WHITE else CL.Ink
			t.label.TextTransparency = if on then 0 else 0.15
			if on and current ~= id then
				Kit.Pop(t.button, 0.88, 0.22)
			end
		end
		current = id
	end
	for i, item in items do
		local b = New("TextButton", {
			Name = item.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = WHITE,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			LayoutOrder = i,
			Parent = frame,
		}, {
			New("UICorner", { CornerRadius = UDim.new(0, 9) }),
			New("UIPadding", { PaddingLeft = UDim.new(0, 15), PaddingRight = UDim.new(0, 15) }),
		})
		local gradient = New("UIGradient", { Rotation = 90, Parent = b })
		local stroke = New("UIStroke", {
			Color = CL.Ink,
			Thickness = 2.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = b,
		})
		local label = Kit.Text(item.text, 17, {
			Name = "Label",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, -2),
			Parent = b,
		})
		tabs[item.id] = { button = b, color = Kit.ButtonFill(item.color or T.Accent), gradient = gradient, stroke = stroke, label = label }
		b.Activated:Connect(function()
			paint(item.id)
			onSelect(item.id)
		end)
	end
	paint(selected)
	return frame, paint
end

-- The dark rounded area a window's list or grid sits in. Returns the frame.
function Kit.Well(props)
	local p = { Name = "Well", BackgroundColor3 = CL.Well, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }
	for k, v in props or {} do
		p[k] = v
	end
	return New("Frame", p, { New("UICorner", { CornerRadius = UDim.new(0, 12) }) })
end

-- Centred section name inside a list ("Sound", "Dive Gear")
function Kit.SectionTitle(parent: Instance, order: number, text: string)
	return Kit.Text(text, 24, {
		Name = "Section",
		TextColor3 = Color3.fromRGB(238, 238, 244),
		Outline = 3,
		Size = UDim2.new(1, -8, 0, 36),
		LayoutOrder = order,
		Parent = parent,
	})
end

-- Settings row: a dark rounded row with a bold title and a small grey line under it. Controls
-- go on its right; `reserve` is the width kept free for them. Returns the row.
function Kit.SettingRow(parent: Instance, order: number, title: string?, desc: string?, reserve: number?)
	local keep = reserve or 250
	local row = New("Frame", {
		Name = "Row",
		BackgroundColor3 = CL.Row,
		Size = UDim2.new(1, -8, 0, 62),
		LayoutOrder = order,
		Parent = parent,
	}, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Color = CL.RowEdge, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	if title then
		Kit.Text(title, 19, {
			Name = "Title",
			Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(16, if desc then 8 else 0),
			Size = UDim2.new(1, -(16 + keep), 0, if desc then 26 else 62),
			Parent = row,
		})
	end
	if desc then
		New("TextLabel", {
			Name = "Desc",
			BackgroundTransparency = 1,
			Text = desc,
			Font = T.Bold,
			TextSize = 13,
			TextColor3 = CL.Sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(16, 35),
			Size = UDim2.new(1, -(16 + keep), 0, 16),
			Parent = row,
		})
	end
	return row
end

-- Pill switch: green with the knob on the right when on, dark with a red end and the knob on
-- the left when off. A tap slides the knob, then calls onChange(newValue).
function Kit.Toggle(on: boolean, onChange: (boolean) -> (), props)
	local W, H, KNOB = 62, 32, 24
	local ON = ColorSequence.new(Color3.fromRGB(59, 245, 98), Color3.fromRGB(23, 201, 60))
	local OFF = ColorSequence.new(Color3.fromRGB(58, 59, 69), Color3.fromRGB(110, 38, 50))
	local track = New("TextButton", {
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = WHITE,
		Size = UDim2.fromOffset(W, H),
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = CL.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	for k, v in props or {} do
		(track :: any)[k] = v
	end
	local gradient = New("UIGradient", { Rotation = if on then 90 else 0, Color = if on then ON else OFF, Parent = track })
	local pad = (H - KNOB) / 2
	local knob = New("Frame", {
		Name = "Knob",
		BackgroundColor3 = if on then WHITE else Color3.fromRGB(201, 203, 214),
		Position = UDim2.fromOffset(if on then W - KNOB - pad else pad, pad),
		Size = UDim2.fromOffset(KNOB, KNOB),
		Parent = track,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	track.Activated:Connect(function()
		local now = not on
		on = now
		gradient.Rotation = if now then 90 else 0
		gradient.Color = if now then ON else OFF
		knob.BackgroundColor3 = if now then WHITE else Color3.fromRGB(201, 203, 214)
		TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
			Position = UDim2.fromOffset(if now then W - KNOB - pad else pad, pad),
		}):Play()
		onChange(now)
	end)
	return track
end

-- Slider: a dark track, a green fill and a round white knob. Drag anywhere on it. onDrag(value)
-- runs while dragging (update a readout), onChange(value) once on release (save it). `value`
-- and the results are 0..1, snapped to props.Step (default 0.05). props.Width, plus layout props.
function Kit.Slider(value: number, onChange: (number) -> (), onDrag: ((number) -> ())?, props)
	props = props or {}
	local width = props.Width or 170
	local step = props.Step or 0.05
	local KNOB = 24
	local hit = New("TextButton", {
		Name = "Slider",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width + KNOB, 44),
	})
	for k, v in props do
		if k ~= "Width" and k ~= "Step" then
			(hit :: any)[k] = v
		end
	end
	local track = New("Frame", {
		Name = "Track",
		BackgroundColor3 = Color3.fromRGB(8, 8, 11),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB / 2, 0.5, 0),
		Size = UDim2.fromOffset(width, 10),
		Parent = hit,
	}, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = WHITE,
		Size = UDim2.fromScale(value, 1),
		Parent = track,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(59, 245, 98), Color3.fromRGB(23, 201, 60)),
		}),
	})
	local knob = New("Frame", {
		Name = "Knob",
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		ZIndex = 2,
		Parent = track,
	}, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = CL.Ink, Thickness = 2 }),
	})
	local current = value
	local function set(x: number)
		local v = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		v = math.clamp(math.round(v / step) * step, 0, 1)
		if v ~= current then
			current = v
			fill.Size = UDim2.fromScale(v, 1)
			fill.Visible = v > 0.001
			knob.Position = UDim2.fromScale(v, 0.5)
			if onDrag then
				onDrag(v)
			end
		end
	end
	fill.Visible = value > 0.001
	local moved: RBXScriptConnection? = nil
	local ended: RBXScriptConnection? = nil
	local function stop(commit: boolean)
		if moved then
			moved:Disconnect()
			moved = nil
		end
		if ended then
			ended:Disconnect()
			ended = nil
			if commit then
				onChange(current)
			end
		end
	end
	hit.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		stop(false)
		set(input.Position.X)
		moved = UserInputService.InputChanged:Connect(function(change)
			if
				change.UserInputType == Enum.UserInputType.MouseMovement
				or (change.UserInputType == Enum.UserInputType.Touch and change == input)
			then
				set(change.Position.X)
			end
		end)
		ended = UserInputService.InputEnded:Connect(function(done)
			if done == input or done.UserInputType == Enum.UserInputType.MouseButton1 then
				stop(true)
			end
		end)
	end)
	hit.Destroying:Connect(function()
		stop(false)
	end)
	return hit
end

return Kit
