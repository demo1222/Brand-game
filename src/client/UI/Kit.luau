-- UI Kit v2 (UI/Visual Overhaul Plan, Phase 1). Declarative helpers with no dependencies.
-- Mobile-first: buttons >= 48px (§18.1). Everything is asset-free: depth comes from
-- UIGradient/UIStroke, icons from emoji badges (see Icons.luau), and item art from RelicView.
-- The v1 API (New, Corner, Stroke, Padding, List, Label, Button, Panel, Scroll, Clear, Pop,
-- Bar) is unchanged, so every existing screen picks up the new style automatically.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Kit = {}

Kit.Theme = {
	Bg = Color3.fromRGB(8, 16, 30),
	Panel = Color3.fromRGB(16, 30, 52),
	PanelLight = Color3.fromRGB(34, 56, 90),
	PanelDark = Color3.fromRGB(10, 19, 34),
	Accent = Color3.fromRGB(40, 205, 225),
	AccentDeep = Color3.fromRGB(20, 110, 170),
	Gold = Color3.fromRGB(255, 196, 50),
	Good = Color3.fromRGB(60, 205, 105),
	Bad = Color3.fromRGB(235, 70, 80),
	Pearl = Color3.fromRGB(150, 200, 255),
	Text = Color3.fromRGB(240, 248, 255),
	Muted = Color3.fromRGB(150, 172, 200),
	DarkText = Color3.fromRGB(45, 28, 0),
	Font = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Title = Enum.Font.FredokaOne,
}
local T = Kit.Theme

------------------------------------------------------------------------------------------
-- Colour helpers
------------------------------------------------------------------------------------------
function Kit.Darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

function Kit.Lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

-- Perceived brightness: pick dark text on bright buttons (gold, white)
function Kit.TextOn(c: Color3): Color3
	local l = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return if l > 0.68 then T.DarkText else Color3.new(1, 1, 1)
end

-- Display colour for a rarity (Secret is black in config; render it as silver on dark UI)
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
		Color = color or T.Accent,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Vertical light-to-dark sheen; multiply over BackgroundColor3
function Kit.Sheen(strength: number?, rotation: number?)
	local s = strength or 0.3
	return New("UIGradient", {
		Rotation = rotation or 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1 - s, 1 - s, 1 - s)),
	})
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

-- Big display text (titles, numbers) with a soft dark outline
function Kit.Title(props)
	local p = {
		Font = T.Title,
		TextSize = 22,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.new(0, 0, 0),
	}
	for k, v in props do
		p[k] = v
	end
	return Kit.Label(p)
end

------------------------------------------------------------------------------------------
-- Motion
------------------------------------------------------------------------------------------
local function scaleOf(gui: GuiObject): UIScale
	return gui:FindFirstChild("KitScale") :: UIScale or New("UIScale", { Name = "KitScale", Parent = gui })
end

function Kit.Pop(gui: GuiObject)
	local scale = scaleOf(gui)
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Press/hover feedback for any GuiButton
function Kit.Juice(button: GuiButton)
	local scale = scaleOf(button)
	local quick = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(scale, quick, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(scale, quick, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, quick, { Scale = 0.93 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = if hovering then 1.04 else 1 })
			:Play()
	end)
end

-- Diagonal light sweep that repeats (VIP banner, Legendary+ cards, claimable rewards)
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
			NumberSequenceKeypoint.new(0.5, 0.55),
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

-- Fake radial glow: stacked circles with falling opacity
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
	for i, t in { 0.88, 0.8, 0.7, 0.6 } do
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

-- Continuous gentle pulse of a UIScale (claimable buttons, alerts)
function Kit.Pulse(gui: GuiObject, amount: number?)
	local scale = scaleOf(gui)
	local a = amount or 0.06
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
-- Controls
------------------------------------------------------------------------------------------
function Kit.Button(text: string, color: Color3?, onClick: (() -> ())?, props)
	local c = color or T.Accent
	local p = {
		Text = text,
		BackgroundColor3 = c,
		TextColor3 = Kit.TextOn(c),
		Font = T.Bold,
		TextSize = 16,
		Size = UDim2.fromOffset(120, 48),
		AutoButtonColor = false,
		TextStrokeTransparency = if Kit.TextOn(c) == T.DarkText then 1 else 0.75,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local b = New("TextButton", p, {
		Kit.Corner(12),
		Kit.Sheen(0.32),
		Kit.Stroke(Kit.Darken(c, 0.45), 2, 0.1),
	})
	Kit.Juice(b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Pill-shaped label that sizes to its text
function Kit.Pill(text: string, color: Color3, props)
	local p = {
		Text = text,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		TextColor3 = Kit.TextOn(color),
		Font = T.Bold,
		TextSize = 12,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local l = New("TextLabel", p, {
		Kit.Round(),
		New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	return l
end

-- Round gradient badge holding an emoji (or an image id from Icons.Images)
function Kit.IconBadge(icon: string, color: Color3, size: number, props)
	local badge = New("Frame", {
		Name = "IconBadge",
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size, size),
	}, {
		Kit.Round(),
		Kit.Gradient(Kit.Lighten(color, 0.35), Kit.Darken(color, 0.25), 135),
		Kit.Stroke(Kit.Darken(color, 0.5), math.max(1.5, size / 28), 0.05),
	})
	for k, v in props or {} do
		(badge :: any)[k] = v
	end
	if string.sub(icon, 1, 13) == "rbxassetid://" then
		New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.72, 0.72),
			ZIndex = badge.ZIndex + 1,
			Parent = badge,
		})
	else
		New("TextLabel", {
			BackgroundTransparency = 1,
			Text = icon,
			TextScaled = true,
			Font = T.Bold,
			TextColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.64, 0.64),
			ZIndex = badge.ZIndex + 1,
			Parent = badge,
		})
	end
	-- top highlight
	New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.08),
		Size = UDim2.fromScale(0.62, 0.3),
		ZIndex = badge.ZIndex,
		Parent = badge,
	}, { Kit.Round() })
	return badge
