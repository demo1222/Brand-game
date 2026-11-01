-- SwimAnimController (UI/Visual Overhaul Plan, Phase 4): procedural swim animation.
-- Every client animates EVERY character that is underwater (the swim pose and body pitch
-- come from SwimController's AlignOrientation, which replicates through physics). Limb motion
-- is written to Motor6D.Transform after the Animator runs (RunService.Stepped), so it needs no
-- uploaded animation assets and works for R15 and R6 rigs.
--   Moving: freestyle arm strokes + flutter kick, faster with speed.
--   Idle:   treading water: sculling arms, slow egg-beater legs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)

local SwimAnimController = {}
local SURFACE = World.WaterSurfaceY
local rad = math.rad

type Rig = {
	r15: boolean,
	joints: { [string]: Motor6D },
	phase: number,
	blend: number,
	swimming: boolean,
	bubbles: ParticleEmitter?,
}
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local R15_JOINTS = {
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftElbow = "LeftLowerArm",
	RightElbow = "RightLowerArm",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	Waist = "UpperTorso",
	Neck = "Head",
}
local R6_JOINTS = { "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip", "Neck" }

local function buildRig(char: Model): Rig?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local joints = {}
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	if r15 then
		for joint, partName in R15_JOINTS do
			local part = char:FindFirstChild(partName)
			local m = part and part:FindFirstChild(joint)
			if m and m:IsA("Motor6D") then
				joints[joint] = m
			end
		end
	else
		local torso = char:FindFirstChild("Torso")
		for _, name in R6_JOINTS do
			local m = torso and torso:FindFirstChild(name)
			if m and m:IsA("Motor6D") then
				joints[name] = m
			end
		end
	end
	local head = char:FindFirstChild("Head")
	local bubbles = nil
	if head then
		local att = Instance.new("Attachment")
		att.Name = "SwimBubbleAttachment"
		att.Position = Vector3.new(0, 0, -0.6)
		att.Parent = head
		bubbles = Instance.new("ParticleEmitter")
		bubbles.Name = "SwimBubbles"
		bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
		bubbles.LightEmission = 0.4
		bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.35) })
		bubbles.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		bubbles.Lifetime = NumberRange.new(1.5, 2.5)
		bubbles.Rate = 3
		bubbles.Speed = NumberRange.new(1, 2)
		bubbles.Acceleration = Vector3.new(0, 4, 0)
		bubbles.SpreadAngle = Vector2.new(25, 25)
		bubbles.Enabled = false
		bubbles.Parent = att
	end
	return { r15 = r15, joints = joints, phase = math.random() * 6, blend = 0, swimming = false, bubbles = bubbles }
end

-- Each pose function returns { joint = {idleCFrame, movingCFrame} }. The two are blended
-- with CFrame:Lerp, which stays continuous through the full arm windmill (a plain
-- angle * blend would jump as the stroke angle wraps).
local function apply(rig: Rig, pose, move: number)
	for name, pair in pose do
		local m = rig.joints[name]
		if m then
			m.Transform = pair[1]:Lerp(pair[2], move)
		end
	end
end

local A = CFrame.Angles

local function poseR15(rig: Rig, t: number)
	local p = rig.phase
	local scull = math.sin(t * 3) * rad(25)
	local kick = math.sin(p * 3) * rad(28)
	local tread = math.sin(t * 2.5)
	return {
		-- freestyle: each arm windmills a full circle, half a turn apart; idle arms scull
		LeftShoulder = { A(rad(40) + scull, 0, rad(-60)), A(p, 0, rad(-10)) },
		RightShoulder = { A(rad(40) - scull, 0, rad(60)), A(p + math.pi, 0, rad(10)) },
		LeftElbow = { A(rad(40), 0, 0), A(rad(25), 0, 0) },
		RightElbow = { A(rad(40), 0, 0), A(rad(25), 0, 0) },
		-- flutter kick when moving, slow egg-beater when idle
		LeftHip = { A(tread * rad(18) + rad(10), 0, 0), A(kick, 0, 0) },
		RightHip = { A(-tread * rad(18) + rad(10), 0, 0), A(-kick, 0, 0) },
		LeftKnee = { A(-(rad(35) + math.max(0, tread) * rad(20)), 0, 0), A(rad(-12), 0, 0) },
		RightKnee = { A(-(rad(35) + math.max(0, -tread) * rad(20)), 0, 0), A(rad(-12), 0, 0) },
		-- body roll with the stroke; head looks forward when horizontal
		Waist = { CFrame.new(), A(0, math.sin(p) * rad(14), 0) },
		Neck = { CFrame.new(), A(rad(35), 0, 0) },
	}
end

local function poseR6(rig: Rig, t: number)
	local p = rig.phase
	-- R6 joints swing about their own Z axis; left/right are mirrored
	local wave = math.sin(t * 3) * rad(20)
	local kick = math.sin(p * 3) * rad(28)
	local tread = math.sin(t * 2.5) * rad(18)
	return {
		["Right Shoulder"] = { A(0, 0, rad(60) + wave), A(0, 0, p) },
		["Left Shoulder"] = { A(0, 0, -(rad(60) - wave)), A(0, 0, -(p + math.pi)) },
		["Right Hip"] = { A(0, 0, tread), A(0, 0, kick) },
		["Left Hip"] = { A(0, 0, tread), A(0, 0, kick) },
	}
end

local function step(dt: number)
	local t = os.clock()
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hrp or not hum or hum.Health <= 0 then
			continue
		end
		local rig = rigs[char]
		if rig == nil then
			rig = buildRig(char)
			if not rig then
				continue
			end
			rigs[char] = rig
		end
		local depth = SURFACE - hrp.Position.Y
		local swimming = if rig.swimming then depth > -0.5 else depth > 1.5
		if swimming ~= rig.swimming then
			rig.swimming = swimming
			if rig.bubbles then
				rig.bubbles.Enabled = swimming
			end
			if not swimming then
				for _, m in rig.joints do
					m.Transform = CFrame.new()
				end
			end
		end
		if not swimming then
			continue
		end
		local speed = hrp.AssemblyLinearVelocity.Magnitude
		local target = math.clamp((speed - 2) / 22, 0, 1)
		rig.blend += (target - rig.blend) * math.clamp(dt * 4, 0, 1)
		rig.phase = (rig.phase + dt * (2.2 + rig.blend * 4.5)) % (math.pi * 2)
		if rig.bubbles then
			rig.bubbles.Rate = 2 + rig.blend * 6
		end
		apply(rig, if rig.r15 then poseR15(rig, t) else poseR6(rig, t), rig.blend)
	end
end

function SwimAnimController.Start()
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

return SwimAnimController
