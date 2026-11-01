-- SuitArt (UI/Visual Overhaul Plan, Phase 4): real diver gear instead of a body recolour.
-- Builds welded, massless parts on the character for each suit tier: helmet, air supply,
-- fins/boots and gear (gloves, chest plate, armour), sized from the character's own body
-- parts so it fits R15 (any scale) and R6. Each category can be hidden by the player
-- (Settings: SuitHelmet, SuitTank, SuitFins, SuitGear); SuitColors = false keeps the player's
-- own outfit instead of the wetsuit colours.
--
--   SuitArt.Apply(character, suitIndex, settings)  -- (re)builds everything
--
-- Module load is Instance-free so the Lune tests can check the tier table.

local SuitArt = {}

local rgb = Color3.fromRGB

-- Per tier: which builder each category uses and the materials
SuitArt.Tiers = {
	{ helmet = "mask", tank = nil, feet = "fins", gear = nil, metal = rgb(40, 40, 46), metalMat = "SmoothPlastic" },
	{
		helmet = "mask",
		tank = "single",
		feet = "longfins",
		gear = "wrist",
		metal = rgb(60, 64, 72),
		metalMat = "Metal",
	},
	{ helmet = "dome", tank = "twin", feet = "boots", gear = "plate", metal = rgb(200, 145, 70), metalMat = "Metal" },
	{
		helmet = "dome",
		tank = "twin",
		feet = "boots",
		gear = "armor",
		metal = rgb(160, 166, 178),
		metalMat = "DiamondPlate",
	},
	{
		helmet = "abyssal",
		tank = "rebreather",
		feet = "longfins",
		gear = "armor",
		metal = rgb(30, 32, 40),
		metalMat = "Metal",
		glow = rgb(80, 230, 255),
		lamps = true,
	},
	{
		helmet = "titan",
		tank = "rebreather",
		feet = "boots",
		gear = "armor",
		metal = rgb(255, 196, 64),
		metalMat = "Foil",
		glow = rgb(255, 170, 60),
		lamps = true,
	},
}

SuitArt.Categories = { "Helmet", "Tank", "Fins", "Gear" }

local GLASS = rgb(170, 225, 255)

------------------------------------------------------------------------------------------
-- Helpers (Roblox only)
------------------------------------------------------------------------------------------
local function first(char: Model, ...: string): BasePart?
	for _, name in { ... } do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- Create a welded, massless piece at body.CFrame * offset
local function piece(
	folder: Instance,
	body: BasePart,
	kind: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: string?,
	transparency: number?
): BasePart
	local p: BasePart
	if kind == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif kind == "Cyl" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = "SuitPiece"
	p.Size = size
	p.Color = color
	p.Material = Enum.Material[material or "SmoothPlastic"]
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Anchored = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local rad = math.rad
local function cf(x, y, z, rx, ry, rz)
	return CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
end

