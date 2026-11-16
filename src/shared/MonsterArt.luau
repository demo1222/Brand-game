-- MonsterArt: the zone guardians' bodies (Config/Monsters), built on the client by
-- GuardianController. Blocky cartoon style to match the relics and suits.
--
--   MonsterArt.Build(def) -> { model = Model, pieces = { {part, offset, role, index?} } }
--
-- The creature faces -Z and is `def.Length` studs long. Every piece is an anchored part placed
-- each frame at rootCFrame * (animation) * offset. Roles:
--   body   rigid
--   tail   wags side to side (faster when chasing)
--   jaw    opens during WindUp and Lunge
--   seg    serpent body segment `index`, follows the head's trail
--   glow   rigid, Neon (eyes, lures, magma cracks)
--
-- Blender models: if ReplicatedStorage.WorldMeshes holds a model named after the monster Id
-- (models/monsters/<Id>.glb, uploaded like the relic bundles), it is used instead. Its parts
-- are rigid except those whose name contains _Tail (wag) or _Jaw (opens). The serpent keeps
-- its code body (its segments follow a trail), so it has no Blender model.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterArt = {}

local function newPart(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): BasePart
	local p: BasePart
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if shape == "Ball" then
			(p :: Part).Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			(p :: Part).Shape = Enum.PartType.Cylinder
		end
	end
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "Egg" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

local rad = math.rad

-- A builder: add(name, size, offset, color, material?, shape?, role?, index?)
local function builder(model: Model)
	local pieces = {}
	local function add(name, size, offset, color, material, shape, role, index)
		local p = newPart(model, name, size, color, material, shape)
		table.insert(pieces, { p, offset, role or "body", index })
		return p
	end
	return pieces, add
end

local function teeth(add, L: number, count: number, from: Vector3, to: Vector3, size: number, down: boolean, role: string?)
	for i = 0, count - 1 do
		local t = if count > 1 then i / (count - 1) else 0.5
		local at = from:Lerp(to, t)
		add("Tooth", Vector3.new(size, size * 1.6, size), CFrame.new(at) * CFrame.Angles(if down then rad(180) else 0, 0, 0), Color3.fromRGB(250, 248, 235), Enum.Material.SmoothPlastic, "Wedge", role)
	end
end

local ART = {}

ART.shark = function(add, L: number, c, def)
	add("Body", Vector3.new(0.3 * L, 0.3 * L, 0.78 * L), CFrame.new(0, 0, 0), c.Body, nil, "Egg")
	add("Belly", Vector3.new(0.27 * L, 0.2 * L, 0.62 * L), CFrame.new(0, -0.07 * L, -0.03 * L), c.Belly, nil, "Egg")
	add("Snout", Vector3.new(0.22 * L, 0.17 * L, 0.3 * L), CFrame.new(0, 0.0, -0.4 * L), c.Body, nil, "Egg")
	local jaw = CFrame.new(0, -0.1 * L, -0.36 * L)
	add("Jaw", Vector3.new(0.19 * L, 0.05 * L, 0.2 * L), jaw, c.Belly, nil, nil, "jaw")
	teeth(add, L, 5, Vector3.new(-0.07 * L, -0.07 * L, -0.43 * L), Vector3.new(0.07 * L, -0.07 * L, -0.43 * L), 0.025 * L, false, "jaw")
	teeth(add, L, 5, Vector3.new(-0.07 * L, -0.06 * L, -0.45 * L), Vector3.new(0.07 * L, -0.06 * L, -0.45 * L), 0.025 * L, true)
	for _, sx in { -1, 1 } do
		add("Eye", Vector3.one * 0.05 * L, CFrame.new(sx * 0.1 * L, 0.04 * L, -0.38 * L), c.Eye, if c.EyeGlow then Enum.Material.Neon else nil, "Ball", if c.EyeGlow then "glow" else "body")
		for g = 0, 2 do
			add("Gill", Vector3.new(0.01 * L, 0.1 * L, 0.012 * L), CFrame.new(sx * 0.145 * L, 0, (-0.24 + g * 0.04) * L) * CFrame.Angles(0, 0, sx * rad(10)), c.Accent)
		end
		add("Pectoral", Vector3.new(0.03 * L, 0.06 * L, 0.2 * L), CFrame.new(sx * 0.2 * L, -0.11 * L, -0.12 * L) * CFrame.Angles(0, sx * rad(-20), sx * rad(-60)), c.Body, nil, "Wedge")
		if def.Scars then
			for k = 0, 2 do
				add("Scar", Vector3.new(0.01 * L, 0.012 * L, 0.12 * L), CFrame.new(sx * 0.152 * L, (0.06 - k * 0.04) * L, (-0.05 + k * 0.05) * L) * CFrame.Angles(rad(20 + k * 10), 0, 0), c.Accent)
			end
		end
	end
	add("Dorsal", Vector3.new(0.035 * L, 0.26 * L, 0.24 * L), CFrame.new(0, 0.25 * L, 0.0), c.Body, nil, "Wedge")
	add("TailStem", Vector3.new(0.14 * L, 0.14 * L, 0.32 * L), CFrame.new(0, 0.01 * L, 0.42 * L), c.Body, nil, "Egg", "tail")
	add("TailTop", Vector3.new(0.03 * L, 0.3 * L, 0.18 * L), CFrame.new(0, 0.14 * L, 0.6 * L) * CFrame.Angles(rad(-35), 0, 0), c.Body, nil, nil, "tail")
	add("TailLow", Vector3.new(0.03 * L, 0.18 * L, 0.13 * L), CFrame.new(0, -0.08 * L, 0.57 * L) * CFrame.Angles(rad(40), 0, 0), c.Body, nil, nil, "tail")
