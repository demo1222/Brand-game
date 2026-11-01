-- SwimController (Master Plan §20.7): custom underwater movement.
-- Below the water surface the character is PlatformStood and driven by a LinearVelocity
-- (camera-relative 3D movement) plus an AlignOrientation for a "diving" pose.
-- PC: WASD + Space (up) / Ctrl or C (down) / Shift (boost).  Mobile: joystick + HUD buttons.
-- Server still decides oxygen, damage and loot; this only moves the client-owned character.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local World = require(Shared.Config.World)
local Upgrades = require(Shared.Config.Upgrades)

local player = Players.LocalPlayer
local SURFACE = World.WaterSurfaceY

local SwimController = {}
local vertical = 0 -- -1..1 from mobile buttons
local mobileBoost = false
local swimming = false
local lastBoostSent = false
local velocity = Vector3.zero
local knock = Vector3.zero
local linVel: LinearVelocity? = nil
local align: AlignOrientation? = nil
-- Diving-board dive: a scripted swan dive. Jumping off a board takes over the character:
--   "air":   a ballistic arc out to sea; the body rotates so the head follows the arc
--            (upright -> horizontal at the top -> head-first down), arms stretched overhead
--   "water": head-first entry with a big splash, then a fast streamlined glide that curves
--            from straight down to forward-down and slows as it reaches the board depth,
--            handing over to normal swimming without a jolt
-- It runs through the same LinearVelocity/AlignOrientation as swimming, so other players see
-- the arc and rotation, and SwimAnimController poses the limbs from the body's tilt.
type Dive = {
	phase: string,
	t0: number,
	dir: Vector3,
	right: Vector3,
	v0: Vector3,
	depth: number,
	entrySpeed: number,
	entryT: number,
}
local dive: Dive? = nil
local DIVE_GRAVITY = 85
local DIVE_LAUNCH = Vector3.new(0, 34, 0) -- plus 20 studs/s out to sea
local DIVE_OUT = 20

SwimController.Depth = 0

function SwimController.SetVertical(v: number)
	vertical = v
end

function SwimController.SetBoost(on: boolean)
	mobileBoost = on
end

function SwimController.IsSwimming(): boolean
	return swimming
end

local function setup(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "SwimAttachment"
	att.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SwimVelocity"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 0
	lv.Parent = hrp
	local ao = Instance.new("AlignOrientation")
	ao.Name = "SwimAlign"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.Responsiveness = 12
	ao.MaxTorque = 0
	ao.Parent = hrp
	linVel, align = lv, ao
	swimming = false
	velocity = Vector3.zero
	dive = nil

	-- Jumping while standing on a diving board launches you out to sea
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		hum.StateChanged:Connect(function(_, new)
			if new ~= Enum.HumanoidStateType.Jumping then
				return
			end
			local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), params)
			local board = hit and hit.Instance
			if board and board:GetAttribute("DiveBoard") and not dive and linVel and align then
				local look = board.CFrame.LookVector
				local dir = Vector3.new(look.X, 0, look.Z).Unit
				dive = {
					phase = "air",
					t0 = os.clock(),
					dir = dir,
					right = dir:Cross(Vector3.yAxis).Unit,
					v0 = dir * DIVE_OUT + DIVE_LAUNCH,
					depth = math.max(char:GetAttribute("DiveBoardDepth") or 20, 8),
					entrySpeed = 0,
					entryT = 0,
				}
				hum.PlatformStand = true
				linVel.MaxForce = 1e6
				align.MaxTorque = 1e6
				align.Responsiveness = 30 -- snappy rotation through the arc
			end
		end)
	end
end

-- Local splash where you enter the water
local function splash(pos: Vector3, count: number?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 0.2, 4)
	p.Position = Vector3.new(pos.X, SURFACE, pos.Z)
	p.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1) })
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(14, 24)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.Acceleration = Vector3.new(0, -40, 0)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rate = 0
	pe.Parent = p
	pe:Emit(count or 45)
	task.delay(2, function()
		p:Destroy()
	end)
end

local function keyDown(...: Enum.KeyCode): boolean
	for _, k in { ... } do
		if UserInputService:IsKeyDown(k) then
			return true
		end
	end
	return false
end

