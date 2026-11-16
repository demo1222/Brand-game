-- GuardianService: one unique monster per zone (Config/Monsters), each guarding a lair of
-- relic nodes that roll with extra luck. The server simulates only an invisible anchored
-- "Guardian" root part per monster (position + facing, MonsterId and State attributes); every
-- client builds the actual creature on top of it (GuardianController + shared/MonsterArt), so
-- the many moving body parts never replicate.
--
-- States: Idle (no diver near the lair: frozen, costs nothing) -> Patrol (circles the lair)
-- -> Chase (a diver came within Sight; never further than Leash from the lair) -> WindUp
-- (telegraph, faces the diver) -> Lunge (fast dash; a hit bites) -> Cooldown (backs off)
-- -> Return (diver escaped the leash) / Scared (a flare: flees for FlareSeconds).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Monsters = require(Shared.Config.Monsters)
local World = require(Shared.Config.World)
local Build = require(script.Parent.Parent.Util.Build)

local GuardianService = {}
local services
local guardians = {}
local rng = Random.new(4242)
local TICK = 1 / 15
local SURFACE = World.WaterSurfaceY

function GuardianService.Init(s)
	services = s
end

local function diverInfo(player: Player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return nil
	end
	if (char:GetAttribute("SpawnShield") or 0) > os.clock() then
		return nil
	end
	if SURFACE - hrp.Position.Y < 2 then
		return nil -- out of the water
	end
	return hrp, hum
end

-- obstacle probe against the sea floor, cliffs and spires (same idea as the Leviathan)
local avoidParams: RaycastParams? = nil
local function avoid(pos: Vector3, dir: Vector3, probe: number): Vector3
	if not avoidParams then
		local ocean = services.WorldService.Root():FindFirstChild("Ocean")
		if not ocean then
			return dir
		end
		avoidParams = RaycastParams.new()
		avoidParams.FilterType = Enum.RaycastFilterType.Include
		avoidParams.FilterDescendantsInstances = { ocean }
	end
	local hit = Workspace:Raycast(pos, dir * probe, avoidParams)
	if not hit then
		return dir
	end
	local n = hit.Normal
	local slide = dir - n * dir:Dot(n) + n * (1 - hit.Distance / probe) * 1.5
	return if slide.Magnitude > 1e-3 then slide.Unit else n
end

local function steer(g, goal: Vector3, speed: number, dt: number, turnRate: number?)
	local delta = goal - g.pos
	local dist = delta.Magnitude
	if dist < 0.2 then
		return dist
	end
	local dir = avoid(g.pos, delta / dist, math.max(g.def.Length * 1.5, speed))
	local turned = g.look:Lerp(dir, math.clamp(dt * (turnRate or 2.5), 0, 1))
	g.look = if turned.Magnitude > 1e-3 then turned.Unit else dir
	g.pos += g.look * math.min(dist, speed * dt)
	-- stay in the zone's depth band and below the surface
	local zoneTop = SURFACE - 4
	g.pos = Vector3.new(g.pos.X, math.min(g.pos.Y, zoneTop), g.pos.Z)
	return dist
end

local function setState(g, state: string)
	if g.state ~= state then
		g.state = state
		g.root:SetAttribute("State", state)
	end
end

local function spawnGuardian(def, index: number)
	local lairPos = services.WorldService.RandomPointInZone(def.Zone, rng)
	local lair = { pos = lairPos, radius = 8 + def.Length * 0.4, luck = def.Luck }
	services.LootService.SpawnGuarded(def.Zone, lair, def.Nodes)
	local home = lairPos + Vector3.new(0, def.Length * 0.5 + 4, 0)
	local root = Build.Part({
		Name = "Guardian",
		Size = Vector3.new(def.Length * 0.3, def.Length * 0.3, def.Length),
		CFrame = CFrame.new(home),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = services.WorldService.Root():FindFirstChild("Creatures"),
	})
	root.Name = `{def.Id}_{index}`
	root:SetAttribute("MonsterId", def.Id)
	root:SetAttribute("State", "Idle")
	local g = {
		def = def,
		root = root,
		lair = lair,
		home = home,
		pos = home,
		look = Vector3.new(1, 0, 0),
		orbit = rng:NextNumber(0, math.pi * 2),
		state = "Idle",
		timer = 0,
		target = nil,
	}
	table.insert(guardians, g)
	return g
end

local function nearestDiver(g, range: number)
	local best, bestDist, bestHrp = nil, range, nil
	for _, player in Players:GetPlayers() do
		local hrp = diverInfo(player)
		if hrp then
			local d = (hrp.Position - g.pos).Magnitude
			if d < bestDist and (hrp.Position - g.lair.pos).Magnitude < g.def.Leash then
				best, bestDist, bestHrp = player, d, hrp
			end
		end
	end
	return best, bestHrp
end

local function anyoneNear(g): boolean
	for _, player in Players:GetPlayers() do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and (hrp.Position - g.lair.pos).Magnitude < Monsters.WakeRange then
			return true
		end
	end
	return false
end

local function tick(g, dt: number)
	local def = g.def
	local now = os.clock()
	if g.state == "Idle" then
		if anyoneNear(g) then
			setState(g, "Patrol")
		end
		return
	end
	if g.state == "Scared" then
		if now >= g.timer then
			setState(g, "Return")
		else
			steer(g, g.pos + g.flee * 40, def.Chase, dt, 4)
		end
	elseif g.state == "Patrol" then
		if not anyoneNear(g) then
			setState(g, "Idle")
			return
		end
		g.orbit += dt * def.Patrol / (g.lair.radius + 10)
		local r = g.lair.radius + 6
		local goal = g.home + Vector3.new(math.cos(g.orbit) * r, math.sin(g.orbit * 0.7) * 3, math.sin(g.orbit) * r)
		steer(g, goal, def.Patrol, dt)
		local player = nearestDiver(g, def.Sight)
		if player then
			g.target = player
			setState(g, "Chase")
		end
	elseif g.state == "Chase" then
		local hrp = g.target and g.target.Parent and diverInfo(g.target)
		if not hrp or (hrp.Position - g.lair.pos).Magnitude > def.Leash then
			g.target = nil
			setState(g, "Return")
		else
			local dist = steer(g, hrp.Position, def.Chase, dt, 3.5)
			if dist < def.Length * 0.8 + 10 then
				g.timer = now + def.WindUp
				setState(g, "WindUp")
				Net.PredatorHint:FireClient(g.target, { State = "WindUp", Position = g.pos, Guardian = def.Name })
			end
		end
	elseif g.state == "WindUp" then
		local hrp = g.target and g.target.Parent and diverInfo(g.target)
		if hrp then
			local to = (hrp.Position - g.pos)
			if to.Magnitude > 0.1 then
				local turned = g.look:Lerp(to.Unit, math.clamp(dt * 7, 0, 1))
				g.look = if turned.Magnitude > 1e-3 then turned.Unit else g.look
			end
			g.pos -= g.look * def.Patrol * 0.3 * dt -- rears back a little
		end
		if now >= g.timer then
			if hrp then
				g.lunge = (hrp.Position - g.pos).Unit
				g.timer = now + 0.45
				g.bit = false
				setState(g, "Lunge")
			else
				setState(g, "Return")
			end
		end
	elseif g.state == "Lunge" then
		g.look = g.lunge
		g.pos += g.lunge * def.Lunge * dt
		if not g.bit then
			for _, player in Players:GetPlayers() do
				local hrp, hum = diverInfo(player)
				if hrp and (hrp.Position - (g.pos + g.look * def.Length * 0.45)).Magnitude < 5 + def.Length * 0.25 then
					g.bit = true
					services.DiveService.SetCause(player, "Guardian:" .. def.Name)
					hum:TakeDamage(hum.MaxHealth * def.Damage)
					Net.Knockback:FireClient(player, g.lunge * 45)
					Net.WorldFX:FireClient(player, "Bite", hrp.Position)
					Net.Notify:FireClient(player, `The {def.Name} bit you!`, "error")
					break
				end
			end
		end
		if now >= g.timer then
			g.timer = now + def.Cooldown
			setState(g, "Cooldown")
		end
	elseif g.state == "Cooldown" then
		steer(g, g.pos - g.look * 20 + Vector3.new(0, 4, 0), def.Patrol, dt)
		if now >= g.timer then
			setState(g, if g.target and g.target.Parent and diverInfo(g.target) then "Chase" else "Return")
		end
	elseif g.state == "Return" then
		if steer(g, g.home, def.Chase * 0.7, dt) < 6 then
			setState(g, "Patrol")
		else
			local player = nearestDiver(g, def.Sight * 0.6)
			if player then
				g.target = player
				setState(g, "Chase")
			end
		end
	end
	g.root.CFrame = CFrame.lookAt(g.pos, g.pos + g.look)
end

-- A flare (PredatorService.useFlare) scares every guardian in range away from it
function GuardianService.Scare(at: Vector3)
	for _, g in guardians do
		if (g.pos - at).Magnitude < Monsters.FlareRange and g.state ~= "Idle" then
			local away = g.pos - at
			g.flee = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 1, 0)
			g.timer = os.clock() + Monsters.FlareSeconds
			g.target = nil
			setState(g, "Scared")
		end
	end
end

function GuardianService.Start()
	for _, def in Monsters.List do
		for i = 1, def.Count do
			spawnGuardian(def, i)
		end
	end
	task.spawn(function()
		while true do
			local dt = task.wait(TICK)
			for _, g in guardians do
				local ok, err = pcall(tick, g, dt)
				if not ok then
					warn(`[GuardianService] {g.def.Id}: {err}`)
					setState(g, "Return")
				end
			end
		end
	end)
end

return GuardianService
