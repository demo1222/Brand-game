-- Icon: vector icons drawn from primitives (UI design "Icon set": 24-unit grid, 2-unit stroke).
-- Each icon is a list of lines, circles and rounded rectangles, rendered with Frames +
-- UICorner + UIStroke, so it needs no uploaded images and stays crisp at any size. When real
-- art is uploaded, Icons.Images still wins (see Icons.luau).
--
--   Icon.new(name, size, color, props?) -> Frame
--   Icon.Has(name) -> boolean
--
-- Primitive codes:  l x1 y1 x2 y2 (line) · c cx cy r (ring) · C cx cy r [color] (disc)
--                   r x y w h rx (outlined rect) · R x y w h rx [color] (filled rect)

local Icon = {}

local rgb = Color3.fromRGB
local GOLD, GOLD_DARK = rgb(245, 192, 74), rgb(169, 120, 30)
local PEARL, WHITE = rgb(191, 216, 255), rgb(255, 255, 255)

Icon.Specs = {
	-- navigation (match the design artboards)
	shop = { { "r", 5, 8, 14, 12, 2 }, { "l", 9, 8, 9, 5 }, { "l", 15, 8, 15, 5 }, { "l", 9, 5, 15, 5 } },
	bag = {
		{ "r", 6, 7, 12, 14, 3 },
		{ "r", 9, 13, 6, 4, 1 },
		{ "l", 10, 7, 10, 4 },
		{ "l", 14, 7, 14, 4 },
		{ "l", 10, 4, 14, 4 },
	},
	upgrade = { { "l", 6, 13, 12, 7 }, { "l", 12, 7, 18, 13 }, { "l", 6, 18, 12, 12 }, { "l", 12, 12, 18, 18 } },
	codex = { { "r", 4, 5, 16, 14, 2 }, { "l", 12, 5, 12, 19 } },
	quests = { { "r", 5, 4, 14, 16, 2 }, { "l", 8, 9, 16, 9 }, { "l", 8, 13, 16, 13 }, { "l", 8, 17, 13, 17 } },
	rebirth = { { "c", 12, 13, 7 }, { "l", 12, 6, 15, 3 }, { "l", 12, 6, 15, 9 } },
	top = { { "r", 7, 4, 10, 9, 4 }, { "l", 12, 13, 12, 17 }, { "r", 8, 17, 8, 3, 1 } },
	friends = { { "c", 9, 9, 3 }, { "c", 16.5, 10, 2.5 }, { "r", 4, 15, 10, 5, 2.5 }, { "r", 14, 15.5, 6, 4.5, 2 } },
	settings = {
		{ "c", 12, 12, 3 },
		{ "c", 12, 12, 7 },
		{ "l", 12, 2.5, 12, 5 },
		{ "l", 12, 19, 12, 21.5 },
		{ "l", 2.5, 12, 5, 12 },
		{ "l", 19, 12, 21.5, 12 },
	},
	diver = { { "c", 12, 11, 8 }, { "c", 12, 11, 3.5 }, { "r", 7, 18, 10, 3, 1 } },
	trade = { { "l", 5, 9, 19, 9 }, { "l", 15, 5, 19, 9 }, { "l", 19, 15, 5, 15 }, { "l", 9, 19, 5, 15 } },
	-- currencies (filled, fixed colours)
	coin = { { "C", 12, 12, 10, GOLD }, { "c", 12, 12, 6.5, GOLD_DARK } },
	pearl = { { "C", 12, 12, 9, PEARL }, { "C", 9, 9, 2.5, WHITE } },
	token = {
		{ "c", 12, 12, 9 },
		{ "l", 12, 7, 12, 17 },
		{ "l", 8, 9, 8, 13 },
		{ "l", 16, 9, 16, 13 },
		{ "l", 8, 13, 16, 13 },
	},
	-- HUD
	oxygen = { { "c", 9, 14, 4 }, { "c", 15.5, 7.5, 3 }, { "c", 17.5, 15.5, 2 } },
	sonar = { { "C", 12, 12, 2 }, { "c", 12, 12, 6 }, { "c", 12, 12, 10 } },
	flare = { { "r", 10, 9, 4, 11, 1 }, { "C", 12, 5.5, 2 } },
	home = { { "l", 12, 19, 12, 6 }, { "l", 7, 11, 12, 6 }, { "l", 17, 11, 12, 6 }, { "l", 5, 21, 19, 21 } },
	boost = { { "l", 4, 8, 14, 8 }, { "l", 7, 12, 20, 12 }, { "l", 4, 16, 14, 16 } },
	up = { { "l", 6, 15, 12, 9 }, { "l", 12, 9, 18, 15 } },
	down = { { "l", 6, 9, 12, 15 }, { "l", 12, 15, 18, 9 } },
	event = {
		{ "l", 13, 3, 6, 13 },
		{ "l", 6, 13, 12, 13 },
		{ "l", 12, 13, 11, 21 },
		{ "l", 11, 21, 18, 10 },
		{ "l", 18, 10, 12, 10 },
		{ "l", 12, 10, 13, 3 },
	},
	lock = { { "r", 5, 11, 14, 9, 2 }, { "r", 8, 4, 8, 10, 4 } },
	close = { { "l", 6, 6, 18, 18 }, { "l", 18, 6, 6, 18 } },
	check = { { "l", 5, 12, 10, 17 }, { "l", 10, 17, 19, 7 } },
	plus = { { "l", 12, 5, 12, 19 }, { "l", 5, 12, 19, 12 } },
	alert = { { "c", 12, 12, 9 }, { "l", 12, 7, 12, 13 }, { "C", 12, 16.5, 1 } },
	info = { { "c", 12, 12, 9 }, { "l", 12, 11, 12, 17 }, { "C", 12, 7.5, 1 } },
	-- items, passes, products
	display = { { "r", 8, 4, 8, 8, 4 }, { "l", 12, 12, 12, 16 }, { "r", 6, 16, 12, 4, 1 } },
	crown = {
		{ "l", 4, 17, 20, 17 },
		{ "l", 4, 17, 5, 7 },
		{ "l", 5, 7, 9, 12 },
		{ "l", 9, 12, 12, 5 },
		{ "l", 12, 5, 15, 12 },
		{ "l", 15, 12, 19, 7 },
		{ "l", 19, 7, 20, 17 },
	},
	star = {
		{ "l", 12, 3, 14.5, 9.5 },
		{ "l", 14.5, 9.5, 21, 9.5 },
		{ "l", 21, 9.5, 15.5, 13.5 },
		{ "l", 15.5, 13.5, 17.5, 20.5 },
		{ "l", 17.5, 20.5, 12, 16 },
		{ "l", 12, 16, 6.5, 20.5 },
		{ "l", 6.5, 20.5, 8.5, 13.5 },
		{ "l", 8.5, 13.5, 3, 9.5 },
		{ "l", 3, 9.5, 9.5, 9.5 },
		{ "l", 9.5, 9.5, 12, 3 },
	},
	gift = {
		{ "r", 4, 9, 16, 11, 2 },
		{ "l", 4, 13, 20, 13 },
		{ "l", 12, 9, 12, 20 },
		{ "c", 9.5, 6.5, 2.5 },
		{ "c", 14.5, 6.5, 2.5 },
	},
	box = { { "r", 4, 7, 16, 13, 2 }, { "l", 4, 11, 20, 11 }, { "l", 10, 14, 14, 14 } },
	potion = { { "c", 12, 15, 6 }, { "l", 10, 9.5, 10, 4 }, { "l", 14, 9.5, 14, 4 }, { "l", 9, 4, 15, 4 } },
	magnet = {
		{ "l", 6, 4, 6, 13 },
		{ "l", 18, 4, 18, 13 },
		{ "c", 12, 13, 6 },
		{ "l", 4, 4, 8, 4 },
		{ "l", 16, 4, 20, 4 },
	},
	scan = { { "c", 10, 10, 6 }, { "l", 14.5, 14.5, 20, 20 } },
	drone = {
		{ "r", 8, 10, 8, 5, 2 },
		{ "c", 5, 7, 2.5 },
		{ "c", 19, 7, 2.5 },
		{ "l", 8, 11, 6, 9 },
		{ "l", 16, 11, 18, 9 },
		{ "l", 12, 15, 12, 19 },
	},
	radio = {
		{ "r", 4, 8, 16, 12, 2 },
		{ "c", 9, 14, 2.5 },
		{ "l", 14, 12, 17, 12 },
		{ "l", 14, 16, 17, 16 },
		{ "l", 7, 8, 16, 3 },
	},
	ticket = { { "r", 3, 7, 18, 10, 2 }, { "l", 15, 7, 15, 17 } },
	heart = { { "c", 8.5, 9.5, 4 }, { "c", 15.5, 9.5, 4 }, { "l", 4.8, 11.5, 12, 19.5 }, { "l", 19.2, 11.5, 12, 19.5 } },
	sign = { { "r", 3, 5, 18, 9, 2 }, { "l", 12, 14, 12, 21 }, { "l", 7, 9.5, 17, 9.5 } },
	sparkle = { { "l", 12, 3, 12, 21 }, { "l", 3, 12, 21, 12 }, { "l", 6, 6, 18, 18 }, { "l", 18, 6, 6, 18 } },
	wrench = { { "c", 16, 8, 4 }, { "l", 13, 11, 5, 19 } },
	clock = { { "c", 12, 12, 9 }, { "l", 12, 12, 12, 7 }, { "l", 12, 12, 16, 14 } },
	gate = { { "r", 4, 5, 16, 15, 2 }, { "l", 9, 5, 9, 20 }, { "l", 15, 5, 15, 20 } },
	shield = { { "r", 5, 3, 14, 13, 3 }, { "l", 5, 13, 12, 21 }, { "l", 19, 13, 12, 21 } },
	bell = { { "r", 6, 5, 12, 12, 6 }, { "l", 4, 17, 20, 17 }, { "C", 12, 20, 1.5 } },
	-- zones
	fish = {
		{ "c", 10, 12, 5 },
		{ "l", 15, 12, 20, 8 },
		{ "l", 15, 12, 20, 16 },
		{ "l", 20, 8, 20, 16 },
		{ "C", 8, 11, 1 },
	},
	kelp = {
		{ "l", 8, 21, 6, 15 },
		{ "l", 6, 15, 9, 9 },
		{ "l", 9, 9, 7, 3 },
		{ "l", 15, 21, 17, 15 },
		{ "l", 17, 15, 14, 9 },
		{ "l", 14, 9, 16, 4 },
	},
	anchor = {
		{ "c", 12, 5, 2 },
		{ "l", 12, 7, 12, 20 },
		{ "l", 8, 10, 16, 10 },
		{ "l", 5, 15, 12, 20 },
		{ "l", 19, 15, 12, 20 },
	},
	eye = { { "c", 12, 12, 8 }, { "C", 12, 12, 3 } },
	vent = {
		{ "l", 6, 21, 10, 9 },
		{ "l", 18, 21, 14, 9 },
		{ "l", 6, 21, 18, 21 },
		{ "c", 12, 6, 2 },
		{ "c", 15, 3, 1.2 },
	},
}

