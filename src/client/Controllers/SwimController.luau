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
-- Diving-board plunge: set when you jump off a board, consumed as you dive to `depth`
local plunge: { depth: number, dir: Vector3, untilT: number }? = nil
local PLUNGE_SPEED = 55

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
	plunge = nil

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
			if board and board:GetAttribute("DiveBoard") then
				local look = board.CFrame.LookVector
				local dir = Vector3.new(look.X, 0, look.Z).Unit
				plunge = { depth = char:GetAttribute("DiveBoardDepth") or 20, dir = dir, untilT = os.clock() + 8 }
				task.defer(function()
					hrp.AssemblyLinearVelocity = dir * 30 + Vector3.new(0, 44, 0)
				end)
			end
		end)
	end
end

-- Local splash where you enter the water
local function splash(pos: Vector3)
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
	pe:Emit(45)
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

	-- Hysteresis so you don't flicker at the surface
	local wantSwim = if swimming then depth > -0.5 else depth > 1.5
	if wantSwim ~= swimming then
		swimming = wantSwim
		hum.PlatformStand = swimming
		linVel.MaxForce = if swimming then 1e6 else 0
		align.MaxTorque = if swimming then 1e6 else 0
		if swimming and plunge then
			splash(hrp.Position)
			velocity = plunge.dir * 10 + Vector3.new(0, -PLUNGE_SPEED, 0)
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
	-- Diving-board plunge: head-first down to the board's depth, then normal swimming
	local plunging = false
	if plunge then
		if depth < plunge.depth and os.clock() < plunge.untilT then
			target = plunge.dir * 8 + Vector3.new(0, -PLUNGE_SPEED, 0)
			plunging = true
		else
			plunge = nil
		end
	end
	-- gentle sink when idle, stronger stop near the seabed
	if dir.Magnitude < 0.05 and not plunging then
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
