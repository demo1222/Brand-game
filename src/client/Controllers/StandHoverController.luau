-- StandHoverController: a hover card over dock stands instead of a label that always floats
-- above every relic (docs/UI_STYLE_GUIDE.md, motion: "World hover card").
--   - Mouse: point at a relic or its pedestal.
--   - Touch / gamepad / keyboard: walk up to a stand (its Display / Take back / Steal prompt
--     shows), and the card shows for that stand.
-- The card pops in with an overshoot, a little wobble and a shine sweep, and pops out when
-- you look away. The server puts the facts on the stand as attributes (DockService).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NumberFormat = require(Shared.NumberFormat)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Materials = require(Shared.Config.Materials)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icon = require(script.Parent.Parent.UI.Icon)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local StandHoverController = {}
local controllers

local HOVER_RANGE = 70 -- studs from the camera
local HOVER_RADIUS = 2.1 -- how close the mouse ray must pass to a stand's axis
local CARD_W, CARD_H = 250, 112

local candidates: { BasePart } = {}
local promptStand: BasePart? = nil
local current: BasePart? = nil
local gui: BillboardGui
local card: Frame
local scale: UIScale
local refs = {} :: { [string]: any }
local hideToken = 0
local nearestStand: () -> BasePart?

function StandHoverController.Init(c)
	controllers = c
end

local function isStand(inst: Instance?): boolean
	return inst ~= nil
		and inst:IsA("BasePart")
		and (inst:GetAttribute("StandIndex") ~= nil or inst:GetAttribute("VaultIndex") ~= nil)
end

-- Closest distance between the ray and a stand's vertical axis (pedestal base to relic top),
-- and how far along the ray that is.
local function rayToAxis(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3): (number, number)
	local u, v, w = dir, b - a, origin - a
	local aa, bb, cc, dd, ee = u:Dot(u), u:Dot(v), v:Dot(v), u:Dot(w), v:Dot(w)
	local den = aa * cc - bb * bb
	local sc, tc
	if den < 1e-6 then
		sc, tc = 0, ee / cc
	else
		sc = (bb * ee - cc * dd) / den
		tc = (aa * ee - bb * dd) / den
	end
	tc = math.clamp(tc, 0, 1)
	sc = math.max((tc * bb - dd) / aa, 0)
	local p, q = origin + u * sc, a + v * tc
	return (p - q).Magnitude, sc
end

local function hoveredStand(): BasePart?
	local cam = Workspace.CurrentCamera
	if not cam then
		return nil
	end
	local m = UserInputService:GetMouseLocation()
	-- a window or button under the mouse wins over the world
	local inset = GuiService:GetGuiInset()
	local objects = player.PlayerGui:GetGuiObjectsAtPosition(m.X - inset.X, m.Y - inset.Y)
	for _, o in objects do
		if o.Visible and o.BackgroundTransparency < 0.95 and o:FindFirstAncestorOfClass("BillboardGui") == nil then
			return nil
		end
	end
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local best, bestAlong = nil, math.huge
	for _, stand in candidates do
		if stand.Parent then
			local base = stand.Position - Vector3.new(0, stand.Size.Y / 2, 0)
			local top = stand.Position + Vector3.new(0, stand.Size.Y / 2 + 4.5, 0)
			local d, along = rayToAxis(ray.Origin, ray.Direction, base, top)
			if d < HOVER_RADIUS and along < bestAlong then
				best, bestAlong = stand, along
			end
		end
	end
	return best
end

-- The relic stand within reach of your character (touch, gamepad, and the moment after a
-- prompt trigger)
local NEAR = 6.5
nearestStand = function(): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	local best, bestD = nil, NEAR
	for _, stand in candidates do
		local d = (stand.Position - hrp.Position).Magnitude
		if d < bestD then
			best, bestD = stand, d
		end
	end
	return best
end

