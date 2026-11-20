-- WorldService: generates the graybox world at runtime (Master Plan §6, §8.1, §19).
-- Ocean volume with five depth zones, a central Harbor plaza, a ring of 16 docks, air pockets,
-- zone landmarks and plaza props (leaderboards, Server Luck Totem, VIP lounge).
-- Replace with art kits later; services only depend on the dock/zone data exposed here.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Build = require(script.Parent.Parent.Util.Build)
local RelicArt = require(Shared.RelicArt)
local WorldMeshes = require(Shared.Config.WorldMeshes)

local WorldService = {}
local services
local docks = {}
local airPockets = {}
local landmarks: { { pos: Vector3, zone: number } } = {}
local root: Folder
local rng = Random.new(1337) -- deterministic layout

local SURFACE = World.WaterSurfaceY
local R = World.OceanRadius

function WorldService.Init(s)
	services = s
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Per-zone look of the cliff walls, shelves and props (UI/Visual Overhaul Plan, Phase 4)
local ZONE_STYLE = {
	{ wall = Color3.fromRGB(196, 168, 126), mat = Enum.Material.Sandstone, shelf = Color3.fromRGB(222, 200, 150), shelfMat = Enum.Material.Sand },
	{ wall = Color3.fromRGB(64, 84, 70), mat = Enum.Material.Slate, shelf = Color3.fromRGB(74, 96, 64), shelfMat = Enum.Material.Grass },
	{ wall = Color3.fromRGB(52, 58, 74), mat = Enum.Material.Slate, shelf = Color3.fromRGB(70, 66, 60), shelfMat = Enum.Material.Mud },
	{ wall = Color3.fromRGB(30, 30, 44), mat = Enum.Material.Basalt, shelf = Color3.fromRGB(38, 36, 52), shelfMat = Enum.Material.Basalt },
	{ wall = Color3.fromRGB(48, 20, 20), mat = Enum.Material.Basalt, shelf = Color3.fromRGB(60, 26, 22), shelfMat = Enum.Material.CrackedLava },
}

-- Surfaces loot and creatures can spawn on, per zone: { pos = top-centre, radius = usable spread }
local anchors: { [number]: { { pos: Vector3, radius: number } } } = {}
-- Where props stand, per zone, so relics never spawn inside a coral or a wreck
local propSpots: { [number]: { Vector3 } } = {}
-- How much room a zone's props take (brain corals are up to 13 studs wide)
local PROP_CLEAR = { 9, 4, 7, 5, 5 }

-- Loot anchors are Attachments inside the surface part, so they move with it when the part is
-- moved in Studio. scan() reads them back (for a fresh build and for a baked map alike).
local function addAnchor(zoneIndex: number, part: BasePart, pos: Vector3, radius: number)
	local a = Instance.new("Attachment")
	a.Name = "LootAnchor"
	a.CFrame = part.CFrame:ToObjectSpace(CFrame.new(pos))
	a:SetAttribute("Zone", zoneIndex)
	a:SetAttribute("Radius", radius)
	a.Parent = part
end

local function clearOfProps(zoneIndex: number, p: Vector3): boolean
	local r = PROP_CLEAR[zoneIndex] or 6
	for _, s in propSpots[zoneIndex] or {} do
		local d = s - p
		if math.abs(d.Y) < 14 and d.X * d.X + d.Z * d.Z < r * r then
			return false
		end
	end
	return true
end

local function deco(props)
	props.CanCollide = props.CanCollide == true
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	return Build.Part(props)
end

-- Props that sit on a surface point `p` (top of a shelf/ledge), themed per zone
local PROPS = {}
-- Reef palette: saturated, cartoon-bright; each coral takes one body colour and a lighter tip
local REEF_HUES = {
	Color3.fromRGB(255, 110, 140), -- pink
	Color3.fromRGB(255, 160, 60), -- orange
	Color3.fromRGB(170, 100, 255), -- violet
	Color3.fromRGB(255, 214, 90), -- yellow
	Color3.fromRGB(70, 210, 200), -- teal
	Color3.fromRGB(255, 90, 80), -- red
}

local function darker(c: Color3): Color3
	return c:Lerp(Color3.new(0, 0, 0), 0.35)
end

local function lighter(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), t)
end

