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
	Track_Board = "down",
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

-- New icon set (Stylized Game Essentials 147). Each entry is the PNG to upload in Studio
-- (Decal/Image). Paste the rbxassetid into Icons.Images under the same key to switch it on.
-- Keys without a file keep the drawn UI/Icon fallback.
Icons.Assets = {
	Coins = "gold_coin.png",
	Pearls = "blue_diamond.png",
	Tokens = "premium_token.png",
	Income = "upgrade_arrow.png",
	Shop = "storefront.png",
	Bag = "inventory_menu.png",
	Upgrades = "upgrade_arrow.png",
	Codex = "skill_book.png",
	Quests = "quest_scroll.png",
	Rebirth = "rebirth_symbol.png",
	Leaderboards = "leaderboard_podium.png",
	Players = "friends.png",
	Settings = "settings_gear.png",
	Trade = "trade_arrows.png",
	Diver = "helmet.png",
	Surface = "home.png",
	Boost = "speed_boost.png",
	Event = "event_ticket.png",
	Sell = "stack_of_coins.png",
	Take = "collect_hand.png",
	Close = "close_button.png",
	Check = "claim_checkmark.png",
	Offline = "clock.png",
	VIP = "vip_crown.png",
	LuckySonar = "luck_clover.png",
	ExtraSlots = "equipment_slot.png",
	BigBag = "money_bag.png",
	InstantSurface = "home.png",
	SpeedFins = "speed_boot.png",
	AutoCollect = "magnet_boost.png",
	MutationScan = "magic_wand.png",
	DeepDiverBundle = "helmet.png",
	CollectorBundle = "crystal_chest.png",
	PassPlus = "reward_star.png",
	Premium = "premium_pass.png",
	StarterPack = "wrapped_gift.png",
	LuckPotion = "luck_potion.png",
	MutationPotion = "mystery_potion.png",
	ServerLuck = "luck_boost.png",
	OxygenRefill = "stamina_potion.png",
	TierSkip = "level_up.png",
	Revive = "healing_cross.png",
	GateRecharge = "energy_bolt.png",
	TidePassPremium = "premium_pass.png",
	CrateSingle = "wooden_chest.png",
	CrateTriple = "gold_chest.png",
	Track_Fins = "speed_boot.png",
	Track_Bag = "money_bag.png",
	Track_Salvage = "wrench.png",
	Track_Offline = "hourglass.png",
	Track_Gate = "locked_gate.png",
	Track_Crab = "defense_shield.png",
	Track_Alarm = "notification_bell.png",
	Gate = "locked_gate.png",
	reward = "reward_star.png",
	coins = "stack_of_coins.png",
	upgrade = "upgrade_arrow.png",
	info = "information_symbol.png",
}

-- Icon to draw for a key: an uploaded image id if one exists, else a drawn icon name
function Icons.Get(key: string): string
	return Icons.Images[key] or Icons.Names[key] or "info"
end

function Icons.Track(trackId: string): string
	return Icons.Images["Track_" .. trackId] or Icons.Names["Track_" .. trackId] or "upgrade"
end

-- Colour per menu key: the HUD rail tile and the window's title band share it, so each
-- window is recognisable at a glance (colour-coded headers)
Icons.Colors = {
	Shop = Color3.fromRGB(245, 192, 74),
	Bag = Color3.fromRGB(63, 214, 230),
	Upgrades = Color3.fromRGB(255, 150, 70),
	Codex = Color3.fromRGB(180, 140, 255),
	Quests = Color3.fromRGB(123, 227, 160),
	Rebirth = Color3.fromRGB(90, 200, 255),
	Leaderboards = Color3.fromRGB(245, 192, 74),
	Players = Color3.fromRGB(255, 130, 180),
	Settings = Color3.fromRGB(169, 189, 214),
	Trade = Color3.fromRGB(245, 192, 74),
	Diver = Color3.fromRGB(63, 214, 230),
}

return Icons