------------------------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------------------------
local function build()
	gui = New("BillboardGui", {
		Name = "StandHoverCard",
		Size = UDim2.fromOffset(CARD_W, CARD_H + 16),
		SizeOffset = Vector2.new(0, 0.5),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = HOVER_RANGE + 20,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	card = New("Frame", {
		Name = "Card",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(CARD_W, CARD_H + 16),
		Parent = gui,
	})
	scale = New("UIScale", { Scale = 0, Parent = card })
	-- pointer under the card, toward the relic
	refs.pointer = New("Frame", {
		Name = "Pointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BorderSizePixel = 0,
		Parent = card,
	}, { Kit.Stroke(T.Outline, 2, 0) })
	-- lip under the face (raised slab)
	refs.lip = New("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(CARD_W, CARD_H - 6),
		Parent = card,
	}, { Kit.Corner(16), Kit.Stroke(T.Outline, 3, 0) })
	local face = New("Frame", {
		Name = "Face",
		Size = UDim2.fromOffset(CARD_W, CARD_H - 6),
		ZIndex = 2,
		Parent = card,
	}, {
		Kit.Corner(16),
		Kit.Stroke(T.Outline, 3, 0),
		New("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 180)),
		}),
	})
	refs.face = face
	refs.name = Kit.Title({
		Text = "",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 26),
		TextScaled = true,
		TextWrapped = false,
		ZIndex = 3,
		Parent = face,
	})
	New("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12, Parent = refs.name })
	refs.tags = New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 36),
		Size = UDim2.new(1, -16, 0, 22),
		ZIndex = 3,
		Parent = face,
	}, { Kit.List(4, true, Enum.HorizontalAlignment.Center) })
	-- income plate: dark well with a coin icon and the rate
	local well = New("Frame", {
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 34),
		ZIndex = 3,
		Parent = face,
	}, { Kit.Corner(10), Kit.Stroke(T.Outline, 2, 0) })
	Icon.new(Icons.Get("Coins"), 22, T.Gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		ZIndex = 4,
		Parent = well,
	})
	refs.rate = Kit.Title({
		Text = "",
		TextSize = 20,
		TextColor3 = Color3.fromRGB(150, 255, 140),
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		TextWrapped = false,
		ZIndex = 4,
		Parent = well,
	})
	refs.owner = Kit.Title({
		Text = "",
		TextSize = 13,
		TextColor3 = Color3.fromRGB(215, 225, 240),
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
		Parent = well,
	})
	-- one-shot shine sweep
	refs.shine = New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = face,
	}, {
		Kit.Corner(16),
		New("UIGradient", {
			Rotation = 20,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.58, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

local function fill(stand: BasePart)
	local rarity = stand:GetAttribute("RelicRarity") or "Common"
	local color = Kit.RarityColor(rarity, Rarities)
	local face = Kit.Darken(color, 0.15)
	refs.face.BackgroundColor3 = face
	refs.lip.BackgroundColor3 = Kit.Darken(color, 0.6)
	refs.pointer.BackgroundColor3 = Kit.Darken(color, 0.6)
	refs.name.Text = stand:GetAttribute("RelicName") or "Relic"
	refs.rate.Text = `+{NumberFormat.short(stand:GetAttribute("RelicRate") or 0)}/s`
	local dock = stand.Parent
	local ownerId = dock and dock:GetAttribute("OwnerUserId")
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	refs.owner.Text = if owner == player
		then (if stand:GetAttribute("IsVault") then "Your vault" else "Yours")
		elseif owner then `{owner.DisplayName}'s`
		else ""
	Kit.Clear(refs.tags)
	Kit.Pill(string.upper(rarity), Kit.Lighten(color, 0.15), {
		TextSize = 13,
		Font = T.Title,
		Size = UDim2.fromOffset(0, 22),
		ZIndex = 4,
		LayoutOrder = 1,
		Parent = refs.tags,
	})
	local muts = stand:GetAttribute("RelicMutations")
	if typeof(muts) == "string" and muts ~= "" then
		for i, id in string.split(muts, ",") do
			local md = Mutations.ById[id]
			Kit.Pill(string.upper(id), if md then md.Color else T.Accent, {
				TextSize = 12,
				Font = T.Title,
				Size = UDim2.fromOffset(0, 22),
				ZIndex = 4,
				LayoutOrder = 1 + i,
				Parent = refs.tags,
			})
		end
	end
	local matId = stand:GetAttribute("RelicMaterial")
	local matDef = matId and Materials.ById[matId]
	if matDef then
		Kit.Pill(`{string.upper(matDef.Name)} x{matDef.Mult}`, matDef.Color, {
			TextSize = 12,
			Font = T.Title,
			Size = UDim2.fromOffset(0, 22),
			ZIndex = 4,
			LayoutOrder = 1,
			Parent = refs.tags,
		})
	end
	local sizeLabel = stand:GetAttribute("RelicSizeTier")
	if sizeLabel and sizeLabel ~= "Tiny" then
		Kit.Pill(sizeLabel, T.Bad, {
			TextSize = 12,
			Font = T.Title,
			Size = UDim2.fromOffset(0, 22),
			ZIndex = 4,
			LayoutOrder = 99,
			Parent = refs.tags,
		})
	end
	-- sit just above the relic
	local model = stand:FindFirstChild("RelicModel") :: Model?
	local topY = stand.Position.Y + stand.Size.Y / 2 + 3
	if model then
		local cf, size = model:GetBoundingBox()
		topY = cf.Position.Y + size.Y / 2 + 0.6
	end
	gui.Adornee = stand
	gui.StudsOffsetWorldSpace = Vector3.new(0, topY - stand.Position.Y, 0)
end

local function popIn()
	hideToken += 1
	gui.Enabled = true
	scale.Scale = 0.15
	card.Rotation = -6
	TweenService:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0), {
		Scale = 1,
	}):Play()
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play()
	local grad = refs.shine:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Offset = Vector2.new(-1, 0)
		TweenService:Create(grad, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12), {
			Offset = Vector2.new(1, 0),
		}):Play()
	end
