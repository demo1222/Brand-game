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

-- World label chip (UI/Visual Overhaul Plan, Phase 4). `size` is given in pixels for
-- compatibility but converted to studs (30 px ≈ 1 stud), so labels shrink with distance
-- instead of staying the same size on screen and piling up. The chip hides itself while its
-- text is empty. Callers keep using `bb.Label.Text` / `.TextColor3`.
function Build.Billboard(parent: Instance, text: string, size: UDim2?, offset: Vector3?, color: Color3?)
	local px = size or UDim2.fromOffset(200, 50)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(px.X.Offset / 30, px.Y.Offset / 30)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(11, 22, 38)
	label.BackgroundTransparency = 0.18
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.fromRGB(234, 244, 255)
	label.TextStrokeTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(63, 214, 230)
	stroke.Transparency = 0.55
	stroke.Thickness = 1.5
	stroke.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = label
	label.Parent = bb
	bb.Enabled = text ~= ""
	label:GetPropertyChangedSignal("Text"):Connect(function()
		bb.Enabled = label.Text ~= ""
	end)
	bb.Parent = parent
	return bb
end

-- Text panel painted onto a part face (dock signs, boards)
function Build.SurfaceLabel(part: BasePart, text: string, face: Enum.NormalId, color: Color3?)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(11, 22, 38)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.fromRGB(234, 244, 255)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.1, 0)
	pad.PaddingBottom = UDim.new(0.1, 0)
	pad.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(63, 214, 230)
	stroke.Thickness = 6
	stroke.Parent = label
	label.Parent = sg
	sg.Parent = part
	return sg
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
