-- Blender meshes for relics and salvage caches (docs/ART_PASS_PLAN.md).
--
-- Models are uploaded from models/relics/*.glb and models/caches/*.glb, either one per asset
-- (AssetId) or several in a bundle asset (Bundles). Studio keeps a copy of each in
-- ReplicatedStorage.RelicMeshes, named by relic ID or cache Name. RelicMeshService (server)
-- reloads any missing copy from its AssetId or bundle, so the place can be rebuilt from this
-- table alone. Built by tools/blender/run_relics.py; colours come from tools/blender/relic_builds.py.
--
-- Parts inside a model are named "<ID>_<Role>". Roles:
--   Main      body, recoloured by mutations
--   Glow      Neon
--   Aura_*    Neon, part of the rarity aura
--   Spin_*    Neon, turns in place
--   others    keep the colour below
-- Scale (optional) multiplies the relic's usual size, for thin shapes that read small.
-- Colors are the colours from the Blender prompt, so the game, not the file, owns them.

local rgb = Color3.fromRGB

local RelicMeshes = {
	-- Bundle assets: each holds many models, named by relic ID or cache Name.
	Bundles = {
		135490075248876, -- relics_bundle_1.glb: 35 relics, Rare to Secret
		120218913176639, -- caches_bundle_1.glb: CACHE_KELP, CACHE_WRECKS, CACHE_ABYSS, CACHE_TRENCH
	},

	Relics = {
		R021 = {
			AssetId = 138551824910166,
			Colors = {
				Main = rgb(255, 196, 64),
				Accent = rgb(232, 162, 28),
				Gem = rgb(90, 52, 16),
				Trim = rgb(217, 210, 191),
				Glow = rgb(255, 244, 194),
			},
		},
		R049 = {
			AssetId = 117722556428460,
			Scale = 1.3, -- thin silhouette; a Mythic should look big
			Colors = {
				Main = rgb(242, 230, 184),
				Accent = rgb(61, 52, 102),
				Trim = rgb(255, 196, 64),
				Gem = rgb(255, 122, 138),
				Glow = rgb(127, 232, 255),
				Spin_Shards = rgb(191, 246, 255),
				Aura_Halo = rgb(127, 232, 255),
				Aura_Cubes = rgb(168, 244, 255),
			},
		},
		R011 = {
			Colors = {
				Main = rgb(242, 179, 61),
				Accent = rgb(201, 206, 214),
				Glass = rgb(174, 227, 255),
				Trim = rgb(200, 150, 62),
				Glow = rgb(255, 255, 255),
			},
		},
		R012 = {
			Colors = {
				Main = rgb(237, 226, 200),
				Accent = rgb(203, 184, 146),
				Gem = rgb(247, 240, 255),
				Glow = rgb(255, 255, 255),
			},
		},
		R013 = {
			Colors = {
				Main = rgb(243, 226, 196),
				Accent = rgb(255, 143, 160),
				Trim = rgb(255, 196, 64),
				Gem = rgb(54, 214, 195),
				Glow = rgb(255, 179, 193),
			},
		},
		R020 = {
			Colors = {
				Main = rgb(211, 216, 224),
				Accent = rgb(184, 52, 63),
				Trim = rgb(240, 200, 96),
				Glow = rgb(255, 255, 255),
			},
		},
		R022 = {
			Colors = {
				Main = rgb(63, 174, 122),
				Trim = rgb(255, 196, 64),
				Accent = rgb(46, 107, 85),
				Glow = rgb(182, 255, 154),
			},
		},
		R023 = {
			Colors = {
				Main = rgb(63, 158, 140),
				Trim = rgb(242, 215, 192),
				Glass = rgb(28, 43, 58),
				Glow = rgb(154, 247, 255),
			},
		},
		R024 = {
			Scale = 1.2,
			Colors = {
				Main = rgb(62, 127, 90),
				Accent = rgb(123, 194, 91),
				Trim = rgb(255, 196, 64),
				Glow = rgb(201, 255, 107),
			},
		},
		R025 = {
			Colors = {
				Main = rgb(255, 196, 64),
				Accent = rgb(79, 163, 94),
				Gem = rgb(247, 240, 255),
				Glow = rgb(143, 243, 255),
				Aura_Notes = rgb(143, 243, 255),
			},
		},
		R030 = {
			Colors = {
				Main = rgb(210, 160, 74),
				Accent = rgb(107, 68, 40),
				Trim = rgb(138, 143, 153),
				Glow = rgb(159, 216, 255),
			},
		},
		R031 = {
			Colors = {
				Main = rgb(79, 143, 126),
				Glass = rgb(207, 239, 255),
				Glow = rgb(125, 255, 212),
				Trim = rgb(47, 58, 63),
				Gem = rgb(16, 58, 48),
			},
		},
		R032 = {
			Colors = {
				Main = rgb(138, 90, 52),
				Accent = rgb(58, 61, 69),
				Trim = rgb(255, 196, 64),
				Gem = rgb(247, 240, 255),
				Glow = rgb(255, 212, 90),
			},
		},
		R033 = {
			Colors = {
				Main = rgb(228, 181, 74),
				Accent = rgb(46, 77, 154),
				Gem = rgb(78, 123, 217),
				Glow = rgb(168, 240, 255),
			},
		},
		R034 = {
			Colors = {
				Main = rgb(200, 150, 62),
				Accent = rgb(242, 230, 200),
				Trim = rgb(138, 90, 32),
				Spin_Needle = rgb(255, 107, 92),
				Glow = rgb(255, 212, 90),
			},
		},
		R035 = {
			Colors = {
				Main = rgb(233, 215, 168),
				Accent = rgb(123, 63, 160),
				Trim = rgb(42, 30, 58),
				Glow = rgb(194, 123, 255),
			},
		},
		R036 = {
			Colors = {
				Main = rgb(156, 107, 66),
				Accent = rgb(47, 94, 142),
				Trim = rgb(255, 196, 64),
				Glow = rgb(191, 246, 255),
				Gem = rgb(217, 210, 191),
				Eyes = rgb(42, 26, 16),
				Aura_Foam = rgb(191, 246, 255),
				Aura_Pearls = rgb(247, 240, 255),
			},
		},
		R037 = {
			Scale = 1.2,
			Colors = {
				Main = rgb(86, 96, 110),
				Accent = rgb(184, 190, 200),
				Trim = rgb(184, 52, 63),
				Glow = rgb(125, 255, 138),
				Gem = rgb(36, 36, 44),
				Aura_Runes = rgb(125, 255, 138),
			},
		},
		R038 = {
			Colors = {
				Main = rgb(176, 122, 62),
				Accent = rgb(79, 163, 138),
				Trim = rgb(90, 62, 40),
				Glow = rgb(143, 224, 255),
				Spin_Rope = rgb(191, 242, 255),
				Aura_Waves = rgb(143, 224, 255),
			},
		},
		R041 = {
			Colors = {
				Main = rgb(58, 61, 69),
				Accent = rgb(237, 228, 208),
				Glow = rgb(255, 226, 122),
				Trim = rgb(107, 111, 120),
				Aura_Rays = rgb(255, 226, 122),
			},
		},
		R042 = {
			Colors = {
				Main = rgb(106, 96, 136),
				Gem = rgb(58, 46, 85),
				Glow = rgb(181, 123, 255),
				Accent = rgb(122, 110, 152),
				Trim = rgb(232, 221, 255),
			},
		},
		R043 = {
			Colors = {
				Main = rgb(230, 220, 196),
				Accent = rgb(255, 255, 255),
				Glow = rgb(127, 232, 255),
				Gem = rgb(58, 50, 38),
			},
		},
		R044 = {
			Colors = {
				Glass = rgb(191, 233, 255),
				Main = rgb(160, 122, 78),
				Glow = rgb(127, 255, 224),
			},
		},
		R045 = {
			Colors = {
				Main = rgb(47, 74, 68),
				Accent = rgb(78, 122, 106),
				Glow = rgb(125, 255, 192),
				Trim = rgb(217, 210, 191),
			},
		},
		R046 = {
			Colors = {
				Main = rgb(110, 31, 51),
				Accent = rgb(42, 15, 24),
				Trim = rgb(233, 199, 207),
				Glow = rgb(98, 200, 255),
			},
		},
		R047 = {
			Colors = {
				Main = rgb(44, 38, 56),
				Trim = rgb(255, 196, 64),
				Glow = rgb(255, 90, 60),
				Aura_Flames = rgb(255, 90, 60),
			},
		},
		R048 = {
			Colors = {
				Main = rgb(43, 166, 160),
				Accent = rgb(230, 220, 196),
				Trim = rgb(90, 58, 38),
				Glow = rgb(127, 255, 232),
				Aura_Plates = rgb(127, 255, 232),
			},
		},
		R050 = {
			Colors = {
				Main = rgb(58, 53, 72),
				Accent = rgb(94, 58, 122),
				Gem = rgb(237, 230, 242),
				Glow = rgb(195, 107, 255),
				Eyes = rgb(18, 10, 26),
				Spin_Lid = rgb(74, 58, 92),
				Aura_Fan = rgb(195, 107, 255),
				Aura_Ring = rgb(224, 184, 255),
			},
		},
		R051 = {
			Colors = {
				Main = rgb(18, 16, 22),
				Accent = rgb(232, 226, 240),
				Glow = rgb(185, 140, 255),
				Spin_Glyphs = rgb(217, 194, 255),
				Aura_Void = rgb(58, 30, 92),
			},
		},
		R052 = {
			Scale = 1.1,
			Colors = {
				Main = rgb(239, 231, 210),
				Accent = rgb(74, 58, 52),
				Trim = rgb(122, 127, 136),
				Glow = rgb(255, 106, 74),
				Aura_Slashes = rgb(255, 106, 74),
				Aura_Embers = rgb(255, 176, 74),
			},
		},
		R054 = {
			Colors = {
				Main = rgb(124, 133, 144),
				Glow = rgb(99, 230, 255),
				Trim = rgb(217, 210, 191),
			},
		},
		R055 = {
			Colors = {
				Gem = rgb(221, 244, 255),
				Main = rgb(46, 43, 48),
				Glow = rgb(255, 255, 255),
			},
		},
		R056 = {
			Scale = 1.2,
			Colors = {
				Main = rgb(238, 228, 204),
				Accent = rgb(63, 111, 74),
				Trim = rgb(58, 42, 34),
				Gem = rgb(224, 48, 63),
				Glow = rgb(157, 255, 122),
			},
		},
		R057 = {
			Colors = {
				Main = rgb(58, 47, 46),
				Glow = rgb(255, 122, 42),
				Accent = rgb(90, 68, 64),
			},
		},
		R058 = {
			Colors = {
				Main = rgb(217, 169, 58),
				Accent = rgb(94, 143, 106),
				Trim = rgb(255, 122, 138),
				Gem = rgb(247, 240, 255),
				Glow = rgb(77, 255, 184),
				Spin_Droplets = rgb(174, 233, 255),
				Aura_Shards = rgb(77, 255, 184),
			},
		},
		R059 = {
			Colors = {
				Main = rgb(91, 98, 112),
				Accent = rgb(58, 63, 74),
				Glow = rgb(255, 74, 58),
				Trim = rgb(217, 210, 191),
				Aura_Rocks = rgb(255, 74, 58),
			},
		},
		R060 = {
			Colors = {
				Main = rgb(106, 58, 60),
				Glow = rgb(255, 90, 42),
				Accent = rgb(138, 90, 76),
				Spin_Rocks = rgb(90, 64, 68),
				Aura_Pulse = rgb(192, 40, 26),
			},
		},
	},

	-- One cache per zone index. A zone without an entry keeps the procedural sand mound.
	Caches = {
		[1] = {
			Name = "CACHE_REEF",
			AssetId = 86216966481980,
			Width = 6, -- studs across, after scaling
			-- Saturated on purpose: the reef's bright sand and teal fog wash out pastels.
			Colors = {
				Main = rgb(196, 160, 104),
				Accent = rgb(255, 104, 92),
				Trim = rgb(255, 196, 64),
				Glow = rgb(255, 200, 40),
				Lid = rgb(255, 140, 120),
				LidInner = rgb(255, 214, 150),
			},
		},
		[2] = {
			Name = "CACHE_KELP",
			Width = 6,
			Colors = {
				Main = rgb(74, 90, 76),
				Accent = rgb(138, 90, 52),
				Trim = rgb(79, 163, 94),
				Lid = rgb(156, 107, 66),
				Glow = rgb(255, 212, 90),
			},
		},
		[3] = {
			Name = "CACHE_WRECKS",
			Width = 6,
			Colors = {
				Main = rgb(90, 94, 102),
				Accent = rgb(110, 74, 48),
				Trim = rgb(58, 61, 69),
				Lid = rgb(122, 84, 52),
				Glow = rgb(255, 212, 90),
			},
		},
		[4] = {
			Name = "CACHE_ABYSS",
			Width = 6,
			Colors = {
				Main = rgb(30, 32, 48),
				Accent = rgb(58, 53, 72),
				Lid = rgb(74, 67, 96),
				Glow = rgb(138, 123, 255),
			},
		},
		[5] = {
			Name = "CACHE_TRENCH",
			Width = 6,
			Colors = {
				Main = rgb(42, 34, 36),
				Accent = rgb(58, 47, 46),
				Lid = rgb(74, 58, 54),
				Glow = rgb(255, 122, 42),
			},
		},
	},
}

-- "R049_Aura_Halo" -> "Aura_Halo"
function RelicMeshes.RoleOf(partName: string, id: string): string
	local prefix = id .. "_"
	if string.sub(partName, 1, #prefix) == prefix then
		return string.sub(partName, #prefix + 1)
	end
	return partName
end

function RelicMeshes.IsNeonRole(role: string): boolean
	return role == "Glow" or string.sub(role, 1, 5) == "Aura_" or string.sub(role, 1, 5) == "Spin_"
end

return RelicMeshes
