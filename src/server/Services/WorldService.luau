-- WorldService: generates the graybox world at runtime (Master Plan §6, §8.1, §19).
-- Ocean volume with five depth zones, a central Harbor plaza, a ring of 16 docks, air pockets,
-- zone landmarks and plaza props (leaderboards, Server Luck Totem, VIP lounge).
-- Replace with art kits later; services only depend on the dock/zone data exposed here.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Build = require(script.Parent.Parent.Util.Build)
local RelicArt = require(Shared.RelicArt)

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

local function addAnchor(zoneIndex: number, pos: Vector3, radius: number)
	anchors[zoneIndex] = anchors[zoneIndex] or {}
	table.insert(anchors[zoneIndex], { pos = pos, radius = radius })
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
PROPS[1] = function(parent, p: Vector3, g: Random)
	local kind = g:NextInteger(1, 4)
	local hue = ({ Color3.fromRGB(255, 120, 130), Color3.fromRGB(255, 170, 70), Color3.fromRGB(180, 100, 255), Color3.fromRGB(255, 220, 120) })[g:NextInteger(1, 4)]
	if kind == 1 then -- brain coral
		local d = g:NextNumber(7, 13)
		deco({ Name = "BrainCoral", Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = CFrame.new(p + Vector3.new(0, d * 0.3, 0)), Color = hue, Material = Enum.Material.Sand, Parent = parent })
	elseif kind == 2 then -- staghorn
		for i = 1, 4 do
			local h = g:NextNumber(7, 15)
			local base = CFrame.new(p) * CFrame.Angles(0, i * 1.6, math.rad(g:NextNumber(10, 35)))
			deco({ Name = "Staghorn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.5, 1.5), CFrame = base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = hue, Material = Enum.Material.SmoothPlastic, Parent = parent })
		end
	elseif kind == 3 then -- sea fan
		local h = g:NextNumber(9, 16)
		deco({ Name = "SeaFan", Size = Vector3.new(h, h, 0.3), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, g:NextNumber(0, 6), 0), Color = hue, Material = Enum.Material.Fabric, Transparency = 0.15, Parent = parent })
	else -- anemone
		deco({ Name = "Anemone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 3, 3), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 60, 110), Parent = parent })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			deco({ Name = "Tentacle", Size = Vector3.new(0.4, 2.2, 0.4), CFrame = CFrame.new(p + Vector3.new(math.cos(a) * 1.1, 3, math.sin(a) * 1.1)) * CFrame.Angles(math.cos(a) * 0.4, 0, -math.sin(a) * 0.4), Color = hue, Material = Enum.Material.Neon, Parent = parent })
		end
	end
end
PROPS[2] = function(parent, p: Vector3, g: Random)
	-- kelp strand: wavy stack of blades
	local segs = g:NextInteger(3, 6)
	local pos = p
	for i = 1, segs do
		local len = g:NextNumber(5, 8)
		local tilt = math.sin(i * 0.9 + p.X) * 0.25
		local cfr = CFrame.new(pos) * CFrame.Angles(tilt, 0, tilt * 0.6)
		deco({ Name = "Kelp", Size = Vector3.new(1.4, len, 0.3), CFrame = cfr * CFrame.new(0, len / 2, 0), Color = Color3.fromRGB(50, 120 + i * 6, 60), Material = Enum.Material.Grass, Parent = parent })
		if i % 3 == 0 then
			deco({ Name = "Bladder", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = cfr * CFrame.new(0.9, len * 0.7, 0), Color = Color3.fromRGB(150, 140, 60), Parent = parent })
		end
		pos = (cfr * CFrame.new(0, len, 0)).Position
	end
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

local function buildOcean()
	local ocean = folder("Ocean", root)
	-- Water surface: a thin translucent slab whose TOP sits exactly at the surface line.
	-- (The old version was coplanar with Studio's template Baseplate, which z-fought and made
	-- the "baseplate" flicker between colours; WorldService.Start now also removes that.)
	Build.Part({
		Name = "WaterSurface",
		Size = Vector3.new(R * 2 + 600, 0.4, R * 2 + 600),
		CFrame = CFrame.new(0, SURFACE - 0.2, 0),
		Color = Color3.fromRGB(38, 150, 200),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.08,
		Transparency = 0.38,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = ocean,
	})
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
				deco({
					Name = "Shelf",
					CanCollide = true,
					Size = Vector3.new(SEG + 6, 6, depthOut),
					CFrame = CFrame.lookAt(shelfCenter, shelfCenter + normal),
					Color = style.shelf,
					Material = style.shelfMat,
					Parent = walls,
				})
				local shelfSurface = Vector3.new(shelfCenter.X, shelfTop, shelfCenter.Z)
				addAnchor(zone.Index, shelfSurface, math.min(SEG, depthOut) * 0.35)
				for _ = 1, (if zone.Index == 1 then 3 else 1) do
					if zone.Index > 1 and rng:NextNumber() > 0.55 then
						continue
					end
					local jitter = along * rng:NextNumber(-SEG / 2 + 4, SEG / 2 - 4) + normal * rng:NextNumber(-depthOut / 2 + 3, depthOut / 2 - 3)
					PROPS[zone.Index](walls, shelfSurface + jitter, rng)
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
				deco({
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
					PROPS[zone.Index](spires, p, rng)
					addAnchor(zone.Index, p, 3)
				end
			end
		end
		-- Reef cap on the shallowest spires
		local topZone = Zones.ForDepth(topDepth)
		if topZone then
			local capStyle = ZONE_STYLE[topZone.Index]
			deco({ Name = "SpireCap", CanCollide = true, Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 2.1, CFrame = CFrame.new(x, topY, z), Color = capStyle.shelf, Material = capStyle.shelfMat, Parent = spires })
			for k = 1, 4 do
				local ang = k / 4 * math.pi * 2
				local p = Vector3.new(x + math.cos(ang) * radius * 0.5, topY + radius * 0.85, z + math.sin(ang) * radius * 0.5)
				PROPS[topZone.Index](spires, p, rng)
				addAnchor(topZone.Index, p, 3)
			end
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
				PROPS[zone.Index](zf, p, rng)
			end
			addAnchor(zone.Index, surface, 15)
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
	local totemPrompt = Build.Prompt(totem, "Boost Server Luck", "199 R$", 0, "LuckPrompt")
	totemPrompt.Triggered:Connect(function(player)
		local Net = require(Shared.Net)
		Net.Offer:FireClient(player, "ServerLuck")
	end)

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
	local doorPrompt = Build.Prompt(door, "Enter VIP Lounge", "VIP Diver", 0, "VipPrompt")
	doorPrompt.Triggered:Connect(function(player)
		if services.MonetizationService.Owns(player, "VIP") then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				services.SecurityService.AllowTeleport(player)
				char:PivotTo(lounge.CFrame + Vector3.new(0, 4, 0))
			end
		else
			local Net = require(Shared.Net)
			Net.Offer:FireClient(player, "VIP")
		end
	end)
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
	-- Dive ramp on the ocean side
	Build.Instance("WedgePart", {
		Name = "DiveRamp",
		Anchored = true,
		Size = Vector3.new(10, 3, 10),
		CFrame = cf * CFrame.new(0, 0.5, -size.Z / 2 - 5) * CFrame.Angles(0, math.rad(180), 0),
		Color = Color3.fromRGB(60, 160, 220),
		Parent = model,
	})

	-- Sign
	local sign = Build.Part({
		Name = "Sign",
		Size = Vector3.new(16, 5, 1),
		CFrame = cf * CFrame.new(0, 7, size.Z / 2 - 1),
		Color = Color3.fromRGB(40, 50, 70),
		Parent = model,
	})
	-- Sign board faces the walkway (+Z, the plaza side); painted on, not a floating label
	local signGui = Build.SurfaceLabel(sign, "Empty Dock", Enum.NormalId.Back)
	local signBack = Build.SurfaceLabel(sign, "Empty Dock", Enum.NormalId.Front)
	signGui.Label:GetPropertyChangedSignal("Text"):Connect(function()
		signBack.Label.Text = signGui.Label.Text
	end)

	-- Stands: 5 rows x 7 columns grid
	local stands = {}
	local cols = 7
	for i = 1, World.MaxStands do
		local row = (i - 1) // cols
		local col = (i - 1) % cols
		local x = (col - (cols - 1) / 2) * World.StandSpacing
		local z = size.Z / 2 - 8 - row * World.StandSpacing
		local stand = Build.Part({
			Name = "Stand" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 4, 4),
			CFrame = cf * CFrame.new(x, 1, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 200, 210),
			Material = Enum.Material.Marble,
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		stand:SetAttribute("StandIndex", i)
		local place = Build.Prompt(stand, "Display", "Stand " .. i, 0, "Place")
		place.Enabled = false
		local steal = Build.Prompt(stand, "Steal", "Relic", 2.5, "Steal")
		steal.Enabled = false
		steal.KeyboardKeyCode = Enum.KeyCode.F
		steal.UIOffset = Vector2.new(0, 60)
		local label = Build.Billboard(stand, "", UDim2.fromOffset(140, 36), Vector3.new(0, 4.5, 0))
		label.Name = "Info"
		label.MaxDistance = 40
		stands[i] = stand
	end
	-- Vault stands (§8.1)
	local vault = {}
	for i = 1, 2 do
		local stand = Build.Part({
			Name = "Vault" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 4, 4),
			CFrame = cf * CFrame.new((i == 1 and -1 or 1) * (size.X / 2 - 4), 1, -size.Z / 2 + 6) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.Foil,
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		stand:SetAttribute("VaultIndex", i)
		local place = Build.Prompt(stand, "Vault", "Vault " .. i, 0, "Place")
		place.Enabled = false
		local label = Build.Billboard(stand, "", UDim2.fromOffset(140, 36), Vector3.new(0, 4.5, 0))
		label.Name = "Info"
		label.MaxDistance = 40
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

	local dock = {
		Index = index,
		CFrame = cf,
		Model = model,
		Platform = platform,
		Stands = stands,
		Vault = vault,
		Pad = pad,
		PadLabel = padGui.Label,
		Sign = signGui.Label,
		Gate = gate,
		GatePrompt = gatePrompt,
		SpawnCFrame = cf * CFrame.new(0, 4, size.Z / 2 - 4) * CFrame.Angles(0, math.rad(180), 0),
		Owner = nil,
	}
	docks[index] = dock
	return dock
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
		local a = list[g:NextInteger(1, #list)]
		local ang = g:NextNumber(0, math.pi * 2)
		local d = g:NextNumber(0, a.radius)
		return a.pos + Vector3.new(math.cos(ang) * d, 1.4, math.sin(ang) * d)
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

function WorldService.Start()
	removeTemplateLeftovers()
	root = folder("AbyssWorld", Workspace)
	folder("Docks", root)
	folder("Relics", root)
	folder("Nodes", root)
	folder("Creatures", root)
	folder("Drops", root)

	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.FogStart = 0
	Lighting.FogEnd = 2000

	buildOcean()
	buildPlaza()
	for i = 1, World.DockCount do
		buildDock(i)
	end
end

function WorldService.Root(): Folder
	return root
end

return WorldService
