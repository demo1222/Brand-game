-- RelicArt: procedural low-poly relic models (UI/Visual Overhaul Plan, Phase 1).
-- One recognisable model per relic, built from primitives, so it needs no uploaded assets.
-- Used by the server (dock stands, the thief's carried relic) and by the client (ViewportFrame
-- "photos" in the Bag, Codex, Reveal and Trade screens), so a relic always looks the same.
--
--   RelicArt.Build(def, opts) -> Model      (PrimaryPart = invisible "Root" at the centre)
--   opts = { mutations = {..}?, size = 1?, targetSize = 4?, forViewport = false?, light = true? }
--
-- Recipes run only inside Roblox. Module load stays free of CFrame/Instance calls so the Lune
-- tests can check that every relic has art (tests/run.luau).
--
-- Phase 3 (real art): replace a recipe with a mesh clone inside Build; nothing else changes.

local RelicArt = {}

local rgb = Color3.fromRGB

-- Named colours usable by any recipe (palette keys win over these).
local NAMED = {
	gold = { rgb(255, 196, 64), "Foil" },
	metal = { rgb(165, 170, 180), "Metal" },
	iron = { rgb(70, 72, 80), "Metal" },
	dark = { rgb(34, 34, 42), "SmoothPlastic" },
	black = { rgb(12, 12, 16), "SmoothPlastic" },
	white = { rgb(240, 238, 228), "SmoothPlastic" },
	bone = { rgb(232, 222, 196), "SmoothPlastic" },
	paper = { rgb(236, 220, 176), "SmoothPlastic" },
	wood = { rgb(122, 80, 46), "Wood" },
	glass = { rgb(170, 225, 255), "Glass" },
	red = { rgb(220, 50, 60), "SmoothPlastic" },
	ember = { rgb(255, 120, 40), "Neon" },
}

------------------------------------------------------------------------------------------
-- Per-relic art: kind (archetype) + palette. main = body colour (mutations recolour it),
-- accent = trim, glow = emissive bits (Neon). mat = main material, trans = main transparency.
------------------------------------------------------------------------------------------
RelicArt.Map = {
	-- Zone 1 · Sunlit Reef
	R001 = { kind = "anchor", main = rgb(150, 92, 60), accent = rgb(105, 64, 44), mat = "CorrodedMetal" },
	R002 = { kind = "bottle", main = rgb(120, 220, 170), accent = rgb(160, 110, 70), mat = "Glass", trans = 0.35 },
	R003 = { kind = "snorkel", main = rgb(255, 170, 40), accent = rgb(40, 40, 50) },
	R004 = { kind = "shard", main = rgb(110, 230, 200), accent = rgb(180, 250, 235), mat = "Glass", trans = 0.2 },
	R005 = { kind = "flipflop", main = rgb(255, 110, 150), accent = rgb(80, 200, 255) },
	R006 = { kind = "starfish", main = rgb(230, 175, 120), accent = rgb(190, 130, 90), mat = "Sandstone" },
	R007 = { kind = "boat", main = rgb(220, 70, 60), accent = rgb(240, 240, 235), mat = "Metal" },
	R008 = { kind = "crown", main = rgb(255, 120, 110), accent = rgb(255, 210, 120), mat = "Sandstone" },
	R009 = { kind = "bell", main = rgb(200, 150, 70), accent = rgb(130, 95, 50), mat = "Metal" },
	R010 = { kind = "clam", main = rgb(250, 190, 200), accent = rgb(255, 250, 240), glow = rgb(255, 245, 225) },
	R011 = { kind = "mask", main = rgb(250, 210, 60), accent = rgb(40, 40, 48) },
	R012 = { kind = "comb", main = rgb(245, 238, 220), accent = rgb(110, 220, 210), mat = "Marble" },
	R013 = { kind = "reefidol", main = rgb(90, 200, 170), accent = rgb(255, 200, 80), glow = rgb(120, 255, 230), mat = "Slate" },
	-- Zone 2 · Kelp Twilight
	R014 = { kind = "lantern", main = rgb(70, 90, 60), accent = rgb(110, 140, 80), glow = rgb(90, 255, 120), mat = "Metal" },
	R015 = { kind = "key", main = rgb(232, 222, 196), accent = rgb(190, 175, 150) },
	R016 = { kind = "boot", main = rgb(110, 75, 50), accent = rgb(225, 215, 190), mat = "Fabric" },
	R017 = { kind = "scroll", main = rgb(60, 140, 70), accent = rgb(30, 90, 45), mat = "Grass" },
	R018 = { kind = "helmet", main = rgb(200, 115, 60), accent = rgb(230, 180, 80), mat = "Metal" },
	R019 = { kind = "pouch", main = rgb(70, 110, 120), accent = rgb(40, 60, 70), glow = rgb(140, 230, 255), mat = "Fabric" },
	R020 = { kind = "spoons", main = rgb(215, 220, 230), accent = rgb(255, 210, 120), mat = "Metal" },
	R021 = { kind = "coin", main = rgb(255, 196, 64), accent = rgb(200, 140, 40), mat = "Foil" },
	R022 = { kind = "turtle", main = rgb(60, 170, 110), accent = rgb(30, 120, 80), mat = "Marble" },
	R023 = { kind = "mirror", main = rgb(230, 200, 120), accent = rgb(170, 90, 230), glow = rgb(200, 240, 255), mat = "Foil" },
	R024 = { kind = "statue", main = rgb(70, 130, 90), accent = rgb(220, 190, 90), glow = rgb(120, 255, 150), mat = "Slate" },
	R025 = { kind = "harp", main = rgb(255, 200, 70), accent = rgb(60, 160, 80), glow = rgb(255, 235, 140), mat = "Foil" },
	-- Zone 3 · Midnight Wrecks
	R026 = { kind = "wheel", main = rgb(130, 85, 50), accent = rgb(220, 180, 90), mat = "Wood" },
	R027 = { kind = "cannonball", main = rgb(55, 58, 66), accent = rgb(150, 110, 70), mat = "Metal" },
	R028 = {
		kind = "porthole",
		main = rgb(200, 160, 80),
		accent = rgb(60, 120, 200),
		glow = rgb(255, 230, 120),
		mat = "Metal",
	},
	R029 = { kind = "barrel", main = rgb(140, 92, 52), accent = rgb(70, 70, 76), mat = "Wood" },
	R030 = { kind = "spyglass", main = rgb(205, 160, 70), accent = rgb(110, 60, 40), glow = rgb(170, 230, 255), mat = "Metal" },
	R031 = { kind = "lantern", main = rgb(60, 70, 85), accent = rgb(90, 105, 125), glow = rgb(160, 250, 255), mat = "Metal" },
	R032 = { kind = "chest", main = rgb(125, 78, 42), accent = rgb(255, 196, 64), glow = rgb(255, 215, 90), mat = "Wood" },
	R033 = { kind = "medal", main = rgb(255, 196, 64), accent = rgb(40, 70, 170), mat = "Foil" },
	R034 = { kind = "compass", main = rgb(210, 165, 75), accent = rgb(220, 50, 60), mat = "Metal" },
	R035 = { kind = "map", main = rgb(205, 190, 150), accent = rgb(90, 30, 120), mat = "Fabric" },
	R036 = { kind = "figurehead", main = rgb(235, 215, 185), accent = rgb(150, 40, 50), mat = "Wood" },
	R037 = { kind = "cutlass", main = rgb(185, 190, 200), accent = rgb(80, 30, 110), glow = rgb(190, 70, 255), mat = "Metal" },
	R038 = { kind = "bell", main = rgb(255, 190, 70), accent = rgb(120, 220, 210), mat = "Foil", big = true },
	-- Zone 4 · The Abyss
	R039 = { kind = "pebble", main = rgb(130, 255, 220), accent = rgb(60, 140, 130), glow = rgb(200, 255, 240), mat = "Neon" },
	R040 = { kind = "lure", main = rgb(70, 60, 80), accent = rgb(120, 90, 110), glow = rgb(255, 245, 140) },
	R041 = { kind = "lantern", main = rgb(30, 40, 60), accent = rgb(255, 196, 64), glow = rgb(80, 220, 255), mat = "Metal" },
	R042 = { kind = "pearl", main = rgb(20, 20, 30), accent = rgb(90, 80, 110), glow = rgb(170, 120, 255) },
	R043 = { kind = "skull", main = rgb(225, 215, 190), accent = rgb(30, 30, 35), glow = rgb(120, 255, 220) },
	R044 = { kind = "orb", main = rgb(60, 240, 255), accent = rgb(150, 170, 190), mat = "Neon" },
	R045 = { kind = "totem", main = rgb(60, 70, 90), accent = rgb(40, 110, 120), glow = rgb(100, 255, 200), mat = "Slate" },
	R046 = { kind = "squid", main = rgb(130, 20, 45), accent = rgb(70, 10, 30), glow = rgb(90, 160, 255) },
	R047 = { kind = "facemask", main = rgb(18, 16, 24), accent = rgb(60, 50, 70), glow = rgb(255, 110, 40), mat = "Glass" },
	R048 = { kind = "scale", main = rgb(40, 140, 140), accent = rgb(20, 70, 80), glow = rgb(90, 255, 220), mat = "Metal" },
	R049 = { kind = "coral", main = rgb(60, 40, 120), accent = rgb(30, 20, 70), glow = rgb(255, 240, 150) },
	R050 = { kind = "eye", main = rgb(240, 50, 60), accent = rgb(40, 10, 20), glow = rgb(255, 230, 90) },
	R051 = {
		kind = "conch",
		main = rgb(230, 220, 250),
		accent = rgb(255, 160, 200),
		glow = rgb(190, 150, 255),
		mat = "Marble",
	},
	-- Zone 5 · The Trench
	R052 = { kind = "tooth", main = rgb(240, 236, 220), accent = rgb(110, 20, 30), glow = rgb(255, 60, 60) },
	R053 = { kind = "crystals", main = rgb(255, 120, 40), accent = rgb(50, 30, 30), mat = "Neon" },
	R054 = { kind = "tablet", main = rgb(120, 115, 105), accent = rgb(80, 75, 70), glow = rgb(90, 220, 255), mat = "Slate" },
	R055 = { kind = "diamond", main = rgb(200, 240, 255), accent = rgb(255, 255, 255), mat = "Glass", trans = 0.15 },
	R056 = { kind = "tooth", main = rgb(170, 230, 120), accent = rgb(40, 70, 30), glow = rgb(150, 255, 60), fang = true },
	R057 = { kind = "ventidol", main = rgb(150, 35, 30), accent = rgb(60, 20, 20), glow = rgb(255, 80, 30), mat = "Basalt" },
	R058 = {
		kind = "crown",
		main = rgb(255, 196, 64),
		accent = rgb(40, 140, 140),
		glow = rgb(90, 255, 220),
		mat = "Foil",
		king = true,
	},
	R059 = {
		kind = "gauntlet",
		main = rgb(120, 125, 140),
		accent = rgb(255, 196, 64),
		glow = rgb(255, 120, 40),
		mat = "DiamondPlate",
	},
	R060 = { kind = "heart", main = rgb(200, 20, 40), accent = rgb(80, 0, 15), glow = rgb(255, 60, 80), mat = "Neon" },
}