local function step(dt: number)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 or not linVel or not align then
		return
	end
	local depth = SURFACE - hrp.Position.Y
	SwimController.Depth = depth

	if dive then
		local d = dive
		local now = os.clock()
		local head: Vector3
		if d.phase == "air" then
			local t = now - d.t0
			local v = d.v0 + Vector3.new(0, -DIVE_GRAVITY * t, 0)
			-- the head swings from upright to leading along the arc, and tips toward straight
			-- down while falling, so the entry is near-vertical like a real dive
			local fall = math.clamp(-v.Y / 40, 0, 1)
			local along = (v.Unit + Vector3.new(0, -0.6 * fall, 0)).Unit
			local k = math.clamp((t - 0.05) / 0.35, 0, 1)
			head = Vector3.yAxis:Lerp(along, k)
			velocity = v
			if depth > 0.3 then
				d.phase = "water"
				d.entryT = now
				d.entrySpeed = math.max(v.Magnitude, 50)
				splash(hrp.Position, 90)
			elseif t > 3 then
				dive = nil -- never reached the water (blocked): give control back
				hum.PlatformStand = false
				linVel.MaxForce = 0
				align.MaxTorque = 0
				align.Responsiveness = 12
				return
			end
		else
			-- streamlined glide: steep at first, levelling out and slowing toward the target depth
			local progress = math.clamp(depth / d.depth, 0, 1)
			local ease = progress * progress * (3 - 2 * progress)
			local angle = math.rad(84 - 62 * ease) -- below the horizon
			head = d.dir * math.cos(angle) + Vector3.new(0, -math.sin(angle), 0)
			local swimSpeed = char:GetAttribute("SwimSpeed") or Upgrades.Base.SwimSpeed
			local speed = d.entrySpeed + (swimSpeed * 1.3 - d.entrySpeed) * ease
			velocity = velocity:Lerp(head * speed, math.clamp(dt * 10, 0, 1))
			if progress >= 1 or now - d.entryT > 5 then
				dive = nil
				align.Responsiveness = 12
				-- normal swimming takes over next frame with this velocity (no jolt)
				swimming = true
				hum.PlatformStand = true
			end
		end
		linVel.VectorVelocity = velocity
		local up = if head.Magnitude > 0.01 then head.Unit else Vector3.yAxis
		local right = d.right
		-- keep the frame orthonormal: right stays horizontal, head rotates about it
		local fwd = right:Cross(up)
		align.CFrame = CFrame.fromMatrix(Vector3.zero, up:Cross(fwd), up)
		return
	end

	-- Hysteresis so you don't flicker at the surface
	local wantSwim = if swimming then depth > -0.5 else depth > 1.5
	if wantSwim ~= swimming then
		swimming = wantSwim
		hum.PlatformStand = swimming
		linVel.MaxForce = if swimming then 1e6 else 0
		align.MaxTorque = if swimming then 1e6 else 0
		if swimming and velocity.Y < -20 then
			splash(hrp.Position)
		end
		if not swimming then
			-- pop out of the water so you can climb onto a dock
			hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(velocity.Y, 0) + 62, velocity.Z)
		end
	end
	if not swimming then
		return
	end

	local cam = Workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)
	local move = hum.MoveDirection
	-- forward input follows camera pitch (§20.7 camera-relative 3D movement)
	local forward = move:Dot(flatLook)
	local dir = move + Vector3.new(0, look.Y * math.max(forward, 0) * 1.2, 0)
	local up = vertical
	if keyDown(Enum.KeyCode.Space, Enum.KeyCode.ButtonA) then
		up = 1
	elseif keyDown(Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB) then
		up = -1
	end
	dir += Vector3.new(0, up, 0)
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end

	local boosting = (keyDown(Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2) or mobileBoost) and dir.Magnitude > 0.1
	if boosting ~= lastBoostSent then
		lastBoostSent = boosting
		Net.SetBoost:FireServer(boosting)
	end

	local speed = char:GetAttribute("SwimSpeed") or Upgrades.Base.SwimSpeed
	if boosting then
		speed *= Upgrades.Base.BoostMult
	end
	speed *= char:GetAttribute("CarrySlow") or 1
	speed *= char:GetAttribute("DockSlow") or 1
	if (char:GetAttribute("JellySlowUntil") or 0) > os.clock() then
		speed *= 0.5
	end

	local target = dir * speed
	-- gentle sink when idle, stronger stop near the seabed
	if dir.Magnitude < 0.05 then
		target = Vector3.new(0, -1.5, 0)
	end
	velocity = velocity:Lerp(target, math.clamp(dt * 6, 0, 1)) + knock
	knock = knock * math.clamp(1 - dt * 4, 0, 1)
	if knock.Magnitude < 0.5 then
		knock = Vector3.zero
	end
	linVel.VectorVelocity = velocity

	-- Diving pose: face movement direction, pitched with vertical motion
	local face = if velocity.Magnitude > 2 then velocity.Unit else flatLook
	if math.abs(face.Y) > 0.98 then
		face = (face + flatLook * 0.2).Unit
	end
	-- Horizontal (streamlined) when swimming, upright when treading water (SwimAnimController
	-- animates the limbs to match)
	local pitch = math.clamp(velocity.Magnitude / math.max(speed, 1) * 1.4, 0, 1)
	align.CFrame = CFrame.lookAt(Vector3.zero, face) * CFrame.Angles(math.rad(-88) * pitch, 0, 0)
end

function SwimController.Start()
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	RunService.RenderStepped:Connect(step)
	Net.Knockback.OnClientEvent:Connect(function(impulse: Vector3)
		if typeof(impulse) == "Vector3" then
			knock += impulse
		end
	end)
end

return SwimController
