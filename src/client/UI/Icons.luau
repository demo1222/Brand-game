-- Icon registry: maps game keys (menu entries, passes, products, upgrade tracks, zones, toast
-- kinds) to drawn icon names from UI/Icon. No emoji: newer emoji render as empty boxes on
-- Roblox and the coloured set clashed with the UI design.
-- When real art is uploaded, put "rbxassetid://<id>" in Images under the same key; anything
-- that draws icons through Kit.IconBadge switches to the image automatically.

local Icons = {}

Icons.Images = {
	-- e.g. Coins = "rbxassetid://1234567890",
}

Icons.Names = {
	-- currencies
	Coins = "coin",
	Pearls = "pearl",
	Tokens = "token",
	Income = "upgrade",
	-- menu / windows
	Shop = "shop",
	Bag = "bag",
	Upgrades = "upgrade",
	Codex = "codex",
	Quests = "quests",
	Rebirth = "rebirth",
	Leaderboards = "top",
	Players = "friends",
	Settings = "settings",
	Trade = "trade",
	Diver = "diver",
	-- HUD actions and states
	Sonar = "sonar",
	Flare = "flare",
	Surface = "home",
	Up = "up",
	Down = "down",
	Boost = "boost",
	Oxygen = "oxygen",
	Depth = "down",
	Event = "event",
	Lock = "lock",
	Sell = "coin",
	Display = "display",
	Vault = "lock",
	Clean = "sparkle",
	Take = "down",
	Huge = "up",
	Alert = "alert",
	Close = "close",
	Check = "check",
	Offline = "clock",
	Death = "alert",
	-- passes
	VIP = "crown",
	DoubleOxygen = "oxygen",
	Drone = "drone",
	LuckySonar = "sonar",
	VaultLock = "lock",
	ExtraSlots = "display",
	BigBag = "bag",
	InstantSurface = "home",
	SpeedFins = "boost",
	AutoCollect = "magnet",
	MutationScan = "scan",
	Radio = "radio",
	DeepDiverBundle = "diver",
	CollectorBundle = "box",
	PassPlus = "star",
	Premium = "star",
	StarterPack = "gift",
	-- products
	LuckPotion = "potion",
	MutationPotion = "potion",
	ServerLuck = "star",
	Flares5 = "flare",
	OxygenRefill = "oxygen",
	SkipPity = "sparkle",
	TierSkip = "upgrade",
	RenameDock = "sign",
	Revive = "heart",
	GateRecharge = "event",
	BarnacleClean = "sparkle",
	TidePassPremium = "ticket",
	CrateSingle = "box",
	CrateTriple = "box",
	-- upgrade tracks (prefixed: some ids collide with menu keys)
	Track_Oxygen = "oxygen",
	Track_Fins = "boost",
	Track_Bag = "bag",
	Track_Sonar = "sonar",
	Track_Salvage = "wrench",
	Track_Display = "display",
	Track_Offline = "clock",
	Track_Gate = "gate",
	Track_Crab = "shield",
	Track_Alarm = "bell",
	Gate = "gate",
	-- zones
	Reef = "fish",
	Kelp = "kelp",
	Wrecks = "anchor",
	Abyss = "eye",
	Trench = "vent",
	-- toast kinds
	error = "alert",
	reward = "gift",
	coins = "coin",
	upgrade = "upgrade",
	info = "info",
}

-- Icon to draw for a key: an uploaded image id if one exists, else a drawn icon name
function Icons.Get(key: string): string
	return Icons.Images[key] or Icons.Names[key] or "info"
end

function Icons.Track(trackId: string): string
	return Icons.Images["Track_" .. trackId] or Icons.Names["Track_" .. trackId] or "upgrade"
end

-- Accent colours per menu key (window header hairlines, HUD rail)
Icons.Colors = {
	Shop = Color3.fromRGB(245, 192, 74),
	Bag = Color3.fromRGB(63, 214, 230),
	Upgrades = Color3.fromRGB(63, 214, 230),
	Codex = Color3.fromRGB(63, 214, 230),
	Quests = Color3.fromRGB(63, 214, 230),
	Rebirth = Color3.fromRGB(63, 214, 230),
	Leaderboards = Color3.fromRGB(245, 192, 74),
	Players = Color3.fromRGB(63, 214, 230),
	Settings = Color3.fromRGB(169, 189, 214),
	Trade = Color3.fromRGB(245, 192, 74),
	Diver = Color3.fromRGB(63, 214, 230),
}

return Icons