------------------------------------------------------------------------------------------
-- Builder primitives (Roblox only)
------------------------------------------------------------------------------------------
local rad = math.rad

local function cf(x, y, z, rx, ry, rz)
	return CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

local function newBuilder()
	local B = { parts = {} }
	-- kind: "Block" | "Ball" | "Cyl" | "Wedge" | "Ellip"
	function B.add(kind: string, size: Vector3, frame: CFrame, col: string, mat: string?, trans: number?)
		table.insert(B.parts, { kind = kind, size = size, cf = frame, col = col, mat = mat, trans = trans })
	end
	function B.box(sx, sy, sz, frame, col, mat, trans)
		B.add("Block", Vector3.new(sx, sy, sz), frame, col, mat, trans)
	end
	function B.ball(d, frame, col, mat, trans)
		B.add("Ball", Vector3.new(d, d, d), frame, col, mat, trans)
	end
	function B.ellip(sx, sy, sz, frame, col, mat, trans)
		B.add("Ellip", Vector3.new(sx, sy, sz), frame, col, mat, trans)
	end
	-- Cylinder along local X
	function B.cyl(len, d, frame, col, mat, trans)
		B.add("Cyl", Vector3.new(len, d, d), frame, col, mat, trans)
	end
	-- Vertical cylinder (axis = Y)
	function B.cylY(h, d, frame, col, mat, trans)
		B.cyl(h, d, frame * CFrame.Angles(0, 0, rad(90)), col, mat, trans)
	end
	-- Disc facing the camera (axis = Z)
	function B.cylZ(depth, d, frame, col, mat, trans)
		B.cyl(depth, d, frame * CFrame.Angles(0, rad(90), 0), col, mat, trans)
	end
	-- Isosceles triangle in the local XY plane, apex towards +Y, thickness along Z
	function B.spike(thick, h, base, frame, col, mat, trans)
		local f = frame * CFrame.Angles(0, rad(90), 0)
		B.add("Wedge", Vector3.new(thick, h, base / 2), f * CFrame.new(0, 0, -base / 4), col, mat, trans)
		B.add(
			"Wedge",
			Vector3.new(thick, h, base / 2),
			f * CFrame.new(0, 0, base / 4) * CFrame.Angles(0, math.pi, 0),
			col,
			mat,
			trans
		)
	end
	-- Ring in the local XY plane (faces the camera), built from tangent blocks
	function B.ring(radius, thick, segments, frame, col, mat)
		local seg = 2 * math.pi * radius / segments * 1.12
		for i = 1, segments do
			local a = (i / segments) * math.pi * 2
			B.box(
				seg,
				thick,
				thick,
				frame * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0) * CFrame.Angles(0, 0, a + math.pi / 2),
				col,
				mat
			)
		end
	end
	-- Crystal: prism with a pointed tip, standing on local Y
	function B.crystal(w, h, frame, col, mat, trans)
		B.box(w, h, w * 0.8, frame, col, mat, trans)
		B.spike(w * 0.8, w * 0.9, w, frame * CFrame.new(0, h / 2 + w * 0.45, 0), col, mat, trans)
	end
	return B
end

------------------------------------------------------------------------------------------
-- Recipes: function(B, P) where P is the palette entry. Built in a ~4-stud box, Y up,
-- camera looking from +Z. The model is auto-centred and scaled afterwards.
------------------------------------------------------------------------------------------
local R = {}

R.anchor = function(B)
	B.cylY(3.4, 0.45, cf(0, 0.1, 0), "main")
	B.box(2.2, 0.32, 0.36, cf(0, 1.3, 0), "accent")
	B.ring(0.42, 0.2, 8, cf(0, 2.1, 0), "accent")
	B.box(1.6, 0.4, 0.4, cf(-0.65, -1.45, 0, 0, 0, -28), "main")
	B.box(1.6, 0.4, 0.4, cf(0.65, -1.45, 0, 0, 0, 28), "main")
	B.spike(0.36, 0.8, 0.75, cf(-1.35, -0.95, 0, 0, 0, 22), "main")
	B.spike(0.36, 0.8, 0.75, cf(1.35, -0.95, 0, 0, 0, -22), "main")
end

