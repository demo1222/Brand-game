-- GuardianController: draws the zone guardians (GuardianService) on this client. The server
-- moves one invisible "Guardian" root part per monster; here each one gets a body from
-- shared/MonsterArt that follows the root smoothly, wags its tail (faster when chasing), opens
-- its jaw on the wind-up and lunge, and (serpents) drags its segments along its trail.
-- Only monsters within DRAW_RANGE of the camera are drawn and animated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monsters = require(Shared.Config.Monsters)
local MonsterArt = require(Shared.MonsterArt)

local GuardianController = {}

local DRAW_RANGE = 320
local folder: Folder
local live: { [BasePart]: any } = {}
local movers: { BasePart } = {}
local targets: { CFrame } = {}

local function attach(root: Instance)
	if not root:IsA("BasePart") or live[root] then
		return
	end
	local id = root:GetAttribute("MonsterId")
	local def = id and Monsters.ById[id]
	if not def then
		return
	end
	local built = MonsterArt.Build(def)
	built.model.Parent = nil -- parented when in range
	local trail = table.create(built.segments * 3 + 4, root.CFrame)
	live[root] = {
		def = def,
		built = built,
		display = root.CFrame,
		trail = trail,
		trailClock = 0,
		phase = math.random() * 10,
		jaw = 0,
		shown = false,
	}
	root.Destroying:Connect(function()
		local e = live[root]
		if e then
			e.built.model:Destroy()
			live[root] = nil
		end
	end)
end

local function step(dt: number)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	table.clear(movers)
	table.clear(targets)
	local t = os.clock()
	for root, e in live do
		local near = (root.Position - camPos).Magnitude < DRAW_RANGE
		if near ~= e.shown then
			e.shown = near
			e.built.model.Parent = if near then folder else nil
			e.display = root.CFrame
		end
		if near then
			local def = e.def
			local state = root:GetAttribute("State")
			local aggressive = state == "Chase" or state == "Lunge" or state == "WindUp" or state == "Scared"
			-- smooth toward the server's root (it updates at 15 Hz)
			e.display = e.display:Lerp(root.CFrame, math.clamp(dt * 9, 0, 1))
			local wagSpeed = if aggressive then 9 else 4
			e.phase += dt * wagSpeed
			local wag = math.sin(e.phase) * (if aggressive then 0.4 else 0.25)
			local bodyRoll = CFrame.Angles(0, math.sin(e.phase) * 0.06, 0)
			local wantJaw = if state == "WindUp" then 1 elseif state == "Lunge" then 0.7 else 0.08 + math.sin(t * 0.8) * 0.05
			e.jaw += (wantJaw - e.jaw) * math.clamp(dt * 10, 0, 1)
			local base = e.display * bodyRoll
			-- serpent trail: record the head position every so often
			if e.built.segments > 0 then
				e.trailClock += dt
				local spacing = def.Length / (e.built.segments * 1.1)
				local last = e.trail[1]
				if (e.display.Position - last.Position).Magnitude >= spacing * 0.34 then
					table.insert(e.trail, 1, e.display)
					table.remove(e.trail)
				end
			end
			local L = def.Length
			for _, piece in e.built.pieces do
				local part, offset, role, index = piece[1], piece[2], piece[3], piece[4]
				local cf
				if role == "tail" then
					-- pivot the tail at the back of the body
					local pivot = CFrame.new(0, 0, 0.3 * L)
					cf = base * pivot * CFrame.Angles(0, wag, 0) * pivot:Inverse() * offset
				elseif role == "jaw" then
					local hinge = CFrame.new(0, -0.05 * L, -0.25 * L)
					cf = base * hinge * CFrame.Angles(math.rad(-28) * e.jaw, 0, 0) * hinge:Inverse() * offset
				elseif role == "seg" then
					local i = math.min(#e.trail, (index or 1) * 3 + 1)
					local here = e.trail[i]
					local ahead = e.trail[math.max(1, i - 2)]
					local look = if (ahead.Position - here.Position).Magnitude > 0.01 then CFrame.lookAt(here.Position, ahead.Position) else here
					local sway = math.sin(e.phase - (index or 1) * 0.6) * L * 0.02
					cf = look * CFrame.new(sway, 0, 0) * offset
				else
					cf = base * offset
				end
				movers[#movers + 1] = part
				targets[#movers] = cf
			end
		end
	end
	if #movers > 0 then
		Workspace:BulkMoveTo(movers, targets, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function GuardianController.Start()
	folder = Instance.new("Folder")
	folder.Name = "LocalGuardians"
	folder.Parent = Workspace
	local root = Workspace:WaitForChild("AbyssWorld")
	local creatures = root:WaitForChild("Creatures")
	for _, c in creatures:GetChildren() do
		attach(c)
	end
	creatures.ChildAdded:Connect(function(c)
		-- attributes arrive with the part, but give replication a frame
		task.defer(attach, c)
	end)
	RunService.RenderStepped:Connect(step)
end

return GuardianController