end

-- Segmented tabs. items = { {id=, text=, icon=?, color=?} }. Returns frame, setSelected(id)
function Kit.Tabs(parent: Instance, items, selected: string, onSelect: (string) -> (), props)
	local frame = New("Frame", {
		Name = "Tabs",
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.2,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = parent,
	}, { Kit.Corner(12), Kit.Padding(4), Kit.List(4, true) })
	for k, v in props or {} do
		if k ~= "TabWidth" then
			(frame :: any)[k] = v
		end
	end
	local buttons = {}
	local width = props and props.TabWidth
	local function paint(id: string)
		for itemId, b in buttons do
			local item = b.item
			local on = itemId == id
			local c = item.color or T.Accent
			b.button.BackgroundColor3 = if on then c else T.PanelLight
			b.button.BackgroundTransparency = if on then 0 else 0.35
			b.button.TextColor3 = if on then Kit.TextOn(c) else T.Muted
			b.stroke.Color = if on then Kit.Darken(c, 0.45) else T.PanelDark
		end
	end
	for i, item in items do
		local b = New("TextButton", {
			Text = if item.icon then `{item.icon} {item.text}` else item.text,
			Font = T.Bold,
			TextSize = 14,
			AutoButtonColor = false,
			BackgroundColor3 = T.PanelLight,
			Size = if width then UDim2.new(0, width, 1, 0) else UDim2.new(1 / #items, -4, 1, 0),
			LayoutOrder = i,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		}, { Kit.Corner(9), Kit.Sheen(0.25) })
		local stroke = Kit.Stroke(T.PanelDark, 1.5, 0.1)
		stroke.Parent = b
		Kit.Juice(b)
		buttons[item.id] = { button = b, item = item, stroke = stroke }
		b.Activated:Connect(function()
			paint(item.id)
			onSelect(item.id)
		end)
	end
	paint(selected)
	return frame, paint
end

function Kit.Panel(props, children)
	local p = {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = New("Frame", p, children)
	Kit.Corner(16).Parent = f
	Kit.Stroke(T.Accent, 2, 0.45).Parent = f
	Kit.Sheen(0.35).Parent = f
	return f
end

-- Flat inner card (rows inside windows)
function Kit.Card(props, children)
	local p = {
		BackgroundColor3 = T.PanelLight,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = New("Frame", p, children)
	Kit.Corner(12).Parent = f
	Kit.Stroke(Kit.Lighten(T.PanelLight, 0.15), 1, 0.6).Parent = f
	Kit.Sheen(0.25).Parent = f
	return f
end

-- Section header with an accent bar
function Kit.Header(parent: Instance, order: number, text: string, color: Color3?)
	local f = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 30),
		LayoutOrder = order,
		Parent = parent,
	})
	New("Frame", {
		BackgroundColor3 = color or T.Accent,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(4, 18),
		Parent = f,
	}, { Kit.Round() })
	Kit.Title({
		Text = text,
		TextSize = 17,
		TextColor3 = color or T.Accent,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -12, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = f,
	})
	return f
end

function Kit.Scroll(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = T.Accent,
		ScrollBarImageTransparency = 0.3,
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

-- Bar with fill; returns frame and a setter(fraction, color?, text?)
function Kit.Bar(props)
	local frame = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(6, 12, 22),
		Size = props.Size or UDim2.fromOffset(240, 22),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}, { Kit.Round(), Kit.Stroke(Color3.new(0, 0, 0), 2, 0.35) })
	local fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or T.Accent,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, { Kit.Round(), Kit.Sheen(0.4) })
	-- glossy top strip
	New("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		Position = UDim2.new(0, 6, 0, 2),
		Size = UDim2.new(1, -12, 0.3, 0),
		Parent = fill,
	}, { Kit.Round() })
	local label = Kit.Label({
		Text = props.Text or "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 14,
		Font = T.Bold,
		TextStrokeTransparency = 0.4,
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