-- a few sea-grass blades and pebbles around a prop's foot, so nothing sits on bare sand
local function reefFoot(parent, p: Vector3, g: Random, spread: number)
	for _ = 1, g:NextInteger(3, 6) do
		local h = g:NextNumber(1.6, 3.4)
		local off = Vector3.new(g:NextNumber(-spread, spread), 0, g:NextNumber(-spread, spread))
		deco({
			Name = "SeaGrass",
			Size = Vector3.new(0.35, h, 0.12),
			CFrame = CFrame.new(p + off + Vector3.new(0, h / 2, 0))
				* CFrame.Angles(g:NextNumber(-0.3, 0.3), g:NextNumber(0, 6), g:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(70, 170 + g:NextInteger(0, 50), 90),
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
	end
	for _ = 1, g:NextInteger(1, 3) do
		local d = g:NextNumber(0.8, 1.8)
		deco({
			Name = "Pebble",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d * 0.6, d),
			CFrame = CFrame.new(p + Vector3.new(g:NextNumber(-spread, spread), d * 0.2, g:NextNumber(-spread, spread))),
			Color = Color3.fromRGB(180, 168, 140),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
end

local function cyl(name: string, len: number, thick: number, cf: CFrame, color: Color3, mat: Enum.Material, parent, extra)
	local props = {
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(len, thick, thick),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = mat,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return deco(props)
end

-- Blender prop (Config.WorldMeshes) if it has been uploaded: cloned, scaled to `height`,
-- turned at random, its _Main parts recoloured to `hue` and _Tip parts to a lighter hue.
-- Returns false when there is no such model, so the caller builds its code version.
local function meshProp(name: string, parent: Instance, p: Vector3, g: Random, height: number, hue: Color3?, rot: CFrame?): boolean
	local folder = ReplicatedStorage:FindFirstChild("WorldMeshes")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return false
	end
	local m = template:Clone()
	WorldMeshes.Paint(m, name)
	-- Imported models keep the bundle's origin as their pivot, often tens of studs away from
	-- the mesh (the bundle spread its models out). Re-centre the pivot on the geometry first,
	-- or scaling and turning throws the prop far off its spot (floating corals and racks).
	local box, size = m:GetBoundingBox()
	m.WorldPivot = box
	m:ScaleTo(m:GetScale() * height / math.max(size.Y, 0.01))
	local _, scaled = m:GetBoundingBox()
	m:PivotTo(CFrame.new(p + Vector3.new(0, scaled.Y / 2, 0)) * (rot or CFrame.Angles(0, g:NextNumber(0, math.pi * 2), 0)))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if hue and d.Name:find("_Main", 1, true) then
				d.Color = hue
			elseif hue and d.Name:find("_Tip", 1, true) and name ~= "CORAL_Tube" then
				d.Color = hue:Lerp(Color3.new(1, 1, 1), 0.45)
			elseif d.Name:find("_Glow", 1, true) then
				d.Material = Enum.Material.Neon
			end
		end
	end
	m.Parent = parent
	return true
end

local CORAL_MESH = { "CORAL_Brain", "CORAL_Branch", "CORAL_Fan", "CORAL_Tube", "CORAL_Table" }
local CORAL_HEIGHT = { 5, 10, 11, 6, 6 }

PROPS[1] = function(parent, p: Vector3, g: Random)
	local kind = g:NextInteger(1, 6)
	local hue = REEF_HUES[g:NextInteger(1, #REEF_HUES)]
	local tip = lighter(hue, 0.45)
	if CORAL_MESH[kind] and meshProp(CORAL_MESH[kind], parent, p, g, CORAL_HEIGHT[kind] * g:NextNumber(0.8, 1.25), hue) then
		reefFoot(parent, p, g, 3)
		return
	end
	if kind == 1 then -- brain coral: a squashed dome with ridged bands and a smaller bud
		local d = g:NextNumber(5, 9)
		local dome = CFrame.new(p + Vector3.new(0, d * 0.22, 0))
		deco({ Name = "BrainCoral", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.62, d), CFrame = dome, Color = hue, Material = Enum.Material.Sand, Parent = parent })
		for i = 1, 3 do
			local r = d * (0.98 - i * 0.18)
			cyl("Ridge", 0.35, r, dome * CFrame.new(0, d * (0.1 + i * 0.06), 0), lighter(hue, 0.18 * i), Enum.Material.Sand, parent)
		end
		local bd = d * 0.45
		deco({ Name = "Bud", Shape = Enum.PartType.Ball, Size = Vector3.new(bd, bd * 0.7, bd), CFrame = CFrame.new(p + Vector3.new(d * 0.55, bd * 0.2, d * 0.2)), Color = lighter(hue, 0.2), Material = Enum.Material.Sand, Parent = parent })
		reefFoot(parent, p, g, d * 0.6)
	elseif kind == 2 then -- branching coral: a trunk that splits twice, with glowing tips
		local function branch(cf: CFrame, len: number, thick: number, depth: number)
			cyl("Branch", len, thick, cf * CFrame.new(0, len / 2, 0), hue, Enum.Material.SmoothPlastic, parent)
			local top = cf * CFrame.new(0, len, 0)
			if depth <= 0 then
				deco({ Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.one * thick * 1.3, CFrame = top, Color = tip, Material = Enum.Material.Neon, Parent = parent })
				return
			end
			deco({ Name = "Knot", Shape = Enum.PartType.Ball, Size = Vector3.one * thick, CFrame = top, Color = hue, Material = Enum.Material.SmoothPlastic, Parent = parent })
			for k = 1, 2 do
				local yaw = g:NextNumber(0, 6) + k * math.pi
				branch(top * CFrame.Angles(0, yaw, math.rad(g:NextNumber(22, 40))), len * g:NextNumber(0.6, 0.8), thick * 0.72, depth - 1)
			end
		end
		for k = 1, g:NextInteger(2, 3) do
			local base = CFrame.new(p + Vector3.new(g:NextNumber(-1.5, 1.5), 0, g:NextNumber(-1.5, 1.5)))
			branch(base * CFrame.Angles(0, k * 2.1, math.rad(g:NextNumber(0, 15))), g:NextNumber(3, 5), 1.1, 2)
		end
		reefFoot(parent, p, g, 3)
	elseif kind == 3 then -- sea fan: a stem and three overlapping lattice fans
		local h = g:NextNumber(7, 12)
		local base = CFrame.new(p) * CFrame.Angles(0, g:NextNumber(0, 6), 0)
		deco({ Name = "FanStem", Size = Vector3.new(0.6, 2, 0.6), CFrame = base * CFrame.new(0, 1, 0), Color = darker(hue), Material = Enum.Material.SmoothPlastic, Parent = parent })
		for i = -1, 1 do
			local w = h * (1 - math.abs(i) * 0.25)
			deco({
				Name = "SeaFan",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.2, w, w),
				CFrame = base * CFrame.new(i * w * 0.28, 2 + w * 0.42, i * 0.15) * CFrame.Angles(0, math.rad(90), 0),
				Color = if i == 0 then hue else lighter(hue, 0.25),
				Material = Enum.Material.Fabric,
				Transparency = 0.12,
				Parent = parent,
			})
		end
		reefFoot(parent, p, g, 2.5)
	elseif kind == 4 then -- tube sponges: a cluster of tubes with dark mouths
		for _ = 1, g:NextInteger(3, 5) do
			local h = g:NextNumber(2.5, 6.5)
			local r = g:NextNumber(1.1, 1.8)
			local at = p + Vector3.new(g:NextNumber(-1.8, 1.8), 0, g:NextNumber(-1.8, 1.8))
			local cf = CFrame.new(at) * CFrame.Angles(g:NextNumber(-0.15, 0.15), 0, g:NextNumber(-0.15, 0.15))
			cyl("Sponge", h, r, cf * CFrame.new(0, h / 2, 0), hue, Enum.Material.Sand, parent)
			cyl("Mouth", 0.1, r * 0.72, cf * CFrame.new(0, h + 0.03, 0), Color3.fromRGB(40, 20, 40), Enum.Material.SmoothPlastic, parent)
		end
		reefFoot(parent, p, g, 3)
	elseif kind == 5 then -- table coral: a wide flat plate on a short stalk
		local d = g:NextNumber(6, 10)
		local stalk = g:NextNumber(1.5, 3)
		cyl("Stalk", stalk, 1.4, CFrame.new(p + Vector3.new(0, stalk / 2, 0)), darker(hue), Enum.Material.Sand, parent)
		cyl("Table", 0.7, d, CFrame.new(p + Vector3.new(0, stalk + 0.3, 0)), hue, Enum.Material.Sand, parent)
		cyl("TableRim", 0.3, d * 1.04, CFrame.new(p + Vector3.new(0, stalk + 0.55, 0)), tip, Enum.Material.SmoothPlastic, parent)
		reefFoot(parent, p, g, d * 0.4)
	else -- anemone: a soft column with glowing tentacles
		cyl("Anemone", 2, 3, CFrame.new(p + Vector3.new(0, 1, 0)), Color3.fromRGB(90, 60, 110), Enum.Material.SmoothPlastic, parent)
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			deco({
				Name = "Tentacle",
				Size = Vector3.new(0.35, 2.4, 0.35),
				CFrame = CFrame.new(p + Vector3.new(math.cos(a) * 1.1, 3, math.sin(a) * 1.1)) * CFrame.Angles(math.cos(a) * 0.45, 0, -math.sin(a) * 0.45),
				Color = tip,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
		end
		reefFoot(parent, p, g, 2)
	end
end
PROPS[2] = function(parent, p: Vector3, g: Random)
	if meshProp("KELP", parent, p, g, g:NextNumber(18, 34), nil) then
		reefFoot(parent, p, g, 3)
		return
	end
	-- kelp: two or three tall strands with leaves on alternating sides and gas bladders
	for strand = 1, g:NextInteger(2, 3) do
		local pos = p + Vector3.new(g:NextNumber(-2, 2), 0, g:NextNumber(-2, 2))
		local phase = g:NextNumber(0, 6)
		local green = Color3.fromRGB(46, 110 + strand * 12, 52)
		for i = 1, g:NextInteger(5, 9) do
			local len = g:NextNumber(4, 6.5)
			local tilt = math.sin(i * 0.7 + phase) * 0.2
			local cfr = CFrame.new(pos) * CFrame.Angles(tilt, phase, tilt * 0.6)
			deco({ Name = "KelpStem", Size = Vector3.new(0.45, len, 0.45), CFrame = cfr * CFrame.new(0, len / 2, 0), Color = Color3.fromRGB(110, 96, 40), Material = Enum.Material.SmoothPlastic, Parent = parent })
			local side = if i % 2 == 0 then 1 else -1
			deco({
				Name = "Kelp",
				Size = Vector3.new(2.6, len * 0.9, 0.15),
				CFrame = cfr * CFrame.new(side * 1.3, len * 0.55, 0) * CFrame.Angles(0, 0, side * -0.35),
				Color = green:Lerp(Color3.fromRGB(150, 210, 80), i / 12),
				Material = Enum.Material.Grass,
				Parent = parent,
			})
			if i % 3 == 0 then
				deco({ Name = "Bladder", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = cfr * CFrame.new(-side * 0.5, len * 0.7, 0), Color = Color3.fromRGB(190, 170, 60), Parent = parent })
			end
			pos = (cfr * CFrame.new(0, len, 0)).Position
		end
	end
	-- a bed of sea grass and a mossy rock at the foot
	reefFoot(parent, p, g, 3)
	local d = g:NextNumber(2, 4)
	deco({ Name = "MossRock", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.6, d * 0.8), CFrame = CFrame.new(p + Vector3.new(g:NextNumber(-3, 3), d * 0.2, g:NextNumber(-3, 3))), Color = Color3.fromRGB(60, 90, 60), Material = Enum.Material.Slate, Parent = parent })
end
PROPS[3] = function(parent, p: Vector3, g: Random)
	local kind = g:NextInteger(1, 3)
	if kind == 1 then
		local art = ({ "barrel", "chest", "wheel", "anchor", "cannonball" })[g:NextInteger(1, 5)]
		local m = RelicArt.BuildArchetype(art, { main = Color3.fromRGB(95, 70, 50), accent = Color3.fromRGB(70, 75, 70) }, { targetSize = g:NextNumber(5, 9), light = false })
		RelicArt.Place(m, CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(g:NextNumber(-0.4, 0.4), g:NextNumber(0, 6), g:NextNumber(-0.4, 0.4)))
		m.Parent = parent
	elseif kind == 2 then -- broken mast
		local h = g:NextNumber(14, 30)
		deco({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.6, 1.6), CFrame = CFrame.new(p) * CFrame.Angles(0, g:NextNumber(0, 6), math.rad(g:NextNumber(30, 70))) * CFrame.new(h / 2, 0, 0), Color = Color3.fromRGB(80, 60, 44), Material = Enum.Material.Wood, Parent = parent })
	else -- plank pile
		for i = 1, 4 do
			deco({ Name = "Plank", Size = Vector3.new(g:NextNumber(6, 12), 0.6, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 0.4 + i * 0.5, 0)) * CFrame.Angles(0, g:NextNumber(0, 6), g:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(100, 76, 54), Material = Enum.Material.WoodPlanks, Parent = parent })
		end
	end
end
PROPS[4] = function(parent, p: Vector3, g: Random)
	if g:NextNumber() < 0.5 then -- tube worms
		for i = 1, g:NextInteger(2, 4) do
			local h = g:NextNumber(3, 8)
			local off = Vector3.new(g:NextNumber(-2, 2), 0, g:NextNumber(-2, 2))
			deco({ Name = "TubeWorm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.6, 0.6), CFrame = CFrame.new(p + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(220, 220, 230), Parent = parent })
			deco({ Name = "WormTip", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = CFrame.new(p + off + Vector3.new(0, h, 0)), Color = Color3.fromRGB(80, 230, 255), Material = Enum.Material.Neon, Parent = parent })
		end
	else -- glowing crystals
		local m = RelicArt.BuildArchetype("crystals", { main = Color3.fromRGB(90, 140, 255), accent = Color3.fromRGB(30, 30, 44), mat = "Neon" }, { targetSize = g:NextNumber(5, 9), light = false })
		RelicArt.Place(m, CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, g:NextNumber(0, 6), 0))
		m.Parent = parent
	end
end
PROPS[5] = function(parent, p: Vector3, g: Random)
	-- hydrothermal vent chimney
	local h = 0
	for i = 1, g:NextInteger(2, 4) do
		local seg = g:NextNumber(3, 6)
		deco({ Name = "Chimney", Shape = Enum.PartType.Cylinder, Size = Vector3.new(seg, 4 - i * 0.6, 4 - i * 0.6), CFrame = CFrame.new(p + Vector3.new(0, h + seg / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 30, 30), Material = Enum.Material.Basalt, Parent = parent })
		h += seg
	end
	local glow = deco({ Name = "VentGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = CFrame.new(p + Vector3.new(0, h, 0)), Color = Color3.fromRGB(255, 80, 30), Material = Enum.Material.Neon, Parent = parent })
	if g:NextNumber() > 0.3 then
		return -- only some vents get a light and smoke (cost)
	end
	Build.Instance("PointLight", { Range = 18, Brightness = 2, Color = glow.Color, Parent = glow })
	Build.Instance("ParticleEmitter", {
		Name = "Smoke",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(40, 30, 30)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(3, 5),
		Rate = 3,
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(10, 10),
		Parent = glow,
	})
end

-- Place a prop and remember the spot (relics keep clear of it: clearOfProps)
local function placeProp(zoneIndex: number, parent: Instance, p: Vector3, g: Random)
	local m = Instance.new("Model")
	m.Name = "Prop"
	m:SetAttribute("Zone", zoneIndex)
	PROPS[zoneIndex](m, p, g)
	m.WorldPivot = CFrame.new(p)
	m.Parent = parent
end

local function buildOcean()
	local ocean = folder("Ocean", root)
	-- Water surface: a thin slab of Terrain water whose top sits exactly at the surface line.
	-- Terrain water gives real rolling waves, sun glints, reflections and refraction for free
	-- (the old flat SmoothPlastic slab looked dead). It is only 16 studs thick: below that the
	-- zone fog (LightingController) takes over, and SwimController keeps the diver on
	-- PlatformStand underwater so the water's buoyancy doesn't fight the swim constraints.
	-- WaterController (client) adds foam, glints, light shafts and bubbles on top.
	local terrain = Workspace.Terrain
	local span = R * 2 + 600
	-- 16 studs thick and fairly opaque: from above, a thin, clear slab showed its own bottom face
	-- as a second, paler water layer with a jagged edge ("double water")
	-- The water itself is filled on each CLIENT (WaterController), not here: the client clears
	-- it while its camera is underwater and refills it on surfacing. Roblox draws a water
	-- slab's bottom face even at WaterTransparency 1, so from inside or under the slab you saw
	-- a second surface ("double water"). Only the look is set here (it replicates).
	local _ = span
	terrain.WaterColor = Color3.fromRGB(20, 110, 160)
	terrain.WaterTransparency = 0.25
	terrain.WaterReflectance = 0.55
	terrain.WaterWaveSize = 0.55
	terrain.WaterWaveSpeed = 14
	-- Seabed
	Build.Part({
		Name = "Seabed",
		Size = Vector3.new(R * 2 + 40, 8, R * 2 + 40),
		CFrame = CFrame.new(0, SURFACE - World.SeabedDepth - 4, 0),
		Color = Color3.fromRGB(40, 20, 20),
		Material = Enum.Material.Basalt,
		Parent = ocean,
	})
	-- Invisible bounds (parts are limited to 2048 studs per axis, so split vertically)
	local half = World.SeabedDepth / 2
	for _, seg in { 0, 1 } do
		local h = half + 40
		local cy = SURFACE + 40 - seg * half - h / 2
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			Build.Part({
				Name = "Bound",
				Size = if d[1] ~= 0 then Vector3.new(4, h, R * 2) else Vector3.new(R * 2, h, 4),
				CFrame = CFrame.new(d[1] * R, cy, d[2] * R),
				Transparency = 1,
				CanQuery = false,
				Parent = ocean,
			})
		end
	end

	-- Cliff walls with a rock shelf at every zone's floor, around the whole dive area.
	-- Everything decorative sits ON a wall shelf, a spire ledge or the seabed: nothing floats.
	local walls = folder("Cliffs", ocean)
	local SEG = 64
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local normal = Vector3.new(-side[1], 0, -side[2]) -- points into the ocean
		local along = Vector3.new(side[2], 0, side[1])
		for s = -R, R - SEG, SEG do
			local t = s + SEG / 2
			for _, zone in Zones.List do
				local style = ZONE_STYLE[zone.Index]
				local top = SURFACE - zone.MinDepth + (if zone.Index == 1 then 6 else 0)
				local bottom = SURFACE - zone.MaxDepth
				local h = top - bottom
				local inset = rng:NextNumber(0, 14)
				local base = Vector3.new(side[1] * R, 0, side[2] * R) + along * t + normal * (14 + inset)
				deco({
					Name = "Cliff",
					CanCollide = true,
					Size = Vector3.new(SEG + 8, h, 28),
					CFrame = CFrame.lookAt(Vector3.new(base.X, (top + bottom) / 2, base.Z), Vector3.new(base.X, (top + bottom) / 2, base.Z) + normal)
						* CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-2, 2))),
					Color = style.wall:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)),
					Material = style.mat,
					Parent = walls,
				})
				-- Boulders break up the flat wall face
				for _ = 1, (if zone.Index == 1 then 2 else 1) do
					if rng:NextNumber() < 0.85 then
						local by = rng:NextNumber(bottom + 10, top - 6)
						local bpos = Vector3.new(base.X, by, base.Z) + normal * rng:NextNumber(12, 20) + along * rng:NextNumber(-SEG / 2, SEG / 2)
						deco({
							Name = "Boulder",
							CanCollide = true,
							Size = Vector3.new(rng:NextNumber(14, 34), rng:NextNumber(10, 28), rng:NextNumber(12, 24)),
							CFrame = CFrame.new(bpos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
							Color = style.wall:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0.05, 0.3)),
							Material = style.mat,
							Parent = walls,
						})
					end
				end
				-- Shelf at the zone's floor
				local depthOut = rng:NextNumber(26, 48)
				local shelfTop = bottom + 6
				local shelfCenter = Vector3.new(base.X, shelfTop - 3, base.Z) + normal * (14 + depthOut / 2)
				local shelf = deco({
					Name = "Shelf",
					CanCollide = true,
					Size = Vector3.new(SEG + 6, 6, depthOut),
					CFrame = CFrame.lookAt(shelfCenter, shelfCenter + normal),
					Color = style.shelf,
					Material = style.shelfMat,
					Parent = walls,
				})
				local shelfSurface = Vector3.new(shelfCenter.X, shelfTop, shelfCenter.Z)
				addAnchor(zone.Index, shelf, shelfSurface, math.min(SEG, depthOut) * 0.35)
				for _ = 1, (if zone.Index == 1 then 3 else 1) do
					if zone.Index > 1 and rng:NextNumber() > 0.55 then
						continue
					end
					local jitter = along * rng:NextNumber(-SEG / 2 + 4, SEG / 2 - 4) + normal * rng:NextNumber(-depthOut / 2 + 3, depthOut / 2 - 3)
					placeProp(zone.Index, walls, shelfSurface + jitter, rng)
				end
			end
		end
	end

	-- Rock spires rising from the seabed, with a ledge in every zone they pass through
	local spires = folder("Spires", ocean)
	for i = 1, 16 do
		local a = (i / 16) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dist = rng:NextNumber(150, R - 110)
		local x, z = math.cos(a) * dist, math.sin(a) * dist
		local topDepth = rng:NextNumber(40, 900)
		local bottomY = SURFACE - World.SeabedDepth
		local topY = SURFACE - topDepth
		local radius = rng:NextNumber(14, 26)
		deco({
			Name = "Spire",
			CanCollide = true,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(topY - bottomY, radius * 2, radius * 2),
			CFrame = CFrame.new(x, (topY + bottomY) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(46, 44, 56),
			Material = Enum.Material.Slate,
			Parent = spires,
		})
		for _, zone in Zones.List do
			local ledgeDepth = math.max(zone.MinDepth + 20, topDepth + 4)
			if ledgeDepth < zone.MaxDepth - 20 then
				local y = SURFACE - rng:NextNumber(ledgeDepth, zone.MaxDepth - 20)
				local style = ZONE_STYLE[zone.Index]
				local lr = radius + rng:NextNumber(10, 22)
				local ledge = deco({
					Name = "Ledge",
					CanCollide = true,
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(5, lr * 2, lr * 2),
					CFrame = CFrame.new(x, y - 2.5, z) * CFrame.Angles(0, 0, math.rad(90)),
					Color = style.shelf,
					Material = style.shelfMat,
					Parent = spires,
				})
				for k = 1, 2 do
					local ang = k / 2 * math.pi * 2 + rng:NextNumber(0, 1)
					local r = rng:NextNumber(radius + 2, lr - 3)
					local p = Vector3.new(x + math.cos(ang) * r, y, z + math.sin(ang) * r)
					placeProp(zone.Index, spires, p, rng)
					addAnchor(zone.Index, ledge, p, 3)
				end
			end
		end
		-- Reef cap on the shallowest spires
		local topZone = Zones.ForDepth(topDepth)
		if topZone then
			local capStyle = ZONE_STYLE[topZone.Index]
			-- a flat stepped plateau (it used to be a giant sand ball that read as a blob): a
			-- wide rock disc, a smaller sand top and a ring of boulders round the rim
			local capTop = topY + 4
			deco({ Name = "SpireCap", CanCollide = true, Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, radius * 2.4, radius * 2.4), CFrame = CFrame.new(x, topY + 1, z) * CFrame.Angles(0, 0, math.rad(90)), Color = capStyle.wall:Lerp(Color3.new(0, 0, 0), 0.1), Material = capStyle.mat, Parent = spires })
			local spireTop = deco({ Name = "SpireTop", CanCollide = true, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, radius * 2.1, radius * 2.1), CFrame = CFrame.new(x, capTop - 0.8, z) * CFrame.Angles(0, 0, math.rad(90)), Color = capStyle.shelf, Material = capStyle.shelfMat, Parent = spires })
			for k = 1, 7 do
				local ang = k / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
				local bs = rng:NextNumber(3, 6)
				deco({ Name = "RimRock", CanCollide = true, Size = Vector3.new(bs, bs * 0.7, bs), CFrame = CFrame.new(x + math.cos(ang) * radius * 1.12, topY + 2.5, z + math.sin(ang) * radius * 1.12) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Color = capStyle.wall:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.25)), Material = capStyle.mat, Parent = spires })
			end
			for k = 1, 4 do
				local ang = k / 4 * math.pi * 2
				local p = Vector3.new(x + math.cos(ang) * radius * 0.55, capTop, z + math.sin(ang) * radius * 0.55)
				placeProp(topZone.Index, spires, p, rng)
			end
			-- relics sit in the open middle of the plateau, between the props
			addAnchor(topZone.Index, spireTop, Vector3.new(x, capTop, z), radius * 0.35)
		end
	end

	-- 3 landmarks per zone (§6 points of interest), each built from that zone's props
	for _, zone in Zones.List do
		local zf = folder(zone.Id, ocean)
		local style = ZONE_STYLE[zone.Index]
		for i = 1, 3 do
			local depth = zone.MinDepth + (zone.MaxDepth - zone.MinDepth) * (i / 4)
			local angle = (i / 3) * math.pi * 2 + zone.Index
			local pos = Vector3.new(math.cos(angle) * R * 0.55, SURFACE - depth, math.sin(angle) * R * 0.55)
			local lm = deco({
				Name = "Landmark",
				CanCollide = true,
				Size = Vector3.new(40, 10, 40),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0),
				Color = style.shelf,
				Material = style.shelfMat,
				Parent = zf,
			})
			lm:SetAttribute("Zone", zone.Index)
			table.insert(landmarks, { pos = pos, zone = zone.Index })
			Build.Instance("PointLight", { Range = 50, Brightness = 1.2, Color = style.wall:Lerp(Color3.new(1, 1, 1), 0.4), Parent = lm })
			local surface = pos + Vector3.new(0, 5, 0)
			for k = 1, 6 do
				local p = surface + Vector3.new(rng:NextNumber(-16, 16), 0, rng:NextNumber(-16, 16))
				placeProp(zone.Index, zf, p, rng)
			end
			addAnchor(zone.Index, lm, surface, 15)
		end
	end

	-- Air pockets (§6): rare oxygen refills in zones 3–5
	local af = folder("AirPockets", ocean)
	for zoneIndex, count in World.AirPocketsPerZone do
		local zone = Zones.List[zoneIndex]
		for _ = 1, count do
			local depth = rng:NextNumber(zone.MinDepth + 40, zone.MaxDepth - 40)
			local p = Build.Part({
				Name = "AirPocket",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 8,
				CFrame = CFrame.new(rng:NextNumber(-R + 60, R - 60), SURFACE - depth, rng:NextNumber(-R + 60, R - 60)),
				Color = Color3.fromRGB(180, 240, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.3,
				CanCollide = false,
				Parent = af,
			})
			Build.Instance("PointLight", { Range = 30, Brightness = 2, Color = p.Color, Parent = p })
			table.insert(airPockets, p)
		end
	end
end

local function buildPlaza()
	local plaza = folder("Plaza", root)
	local top = SURFACE + World.DockHeight
	Build.Part({
		Name = "Harbor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, World.PlazaRadius * 2, World.PlazaRadius * 2),
		CFrame = CFrame.new(0, top - 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(160, 130, 95),
		Material = Enum.Material.WoodPlanks,
		Parent = plaza,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HarborSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, top + 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.5
	spawn.Parent = plaza

	-- Leaderboard boards (§14) — LeaderboardService fills the SurfaceGuis
	local boards = folder("Leaderboards", plaza)
	local names = { "Deepest", "TotalValue", "Rebirths", "Steals", "Codex" }
	for i, name in names do
		local a = (i - 1) / #names * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 45, top + 9, math.sin(a) * 45)
		local board = Build.Part({
			Name = name,
			Size = Vector3.new(14, 16, 1),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, top + 9, 0)),
			Color = Color3.fromRGB(20, 30, 45),
			Parent = boards,
		})
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Board"
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(400, 460)
		sg.Parent = board
		local list = Instance.new("TextLabel")
		list.Name = "Text"
		list.Size = UDim2.fromScale(1, 1)
		list.BackgroundTransparency = 1
		list.TextColor3 = Color3.new(1, 1, 1)
		list.Font = Enum.Font.GothamMedium
		list.TextSize = 22
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Text = name .. "\nLoading…"
		list.Parent = sg
	end

	-- Server Luck Totem (§15.3)
	local totem = Build.Part({
		Name = "LuckTotem",
		Size = Vector3.new(4, 14, 4),
		CFrame = CFrame.new(0, top + 7, -18),
		Color = Color3.fromRGB(80, 255, 140),
		Material = Enum.Material.Neon,
		Parent = plaza,
	})
	Build.Billboard(totem, "SERVER LUCK TOTEM\n2x luck for everyone", UDim2.fromOffset(240, 60), Vector3.new(0, 10, 0))
	Build.Prompt(totem, "Boost Server Luck", "199 R$", 0, "LuckPrompt")

	-- VIP lounge (§15.2 "VIP door you can see but not enter")
	local lounge = Build.Part({
		Name = "VipLounge",
		Size = Vector3.new(30, 1, 30),
		CFrame = CFrame.new(0, top + 30, 50),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Marble,
		Parent = plaza,
	})
	Build.Billboard(lounge, "VIP LOUNGE", UDim2.fromOffset(200, 50), Vector3.new(0, 6, 0), Color3.fromRGB(255, 210, 80))
	local door = Build.Part({
		Name = "VipDoor",
		Size = Vector3.new(8, 12, 1),
		CFrame = CFrame.new(0, top + 6, 30),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Parent = plaza,
	})
	Build.Billboard(door, "VIP", UDim2.fromOffset(120, 40), Vector3.new(0, 8, 0), Color3.fromRGB(255, 210, 80))
	Build.Prompt(door, "Enter VIP Lounge", "VIP Diver", 0, "VipPrompt")
end

------------------------------------------------------------------------------------------
-- Display pedestal (a dock keeper: rebuilt from this code). Blocky stepped plinth with brass
-- corners. Parts named Trim* are recoloured by DockService to the displayed relic's rarity.
-- The stand part itself is an invisible box over the pedestal that carries the prompts.
------------------------------------------------------------------------------------------
local PEDESTAL_HEIGHT = 2.6
local STAND_REACH = 6 -- studs; 12 reached two or three stands away

local PED = {
	Base = Color3.fromRGB(38, 48, 63),
	Step = Color3.fromRGB(52, 64, 90),
	Column = Color3.fromRGB(62, 76, 104),
	Brass = Color3.fromRGB(128, 94, 42), -- darker than gold on purpose: bright yellow blooms
	TrimIdle = Color3.fromRGB(90, 100, 120),
	VaultBase = Color3.fromRGB(70, 52, 24),
	VaultStep = Color3.fromRGB(120, 88, 34),
	VaultColumn = Color3.fromRGB(150, 112, 44),
}

local function buildPedestal(stand: BasePart, isVault: boolean)
	local ped = Instance.new("Model")
	ped.Name = "Pedestal"
	local floor = stand.CFrame * CFrame.new(0, -PEDESTAL_HEIGHT / 2, 0)
	local function block(name: string, size: Vector3, y: number, color: Color3, neon: boolean?, offset: Vector3?)
		return Build.Part({
			Name = name,
			Size = size,
			CFrame = floor * CFrame.new((offset or Vector3.zero) + Vector3.new(0, y, 0)),
			Color = color,
			Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CanCollide = not neon,
			CastShadow = not neon,
			Parent = ped,
		})
	end
	local base = if isVault then PED.VaultBase else PED.Base
	local step = if isVault then PED.VaultStep else PED.Step
	local column = if isVault then PED.VaultColumn else PED.Column
	local trim = if isVault then PED.Brass else PED.TrimIdle
	block("Base", Vector3.new(3.8, 0.5, 3.8), 0.25, base)
	block("TrimLow", Vector3.new(3.9, 0.12, 3.9), 0.56, trim, true)
	block("Step", Vector3.new(3.2, 0.4, 3.2), 0.82, step)
	block("Column", Vector3.new(2.3, 1.1, 2.3), 1.57, column)
	-- a brass plaque on the front (the side facing the corridor, -Z)
	block("Plaque", Vector3.new(1.4, 0.5, 0.1), 1.6, PED.Brass, false, Vector3.new(0, 0, -1.2)).Material = Enum.Material.Metal
	block("TrimHigh", Vector3.new(3.16, 0.1, 3.16), 2.12, trim, true)
	block("Cap", Vector3.new(3.1, 0.35, 3.1), 2.3, step)
	local pad = block("TrimPad", Vector3.new(2.2, 0.06, 2.2), 2.5, trim, true)
	pad.Transparency = 0.6
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			block("Corner", Vector3.new(0.45, 0.45, 0.45), 2.66, PED.Brass, false, Vector3.new(cx * 1.33, 0, cz * 1.33)).Material =
				Enum.Material.Metal
		end
	end
	ped.Parent = stand
	return ped
end

-- Suit Shop stall (a keeper visual: rebuilt from code on every dock). A blocky market stand
-- in the reference style: wooden posts and counter, a striped teal-and-white awning with a
-- scalloped lip, a SUIT SHOP sign, a brass helmet and a tank on the counter, and a glowing
-- floor disc where you stand to browse. `cf` is the floor centre; the counter faces -Z.
-- The prompt (SuitShopPrompt) opens the Suit Shop window on the client (SuitShopController).
local STALL = {
	Post = Color3.fromRGB(150, 104, 62),
	Wood = Color3.fromRGB(205, 160, 98),
	Dark = Color3.fromRGB(120, 84, 50),
	StripeA = Color3.fromRGB(63, 200, 230),
	StripeB = Color3.fromRGB(240, 248, 255),
	Brass = Color3.fromRGB(200, 150, 70),
	Glow = Color3.fromRGB(80, 230, 255),
}

local function buildSuitStall(parent: Instance, cf: CFrame)
	local stall = Instance.new("Model")
	stall.Name = "SuitShop"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, extra)
		local props = {
			Name = name,
			Size = size,
			CFrame = cf * offset,
			Color = color,
			Material = material or Enum.Material.WoodPlanks,
			Parent = stall,
		}
		for k, v in extra or {} do
			props[k] = v
		end
		return Build.Part(props)
	end
	local W, D = 8, 4
	-- posts (studded blocks: chunky square posts with a cap)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part("Post", Vector3.new(0.8, 6.4, 0.8), CFrame.new(x * (W / 2 - 0.4), 3.2, z * (D / 2 - 0.4)), STALL.Post, Enum.Material.Wood)
			part("PostCap", Vector3.new(1, 0.4, 1), CFrame.new(x * (W / 2 - 0.4), 0.2, z * (D / 2 - 0.4)), STALL.Dark, Enum.Material.Wood)
		end
	end
	-- counter (front), its top, side walls and back wall
	local counter = part("Counter", Vector3.new(W - 0.8, 2.4, 1.2), CFrame.new(0, 1.2, -D / 2 + 0.6), STALL.Wood)
	part("CounterTop", Vector3.new(W + 0.2, 0.3, 1.6), CFrame.new(0, 2.55, -D / 2 + 0.6), STALL.Dark)
	part("CounterTrim", Vector3.new(W - 0.6, 0.25, 0.1), CFrame.new(0, 2.0, -D / 2 - 0.02), STALL.Glow, Enum.Material.Neon, { CanCollide = false })
	for _, x in { -1, 1 } do
		part("SideWall", Vector3.new(0.4, 2.4, D - 1.6), CFrame.new(x * (W / 2 - 0.4), 1.2, 0.2), STALL.Wood)
	end
	part("BackWall", Vector3.new(W - 0.8, 6, 0.4), CFrame.new(0, 3, D / 2 - 0.4), STALL.Wood)
	-- awning: 8 stripes sloping down to the front, with a scalloped lip
	local slope = math.rad(14)
	local stripes = 8
	local sw = (W + 0.8) / stripes
	for i = 1, stripes do
		local x = -(W + 0.8) / 2 + sw * (i - 0.5)
		local color = if i % 2 == 1 then STALL.StripeA else STALL.StripeB
		part(
			"Awning",
			Vector3.new(sw, 0.35, D + 1.6),
			CFrame.new(x, 6.9, -0.3) * CFrame.Angles(-slope, 0, 0),
			color,
			Enum.Material.SmoothPlastic
		)
		part(
			"AwningLip",
			Vector3.new(sw, 0.6, 0.3),
			CFrame.new(x, 6.9 - math.sin(slope) * (D / 2 + 1.1) - 0.3, -0.3 - (D / 2 + 0.8) * math.cos(slope)),
			color,
			Enum.Material.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	-- sign on the roof
	local sign = part("Sign", Vector3.new(6.4, 1.5, 0.3), CFrame.new(0, 8.3, 0.6), Color3.fromRGB(28, 22, 40), Enum.Material.SmoothPlastic)
	local signFront = Build.SurfaceLabel(sign, "SUIT SHOP", Enum.NormalId.Front, Color3.fromRGB(255, 120, 220))
	signFront.Label.UIStroke.Color = Color3.fromRGB(226, 72, 196)
	-- props on the counter: a brass dive helmet with a porthole, and an air tank
	part("Helmet", Vector3.new(1.3, 1.3, 1.3), CFrame.new(-2.2, 3.35, -D / 2 + 0.6), STALL.Brass, Enum.Material.Metal, { Shape = Enum.PartType.Ball, CanCollide = false })
	part("Porthole", Vector3.new(0.12, 0.7, 0.7), CFrame.new(-2.2, 3.4, -D / 2 - 0.05) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(170, 225, 255), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.3, CanCollide = false })
	part("Tank", Vector3.new(1.6, 0.6, 0.6), CFrame.new(2.2, 3.5, -D / 2 + 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 200, 40), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	-- glow: warm bulbs along the awning lip, a light under the awning and a pink sign light
	for i = 0, 4 do
		local x = -W / 2 + 0.4 + i * (W - 0.8) / 4
		local bulb = part("Bulb", Vector3.new(0.45, 0.45, 0.45), CFrame.new(x, 6.9 - math.sin(slope) * (D / 2 + 1.1) - 0.75, -0.3 - (D / 2 + 0.8) * math.cos(slope)), Color3.fromRGB(255, 226, 150), Enum.Material.Neon, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CastShadow = false,
		})
		bulb.Name = "Bulb"
	end
	local lamp = part("AwningLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 5.6, -0.4), STALL.Glow, Enum.Material.Neon, { Transparency = 1, CanCollide = false })
	Build.Instance("PointLight", { Range = 9, Brightness = 0.5, Color = Color3.fromRGB(255, 220, 160), Shadows = false, Parent = lamp })
	Build.Instance("PointLight", { Range = 10, Brightness = 2, Color = Color3.fromRGB(255, 120, 220), Parent = sign })
	-- floor pad where you stand to browse: stepping on it opens the Suit Shop
	-- (SuitShopController watches every part tagged SuitShopDisc). A glowing ring and a disc.
	local discCf = CFrame.new(0, 0.06, -D / 2 - 3.2)
	local disc = part("BrowseDisc", Vector3.new(0.1, 5.4, 5.4), discCf * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 140, 170), Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.7,
		CanCollide = false,
		CanQuery = false,
	})
	part("BrowseRing", Vector3.new(0.08, 6.2, 6.2), discCf * CFrame.new(0, -0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), STALL.Glow, Enum.Material.Neon, {
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
	})
	Build.Instance("PointLight", { Range = 7, Brightness = 0.6, Color = STALL.Glow, Shadows = false, Parent = disc })
	CollectionService:AddTag(disc, "SuitShopDisc")
	local hint = Build.Billboard(disc, "STEP HERE", UDim2.fromOffset(120, 30), Vector3.new(0, 3.2, 0), STALL.Glow)
	hint.MaxDistance = 30
	local prompt = Build.Prompt(counter, "Browse suits", "Suit Shop", 0, "SuitShopPrompt")
	prompt.MaxActivationDistance = 10
	stall.PrimaryPart = counter
	stall.Parent = parent
	return stall
