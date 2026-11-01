-- Icon registry (UI/Visual Overhaul Plan). Every icon in the UI is looked up here.
-- Today icons are colour emoji shown in gradient badges (Kit.IconBadge). When real icon art is
-- uploaded, put "rbxassetid://<id>" in Images under the same key and the UI switches to the
-- image automatically; no screen code changes.

local Icons = {}

Icons.Images = {
	-- e.g. Coins = "rbxassetid://1234567890",
}

Icons.Emoji = {
	-- Currencies
	Coins = "🪙",
	Pearls = "🫧",
	Tokens = "🔱",
	Robux = "💎",
	Income = "📈",
	-- Menu / windows
	Shop = "🛒",
	Bag = "🎒",
	Upgrades = "⚒️",
	Codex = "📖",
	Quests = "📜",
	Rebirth = "🌊",
	Leaderboards = "🏆",
	Players = "👥",
	Settings = "⚙️",
	Trade = "🤝",
	-- HUD actions
	Sonar = "📡",
	Flare = "🧨",
	Surface = "🏝️",
	Up = "⬆️",
	Down = "⬇️",
	Boost = "💨",
	Oxygen = "🫁",
	Depth = "🌊",
	Event = "⚡",
	Lock = "🔒",
	Sell = "💰",
	Display = "🏛️",
	Vault = "🔐",
	Clean = "🧽",
	Take = "✋",
	Huge = "🔺",
	Alert = "🚨",
	-- Passes
	VIP = "👑",
	DoubleOxygen = "🫁",
	Drone = "🛸",
	LuckySonar = "🍀",
	VaultLock = "🔐",
	ExtraSlots = "🏛️",
	BigBag = "🎒",
	InstantSurface = "🚀",
	SpeedFins = "🦈",
	AutoCollect = "🧲",
	MutationScan = "🔬",
	Radio = "📻",
	DeepDiverBundle = "🤿",
	CollectorBundle = "🗃️",
	PassPlus = "🌟",
	Premium = "⭐",
	StarterPack = "🎁",
	-- Products
	LuckPotion = "🍀",
	MutationPotion = "🧪",
	ServerLuck = "🌈",
	Flares5 = "🧨",
	OxygenRefill = "🫁",
	SkipPity = "🎲",
	TierSkip = "⏩",
	RenameDock = "🪧",
	Revive = "❤️",
	GateRecharge = "🔋",
	BarnacleClean = "🧽",
	TidePassPremium = "🎫",
	CrateSingle = "📦",
	CrateTriple = "📦",
	-- Upgrade tracks
	Oxygen_Track = "🫁",
	Fins = "🦈",
	Bag_Track = "🎒",
	Sonar_Track = "📡",
	Salvage = "🔧",
	Display_Track = "🏛️",
	Offline = "🌙",
	Gate = "🚧",
	Crab = "🦀",
	Alarm = "🔔",
	Suit = "🤿",
	-- Zones
	Reef = "🐠",
	Kelp = "🌿",
	Wrecks = "⚓",
	Abyss = "🦑",
	Trench = "🌋",
	-- Toast kinds
	error = "⚠️",
	reward = "🎁",
	coins = "🪙",
	upgrade = "⬆️",
	info = "💬",
}

-- Upgrade track ids collide with menu keys; map them explicitly
local TRACK_KEYS = { Oxygen = "Oxygen_Track", Bag = "Bag_Track", Sonar = "Sonar_Track", Display = "Display_Track" }

function Icons.Get(key: string): string
	return Icons.Images[key] or Icons.Emoji[key] or "✦"
end

function Icons.Track(trackId: string): string
	return Icons.Get(TRACK_KEYS[trackId] or trackId)
end

-- Badge colours per menu key (HUD tiles, window headers)
Icons.Colors = {
	Shop = Color3.fromRGB(255, 196, 50),
	Bag = Color3.fromRGB(60, 160, 255),
	Upgrades = Color3.fromRGB(255, 140, 60),
	Codex = Color3.fromRGB(170, 100, 255),
	Quests = Color3.fromRGB(80, 205, 120),
	Rebirth = Color3.fromRGB(40, 205, 225),
	Leaderboards = Color3.fromRGB(255, 170, 40),
	Players = Color3.fromRGB(255, 100, 160),
	Settings = Color3.fromRGB(130, 150, 175),
	Trade = Color3.fromRGB(255, 196, 50),
}

return Icons