end

ART.barracuda = function(add, L: number, c)
	add("Body", Vector3.new(0.14 * L, 0.16 * L, 0.82 * L), CFrame.new(0, 0, 0), c.Body, Enum.Material.Metal, "Egg")
	add("Belly", Vector3.new(0.12 * L, 0.08 * L, 0.66 * L), CFrame.new(0, -0.04 * L, -0.02 * L), c.Belly, nil, "Egg")
	add("Head", Vector3.new(0.12 * L, 0.12 * L, 0.22 * L), CFrame.new(0, 0.01 * L, -0.43 * L), c.Body, Enum.Material.Metal, "Egg")
	add("Jaw", Vector3.new(0.08 * L, 0.035 * L, 0.24 * L), CFrame.new(0, -0.05 * L, -0.48 * L), c.Belly, nil, nil, "jaw")
	teeth(add, L, 7, Vector3.new(0, -0.03 * L, -0.38 * L), Vector3.new(0, -0.03 * L, -0.58 * L), 0.018 * L, false, "jaw")
	for _, sx in { -1, 1 } do
		add("Eye", Vector3.one * 0.04 * L, CFrame.new(sx * 0.05 * L, 0.03 * L, -0.45 * L), c.Eye, Enum.Material.Neon, "Ball", "glow")
		for k = 0, 5 do
			add("Bar", Vector3.new(0.01 * L, 0.1 * L, 0.03 * L), CFrame.new(sx * 0.068 * L, 0.02 * L, (-0.25 + k * 0.09) * L), c.Accent)
		end
		add("Pectoral", Vector3.new(0.02 * L, 0.04 * L, 0.1 * L), CFrame.new(sx * 0.08 * L, -0.05 * L, -0.2 * L) * CFrame.Angles(0, sx * rad(-25), sx * rad(-50)), c.Body, nil, "Wedge")
	end
	add("Dorsal1", Vector3.new(0.02 * L, 0.1 * L, 0.1 * L), CFrame.new(0, 0.11 * L, -0.08 * L), c.Accent, nil, "Wedge")
	add("Dorsal2", Vector3.new(0.02 * L, 0.08 * L, 0.08 * L), CFrame.new(0, 0.1 * L, 0.2 * L), c.Accent, nil, "Wedge")
	add("TailStem", Vector3.new(0.07 * L, 0.08 * L, 0.18 * L), CFrame.new(0, 0, 0.45 * L), c.Body, Enum.Material.Metal, "Egg", "tail")
	add("TailTop", Vector3.new(0.02 * L, 0.18 * L, 0.11 * L), CFrame.new(0, 0.08 * L, 0.55 * L) * CFrame.Angles(rad(-40), 0, 0), c.Accent, nil, nil, "tail")
	add("TailLow", Vector3.new(0.02 * L, 0.18 * L, 0.11 * L), CFrame.new(0, -0.08 * L, 0.55 * L) * CFrame.Angles(rad(40), 0, 0), c.Accent, nil, nil, "tail")
