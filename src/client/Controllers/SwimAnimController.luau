-- SwimAnimController (UI/Visual Overhaul Plan, Phase 4): procedural swim animation.
-- Every client animates EVERY character that is underwater (the swim pose and body pitch
-- come from SwimController's AlignOrientation, which replicates through physics). Limb motion
-- is written to Motor6D.Transform in RunService.Stepped, so it needs no uploaded animation
-- assets and works for R15 and R6 rigs.
--   Moving: freestyle. Each arm has a pull (the hand sweeps in under the chest, elbow bent
--           mid-pull) and a high recovery. The torso rolls about its spine toward the pulling
--           arm. The head turns to breathe every second stroke. The legs do a 6-beat kick.
--   Idle:   treading water: sculling arms, slow egg-beater legs.
--   Diving: streamlined (arms overhead, legs together, small dolphin kick), shown in the air when
--           the body is tilted off a diving board, and underwater while plunging steeply. Read
--           from the body's tilt and speed, so every client sees it.
--   R6:     arms and legs only. R6 has no Waist, and its Neck axes are not verified, so there is
--           no roll and no breath turn on R6.
-- Pose tables are built once per rig (names, idle, moving, dive). Each frame only overwrites
-- their entries, so no table is allocated in the loop. CFrame values are still made each frame
-- because the angles change every frame.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)

local SwimAnimController = {}
local SURFACE = World.WaterSurfaceY
local rad = math.rad
local TAU = math.pi * 2
local A = CFrame.Angles
local IDENTITY = CFrame.new()
local ARMS_OVERHEAD = A(math.pi, 0, 0)
local BREATH_HOLD = 0.4 -- seconds the head stays turned to breathe
local BREATH_TURN = rad(50)

