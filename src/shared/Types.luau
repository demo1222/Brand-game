-- Shared types (Master Plan §21.1)

export type RelicInstance = {
	uid: string, -- HttpService:GenerateGUID(false)
	id: string, -- "R041"
	rarity: string,
	mutations: { string },
	size: number,
	foundAt: number, -- os.time()
	foundBy: number, -- original finder UserId (provenance for trades)
	locked: boolean?, -- favourite lock (prevents selling)
	placedAt: number?, -- os.time() when put on a stand (steal protection)
}

-- DataStores require string keys for sparse maps, so stands are keyed "1".."34".
export type ProfileData = {
	Version: number,
	Coins: number,
	Pearls: number,
	LifetimeCoins: number,
	Uncollected: number,
	Level: number,
	XP: number,
	Rebirths: number,
	RebirthTokens: number,
	Talents: { [string]: number },
	Upgrades: { [string]: number },
	Suit: number,
	Bag: { RelicInstance }, -- carried on the current dive (lost on death)
	Storage: { RelicInstance }, -- secured at the dock (overflow inventory)
	Stands: { [string]: RelicInstance },
	Vault: { [string]: RelicInstance },
	Codex: { [string]: { [string]: boolean } },
	Pity: { [string]: number },
	Flares: number,
	LastLogout: number,
	PlayTime: number,
	LoginStreak: number,
	LastLoginDay: number,
	LastDailyClaimDay: number,
	Quests: any,
	TidePass: { SeasonId: string, XP: number, Premium: boolean, ClaimedFree: { [string]: boolean }, ClaimedPremium: { [string]: boolean } },
	PurchaseHistory: { [string]: number },
	ProductCounts: { [string]: number },
	ActiveBoosts: { [string]: number },
	RedeemedCodes: { [string]: boolean },
	StarterPackShownAt: number?,
	StarterPackBought: boolean,
	LastFreeRevive: number,
	LastSubPearlsDay: number,
	LastVipChestDay: number,
	LastPremiumChest: number,
	DockName: string?,
	RenameTokens: number,
	Settings: { Music: number, SFX: number, LowScare: boolean },
	Stats: {
		Dives: number,
		Deaths: number,
		Steals: number,
		TimesRobbed: number,
		DeepestDepth: number,
		MythicsFound: number,
		Salvaged: number,
	},
	Flags: { [string]: boolean },
}

return {}