R.bottle = function(B, P)
	B.cylY(2.2, 1.35, cf(0, -0.5, 0), "main", nil, P.trans)
	B.ellip(1.35, 0.9, 1.35, cf(0, 0.6, 0), "main", nil, P.trans)
	B.cylY(0.9, 0.5, cf(0, 1.25, 0), "main", nil, P.trans)
	B.cylY(0.45, 0.52, cf(0, 1.85, 0), "accent", "Wood")
	B.cylY(1.4, 0.5, cf(0, -0.45, 0, 0, 0, 14), "paper")
	B.box(0.55, 0.12, 0.12, cf(0, -0.1, 0.25, 0, 0, 14), "red")
end

R.snorkel = function(B)
	B.cylY(2.8, 0.48, cf(0, 0.3, 0), "main")
	B.cylY(0.16, 0.54, cf(0, 1.0, 0), "accent")
	B.cylY(0.16, 0.54, cf(0, 0.2, 0), "accent")
	B.cylY(0.16, 0.54, cf(0, -0.6, 0), "accent")
	B.ball(0.48, cf(0, -1.1, 0), "main")
	B.cyl(0.85, 0.42, cf(0.42, -1.1, 0), "main")
	B.ball(0.5, cf(0.95, -1.1, 0), "dark")
	B.box(0.5, 0.35, 0.5, cf(0, 1.8, 0), "accent")
	B.box(0.08, 0.7, 0.42, cf(0.02, 0.6, 0.02, 0, 0, 25), "dark")
end

R.shard = function(B, P)
	B.crystal(0.85, 2.0, cf(0, -0.1, 0, 0, 0, 6), "main", nil, P.trans)
	B.crystal(0.6, 1.2, cf(-0.75, -0.5, 0.1, 0, 0, 28), "accent", "Glass", P.trans)
	B.crystal(0.55, 1.0, cf(0.7, -0.6, 0.05, 0, 0, -24), "main", nil, P.trans)
end

R.flipflop = function(B)
	local base = cf(0, 0, 0, 55, 0, -15)
	B.ellip(1.35, 0.28, 3.1, base, "main")
	B.ellip(1.4, 0.12, 3.15, base * CFrame.new(0, -0.18, 0), "white")
	B.box(0.12, 0.12, 1.3, base * cf(-0.35, 0.25, 0.1, 0, -28, 0), "accent")
	B.box(0.12, 0.12, 1.3, base * cf(0.35, 0.25, 0.1, 0, 28, 0), "accent")
	B.ball(0.25, base * CFrame.new(0, 0.25, -0.5), "accent")
end

R.starfish = function(B)
	B.ellip(1.1, 1.1, 0.5, cf(), "main")
	for i = 0, 4 do
		local a = i * 72
		B.spike(0.4, 1.7, 0.95, cf(0, 0, 0, 0, 0, a) * CFrame.new(0, 1.1, 0), "main")
		B.ball(0.22, cf(0, 0, 0, 0, 0, a) * CFrame.new(0, 0.8, 0.2), "accent")
		B.ball(0.16, cf(0, 0, 0, 0, 0, a) * CFrame.new(0, 1.3, 0.18), "accent")
	end
end

R.boat = function(B)
	B.box(2.4, 0.8, 1.2, cf(-0.3, -0.3, 0), "main")
	B.spike(1.2, 1.0, 0.8, cf(1.4, -0.3, 0, 0, 0, -90), "main")
	B.box(2.42, 0.18, 1.22, cf(-0.3, -0.05, 0), "accent")
	B.box(1.0, 0.7, 0.9, cf(-0.5, 0.45, 0), "accent")
	B.box(1.04, 0.2, 0.94, cf(-0.5, 0.85, 0), "main")
	B.cylY(0.7, 0.32, cf(-0.5, 1.2, 0), "dark")
	B.cylZ(0.05, 0.25, cf(-0.75, 0.45, 0.46), "glass")
	B.cylZ(0.05, 0.25, cf(-0.25, 0.45, 0.46), "glass")
	B.cyl(0.25, 0.35, cf(-1.7, -0.6, 0), "metal")
end

R.crown = function(B, P)
	local band = if P.king then 0.9 else 0.75
	B.cylY(band, 2.4, cf(0, -0.4, 0), "main")
	B.cylY(0.18, 2.5, cf(0, -0.4 - band / 2, 0), "accent")
	local n = if P.king then 8 else 7
	for i = 1, n do
		local a = (i / n) * 360
		local h = if P.king then 1.3 else (if i % 2 == 0 then 1.1 else 0.8)
		B.spike(0.25, h, 0.6, cf(0, 0, 0, 0, a, 0) * CFrame.new(0, -0.4 + band / 2 + h / 2 - 0.05, 1.08), "main")
		if P.king then
			B.ball(0.24, cf(0, 0, 0, 0, a, 0) * CFrame.new(0, -0.4 + band / 2 + h, 1.08), "gold")
		end
	end
	B.ball(0.45, cf(0, -0.35, 1.18), if P.glow then "glow" else "accent")
	B.ball(0.3, cf(-0.75, -0.4, 0.95), "accent")
	B.ball(0.3, cf(0.75, -0.4, 0.95), "accent")
end

R.bell = function(B, P)
	local trim = if P.big then "accent" else "main"
	B.ring(0.3, 0.16, 8, cf(0, 1.75, 0), "accent")
	B.ellip(1.3, 1.2, 1.3, cf(0, 1.0, 0), "main")
	B.cylY(0.7, 1.55, cf(0, 0.55, 0), "main")
	B.cylY(0.7, 1.95, cf(0, -0.05, 0), "main")
	B.cylY(0.35, 2.45, cf(0, -0.55, 0), trim)
	B.cylY(0.12, 2.0, cf(0, 0.5, 0), trim)
	B.ball(0.55, cf(0, -0.85, 0), "dark")
	if P.big then
		B.cylY(0.1, 2.1, cf(0, 0.15, 0), "accent")
		B.ball(0.35, cf(0, 0.25, 1.0), "accent")
	end
end

R.clam = function(B)
	B.ellip(2.6, 0.8, 2.0, cf(0, -0.4, 0), "main")
	B.ellip(2.6, 0.8, 2.0, cf(0, 0.45, -0.45, -38, 0, 0), "main")
	for i = -2, 2 do
		B.box(0.08, 0.1, 1.9, cf(i * 0.42, 0.7, -0.45, -38, i * 8, 0), "accent")
	end
	B.ball(0.85, cf(0, 0.0, 0.3), "glow")
end

R.mask = function(B)
	B.ellip(2.6, 1.5, 0.6, cf(0, 0.2, 0), "main")
	B.ellip(2.1, 1.05, 0.3, cf(0, 0.25, 0.22), "glass", "Glass", 0.35)
	B.spike(0.5, 0.6, 0.8, cf(0, -0.7, 0.15, 0, 0, 180), "main")
	B.box(3.2, 0.3, 0.2, cf(0, 0.25, -0.35), "accent")
	B.box(0.12, 0.9, 0.06, cf(-0.3, 0.3, 0.38, 0, 0, -30), "white", nil, 0.4)
end

R.comb = function(B)
	B.box(2.8, 0.55, 0.25, cf(0, 0.5, 0), "main")
	B.ellip(1.4, 0.75, 0.3, cf(0, 0.95, 0), "main")
	B.ball(0.35, cf(0, 0.95, 0.15), "accent")
	for i = 0, 10 do
		B.box(0.13, 1.25, 0.2, cf(-1.25 + i * 0.25, -0.35, 0), "main")
	end
end

