-- MegalodonAnimator: drives the Parts made by MegalodonBuilder with procedural poses.
-- Ports Idle / Swimming / Chasing / Attacking from the artifact viewer, so the
-- animation matches the web preview.
--
-- Usage (server):
--   local MegalodonBuilder = require(path.MegalodonBuilder)
--   local MegalodonAnimator = require(path.MegalodonAnimator)
--   local origin = CFrame.new(0, 30, 0)
--   local model = MegalodonBuilder.build(workspace, origin)
--   local anim = MegalodonAnimator.new(model, origin)
--   anim:SetState("Attacking")

local RunService = game:GetService("RunService")

local S = 4 -- studs per viewer unit (same scale the builder uses)
local TAU = math.pi * 2
local NSEG = 8
local SEG_NAMES = { "Body2", "Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Caudal" }
-- Offset of each chain segment from its parent's joint (viewer units, along -X)
local SEG_OFFSETS = { -1.6, -1.4, -1.0, -0.9, -0.8, -0.7, -0.6, -0.5 }
local TORSO_X = 3.3
local RED = Color3.fromRGB(163, 20, 28)
local BLACK = Color3.fromRGB(10, 10, 11)
local LERP_KEYS = { "x", "y", "pitch", "roll", "head", "jaw" }

local REST = { x = 0, y = 0, pitch = 0, roll = 0, head = 0, jaw = 0.06, yaw = { 0, 0, 0, 0, 0, 0, 0, 0 } }

local function eio(u)
	if u < 0.5 then
		return 2 * u * u
	end
	return 1 - ((-2 * u + 2) ^ 2) / 2
end

local function eoc(u)
	return 1 - (1 - u) ^ 3
end

local function wave(t, amp, om, k, gr)
	gr = gr or 1.4
	local yaw = {}
	for i = 0, NSEG - 1 do
		yaw[i + 1] = amp * (0.3 + 0.7 * ((i / (NSEG - 1)) ^ gr)) * math.sin(om * t - k * i)
	end
	return yaw
end

local STATES = {
	Idle = {
		T = 8, rate = 3, red = 0,
		f = function(t)
			local w = TAU / 8
			return {
				x = 0, y = 0.15 * math.sin(w * t), pitch = 0.03 * math.sin(w * t + 1), roll = 0,
				head = 0.02 * math.sin(2 * w * t + 2), jaw = 0.07 + 0.04 * math.sin(2 * w * t),
				yaw = wave(t, 0.07, 2 * w, 0.6),
			}
		end,
	},
	Swimming = {
		T = 2, rate = 4, red = 0,
		f = function(t)
			local w = TAU / 2
			return {
				x = 0, y = 0.05 * math.sin(2 * w * t), pitch = 0, roll = 0.03 * math.sin(w * t),
				head = -0.06 * math.sin(w * t + 0.6), jaw = 0.1,
				yaw = wave(t, 0.17, w, 0.75),
			}
		end,
	},
	Chasing = {
		T = 0.8, rate = 8, red = 1,
		f = function(t)
			local w = TAU / 0.8
			return {
				x = 0.06 * math.sin(2 * w * t), y = 0.04 * math.sin(2 * w * t), pitch = -0.16,
				roll = 0.06 * math.sin(w * t), head = -0.09 * math.sin(w * t + 0.5),
				jaw = 0.4 + 0.06 * math.sin(2 * w * t),
				yaw = wave(t, 0.27, w, 0.85, 1.2),
			}
		end,
	},
	Attacking = {
		T = 2.4, rate = 30, red = 0.8,
		f = function(t)
			local p = (t % 2.4) / 2.4
			local x, jaw, pitch, roll, hd, amp = 0, 0.06, 0, 0, 0, 0.06
			if p < 0.42 then
				local u = eio(p / 0.42)
				x = -0.7 * u; jaw = 0.06 + 0.84 * u; pitch = 0.1 * u; amp = 0.08
			elseif p < 0.56 then
				local u = eoc((p - 0.42) / 0.14)
				x = -0.7 + 2.6 * u; jaw = 0.9; pitch = 0.1 - 0.28 * u; amp = 0.3
			elseif p < 0.6 then
				local q = (p - 0.56) / 0.04
				x = 1.9; jaw = 0.9 * (1 - q * q); pitch = -0.18; amp = 0.22
			else
				local q = (p - 0.6) / 0.4
				local sh = math.exp(-5 * q) * math.sin(q * 30)
				x = 1.9 * (1 - eio(q)) - 0.35 * math.sin(math.min(q * 2.5, 1) * math.pi) * (1 - q)
				jaw = 0.06 * eio(q)
				pitch = -0.18 * (1 - eio(q)) + 0.08 * sh
				roll = 0.07 * sh; hd = 0.06 * sh; amp = 0.06 + 0.1 * (1 - q)
			end
			return { x = x, y = 0, pitch = pitch, roll = roll, head = hd, jaw = jaw, yaw = wave(t, amp, TAU / 2.4 * 5, 0.8, 1.2) }
		end,
	},
}