type Rig = {
	r15: boolean,
	names: { string },
	joints: { [string]: Motor6D },
	idlePose: { [string]: CFrame },
	movePose: { [string]: CFrame },
	divePose: { [string]: CFrame },
	phase: number, -- stroke phase, 0..TAU. Left arm strokes once per turn, right arm half a turn later
	blend: number, -- 0 treading, 1 full freestyle
	dive: number, -- 0 normal, 1 streamlined
	swimming: boolean,
	posed: boolean, -- true while any pose is written to the joints
	breath: number, -- seconds into a breath turn, or -1 when not breathing
	breathSide: number, -- +1 or -1
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
local R15_NAMES = {
	"LeftShoulder",
	"RightShoulder",
	"LeftElbow",
	"RightElbow",
	"LeftHip",
	"RightHip",
	"LeftKnee",
	"RightKnee",
	"Waist",
	"Neck",
}
local R6_NAMES = { "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

local function newPose(names: { string }): { [string]: CFrame }
	local pose = {}
	for _, name in names do
		pose[name] = IDENTITY
	end
	return pose
end

local function buildRig(char: Model): Rig?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local names = if r15 then R15_NAMES else R6_NAMES
	local joints = {}
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
		for _, name in R6_NAMES do
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
	return {
		r15 = r15,
		names = names,
		joints = joints,
		idlePose = newPose(names),
		movePose = newPose(names),
		divePose = newPose(names),
		phase = math.random() * TAU,
		blend = 0,
		dive = 0,
		swimming = false,
		posed = false,
		breath = -1,
		breathSide = 1,
		bubbles = bubbles,
	}
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- One arm's stroke shape. u runs 0..1 through one cycle, and 0 is the reach at the front.
--   Pull (u 0..0.5): the hand sweeps from the front, under the chest, back to the hip. The elbow
--                    bends most in the middle of the pull.
--   Recovery (u 0.5..1): the arm comes out high with the elbow bent, then reaches forward again.
-- Returns swing (shoulder X, positive is forward), side (shoulder Z, positive is inward for the
-- left arm) and the elbow bend. Every end point matches the next segment, so the motion has no
-- jumps at the wrap.
local function strokeArm(u: number): (number, number, number)
	if u < 0.5 then
		local k = u * 2
		local e = smooth(k)
		return lerp(rad(75), rad(-40), e), lerp(rad(-25), rad(5), e), rad(25 + 75 * math.sin(k * math.pi))
	end
	local k = (u - 0.5) * 2
	local e = smooth(k)
	return lerp(rad(-40), rad(75), e), lerp(rad(5), rad(-25), e), rad(25 + 65 * math.sin(k * math.pi))
end

-- Fills rig.idlePose and rig.movePose for R15. Shares the stroke phase with the kick.
local function poseR15(rig: Rig, t: number)
	local idle, move = rig.idlePose, rig.movePose
	local p = rig.phase
	local scull = math.sin(t * 3) * rad(25)
	local tread = math.sin(t * 2.5)

	-- idle: sculling arms, slow egg-beater legs, head up
	idle.LeftShoulder = A(rad(40) + scull, 0, rad(-60))
	idle.RightShoulder = A(rad(40) - scull, 0, rad(60))
	idle.LeftElbow = A(rad(40), 0, 0)
	idle.RightElbow = A(rad(40), 0, 0)
	idle.LeftHip = A(tread * rad(18) + rad(10), 0, 0)
	idle.RightHip = A(-tread * rad(18) + rad(10), 0, 0)
	idle.LeftKnee = A(-(rad(35) + math.max(0, tread) * rad(20)), 0, 0)
	idle.RightKnee = A(-(rad(35) + math.max(0, -tread) * rad(20)), 0, 0)
	idle.Waist = IDENTITY
	idle.Neck = IDENTITY

	-- moving: freestyle strokes. The right arm is half a turn behind the left.
	local uL = p / TAU
	local uR = uL + 0.5
	if uR >= 1 then
		uR -= 1
	end
	local swingL, sideL, bendL = strokeArm(uL)
	local swingR, sideR, bendR = strokeArm(uR)
	move.LeftShoulder = A(swingL, 0, sideL)
	move.RightShoulder = A(swingR, 0, -sideR) -- mirrored: the right arm's Z is flipped
	move.LeftElbow = A(bendL, 0, 0)
	move.RightElbow = A(bendR, 0, 0)

	-- 6-beat flutter kick: three kicks per leg per full turn of the stroke phase
	local kick = math.sin(p * 3) * rad(28)
	move.LeftHip = A(kick, 0, 0)
	move.RightHip = A(-kick, 0, 0)
	move.LeftKnee = A(rad(-12), 0, 0)
	move.RightKnee = A(rad(-12), 0, 0)

	-- Roll about the spine. The Waist's Y axis is the body's long axis (head to toe). The body
	-- is pitched face down, so Y points along the swim direction. The pulling shoulder drops:
	-- the left arm pulls while sin(p) > 0, so the roll is -sin(p). Positive Y would drop the
	-- right shoulder instead.
	move.Waist = A(0, -math.sin(p) * rad(14), 0)

	-- head lifted; during a breath it turns to the breathing side
	local turn = 0
	if rig.breath >= 0 then
		turn = rig.breathSide * BREATH_TURN * math.sin(math.clamp(rig.breath / BREATH_HOLD, 0, 1) * math.pi)
	end
	move.Neck = A(rad(35), turn, 0)
end

-- Streamlined dive, filled into rig.divePose: arms overhead, legs together, small dolphin kick
local function poseDiveR15(rig: Rig, t: number)
	local pose = rig.divePose
	local kick = math.sin(t * 9) * rad(10)
	local legs = A(kick, 0, 0)
	local knees = A(-math.max(0, kick), 0, 0)
	pose.LeftShoulder = ARMS_OVERHEAD
	pose.RightShoulder = ARMS_OVERHEAD
	pose.LeftElbow = IDENTITY
	pose.RightElbow = IDENTITY
	pose.LeftHip = legs
	pose.RightHip = legs
	pose.LeftKnee = knees
	pose.RightKnee = knees
	pose.Waist = IDENTITY
	pose.Neck = IDENTITY
end

-- R6: arms and legs only (see the header). Joint Z is the sagittal swing axis on R6. The left
-- side is mirrored, so the same angle swings the two limbs in opposite world directions.
local function poseR6Move(rig: Rig, t: number)
	local idle, move = rig.idlePose, rig.movePose
	local p = rig.phase
	local wave = math.sin(t * 3) * rad(20)
	local tread = math.sin(t * 2.5) * rad(18)
	local kick = math.sin(p * 3) * rad(28)
	idle["Right Shoulder"] = A(0, 0, rad(60) + wave)
	idle["Left Shoulder"] = A(0, 0, -(rad(60) - wave))
	idle["Right Hip"] = A(0, 0, tread)
	idle["Left Hip"] = A(0, 0, tread)
	move["Right Shoulder"] = A(0, 0, p)
	move["Left Shoulder"] = A(0, 0, -(p + math.pi))
	move["Right Hip"] = A(0, 0, kick)
	move["Left Hip"] = A(0, 0, kick)
end

local function poseR6Dive(rig: Rig, t: number)
	local dive = rig.divePose
	local kick = math.sin(t * 9) * rad(10)
	dive["Right Shoulder"] = A(0, 0, math.pi)
	dive["Left Shoulder"] = A(0, 0, -math.pi)
	dive["Right Hip"] = A(0, 0, kick)
	dive["Left Hip"] = A(0, 0, -kick)
end

-- Writes Motor6D.Transform from the cached poses: idle to moving by blend, then to dive by dive
local function apply(rig: Rig)
	local idle, move, dive = rig.idlePose, rig.movePose, rig.divePose
	local blend, diveAmt = rig.blend, rig.dive
	for _, name in rig.names do
		local m = rig.joints[name]
		if m then
			local cf = if blend > 0.001 then idle[name]:Lerp(move[name], blend) else idle[name]
			if diveAmt > 0.001 then
				cf = cf:Lerp(dive[name], diveAmt)
			end
			m.Transform = cf
		end
	end
end

-- In the air, only the dive pose is shown
local function applyDive(rig: Rig)
	local dive = rig.divePose
	for _, name in rig.names do
		local m = rig.joints[name]
		if m then
			m.Transform = IDENTITY:Lerp(dive[name], rig.dive)
		end
	end
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
		end
		-- Streamline: tilted in the air just above the water (a board dive), or a steep fast
		-- plunge underwater
		local vel = hrp.AssemblyLinearVelocity
		local tilted = hrp.CFrame.UpVector.Y < 0.85
		local diveTarget = if swimming
			then math.clamp((-vel.Y - 18) / 14, 0, 1)
			elseif tilted and depth > -40 then 1
			else 0
		rig.dive += (diveTarget - rig.dive) * math.clamp(dt * 10, 0, 1)
		if not swimming and rig.dive < 0.02 then
			if rig.posed then
				rig.posed = false
				rig.dive = 0
				rig.breath = -1
				for _, m in rig.joints do
					m.Transform = IDENTITY
				end
			end
			continue
		end
		rig.posed = true

		if not swimming then
			-- in the air: only the dive pose (a board dive)
			if rig.r15 then
				poseDiveR15(rig, t)
			else
				poseR6Dive(rig, t)
			end
			applyDive(rig)
			continue
		end

		local speed = vel.Magnitude
		local target = math.clamp((speed - 2) / 22, 0, 1)
		rig.blend += (target - rig.blend) * math.clamp(dt * 4, 0, 1)
		local before = rig.phase
		rig.phase = (rig.phase + dt * (2.2 + rig.blend * 4.5)) % TAU
		if rig.r15 and rig.phase < before and rig.blend > 0.5 then
			-- a turn of the phase is one stroke of each arm, so this breathes on every second
			-- stroke. The side alternates each breath.
			rig.breath = 0
			rig.breathSide = -rig.breathSide
		end
		if rig.breath >= 0 then
			rig.breath += dt
			if rig.breath > BREATH_HOLD then
				rig.breath = -1
			end
		end
		if rig.bubbles then
			rig.bubbles.Rate = 2 + rig.blend * 6
		end
		if rig.r15 then
			poseR15(rig, t)
		else
			poseR6Move(rig, t)
		end
		if rig.dive > 0.001 then
			if rig.r15 then
				poseDiveR15(rig, t)
			else
				poseR6Dive(rig, t)
			end
		end
		apply(rig)
	end
end

function SwimAnimController.Start()
	RunService.Stepped:Connect(function(_, dt)
		step(dt)
	end)
end

return SwimAnimController
