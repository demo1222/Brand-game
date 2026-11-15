-- RelicAura: "the rarer, the louder" (docs/ART_PASS_PLAN.md).
--
--   RelicAura.Decorate(model, rarity, size)  world only: lights, particles, a light pillar.
--       Adds the "RelicAura" tag so RelicAuraController animates the model on clients.
--   RelicAura.Animate(model, t)              moves Spin_ and Aura_ parts. Used for world models
--       (RelicAuraController) and ViewportFrame cards (RelicView). Pure CFrame maths, cheap.
--   RelicAura.CardGlow(rarity)               glow settings for a card backdrop, or nil.
--
-- Part roles come from the Blender models (RelicArt.FromTemplate sets the Role attribute):
--   Spin_*            turns in place around its own vertical axis (Spin_Lid blinks instead)
--   orbit auras       the whole cloud circles the relic (shards, cubes, rocks, notes...)
--   pulse auras       rings, halos and rays breathe in size
--   other Aura_       bob up and down

local RelicAura = {}

local Rarities = require(script.Parent.Config.Rarities)

local TAG = "RelicAura"

local ORBIT = {
	Aura_Notes = true,
	Aura_Plates = true,
	Aura_Rocks = true,
	Aura_Cubes = true,
	Aura_Pearls = true,
	Aura_Void = true,
	Aura_Shards = true,
	Aura_Embers = true,
	Aura_Runes = true,
}
local PULSE = {
	Aura_Halo = true,
	Aura_Waves = true,
	Aura_Pulse = true,
	Aura_Ring = true,
	Aura_Rays = true,
	Aura_Foam = true,
	Aura_Fan = true,
	Aura_Flames = true,
	Aura_Slashes = true,
}

-- Per tier: light range/brightness (per stud of relic size), particle rate, pillar.
local TIERS = {
	[3] = { light = 2.0, bright = 0.9, rate = 2, size = 0.12, pillar = false }, -- Rare
	[4] = { light = 2.5, bright = 1.3, rate = 5, size = 0.15, pillar = false }, -- Epic
	[5] = { light = 3.2, bright = 1.9, rate = 10, size = 0.18, pillar = false, motes = true }, -- Legendary
	[6] = { light = 4.0, bright = 2.6, rate = 18, size = 0.2, pillar = true, motes = true }, -- Mythic
	[7] = { light = 3.0, bright = 1.6, rate = 14, size = 0.22, pillar = true, motes = true, dark = true }, -- Secret
}

local function roleOf(p: Instance): string?
	local r = p:GetAttribute("Role")
	return if typeof(r) == "string" then r else nil
end

-- The colour that best represents the relic's aura: an Aura_ part, then Glow, then rarity.
local function auraColor(model: Model, rarity: string): Color3
	local glow = nil
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local r = roleOf(p)
			if r and string.sub(r, 1, 5) == "Aura_" then
				return p.Color
			elseif r == "Glow" then
				glow = glow or p.Color
			end
		end
	end
	local rc = Rarities[rarity]
	return glow or (if type(rc) == "table" then rc.Color else Color3.new(1, 1, 1))
end

------------------------------------------------------------------------------------------
-- World decoration (server or client; instances replicate)
------------------------------------------------------------------------------------------
function RelicAura.Decorate(model: Model, rarity: string, size: number)
	local tier = Rarities.TierOf(rarity)
	local cfg = TIERS[tier]
	local root = model.PrimaryPart
	if not cfg or not root then
		return
	end
	local color = auraColor(model, rarity)
	size = math.max(size, 1)

	local light = root:FindFirstChildWhichIsA("PointLight") or Instance.new("PointLight")
	light.Color = color
	light.Range = cfg.light * size
	light.Brightness = cfg.bright
	light.Shadows = false
	light.Parent = root

	local core = Instance.new("Attachment")
	core.Name = "AuraCore"
	core.Parent = root

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "AuraSparkles"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = if cfg.dark then 0.3 else 1
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.size * size),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Transparency = NumberSequence.new(0.1)
	sparkle.Lifetime = NumberRange.new(0.8, 1.6)
	sparkle.Rate = cfg.rate
	sparkle.Speed = NumberRange.new(0.3 * size, 0.8 * size)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core

	if cfg.motes then
		local motes = Instance.new("ParticleEmitter")
		motes.Name = "AuraMotes"
		motes.Texture = if cfg.dark then "rbxasset://textures/particles/smoke_main.dds" else "rbxasset://textures/particles/sparkles_main.dds"
		motes.Color = if cfg.dark then ColorSequence.new(Color3.fromRGB(20, 10, 30), color) else ColorSequence.new(color)
		motes.LightEmission = if cfg.dark then 0 else 0.8
		motes.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05 * size),
			NumberSequenceKeypoint.new(0.4, (if cfg.dark then 0.35 else 0.12) * size),
			NumberSequenceKeypoint.new(1, 0),
		})
		motes.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, if cfg.dark then 0.4 else 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		motes.Lifetime = NumberRange.new(1.5, 2.5)
		motes.Rate = cfg.rate * 0.6
		motes.Speed = NumberRange.new(0.2 * size, 0.5 * size)
		motes.Acceleration = Vector3.new(0, 0.6 * size, 0)
		motes.EmissionDirection = Enum.NormalId.Top
		motes.SpreadAngle = Vector2.new(60, 60)
		motes.RotSpeed = NumberRange.new(-60, 60)
		motes.Parent = core
	end

	if cfg.pillar then
		local top = Instance.new("Attachment")
		top.Name = "AuraTop"
		top.Position = Vector3.new(0, size * 2.2, 0)
		top.Parent = root
		local beam = Instance.new("Beam")
		beam.Name = "AuraPillar"
		beam.Attachment0 = core
		beam.Attachment1 = top
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = if cfg.dark then 0.2 else 1
		beam.FaceCamera = true
		beam.Width0 = 0.35 * size
		beam.Width1 = 0.05 * size
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Segments = 1
		beam.Parent = root
	end

	model:SetAttribute("AuraTier", tier)
	model:AddTag(TAG)