-- World transform of every joint for a given pose. Mirrors the viewer's rig hierarchy:
-- rig -> Torso -> Body2 -> Tail1..Tail6 -> Caudal, with Head on Torso and Jaw on Head.
local function computePivots(origin, p)
	local pv = {}
	local rig = origin * CFrame.new(S * p.x, S * p.y, 0) * CFrame.Angles(p.roll, 0, p.pitch)
	local cur = rig * CFrame.new(S * TORSO_X, 0, 0)
	pv.Torso = cur
	for i = 1, NSEG do
		cur = cur * CFrame.new(S * SEG_OFFSETS[i], 0, 0) * CFrame.Angles(0, p.yaw[i], 0)
		pv[SEG_NAMES[i]] = cur
	end
	pv.Head = pv.Torso * CFrame.Angles(0, p.head, 0)
	pv.Jaw = pv.Head * CFrame.Angles(0, 0, -p.jaw)
	return pv
end

-- Which joint moves a part, based on the group Model the builder put it in.
local function keyFor(groupName, pv)
	if groupName == "Eye_L" or groupName == "Eye_R" then
		return "Head"
	end
	if pv[groupName] then
		return groupName
	end
	return nil
end

local MegalodonAnimator = {}
MegalodonAnimator.__index = MegalodonAnimator

function MegalodonAnimator.new(model: Model, origin: CFrame)
	local self = setmetatable({}, MegalodonAnimator)
	self.origin = origin
	self.state = "Swimming"
	self.stateT0 = time()
	self.cur = { x = 0, y = 0, pitch = 0, roll = 0, head = 0, jaw = 0.06, yaw = { 0, 0, 0, 0, 0, 0, 0, 0 } }
	self.red = 0

	-- Record each part's offset from its joint at rest, so the animation can move it rigidly.
	local restPv = computePivots(origin, REST)
	self.parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Parent then
			local key = keyFor(d.Parent.Name, restPv)
			if key then
				table.insert(self.parts, {
					part = d,
					key = key,
					rel = restPv[key]:ToObjectSpace(d.CFrame),
					eye = d.Name == "eye_black",
				})
			end
		end
	end

	self.conn = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

function MegalodonAnimator:SetState(name: string)
	assert(STATES[name], "unknown Megalodon state: " .. tostring(name))
	self.state = name
	self.stateT0 = time()
end

function MegalodonAnimator:_step(dt: number)
	local st = STATES[self.state]
	local t = time() - self.stateT0
	local a = 1 - math.exp(-st.rate * dt)
	local target = st.f(t)
	local c = self.cur
	for _, k in LERP_KEYS do
		c[k] = c[k] + (target[k] - c[k]) * a
	end
	for i = 1, NSEG do
		c.yaw[i] = c.yaw[i] + (target.yaw[i] - c.yaw[i]) * a
	end
	self.red = self.red + (st.red - self.red) * (1 - math.exp(-6 * dt))

	local pv = computePivots(self.origin, c)
	local eyeColor = BLACK:Lerp(RED, self.red)
	for _, e in self.parts do
		e.part.CFrame = pv[e.key] * e.rel
		if e.eye then
			e.part.Color = eyeColor
		end
	end
end

function MegalodonAnimator:Destroy()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

return MegalodonAnimator