function Icon.Has(name: string?): boolean
	return name ~= nil and Icon.Specs[name] ~= nil
end

local function frame(parent: Instance, z: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	return f
end

-- Draw `name` into a square Frame of `size` px. Stroke scales with size (2 units of 24).
function Icon.new(name: string, size: number, color: Color3, props): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon_" .. name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	for k, v in props or {} do
		(holder :: any)[k] = v
	end
	local z = holder.ZIndex + 1
	local k = size / 24
	local t = math.max(1, 2 * k)
	for _, prim in Icon.Specs[name] or {} do
		local kind = prim[1]
		if kind == "l" then
			local x1, y1, x2, y2 = prim[2] * k, prim[3] * k, prim[4] * k, prim[5] * k
			local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
			local f = frame(holder, z)
			f.BackgroundColor3 = color
			f.Size = UDim2.fromOffset(len + t, t)
			f.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
			f.Rotation = math.deg(math.atan2(y2 - y1, x2 - x1))
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		elseif kind == "c" or kind == "C" then
			local r = prim[4] * k
			local f = frame(holder, z)
			f.Position = UDim2.fromOffset(prim[2] * k, prim[3] * k)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
			if prim[5] then
				f:SetAttribute("Fixed", true)
			end
			if kind == "C" then
				f.BackgroundColor3 = prim[5] or color
				f.Size = UDim2.fromOffset(r * 2, r * 2)
			else
				-- UIStroke draws outside the frame: shrink by half a stroke so the ring is centred
				f.BackgroundTransparency = 1
				f.Size = UDim2.fromOffset(math.max(1, r * 2 - t), math.max(1, r * 2 - t))
				local s = Instance.new("UIStroke")
				s.Thickness = t
				s.Color = prim[5] or color
				if prim[5] then
					s:SetAttribute("Fixed", true)
				end
				s.Parent = f
			end
		elseif kind == "r" or kind == "R" then
			local x, y, w, h, rx = prim[2] * k, prim[3] * k, prim[4] * k, prim[5] * k, (prim[6] or 0) * k
			local f = frame(holder, z)
			f.Position = UDim2.fromOffset(x + w / 2, y + h / 2)
			local c = Instance.new("UICorner")
			c.Parent = f
			if prim[7] then
				f:SetAttribute("Fixed", true)
			end
			if kind == "R" then
				f.BackgroundColor3 = prim[7] or color
				f.Size = UDim2.fromOffset(w, h)
				c.CornerRadius = UDim.new(0, rx)
			else
				f.BackgroundTransparency = 1
				f.Size = UDim2.fromOffset(math.max(1, w - t), math.max(1, h - t))
				c.CornerRadius = UDim.new(0, math.max(0, rx - t / 2))
				local s = Instance.new("UIStroke")
				s.Thickness = t
				s.Color = color
				s.Parent = f
			end
		end
	end
	return holder
end

-- Recolour an icon made by Icon.new (selected tabs, disabled states)
function Icon.SetColor(holder: Instance, color: Color3)
	for _, d in holder:GetDescendants() do
		if d:IsA("UIStroke") and d:GetAttribute("Fixed") == nil then
			d.Color = color
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 and d:GetAttribute("Fixed") == nil then
			d.BackgroundColor3 = color
		end
	end
end

return Icon
