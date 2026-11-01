-- AdminService (Master Plan §20.6, §23, §26.1): whitelisted chat commands, audit log,
-- LiveConfig (tune without publishing), Admin Abuse events, and the ban tool.
--
-- Chat commands (admins only), prefix "/as":
--   /as coins <n> | pearls <n> | level <n> | suit <n> | relic <Rarity>
--   /as pass <Key> | product <Key>            (grant / simulate for testing)
--   /as event <EventId> [minutes]             (Admin Abuse Hour)
--   /as luck <mult> <minutes>                 (server luck boost)
--   /as raids on|off
--   /as live reload                           (reload LiveConfig on every server)
--   /as kick <name> | ban <userId> <hours> [reason]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Economy = require(Shared.Config.Economy)

local LIVE_TOPIC = "AbyssSalvage_Live"
local AdminService = {}
local services
local auditStore, liveStore

function AdminService.Init(s)
	services = s
end

function AdminService.IsAdmin(player: Player): boolean
	if player.UserId == game.CreatorId and game.CreatorType == Enum.CreatorType.User then
		return true
	end
	if table.find(Economy.AdminUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		if ok and rank >= 254 then
			return true
		end
	end
	return false
end

local function audit(player: Player, command: string)
	print(`[Admin] {player.Name}: {command}`)
	if auditStore then
		task.spawn(function()
			pcall(auditStore.SetAsync, auditStore, `{os.time()}_{player.UserId}`, { cmd = command, user = player.UserId })
		end)
	end
end

-- Deep-merge LiveConfig overrides into the shared Economy config table
local function merge(target, source)
	for k, v in source do
		if typeof(v) == "table" and typeof(target[k]) == "table" and #v == 0 then
			merge(target[k], v)
		else
			target[k] = v
		end
	end
end

function AdminService.ReloadLiveConfig()
	if not liveStore then
		return
	end
	local ok, config = pcall(liveStore.GetAsync, liveStore, "LiveConfig")
	if ok and typeof(config) == "table" then
		if config.Codes then
			services.CodesService.SetLiveCodes(config.Codes)
			config.Codes = nil
		end
		merge(Economy, config)
		print("[Admin] LiveConfig applied")
	end
end

local function findPlayer(name: string): Player?
	name = name:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #name) == name or p.DisplayName:lower():sub(1, #name) == name then
			return p
		end
	end
	return nil
end

local COMMANDS = {}

COMMANDS.coins = function(player, args)
	local n = tonumber(args[1])
	if n then
		services.CurrencyService.AddCoins(player, n, "Admin")
	end
end
COMMANDS.pearls = function(player, args)
	local n = tonumber(args[1])
	if n then
		services.CurrencyService.AddPearls(player, n, "Admin")
	end
end
COMMANDS.level = function(player, args)
	local data = services.DataService.GetData(player)
	local n = tonumber(args[1])
	if data and n then
		data.Level = math.max(1, math.floor(n))
		data.XP = 0
		services.DataService.Replicate(player, "Level", "XP")
	end
end
COMMANDS.suit = function(player, args)
	local data = services.DataService.GetData(player)
	local n = tonumber(args[1])
	if data and n then
		data.Suit = math.clamp(math.floor(n), 1, 5)
		services.DataService.Replicate(player, "Suit")
		services.UpgradeService.PushDerived(player)
		services.UpgradeService.ApplySuitVisual(player)
	end
end
COMMANDS.relic = function(player, args)
	services.InventoryService.GrantRandomRelic(player, args[1] or "Rare", "Admin")
end
COMMANDS.pass = function(player, args)
	if args[1] then
		services.MonetizationService.GrantPassKey(player, args[1])
	end
end
COMMANDS.product = function(player, args)
	if args[1] then
		local ok = services.MonetizationService.SimulateProduct(player, args[1])
		Net.Notify:FireClient(player, `Simulated {args[1]}: {ok}`, "info")
	end
end
COMMANDS.event = function(_, args)
	local minutes = tonumber(args[2]) or 10
	services.EventService.StartAdminEvent(args[1] or "", minutes * 60)
end
COMMANDS.luck = function(player, args)
	services.EventService.StartServerBoost("Luck", tonumber(args[1]) or 2, (tonumber(args[2]) or 15) * 60, player)
	services.AnnouncementService.Server("ADMIN ABUSE: Server luck boost!", "Mythic")
end
COMMANDS.raids = function(_, args)
	Economy.Raid.Enabled = args[1] ~= "off"
end
COMMANDS.live = function(_, args)
	if args[1] == "reload" then
		AdminService.ReloadLiveConfig()
		pcall(MessagingService.PublishAsync, MessagingService, LIVE_TOPIC, "reload")
	end
end
COMMANDS.kick = function(_, args)
	local target = args[1] and findPlayer(args[1])
	if target then
		target:Kick("Removed by a moderator.")
	end
end
COMMANDS.ban = function(player, args)
	local userId = tonumber(args[1])
	local hours = tonumber(args[2]) or 24
	if not userId then
		return
	end
	local reason = table.concat(args, " ", 3)
	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			Duration = math.floor(hours * 3600),
			DisplayReason = "Exploiting",
			PrivateReason = reason ~= "" and reason or ("Banned by " .. player.Name),
			ExcludeAltAccounts = false,
			ApplyToUniverse = true,
		})
	end)
	Net.Notify:FireClient(player, if ok then `Banned {userId} for {hours}h` else `Ban failed: {err}`, "info")
end

local function onChatted(player: Player, message: string)
	if message:sub(1, 4):lower() ~= "/as " or not AdminService.IsAdmin(player) then
		return
	end
	local args = string.split(message:sub(5), " ")
	local cmd = table.remove(args, 1)
	local fn = cmd and COMMANDS[cmd:lower()]
	if fn then
		audit(player, message)
		local ok, err = pcall(fn, player, args)
		if not ok then
			Net.Notify:FireClient(player, "Command error: " .. tostring(err), "error")
		end
	end
end

function AdminService.Start()
	pcall(function()
		auditStore = DataStoreService:GetDataStore("AbyssSalvage_Audit")
		liveStore = DataStoreService:GetDataStore("AbyssSalvage_Live")
	end)
	task.spawn(AdminService.ReloadLiveConfig)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(LIVE_TOPIC, function()
				AdminService.ReloadLiveConfig()
			end)
		end)
	end)
	local function hook(player: Player)
		player.Chatted:Connect(function(msg)
			onChatted(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return AdminService
