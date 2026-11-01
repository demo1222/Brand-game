-- Small helpers for building graybox geometry and GUI on the server.

local Build = {}

function Build.Part(props): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" and k ~= "Children" then
			(p :: any)[k] = v
		end
	end
	if props.Children then
		for _, c in props.Children do
			c.Parent = p
		end
	end
	p.Parent = props.Parent
	return p
end

function Build.Instance(className: string, props)
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" and k ~= "Children" then
			(inst :: any)[k] = v
		end
	end
	if props and props.Children then
		for _, c in props.Children do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Build.Billboard(parent: Instance, text: string, size: UDim2?, offset: Vector3?, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = size or UDim2.fromOffset(200, 50)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = bb
	bb.Parent = parent
	return bb
end

function Build.Prompt(parent: Instance, action: string, object: string, hold: number?, name: string?)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name or "Prompt"
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

-- Builds a simple relic display model from its config row (graybox art)
function Build.RelicModel(def, rarityColor: Color3, mutations: { string }?, mutationDefs, size: number?)
	local scale = 1.4 * (size or 1)
	local shape = def.Shape
	local p = Instance.new("Part")
	p.Name = def.Id
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = rarityColor
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * scale
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(scale * 1.2, scale, scale)
	elseif shape == "Wedge" then
		p:Destroy()
		p = Instance.new("WedgePart")
		p.Name = def.Id
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Color = rarityColor
		p.Size = Vector3.new(scale * 0.6, scale, scale * 1.2)
	else
		p.Size = Vector3.new(scale, scale * 0.8, scale)
	end
	local tierGlow = rarityColor
	if mutations and #mutations > 0 then
		local m = mutationDefs[mutations[1]]
		if m then
			p.Color = m.Color
			local mat = Enum.Material[m.Material]
			if mat then
				p.Material = mat
			end
			tierGlow = m.Color
		end
	end
	local light = Instance.new("PointLight")
	light.Color = tierGlow
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = p
	return p
end

return Build