R.reefidol = function(B)
	B.box(1.8, 0.35, 1.4, cf(0, -1.6, 0), "accent")
	B.ellip(1.5, 1.8, 1.15, cf(0, -0.55, 0), "main")
	B.ball(1.25, cf(0, 0.95, 0), "main")
	B.box(0.5, 0.12, 0.1, cf(0, 0.6, 0.6), "dark")
	B.ball(0.24, cf(-0.22, 1.08, 0.55), "glow")
	B.ball(0.24, cf(0.22, 1.08, 0.55), "glow")
	B.spike(0.36, 1.0, 0.9, cf(0, 1.85, 0), "accent")
	B.spike(0.3, 0.8, 0.7, cf(-0.5, 1.45, 0, 0, 0, 30), "accent")
	B.spike(0.3, 0.8, 0.7, cf(0.5, 1.45, 0, 0, 0, -30), "accent")
	B.ellip(0.5, 1.2, 0.5, cf(-1.0, -0.45, 0, 0, 0, 18), "main")
	B.ellip(0.5, 1.2, 0.5, cf(1.0, -0.45, 0, 0, 0, -18), "main")
	B.ball(0.3, cf(0, -0.5, 0.55), "glow")
end

-- Vent Idol: a basalt idol with a lava mouth and cracks (was a box stack)
R.ventidol = function(B)
	B.box(1.9, 0.4, 1.5, cf(0, -1.8, 0), "accent")
	B.ellip(1.6, 2.0, 1.2, cf(0, -0.7, 0), "main")
	B.ellip(1.25, 1.2, 1.0, cf(0, 0.9, 0), "main")
	B.box(0.9, 0.26, 0.12, cf(0, 0.62, 0.44), "glow")
	B.ball(0.26, cf(-0.28, 1.05, 0.42), "glow")
	B.ball(0.26, cf(0.28, 1.05, 0.42), "glow")
	B.spike(0.3, 1.0, 0.7, cf(-0.5, 1.7, 0, 0, 0, 25), "accent")
	B.spike(0.3, 1.0, 0.7, cf(0.5, 1.7, 0, 0, 0, -25), "accent")
	B.spike(0.36, 1.1, 0.8, cf(0, 1.75, 0), "main")
	B.box(0.08, 1.2, 0.06, cf(0.35, -0.5, 0.47, 0, 0, 14), "glow")
end

R.lantern = function(B, P)
	B.cylY(0.3, 1.5, cf(0, -1.15, 0), "main")
	B.cylY(0.25, 1.5, cf(0, 1.1, 0), "main")
	B.cylY(0.25, 1.0, cf(0, 1.35, 0), "main")
	B.cylY(0.25, 0.55, cf(0, 1.55, 0), "accent")
	B.ring(0.32, 0.12, 8, cf(0, 1.95, 0), "accent")
	for _, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		B.box(0.14, 2.1, 0.14, cf(p[1] * 0.55, 0, p[2] * 0.55), "accent")
	end
	B.box(1.0, 1.95, 1.0, cf(), "glass", "Glass", 0.55)
	B.ellip(0.5, 0.85, 0.5, cf(0, -0.1, 0), "glow")
	if P.glow then
		B.ball(0.25, cf(0, 0.4, 0), "white", "Neon")
	end
end

R.key = function(B)
	local base = cf(0, 0, 0, 0, 0, 30)
	B.ring(0.55, 0.24, 10, base * CFrame.new(-1.2, 0, 0), "main")
	B.box(2.3, 0.26, 0.26, base * CFrame.new(0.3, 0, 0), "main")
	for i = 0, 2 do
		B.box(0.08, 0.55, 0.18, base * cf(-0.2 + i * 0.4, 0.2, 0, 0, 0, -25), "accent")
		B.box(0.08, 0.55, 0.18, base * cf(-0.2 + i * 0.4, -0.2, 0, 0, 0, 25), "accent")
	end
	B.box(0.22, 0.6, 0.26, base * CFrame.new(1.3, -0.3, 0), "main")
	B.box(0.22, 0.42, 0.26, base * CFrame.new(0.95, -0.22, 0), "main")
end

R.boot = function(B)
	B.box(1.05, 2.0, 1.05, cf(-0.45, 0.45, 0), "main")
	B.box(2.0, 0.8, 1.05, cf(0.1, -0.85, 0), "main")
	B.ellip(0.9, 0.8, 1.05, cf(1.05, -0.85, 0), "main")
	B.box(2.6, 0.25, 1.1, cf(0.15, -1.35, 0), "dark")
	B.box(1.15, 0.25, 1.15, cf(-0.45, 1.4, 0), "dark")
	for _, p in { { -0.6, 0.7 }, { -0.2, -0.1 }, { 0.6, -0.6 }, { -0.7, -0.5 }, { -0.25, 0.95 } } do
		B.ball(0.32, cf(p[1], p[2], 0.52), "accent")
	end
end

R.scroll = function(B)
	B.box(2.0, 2.3, 0.08, cf(), "paper")
	B.cyl(2.5, 0.5, cf(0, 1.2, 0), "main")
	B.cyl(2.5, 0.5, cf(0, -1.2, 0), "main")
	for _, x in { -1.35, 1.35 } do
		B.ball(0.35, cf(x, 1.2, 0), "accent")
		B.ball(0.35, cf(x, -1.2, 0), "accent")
	end
	for i = 0, 3 do
		B.box(1.3 - (i % 2) * 0.4, 0.1, 0.05, cf(-0.1, 0.6 - i * 0.4, 0.06), "accent")
	end
end

R.helmet = function(B)
	B.ball(2.5, cf(0, 0.3, 0), "main")
	B.cylY(0.55, 2.3, cf(0, -1.1, 0), "accent")
	B.cylY(0.2, 2.6, cf(0, -1.4, 0), "main")
	B.ring(0.62, 0.22, 12, cf(0, 0.3, 1.18), "accent")
	B.cylZ(0.12, 1.2, cf(0, 0.3, 1.17), "glass", "Glass", 0.25)
	for _, x in { -1, 1 } do
		B.ring(0.36, 0.16, 8, cf(x * 1.18, 0.35, 0, 0, 90, 0), "accent")
		B.cylZ(0.1, 0.7, cf(x * 1.16, 0.35, 0, 0, 90, 0), "glass", "Glass", 0.25)
	end
	B.cylY(0.4, 0.5, cf(0, 1.6, 0), "accent")
	for i = 0, 5 do
		local a = rad(i * 60)
		B.ball(0.16, cf(math.cos(a) * 0.82, 0.3 + math.sin(a) * 0.82, 1.1), "accent")
	end
end

R.pouch = function(B)
	B.ellip(2.0, 1.9, 1.6, cf(0, -0.35, 0), "main")
	B.cylY(0.45, 0.85, cf(0, 0.7, 0), "main")
	B.ring(0.47, 0.14, 10, cf(0, 0.6, 0, 90, 0, 0), "accent")
	B.ellip(1.25, 0.45, 1.1, cf(0, 1.05, 0), "main")
	B.ball(0.18, cf(-0.45, -0.1, 0.78), "glow")
	B.ball(0.14, cf(0.3, -0.6, 0.76), "glow")
	B.box(0.08, 0.6, 0.06, cf(0.1, -0.2, 0.8, 0, 0, 35), "glow")
	B.box(0.08, 0.5, 0.06, cf(0.25, -0.4, 0.78, 0, 0, -30), "glow")
end

R.spoons = function(B)
	for i, a in { -22, 0, 22 } do
		local base = cf(0, -0.4, -0.1 * i, 0, 0, a)
		B.box(0.2, 2.4, 0.1, base, "main")
		B.ellip(0.7, 0.95, 0.2, base * CFrame.new(0, 1.55, 0), "main")
		B.ball(0.22, base * CFrame.new(0, -1.15, 0), "accent")
	end
end

