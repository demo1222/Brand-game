-- TutorialController (Master Plan §17): FTUE hints driven by server flags and player state.
-- Shows one objective at a time with a guiding beam toward the target.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Upgrades = require(Shared.Config.Upgrades)
local NumberFormat = require(Shared.NumberFormat)
local Kit = require(script.Parent.Parent.UI.Kit)

local T = Kit.Theme
local player = Players.LocalPlayer
local TutorialController = {}
local controllers
local label: TextLabel
local beam: Beam?
local targetAttachment: Attachment
local targetPart: Part

function TutorialController.Init(c)
	controllers = c
end

local function myDock(): Model?
	local root = Workspace:FindFirstChild("AbyssWorld")
	local docks = root and root:FindFirstChild("Docks")
	if not docks then
		return nil
	end
	for _, d in docks:GetChildren() do
		if d:GetAttribute("OwnerUserId") == player.UserId then
			return d
		end
	end
	return nil
end

local function nearestNode(pos: Vector3): BasePart?
	local root = Workspace:FindFirstChild("AbyssWorld")
	local nodes = root and root:FindFirstChild("Nodes")
	if not nodes then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, n in nodes:GetChildren() do
		if n:IsA("BasePart") then
			local d = (n.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = n, d
			end
		end
	end
	return best
end

-- Returns objective text and optional world target
local function objective(): (string?, Vector3?)
	local S = controllers.State
	local flags = S.Get("Flags") or {}
	local stats = S.Get("Stats") or {}
	local bag = S.Get("Bag") or {}
	local storage = S.Get("Storage") or {}
	local stands = S.Get("Stands") or {}
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local dock = myDock()
	if (stats.Dives or 0) == 0 and #bag == 0 and next(stands) == nil and #storage == 0 then
		local ramp = dock and dock:FindFirstChild("DiveRamp")
		return "Your dock. Your treasures. The deep awaits.\nJump off the dive ramp into the ocean!", ramp and ramp.Position
	end
	if (stats.Salvaged or 0) < 2 and controllers.SwimController.IsSwimming() then
		local node = nearestNode(hrp.Position)
		return "Swim to a glowing relic and HOLD [E] / tap to salvage it.", node and node.Position
	end
	if #bag > 0 then
		local pad = dock and dock:FindFirstChild("Platform")
		return "Swim back up to YOUR dock to secure your bag before your oxygen runs out!", pad and pad.Position
	end
	if #storage > 0 and next(stands) == nil then
		local stand = dock and dock:FindFirstChild("Stand1")
		return "Put a relic on a display stand — it earns Coins forever!", stand and stand.Position
	end
	if not flags.F_FirstUpgrade and next(stands) ~= nil then
		local pad = dock and dock:FindFirstChild("CollectorPad")
		return "Step on the green pad to collect Coins, then buy an upgrade (⬆️).", pad and pad.Position
	end
	if (S.Get("Suit") or 1) < 2 then
		return `Next goal: buy the Neoprene suit ({NumberFormat.short(Upgrades.Suits[2].Cost)} Coins) to dive into the Kelp Twilight.`, nil
	end
	return nil
end

function TutorialController.Start()
	label = Kit.Label({
		Name = "Objective",
		Text = "",
		Visible = false,
		Font = T.Bold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -200),
		Size = UDim2.fromOffset(560, 50),
		Parent = controllers.UIController.Root,
	})
	targetPart = Instance.new("Part")
	targetPart.Name = "TutorialTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = Workspace
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart

	while true do
		local text, target = objective()
		label.Visible = text ~= nil
		label.Text = text or ""
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if target and hrp then
			targetPart.Position = target
			if not beam or not beam.Parent or beam.Attachment0 == nil or beam.Attachment0.Parent ~= hrp then
				if beam then
					beam:Destroy()
				end
				local a0 = hrp:FindFirstChild("TutorialAttachment") or Instance.new("Attachment")
				a0.Name = "TutorialAttachment"
				a0.Parent = hrp
				beam = Instance.new("Beam")
				beam.Attachment0 = a0 :: Attachment
				beam.Attachment1 = targetAttachment
				beam.Width0 = 0.6
				beam.Width1 = 0.6
				beam.FaceCamera = true
				beam.Color = ColorSequence.new(Color3.fromRGB(80, 255, 200))
				beam.Transparency = NumberSequence.new(0.3)
				beam.Parent = targetPart
			end
			beam.Enabled = true
		elseif beam then
			beam.Enabled = false
		end
		task.wait(0.5)
	end
end

return TutorialController
