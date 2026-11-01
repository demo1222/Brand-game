-- WorldService: generates the graybox world at runtime (Master Plan §6, §8.1, §19).
-- Ocean volume with five depth zones, a central Harbor plaza, a ring of 16 docks, air pockets,
-- zone landmarks and plaza props (leaderboards, Server Luck Totem, VIP lounge).
-- Replace with art kits later; services only depend on the dock/zone data exposed here.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Build = require(script.Parent.Parent.Util.Build)

local WorldService = {}
local services
local docks = {}
local airPockets = {}
local root: Folder
local rng = Random.new(1337) -- deterministic layout

local SURFACE = World.WaterSurfaceY
local R = World.OceanRadius

function WorldService.Init(s)
	services = s
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function buildOcean()
	local ocean = folder("Ocean", root)
	-- Water surface (visual only; swimming is handled by the client SwimController)
	Build.Part({
		Name = "WaterSurface",
		Size = Vector3.new(R * 2 + 600, 1, R * 2 + 600),
		CFrame = CFrame.new(0, SURFACE - 0.5, 0),
		Color = Color3.fromRGB(30, 140, 200),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = ocean,
	})
	-- Seabed
	Build.Part({
		Name = "Seabed",
		Size = Vector3.new(R * 2 + 40, 8, R * 2 + 40),
		CFrame = CFrame.new(0, SURFACE - World.SeabedDepth - 4, 0),
		Color = Color3.fromRGB(40, 20, 20),
		Material = Enum.Material.Basalt,
		Parent = ocean,
	})
	-- Invisible bounds (parts are limited to 2048 studs per axis, so split vertically)
	local half = World.SeabedDepth / 2
	for _, seg in { 0, 1 } do
		local h = half + 40
		local cy = SURFACE + 40 - seg * half - h / 2
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			Build.Part({
				Name = "Bound",
				Size = if d[1] ~= 0 then Vector3.new(4, h, R * 2) else Vector3.new(R * 2, h, 4),
				CFrame = CFrame.new(d[1] * R, cy, d[2] * R),
				Transparency = 1,
				CanQuery = false,
				Parent = ocean,
			})
		end
	end

	-- Zone dressing: rocks, kelp, wrecks, vents. Landmarks act as points of interest.
	local palette = {
		{ Color3.fromRGB(240, 120, 110), Enum.Material.Sand, "Coral" },
		{ Color3.fromRGB(40, 120, 60), Enum.Material.Grass, "Kelp" },
		{ Color3.fromRGB(90, 70, 50), Enum.Material.WoodPlanks, "Wreck" },
		{ Color3.fromRGB(30, 30, 50), Enum.Material.Slate, "Rock" },
		{ Color3.fromRGB(60, 15, 15), Enum.Material.Basalt, "Vent" },
	}
	for _, zone in Zones.List do
		local zf = folder(zone.Id, ocean)
		local style = palette[zone.Index]
		for i = 1, 40 do
			local depth = rng:NextNumber(zone.MinDepth + 10, zone.MaxDepth - 10)
			local pos = Vector3.new(rng:NextNumber(-R + 30, R - 30), SURFACE - depth, rng:NextNumber(-R + 30, R - 30))
			if style[3] == "Kelp" then
				Build.Part({
					Name = "Kelp",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(rng:NextNumber(40, 90), 2, 2),
					CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
					Color = style[1],
					Material = style[2],
					CanCollide = false,
					Parent = zf,
				})
			else
				Build.Part({
					Name = style[3],
					Size = Vector3.new(rng:NextNumber(6, 26), rng:NextNumber(4, 18), rng:NextNumber(6, 26)),
					CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
					Color = style[1],
					Material = style[2],
					Parent = zf,
				})
			end
			if style[3] == "Vent" and i % 4 == 0 then
				Build.Part({
					Name = "VentGlow",
					Shape = Enum.PartType.Ball,
					Size = Vector3.one * 5,
					CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)),
					Color = Color3.fromRGB(255, 60, 20),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = zf,
				})
			end
		end
		-- 3 landmarks per zone (§6 points of interest)
		for i = 1, 3 do
			local depth = zone.MinDepth + (zone.MaxDepth - zone.MinDepth) * (i / 4)
			local angle = (i / 3) * math.pi * 2 + zone.Index
			local pos = Vector3.new(math.cos(angle) * R * 0.55, SURFACE - depth, math.sin(angle) * R * 0.55)
			local lm = Build.Part({
				Name = "Landmark",
				Size = Vector3.new(30, 50, 30),
				CFrame = CFrame.new(pos),
				Color = style[1]:Lerp(Color3.new(1, 1, 1), 0.2),
				Material = style[2],
				Parent = zf,
			})
			lm:SetAttribute("Zone", zone.Index)
			Build.Instance("PointLight", { Range = 40, Brightness = 1, Color = style[1], Parent = lm })
		end
	end

	-- Air pockets (§6): rare oxygen refills in zones 3–5
	local af = folder("AirPockets", ocean)
	for zoneIndex, count in World.AirPocketsPerZone do
		local zone = Zones.List[zoneIndex]
		for _ = 1, count do
			local depth = rng:NextNumber(zone.MinDepth + 40, zone.MaxDepth - 40)
			local p = Build.Part({
				Name = "AirPocket",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 8,
				CFrame = CFrame.new(rng:NextNumber(-R + 60, R - 60), SURFACE - depth, rng:NextNumber(-R + 60, R - 60)),
				Color = Color3.fromRGB(180, 240, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.3,
				CanCollide = false,
				Parent = af,
			})
			Build.Instance("PointLight", { Range = 30, Brightness = 2, Color = p.Color, Parent = p })
			table.insert(airPockets, p)
		end
	end
end

local function buildPlaza()
	local plaza = folder("Plaza", root)
	local top = SURFACE + World.DockHeight
	Build.Part({
		Name = "Harbor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, World.PlazaRadius * 2, World.PlazaRadius * 2),
		CFrame = CFrame.new(0, top - 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(160, 130, 95),
		Material = Enum.Material.WoodPlanks,
		Parent = plaza,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HarborSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, top + 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.5
	spawn.Parent = plaza

	-- Leaderboard boards (§14) — LeaderboardService fills the SurfaceGuis
	local boards = folder("Leaderboards", plaza)
	local names = { "Deepest", "TotalValue", "Rebirths", "Steals", "Codex" }
	for i, name in names do
		local a = (i - 1) / #names * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 45, top + 9, math.sin(a) * 45)
		local board = Build.Part({
			Name = name,
			Size = Vector3.new(14, 16, 1),
			CFrame = CFrame.lookAt(pos, Vector3.new(0, top + 9, 0)),
			Color = Color3.fromRGB(20, 30, 45),
			Parent = boards,
		})
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Board"
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(400, 460)
		sg.Parent = board
		local list = Instance.new("TextLabel")
		list.Name = "Text"
		list.Size = UDim2.fromScale(1, 1)
		list.BackgroundTransparency = 1
		list.TextColor3 = Color3.new(1, 1, 1)
		list.Font = Enum.Font.GothamMedium
		list.TextSize = 22
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Text = name .. "\nLoading…"
		list.Parent = sg
	end

	-- Server Luck Totem (§15.3)
	local totem = Build.Part({
		Name = "LuckTotem",
		Size = Vector3.new(4, 14, 4),
		CFrame = CFrame.new(0, top + 7, -18),
		Color = Color3.fromRGB(80, 255, 140),
		Material = Enum.Material.Neon,
		Parent = plaza,
	})
	Build.Billboard(totem, "SERVER LUCK TOTEM\n2x luck for everyone", UDim2.fromOffset(240, 60), Vector3.new(0, 10, 0))
	local totemPrompt = Build.Prompt(totem, "Boost Server Luck", "199 R$", 0, "LuckPrompt")
	totemPrompt.Triggered:Connect(function(player)
		local Net = require(Shared.Net)
		Net.Offer:FireClient(player, "ServerLuck")
	end)

	-- VIP lounge (§15.2 "VIP door you can see but not enter")
	local lounge = Build.Part({
		Name = "VipLounge",
		Size = Vector3.new(30, 1, 30),
		CFrame = CFrame.new(0, top + 30, 50),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Marble,
		Parent = plaza,
	})
	Build.Billboard(lounge, "VIP LOUNGE", UDim2.fromOffset(200, 50), Vector3.new(0, 6, 0), Color3.fromRGB(255, 210, 80))
	local door = Build.Part({
		Name = "VipDoor",
		Size = Vector3.new(8, 12, 1),
		CFrame = CFrame.new(0, top + 6, 30),
		Color = Color3.fromRGB(255, 200, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Parent = plaza,
	})
	Build.Billboard(door, "VIP", UDim2.fromOffset(120, 40), Vector3.new(0, 8, 0), Color3.fromRGB(255, 210, 80))
	local doorPrompt = Build.Prompt(door, "Enter VIP Lounge", "VIP Diver", 0, "VipPrompt")
	doorPrompt.Triggered:Connect(function(player)
		if services.MonetizationService.Owns(player, "VIP") then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				services.SecurityService.AllowTeleport(player)
				char:PivotTo(lounge.CFrame + Vector3.new(0, 4, 0))
			end
		else
			local Net = require(Shared.Net)
			Net.Offer:FireClient(player, "VIP")
		end
	end)
end

local function buildDock(index: number)
	local angle = (index - 1) / World.DockCount * math.pi * 2
	local center = Vector3.new(math.cos(angle) * World.DockRingRadius, SURFACE + World.DockHeight, math.sin(angle) * World.DockRingRadius)
	-- Dock faces outward (look away from the plaza); local -Z points to the open ocean
	local cf = CFrame.lookAt(center, center + Vector3.new(center.X, 0, center.Z).Unit)
	local model = Instance.new("Model")
	model.Name = "Dock" .. index
	model.Parent = root.Docks

	local size = World.DockSize
	local platform = Build.Part({
		Name = "Platform",
		Size = size,
		CFrame = cf * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(150, 115, 80),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	model.PrimaryPart = platform
	-- Pillars into the water
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			Build.Part({
				Name = "Pillar",
				Size = Vector3.new(2, World.DockHeight + 20, 2),
				CFrame = cf * CFrame.new(x * (size.X / 2 - 2), -(World.DockHeight + 20) / 2, z * (size.Z / 2 - 2)),
				Color = Color3.fromRGB(90, 70, 50),
				Material = Enum.Material.Wood,
				Parent = model,
			})
		end
	end
	-- Walkway to the plaza
	local inner = cf * CFrame.new(0, -1, size.Z / 2)
	local plazaEdge = Vector3.new(0, inner.Position.Y, 0) + (Vector3.new(center.X, 0, center.Z).Unit * World.PlazaRadius)
	local walkLen = (inner.Position - plazaEdge).Magnitude
	Build.Part({
		Name = "Walkway",
		Size = Vector3.new(6, 1, walkLen),
		CFrame = CFrame.lookAt((inner.Position + plazaEdge) / 2, plazaEdge),
		Color = Color3.fromRGB(130, 100, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	-- Dive ramp on the ocean side
	Build.Instance("WedgePart", {
		Name = "DiveRamp",
		Anchored = true,
		Size = Vector3.new(10, 3, 10),
		CFrame = cf * CFrame.new(0, 0.5, -size.Z / 2 - 5) * CFrame.Angles(0, math.rad(180), 0),
		Color = Color3.fromRGB(60, 160, 220),
		Parent = model,
	})

	-- Sign
	local sign = Build.Part({
		Name = "Sign",
		Size = Vector3.new(16, 5, 1),
		CFrame = cf * CFrame.new(0, 7, size.Z / 2 - 1),
		Color = Color3.fromRGB(40, 50, 70),
		Parent = model,
	})
	local signGui = Build.Billboard(sign, "Empty Dock", UDim2.fromOffset(260, 70), Vector3.new(0, 4, 0))
	signGui.MaxDistance = 250

	-- Stands: 5 rows x 7 columns grid
	local stands = {}
	local cols = 7
	for i = 1, World.MaxStands do
		local row = (i - 1) // cols
		local col = (i - 1) % cols
		local x = (col - (cols - 1) / 2) * World.StandSpacing
		local z = size.Z / 2 - 8 - row * World.StandSpacing
		local stand = Build.Part({
			Name = "Stand" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 4, 4),
			CFrame = cf * CFrame.new(x, 1, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 200, 210),
			Material = Enum.Material.Marble,
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		stand:SetAttribute("StandIndex", i)
		local place = Build.Prompt(stand, "Display", "Stand " .. i, 0, "Place")
		place.Enabled = false
		local steal = Build.Prompt(stand, "Steal", "Relic", 2.5, "Steal")
		steal.Enabled = false
		steal.KeyboardKeyCode = Enum.KeyCode.F
		steal.UIOffset = Vector2.new(0, 60)
		local label = Build.Billboard(stand, "", UDim2.fromOffset(140, 36), Vector3.new(0, 4.5, 0))
		label.Name = "Info"
		label.MaxDistance = 40
		stands[i] = stand
	end
	-- Vault stands (§8.1)
	local vault = {}
	for i = 1, 2 do
		local stand = Build.Part({
			Name = "Vault" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2, 4, 4),
			CFrame = cf * CFrame.new((i == 1 and -1 or 1) * (size.X / 2 - 4), 1, -size.Z / 2 + 6) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.Foil,
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		stand:SetAttribute("VaultIndex", i)
		local place = Build.Prompt(stand, "Vault", "Vault " .. i, 0, "Place")
		place.Enabled = false
		local label = Build.Billboard(stand, "", UDim2.fromOffset(140, 36), Vector3.new(0, 4.5, 0))
		label.Name = "Info"
		label.MaxDistance = 40
		vault[i] = stand
	end

	-- Coin collector pad (§8.1)
	local pad = Build.Part({
		Name = "CollectorPad",
		Size = Vector3.new(5, 0.6, 5),
		CFrame = cf * CFrame.new(-size.X / 2 + 3, 0.3, size.Z / 2 - 4),
		Color = Color3.fromRGB(60, 230, 120),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	local padGui = Build.Billboard(pad, "0", UDim2.fromOffset(160, 40), Vector3.new(0, 4, 0), Color3.fromRGB(120, 255, 160))
	padGui.MaxDistance = 80

	-- Laser gate visual (§8.4)
	local gate = Build.Part({
		Name = "LaserGate",
		Size = Vector3.new(size.X + 2, 16, size.Z + 2),
		CFrame = cf * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local gateButton = Build.Part({
		Name = "GateButton",
		Size = Vector3.new(2, 3, 2),
		CFrame = cf * CFrame.new(size.X / 2 - 2, 1.5, size.Z / 2 - 4),
		Color = Color3.fromRGB(255, 40, 60),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local gatePrompt = Build.Prompt(gateButton, "Activate Laser Gate", "Dock Defense", 0, "GatePrompt")
	gatePrompt.Enabled = false

	local dock = {
		Index = index,
		CFrame = cf,
		Model = model,
		Platform = platform,
		Stands = stands,
		Vault = vault,
		Pad = pad,
		PadLabel = padGui.Label,
		Sign = signGui.Label,
		Gate = gate,
		GatePrompt = gatePrompt,
		SpawnCFrame = cf * CFrame.new(0, 4, size.Z / 2 - 4) * CFrame.Angles(0, math.rad(180), 0),
		Owner = nil,
	}
	docks[index] = dock
	return dock
end

function WorldService.GetDocks()
	return docks
end

function WorldService.GetAirPockets()
	return airPockets
end

-- Is a world position inside a dock's raid area?
function WorldService.IsInsideDock(dock, position: Vector3, margin: number?): boolean
	local rel = dock.CFrame:PointToObjectSpace(position)
	local size = World.DockSize
	local m = margin or 2
	return math.abs(rel.X) <= size.X / 2 + m and math.abs(rel.Z) <= size.Z / 2 + m and rel.Y > -9 and rel.Y < 30
end

function WorldService.DepthOf(position: Vector3): number
	return SURFACE - position.Y
end

function WorldService.RandomPointInZone(zoneIndex: number, r: Random?): Vector3
	local zone = Zones.List[zoneIndex]
	local g = r or rng
	local depth = g:NextNumber(zone.MinDepth + 8, zone.MaxDepth - 8)
	return Vector3.new(g:NextNumber(-R + 20, R - 20), SURFACE - depth, g:NextNumber(-R + 20, R - 20))
end

function WorldService.Start()
	root = folder("AbyssWorld", Workspace)
	folder("Docks", root)
	folder("Relics", root)
	folder("Nodes", root)
	folder("Creatures", root)
	folder("Drops", root)

	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.FogStart = 0
	Lighting.FogEnd = 2000

	buildOcean()
	buildPlaza()
	for i = 1, World.DockCount do
		buildDock(i)
	end
end

function WorldService.Root(): Folder
	return root
end

return WorldService
