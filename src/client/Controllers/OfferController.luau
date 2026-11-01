-- OfferController (Master Plan §15.10, §22.5): contextual offers, death screen with revive
-- timer, "You were robbed" screen with revenge, offline-earnings popup and confirm dialogs.
-- Rule: at most one UNPROMPTED offer per 10 minutes; contextual offers are always allowed
-- because the player can simply dismiss them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local Passes = require(Shared.Config.Passes)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Config.Economy)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local OfferController = {}
local controllers
local lastUnprompted = -math.huge
local current: Frame? = nil
local currentHolder: Frame? = nil

local UNPROMPTED = { StarterPack = true, Drone = true }

local OFFER_TEXT = {
	DoubleOxygen = "Out of air? Double your tank — forever.",
	BigBag = "Bag full! Carry 4 more relics every dive.",
	ExtraSlots = "Stands full! Add 4 more display stands.",
	VaultLock = "Protect your best relics: 2 unstealable vault slots + keep 1 relic when you die.",
	LuckySonar = "So close! +25% luck on every rare roll.",
	InstantSurface = "Teleport home once per dive — never lose a bag in the deep again.",
	Drone = "Let a drone collect Common & Uncommon relics around you.",
	AutoCollect = "Never walk to the collector pad again.",
	StarterPack = "One-time offer: 10K Coins, 100 Pearls, the Neoprene suit and a Rare relic!",
	Flares5 = "Out of flares! 5 flares distract the Leviathan for 6s each.",
	GateRecharge = "Recharge your Laser Gate right now.",
	SkipPity = "Unlucky streak? Roll the Legendary table instantly.",
	ServerLuck = "Give EVERYONE in the server 2x luck for 15 minutes. Your name gets announced!",
	BarnacleClean = "Scrub off the barnacles and reroll this relic's mutation.",
	TidePassPremium = "Unlock the premium Tide Pass track.",
	RenameDock = "Give your dock a custom name.",
	VIP = "VIP Divers earn 1.5x Coins and get into the VIP lounge.",
}

function OfferController.Init(c)
	controllers = c
end

local function closeCurrent()
	if currentHolder then
		currentHolder:Destroy()
	end
	currentHolder = nil
	current = nil
end

-- Modal with a dim backdrop, a hero icon badge overlapping the top edge and a soft glow.
-- Returns the content panel (vertical list layout).
local function modal(height: number?, icon: string?, color: Color3?): Frame
	closeCurrent()
	local accent = color or T.Accent
	local holder = New("Frame", {
		Name = "ModalHolder",
		BackgroundColor3 = Color3.fromRGB(0, 4, 12),
		BackgroundTransparency = 0.45,
		Size = UDim2.new(1, 0, 1, 60),
		Position = UDim2.fromOffset(0, -60),
		Active = true,
		ZIndex = 20,
		Parent = controllers.UIController.Overlay,
	})
	local h = (height or 230) + 34
	local f = Kit.Panel({
		Name = "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 30),
		Size = UDim2.fromOffset(400, h),
		ZIndex = 21,
		Parent = holder,
	}, {
		New("UIPadding", {
			PaddingTop = UDim.new(0, 44),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
		Kit.List(8, false, Enum.HorizontalAlignment.Center),
	})
	local stroke = f:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
		stroke.Transparency = 0.05
		stroke.Thickness = 2.5
	end
	Kit.Glow(holder, accent, 170, { Position = UDim2.new(0.5, 0, 0.5, 30 - h / 2), ZIndex = 20 })
	local badge = Kit.IconBadge(icon or "✦", accent, 76, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 30 - h / 2),
		ZIndex = 23,
		Parent = holder,
	})
	Kit.Pop(f)
	Kit.Pop(badge)
	current = f
	currentHolder = holder
	return f
end

local function title(parent: Frame, text: string, color: Color3?, order: number)
	return Kit.Title({
		Text = text,
		TextSize = 24,
		TextColor3 = color or T.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		ZIndex = 22,
		Parent = parent,
	})
end

local function buttonsRow(parent: Frame, order: number)
	return New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.List(8, true, Enum.HorizontalAlignment.Center) })
end

-- Generic offer for a pass or product key
function OfferController.Show(key: string)
	local pass = Passes[key]
	local product = Products[key]
	if not pass and not product then
		return
	end
	if pass and controllers.State.Owns(key) then
		return
	end
	if UNPROMPTED[key] then
		if os.clock() - lastUnprompted < Economy.UnpromptedOfferCooldown then
			return
		end
		lastUnprompted = os.clock()
	end
	Net.OfferShown:FireServer(key)
	local def = pass or product
	local f = modal(nil, Icons.Get(key), T.Gold)
	title(f, def.name, Kit.Lighten(T.Gold, 0.3), 1)
	Kit.Label({
		Text = OFFER_TEXT[key] or def.desc or "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 70),
		Parent = f,
	})
	local row = buttonsRow(f, 3)
	Kit.Button(`Buy · {def.price} R$`, T.Gold, function()
		Net.RequestPurchase:FireServer(if pass then "Pass" else "Product", key)
		closeCurrent()
	end, { Size = UDim2.fromOffset(170, 48), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = row })
	Kit.Button("No thanks", T.PanelLight, closeCurrent, { Size = UDim2.fromOffset(130, 48), Parent = row })
end

