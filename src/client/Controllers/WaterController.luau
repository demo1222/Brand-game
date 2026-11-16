-- WaterController: client-only life on and under the sea surface. The waves themselves are
-- Terrain water (WorldService.buildOcean sets the wave size and speed); this adds:
--   * ripple rings that spread from every dock pillar and board post at the water line
--   * buoys (anything tagged Bob) that bob and tilt on the swell
--   * sun glints: sparkles on the surface around the camera while you're above water
--   * (light shafts: switched off, SHAFTS = 0; they flickered)
--   * double-water fix: the Terrain water slab is only 8 studs thick, so from underwater its
--     bottom face looked like a second surface. Underwater we make the Terrain water invisible
--     and show a flat local "ceiling" part at the surface line instead.
--   * mutes Roblox's default swim and splash sounds (the looping water noise), since Terrain
--     water puts the character in the Swimming state near the surface
-- Everything is local, never replicated, and only near the camera.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)

local WaterController = {}

local SURFACE = World.WaterSurfaceY
local RIPPLE_RANGE = 160 -- studs from the camera
local RIPPLE_EVERY = 1.8 -- seconds between rings per post
local SHAFTS = 0 -- off: the flat neon planes flickered as you moved (owner feedback)
local SHAFT_DEPTH = 160 -- shafts fade out below this depth

local folder: Folder
local glintPart: Part
local glints: ParticleEmitter
local shafts: { { part: Part, offset: Vector3, phase: number } } = {}
local bobbers: { [BasePart]: CFrame } = {}
local posts: { BasePart } = {}
local nextRipple: { [BasePart]: number } = {}
local ceiling: Part
local wasUnder = false

local MUTED_SOUNDS = { Swimming = true, Splash = true }

local function muteSound(s: Instance)
	if s:IsA("Sound") and MUTED_SOUNDS[s.Name] then
		s.Volume = 0
	end
end

local function onCharacter(char: Model)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then
		return
	end
	for _, s in hrp:GetChildren() do
		muteSound(s)
	end
	hrp.ChildAdded:Connect(muteSound)
end

-- Underwater: hide the Terrain water (both its faces) and show the flat ceiling instead
-- The sea's Terrain water slab exists only on this client. Roblox draws a water slab's bottom
-- face even at WaterTransparency 1, so with the camera inside or under the slab you saw a second
-- surface. Underwater the slab is cleared (local only) and a flat ceiling part stands in for the
-- surface; on surfacing the slab is filled again.
local SLAB_CF = CFrame.new(0, World.WaterSurfaceY - 8, 0)
local SLAB_SIZE = Vector3.new(World.OceanRadius * 2 + 600, 16, World.OceanRadius * 2 + 600)

local function fillWater()
	Workspace.Terrain:FillBlock(SLAB_CF, SLAB_SIZE, Enum.Material.Water)
end

local function setUnderwater(under: boolean)
	if under then
		Workspace.Terrain:Clear() -- the slab is the only terrain in the game
	else
		fillWater()
	end
	ceiling.Transparency = if under then 0.3 else 1
end

local function localPart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = folder
	return p
end