------------------------------------------------------------------------------------------
-- Helmets (sized from the head)
------------------------------------------------------------------------------------------
local function helmet(folder: Instance, char: Model, tier, suitColor: Color3)
	local head = first(char, "Head")
	if not head then
		return
	end
	local s = math.max(head.Size.X, head.Size.Z)
	local m, mat = tier.metal, tier.metalMat
	if tier.helmet == "mask" then
		-- dive mask + snorkel
		piece(
			folder,
			head,
			"Block",
			Vector3.new(s * 0.9, s * 0.42, s * 0.16),
			cf(0, s * 0.12, -s * 0.5),
			rgb(30, 30, 36)
		)
		piece(
			folder,
			head,
			"Block",
			Vector3.new(s * 0.74, s * 0.3, s * 0.06),
			cf(0, s * 0.12, -s * 0.59),
			GLASS,
			"Glass",
			0.35
		)
		piece(folder, head, "Block", Vector3.new(s * 1.04, s * 0.12, s * 1.04), cf(0, s * 0.12, 0), rgb(30, 30, 36))
		piece(
			folder,
			head,
			"Cyl",
			Vector3.new(s * 1.1, s * 0.16, s * 0.16),
			cf(s * 0.56, s * 0.35, -s * 0.1, 0, 0, 90),
			suitColor
		)
		piece(
			folder,
			head,
			"Block",
			Vector3.new(s * 0.18, s * 0.18, s * 0.3),
			cf(s * 0.45, -s * 0.2, -s * 0.38),
			rgb(30, 30, 36)
		)
		return
	end
	local big = if tier.helmet == "titan" then 1.25 else 1
	local d = s * 1.55 * big
	-- dome, collar and bolts
	piece(folder, head, "Ball", Vector3.one * d, cf(0, s * 0.08, 0), m, mat)
	piece(folder, head, "Cyl", Vector3.new(s * 0.4, d * 0.95, d * 0.95), cf(0, -d * 0.46, 0, 0, 0, 90), m, mat)
	piece(
		folder,
		head,
		"Cyl",
		Vector3.new(s * 0.12, d * 1.02, d * 1.02),
		cf(0, -d * 0.62, 0, 0, 0, 90),
		rgb(40, 40, 46),
		"Metal"
	)
	if tier.helmet == "dome" then
		-- classic front porthole + side ports
		piece(
			folder,
			head,
			"Cyl",
			Vector3.new(s * 0.14, d * 0.6, d * 0.6),
			cf(0, s * 0.08, -d * 0.47, 0, 90, 0),
			m:Lerp(rgb(0, 0, 0), 0.25),
			mat
		)
		piece(
			folder,
			head,
			"Cyl",
			Vector3.new(s * 0.06, d * 0.48, d * 0.48),
			cf(0, s * 0.08, -d * 0.52, 0, 90, 0),
			GLASS,
			"Glass",
			0.45
		)
		for _, x in { -1, 1 } do
			piece(
				folder,
				head,
				"Cyl",
				Vector3.new(s * 0.1, d * 0.32, d * 0.32),
				cf(x * d * 0.47, s * 0.12, 0),
				m:Lerp(rgb(0, 0, 0), 0.25),
				mat
			)
			piece(
				folder,
				head,
				"Cyl",
				Vector3.new(s * 0.04, d * 0.24, d * 0.24),
				cf(x * d * 0.5, s * 0.12, 0),
				GLASS,
				"Glass",
				0.45
			)
		end
		piece(folder, head, "Cyl", Vector3.new(s * 0.3, s * 0.22, s * 0.22), cf(0, d * 0.5, 0, 0, 0, 90), m, mat)
	else
		-- armoured helmet with a glowing visor slit (Abyssal Rig / Titan)
		piece(
			folder,
			head,
			"Block",
			Vector3.new(d * 0.72, d * 0.18, s * 0.2),
			cf(0, s * 0.12, -d * 0.45),
			tier.glow or GLASS,
			"Neon"
		)
		piece(
			folder,
			head,
			"Block",
			Vector3.new(d * 0.16, d * 0.62, d * 0.16),
			cf(0, d * 0.2, -d * 0.36, -20, 0, 0),
			m:Lerp(rgb(0, 0, 0), 0.2),
			mat
		)
		if tier.lamps then
			for _, x in { -1, 1 } do
				local lamp = piece(
					folder,
					head,
					"Cyl",
					Vector3.new(s * 0.22, s * 0.3, s * 0.3),
					cf(x * d * 0.48, s * 0.35, -d * 0.12, 0, 90, 0),
					tier.glow or GLASS,
					"Neon"
				)
				local light = Instance.new("SpotLight")
				light.Face = Enum.NormalId.Right
				light.Angle = 50
				light.Range = 40
				light.Brightness = 3
				light.Color = tier.glow or Color3.new(1, 1, 1)
				light.Parent = lamp
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Air supply (on the upper torso's back: +Z is behind the character)
------------------------------------------------------------------------------------------
local function tank(folder: Instance, char: Model, tier, suitColor: Color3)
	local torso = first(char, "UpperTorso", "Torso")
	if not torso or not tier.tank then
		return
	end
	local w, h, dz = torso.Size.X, torso.Size.Y, torso.Size.Z
	local m, mat = tier.metal, tier.metalMat
	if tier.tank == "single" then
		local dia = w * 0.42
		piece(
			folder,
			torso,
			"Cyl",
			Vector3.new(h * 1.1, dia, dia),
			cf(0, 0, dz / 2 + dia / 2, 0, 0, 90),
			rgb(250, 200, 40),
			"Metal"
		)
		piece(
			folder,
			torso,
			"Cyl",
			Vector3.new(h * 0.12, dia * 0.5, dia * 0.5),
			cf(0, h * 0.6, dz / 2 + dia / 2, 0, 0, 90),
			rgb(40, 40, 46),
			"Metal"
		)
	elseif tier.tank == "twin" then
		local dia = w * 0.36
		for _, x in { -1, 1 } do
			piece(
				folder,
				torso,
				"Cyl",
				Vector3.new(h * 1.15, dia, dia),
				cf(x * dia * 0.55, 0, dz / 2 + dia / 2, 0, 0, 90),
				m,
				mat
			)
			piece(folder, torso, "Ball", Vector3.one * dia, cf(x * dia * 0.55, h * 0.57, dz / 2 + dia / 2), m, mat)
		end
		piece(
			folder,
			torso,
			"Block",
			Vector3.new(dia * 2.3, h * 0.1, dia * 0.4),
			cf(0, h * 0.25, dz / 2 + dia / 2),
			rgb(40, 40, 46),
			"Metal"
		)
		piece(
			folder,
			torso,
			"Block",
			Vector3.new(dia * 2.3, h * 0.1, dia * 0.4),
			cf(0, -h * 0.25, dz / 2 + dia / 2),
			rgb(40, 40, 46),
			"Metal"
		)
	else -- rebreather pack
		local pack = piece(
			folder,
			torso,
			"Block",
			Vector3.new(w * 0.85, h * 1.05, dz * 0.55),
			cf(0, 0, dz / 2 + dz * 0.27),
			m,
			mat
		)
		pack.Name = "Pack"
		for _, x in { -1, 1 } do
			piece(
				folder,
				torso,
				"Block",
				Vector3.new(w * 0.08, h * 0.8, dz * 0.57),
				cf(x * w * 0.3, 0, dz / 2 + dz * 0.28),
				tier.glow or suitColor,
				"Neon"
			)
		end
	end
end

------------------------------------------------------------------------------------------
-- Feet: fins or weighted boots
------------------------------------------------------------------------------------------
local function feet(folder: Instance, char: Model, tier, suitColor: Color3)
	local r15 = char:FindFirstChild("LeftFoot") ~= nil
	for _, side in { "Left", "Right" } do
		local foot: BasePart?, off: CFrame
		if r15 then
			foot = first(char, side .. "Foot")
			off = CFrame.new()
		else
			foot = first(char, side .. " Leg")
			off = CFrame.new(0, foot and -foot.Size.Y * 0.45 or 0, 0)
		end
		if foot then
			local fw = foot.Size.X
			local fl = if r15 then foot.Size.Z else foot.Size.Z
			local fh = if r15 then foot.Size.Y else foot.Size.Y * 0.1
			if tier.feet == "boots" then
				piece(
					folder,
					foot,
					"Block",
					Vector3.new(fw * 1.2, math.max(fh, 0.3) * 1.5, fl * 1.25),
					off * cf(0, 0, -fl * 0.05),
					tier.metal,
					tier.metalMat
				)
				piece(
					folder,
					foot,
					"Block",
					Vector3.new(fw * 1.25, 0.15, fl * 1.3),
					off * cf(0, -math.max(fh, 0.3) * 0.75, -fl * 0.05),
					rgb(30, 30, 34),
					"Metal"
				)
			else
				local len = fl * (if tier.feet == "longfins" then 2.4 else 1.6)
				local finColor = if tier.glow then tier.metal else suitColor:Lerp(rgb(0, 0, 0), 0.25)
				piece(folder, foot, "Block", Vector3.new(fw * 1.15, math.max(fh, 0.3) * 1.2, fl * 0.9), off, finColor)
				piece(
					folder,
					foot,
					"Block",
					Vector3.new(fw * 1.7, 0.1, len),
					off * cf(0, -math.max(fh, 0.3) * 0.3, -fl * 0.45 - len / 2),
					finColor,
					"SmoothPlastic"
				)
				if tier.glow then
					piece(
						folder,
						foot,
						"Block",
						Vector3.new(fw * 1.72, 0.12, 0.12),
						off * cf(0, -math.max(fh, 0.3) * 0.3, -fl * 0.45 - len),
						tier.glow,
						"Neon"
					)
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
-- Gear: wrist computer, chest plate, armour + gloves
------------------------------------------------------------------------------------------
local function gear(folder: Instance, char: Model, tier, suitColor: Color3)
	if not tier.gear then
		return
	end
	local m, mat = tier.metal, tier.metalMat
	local torso = first(char, "UpperTorso", "Torso")
	local lowerArm = first(char, "LeftLowerArm", "Left Arm")
	if tier.gear == "wrist" and lowerArm then
		piece(
			folder,
			lowerArm,
			"Block",
			Vector3.new(lowerArm.Size.X * 1.15, lowerArm.Size.Y * 0.25, lowerArm.Size.Z * 1.15),
			cf(0, -lowerArm.Size.Y * 0.2, 0),
			rgb(30, 30, 36)
		)
		piece(
			folder,
			lowerArm,
			"Block",
			Vector3.new(lowerArm.Size.X * 0.7, lowerArm.Size.Y * 0.18, 0.05),
			cf(0, -lowerArm.Size.Y * 0.2, -lowerArm.Size.Z * 0.6),
			rgb(80, 230, 255),
			"Neon"
		)
		return
	end
	if torso then
		local w, h, dz = torso.Size.X, torso.Size.Y, torso.Size.Z
		piece(
			folder,
			torso,
			"Block",
			Vector3.new(w * 0.86, h * 0.62, dz * 0.25),
			cf(0, h * 0.12, -dz / 2 - dz * 0.1),
			m,
			mat
		)
		if tier.glow then
			piece(
				folder,
				torso,
				"Block",
				Vector3.new(w * 0.3, h * 0.08, dz * 0.27),
				cf(0, h * 0.12, -dz / 2 - dz * 0.12),
				tier.glow,
				"Neon"
			)
		end
	end
	if tier.gear == "armor" then
		for _, side in { "Left", "Right" } do
			local upper = first(char, side .. "UpperArm", side .. " Arm")
			if upper then
				local x = if side == "Left" then -1 else 1
				piece(
					folder,
					upper,
					"Block",
					Vector3.new(upper.Size.X * 1.35, upper.Size.Y * 0.32, upper.Size.Z * 1.35),
					cf(x * upper.Size.X * 0.08, upper.Size.Y * 0.38, 0),
					m,
					mat
				)
			end
			local hand = first(char, side .. "Hand")
			if hand then
				piece(folder, hand, "Block", hand.Size * 1.2, CFrame.new(), m:Lerp(rgb(0, 0, 0), 0.3), mat)
			end
		end
		local lower = first(char, "LowerTorso")
		if lower then
			piece(
				folder,
				lower,
				"Block",
				Vector3.new(lower.Size.X * 1.08, lower.Size.Y * 0.35, lower.Size.Z * 1.12),
				cf(0, lower.Size.Y * 0.2, 0),
				rgb(40, 40, 46),
				"Metal"
			)
		end
	end
end

------------------------------------------------------------------------------------------
-- Outfit: wetsuit colours on/off without losing the player's own clothes
------------------------------------------------------------------------------------------
local function applyColors(char: Model, color: Color3?)
	local store = char:FindFirstChild("StoredOutfit")
	if color then
		if not store then
			store = Instance.new("Folder")
			store.Name = "StoredOutfit"
			store.Parent = char
		end
		for _, c in char:GetChildren() do
			if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
				c.Parent = store -- clothing only renders as a direct child of the character
			end
		end
		for _, part in char:GetChildren() do
			if part:IsA("BasePart") and part.Name ~= "Head" and part.Name ~= "HumanoidRootPart" then
				if part:GetAttribute("OrigColor") == nil then
					part:SetAttribute("OrigColor", part.Color)
				end
				part.Color = color
			end
		end
	else
		if store then
			for _, c in store:GetChildren() do
				c.Parent = char
			end
			store:Destroy()
		end
		for _, part in char:GetChildren() do
			local orig = part:GetAttribute("OrigColor")
			if part:IsA("BasePart") and typeof(orig) == "Color3" then
				part.Color = orig
				part:SetAttribute("OrigColor", nil)
			end
		end
	end
end

-- Hide hats and hair under a closed helmet (restored when the helmet is hidden)
local function setAccessoriesHidden(char: Model, hidden: boolean)
	for _, acc in char:GetChildren() do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local accType = acc.AccessoryType
				local onHead = accType == Enum.AccessoryType.Hat
					or accType == Enum.AccessoryType.Hair
					or accType == Enum.AccessoryType.Face
				if hidden and onHead then
					if handle:GetAttribute("OrigTransparency") == nil then
						handle:SetAttribute("OrigTransparency", handle.Transparency)
					end
					handle.Transparency = 1
				elseif not hidden then
					local orig = handle:GetAttribute("OrigTransparency")
					if typeof(orig) == "number" then
						handle.Transparency = orig
						handle:SetAttribute("OrigTransparency", nil)
					end
				end
			end
		end
	end
end

local function shown(settings, key: string): boolean
	return not settings or settings[key] ~= false
end

function SuitArt.Apply(char: Model, suitIndex: number, suitColor: Color3, settings)
	local old = char:FindFirstChild("DiverSuit")
	if old then
		old:Destroy()
	end
	local tier = SuitArt.Tiers[suitIndex] or SuitArt.Tiers[1]
	local root = Instance.new("Model")
	root.Name = "DiverSuit"
	local folders = {}
	for _, cat in SuitArt.Categories do
		local f = Instance.new("Folder")
		f.Name = cat
		f.Parent = root
		folders[cat] = f
	end
	if shown(settings, "SuitHelmet") then
		helmet(folders.Helmet, char, tier, suitColor)
	end
	if shown(settings, "SuitTank") then
		tank(folders.Tank, char, tier, suitColor)
	end
	if shown(settings, "SuitFins") then
		feet(folders.Fins, char, tier, suitColor)
	end
	if shown(settings, "SuitGear") then
		gear(folders.Gear, char, tier, suitColor)
	end
	root.Parent = char
	applyColors(char, if shown(settings, "SuitColors") then suitColor else nil)
	setAccessoriesHidden(char, shown(settings, "SuitHelmet") and tier.helmet ~= "mask")
	return root
end

return SuitArt
