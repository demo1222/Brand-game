-- Server boot (Master Plan §20.3): creates remotes, then loads services in dependency order.
-- Each service may expose Init(services) (store references, no yielding) and Start()
-- (connect events, spawn loops). All Inits run before any Start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
Net.Setup()

local ORDER = {
	"PolicyWrapper",
	"DataService",
	"AnalyticsService",
	"CurrencyService",
	"BoostService",
	"MonetizationService",
	"InventoryService",
	"WorldService",
	"EventService",
	"UpgradeService",
	"DockService",
	"LootService",
	"DiveService",
	"PredatorService",
	"RaidService",
	"TradeService",
	"SocialService",
	"QuestService",
	"RebirthService",
	"LeaderboardService",
	"AnnouncementService",
	"CodesService",
	"AdminService",
	"SecurityService",
}

local services = {}
for _, name in ORDER do
	local module = script.Services:FindFirstChild(name)
	assert(module, "Missing service " .. name)
	services[name] = require(module)
end

for _, name in ORDER do
	local svc = services[name]
	if svc.Init then
		local ok, err = pcall(svc.Init, services)
		if not ok then
			warn(`[Boot] {name}.Init failed: {err}`)
		end
	end
end

for _, name in ORDER do
	local svc = services[name]
	if svc.Start then
		task.spawn(function()
			local ok, err = pcall(svc.Start)
			if not ok then
				warn(`[Boot] {name}.Start failed: {err}`)
			end
		end)
	end
end

print(`[Abyss Salvage] server booted ({#ORDER} services)`)
