-- RelicView: live 3D "photos" of relics in ViewportFrames (UI/Visual Overhaul Plan, Phase 1).
-- Templates are built once per relic + first mutation (RelicArt) and cloned per view.
--
--   RelicView.new(props) -> ViewportFrame
--     props.Relic       { id, mutations?, size? }  (or props.Id for a bare relic id)
--     props.Spin        orbit the camera (detail panel, reveal)
--     props.Silhouette  render as a black shape (undiscovered Codex entries)
--     props.Angle       static yaw in degrees (default 28)
--     + any ViewportFrame property (Size, Position, AnchorPoint, ZIndex, Parent, ...)
--   RelicView.Archetype(archetype, palette, props) -> ViewportFrame (suit helmets etc.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RelicArt = require(Shared.RelicArt)
local Relics = require(Shared.Config.Relics)
local Mutations = require(Shared.Config.Mutations)
local RelicAura = require(Shared.RelicAura)

local RelicView = {}

-- Blender relic meshes load lazily, so a card's first frame can be blank. Fetch them all once.
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("RelicMeshes", 10)
	if folder then
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(folder:GetDescendants())
		end)
	end
end)

local TARGET = 4 -- model size in studs inside the viewport
local FOV = 32
local templates: { [string]: Model } = {}
local spinning = setmetatable({}, { __mode = "k" }) :: { [ViewportFrame]: { cam: Camera, dist: number, pitch: number, speed: number, yaw: number } }
local spinConn: RBXScriptConnection? = nil

local function cameraCFrame(yawDeg: number, pitchDeg: number, dist: number): CFrame
	local rot = CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(math.rad(-pitchDeg), 0, 0)
	return CFrame.lookAt(rot * Vector3.new(0, 0, dist), Vector3.zero)
end

local function ensureSpinLoop()
	if spinConn then
		return
	end
	spinConn = RunService.RenderStepped:Connect(function(dt)
		local any = false
		for vpf, s in spinning do
			any = true
			if vpf.Parent == nil then
				spinning[vpf] = nil
			elseif vpf.Visible then
				s.yaw = (s.yaw + dt * s.speed) % 360
				s.cam.CFrame = cameraCFrame(s.yaw, s.pitch, s.dist)
			end
		end
		if not any and spinConn then
			spinConn:Disconnect()
			spinConn = nil
		end
	end)
end

local function templateFor(id: string, mutations: { string }?): Model?
	local def = Relics.ById[id]
	if not def then
		return nil
	end
	local m1 = if mutations and mutations[1] then mutations[1] else ""
	local key = `{id}|{m1}`
	local t = templates[key]
	if not t then
		t = RelicArt.Build(def, {
			mutations = if m1 ~= "" then { m1 } else nil,
			mutationDefs = Mutations.ById,
			targetSize = TARGET,
			forViewport = true,
			light = false,
		})
		templates[key] = t
	end
	return t
end

------------------------------------------------------------------------------------------
-- Aura motion and rarity glow (RelicAura): Spin_/Aura_ parts move, Epic+ cards get a glow.
------------------------------------------------------------------------------------------
local auraViews = setmetatable({}, { __mode = "k" }) :: { [ViewportFrame]: Model }
local glowViews = setmetatable({}, { __mode = "k" }) :: { [Frame]: any }
local fxConn: RBXScriptConnection? = nil

local function ensureFxLoop()
	if fxConn then
		return
	end
	fxConn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local any = false
		for vpf, model in auraViews do
			any = true
			if vpf.Parent == nil then
				auraViews[vpf] = nil
			elseif vpf.Visible then
				RelicAura.Animate(model, t)
			end
		end
		for frame, g in glowViews do
			any = true
			if frame.Parent == nil then
				glowViews[frame] = nil
			elseif g.pulse > 0 then
				local k = (math.sin(t * g.pulse) + 1) / 2
				g.inner.BackgroundTransparency = g.transparency + 0.15 * k
				g.outer.BackgroundTransparency = math.min(g.transparency + 0.2 + 0.12 * (1 - k), 1)
			end
		end
		if not any and fxConn then
			fxConn:Disconnect()
			fxConn = nil
		end
	end)
end

