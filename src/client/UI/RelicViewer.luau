-- RelicViewer: full-screen showcase of one relic (Codex "View").
-- The game behind blurs and dims; the relic sits big in the middle on a rarity glow and turns
-- slowly. Drag to rotate it yourself. Below: the name, a big rarity word, lore and info chips.
-- Close with the X button or Escape / B. Clicking the backdrop does nothing (a missed click
-- must never close a modal: docs/UI_STYLE_GUIDE.md).
--
--   RelicViewer.Open({ Id = "R049", Mutations = {..}?, Info = { "Zone: The Abyss", ... }? })
--   RelicViewer.Close()

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Kit = require(script.Parent.Kit)
local RelicView = require(script.Parent.RelicView)
local RelicCard = require(script.Parent.RelicCard)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local RelicViewer = {}

local current: { gui: ScreenGui, blur: BlurEffect, conns: { RBXScriptConnection }, hidden: { ScreenGui } }? = nil
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function RelicViewer.Close()
	local c = current
	if not c then
		return
	end
	current = nil
	for _, conn in c.conns do
		conn:Disconnect()
	end
	for _, g in c.hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	TweenService:Create(c.blur, FADE, { Size = 0 }):Play()
	local root = c.gui:FindFirstChild("Root") :: Frame?
	if root then
		TweenService:Create(root, FADE, { GroupTransparency = 1 } :: any):Play()
		local stage = root:FindFirstChild("Stage") :: Frame?
		if stage then
			Kit.PopOut(stage, nil, 0.7)
		end
	end
	task.delay(0.26, function()
		c.blur:Destroy()
		c.gui:Destroy()
	end)
end

function RelicViewer.IsOpen(): boolean
	return current ~= nil
end

function RelicViewer.Open(args)
	RelicViewer.Close()
	local def = Relics.ById[args.Id]
	if not def then
		return
	end
	local rColor = Kit.RarityColor(def.Rarity, Rarities)
	local conns = {}

	local blur = Instance.new("BlurEffect")
	blur.Name = "RelicViewerBlur"
	blur.Size = 0
	blur.Parent = Lighting
	TweenService:Create(blur, FADE, { Size = 22 }):Play()

	local gui = New("ScreenGui", {
		Name = "RelicViewer",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- CanvasGroup so the whole screen can fade in and out together
	local root = New("CanvasGroup", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Parent = gui,
	})
	TweenService:Create(root, FADE, { GroupTransparency = 0 } :: any):Play()

	-- Backdrop: dark tint with a rarity-coloured vertical fade. Active, so clicks stop here.
	local _, seq = RelicCard.RarityBackground(def.Rarity)
	New("Frame", {
		Name = "Backdrop",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(4, 8, 18),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Parent = root,
	}, {
		New("UIGradient", {
			Rotation = 90,
			Color = seq,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(0.6, 0.2),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})
	-- Stage: rarity glow + the relic, a square that fits the screen height
	local stage = New("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.62, 0.62),
		Parent = root,
	}, { New("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	Kit.Glow(stage, rColor, 10, { Size = UDim2.fromScale(1.1, 1.1), Layers = 18 })
	local vpf = RelicView.new({
		Relic = { id = def.Id, mutations = args.Mutations },
		Angle = 28,
		Pitch = 12,
		Zoom = 0.95,
		ZIndex = 3,
		Parent = stage,
	})
	vpf.Active = true
	stage.ZIndex = 2
	Kit.Pop(stage, 0.6, 0.35)
	-- Drag to rotate; otherwise turn slowly on its own
	local cam = vpf.CurrentCamera
	local dist = if cam then cam.CFrame.Position.Magnitude else 10
	local yaw, pitch = 28, 12
	local dragging, lastPos = false, nil
	table.insert(
		conns,
		vpf.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, lastPos = true, input.Position
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and lastPos
				and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
			then
				local d = input.Position - lastPos
				lastPos = input.Position
				yaw -= d.X * 0.5
				pitch = math.clamp(pitch + d.Y * 0.3, -35, 60)
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	)
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt)
			if not dragging then
				yaw += dt * 22
			end
			if cam then
				local rot = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-pitch), 0, 0)
				cam.CFrame = CFrame.lookAt(rot * Vector3.new(0, 0, dist), Vector3.zero)
			end
		end)
	)

	-- Name, rarity, lore and chips along the bottom
	local info = New("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.new(0.9, 0, 0, 190),
		ZIndex = 2,
		Parent = root,
	}, { Kit.List(4, false, Enum.HorizontalAlignment.Center) })
	local name = Kit.Title({
		Text = def.Name,
		TextSize = 44,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 50),
		TextScaled = true,
		LayoutOrder = 1,
		Parent = info,
	})
	New("UITextSizeConstraint", { MaxTextSize = 46, Parent = name })
	local rarityLabel = Kit.Title({
		Text = string.upper(def.Rarity),
		TextSize = 40,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 2,
		Parent = info,
	})
	-- rarity word painted in a light-to-rarity gradient
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Kit.Lighten(rColor, 0.55), rColor),
		Parent = rarityLabel,
	})
	Kit.Label({
		Text = `"{def.Lore}"`,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(210, 220, 235),
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 3,
		Parent = info,
	})
	local chips = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 4,
		Parent = info,
	}, { Kit.List(8, true, Enum.HorizontalAlignment.Center) })
	for i, text in args.Info or {} do
		Kit.Pill(text, if i == 1 then rColor else T.PanelLight, { LayoutOrder = i, Parent = chips })
	end
	Kit.Label({
		Text = "Drag to rotate · X or Esc to close",
		TextSize = 13,
		TextColor3 = Color3.fromRGB(150, 165, 190),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 5,
		Parent = info,
	})

	-- Close button, top right
	Kit.Button("X", T.Bad, RelicViewer.Close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(52, 52),
		TextSize = 22,
		ZIndex = 5,
		Parent = root,
	})
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				RelicViewer.Close()
			end
		end)
	)
	-- BlurEffect only blurs the 3D world, so hide the rest of the UI (HUD, the Codex window)
	-- while viewing; Close turns it back on.
	local hidden = {}
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	current = { gui = gui, blur = blur, conns = conns, hidden = hidden }
end

return RelicViewer
