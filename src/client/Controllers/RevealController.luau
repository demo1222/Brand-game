-- RevealController (Master Plan §7.1 reveal effects, §18.3; UI/Visual Overhaul Plan):
-- full-screen reveal with rotating rarity rays, layered glow, a spinning 3D model of the
-- relic, mutation chips and tier-specific flair. Reveals become skippable (tap) after the
-- first 10.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Kit = require(script.Parent.Parent.UI.Kit)
local RelicView = require(script.Parent.Parent.UI.RelicView)

local New, T = Kit.New, Kit.Theme
local RevealController = {}
local controllers
local seen = 0
local queue = {}
local showing = false

function RevealController.Init(c)
	controllers = c
end

local function rays(parent: Instance, color: Color3, count: number)
	local holder = New("Frame", {
		Name = "Rays",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(10, 10),
		Parent = parent,
	})
	local bars = {}
	for i = 1, count do
		local bar = New("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(1400, 60),
			Rotation = (i / count) * 180,
			Parent = holder,
		}, {
			New("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.4, 0.55),
					NumberSequenceKeypoint.new(0.5, 0.35),
					NumberSequenceKeypoint.new(0.6, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		table.insert(bars, bar)
	end
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		for i, bar in bars do
			bar.Rotation = (i / count) * 180 + t * 18
		end
	end)
	return holder
end

local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local entry = table.remove(queue, 1)
	local relic = entry.relic
	local def = Relics.ById[relic.id]
	local rarity = Rarities[relic.rarity]
	local tier = rarity.Tier
	local rColor = Kit.RarityColor(relic.rarity, Rarities)
	seen += 1

	local overlay = controllers.UIController.Overlay
	local root = New("Frame", {
		Name = "Reveal",
		BackgroundColor3 = Color3.fromRGB(0, 3, 10),
		BackgroundTransparency = if tier >= 3 then 0.35 else 0.6,
		Size = UDim2.new(1, 0, 1, 60),
		Position = UDim2.fromOffset(0, -60),
		Parent = overlay,
	})
	local stageArea = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		Parent = root,
	})
	if tier >= 2 then
		rays(stageArea, rColor, 4 + tier * 2)
	end
	local glow = Kit.Glow(stageArea, rColor, 300 + tier * 30, { Position = UDim2.fromScale(0.5, 0.4) })

	-- 3D model
	local model = RelicView.new({
		Relic = relic,
		Spin = 60,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(240, 240),
		ZIndex = 3,
		Parent = stageArea,
	})
	local modelScale = New("UIScale", { Scale = 0.2, Parent = model })
	TweenService:Create(
		modelScale,
		TweenInfo.new(if tier >= 5 then 0.9 else 0.45, Enum.EasingStyle.Back),
		{ Scale = if relic.size >= 1.35 then 1.15 else 1 }
	):Play()

	-- Text block
	local info = New(
		"Frame",
		{
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.4, 120),
			Size = UDim2.new(0.9, 0, 0, 160),
			ZIndex = 4,
			Parent = stageArea,
		},
		{
			Kit.List(4, false, Enum.HorizontalAlignment.Center),
			New("UISizeConstraint", { MaxSize = Vector2.new(520, 200) }),
		}
	)
	local title = Kit.Title({
		Text = `{rarity.Icon} {relic.rarity:upper()} {rarity.Icon}`,
		TextSize = if tier >= 6 then 40 else 32,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 42),
		TextWrapped = false,
		LayoutOrder = 1,
		ZIndex = 4,
		Parent = info,
	})
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Kit.Lighten(rColor, 0.55), rColor),
		Parent = title,
	})
	Kit.Title({
		Text = (if relic.size >= 1.35 then "HUGE! " else "") .. def.Name,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 2,
		ZIndex = 4,
		Parent = info,
	})
	if #relic.mutations > 0 then
		local chips = New("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 3,
			ZIndex = 4,
			Parent = info,
		}, { Kit.List(6, true, Enum.HorizontalAlignment.Center) })
		for i, m in relic.mutations do
			local md = Mutations.ById[m]
			Kit.Pill(
				`{m} ×{md and md.Mult or 1}`,
				md and md.Color or T.Accent,
				{ TextSize = 14, Size = UDim2.fromOffset(0, 24), LayoutOrder = i, ZIndex = 4, Parent = chips }
			)
		end
	end
	Kit.Pill(
		`+{NumberFormat.short(Formulas.RelicCPS(relic))} Coins/s on display  ·  Size {relic.size}×`,
		T.PanelDark,
		{
			TextSize = 14,
			TextColor3 = Color3.fromRGB(140, 255, 170),
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = 4,
			ZIndex = 4,
			Parent = info,
		}
	)
	Kit.Label({
		Text = `"{def.Lore}"`,
		TextColor3 = T.Muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 5,
		ZIndex = 4,
		Parent = info,
	})
	Kit.Pop(info)

	-- Tier flair: screen flash (Epic+), slow-mo blur (Legendary+)
	local blur
	if tier >= 5 then
		blur = Instance.new("BlurEffect")
		blur.Size = 14
		blur.Parent = Lighting
	end
	if tier >= 4 then
		local flash = New("Frame", {
			BackgroundColor3 = Kit.Lighten(rColor, 0.4),
			BackgroundTransparency = 0.2,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
			Parent = root,
		})
		TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		task.delay(1, function()
			flash:Destroy()
		end)
	end
	-- breathing glow
	local glowScale = New("UIScale", { Parent = glow })
	TweenService:Create(
		glowScale,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.12 }
	):Play()

	if controllers.AudioController then
		controllers.AudioController.Play("Reveal", 0.8 + tier * 0.08)
	end

	local duration = ({ 1.6, 1.8, 2.2, 2.6, 3.4, 4.5, 6 })[tier] or 2
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		if blur then
			blur:Destroy()
		end
		TweenService:Create(root, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(modelScale, TweenInfo.new(0.2), { Scale = 0 }):Play()
		info.Visible = false
		task.delay(0.22, function()
			root:Destroy()
			showing = false
			showNext()
		end)
	end
	if seen > 10 then
		local skip = New("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
			Parent = root,
		})
		skip.Activated:Connect(finish)
		Kit.Label({
			Text = "Tap to continue",
			TextColor3 = T.Muted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -20),
			Size = UDim2.fromOffset(200, 20),
			ZIndex = 5,
			Parent = stageArea,
		})
	end
	task.delay(duration, finish)
end

function RevealController.Start()
	Net.RevealRelic.OnClientEvent:Connect(function(relic, source)
		table.insert(queue, { relic = relic, source = source })
		showNext()
	end)
end

return RevealController
