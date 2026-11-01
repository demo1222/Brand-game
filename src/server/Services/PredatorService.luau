-- PredatorService (Master Plan §10): the Leviathan state machine and secondary hazards.
--   Patrol → Investigate (noise) → Hunt (sight) → Lunge (1s telegraphed wind-up) → Cooldown
-- Movement is server-simulated on anchored parts (network ownership stays on the server);
-- clients only receive positions via replication plus a lightweight PredatorHint for audio/UI.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Formulas)
local Build = require(script.Parent.Parent.Util.Build)

local L = Economy.Leviathan
local SURFACE = World.WaterSurfaceY
local TICK = 1 / 20

local PredatorService = {}
local services
local rng = Random.new()
local leviathans = {}
local hazards = {}
local noise: { [Player]: number } = {}
local hunted: { [Player]: boolean } = {}
local flareLimiter = RateLimiter.new(3, 0.5)
local creatureFolder: Folder

function PredatorService.Init(s)
	services = s
end

function PredatorService.AddNoise(player: Player, amount: number)
	local data = services.DataService.GetData(player)
	local mult = if data then Formulas.NoiseMultiplier(data) else 1
	noise[player] = math.min(100, (noise[player] or 0) + amount * mult)
end

function PredatorService.WasHunted(player: Player): boolean
	return hunted[player] == true
end

function PredatorService.ClearHunted(player: Player)
	hunted[player] = nil
end

------------------------------------------------------------------------------------------
-- Leviathan
------------------------------------------------------------------------------------------
local function randomDeepPoint(): Vector3
	local r = World.OceanRadius - 40
	local depth = rng:NextNumber(L.MinDepth + 30, World.SeabedDepth - 40)
	return Vector3.new(rng:NextNumber(-r, r), SURFACE - depth, rng:NextNumber(-r, r))
end

