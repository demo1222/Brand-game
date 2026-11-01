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

local RelicView = {}

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

local function mount(model: Model, props)
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
	return mount(t, props)
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