R.coin = function(B)
	B.cylZ(0.28, 2.4, cf(), "main")
	B.ring(1.12, 0.16, 18, cf(0, 0, 0.12), "accent")
	B.ball(0.75, cf(0, 0.15, 0.2), "accent")
	B.box(0.5, 0.25, 0.1, cf(0, -0.35, 0.18), "accent")
	B.box(1.2, 0.12, 0.08, cf(0, -0.5, 0.17, 0, 0, 30), "accent")
	B.box(1.2, 0.12, 0.08, cf(0, -0.5, 0.17, 0, 0, -30), "accent")
	B.ball(0.18, cf(-0.15, 0.2, 0.52), "dark")
	B.ball(0.18, cf(0.15, 0.2, 0.52), "dark")
end

R.turtle = function(B)
	B.ellip(2.6, 1.1, 2.1, cf(0, 0.1, 0), "main")
	B.ellip(1.6, 0.5, 1.3, cf(0, 0.5, 0), "accent")
	B.ellip(0.8, 0.65, 0.75, cf(1.55, 0.0, 0.2), "main")
	B.ball(0.14, cf(1.8, 0.12, 0.52), "black")
	for _, p in { { 0.8, 0.9 }, { -0.8, 0.9 }, { 0.8, -0.9 }, { -0.8, -0.9 } } do
		B.ellip(1.0, 0.22, 0.5, cf(p[1], -0.3, p[2], 0, if p[2] > 0 then -25 else 25, 0), "accent")
	end
	B.spike(0.2, 0.5, 0.35, cf(-1.45, -0.05, 0, 0, 0, 90), "accent")
end

R.mirror = function(B)
	B.ring(0.95, 0.28, 16, cf(0, 0.55, 0), "main")
	B.cylZ(0.1, 1.85, cf(0, 0.55, 0), "glow", "Glass", 0.1)
	B.box(0.32, 1.6, 0.26, cf(0, -1.15, 0), "main")
	B.ball(0.42, cf(0, -0.35, 0.1), "accent")
	B.ball(0.3, cf(0, -2.0, 0), "accent")
	B.spike(0.25, 0.5, 0.4, cf(0, 1.75, 0), "main")
end

R.statue = function(B)
	B.box(2.0, 0.5, 1.6, cf(0, -1.8, 0), "accent")
	B.box(1.0, 1.2, 0.65, cf(0, -0.95, 0), "main")
	B.box(1.35, 1.25, 0.75, cf(0, 0.25, 0), "main")
	B.ball(0.9, cf(0, 1.3, 0), "main")
	for i = -1, 1 do
		B.spike(0.2, 0.55, 0.32, cf(i * 0.3, 1.9, 0), "accent")
	end
	B.box(0.35, 1.1, 0.4, cf(-0.85, 0.15, 0, 0, 0, -10), "main")
	B.box(0.35, 1.1, 0.4, cf(0.85, 0.3, 0, 0, 0, 20), "main")
	B.cylY(3.4, 0.16, cf(1.1, 0.0, 0.1), "accent")
	B.ball(0.42, cf(1.1, 1.75, 0.1), "glow")
end

R.harp = function(B)
	B.box(0.32, 3.4, 0.32, cf(-1.1, 0, 0), "main")
	B.box(2.3, 0.34, 0.32, cf(-0.05, 1.42, 0, 0, 0, -13), "main")
	local dx, dy = 2.05, 2.6
	B.box(0.4, math.sqrt(dx * dx + dy * dy), 0.42, cf(0.0, -0.3, 0, 0, 0, -math.deg(math.atan2(dx, dy))), "main")
	for i = 0, 5 do
		local x = -0.85 + i * 0.28
		local top = 1.42 - (x + 0.05) * math.tan(rad(13)) - 0.12
		local bottom = -1.6 + (x + 1.0) * (dy / dx) + 0.1
		if top > bottom then
			B.box(0.05, top - bottom, 0.05, cf(x, (top + bottom) / 2, 0), "glow")
		end
	end
	B.ellip(0.5, 0.9, 0.2, cf(-1.25, 1.8, 0.1, 0, 0, 30), "accent")
	B.ellip(0.4, 0.8, 0.2, cf(-1.3, -1.4, 0.1, 0, 0, -25), "accent")
	B.ball(0.4, cf(1.0, 1.15, 0), "accent")
end

R.wheel = function(B)
	B.ring(1.2, 0.3, 16, cf(), "main")
	B.cylZ(0.5, 0.8, cf(), "accent")
	for i = 0, 3 do
		B.box(3.5, 0.16, 0.16, cf(0, 0, 0, 0, 0, i * 45), "main")
	end
	for i = 0, 7 do
		local a = rad(i * 45)
		B.ellip(0.26, 0.26, 0.4, cf(math.cos(a) * 1.8, math.sin(a) * 1.8, 0), "main")
	end
end

R.cannonball = function(B)
	B.ball(2.4, cf(), "main")
	B.ring(1.2, 0.14, 16, cf(), "accent")
	B.cylY(0.25, 0.45, cf(0, 1.15, 0), "dark")
	B.ring(0.32, 0.12, 8, cf(0, 1.3, 0, 90, 0, 0), "accent")
	B.ball(0.9, cf(-1.2, -0.85, -0.6), "main")
	B.ball(0.9, cf(1.25, -0.9, -0.4), "main")
	B.ellip(0.4, 0.25, 0.1, cf(-0.45, 0.5, 1.12, 0, 0, 30), "white", nil, 0.6)
	B.ellip(0.7, 0.5, 0.08, cf(0.55, -0.45, 1.05, 0, 0, -25), "accent")
end

R.porthole = function(B)
	B.ring(1.15, 0.38, 16, cf(), "main")
	B.cylZ(0.12, 2.1, cf(0, 0, -0.05), "accent", "Glass", 0.3)
	for i = 0, 7 do
		local a = rad(i * 45 + 22.5)
		B.ball(0.2, cf(math.cos(a) * 1.15, math.sin(a) * 1.15, 0.2), "dark")
	end
	B.box(0.35, 0.7, 0.35, cf(1.45, 0, 0), "main")
	B.ball(0.22, cf(-0.3, 0.1, 0.05), "glow")
	B.ball(0.22, cf(0.3, 0.1, 0.05), "glow")
end

R.barrel = function(B)
	B.cylY(2.6, 1.75, cf(), "main")
	B.cylY(1.4, 2.0, cf(), "main")
	B.cylY(0.16, 1.82, cf(0, 1.0, 0), "accent")
	B.cylY(0.16, 1.82, cf(0, -1.0, 0), "accent")
	B.cylY(0.16, 2.06, cf(0, 0.35, 0), "accent")
	B.cylY(0.16, 2.06, cf(0, -0.35, 0), "accent")
	B.cylZ(0.25, 0.3, cf(0, 0, 1.0), "dark")
end

R.spyglass = function(B)
	local base = cf(0, 0, 0, 0, 0, 22)
	B.cyl(1.4, 0.85, base * CFrame.new(-1.0, 0, 0), "accent")
	B.cyl(1.2, 0.68, base * CFrame.new(0.2, 0, 0), "main")
	B.cyl(1.0, 0.52, base * CFrame.new(1.25, 0, 0), "main")
	B.cyl(0.15, 0.95, base * CFrame.new(-1.68, 0, 0), "gold")
	B.cyl(0.15, 0.78, base * CFrame.new(-0.35, 0, 0), "gold")
	B.cyl(0.15, 0.62, base * CFrame.new(0.78, 0, 0), "gold")
	B.cyl(0.08, 0.8, base * CFrame.new(-1.75, 0, 0), "glow", "Glass", 0.2)
end

