-- FXController (UI/Visual Overhaul Plan, Phase 2): client-only juice.
--   • Coin bursts: "+1,240" pop-up text and coins that fly into the HUD coin badge (§18.3).
--   • Dock displays: relics on stands bob and spin, stand a rarity-coloured glow ring, and
--     Legendary+ get sparkles (Mythic+ also a light pillar). All local, so it costs the server
--     nothing and never replicates.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local Rarities = require(Shared.Config.Rarities)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icon = require(script.Parent.Parent.UI.Icon)

local New, T = Kit.New, Kit.Theme
local FXController = {}
local controllers

local DISPLAY_RANGE = 110 -- studs from the camera within which stand relics animate
local MAX_ANIMATED = 60

function FXController.Init(c)
	controllers = c
end

------------------------------------------------------------------------------------------
-- Coin burst
------------------------------------------------------------------------------------------
local function screenPointOf(worldPos: Vector3?): Vector2
	local cam = Workspace.CurrentCamera
	local overlay = controllers.UIController.Overlay :: ScreenGui
	local size = overlay.AbsoluteSize
	if worldPos and cam then
		local p, onScreen = cam:WorldToScreenPoint(worldPos)
		if onScreen then
			return Vector2.new(p.X, p.Y)
		end
	end
	return Vector2.new(size.X / 2, size.Y * 0.45)
end

function FXController.CoinBurst(amount: number, worldPos: Vector3?, caption: string?)
	local overlay = controllers.UIController.Overlay :: ScreenGui
	local start = screenPointOf(worldPos)
	local hud = controllers.HUDController
	local target = hud.CoinTarget and hud.CoinTarget() or Vector2.new(60, 40)

	-- Floating "+amount" text
	local pop = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(start.X, start.Y),
		Size = UDim2.fromOffset(260, 70),
		ZIndex = 30,
		Parent = overlay,
	})
	local value = Kit.Title({
		Text = `+{NumberFormat.short(amount)}`,
		TextSize = 40,
		TextColor3 = T.Gold,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(70, 40, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 44),
		TextWrapped = false,
		ZIndex = 30,
		Parent = pop,
	})
	local cap
	if caption then
		cap = Kit.Title({
			Text = caption,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 22),
			TextWrapped = false,
			ZIndex = 30,
			Parent = pop,
		})
	end
	Kit.Pop(pop)
	TweenService:Create(pop, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(start.X, start.Y - 80),
	}):Play()
	task.delay(0.8, function()
		local fade = TweenInfo.new(0.5)
		TweenService:Create(value, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		if cap then
			TweenService:Create(cap, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.wait(0.55)
		pop:Destroy()
	end)

	-- Flying coins
	local count = math.clamp(math.floor(3 + math.log10(math.max(amount, 1)) * 2), 4, 14)
	local rng = Random.new()
	for i = 1, count do
		local coin = Icon.new("coin", 28, T.Gold, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(start.X, start.Y),
			ZIndex = 29,
			Parent = overlay,
		})
		local coinScale = New("UIScale", { Parent = coin })
		local spread = start + Vector2.new(rng:NextNumber(-90, 90), rng:NextNumber(-70, 40))
		local out = TweenService:Create(coin, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(spread.X, spread.Y),
			Rotation = rng:NextNumber(-40, 40),
		})
		out:Play()
		task.delay(0.28 + i * 0.045, function()
			local fly = TweenService:Create(coin, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
			})
			TweenService:Create(coinScale, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
			fly:Play()
			fly.Completed:Wait()
			coin:Destroy()
			if hud.BumpCoins then
				hud.BumpCoins()
			end
		end)
	end
	if controllers.AudioController then
		controllers.AudioController.Play("Coins", 1)
	end
end

------------------------------------------------------------------------------------------
-- Dock displays
------------------------------------------------------------------------------------------
type Display = {
	model: Model,
	base: CFrame,
	phase: number,
	extras: { Instance },
}
local displays: { [Model]: Display } = {}
local extrasFolder: Folder

local function removeDisplay(model: Model)
	local d = displays[model]
	if d then
		for _, x in d.extras do
			x:Destroy()
		end
		displays[model] = nil
	end
end

local function addDisplay(model: Model)
	if displays[model] then
		return
	end
	local rarityName = model:GetAttribute("Rarity")
	local rarity = rarityName and Rarities[rarityName]
	local color = Kit.RarityColor(rarityName, Rarities)
	local tier = if type(rarity) == "table" then rarity.Tier else 1
	local base = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local extras = {}

	local ring = Instance.new("Part")
	ring.Name = "DisplayRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.35
	local d = math.max(size.X, size.Z) + 1
	ring.Size = Vector3.new(0.12, d, d)
	ring.CFrame = CFrame.new(base.Position - Vector3.new(0, size.Y / 2 + 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = extrasFolder
	table.insert(extras, ring)

	if tier >= 5 then
		local root = model.PrimaryPart
		if root then
			local attach = Instance.new("Attachment")
			attach.Name = "DisplaySparkles"
			attach.Parent = root
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(color)
			pe.LightEmission = 1
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
			pe.Lifetime = NumberRange.new(1, 1.6)
			pe.Rate = 4 + (tier - 5) * 6
			pe.Speed = NumberRange.new(0.6, 1.6)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Parent = attach
			table.insert(extras, attach)
		end
	end
	if tier >= 6 then
		local pillar = ring:Clone()
		pillar.Name = "LightPillar"
		pillar.Size = Vector3.new(14, d * 0.6, d * 0.6)
		pillar.Transparency = 0.82
		pillar.CFrame = CFrame.new(base.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Parent = extrasFolder
		table.insert(extras, pillar)
	end

	displays[model] = { model = model, base = base, phase = math.random() * math.pi * 2, extras = extras }
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeDisplay(model)
		end
	end)
end

local function watchDocks(docks: Instance)
	for _, d in docks:GetDescendants() do
		if d:IsA("Model") and d.Name == "RelicModel" then
			task.defer(addDisplay, d)
		end
	end
	docks.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and d.Name == "RelicModel" then
			-- wait a frame so the model's parts and pivot have replicated
			task.delay(0.1, function()
				if d.Parent then
					addDisplay(d)
				end
			end)
		end
	end)
end

local accumulator = 0
local function animate(dt: number)
	accumulator += dt
	if accumulator < 1 / 30 then
		return
	end
	accumulator = 0
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	local animated = 0
	for model, d in displays do
		if animated >= MAX_ANIMATED then
			break
		end
		if (d.base.Position - camPos).Magnitude < DISPLAY_RANGE then
			animated += 1
			local bob = math.sin(t * 1.6 + d.phase) * 0.25
			model:PivotTo(d.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * 0.7 + d.phase, 0))
		end
	end
end

function FXController.Start()
	Net.CoinBurst.OnClientEvent:Connect(FXController.CoinBurst)
	extrasFolder = Instance.new("Folder")
	extrasFolder.Name = "LocalDisplayFX"
	extrasFolder.Parent = Workspace
	RunService.Heartbeat:Connect(animate)
	task.spawn(function()
		local root = Workspace:WaitForChild("AbyssWorld", 60)
		local docks = root and root:WaitForChild("Docks", 30)
		if docks then
			watchDocks(docks)
		end
	end)
end

return FXController