end

------------------------------------------------------------------------------------------
-- Animation (client)
------------------------------------------------------------------------------------------
local state: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any

local function prepare(model: Model)
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local entries = {}
	local i = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			local r = roleOf(p)
			if r and (string.sub(r, 1, 5) == "Aura_" or string.sub(r, 1, 5) == "Spin_") then
				i += 1
				local kind = if r == "Spin_Lid"
					then "lid"
					elseif string.sub(r, 1, 5) == "Spin_" then "spin"
					elseif ORBIT[r] then "orbit"
					elseif PULSE[r] then "pulse"
					else "bob"
				table.insert(entries, {
					part = p,
					base = root.CFrame:ToObjectSpace(p.CFrame),
					size = p.Size,
					kind = kind,
					phase = i * 1.7,
					fast = r == "Aura_Flames",
				})
			end
		end
	end
	local ok, extent = pcall(function()
		return model:GetExtentsSize()
	end)
	local s = if ok then math.max(extent.X, extent.Y, extent.Z) else 4
	local st = { entries = entries, amp = s * 0.035 }
	state[model] = st
	return st
end

function RelicAura.HasMotion(model: Model): boolean
	local st = state[model] or prepare(model)
	return st ~= nil and #st.entries > 0
end

function RelicAura.Animate(model: Model, t: number)
	local st = state[model]
	-- Parts may still be streaming in: prepare again until the model has its aura parts.
	if not st or (#st.entries == 0 and (st.retries or 0) < 30) then
		local retries = if st then (st.retries or 0) + 1 else 0
		st = prepare(model)
		if st then
			st.retries = retries
		end
	end
	local root = model.PrimaryPart
	if not st or not root then
		return
	end
	local rootCF = root.CFrame
	local amp = st.amp
	for _, e in st.entries do
		local base = e.base
		local cf
		if e.kind == "spin" then
			cf = rootCF * CFrame.new(base.Position) * CFrame.Angles(0, t * 1.2 + e.phase, 0) * base.Rotation
		elseif e.kind == "orbit" then
			cf = rootCF * CFrame.Angles(0, t * 0.5, 0) * CFrame.new(0, math.sin(t * 1.4 + e.phase) * amp, 0) * base
		elseif e.kind == "pulse" then
			local k = 1 + (if e.fast then 0.12 * math.sin(t * 9 + e.phase) else 0.06 * math.sin(t * 2.4 + e.phase))
			e.part.Size = e.size * k
			cf = rootCF * base
		elseif e.kind == "lid" then
			local c = (t + e.phase) % 4.5
			local shut = if c < 0.12 then c / 0.12 elseif c < 0.24 then 1 - (c - 0.12) / 0.12 else 0
			cf = rootCF * CFrame.new(base.Position - Vector3.new(0, e.size.Y * 0.55 * shut, 0)) * base.Rotation
		else
			cf = rootCF * CFrame.new(0, math.sin(t * 1.6 + e.phase) * amp, 0) * base
		end
		e.part.CFrame = cf
	end
end

-- Card backdrop: colour, transparency and pulse speed by rarity. nil = no glow.
function RelicAura.CardGlow(rarity: string)
	local tier = Rarities.TierOf(rarity)
	local rc = Rarities[rarity]
	if tier < 4 or type(rc) ~= "table" then
		return nil
	end
	local color = if tier == 7 then Color3.fromRGB(150, 90, 255) else rc.Color
	return {
		color = color,
		transparency = ({ [4] = 0.72, [5] = 0.6, [6] = 0.48, [7] = 0.5 })[tier] or 0.7,
		pulse = ({ [4] = 0, [5] = 1.6, [6] = 2.4, [7] = 1.2 })[tier] or 0,
		size = ({ [4] = 0.7, [5] = 0.8, [6] = 0.92, [7] = 0.9 })[tier] or 0.7,
	}
end

RelicAura.Tag = TAG

return RelicAura
