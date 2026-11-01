-- Remote definitions (Master Plan §20.4).
-- Remotes are named by intent. The client only ever sends intent + IDs, never values.
-- Server: Net.Setup() creates the instances. Client: Net.<Name> waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- client -> server
	"ClientReady",
	"SetBoost",
	"UseSonar",
	"UseFlare",
	"RequestUpgrade",
	"RequestBuySuit",
	"RequestSell",
	"RequestSellCommons",
	"RequestToggleLock",
	"RequestPlaceRelic",
	"RequestPickupRelic",
	"RequestCollect",
	"RequestClaimOffline",
	"RequestFreeRevive",
	"RequestInstantSurface",
	"RequestRebirth",
	"RequestTalent",
	"RequestClaimQuest",
	"RequestClaimDaily",
	"RequestClaimTier",
	"RequestBuyTidePassPearls",
	"RequestRedeemCode",
	"RequestPurchase", -- (kind, key): server validates and prompts
	"RequestRevenge",
	"ActivateGate",
	"RequestCleanBarnacle",
	"TradeRequest",
	"TradeRespond",
	"TradeSetOffer",
	"TradeConfirm",
	"TradeCancel",
	"PartyInvite",
	"PartyRespond",
	"PartyLeave",
	"UpdateSettings",
	"RenameDock",
	"OfferShown",
	-- server -> client
	"StateUpdated",
	"Notify",
	"Announce",
	"RevealRelic",
	"PlayerDied",
	"Revived",
	"Robbed",
	"Intruder",
	"OfflineEarnings",
	"EventsChanged",
	"SonarResult",
	"Knockback",
	"TradeUpdated",
	"PartyUpdated",
	"Offer",
	"Leaderboards",
	"CarryChanged",
	"CoinBurst", -- (amount, worldPosition?, caption?): coin pop-up + fly-to-HUD effect
}

local UNRELIABLE = {
	"DiveStatus", -- oxygen/depth/zone at 5 Hz
	"PredatorHint", -- leviathan proximity for audio/UI
}

local Net = {}
local folder: Folder? = nil

function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup is server-only")
	local f = Instance.new("Folder")
	f.Name = "Remotes"
	for _, name in EVENTS do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = f
	end
	for _, name in UNRELIABLE do
		local r = Instance.new("UnreliableRemoteEvent")
		r.Name = name
		r.Parent = f
	end
	f.Parent = ReplicatedStorage
	folder = f
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		error("Net used before Net.Setup()")
	end
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	return folder :: Folder
end

setmetatable(Net, {
	__index = function(_, name: string)
		local f = getFolder()
		local r = f:FindFirstChild(name)
		if not r and RunService:IsClient() then
			r = f:WaitForChild(name, 10)
		end
		assert(r, "Unknown remote " .. tostring(name))
		rawset(Net, name, r)
		return r
	end,
})

return Net
