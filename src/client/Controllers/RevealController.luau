-- RevealController (Master Plan §7.1 reveal effects, §18.3): rarity reveal card with
-- tier-specific flair. Reveals become skippable (tap) after the first 10.

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local NumberFormat = require(Shared.NumberFormat)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Kit = require(script.Parent.Parent.UI.Kit)

local New, T = Kit.New, Kit.Theme
local RevealController = {}
local controllers
local seen = 0
local queue = {}
local showing = false

function RevealController.Init(c)
	controllers = c
end

local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local entry = table.remove(queue, 1)
	local relic = entry.relic
	local def = Relics.ById[relic.id]
	local rarity = Rarities[relic.rarity]
	local tier = rarity.Tier
	seen += 1

	local overlay = controllers.UIController.Overlay
	local card = Kit.Panel({
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(340, 200),
		BackgroundColor3 = Color3.fromRGB(8, 12, 22),
		Parent = overlay,
	}, { Kit.Padding(12), Kit.List(4, false, Enum.HorizontalAlignment.Center) })
	local stroke = card:FindFirstChildOfClass("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = if tier >= 5 then 4 else 2

	local mutText = ""
	if #relic.mutations > 0 then
		local parts = {}
		for _, m in relic.mutations do
			table.insert(parts, `{m} x{Mutations.ById[m] and Mutations.ById[m].Mult or 1}`)
		end
		mutText = table.concat(parts, " · ")
	end
	Kit.Label({
		Text = `{rarity.Icon} {relic.rarity:upper()} {rarity.Icon}`,
		Font = T.Bold,
		TextSize = if tier >= 6 then 30 else 24,
		TextColor3 = if relic.rarity == "Secret" then Color3.new(1, 1, 1) else rarity.Color,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = card,
	})
	Kit.Label({
		Text = (if relic.size >= 1.35 then "HUGE! " else "") .. def.Name,
		Font = T.Bold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = card,
	})
	if mutText ~= "" then
		local m = Mutations.ById[relic.mutations[1]]
		Kit.Label({
			Text = mutText,
			Font = T.Bold,
			TextSize = 16,
			TextColor3 = m and m.Color or T.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 20),
			Parent = card,
		})
	end
	Kit.Label({
		Text = `Size {relic.size}x · +{NumberFormat.short(Formulas.RelicCPS(relic))} Coins/s when displayed`,
		TextColor3 = T.Muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = card,
	})
	Kit.Label({
		Text = `"{def.Lore}"`,
		TextColor3 = T.Muted,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = card,
	})
	Kit.Pop(card)

	-- Tier flair: screen glow (Epic), slow-mo blur (Legendary), flash (Mythic+)
	local blur
	if tier >= 5 then
		blur = Instance.new("BlurEffect")
		blur.Size = 12
		blur.Parent = Lighting
	end
	if tier >= 4 then
		local glow = New("Frame", {
			BackgroundColor3 = rarity.Color,
			BackgroundTransparency = 0.6,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Parent = overlay,
		})
		TweenService:Create(glow, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		task.delay(1.3, function()
			glow:Destroy()
		end)
	end
	if controllers.AudioController then
		controllers.AudioController.Play("Reveal", 0.8 + tier * 0.08)
	end

	local duration = ({ 1.4, 1.6, 2, 2.4, 3.2, 4.5, 6 })[tier] or 2
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		if blur then
			blur:Destroy()
		end
		card:Destroy()
		showing = false
		showNext()
	end
	if seen > 10 then
		local skip = New("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			Parent = card,
		})
		skip.Activated:Connect(finish)
	end
	task.delay(duration, finish)
end

function RevealController.Start()
	Net.RevealRelic.OnClientEvent:Connect(function(relic, source)
		table.insert(queue, { relic = relic, source = source })
		showNext()
	end)
end

return RevealController
