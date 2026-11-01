-- SonarController (Master Plan §5.1, §11.1): pings the server and draws temporary markers.
-- Markers show rarity once Sonar is level 5 and mutations at level 10 / Mutation Scanner.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Rarities = require(Shared.Config.Rarities)
local Kit = require(script.Parent.Parent.UI.Kit)

local MARKER_SECONDS = 7
local SonarController = {}
local controllers
local lastPing = 0
local markerFolder: Folder

function SonarController.Init(c)
	controllers = c
end

function SonarController.Ping()
	local cd = controllers.State.Derived("SonarCooldown") or 6
	if os.clock() - lastPing < cd then
		controllers.UIController.Toast(`Sonar recharging ({math.ceil(cd - (os.clock() - lastPing))}s)`, "info")
		return
	end
	lastPing = os.clock()
	Net.UseSonar:FireServer()
end

-- Expanding sonar pulse around the diver (local only)
local function pulse(range: number)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.ForceField
	ball.Color = Color3.fromRGB(80, 240, 255)
	ball.Size = Vector3.one * 2
	ball.CFrame = hrp.CFrame
	ball.Parent = markerFolder
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ball, info, { Size = Vector3.one * range * 2, Transparency = 1 }):Play()
	task.delay(1, function()
		ball:Destroy()
	end)
end

-- Make the pinged node's sparkles burst in its rarity colour for the marker's lifetime
local function tintNode(position: Vector3, color: Color3)
	local root = Workspace:FindFirstChild("AbyssWorld")
	local nodes = root and root:FindFirstChild("Nodes")
	if not nodes then
		return
	end
	for _, node in nodes:GetChildren() do
		if node:IsA("BasePart") and (node.Position - position).Magnitude < 1 then
			local pe = node:FindFirstChild("Sparkles", true) :: ParticleEmitter?
			if pe then
				local oldColor, oldRate = pe.Color, pe.Rate
				pe.Color = ColorSequence.new(color)
				pe.Rate = 24
				task.delay(MARKER_SECONDS, function()
					if pe.Parent then
						pe.Color, pe.Rate = oldColor, oldRate
					end
				end)
			end
			return
		end
	end
end

local function marker(info, from: string?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = info.Position + Vector3.new(0, 2.5, 0)
	local rarity = info.Rarity and Rarities[info.Rarity]
	local color = if rarity then Kit.RarityColor(info.Rarity, Rarities) else Color3.fromRGB(120, 255, 255)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(140, 56)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.Parent = p
	local text = if rarity then `{rarity.Icon} {info.Rarity}` else "◎ Relic"
	if info.Mutations and #info.Mutations > 0 then
		text ..= "\n✨ " .. table.concat(info.Mutations, " ")
	end
	if from then
		text ..= `\n({from})`
	end
	local chip = Kit.New("TextLabel", {
		BackgroundColor3 = Kit.Darken(color, 0.7),
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.75),
		Font = Kit.Theme.Title,
		TextScaled = true,
		TextColor3 = Kit.Lighten(color, 0.3),
		TextStrokeTransparency = 0.3,
		Text = text,
		Parent = bb,
	}, { Kit.Round(), Kit.Stroke(color, 2, 0), Kit.New("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	local arrow = Kit.New("TextLabel", {
		BackgroundTransparency = 1,
		Text = "▼",
		TextScaled = true,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(16, 12),
		Parent = chip,
	})
	arrow.ZIndex = chip.ZIndex
	p.Parent = markerFolder
	tintNode(info.Position, color)
	task.delay(MARKER_SECONDS, function()
		p:Destroy()
	end)
end

function SonarController.Start()
	markerFolder = Instance.new("Folder")
	markerFolder.Name = "SonarMarkers"
	markerFolder.Parent = Workspace
	Net.SonarResult.OnClientEvent:Connect(function(results, range, from)
		if not from then
			pulse(range)
		end
		for _, info in results do
			marker(info, from)
		end
		if not from then
			controllers.UIController.Toast(`Sonar: {#results} relic{#results == 1 and "" or "s"} within {math.floor(range)} studs`, "info")
		end
	end)
end

return SonarController