function OfferController.Confirm(text: string, okLabel: string, callback: (boolean) -> ())
	local f = modal(190, "💬", T.Accent)
	Kit.Label({ Text = text, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 70), Parent = f })
	local row = buttonsRow(f, 2)
	Kit.Button(okLabel, T.Good, function()
		closeCurrent()
		callback(true)
	end, { Size = UDim2.fromOffset(140, 48), Parent = row })
	Kit.Button("Decline", T.PanelLight, function()
		closeCurrent()
		callback(false)
	end, { Size = UDim2.fromOffset(140, 48), Parent = row })
	task.delay(30, function()
		if current == f then
			closeCurrent()
			callback(false)
		end
	end)
end

local function deathScreen(info)
	local f = modal(260, if info.Cause == "Oxygen" then Icons.Get("Oxygen") else "💀", T.Bad)
	local lowScare = (controllers.State.Get("Settings") or {}).LowScare
	local causeText = ({
		Leviathan = if lowScare then "The Leviathan got you." else "THE LEVIATHAN GOT YOU",
		Oxygen = "You ran out of air.",
		Pressure = "The pressure was too much — get a stronger suit.",
		Eel = "Shocked by an eel.",
		Jellyfish = "Stung by jellyfish.",
	})[info.Cause] or "You were knocked out."
	title(f, causeText, Kit.Lighten(T.Bad, 0.3), 1)
	local bagText = if info.BagCount > 0
		then `Your bag ({info.BagCount} relics, ~{NumberFormat.short(info.BagValue)} Coins) will sink in`
		else "Your bag was empty."
	local timerLabel = Kit.Label({ Text = bagText, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 50), Parent = f })
	if info.Kept then
		Kit.Label({ Text = "Vault Lock kept your most valuable relic safe.", TextColor3 = T.Good, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), Parent = f })
	end
	local row = buttonsRow(f, 4)
	if info.BagCount > 0 or info.Underwater then
		if info.FreeRevive then
			Kit.Button("Free revive (Pass+)", T.Accent, function()
				Net.RequestFreeRevive:FireServer()
				closeCurrent()
			end, { Size = UDim2.fromOffset(170, 48), Parent = row })
		end
		Kit.Button(`Revive here · {Products.Revive.price} R$`, T.Gold, function()
			Net.RequestPurchase:FireServer("Product", "Revive")
		end, { Size = UDim2.fromOffset(190, 48), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = row })
	end
	Kit.Button("Respawn", T.PanelLight, closeCurrent, { Size = UDim2.fromOffset(110, 48), Parent = row })
	local deadline = os.clock() + info.Timer
	task.spawn(function()
		while current == f and os.clock() < deadline do
			if info.BagCount > 0 then
				timerLabel.Text = `{bagText} {math.ceil(deadline - os.clock())}s. Other divers can loot it!`
			end
			task.wait(0.2)
		end
		if current == f then
			closeCurrent()
		end
	end)
end

local function robbedScreen(info)
	local f = modal(250, Icons.Get("Alert"), T.Bad)
	title(f, "YOU WERE ROBBED!", Kit.Lighten(T.Bad, 0.3), 1)
	Kit.Label({ Text = `{info.Thief} stole your {info.Rarity} {info.Relic}.`, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 40), Parent = f })
	local row = buttonsRow(f, 3)
	Kit.Button(`Revenge! ({info.RevengeSeconds}s)`, T.Bad, function()
		Net.RequestRevenge:FireServer()
		closeCurrent()
	end, { Size = UDim2.fromOffset(170, 48), Parent = row })
	if not info.HasVault then
		Kit.Button(`Vault Lock · {Passes.VaultLock.price} R$`, T.Gold, function()
			Net.RequestPurchase:FireServer("Pass", "VaultLock")
			closeCurrent()
		end, { Size = UDim2.fromOffset(170, 48), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = row })
	end
	Kit.Button("Close", T.PanelLight, closeCurrent, { Size = UDim2.fromOffset(100, 40), LayoutOrder = 4, Parent = f })
end

local function offlineScreen(info)
	local f = modal(240, Icons.Get("Offline"), T.Good)
	title(f, "Welcome back, diver!", nil, 1)
	Kit.Label({
		Text = `Your dock earned {NumberFormat.short(info.Amount)} Coins while you were away ({NumberFormat.time(math.min(info.Elapsed, info.CapHours * 3600))}, cap {info.CapHours}h).`,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 60),
		Parent = f,
	})
	local row = buttonsRow(f, 3)
	Kit.Button("Collect", T.Good, function()
		Net.RequestClaimOffline:FireServer(false)
		closeCurrent()
	end, { Size = UDim2.fromOffset(130, 48), Parent = row })
	if info.CanDouble then
		Kit.Button(`Collect 2x (Pass+)`, T.Accent, function()
			Net.RequestClaimOffline:FireServer(true)
			closeCurrent()
		end, { Size = UDim2.fromOffset(170, 48), Parent = row })
	else
		Kit.Button("2x with Pass+", T.Gold, function()
			Net.RequestClaimOffline:FireServer(false)
			closeCurrent()
			controllers.ShopController.OpenTab("Pass+")
		end, { Size = UDim2.fromOffset(170, 48), TextColor3 = Color3.fromRGB(40, 25, 0), Parent = row })
	end
end

function OfferController.Start()
	Net.Offer.OnClientEvent:Connect(OfferController.Show)
	Net.PlayerDied.OnClientEvent:Connect(deathScreen)
	Net.Revived.OnClientEvent:Connect(function()
		closeCurrent()
		controllers.UIController.Toast("Revived! Your bag is safe.", "reward")
	end)
	Net.Robbed.OnClientEvent:Connect(robbedScreen)
	Net.OfflineEarnings.OnClientEvent:Connect(function(info)
		task.wait(2)
		offlineScreen(info)
	end)
end

return OfferController