local function circle(scale: number, color: Color3, transparency: number, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(scale, scale)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = f
	f.Parent = parent
	return f
end

-- A soft rarity glow under the model: two circles in a frame that tracks the viewport.
local function addGlow(vpf: ViewportFrame, parent: Instance, g)
	local holder = Instance.new("Frame")
	holder.Name = "RarityGlow"
	holder.BackgroundTransparency = 1
	holder.Size = vpf.Size
	holder.Position = vpf.Position
	holder.AnchorPoint = vpf.AnchorPoint
	holder.ZIndex = math.max(vpf.ZIndex - 1, 0)
	holder.Visible = vpf.Visible
	local outer = circle(g.size * 1.2, g.color, math.min(g.transparency + 0.2, 1), holder)
	local inner = circle(g.size * 0.75, g.color, g.transparency, holder)
	holder.Parent = parent
	vpf:GetPropertyChangedSignal("Visible"):Connect(function()
		holder.Visible = vpf.Visible
	end)
	vpf.AncestryChanged:Connect(function()
		if vpf.Parent ~= parent then
			holder:Destroy()
		end
	end)
	glowViews[holder] = { inner = inner, outer = outer, transparency = g.transparency, pulse = g.pulse }
	ensureFxLoop()
end

local function mount(model: Model, props, rarity: string?)
	local vpf = Instance.new("ViewportFrame")
	vpf.BackgroundTransparency = 1
	vpf.Ambient = Color3.fromRGB(150, 155, 170)
	vpf.LightColor = Color3.fromRGB(255, 250, 240)
	vpf.LightDirection = Vector3.new(-0.6, -1, -0.8)
	vpf.Size = UDim2.fromScale(1, 1)
	for k, v in props do
		if
			k ~= "Relic"
			and k ~= "Id"
			and k ~= "Spin"
			and k ~= "Silhouette"
			and k ~= "Angle"
			and k ~= "Pitch"
			and k ~= "Parent"
			and k ~= "Zoom"
		then
			(vpf :: any)[k] = v
		end
	end
	if props.Silhouette then
		vpf.ImageColor3 = Color3.new(0, 0, 0)
		vpf.ImageTransparency = 0.15
	end

	local clone = model:Clone()
	clone.Parent = vpf
	local _, size = clone:GetBoundingBox()
	local radius = math.max(size.Magnitude / 2, 0.5)
	local dist = radius / math.tan(math.rad(FOV / 2)) * (props.Zoom or 1.1)

	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	local yaw = props.Angle or 28
	local pitch = props.Pitch or 14
	cam.CFrame = cameraCFrame(yaw, pitch, dist)
	cam.Parent = vpf
	vpf.CurrentCamera = cam

	if props.Spin then
		spinning[vpf] = {
			cam = cam,
			dist = dist,
			pitch = pitch,
			speed = if type(props.Spin) == "number" then props.Spin else 40,
			yaw = yaw,
		}
		ensureSpinLoop()
	end
	if RelicAura.HasMotion(clone) then
		auraViews[vpf] = clone
		ensureFxLoop()
	end
	if rarity and not props.Silhouette then
		local glow = RelicAura.CardGlow(rarity)
		if glow then
			if props.Parent then
				addGlow(vpf, props.Parent, glow)
			else
				local conn
				conn = vpf:GetPropertyChangedSignal("Parent"):Connect(function()
					if vpf.Parent then
						conn:Disconnect()
						addGlow(vpf, vpf.Parent, glow)
					end
				end)
			end
		end
	end
	if props.Parent then
		vpf.Parent = props.Parent
	end
	return vpf
end

function RelicView.new(props): ViewportFrame
	local relic = props.Relic or { id = props.Id }
	local t = templateFor(relic.id, relic.mutations)
	if not t then
		local empty = Instance.new("ViewportFrame")
		empty.BackgroundTransparency = 1
		empty.Size = props.Size or UDim2.fromScale(1, 1)
		empty.Parent = props.Parent
		return empty
	end
	local def = Relics.ById[relic.id]
	return mount(t, props, def and def.Rarity)
end

local archetypeCache: { [string]: Model } = {}
function RelicView.Archetype(archetype: string, palette, props): ViewportFrame
	local key = archetype .. tostring(palette.main)
	local t = archetypeCache[key]
	if not t then
		t = RelicArt.BuildArchetype(archetype, palette, { targetSize = TARGET, forViewport = true, light = false })
		archetypeCache[key] = t
	end
	return mount(t, props)
end

return RelicView
