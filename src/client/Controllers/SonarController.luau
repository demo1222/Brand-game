-- SonarController (Master Plan §5.1, §11.1): pings the server and draws temporary markers.
-- Markers show rarity once Sonar is level 5 and mutations at level 10 / Mutation Scanner.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Rarities = require(Shared.Config.Rarities)

local MARKER_SECONDS = 7
local SonarController = {}
local controllers
local lastPing = 0
local markerFolder: Folder

function SonarController.Init(c)
	controllers = c
end

function SonarController.Ping()
	local cd = controllers.State.Derived("SonarCooldown") or 6
	if os.clock() - lastPing < cd then
		controllers.UIController.Toast(`Sonar recharging ({math.ceil(cd - (os.clock() - lastPing))}s)`, "info")
		return
	end
	lastPing = os.clock()
	Net.UseSonar:FireServer()
end

local function marker(info, from: string?)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = info.Position
	local rarity = info.Rarity and Rarities[info.Rarity]
	local color = if rarity then rarity.Color else Color3.fromRGB(120, 255, 255)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(110, 46)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 400
	bb.Parent = p
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.TextColor3 = color
	local text = if rarity then `{rarity.Icon} {info.Rarity}` else "◎"
	if info.Mutations and #info.Mutations > 0 then
		text ..= "\n" .. table.concat(info.Mutations, " ")
	end
	if from then
		text ..= `\n({from})`
	end
	label.Text = text
	label.Parent = bb
	p.Parent = markerFolder
	task.delay(MARKER_SECONDS, function()
		p:Destroy()
	end)
end

function SonarController.Start()
	markerFolder = Instance.new("Folder")
	markerFolder.Name = "SonarMarkers"
	markerFolder.Parent = Workspace
	Net.SonarResult.OnClientEvent:Connect(function(results, range, from)
		for _, info in results do
			marker(info, from)
		end
		if not from then
			controllers.UIController.Toast(`Sonar: {#results} relic{#results == 1 and "" or "s"} within {math.floor(range)} studs`, "info")
		end
	end)
end

return SonarController
