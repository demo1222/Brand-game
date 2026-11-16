-- Blender meshes for the world: zone guardians and reef props (tools/blender/run_world.py).
--
-- Upload models/monsters/monsters_bundle_1.glb and models/world/world_bundle_1.glb the same way
-- as the relic bundles (Studio: Import 3D, or Asset Manager > Bulk Import, then publish), and
-- paste the asset IDs into Bundles below. RelicMeshService.EnsureWorldMeshes loads them into
-- ReplicatedStorage.WorldMeshes at boot; until then the game uses its code-built versions.
--
-- Model names inside the bundles:
--   ReefShark, Barracuda, WreckShark, AbyssAngler      -> GuardianController (MonsterArt)
--   CORAL_Brain, CORAL_Branch, CORAL_Fan, CORAL_Tube, CORAL_Table, KELP -> WorldService reef
--   AIR_RACK                                           -> the tank rack on every dock
-- Parts are "<ID>_<Role>". WorldService recolours _Main parts to each coral's hue.

local rgb = Color3.fromRGB

-- Studio's importer drops the glTF material colours (parts arrive grey), so the game owns the
-- colours, per role (the part name after "<ID>_"), like Config.RelicMeshes. Roles listed in
-- Neon glow. Reef props: WorldService still recolours _Main/_Tip to each coral's hue.
local SHARK = { Body = rgb(110, 140, 165), Belly = rgb(235, 238, 240), Accent = rgb(70, 90, 110), Eye = rgb(20, 20, 24), Teeth = rgb(250, 248, 235), Tail = rgb(110, 140, 165), TailFin = rgb(110, 140, 165), Jaw = rgb(235, 238, 240), JawTeeth = rgb(250, 248, 235) }
local Colors = {
	ReefShark = SHARK,
	Barracuda = { Body = rgb(150, 175, 160), Belly = rgb(220, 230, 215), Accent = rgb(60, 110, 70), Glow = rgb(240, 210, 60), Teeth = rgb(250, 248, 235), Tail = rgb(60, 110, 70), TailFin = rgb(60, 110, 70), Jaw = rgb(220, 230, 215), JawTeeth = rgb(250, 248, 235) },
	WreckShark = { Body = rgb(58, 66, 80), Belly = rgb(190, 190, 185), Accent = rgb(150, 40, 40), Glow = rgb(255, 50, 40), Teeth = rgb(250, 248, 235), Tail = rgb(58, 66, 80), TailFin = rgb(58, 66, 80), Jaw = rgb(190, 190, 185), JawTeeth = rgb(250, 248, 235) },
	AbyssAngler = { Body = rgb(34, 30, 46), Belly = rgb(60, 50, 70), Accent = rgb(42, 36, 56), Glow = rgb(80, 240, 255), Teeth = rgb(240, 238, 230), Tail = rgb(34, 30, 46), TailFin = rgb(34, 30, 46), Jaw = rgb(60, 50, 70), JawTeeth = rgb(240, 238, 230) },
	CORAL_Brain = { Main = rgb(255, 110, 140), Tip = rgb(255, 180, 196), Rock = rgb(180, 168, 140) },
	CORAL_Branch = { Main = rgb(170, 100, 255), Glow = rgb(230, 200, 255), Rock = rgb(180, 168, 140) },
	CORAL_Fan = { Main = rgb(255, 160, 60), Tip = rgb(255, 210, 154), Stem = rgb(140, 90, 42), Rock = rgb(180, 168, 140) },
	CORAL_Tube = { Main = rgb(255, 214, 90), Tip = rgb(40, 20, 42), Rock = rgb(180, 168, 140) },
	CORAL_Table = { Main = rgb(70, 210, 200), Tip = rgb(168, 240, 234), Stem = rgb(44, 138, 132), Rock = rgb(180, 168, 140) },
	KELP = { Main = rgb(60, 140, 60), Tip = rgb(150, 210, 80), Stem = rgb(110, 96, 40), Glow = rgb(200, 180, 60), Rock = rgb(60, 90, 60) },
	AIR_RACK = { Main = rgb(250, 200, 40), Tip = rgb(240, 240, 240), Stem = rgb(70, 78, 92), Accent = rgb(40, 40, 46) },
}

-- Paint a cloned world mesh by role (call on every clone; cheap)
local function paint(model: Instance, id: string)
	local colors = Colors[id]
	if not colors then
		return
	end
	local prefix = id .. "_"
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name:sub(1, #prefix) == prefix then
			local role = p.Name:sub(#prefix + 1)
			local c = colors[role]
			if c then
				p.Color = c
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
			end
			p.Material = if role == "Glow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

return {
	Colors = Colors,
	Paint = paint,
	Bundles = {
		-- 0000000000, -- monsters_bundle_1.glb
		-- 0000000000, -- world_bundle_1.glb
	},
	Names = {
		"ReefShark",
		"Barracuda",
		"WreckShark",
		"AbyssAngler",
		"CORAL_Brain",
		"CORAL_Branch",
		"CORAL_Fan",
		"CORAL_Tube",
		"CORAL_Table",
		"KELP",
		"AIR_RACK",
	},
}
