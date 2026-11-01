-- Small helpers for building graybox geometry and GUI on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RelicArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicArt"))

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

-- Builds a relic display model (shared/RelicArt): the same procedural model the UI shows.
-- Returns a Model whose PrimaryPart ("Root") sits at the model's centre.
function Build.RelicModel(def, rarityColor: Color3, mutations: { string }?, mutationDefs, size: number?): Model
	return RelicArt.Build(def, {
		mutations = mutations,
		mutationDefs = mutationDefs,
		size = size or 1,
		targetSize = 2.2,
		rarityColor = rarityColor,
	})
end

return Build