R.chest = function(B)
	B.box(2.7, 1.35, 1.6, cf(0, -0.45, 0), "main")
	B.cyl(2.7, 1.6, cf(0, 0.2, 0), "main")
	for _, x in { -1.05, 1.05 } do
		B.box(0.22, 1.4, 1.65, cf(x, -0.45, 0), "accent")
		B.cyl(0.22, 1.66, cf(x, 0.2, 0), "accent")
	end
	B.box(0.45, 0.55, 0.2, cf(0, 0.0, 0.82), "accent")
	B.box(0.12, 0.2, 0.05, cf(0, -0.05, 0.93), "dark")
	for i, p in { { -0.6, 0.12 }, { 0.15, 0.05 }, { 0.7, 0.14 } } do
		B.cylZ(0.08, 0.38, cf(p[1], p[2] + 0.18, 0.75 + i * 0.02, 0, 0, i * 20), "glow", "Neon")
	end
end

R.medal = function(B)
	B.box(0.55, 1.5, 0.1, cf(-0.3, 1.0, 0, 0, 0, 14), "accent")
	B.box(0.55, 1.5, 0.1, cf(0.3, 1.0, -0.02, 0, 0, -14), "accent")
	B.box(0.2, 1.5, 0.12, cf(-0.3, 1.0, 0.02, 0, 0, 14), "white")
	B.ring(0.15, 0.1, 6, cf(0, 0.25, 0), "main")
	B.cylZ(0.22, 1.8, cf(0, -0.65, 0), "main")
	B.ring(0.88, 0.12, 16, cf(0, -0.65, 0.12), "gold")
	for i = 0, 4 do
		B.spike(0.08, 0.5, 0.36, cf(0, -0.65, 0.16, 0, 0, i * 72) * CFrame.new(0, 0.25, 0), "accent")
	end
end

R.compass = function(B)
	B.cylZ(0.45, 2.3, cf(), "main")
	B.ring(1.1, 0.18, 18, cf(0, 0, 0.22), "main")
	B.cylZ(0.05, 1.95, cf(0, 0, 0.22), "white")
	B.spike(0.06, 0.85, 0.3, cf(0, 0.42, 0.27, 0, 0, -20), "accent")
	B.spike(0.06, 0.85, 0.3, cf(0, -0.42, 0.27, 0, 0, 160), "metal")
	B.ball(0.18, cf(0, 0, 0.3), "dark")
	B.ring(0.25, 0.12, 8, cf(0, 1.35, 0), "main")
	for i = 0, 3 do
		B.box(0.06, 0.25, 0.05, cf(0, 0, 0.25, 0, 0, i * 90) * CFrame.new(0, 0.82, 0), "dark")
	end
end

R.map = function(B)
	B.box(2.6, 1.9, 0.06, cf(0.2, 0, 0, 0, 0, -4), "main")
	B.cylY(2.1, 0.42, cf(-1.2, 0.08, 0), "main")
	B.cylY(2.1, 0.42, cf(1.6, -0.12, 0), "main")
	B.box(0.7, 0.12, 0.05, cf(0.6, 0.35, 0.05, 0, 0, 45), "red")
	B.box(0.7, 0.12, 0.05, cf(0.6, 0.35, 0.05, 0, 0, -45), "red")
	for i = 0, 5 do
		B.ball(0.18 - i * 0.015, cf(-0.6 + i * 0.22, -0.3 + math.sin(i) * 0.25, 0.05), "accent")
	end
	B.ellip(0.7, 0.5, 0.05, cf(-0.4, 0.45, 0.04), "accent")
end

R.figurehead = function(B)
	B.box(0.55, 3.2, 0.55, cf(-0.6, 0.0, -0.4, 0, 0, -18), "wood")
	B.ellip(1.4, 1.8, 1.0, cf(0, -0.55, 0), "accent")
	B.ball(1.3, cf(0.05, 0.85, 0.05), "main")
	B.ellip(1.4, 1.6, 0.9, cf(-0.1, 0.8, -0.25), "gold")
	B.ellip(0.35, 1.1, 0.3, cf(0.75, -0.35, 0.1, 0, 0, 30), "main")
	B.ball(0.16, cf(-0.3, 0.95, 0.6), "black")
	B.ball(0.16, cf(0.42, 0.95, 0.6), "black")
	B.cylY(0.25, 1.5, cf(0, -1.5, 0), "gold")
end

R.cutlass = function(B, P)
	local base = cf(0, 0, 0, 0, 0, -28)
	B.box(0.42, 2.5, 0.08, base * CFrame.new(0, 0.6, 0), "main")
	B.spike(0.08, 0.7, 0.42, base * CFrame.new(0, 2.2, 0), "main")
	B.box(0.06, 2.6, 0.1, base * CFrame.new(0.2, 0.75, 0), if P.glow then "glow" else "metal")
	B.box(1.1, 0.22, 0.28, base * CFrame.new(0, -0.7, 0), "gold")
	B.box(0.14, 0.9, 0.2, base * CFrame.new(0.5, -1.05, 0), "gold")
	B.cylY(0.85, 0.3, base * CFrame.new(0, -1.25, 0), "accent")
	B.ball(0.35, base * CFrame.new(0, -1.75, 0), "gold")
end

R.pebble = function(B)
	B.ellip(2.1, 1.5, 1.7, cf(0, 0.1, 0, 0, 0, 10), "main")
	B.box(0.14, 1.3, 0.8, cf(0.25, 0.2, 0.8, 0, 0, 30), "glow")
	B.ellip(0.95, 0.65, 0.85, cf(-1.2, -0.45, 0.25), "accent")
end

R.lure = function(B)
	B.ellip(1.6, 0.5, 1.0, cf(0, -1.4, 0), "accent")
	B.box(0.18, 1.4, 0.18, cf(-0.3, -0.5, 0, 0, 0, -12), "main")
	B.box(0.18, 1.2, 0.18, cf(0.0, 0.65, 0, 0, 0, -40), "main")
	B.box(0.18, 0.9, 0.18, cf(0.55, 1.15, 0, 0, 0, -80), "main")
	B.ball(0.95, cf(1.05, 0.95, 0), "glow")
	B.ball(0.5, cf(1.05, 0.95, 0.25), "white", "Neon")
	for i = 0, 3 do
		B.spike(0.1, 0.3, 0.16, cf(-0.6 + i * 0.4, -1.25, 0.4), "bone")
	end
end

R.pearl = function(B)
	B.ellip(2.4, 0.7, 2.0, cf(0, -0.75, 0), "accent")
	B.ellip(2.5, 0.25, 2.1, cf(0, -0.55, 0), "accent")
	B.ball(1.6, cf(0, 0.25, 0), "main", "SmoothPlastic")
	B.ring(0.95, 0.06, 20, cf(0, 0.25, 0, 0, 0, 0), "glow")
	B.ellip(0.35, 0.25, 0.1, cf(-0.35, 0.65, 0.72, 0, 0, 30), "white", nil, 0.5)
end

R.skull = function(B)
	B.ellip(2.1, 1.7, 1.9, cf(0, 0.55, 0), "main")
	B.ellip(0.55, 0.55, 0.3, cf(-0.45, 0.45, 0.85), "accent")
	B.ellip(0.55, 0.55, 0.3, cf(0.45, 0.45, 0.85), "accent")
	B.ball(0.15, cf(-0.45, 0.45, 0.98), "glow")
	B.ball(0.15, cf(0.45, 0.45, 0.98), "glow")
	B.box(2.4, 0.5, 1.9, cf(0, -0.85, 0.3, 10, 0, 0), "main")
	for i = -3, 3 do
		B.spike(0.15, 0.55, 0.28, cf(i * 0.32, -0.4, 1.15, 10, 0, 180), "white")
	end
	for i = -2, 2 do
		B.spike(0.15, 0.45, 0.26, cf(i * 0.36, -0.15, 0.9), "white")
	end
end

R.orb = function(B)
	B.ball(1.9, cf(), "main")
	B.ball(1.1, cf(0, 0, 0.45), "white", "Neon", 0.3)
	B.ring(1.35, 0.1, 22, cf(0, 0, 0, 70, 0, 0), "accent")
	B.ring(1.35, 0.1, 22, cf(0, 0, 0, 70, 60, 0), "accent")
	B.ball(0.2, cf(1.5, 0.4, 0), "main")
	B.ball(0.15, cf(-1.4, -0.5, 0.3), "main")