local function buildLeviathanModel(): Model
	local model = Instance.new("Model")
	model.Name = "Leviathan"
	local head = Build.Part({
		Name = "Head",
		Size = Vector3.new(10, 8, 16),
		Color = Color3.fromRGB(25, 30, 40),
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	model.PrimaryPart = head
	for _, x in { -1, 1 } do
		local eye = Build.Part({
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			Color = Color3.fromRGB(255, 40, 30),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		eye.CFrame = head.CFrame * CFrame.new(x * 3.5, 2, -7)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, eye
		w.Parent = eye
	end
	local light = Instance.new("SpotLight")
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 40
	light.Angle = 60
	light.Brightness = 3
	light.Face = Enum.NormalId.Front
	light.Parent = head
	-- Body segments trail behind the head (positioned every tick)
	local segments = {}
	for i = 1, 7 do
		local seg = Build.Part({
			Name = "Seg" .. i,
			Size = Vector3.new(9 - i * 0.8, 7 - i * 0.6, 12),
			Color = Color3.fromRGB(30, 35, 50),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
		table.insert(segments, seg)
	end
	model.Parent = creatureFolder
	return model, segments
end

local function spawnLeviathan()
	local model, segments = buildLeviathanModel()
	local pos = randomDeepPoint()
	local lev = {
		model = model,
		segments = segments,
		trail = {},
		pos = pos,
		look = Vector3.new(0, 0, -1),
		state = "Patrol",
		waypoint = randomDeepPoint(),
		target = nil,
		investigate = nil,
		timer = 0,
		lungeDir = nil,
		distractedUntil = 0,
		flarePos = nil,
	}
	for _ = 1, #segments * 4 do
		table.insert(lev.trail, pos)
	end
	table.insert(leviathans, lev)
	return lev
end

local function despawnLeviathan()
	local lev = table.remove(leviathans)
	if lev then
		lev.model:Destroy()
	end
end

-- Obstacle avoidance (§10 follow-up): probe ahead against the cliffs, spires and ledges and
-- slide along whatever is in the way instead of swimming through it.
local avoidParams: RaycastParams? = nil
local function avoid(lev, dir: Vector3, speed: number): Vector3
	if not avoidParams then
		local ocean = services.WorldService.Root():FindFirstChild("Ocean")
		if not ocean then
			return dir
		end
		avoidParams = RaycastParams.new()
		avoidParams.FilterType = Enum.RaycastFilterType.Include
		avoidParams.FilterDescendantsInstances = { ocean }
	end
	local probe = math.max(30, speed * 1.5)
	local hit = Workspace:Raycast(lev.pos, dir * probe, avoidParams)
	if not hit then
		return dir
	end
	local n = hit.Normal
	local slide = dir - n * dir:Dot(n)
	local out = slide + n * (1 - hit.Distance / probe) * 1.5
	return if out.Magnitude > 1e-3 then out.Unit else n
end

local function moveToward(lev, goal: Vector3, speed: number, dt: number)
	local delta = goal - lev.pos
	local dist = delta.Magnitude
	if dist < 0.1 then
		return dist
	end
	local dir = avoid(lev, delta / dist, speed)
	-- smooth turning
	local turned = lev.look:Lerp(dir, math.clamp(dt * 3, 0, 1))
	lev.look = if turned.Magnitude > 1e-3 then turned.Unit else dir
	local step = math.min(dist, speed * dt)
	lev.pos += lev.look * step
	-- keep inside the deep zone
	local minY = SURFACE - World.SeabedDepth + 10
	local maxY = SURFACE - L.MinDepth + 60
	lev.pos = Vector3.new(
		math.clamp(lev.pos.X, -World.OceanRadius + 70, World.OceanRadius - 70),
		math.clamp(lev.pos.Y, minY, maxY),
		math.clamp(lev.pos.Z, -World.OceanRadius + 70, World.OceanRadius - 70)
	)
	return dist
end

local function render(lev)
	local head = lev.model.PrimaryPart
	lev.model:PivotTo(CFrame.lookAt(lev.pos, lev.pos + lev.look))
	table.insert(lev.trail, 1, lev.pos)
	table.remove(lev.trail)
	for i, seg in lev.segments do
		local a = lev.trail[math.min(#lev.trail, i * 4)]
		local b = lev.trail[math.min(#lev.trail, i * 4 - 2)] or a
		if (b - a).Magnitude > 0.01 then
			seg.CFrame = CFrame.lookAt(a, b)
		else
			seg.Position = a
		end
	end
	return head
end

local function playerInfo(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return nil
	end
	if (char:GetAttribute("SpawnShield") or 0) > os.clock() then
		return nil
	end
	local depth = SURFACE - hrp.Position.Y
	if depth < L.MinDepth - 20 then
		return nil
	end
	return hrp, hum
end

local function canSee(lev, pos: Vector3): boolean
	local delta = pos - lev.pos
	local dist = delta.Magnitude
	if dist > L.SightRange then
		return false
	end
	local angle = math.deg(math.acos(math.clamp(lev.look:Dot(delta.Unit), -1, 1)))
	return angle <= L.SightConeDeg or dist < 15
end

local function tickLeviathan(lev, dt: number)
	local now = os.clock()
	-- Flare distraction (§10.1 co-op)
	if lev.distractedUntil > now and lev.flarePos then
		lev.state = "Distracted"
		moveToward(lev, lev.flarePos, L.HuntSpeed, dt)
		render(lev)
		return
	elseif lev.state == "Distracted" then
		lev.state = "Patrol"
		lev.target = nil
	end

	if lev.state == "Patrol" or lev.state == "Investigate" then
		-- Look for prey
		local best, bestScore = nil, 0
		for _, player in Players:GetPlayers() do
			local hrp = playerInfo(player)
			if hrp then
				local dist = (hrp.Position - lev.pos).Magnitude
				if canSee(lev, hrp.Position) then
					local score = 200 - dist
					if score > bestScore then
						best, bestScore = player, score
					end
				elseif dist < L.HearRange and (noise[player] or 0) > 30 then
					lev.state = "Investigate"
					lev.investigate = hrp.Position
				end
			end
		end
		if best then
			lev.state = "Hunt"
			lev.target = best
			hunted[best] = true
		elseif lev.state == "Investigate" and lev.investigate then
			if moveToward(lev, lev.investigate, (L.PatrolSpeed + L.HuntSpeed) / 2, dt) < 8 then
				lev.state = "Patrol"
				lev.investigate = nil
			end
		else
			if moveToward(lev, lev.waypoint, L.PatrolSpeed, dt) < 10 then
				lev.waypoint = randomDeepPoint()
			end
		end
	elseif lev.state == "Hunt" then
		local target = lev.target
		local hrp = target and target.Parent and playerInfo(target)
		if not hrp then
			lev.state = "Patrol"
			lev.target = nil
		else
			local dist = moveToward(lev, hrp.Position, L.HuntSpeed, dt)
			if dist > L.SightRange * 2.5 then
				lev.state = "Patrol"
				lev.target = nil
			elseif dist < 28 then
				lev.state = "WindUp"
				lev.timer = L.WindUp
				Net.PredatorHint:FireClient(target, { State = "WindUp", Position = lev.pos })
			end
		end
	elseif lev.state == "WindUp" then
		lev.timer -= dt
		local target = lev.target
		local hrp = target and target.Parent and playerInfo(target)
		if hrp then
			-- face the target while rearing back
			local turned = lev.look:Lerp((hrp.Position - lev.pos).Unit, math.clamp(dt * 6, 0, 1))
			if turned.Magnitude > 1e-3 then
				lev.look = turned.Unit
			end
		end
		if lev.timer <= 0 then
			if hrp then
				lev.lungeDir = (hrp.Position - lev.pos).Unit
				lev.state = "Lunge"
				lev.timer = 0.6
			else
				lev.state = "Patrol"
			end
		end
	elseif lev.state == "Lunge" then
		lev.timer -= dt
		lev.pos += lev.lungeDir * L.LungeSpeed * dt
		lev.look = lev.lungeDir
		-- hit check against everyone in the path
		for _, player in Players:GetPlayers() do
			local hrp, hum = playerInfo(player)
			if hrp and (hrp.Position - lev.pos).Magnitude < L.HitRadius then
				services.DiveService.SetCause(player, "Leviathan")
				hum:TakeDamage(hum.MaxHealth * L.HitDamage)
				Net.Knockback:FireClient(player, lev.lungeDir * 60)
				lev.timer = 0
			end
		end
		if lev.timer <= 0 then
			lev.state = "Cooldown"
			lev.timer = L.CooldownSeconds
		end
	elseif lev.state == "Cooldown" then
		lev.timer -= dt
		moveToward(lev, lev.pos + lev.look * 30, L.PatrolSpeed, dt)
		if lev.timer <= 0 then
			lev.state = if lev.target and lev.target.Parent then "Hunt" else "Patrol"
		end
	end
	render(lev)
end

local function desiredLeviathans(): number
	local deep = 0
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and SURFACE - hrp.Position.Y >= L.MinDepth then
			deep += 1
		end
	end
	local base = 1 + math.floor(deep / L.PlayersPerExtra)
	return math.floor(base * services.EventService.LeviathanMult())
end

local function useFlare(player: Player)
	if not flareLimiter:Check(player) then
		return
	end
	local data = services.DataService.GetData(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not hrp then
		return
	end
	if data.Flares <= 0 then
		Net.Offer:FireClient(player, "Flares5")
		return
	end
	data.Flares -= 1
	services.DataService.Replicate(player, "Flares")
	local flarePos = hrp.Position + hrp.CFrame.LookVector * 25
	local flare = Build.Part({
		Name = "Flare",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		CFrame = CFrame.new(flarePos),
		Color = Color3.fromRGB(255, 80, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = creatureFolder,
	})
	Build.Instance("PointLight", { Range = 60, Brightness = 5, Color = flare.Color, Parent = flare })
	task.delay(L.FlareSeconds, function()
		flare:Destroy()
	end)
	for _, lev in leviathans do
		if (lev.pos - flarePos).Magnitude < 160 then
			lev.distractedUntil = os.clock() + L.FlareSeconds
			lev.flarePos = flarePos
		end
	end
end

------------------------------------------------------------------------------------------
-- Secondary hazards (§10.2)
------------------------------------------------------------------------------------------
local function spawnHazards()
	-- Electric eels: zone 2+, dart between two points
	for i = 1, 14 do
		local zoneIndex = if i <= 8 then 2 else 3
		local a = services.WorldService.RandomPointInZone(zoneIndex, rng, true)
		local b = a + Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(-15, 15), rng:NextNumber(-60, 60))
		local part = Build.Part({
			Name = "Eel",
			Size = Vector3.new(1.5, 1.5, 10),
			CFrame = CFrame.new(a),
			Color = Color3.fromRGB(230, 230, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = creatureFolder,
		})
		table.insert(hazards, { kind = "Eel", part = part, a = a, b = b, t = rng:NextNumber(0, 1), speed = 0.25 })
	end
	-- Jellyfish swarms: zone 3+
	for i = 1, 18 do
		local zoneIndex = 3 + (i % 3)
		local pos = services.WorldService.RandomPointInZone(zoneIndex, rng, true)
		local part = Build.Part({
			Name = "Jellyfish",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 6,
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(255, 120, 220),
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
			Parent = creatureFolder,
		})
		table.insert(hazards, { kind = "Jelly", part = part, base = pos, t = rng:NextNumber(0, 10) })
	end
	-- Anglerfish (§10, zone 4): a glowing lure in the dark; lunges at divers who come close
	for _ = 1, 8 do
		local pos = services.WorldService.RandomPointInZone(4, rng, true)
		local body = Build.Part({
			Name = "Anglerfish",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 6,
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(28, 26, 36),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			Parent = creatureFolder,
		})
		local lure = Build.Part({
			Name = "Lure",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			CFrame = CFrame.new(pos + Vector3.new(0, 4, -3)),
			Color = Color3.fromRGB(255, 240, 140),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			Parent = body,
		})
		Build.Instance("PointLight", { Range = 22, Brightness = 2.5, Color = lure.Color, Parent = lure })
		for _, x in { -1, 1 } do
			Build.Part({
				Name = "Tooth",
				Size = Vector3.new(0.3, 1, 0.3),
				CFrame = CFrame.new(pos + Vector3.new(x * 1.2, -0.8, -2.8)),
				Color = Color3.fromRGB(235, 230, 210),
				CanCollide = false,
				CanQuery = false,
				Parent = body,
			})
		end
		table.insert(hazards, { kind = "Angler", part = body, lure = lure, home = pos, pos = pos, t = rng:NextNumber(0, 10), lunge = 0, target = nil })
	end
	-- Pressure-crack geysers (§10, zone 5): telegraph, then erupt and blast divers upward
	for _ = 1, 10 do
		local pos = services.WorldService.RandomPointInZone(5, rng)
		local crack = Build.Part({
			Name = "Geyser",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 6, 6),
			CFrame = CFrame.new(pos - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(70, 20, 12),
			Material = Enum.Material.CrackedLava,
			CanCollide = false,
			CanQuery = false,
			Parent = creatureFolder,
		})
		local column = Build.Part({
			Name = "Column",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(40, 6, 6),
			CFrame = CFrame.new(pos + Vector3.new(0, 19, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 160, 120),
			Material = Enum.Material.Neon,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = crack,
		})
		table.insert(hazards, { kind = "Geyser", part = crack, column = column, base = pos, t = rng:NextNumber(0, 10), period = rng:NextNumber(8, 12) })
	end
	-- Whirlpools (§10, zone 3): a spinning current that drags divers in
	for _ = 1, 5 do
		local pos = services.WorldService.RandomPointInZone(3, rng, true)
		local ring = Build.Part({
			Name = "Whirlpool",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 50, 50),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.ForceField,
			Transparency = 0.2,
			CanCollide = false,
			CanQuery = false,
			Parent = creatureFolder,
		})
		table.insert(hazards, { kind = "Whirl", part = ring, base = pos, t = 0, radius = 25 })
	end
end

local hazardCooldown: { [string]: number } = {}

local function tickHazards(dt: number)
	local positions = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and hrp.Position.Y < SURFACE - 100 then
			table.insert(positions, { player = player, hrp = hrp, hum = hum })
		end
	end
	for _, h in hazards do
		if h.kind == "Eel" then
			h.t += dt * h.speed
			local alpha = (math.sin(h.t * math.pi) + 1) / 2
			local pos = h.a:Lerp(h.b, alpha)
			local dir = (h.b - h.a).Unit * (if math.cos(h.t * math.pi) >= 0 then 1 else -1)
			h.part.CFrame = CFrame.lookAt(pos, pos + dir)
		elseif h.kind == "Jelly" then
			h.t += dt
			h.part.Position = h.base + Vector3.new(math.sin(h.t * 0.5) * 4, math.sin(h.t) * 3, math.cos(h.t * 0.5) * 4)
		elseif h.kind == "Angler" then
			h.t += dt
			local goal = h.home + Vector3.new(math.sin(h.t * 0.2) * 10, math.sin(h.t * 0.5) * 2, math.cos(h.t * 0.2) * 10)
			if h.lunge > 0 and h.target and h.target.Parent then
				h.lunge -= dt
				goal = h.target.Position
				h.pos = h.pos + (goal - h.pos).Unit * math.min((goal - h.pos).Magnitude, 34 * dt)
			else
				h.lunge = 0
				h.pos = h.pos:Lerp(goal, math.clamp(dt * 0.8, 0, 1))
			end
			local look = if (goal - h.pos).Magnitude > 0.5 then (goal - h.pos).Unit else Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(h.pos, h.pos + look)
			local delta = cf * h.part.CFrame:Inverse()
			for _, d in h.part:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = delta * d.CFrame
				end
			end
			h.part.CFrame = cf
			-- the lure flickers when hunting
			h.lure.Transparency = if h.lunge > 0 and (h.t * 10) % 2 < 1 then 0.6 else 0
		elseif h.kind == "Geyser" then
			h.t += dt
			local phase = h.t % h.period
			local warning = phase > h.period - 1.5
			local erupting = phase < 2
			h.part.Color = if warning then Color3.fromRGB(255, 90, 30) else Color3.fromRGB(70, 20, 12)
			h.part.Material = if warning then Enum.Material.Neon else Enum.Material.CrackedLava
			h.column.Transparency = if erupting then 0.35 else 1
			h.erupting = erupting
		elseif h.kind == "Whirl" then
			h.t += dt
			h.part.CFrame = CFrame.new(h.base) * CFrame.Angles(0, h.t * 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		for _, p in positions do
			local dist = (p.hrp.Position - h.part.Position).Magnitude
			if h.kind == "Eel" and dist < 6 then
				local key = "E" .. p.player.UserId
				if (hazardCooldown[key] or 0) < os.clock() then
					hazardCooldown[key] = os.clock() + 2
					local s = services.DiveService.GetState(p.player)
					if s then
						services.DiveService.AddOxygen(p.player, -s.maxOxygen * 0.1)
					end
					services.DiveService.SetCause(p.player, "Eel")
					p.hum:TakeDamage(10)
					Net.Knockback:FireClient(p.player, (p.hrp.Position - h.part.Position).Unit * 50)
					Net.Notify:FireClient(p.player, "Zapped by an eel! -10% oxygen", "error")
				end
			elseif h.kind == "Jelly" and dist < 6 then
				services.DiveService.SetCause(p.player, "Jellyfish")
				p.hum:TakeDamage(p.hum.MaxHealth * 0.05 * dt)
				p.player.Character:SetAttribute("JellySlowUntil", os.clock() + 1.5)
			elseif h.kind == "Angler" then
				if h.lunge <= 0 and dist < 25 and dist > 6 then
					h.lunge, h.target = 2, p.hrp
				elseif dist < 5 then
					local key = "A" .. p.player.UserId
					if (hazardCooldown[key] or 0) < os.clock() then
						hazardCooldown[key] = os.clock() + 3
						services.DiveService.SetCause(p.player, "Anglerfish")
						p.hum:TakeDamage(p.hum.MaxHealth * 0.25)
						Net.Knockback:FireClient(p.player, (p.hrp.Position - h.pos).Unit * 60)
						Net.Notify:FireClient(p.player, "An anglerfish bit you! Don't follow strange lights.", "error")
						h.lunge = 0
					end
				end
			elseif h.kind == "Geyser" and h.erupting then
				local flat = Vector3.new(p.hrp.Position.X - h.base.X, 0, p.hrp.Position.Z - h.base.Z).Magnitude
				local above = p.hrp.Position.Y - h.base.Y
				if flat < 4 and above > -2 and above < 40 then
					local key = "G" .. p.player.UserId
					if (hazardCooldown[key] or 0) < os.clock() then
						hazardCooldown[key] = os.clock() + 1.5
						services.DiveService.SetCause(p.player, "Pressure")
						p.hum:TakeDamage(p.hum.MaxHealth * 0.15)
						Net.Knockback:FireClient(p.player, Vector3.new(0, 90, 0))
						Net.Notify:FireClient(p.player, "A pressure geyser erupted under you!", "error")
					end
				end
			elseif h.kind == "Whirl" and dist < h.radius then
				-- pull inward and around, every half second
				local key = "W" .. p.player.UserId
				if (hazardCooldown[key] or 0) < os.clock() then
					hazardCooldown[key] = os.clock() + 0.5
					local toCenter = h.base - p.hrp.Position
					local flat = Vector3.new(toCenter.X, 0, toCenter.Z)
					if flat.Magnitude > 1 then
						local tangent = Vector3.new(-flat.Z, 0, flat.X).Unit
						Net.Knockback:FireClient(p.player, flat.Unit * 14 + tangent * 18)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------------------
function PredatorService.Start()
	creatureFolder = services.WorldService.Root():FindFirstChild("Creatures")
	spawnLeviathan()
	spawnHazards()

	Net.UseFlare.OnServerEvent:Connect(useFlare)

	task.spawn(function()
		local acc = 0
		local hintAcc = 0
		while true do
			local dt = task.wait(TICK)
			acc += dt
			hintAcc += dt
			for _, lev in leviathans do
				local ok, err = pcall(tickLeviathan, lev, dt)
				if not ok then
					warn("[Predator] " .. tostring(err))
				end
			end
			tickHazards(dt)
			-- noise decay + cursed relics keep you loud (§7.4)
			for _, player in Players:GetPlayers() do
				local n = (noise[player] or 0) - 15 * dt
				local data = services.DataService.GetData(player)
				if data then
					for _, relic in data.Bag do
						for _, m in relic.mutations do
							if Mutations.ById[m] and Mutations.ById[m].Noisy then
								n += 10 * dt
							end
						end
					end
				end
				noise[player] = math.clamp(n, 0, 100)
			end
			if acc >= 5 then
				acc = 0
				local want = desiredLeviathans()
				while #leviathans < want do
					spawnLeviathan()
				end
				while #leviathans > want do
					despawnLeviathan()
				end
			end
			if hintAcc >= 0.25 then
				hintAcc = 0
				for _, player in Players:GetPlayers() do
					local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if hrp and SURFACE - hrp.Position.Y > L.MinDepth - 150 then
						local nearest, state = math.huge, "None"
						for _, lev in leviathans do
							local d = (lev.pos - hrp.Position).Magnitude
							if d < nearest then
								nearest = d
								state = if lev.target == player then lev.state else "Patrol"
							end
						end
						Net.PredatorHint:FireClient(player, { Distance = nearest, State = state, Noise = noise[player] or 0 })
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		noise[p] = nil
		hunted[p] = nil
		flareLimiter:Remove(p)
		for _, lev in leviathans do
			if lev.target == p then
				lev.target = nil
				lev.state = "Patrol"
			end
		end
	end)
end

return PredatorService