end

-- Dive station dressing (a keeper visual: rebuilt from code on every dock). Makes the plot read
-- as a working dive base instead of a bare plank: rope railings, lamp posts, a tank rack and an
-- air compressor by the diving board, a diver-down flag, a life ring, a moored dinghy and
-- buoys (tagged Bob; WaterController bobs them). Nothing sits on the stand lines or the
-- corridor. `cf` is the dock centre (top surface), local -Z points out to sea.
local DS = {
	Wood = Color3.fromRGB(96, 70, 48),
	Rope = Color3.fromRGB(214, 190, 140),
	Steel = Color3.fromRGB(70, 78, 92),
	Tank = Color3.fromRGB(250, 200, 40),
	Red = Color3.fromRGB(220, 40, 40),
	White = Color3.fromRGB(245, 245, 245),
	Lamp = Color3.fromRGB(255, 220, 150),
}

local function buildDiveStation(model: Model, cf: CFrame, size: Vector3)
	local f = Instance.new("Model")
	f.Name = "DiveStation"
	local function p(name: string, sz: Vector3, at: CFrame, color: Color3, mat: Enum.Material?, extra)
		local props = { Name = name, Size = sz, CFrame = cf * at, Color = color, Material = mat or Enum.Material.SmoothPlastic, Parent = f }
		for k, v in extra or {} do
			props[k] = v
		end
		return Build.Part(props)
	end
	local hx, hz = size.X / 2, size.Z / 2
	-- rope railings down both long sides (posts collide, ropes don't)
	for _, sx in { -1, 1 } do
		local x = sx * (hx - 0.4)
		local z = -hz + 1
		while z <= hz - 1 do
			p("RailPost", Vector3.new(0.5, 3.4, 0.5), CFrame.new(x, 1.7, z), DS.Wood, Enum.Material.Wood)
			z += 6
		end
		for _, y in { 3.1, 1.8 } do
			p("Rope", Vector3.new(size.Z - 2, 0.22, 0.22), CFrame.new(x, y, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(90), 0, 0), DS.Rope, Enum.Material.Fabric, {
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
			})
		end
	end
	-- lamp posts on the four corners
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local at = CFrame.new(sx * (hx - 0.6), 0, sz * (hz - 0.6))
			p("LampPost", Vector3.new(0.5, 7, 0.5), at * CFrame.new(0, 3.5, 0), DS.Steel, Enum.Material.Metal)
			local bulb = p("Lamp", Vector3.new(1.1, 1.1, 1.1), at * CFrame.new(0, 7.4, 0), DS.Lamp, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
			p("LampCap", Vector3.new(1.5, 0.3, 1.5), at * CFrame.new(0, 8.05, 0), DS.Steel, Enum.Material.Metal, { CanCollide = false })
			Build.Instance("PointLight", { Range = 16, Brightness = 1.2, Color = DS.Lamp, Shadows = false, Parent = bulb })
		end
	end
	-- tank rack (sea end, left): a frame with five upright air tanks (the Blender AIR_RACK when
	-- uploaded; the code rack below is hidden then)
	local rack = CFrame.new(-16, 0, -hz + 1.6)
	local rackMesh = meshProp("AIR_RACK", f, (cf * rack).Position, Random.new(1), 4, nil, cf.Rotation)
	if not rackMesh then
		p("RackBase", Vector3.new(7, 0.4, 1.6), rack * CFrame.new(0, 0.2, 0), DS.Steel, Enum.Material.DiamondPlate)
		p("RackBar", Vector3.new(7, 0.3, 0.3), rack * CFrame.new(0, 2.6, 0.6), DS.Steel, Enum.Material.Metal)
		for i = -2, 2 do
			local t = rack * CFrame.new(i * 1.35, 0, 0)
			p("Tank", Vector3.new(3, 1, 1), t * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)), if i % 2 == 0 then DS.Tank else Color3.fromRGB(240, 240, 240), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			p("Valve", Vector3.new(0.35, 0.5, 0.35), t * CFrame.new(0, 3.6, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, { CanCollide = false })
		end
	end
	-- the rack refills your air (DiveService.RefillAtRack); a glowing AIR sign marks it
	local airSign = p("AirSign", Vector3.new(3, 1, 0.2), rack * CFrame.new(0, 4.6, 0), Color3.fromRGB(20, 40, 60), Enum.Material.SmoothPlastic, { CanCollide = false })
	Build.SurfaceLabel(airSign, "AIR", Enum.NormalId.Back, Color3.fromRGB(110, 230, 255))
	Build.SurfaceLabel(airSign, "AIR", Enum.NormalId.Front, Color3.fromRGB(110, 230, 255))
	Build.Instance("PointLight", { Range = 8, Brightness = 0.8, Color = Color3.fromRGB(110, 230, 255), Shadows = false, Parent = airSign })
	local hit = p("AirRack", Vector3.new(7, 4, 3), rack * CFrame.new(0, 2, 0), DS.Steel, nil, { Transparency = 1, CanCollide = false })
	local refill = Build.Prompt(hit, "Refill air", "Tank rack", 0.6, "AirRefillPrompt")
	refill.MaxActivationDistance = 10
	-- air compressor (sea end, right): a box with a grille, gauge and a coiled hose
	local comp = CFrame.new(16, 0, -hz + 1.8)
	p("Compressor", Vector3.new(3.6, 2.4, 2.2), comp * CFrame.new(0, 1.2, 0), Color3.fromRGB(40, 120, 200), Enum.Material.Metal)
	p("Grille", Vector3.new(2.6, 1.4, 0.1), comp * CFrame.new(0, 1.3, 1.12), Color3.fromRGB(30, 30, 36), Enum.Material.DiamondPlate, { CanCollide = false })
	p("Gauge", Vector3.new(0.1, 0.8, 0.8), comp * CFrame.new(1.85, 1.8, 0) * CFrame.Angles(0, 0, 0), DS.White, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	p("HoseCoil", Vector3.new(0.5, 2.2, 2.2), comp * CFrame.new(-3, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 30, 30), Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	-- diver-down flag on the sea-end corner
	local pole = CFrame.new(-hx + 1.8, 0, -hz + 1.8)
	p("FlagPole", Vector3.new(0.4, 12, 0.4), pole * CFrame.new(0, 6, 0), DS.White, Enum.Material.Metal)
	p("Flag", Vector3.new(0.1, 2.6, 3.6), pole * CFrame.new(0, 10.4, 1.9), DS.Red, Enum.Material.Fabric, { CanCollide = false })
	p("FlagStripe", Vector3.new(0.12, 0.55, 4.2), pole * CFrame.new(0, 10.4, 1.9) * CFrame.Angles(math.rad(-35), 0, 0), DS.White, Enum.Material.Fabric, { CanCollide = false })
	-- life ring on the right railing (eight segments round a ring)
	local ring = CFrame.new(hx - 0.1, 2.4, 2) * CFrame.Angles(0, math.rad(90), 0)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		p("LifeRing", Vector3.new(0.7, 0.55, 0.45), ring * CFrame.new(math.cos(a) * 0.95, math.sin(a) * 0.95, 0) * CFrame.Angles(0, 0, a + math.pi / 2), if i % 2 == 0 then Color3.fromRGB(255, 110, 40) else DS.White, Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	-- a dinghy moored off the right side, sitting on the water
	local boat = CFrame.new(hx + 4.5, -World.DockHeight + 0.4, -4)
	p("Hull", Vector3.new(4, 0.6, 10), boat * CFrame.new(0, 0, 0), DS.White, Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, s in { -1, 1 } do
		p("HullSide", Vector3.new(0.4, 1.4, 10), boat * CFrame.new(s * 1.9, 0.6, 0), Color3.fromRGB(230, 70, 60), Enum.Material.SmoothPlastic, { CanCollide = false })
	end
	p("Bow", Vector3.new(4.2, 1.4, 0.4), boat * CFrame.new(0, 0.6, -5), Color3.fromRGB(230, 70, 60), Enum.Material.SmoothPlastic, { CanCollide = false })
	p("Seat", Vector3.new(3.4, 0.3, 1.2), boat * CFrame.new(0, 0.8, 1), DS.Wood, Enum.Material.Wood, { CanCollide = false })
	p("Motor", Vector3.new(1, 2.2, 1), boat * CFrame.new(0, 0.9, 5.3), Color3.fromRGB(40, 40, 46), Enum.Material.Metal, { CanCollide = false })
	p("MooringLine", Vector3.new(0.15, 0.15, 6.5), CFrame.new(hx + 2, -World.DockHeight / 2 + 0.5, -8.5) * CFrame.Angles(math.rad(-30), math.rad(-35), 0), DS.Rope, Enum.Material.Fabric, { CanCollide = false })
	-- buoys around the dock's sea end (WaterController bobs anything tagged Bob)
	for i, at in { Vector3.new(-hx - 6, 0, -hz - 4), Vector3.new(hx + 6, 0, -hz - 8), Vector3.new(-hx - 3, 0, hz - 6), Vector3.new(hx + 10, 0, 6) } do
		local b = p("Buoy", Vector3.new(2, 2, 2), CFrame.new(at.X, -World.DockHeight + 0.4, at.Z), if i % 2 == 0 then DS.Red else Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
		local band = p("BuoyBand", Vector3.new(0.5, 2.1, 2.1), CFrame.new(at.X, -World.DockHeight + 0.6, at.Z) * CFrame.Angles(0, 0, math.rad(90)), DS.White, Enum.Material.SmoothPlastic, {
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		CollectionService:AddTag(b, "Bob")
		CollectionService:AddTag(band, "Bob")
	end
	-- crates by the collector pad
	for i, at in { Vector3.new(-19, 1, hz - 2.2), Vector3.new(-17.2, 1, hz - 2), Vector3.new(-18.1, 3, hz - 2.1) } do
		p("Crate", Vector3.new(1.9, 2, 1.9), CFrame.new(at) * CFrame.Angles(0, math.rad(i * 9), 0), Color3.fromRGB(170, 120, 70), Enum.Material.WoodPlanks)
	end
	f.Parent = model
end

local function buildDock(index: number)
	local angle = (index - 1) / World.DockCount * math.pi * 2
	local center = Vector3.new(math.cos(angle) * World.DockRingRadius, SURFACE + World.DockHeight, math.sin(angle) * World.DockRingRadius)
	-- Dock faces outward (look away from the plaza); local -Z points to the open ocean
	local cf = CFrame.lookAt(center, center + Vector3.new(center.X, 0, center.Z).Unit)
	local model = Instance.new("Model")
	model.Name = "Dock" .. index
	model.Parent = root.Docks

	local size = World.DockSize
	local platform = Build.Part({
		Name = "Platform",
		Size = size,
		CFrame = cf * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(150, 115, 80),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	model.PrimaryPart = platform
	-- Pillars into the water
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Build.Part({
				Name = "Pillar",
				Size = Vector3.new(2, World.DockHeight + 20, 2),
				CFrame = cf * CFrame.new(x * (size.X / 2 - 2), -(World.DockHeight + 20) / 2, z * (size.Z / 2 - 2)),
				Color = Color3.fromRGB(90, 70, 50),
				Material = Enum.Material.Wood,
				Parent = model,
			})
		end
	end
	-- Walkway to the plaza
	local inner = cf * CFrame.new(0, -1, size.Z / 2)
	local plazaEdge = Vector3.new(0, inner.Position.Y, 0) + (Vector3.new(center.X, 0, center.Z).Unit * World.PlazaRadius)
	local walkLen = (inner.Position - plazaEdge).Magnitude
	Build.Part({
		Name = "Walkway",
		Size = Vector3.new(6, 1, walkLen),
		CFrame = CFrame.lookAt((inner.Position + plazaEdge) / 2, plazaEdge),
		Color = Color3.fromRGB(130, 100, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Diving board on the ocean side: jump off it to launch and plunge (SwimController).
	-- "DiveRamp" is the board you stand on; its LookVector points out to sea. The owner's
	-- Diving Board upgrade level re-skins it (DockService.RefreshDock).
	local boardCf = cf * CFrame.new(0, 0.6, -size.Z / 2 - 6) * CFrame.Angles(math.rad(8), 0, 0)
	local board = Build.Part({
		Name = "DiveRamp",
		Size = Vector3.new(5, 0.6, 14),
		CFrame = boardCf,
		Color = Color3.fromRGB(120, 92, 64),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	board:SetAttribute("DiveBoard", true)
	Build.Part({
		Name = "BoardTrim",
		Size = Vector3.new(5.2, 0.25, 1.2),
		CFrame = boardCf * CFrame.new(0, 0.3, -6.4),
		Color = Color3.fromRGB(63, 214, 230),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	for _, x in { -1.8, 1.8 } do
		Build.Part({
			Name = "BoardPost",
			Size = Vector3.new(0.6, 6, 0.6),
			CFrame = cf * CFrame.new(x, -2.4, -size.Z / 2 - 2),
			Color = Color3.fromRGB(90, 70, 50),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	Build.Billboard(board, "JUMP TO DIVE", UDim2.fromOffset(170, 34), Vector3.new(0, 3, -4), Color3.fromRGB(63, 214, 230)).MaxDistance = 40

	-- Entrance arch: the dock's name board rides high on two posts over the walkway, so it
	-- never blocks the view of the dock (it used to stand at head height mid-entrance).
	local archZ = size.Z / 2 - 1
	for _, x in { -9.2, 9.2 } do
		Build.Part({ Name = "ArchPost", Size = Vector3.new(1.4, 17, 1.4), CFrame = cf * CFrame.new(x, 8.5, archZ), Color = Color3.fromRGB(70, 52, 38), Material = Enum.Material.Wood, Parent = model })
		Build.Part({ Name = "ArchCap", Size = Vector3.new(2, 0.8, 2), CFrame = cf * CFrame.new(x, 17.3, archZ), Color = Color3.fromRGB(230, 180, 70), Material = Enum.Material.Metal, Parent = model })
	end
	Build.Part({ Name = "ArchBeam", Size = Vector3.new(20, 1, 1.4), CFrame = cf * CFrame.new(0, 16.2, archZ), Color = Color3.fromRGB(70, 52, 38), Material = Enum.Material.Wood, Parent = model })
	local sign = Build.Part({
		Name = "Sign",
		Size = Vector3.new(16, 4.6, 0.8),
		CFrame = cf * CFrame.new(0, 13.3, archZ),
		Color = Color3.fromRGB(22, 30, 48),
		Parent = model,
	})
	for _, y in { 2.45, -2.45 } do
		Build.Part({ Name = "SignTrim", Size = Vector3.new(16.4, 0.3, 1), CFrame = sign.CFrame * CFrame.new(0, y, 0), Color = Color3.fromRGB(63, 214, 230), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false, Parent = model })
	end
	buildDiveStation(model, cf, size)
	-- Sign board faces the walkway (+Z, the plaza side); painted on, not a floating label
	Build.SurfaceLabel(sign, "Empty Dock", Enum.NormalId.Back).Name = "SignFront"
	Build.SurfaceLabel(sign, "Empty Dock", Enum.NormalId.Front).Name = "SignBack"

	-- Stands line both long sides of the dock, leaving a clear corridor from the spawn to the
	-- diving board. Three lines per side (outer, middle, inner) of six pedestals each. They fill
	-- outer lines first, from the plaza end toward the sea, alternating left and right, so the
	-- first stands a new player owns sit by the spawn. Each pedestal faces the corridor.
	local stands = {}
	local lines = { size.X / 2 - 5, size.X / 2 - 11.5, size.X / 2 - 18 }
	local rowsZ = { 12, 6.8, 1.6, -3.6, -8.8, -14 }
	local slots = {}
	for _, lx in lines do
		for _, z in rowsZ do
			table.insert(slots, { x = -lx, z = z, yaw = -90 })
			table.insert(slots, { x = lx, z = z, yaw = 90 })
		end
	end
	for i = 1, World.MaxStands do
		local s = slots[i]
		local standCf = cf * CFrame.new(s.x, PEDESTAL_HEIGHT / 2, s.z) * CFrame.Angles(0, math.rad(s.yaw), 0)
		local stand = Build.Part({
			Name = "Stand" .. i,
			Size = Vector3.new(3, PEDESTAL_HEIGHT, 3),
			CFrame = standCf,
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		stand:SetAttribute("StandIndex", i)
		buildPedestal(stand, false)
		-- Short reach: stands are ~5 studs apart, so you act on the one you're standing at.
		-- The relic's facts show in a client hover card (StandHoverController), not a label.
		local place = Build.Prompt(stand, "Display", "Stand " .. i, 0, "Place")
		place.Enabled = false
		place.MaxActivationDistance = STAND_REACH
		local steal = Build.Prompt(stand, "Steal", "Relic", 2.5, "Steal")
		steal.Enabled = false
		steal.KeyboardKeyCode = Enum.KeyCode.F
		steal.UIOffset = Vector2.new(0, 60)
		steal.MaxActivationDistance = STAND_REACH
		stands[i] = stand
	end
	-- Vault stands (§8.1): gold pedestals flanking the way to the diving board
	local vault = {}
	for i = 1, 2 do
		local sx = if i == 1 then -1 else 1
		local stand = Build.Part({
			Name = "Vault" .. i,
			Size = Vector3.new(3, PEDESTAL_HEIGHT, 3),
			CFrame = cf * CFrame.new(sx * 6, PEDESTAL_HEIGHT / 2, -size.Z / 2 + 5) * CFrame.Angles(0, math.rad(180), 0),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		stand:SetAttribute("VaultIndex", i)
		buildPedestal(stand, true)
		local place = Build.Prompt(stand, "Vault", "Vault " .. i, 0, "Place")
		place.Enabled = false
		place.MaxActivationDistance = STAND_REACH
		vault[i] = stand
	end

	-- Coin collector pad (§8.1)
	local pad = Build.Part({
		Name = "CollectorPad",
		Size = Vector3.new(5, 0.6, 5),
		CFrame = cf * CFrame.new(-size.X / 2 + 3, 0.3, size.Z / 2 - 4),
		Color = Color3.fromRGB(60, 230, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local padGui = Build.Billboard(pad, "0", UDim2.fromOffset(160, 40), Vector3.new(0, 4, 0), Color3.fromRGB(120, 255, 160))
	padGui.Name = "PadGui"
	padGui.MaxDistance = 80

	-- Laser gate visual (§8.4)
	local gate = Build.Part({
		Name = "LaserGate",
		Size = Vector3.new(size.X + 2, 16, size.Z + 2),
		CFrame = cf * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local gateButton = Build.Part({
		Name = "GateButton",
		Size = Vector3.new(2, 3, 2),
		CFrame = cf * CFrame.new(size.X / 2 - 2, 1.5, size.Z / 2 - 4),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local gatePrompt = Build.Prompt(gateButton, "Activate Laser Gate", "Dock Defense", 0, "GatePrompt")
	gatePrompt.Enabled = false

	-- Suit Shop stall at the plaza end, right of the spawn, its counter facing the corridor
	buildSuitStall(model, cf * CFrame.new(size.X / 2 - 12, 0, size.Z / 2 - 3.6) * CFrame.Angles(0, math.rad(90), 0))
end

function WorldService.GetDocks()
	return docks
end

function WorldService.GetAirPockets()
	return airPockets
end

-- Is a world position inside a dock's raid area?
function WorldService.IsInsideDock(dock, position: Vector3, margin: number?): boolean
	local rel = dock.CFrame:PointToObjectSpace(position)
	local size = World.DockSize
	local m = margin or 2
	return math.abs(rel.X) <= size.X / 2 + m and math.abs(rel.Z) <= size.Z / 2 + m and rel.Y > -9 and rel.Y < 30
end

-- Landmark luck (§6): is a point within `radius` of one of this zone's landmarks?
function WorldService.IsNearLandmark(position: Vector3, zoneIndex: number, radius: number): boolean
	for _, lm in landmarks do
		if lm.zone == zoneIndex and (lm.pos - position).Magnitude <= radius then
			return true
		end
	end
	return false
end

function WorldService.DepthOf(position: Vector3): number
	return SURFACE - position.Y
end

-- A spawn point inside a zone. Prefers a surface (shelf, ledge, landmark) so loot sits on
-- something instead of floating; `freeWater` asks for an open-water point (creatures).
function WorldService.RandomPointInZone(zoneIndex: number, r: Random?, freeWater: boolean?): Vector3
	local zone = Zones.List[zoneIndex]
	local g = r or rng
	local list = anchors[zoneIndex]
	if not freeWater and list and #list > 0 then
		-- try a few surface points and keep the first that isn't inside a coral, kelp bed or
		-- wreck prop (relics used to spawn hidden inside brain corals)
		local p
		for _ = 1, 24 do
			local a = list[g:NextInteger(1, #list)]
			local ang = g:NextNumber(0, math.pi * 2)
			local d = g:NextNumber(0, a.radius)
			p = a.pos + Vector3.new(math.cos(ang) * d, 1.4, math.sin(ang) * d)
			if clearOfProps(zoneIndex, p) then
				return p
			end
		end
		return p
	end
	local depth = g:NextNumber(zone.MinDepth + 8, zone.MaxDepth - 8)
	return Vector3.new(g:NextNumber(-R + 20, R - 20), SURFACE - depth, g:NextNumber(-R + 20, R - 20))
end

-- Studio's "Baseplate" template leaves a 2048-stud Baseplate at Y=0 and a SpawnLocation.
-- The baseplate sits exactly at the water line: it z-fights with the sea (the flickering
-- colours) and its grid texture shows through underwater. Remove both.
local function removeTemplateLeftovers()
	for _, child in Workspace:GetChildren() do
		if (child.Name == "Baseplate" and child:IsA("BasePart")) or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
end

local RUNTIME_FOLDERS = { "Docks", "Relics", "Nodes", "Creatures", "Drops" }

-- Build the whole map from code into a fresh AbyssWorld folder (no gameplay wiring).
local function buildAll()
	root = folder("AbyssWorld", Workspace)
	for _, name in RUNTIME_FOLDERS do
		folder(name, root)
	end
	-- load uploaded Blender props first (none yet = code versions), then build
	if services and services.RelicMeshService and services.RelicMeshService.EnsureWorldMeshes then
		pcall(services.RelicMeshService.EnsureWorldMeshes)
	end
	buildOcean()
	buildPlaza()
	for i = 1, World.DockCount do
		buildDock(i)
	end
end

-- Read the gameplay data back from the instances, so a map edited by hand in Studio works:
-- docks from Docks/DockN, loot anchors from LootAnchor attachments, prop spots from Prop
-- models, landmarks from Landmark parts, air pockets from AirPocket parts.
local function scan()
	table.clear(docks)
	table.clear(airPockets)
	table.clear(landmarks)
	table.clear(anchors)
	table.clear(propSpots)

	for _, d in root:GetDescendants() do
		if d:IsA("Attachment") and d.Name == "LootAnchor" then
			local z = d:GetAttribute("Zone")
			if z then
				anchors[z] = anchors[z] or {}
				table.insert(anchors[z], { pos = d.WorldPosition, radius = d:GetAttribute("Radius") or 5 })
			end
		elseif d:IsA("Model") and d.Name == "Prop" and d:GetAttribute("Zone") then
			local z = d:GetAttribute("Zone")
			propSpots[z] = propSpots[z] or {}
			table.insert(propSpots[z], d:GetPivot().Position)
		elseif d:IsA("BasePart") and d.Name == "Landmark" and d:GetAttribute("Zone") then
			table.insert(landmarks, { pos = d.Position, zone = d:GetAttribute("Zone") })
		elseif d:IsA("BasePart") and d.Name == "AirPocket" then
			table.insert(airPockets, d)
		end
	end

	local size = World.DockSize
	for _, model in root.Docks:GetChildren() do
		local index = tonumber(model.Name:match("^Dock(%d+)$"))
		local platform = model:FindFirstChild("Platform")
		if not (index and model:IsA("Model") and platform) then
			continue
		end
		-- the platform sits 1 stud below the dock's frame (buildDock)
		local cf = platform.CFrame * CFrame.new(0, 1, 0)
		local stands, vault = {}, {}
		for i = 1, World.MaxStands do
			stands[i] = model:FindFirstChild("Stand" .. i)
		end
		for i = 1, 2 do
			vault[i] = model:FindFirstChild("Vault" .. i)
		end
		local pad = model:FindFirstChild("CollectorPad")
		local sign = model:FindFirstChild("Sign")
		local gateButton = model:FindFirstChild("GateButton")
		docks[index] = {
			Index = index,
			CFrame = cf,
			Model = model,
			Platform = platform,
			Stands = stands,
			Vault = vault,
			Pad = pad,
			PadLabel = pad and pad:FindFirstChild("PadGui") and pad.PadGui.Label,
			Sign = sign and sign:FindFirstChild("SignFront") and sign.SignFront.Label,
			Gate = model:FindFirstChild("LaserGate"),
			GatePrompt = gateButton and gateButton:FindFirstChild("GatePrompt"),
			Board = model:FindFirstChild("DiveRamp"),
			SpawnCFrame = cf * CFrame.new(0, 4, size.Z / 2 - 4) * CFrame.Angles(0, math.rad(180), 0),
			Owner = nil,
		}
	end
end

-- Gameplay hooks on world objects. Runs after build or adoption (connections are not saved
-- with the place, so a baked map needs them made here).
local function wire()
	local Net = require(Shared.Net)
	for _, d in root:GetDescendants() do
		if d:IsA("BillboardGui") then
			Build.WireAutoHide(d)
		end
	end

	local plaza = root:FindFirstChild("Plaza")
	local totem = plaza and plaza:FindFirstChild("LuckTotem")
	local luck = totem and totem:FindFirstChild("LuckPrompt")
	if luck then
		luck.Triggered:Connect(function(player)
			Net.Offer:FireClient(player, "ServerLuck")
		end)
	end
	local door = plaza and plaza:FindFirstChild("VipDoor")
	local vip = door and door:FindFirstChild("VipPrompt")
	if vip then
		vip.Triggered:Connect(function(player)
			if services.MonetizationService.Owns(player, "VIP") then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local lounge = plaza:FindFirstChild("VipLounge")
				if hrp and lounge then
					services.SecurityService.AllowTeleport(player)
					char:PivotTo(lounge.CFrame + Vector3.new(0, 4, 0))
				end
			else
				Net.Offer:FireClient(player, "VIP")
			end
		end)
	end

	for _, dock in docks do
		for _, d in dock.Model:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "AirRefillPrompt" then
				d.Triggered:Connect(function(player)
					services.DiveService.RefillAtRack(player)
				end)
			end
		end
		-- the sign is painted on both faces: mirror the front text onto the back
		local sign = dock.Model:FindFirstChild("Sign")
		local back = sign and sign:FindFirstChild("SignBack")
		if dock.Sign and back then
			dock.Sign:GetPropertyChangedSignal("Text"):Connect(function()
				back.Label.Text = dock.Sign.Text
			end)
		end
	end
end

function WorldService.Start()
	removeTemplateLeftovers()
	local baked = Workspace:FindFirstChild("AbyssWorld")
	if baked and baked:GetAttribute("Baked") then
		-- The map was saved in the place (edited in Studio): use it as it is.
		root = baked
		for _, name in RUNTIME_FOLDERS do
			if not root:FindFirstChild(name) then
				folder(name, root)
			end
		end
		if services.RelicMeshService and services.RelicMeshService.EnsureWorldMeshes then
			pcall(services.RelicMeshService.EnsureWorldMeshes)
		end
	else
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Lighting.FogStart = 0
		Lighting.FogEnd = 2000
		buildAll()
	end
	scan()
	wire()
end

-- Edit mode only (Studio command bar / MCP): build the map into the place so it can be
-- edited by hand and saved. Replaces an existing AbyssWorld. Gameplay then adopts it.
function WorldService.Bake(meshService)
	local old = Workspace:FindFirstChild("AbyssWorld")
	if old then
		old:Destroy()
	end
	removeTemplateLeftovers()
	services = services or { RelicMeshService = meshService }
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.FogStart = 0
	Lighting.FogEnd = 2000
	buildAll()
	root:SetAttribute("Baked", true)
	return root
end

function WorldService.Root(): Folder
	return root
end

return WorldService