end

R.totem = function(B)
	for i = 0, 2 do
		local y = -1.25 + i * 1.05
		B.box(1.4, 1.0, 1.2, cf(0, y, 0), if i % 2 == 0 then "main" else "accent")
		B.ball(0.26, cf(-0.35, y + 0.15, 0.6), "glow")
		B.ball(0.26, cf(0.35, y + 0.15, 0.6), "glow")
		B.spike(0.3, 0.4, 0.4, cf(0, y - 0.22, 0.62, 0, 0, 180), "accent")
	end
	B.spike(0.3, 1.0, 1.0, cf(-1.05, 1.0, 0, 0, 0, 55), "accent")
	B.spike(0.3, 1.0, 1.0, cf(1.05, 1.0, 0, 0, 0, -55), "accent")
	B.spike(0.36, 1.2, 0.8, cf(0, 2.0, 0), "accent")
	B.spike(0.3, 0.8, 0.5, cf(-0.5, 1.75, 0, 0, 0, 22), "main")
	B.spike(0.3, 0.8, 0.5, cf(0.5, 1.75, 0, 0, 0, -22), "main")
end

R.squid = function(B)
	B.ellip(1.4, 2.1, 1.1, cf(0, 0.75, 0), "main")
	B.ellip(0.9, 0.45, 0.2, cf(-0.75, 1.5, 0, 0, 0, 25), "accent")
	B.ellip(0.9, 0.45, 0.2, cf(0.75, 1.5, 0, 0, 0, -25), "accent")
	B.ball(0.32, cf(-0.35, 0.2, 0.48), "glow")
	B.ball(0.32, cf(0.35, 0.2, 0.48), "glow")
	B.ellip(2.6, 0.5, 1.6, cf(0, -0.35, 0), "accent")
	for i = 0, 7 do
		local a = -70 + i * 20
		B.box(0.2, 1.7, 0.22, cf(0, -0.4, 0, 0, 0, a) * CFrame.new(0, -0.95, 0.15), "main")
	end
end

R.facemask = function(B)
	B.ellip(1.9, 2.5, 0.7, cf(), "main")
	B.ellip(2.0, 0.35, 0.6, cf(0, 0.45, 0.1), "accent")
	B.ellip(0.55, 0.3, 0.2, cf(-0.42, 0.2, 0.3, 0, 0, -12), "black")
	B.ellip(0.55, 0.3, 0.2, cf(0.42, 0.2, 0.3, 0, 0, 12), "black")
	B.ball(0.18, cf(-0.42, 0.2, 0.36), "glow")
	B.ball(0.18, cf(0.42, 0.2, 0.36), "glow")
	B.spike(0.3, 0.6, 0.32, cf(0, -0.25, 0.3), "accent")
	B.box(0.7, 0.1, 0.12, cf(0, -0.75, 0.32), "glow")
	B.spike(0.2, 0.55, 0.4, cf(0, 1.1, 0.2), "glow")
end

R.scale = function(B)
	B.box(2.2, 1.3, 0.35, cf(0, 0.6, 0), "main")
	B.spike(0.35, 2.0, 2.2, cf(0, -1.05, 0, 0, 0, 180), "main")
	B.box(0.22, 2.9, 0.5, cf(0, -0.15, 0.05), "accent")
	B.box(2.3, 0.18, 0.4, cf(0, 1.25, 0), "glow")
	B.box(0.1, 1.8, 0.4, cf(-0.6, -0.15, 0.05, 0, 0, 25), "glow")
	B.box(0.1, 1.8, 0.4, cf(0.6, -0.15, 0.05, 0, 0, -25), "glow")
end

R.coral = function(B)
	B.cylY(1.0, 0.5, cf(0, -1.5, 0), "accent")
	B.ellip(1.3, 0.35, 1.0, cf(0, -2.0, 0), "accent")
	local branches = {
		{ 0, 1.6, 0 },
		{ -35, 1.3, 0.1 },
		{ 35, 1.3, -0.1 },
		{ -60, 0.9, 0 },
		{ 60, 0.9, 0.1 },
		{ -15, 1.0, 0.3 },
		{ 18, 1.1, -0.3 },
	}
	for _, b in branches do
		local base = cf(0, -1.0, b[3], 0, 0, b[1])
		B.cylY(b[2], 0.28, base * CFrame.new(0, b[2] / 2, 0), "main")
		B.ball(0.42, base * CFrame.new(0, b[2], 0), "glow")
	end
end

R.eye = function(B)
	B.ball(2.3, cf(), "white")
	B.cylZ(0.12, 1.3, cf(0, 0, 1.08), "main")
	B.cylZ(0.13, 0.85, cf(0, 0, 1.1), "glow")
	B.box(0.22, 0.95, 0.1, cf(0, 0, 1.17), "black")
	B.ellip(2.6, 0.9, 2.6, cf(0, 1.05, -0.1, -12, 0, 0), "accent")
	B.ellip(2.6, 0.7, 2.6, cf(0, -1.1, -0.1, 12, 0, 0), "accent")
	for i = 0, 2 do
		B.box(0.04, 0.7, 0.04, cf(-0.75 + i * 0.75, 0.0, 0.9, 0, 0, -50 + i * 50), "red")
	end
end

R.conch = function(B)
	local sizes = { 1.7, 1.4, 1.1, 0.85, 0.6, 0.4 }
	for i, d in sizes do
		local a = (i - 1) * 0.9
		local r = 0.55 - i * 0.07
		B.ellip(
			d,
			d * 0.9,
			d,
			cf(math.cos(a) * r - (i - 1) * 0.15, (i - 1) * 0.42 - 0.6, math.sin(a) * r * 0.5),
			"main"
		)
		if i <= 4 then
			B.spike(
				0.15,
				0.45,
				0.25,
				cf(math.cos(a) * r - (i - 1) * 0.15 + d * 0.35, (i - 1) * 0.42 - 0.4, 0.2, 0, 0, -40),
				"accent"
			)
		end
	end
	B.ellip(1.0, 1.5, 0.4, cf(0.55, -0.6, 0.55, 0, 0, -15), "accent")
	B.ellip(0.6, 1.0, 0.3, cf(0.55, -0.6, 0.72, 0, 0, -15), "glow")
end

R.tooth = function(B, P)
	if P.fang then
		B.spike(0.45, 1.6, 0.9, cf(0.1, -0.45, 0, 0, 0, 172), "main")
		B.spike(0.45, 1.4, 0.9, cf(-0.05, 1.0, 0, 0, 0, 0), "main")
		B.box(0.9, 0.3, 0.45, cf(0, 0.2, 0), "main")
		B.ball(0.3, cf(0.25, -1.3, 0.1), "glow")
		B.box(1.0, 0.25, 0.5, cf(0, 0.38, 0), "accent")
	else
		B.spike(0.7, 3.2, 1.25, cf(0, -0.25, 0, 0, 0, 175), "main")
		B.ellip(1.35, 1.0, 0.9, cf(0, 1.5, 0), "accent")
		B.ellip(1.0, 0.7, 0.8, cf(0, 2.0, 0), "accent")
		B.box(0.08, 1.4, 0.72, cf(0.15, -0.2, 0, 0, 0, 10), "glow")
	end
end

R.crystals = function(B)
	B.ellip(2.6, 0.8, 1.9, cf(0, -1.4, 0), "accent", "Basalt")
	B.crystal(0.75, 2.0, cf(0, -0.1, 0), "main")
	B.crystal(0.55, 1.3, cf(-0.75, -0.6, 0.2, 0, 0, 25), "main")
	B.crystal(0.5, 1.1, cf(0.75, -0.7, 0.1, 0, 0, -28), "main")
	B.crystal(0.4, 0.8, cf(0.25, -0.9, 0.6, 30, 0, -10), "main")