end

local function popOut()
	hideToken += 1
	local token = hideToken
	local t = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	t:Play()
	t.Completed:Once(function()
		if token == hideToken then
			gui.Enabled = false
		end
	end)
end

local function setTarget(stand: BasePart?)
	if stand == current then
		return
	end
	current = stand
	if stand then
		fill(stand)
		popIn()
	else
		popOut()
	end
end

------------------------------------------------------------------------------------------
-- Candidates: stands with a relic near the camera (rebuilt twice a second)
------------------------------------------------------------------------------------------
local function refreshCandidates(docks: Instance)
	local cam = Workspace.CurrentCamera
	local out = {}
	if cam then
		local camPos = cam.CFrame.Position
		for _, dock in docks:GetChildren() do
			for _, part in dock:GetChildren() do
				if
					isStand(part)
					and part:GetAttribute("HasRelic") == true
					and ((part :: BasePart).Position - camPos).Magnitude < HOVER_RANGE
				then
					table.insert(out, part :: BasePart)
				end
			end
		end
	end
	candidates = out
end

local function anyWindowOpen(): boolean
	local ui = controllers and controllers.UIController
	return ui ~= nil and ui.AnyOpen ~= nil and ui.AnyOpen()
end

function StandHoverController.Start()
	build()
	local root = Workspace:WaitForChild("AbyssWorld", 60)
	local docks = root and root:WaitForChild("Docks", 30)
	if not docks then
		return
	end

	ProximityPromptService.PromptShown:Connect(function(prompt)
		local stand = prompt.Parent
		if isStand(stand) and (prompt.Name == "Place" or prompt.Name == "Steal") then
			promptStand = stand :: BasePart
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt.Parent == promptStand then
			promptStand = nil
		end
	end)

	local sinceRefresh = 1
	local sinceCheck = 0
	RunService.RenderStepped:Connect(function(dt)
		sinceRefresh += dt
		if sinceRefresh > 0.5 then
			sinceRefresh = 0
			refreshCandidates(docks)
		end
		sinceCheck += dt
		if sinceCheck < 1 / 20 then
			return
		end
		sinceCheck = 0
		local target: BasePart? = nil
		if not anyWindowOpen() then
			if UserInputService.MouseEnabled and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then
				target = hoveredStand()
			end
			if not target and promptStand and promptStand:GetAttribute("HasRelic") == true then
				target = promptStand
			end
			-- prompt events can arrive out of order right after a trigger: fall back to the
			-- relic stand you're standing at
			if not target then
				target = nearestStand()
			end
		end
		if target and target:GetAttribute("HasRelic") ~= true then
			target = nil
		end
		setTarget(target)
		-- the relic was swapped or its rate changed while the card is up
		if current and refs.name.Text ~= (current:GetAttribute("RelicName") or "Relic") then
			fill(current)
			popIn()
		elseif current then
			refs.rate.Text = `+{NumberFormat.short(current:GetAttribute("RelicRate") or 0)}/s`
		end
	end)
end

return StandHoverController