end

ART.angler = function(add, L: number, c)
	add("Body", Vector3.new(0.6 * L, 0.55 * L, 0.62 * L), CFrame.new(0, 0, 0), c.Body, nil, "Egg")
	add("Belly", Vector3.new(0.5 * L, 0.3 * L, 0.5 * L), CFrame.new(0, -0.14 * L, -0.04 * L), c.Belly, nil, "Egg")
	-- the huge underbite: a jaw slab with needle teeth pointing up, and fangs hanging down
	add("Jaw", Vector3.new(0.56 * L, 0.12 * L, 0.36 * L), CFrame.new(0, -0.2 * L, -0.24 * L), c.Belly, nil, nil, "jaw")
	add("Mouth", Vector3.new(0.5 * L, 0.18 * L, 0.05 * L), CFrame.new(0, -0.1 * L, -0.4 * L), Color3.fromRGB(10, 6, 14))
	teeth(add, L, 7, Vector3.new(-0.24 * L, -0.11 * L, -0.4 * L), Vector3.new(0.24 * L, -0.11 * L, -0.4 * L), 0.05 * L, false, "jaw")
	teeth(add, L, 6, Vector3.new(-0.21 * L, -0.02 * L, -0.38 * L), Vector3.new(0.21 * L, -0.02 * L, -0.38 * L), 0.05 * L, true)
	for _, sx in { -1, 1 } do
		add("Eye", Vector3.one * 0.07 * L, CFrame.new(sx * 0.18 * L, 0.12 * L, -0.26 * L), c.Eye, Enum.Material.Neon, "Ball", "glow")
		add("Pectoral", Vector3.new(0.03 * L, 0.18 * L, 0.16 * L), CFrame.new(sx * 0.3 * L, -0.06 * L, 0.04 * L) * CFrame.Angles(0, 0, sx * rad(-30)), c.Body, nil, "Wedge", "tail")
		for k = 0, 3 do
			add("Spot", Vector3.one * 0.03 * L, CFrame.new(sx * 0.29 * L, (0.1 - k * 0.07) * L, (0.05 + k * 0.03) * L), c.Accent, Enum.Material.Neon, "Ball", "glow")
		end
	end
	-- the lure: a stalk arching forward from the head and a glowing bulb
	add("Stalk1", Vector3.new(0.03 * L, 0.28 * L, 0.03 * L), CFrame.new(0, 0.38 * L, -0.12 * L) * CFrame.Angles(rad(-25), 0, 0), c.Body)
	add("Stalk2", Vector3.new(0.025 * L, 0.22 * L, 0.025 * L), CFrame.new(0, 0.5 * L, -0.32 * L) * CFrame.Angles(rad(-80), 0, 0), c.Body)
	local bulb = add("Lure", Vector3.one * 0.09 * L, CFrame.new(0, 0.46 * L, -0.44 * L), c.Accent, Enum.Material.Neon, "Ball", "glow")
	local light = Instance.new("PointLight")
	light.Range = L * 2
	light.Brightness = 2
	light.Color = c.Accent
	light.Parent = bulb
	add("Dorsal", Vector3.new(0.03 * L, 0.16 * L, 0.24 * L), CFrame.new(0, 0.3 * L, 0.12 * L), c.Accent, nil, "Wedge")
	add("TailStem", Vector3.new(0.18 * L, 0.18 * L, 0.24 * L), CFrame.new(0, 0, 0.36 * L), c.Body, nil, "Egg", "tail")
	add("TailFan", Vector3.new(0.03 * L, 0.36 * L, 0.2 * L), CFrame.new(0, 0, 0.5 * L), c.Body, nil, nil, "tail")
end

