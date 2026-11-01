-- Daily / weekly quests feeding Tide Pass XP (Master Plan §15.5)
-- Stat = the progress counter name QuestService.Progress() is called with.

return {
	DailyCount = 3,
	WeeklyCount = 3,
	Daily = {
		{ Id = "D_Salvage20", Text = "Salvage 20 relics", Stat = "Salvage", Goal = 20, Xp = 40, Coins = 1500 },
		{ Id = "D_Dive5", Text = "Complete 5 dives", Stat = "Escape", Goal = 5, Xp = 40, Coins = 1500 },
		{ Id = "D_Rare3", Text = "Find 3 Rare+ relics", Stat = "RarePlus", Goal = 3, Xp = 50, Pearls = 5 },
		{ Id = "D_Mutated2", Text = "Find 2 mutated relics", Stat = "Mutated", Goal = 2, Xp = 50, Pearls = 5 },
		{ Id = "D_Collect", Text = "Collect dock Coins 5 times", Stat = "Collect", Goal = 5, Xp = 30, Coins = 1000 },
		{ Id = "D_Upgrade3", Text = "Buy 3 upgrades", Stat = "Upgrade", Goal = 3, Xp = 40, Coins = 2000 },
		{ Id = "D_Deep", Text = "Reach the Midnight Wrecks", Stat = "ReachZone3", Goal = 1, Xp = 50, Pearls = 5 },
		{ Id = "D_Sell10", Text = "Sell 10 relics", Stat = "Sell", Goal = 10, Xp = 30, Coins = 1000 },
	},
	Weekly = {
		{ Id = "W_Escape3", Text = "Escape the Leviathan 3 times", Stat = "LeviathanEscape", Goal = 3, Xp = 200, Pearls = 40 },
		{ Id = "W_Steal2", Text = "Steal 2 relics", Stat = "Steal", Goal = 2, Xp = 150, Pearls = 25 },
		{ Id = "W_Bio1", Text = "Find a Bioluminescent relic", Stat = "Mut_Bioluminescent", Goal = 1, Xp = 200, Pearls = 40 },
		{ Id = "W_Epic10", Text = "Find 10 Epic+ relics", Stat = "EpicPlus", Goal = 10, Xp = 200, Pearls = 30 },
		{ Id = "W_Salvage200", Text = "Salvage 200 relics", Stat = "Salvage", Goal = 200, Xp = 250, Pearls = 40 },
	},
}
