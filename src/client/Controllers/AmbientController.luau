-- AmbientController (UI/Visual Overhaul Plan, Phase 4): client-only underwater life.
--   • Marine snow: drifting particles around the camera while underwater (denser deeper).
--   • Fish schools: small schools in the Reef and Kelp zones that wander near the diver and
--     scatter away from them. All local, never replicated, cheap (one part per fish).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)

local AmbientController = {}
local player = Players.LocalPlayer

local SURFACE = World.WaterSurfaceY
local SCHOOLS = 6
local FISH_PER_SCHOOL = 7
local SCHOOL_RANGE = 140 -- schools stay within this distance of the camera

local folder: Folder
local snowPart: Part
local snow: ParticleEmitter
local schools = {}

local FISH_COLORS = {
	{ Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 230, 90) },
	{ Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 220, 230) },
	{ Color3.fromRGB(120, 230, 200), Color3.fromRGB(40, 80, 90) },
}

local function makeFish(color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "Fish"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(0.5, 0.8, 1.4)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = folder
	return p
end

local function newSchool(i: number, camPos: Vector3)
	local palette = FISH_COLORS[(i % #FISH_COLORS) + 1]
	local s = {
		center = camPos + Vector3.new(math.random(-80, 80), math.random(-20, 20), math.random(-80, 80)),
		heading = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit,
		speed = 7 + math.random() * 5,
		fish = {},
		offsets = {},
		phase = math.random() * 10,
	}
	for f = 1, FISH_PER_SCHOOL do
		table.insert(s.fish, makeFish(if f % 3 == 0 then palette[2] else palette[1]))
		table.insert(
			s.offsets,
			Vector3.new(math.random(-40, 40) / 10, math.random(-20, 20) / 10, math.random(-40, 40) / 10)
		)
	end
	return s
end

local function setSchoolsVisible(on: boolean)
	for _, s in schools do
		for _, f in s.fish do
			f.Transparency = if on then 0 else 1
		end
	end
end

local fishVisible = false
local function step(dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local depth = SURFACE - camPos.Y
	local underwater = depth > 0.5

	-- Marine snow follows the camera
	snow.Enabled = underwater
	if underwater then
		snowPart.CFrame = CFrame.new(camPos + cam.CFrame.LookVector * 20)
		local zone = Zones.ForDepth(depth)
		snow.Rate = if zone and zone.Index >= 3 then 70 else 35
		snow.Color = ColorSequence.new(
			if zone and zone.Index >= 4 then Color3.fromRGB(170, 220, 255) else Color3.fromRGB(235, 245, 255)
		)
	end

	-- Fish only in the two shallow zones
	local wantFish = underwater and depth < 400
	if wantFish ~= fishVisible then
		fishVisible = wantFish
		setSchoolsVisible(wantFish)
	end
	if not wantFish then
		return
	end
	local diver = camPos
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		diver = hrp.Position
	end
	local t = os.clock()
	for _, s in schools do
		-- wander, stay near the camera, stay in the water column, flee the diver
		local toCam = camPos - s.center
		if toCam.Magnitude > SCHOOL_RANGE then
			s.center = camPos - toCam.Unit * SCHOOL_RANGE * 0.6 + Vector3.new(0, math.random(-10, 10), 0)
		end
		local steer = Vector3.new(
			math.noise(t * 0.1, s.phase),
			math.noise(t * 0.1, s.phase + 5) * 0.3,
			math.noise(t * 0.1, s.phase + 9)
		)
		local away = s.center - diver
		if away.Magnitude < 25 then
			steer += away.Unit * 2
		end
		local yMin, yMax = SURFACE - 390, SURFACE - 4
		if s.center.Y < yMin + 10 then
			steer += Vector3.new(0, 1, 0)
		elseif s.center.Y > yMax - 6 then
			steer -= Vector3.new(0, 1, 0)
		end
		local h = s.heading + steer * dt * 1.5
		s.heading = if h.Magnitude > 1e-3 then h.Unit else s.heading
		local fast = away.Magnitude < 25
		s.center += s.heading * s.speed * (if fast then 2.2 else 1) * dt
		local look = CFrame.lookAt(Vector3.zero, s.heading)
		for i, fish in s.fish do
			local o = s.offsets[i]
			local wobble = Vector3.new(math.sin(t * 2 + i), math.sin(t * 1.3 + i * 2) * 0.5, math.cos(t * 1.7 + i))
			local pos = s.center + look * (o + wobble * 0.6)
			local wag = math.sin(t * 14 + i) * 0.25
			fish.CFrame = CFrame.lookAt(pos, pos + s.heading) * CFrame.Angles(0, wag, 0)
		end
	end
end

function AmbientController.Start()
	folder = Instance.new("Folder")
	folder.Name = "LocalAmbient"
	folder.Parent = Workspace

	snowPart = Instance.new("Part")
	snowPart.Name = "MarineSnow"
	snowPart.Anchored = true
	snowPart.CanCollide = false
	snowPart.CanQuery = false
	snowPart.CanTouch = false
	snowPart.Transparency = 1
	snowPart.Size = Vector3.new(70, 40, 70)
	snowPart.Parent = folder
	snow = Instance.new("ParticleEmitter")
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.LightEmission = 0.3
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	snow.Size = NumberSequence.new(0.12)
	snow.Lifetime = NumberRange.new(4, 7)
	snow.Speed = NumberRange.new(0.2, 0.8)
	snow.Acceleration = Vector3.new(0, -0.3, 0)
	snow.RotSpeed = NumberRange.new(-30, 30)
	snow.Enabled = false
	snow.Parent = snowPart

	local camPos = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or Vector3.zero
	for i = 1, SCHOOLS do
		table.insert(schools, newSchool(i, camPos + Vector3.new(0, -60, 0)))
	end
	setSchoolsVisible(false)
	RunService.RenderStepped:Connect(step)
end

return AmbientController