end

R.tablet = function(B)
	B.box(2.0, 2.4, 0.42, cf(0, -0.25, 0), "main")
	B.cylZ(0.42, 2.0, cf(0, 0.95, 0), "main")
	B.box(2.1, 0.25, 0.5, cf(0, -1.45, 0), "accent")
	for i = 0, 4 do
		local w = 1.4 - (i % 3) * 0.25
		B.box(w, 0.1, 0.05, cf(0, 0.85 - i * 0.42, 0.23), "glow")
	end
	B.box(0.06, 0.9, 0.06, cf(0.6, -0.6, 0.22, 0, 0, 25), "accent")
end

R.diamond = function(B, P)
	B.cylY(0.5, 2.2, cf(0, 0.55, 0), "main", nil, P.trans)
	B.cylY(0.3, 1.5, cf(0, 0.9, 0), "accent", "Glass", P.trans)
	for i = 0, 3 do
		B.spike(1.0, 1.7, 2.2, cf(0, -0.55, 0, 0, i * 45, 180), "main", nil, P.trans)
	end
	B.ellip(0.35, 0.2, 0.1, cf(-0.4, 0.75, 1.0, 0, 0, 30), "white", "Neon", 0.3)
end

R.gauntlet = function(B)
	B.cylY(0.9, 1.3, cf(0, -0.9, 0), "main")
	B.cylY(0.22, 1.5, cf(0, -1.4, 0), "accent")
	B.cylY(0.2, 1.4, cf(0, -0.42, 0), "accent")
	B.box(1.6, 0.95, 0.9, cf(0, 0.1, 0), "main")
	for i = 0, 3 do
		local x = -0.6 + i * 0.4
		B.box(0.32, 1.1, 0.4, cf(x, 1.05, 0.04, 0, 0, -4 + i * 2.5), "main")
		B.box(0.36, 0.18, 0.46, cf(x, 0.6, 0.08), "accent")
	end
	B.box(0.38, 0.85, 0.4, cf(-0.95, 0.35, 0.15, 0, 0, 38), "main")
	B.ball(0.35, cf(0, 0.1, 0.5), "glow")
	B.box(0.08, 1.0, 0.05, cf(0, -0.9, 0.66), "glow")
end

R.heart = function(B)
	B.ball(1.5, cf(-0.55, 0.45, 0), "main")
	B.ball(1.5, cf(0.55, 0.45, 0), "main")
	B.spike(1.2, 1.8, 2.5, cf(0, -0.65, 0, 0, 0, 180), "main")
	B.cylY(0.6, 0.35, cf(-0.3, 1.35, -0.1, 0, 0, 15), "accent")
	B.cylY(0.5, 0.3, cf(0.35, 1.3, -0.15, 0, 0, -20), "accent")
	B.box(0.08, 1.2, 0.08, cf(-0.4, 0.0, 0.62, 0, 0, 25), "accent")
	B.box(0.08, 1.0, 0.08, cf(0.35, 0.15, 0.62, 0, 0, -30), "accent")
end

-- Generic shapes (fallbacks and non-relic art such as suits)
R.Ball = function(B)
	B.ball(2.2, cf(), "main")
end
R.Block = function(B)
	B.box(2.0, 1.6, 2.0, cf(), "main")
end
R.Cylinder = function(B)
	B.cylY(2.2, 1.8, cf(), "main")
end
R.Wedge = function(B)
	B.spike(1.2, 2.4, 2.2, cf(), "main")
end

RelicArt.Recipes = R

------------------------------------------------------------------------------------------
-- Build
------------------------------------------------------------------------------------------
local function resolve(col: string, P, mut, forViewport: boolean)
	-- returns color, material, transparencyOverride
	local color, material = nil, nil
	if col == "main" then
		if mut then
			local matName = mut.Material
			if forViewport and (matName == "ForceField" or matName == "Glass") then
				matName = "Neon"
			end
			return mut.Color, matName, if mut.Material == "Glass" and not forViewport then 0.25 else 0
		end
		color, material = P.main, P.mat or "SmoothPlastic"
	elseif col == "glow" then
		color, material = P.glow or P.accent or P.main, "Neon"
	elseif P[col] and typeof(P[col]) == "Color3" then
		color, material = P[col], "SmoothPlastic"
	elseif NAMED[col] then
		color, material = NAMED[col][1], NAMED[col][2]
	else
		color, material = P.main, "SmoothPlastic"
	end
	return color, material, nil
end

local function makePart(spec): BasePart
	local p: BasePart
	if spec.kind == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if spec.kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif spec.kind == "Cyl" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	if spec.kind == "Ellip" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function RelicArt.ArtFor(relicId: string, fallbackShape: string?)
	local art = RelicArt.Map[relicId]
	if art and R[art.kind] then
		return art
	end
	return { kind = fallbackShape or "Ball", main = Color3.fromRGB(170, 170, 170), accent = Color3.fromRGB(110, 110, 120) }
end

-- Build a model from an archetype + palette directly (used for suit helmets etc.)
function RelicArt.BuildArchetype(archetype: string, palette, opts)
	opts = opts or {}
	local recipe = R[archetype] or R.Ball
	local B = newBuilder()
	recipe(B, palette)

	local mutDefs = opts.mutationDefs
	local mut = nil
	if opts.mutations and #opts.mutations > 0 and mutDefs then
		mut = mutDefs[opts.mutations[1]]
	end

	-- Bounding box of the raw recipe
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, spec in B.parts do
		local h = spec.size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local w = spec.cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
					minV = minV:Min(w)
					maxV = maxV:Max(w)
				end
			end
		end
	end
	local center = (minV + maxV) / 2
	local extent = maxV - minV
	local longest = math.max(extent.X, extent.Y, extent.Z, 0.01)
	local k = (opts.targetSize or 4) * (opts.size or 1) / longest

	local model = Instance.new("Model")
	model.Name = opts.name or archetype
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * 0.2
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local glowColor = nil
	for i, spec in B.parts do
		local p = makePart(spec)
		p.Name = `P{i}`
		p.Size = spec.size * k
		p.CFrame = CFrame.new((spec.cf.Position - center) * k) * spec.cf.Rotation
		local color, matName, transOverride =
			resolve(spec.col, palette, if spec.col == "main" then mut else nil, opts.forViewport == true)
		p.Color = color
		local mat = Enum.Material[spec.mat or matName or "SmoothPlastic"]
		if spec.col == "main" and mut then
			mat = Enum.Material[matName] -- mutation material wins on the body
		end
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Transparency = transOverride or spec.trans or 0
		if p.Material == Enum.Material.Neon then
			glowColor = glowColor or p.Color
		end
		p.Parent = model
	end

	if opts.light ~= false and not opts.forViewport then
		local light = Instance.new("PointLight")
		light.Color = if mut then mut.Color else (glowColor or opts.rarityColor or palette.main)
		light.Range = 10 * (opts.size or 1)
		light.Brightness = 1.6
		light.Parent = root
	end
	return model
end

-- Move a freshly built model so its centre (the Root, at the origin) lands on `cf`.
-- Same result as Model:PivotTo for these models; plain CFrame math, so it also runs in Lune.
function RelicArt.Place(model: Model, cf: CFrame)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = cf * part.CFrame
		end
	end
end

-- def: Relics.ById entry. opts: see header.
function RelicArt.Build(def, opts)
	opts = opts or {}
	local art = RelicArt.ArtFor(def.Id, def.Shape)
	local o = table.clone(opts)
	o.name = o.name or def.Id
	return RelicArt.BuildArchetype(art.kind, art, o)
end

return RelicArt