-- A thin white ring at the water line that grows and fades
local function ripple(at: Vector3, radius: number)
	local ring = localPart({
		Name = "Ripple",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, radius * 2, radius * 2),
		CFrame = CFrame.new(at.X, SURFACE + 0.08, at.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(235, 250, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	local grow = radius * 2 + 7
	local tween = TweenService:Create(ring, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, grow, grow),
		Transparency = 1,
	})
	tween.Completed:Once(function()
		ring:Destroy()
	end)
	tween:Play()
end

-- Every collidable post that crosses the water line (dock pillars, board posts)
local function collectPosts()
	table.clear(posts)
	local root = Workspace:FindFirstChild("AbyssWorld")
	local docks = root and root:FindFirstChild("Docks")
	if not docks then
		return
	end
	for _, d in docks:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Pillar" or d.Name == "BoardPost") then
			local top = d.Position.Y + d.Size.Y / 2
			local bottom = d.Position.Y - d.Size.Y / 2
			if top > SURFACE and bottom < SURFACE then
				table.insert(posts, d)
				nextRipple[d] = os.clock() + math.random() * RIPPLE_EVERY
			end
		end
	end
end

local function addBobber(p: Instance)
	if p:IsA("BasePart") then
		bobbers[p] = p.CFrame
	end
end

local clock = 0
local function step(dt: number)
	clock += dt
	if clock < 1 / 30 then
		return
	end
	dt, clock = clock, 0
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local depth = SURFACE - camPos.Y
	local t = os.clock()

	-- a little hysteresis so bobbing at the surface doesn't swap the water every frame
	local under = if wasUnder then depth > -0.2 else depth > 0.6
	if under ~= wasUnder then
		wasUnder = under
		setUnderwater(under)
	end
	if under then
		ceiling.CFrame = CFrame.new(camPos.X, SURFACE - 0.05, camPos.Z)
	end

	-- buoys: a slow bob and a little roll, phase from position so neighbours differ
	for part, base in bobbers do
		if part.Parent == nil then
			bobbers[part] = nil
		elseif (base.Position - camPos).Magnitude < 260 then
			local ph = base.Position.X * 0.07 + base.Position.Z * 0.05
			local y = math.sin(t * 1.5 + ph) * 0.35
			part.CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(math.sin(t * 1.1 + ph) * 0.08, 0, math.cos(t * 1.3 + ph) * 0.08)
		end
	end

	-- ripples round posts near the camera (only when the surface could be in view)
	if depth < 40 then
		for _, post in posts do
			local due = nextRipple[post]
			if due and t >= due then
				nextRipple[post] = t + RIPPLE_EVERY + math.random() * 0.6
				local d = (post.Position - camPos)
				if d.X * d.X + d.Z * d.Z < RIPPLE_RANGE * RIPPLE_RANGE then
					ripple(post.Position, math.max(post.Size.X, post.Size.Z) * 0.6)
				end
			end
		end
	end

	-- sun glints on the surface around you while you're above water
	glints.Enabled = depth < 0
	if depth < 0 then
		local ahead = camPos + Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z) * 50
		glintPart.CFrame = CFrame.new(ahead.X, SURFACE + 0.3, ahead.Z)
	end

	-- light shafts from the surface while shallow underwater; they sway and fade with depth
	local showShafts = depth > 1 and depth < SHAFT_DEPTH
	local fade = if showShafts then math.clamp(depth / SHAFT_DEPTH, 0, 1) else 1
	for _, s in shafts do
		if showShafts then
			local x = camPos.X + s.offset.X + math.sin(t * 0.25 + s.phase) * 4
			local z = camPos.Z + s.offset.Z + math.cos(t * 0.2 + s.phase) * 4
			local len = s.part.Size.Y
			local tilt = math.rad(14) + math.sin(t * 0.3 + s.phase) * math.rad(3)
			s.part.CFrame = CFrame.new(x, SURFACE, z) * CFrame.Angles(tilt, s.phase, 0) * CFrame.new(0, -len / 2, 0)
			s.part.Transparency = 0.935 + fade * 0.06 + math.sin(t * 0.8 + s.phase) * 0.01
		else
			s.part.Transparency = 1
		end
	end
end

function WaterController.Start()
	folder = Instance.new("Folder")
	folder.Name = "LocalWater"
	folder.Parent = Workspace

	fillWater()
	ceiling = localPart({
		Name = "SurfaceFromBelow",
		Size = Vector3.new(1600, 0.1, 1600),
		Color = Color3.fromRGB(150, 220, 240),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.15,
		Transparency = 1,
	})
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	glintPart = localPart({ Name = "Glints", Size = Vector3.new(140, 0.2, 140), Transparency = 1 })
	glints = Instance.new("ParticleEmitter")
	glints.Shape = Enum.ParticleEmitterShape.Box
	glints.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	glints.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glints.Color = ColorSequence.new(Color3.fromRGB(255, 252, 235))
	glints.LightEmission = 1
	glints.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(1, 0) })
	glints.Transparency = NumberSequence.new(0.15)
	glints.Lifetime = NumberRange.new(0.5, 1)
	glints.Rate = 60
	glints.Speed = NumberRange.new(0, 0)
	glints.Rotation = NumberRange.new(0, 360)
	glints.Enabled = false
	glints.Parent = glintPart

	for i = 1, SHAFTS do
		local a = i / SHAFTS * math.pi * 2
		local r = 18 + (i % 3) * 16
		table.insert(shafts, {
			part = localPart({
				Name = "LightShaft",
				Size = Vector3.new(2 + (i % 3) * 1.5, 90 + (i % 4) * 20, 0.2),
				Color = Color3.fromRGB(200, 245, 255),
				Material = Enum.Material.Neon,
				Transparency = 1,
			}),
			offset = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r),
			phase = a,
		})
	end

	for _, p in CollectionService:GetTagged("Bob") do
		addBobber(p)
	end
	CollectionService:GetInstanceAddedSignal("Bob"):Connect(addBobber)

	collectPosts()
	-- docks build on the server before the client loads, but re-scan once in case of streaming
	task.delay(5, collectPosts)
	RunService.RenderStepped:Connect(step)
end

return WaterController