ART.serpent = function(add, L: number, c)
	-- head (the root), then 11 body segments that follow its trail
	add("Head", Vector3.new(0.12 * L, 0.1 * L, 0.16 * L), CFrame.new(0, 0, 0), c.Body, Enum.Material.Basalt)
	add("Snout", Vector3.new(0.09 * L, 0.06 * L, 0.08 * L), CFrame.new(0, -0.005 * L, -0.1 * L), c.Body, Enum.Material.Basalt)
	add("Jaw", Vector3.new(0.09 * L, 0.025 * L, 0.12 * L), CFrame.new(0, -0.05 * L, -0.07 * L), c.Belly, Enum.Material.Basalt, nil, "jaw")
	teeth(add, L, 4, Vector3.new(-0.035 * L, -0.035 * L, -0.12 * L), Vector3.new(0.035 * L, -0.035 * L, -0.12 * L), 0.015 * L, false, "jaw")
	for _, sx in { -1, 1 } do
		add("Eye", Vector3.one * 0.022 * L, CFrame.new(sx * 0.05 * L, 0.03 * L, -0.06 * L), c.Eye, Enum.Material.Neon, "Ball", "glow")
		add("Horn", Vector3.new(0.015 * L, 0.08 * L, 0.04 * L), CFrame.new(sx * 0.04 * L, 0.07 * L, 0.03 * L) * CFrame.Angles(rad(-35), 0, sx * rad(-20)), c.Accent, Enum.Material.Neon, "Wedge", "glow")
	end
	add("Crack", Vector3.new(0.02 * L, 0.01 * L, 0.12 * L), CFrame.new(0, 0.05 * L, 0.01 * L), c.Accent, Enum.Material.Neon, nil, "glow")
	local n = 11
	for i = 1, n do
		local t = i / n
		local s = (0.1 - t * 0.065) * L
		add("Segment", Vector3.new(s, s * 0.9, s * 1.25), CFrame.new(), c.Body, Enum.Material.Basalt, "Egg", "seg", i)
		add("SegCrack", Vector3.new(s * 0.22, s * 0.12, s * 0.9), CFrame.new(0, s * 0.42, 0), c.Accent, Enum.Material.Neon, nil, "seg", i)
		if i % 3 == 0 then
			add("Spike", Vector3.new(s * 0.15, s * 0.6, s * 0.4), CFrame.new(0, s * 0.6, 0), c.Accent, Enum.Material.Neon, "Wedge", "seg", i)
		end
	end
end

local function fromTemplate(template: Model, def)
	local model = template:Clone()
	require(script.Parent.Config.WorldMeshes).Paint(model, def.Id)
	local _, size = model:GetBoundingBox()
	local k = def.Length / math.max(size.Z, size.X, 0.01)
	model:ScaleTo(model:GetScale() * k)
	-- Blender models face +Y, which Studio imports as +Z; turn them so the front is -Z
	local cf = model:GetBoundingBox() * CFrame.Angles(0, math.pi, 0)
	local pieces = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			-- <ID>_Tail / _TailFin wag, <ID>_Jaw / _JawTeeth open
			local role = if p.Name:find("_Tail", 1, true) then "tail" elseif p.Name:find("_Jaw", 1, true) then "jaw" else "body"
			table.insert(pieces, { p, cf:ToObjectSpace(p.CFrame), role })
		end
	end
	return pieces
end

function MonsterArt.Build(def)
	local model = Instance.new("Model")
	model.Name = def.Id
	local folder = ReplicatedStorage:FindFirstChild("WorldMeshes")
	local template = folder and folder:FindFirstChild(def.Id)
	if template and template:IsA("Model") then
		local pieces = fromTemplate(template, def)
		for _, piece in pieces do
			piece[1].Parent = model
		end
		return { model = model, pieces = pieces, segments = 0 }
	end
	local pieces, add = builder(model)
	local art = ART[def.Art] or ART.shark
	art(add, def.Length, def.Colors, def)
	local segments = 0
	for _, piece in pieces do
		if piece[3] == "seg" then
			segments = math.max(segments, piece[4])
		end
	end
	return { model = model, pieces = pieces, segments = segments }
end

return MonsterArt
