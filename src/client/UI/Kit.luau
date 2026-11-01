-- Tiny declarative UI kit (no dependencies). Mobile-first sizes: buttons >= 48px (§18.1).

local TweenService = game:GetService("TweenService")

local Kit = {}

Kit.Theme = {
	Bg = Color3.fromRGB(12, 22, 38),
	Panel = Color3.fromRGB(20, 34, 56),
	PanelLight = Color3.fromRGB(32, 52, 82),
	Accent = Color3.fromRGB(40, 200, 220),
	Gold = Color3.fromRGB(255, 200, 60),
	Good = Color3.fromRGB(70, 210, 110),
	Bad = Color3.fromRGB(235, 70, 80),
	Text = Color3.fromRGB(235, 245, 255),
	Muted = Color3.fromRGB(150, 170, 195),
	Font = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
}
local T = Kit.Theme

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

function Kit.Stroke(color: Color3?, thickness: number?)
	return New("UIStroke", { Color = color or T.Accent, Thickness = thickness or 1.5, Transparency = 0.3 })
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

function Kit.Button(text: string, color: Color3?, onClick: (() -> ())?, props)
	local p = {
		Text = text,
		BackgroundColor3 = color or T.Accent,
		TextColor3 = Color3.new(1, 1, 1),
		Font = T.Bold,
		TextSize = 16,
		Size = UDim2.fromOffset(120, 48),
		AutoButtonColor = true,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local b = New("TextButton", p, { Kit.Corner(10) })
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

function Kit.Panel(props, children)
	local p = {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
	}
	for k, v in props do
		p[k] = v
	end
	local f = New("Frame", p, children)
	Kit.Corner(14).Parent = f
	Kit.Stroke(T.Accent, 1.5).Parent = f
	return f
end

function Kit.Scroll(props)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		p[k] = v
	end
	return New("ScrollingFrame", p)
end

function Kit.Clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function Kit.Pop(gui: GuiObject)
	local scale = gui:FindFirstChildOfClass("UIScale") or New("UIScale", { Parent = gui })
	scale.Scale = 0.85
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Bar with fill; returns frame and a setter(fraction, color?)
function Kit.Bar(props)
	local frame = New("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 15, 25),
		Size = props.Size or UDim2.fromOffset(240, 22),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
	}, { Kit.Corner(8), Kit.Stroke(Color3.new(1, 1, 1), 1) })
	local fill = New("Frame", {
		Name = "Fill",
		BackgroundColor3 = props.Color or T.Accent,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, { Kit.Corner(8) })
	local label = Kit.Label({
		Text = props.Text or "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextSize = 14,
		Font = T.Bold,
		ZIndex = 3,
		Parent = frame,
	})
	return frame, function(fraction: number, color: Color3?, text: string?)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if color then
			fill.BackgroundColor3 = color
		end
		if text then
			label.Text = text
		end
	end
end

return Kit
