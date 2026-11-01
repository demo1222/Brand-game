-- PredatorService (Master Plan §10): the Leviathan state machine and secondary hazards.
--   Patrol → Investigate (noise) → Hunt (sight) → Lunge (1s telegraphed wind-up) → Cooldown
-- Movement is server-simulated on anchored parts (network ownership stays on the server);
-- clients only receive positions via replication plus a lightweight PredatorHint for audio/UI.

local Players = game:GetService("Players")
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

local function moveToward(lev, goal: Vector3, speed: number, dt: number)
	local delta = goal - lev.pos
	local dist = delta.Magnitude
	if dist < 0.1 then
		return dist
	end
	local dir = delta / dist
	-- smooth turning
	local turned = lev.look:Lerp(dir, math.clamp(dt * 3, 0, 1))
	lev.look = if turned.Magnitude > 1e-3 then turned.Unit else dir
	local step = math.min(dist, speed * dt)
	lev.pos += lev.look * step
	-- keep inside the deep zone
	local minY = SURFACE - World.SeabedDepth + 10
	local maxY = SURFACE - L.MinDepth + 60
	lev.pos = Vector3.new(
		math.clamp(lev.pos.X, -World.OceanRadius + 20, World.OceanRadius - 20),
		math.clamp(lev.pos.Y, minY, maxY),
		math.clamp(lev.pos.Z, -World.OceanRadius + 20, World.OceanRadius - 20)
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
		local a = services.WorldService.RandomPointInZone(zoneIndex, rng)
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
		local pos = services.WorldService.RandomPointInZone(zoneIndex, rng)
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
		else
			h.t += dt
			h.part.Position = h.base + Vector3.new(math.sin(h.t * 0.5) * 4, math.sin(h.t) * 3, math.cos(h.t * 0.5) * 4)
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
