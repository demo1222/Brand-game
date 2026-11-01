-- AnnouncementService (Master Plan §14): local, server-wide and cross-server announcements,
-- plus overhead titles ([VIP] tag, level, rebirth tier). Global messages go through
-- MessagingService, rate-limited to 1 per 10s per server (§21.3).

local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)

local TOPIC = "AbyssSalvage_Global"
local NEAR_RADIUS = 200

local AnnouncementService = {}
local services
local lastGlobal = 0

function AnnouncementService.Init(s)
	services = s
end

function AnnouncementService.Server(text: string, rarity: string?)
	Net.Announce:FireAllClients(text, rarity or "Rare")
end

function AnnouncementService.Near(source: Player, text: string, rarity: string?)
	local hrp = source.Character and source.Character:FindFirstChild("HumanoidRootPart")
	for _, p in Players:GetPlayers() do
		local other = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if p == source or (hrp and other and (hrp.Position - other.Position).Magnitude < NEAR_RADIUS) then
			Net.Announce:FireClient(p, text, rarity or "Legendary")
		end
	end
end

function AnnouncementService.Global(text: string, rarity: string?)
	AnnouncementService.Server(text, rarity)
	if os.clock() - lastGlobal < 10 then
		return
	end
	lastGlobal = os.clock()
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { Text = text, Rarity = rarity, JobId = game.JobId })
		end)
	end)
end

-- Overhead title: [VIP] Name · Lv 12 · ✦3
function AnnouncementService.UpdateTitle(player: Player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local data = services.DataService.GetData(player)
	if not head or not data then
		return
	end
	local bb = head:FindFirstChild("Title") :: BillboardGui?
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "Title"
		bb.Size = UDim2.fromOffset(220, 46)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.Parent = bb
		bb.Parent = head
	end
	local vip = services.MonetizationService.Owns(player, "VIP")
	local tags = {}
	if vip then
		table.insert(tags, "[VIP]")
	end
	if services.MonetizationService.HasActiveSubscription(player) then
		table.insert(tags, "[PASS+]")
	end
	local rebirth = if data.Rebirths > 0 then ` · ✦{data.Rebirths}` else ""
	local label = bb:FindFirstChild("Label") :: TextLabel
	label.Text = `{table.concat(tags, " ")} {player.DisplayName}\nLv {data.Level}{rebirth}`
	label.TextColor3 = if vip then Color3.fromRGB(255, 210, 80) else Color3.new(1, 1, 1)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function AnnouncementService.Start()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if typeof(data) == "table" and data.JobId ~= game.JobId and typeof(data.Text) == "string" then
					Net.Announce:FireAllClients("🌐 " .. data.Text, data.Rarity or "Secret")
				end
			end)
		end)
		if not ok then
			warn("[Announcement] MessagingService unavailable: " .. tostring(err))
		end
	end)
	services.DataService.ProfileLoaded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 5)
			AnnouncementService.UpdateTitle(player)
		end)
		if player.Character then
			AnnouncementService.UpdateTitle(player)
		end
	end)
	services.MonetizationService.PassGranted:Connect(function(player)
		AnnouncementService.UpdateTitle(player)
	end)
end

return AnnouncementService
