-- TradeService (Master Plan §14, §23): two-sided trade window, both confirm, 5s countdown,
-- server-side re-validation and an atomic swap (relic UIDs are moved, never copied).
-- Only Storage relics can be traded (not the dive bag, not displayed, not locked).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Economy = require(Shared.Config.Economy)
local Relics = require(Shared.Config.Relics)

local MAX_ITEMS = 8
local TradeService = {}
local services
local limiter = RateLimiter.new(8, 3)
local sessions: { [Player]: any } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> {from -> clock}

function TradeService.Init(s)
	services = s
end

local function partnerOf(session, player: Player): Player
	return if session.a == player then session.b else session.a
end

local function relicsFor(player: Player, uids: { string })
	local data = services.DataService.GetData(player)
	local out = {}
	for _, uid in uids do
		for _, r in data.Storage do
			if r.uid == uid then
				table.insert(out, r)
			end
		end
	end
	return out
end

local function push(session)
	for _, p in { session.a, session.b } do
		local partner = partnerOf(session, p)
		Net.TradeUpdated:FireClient(p, {
			Kind = "Session",
			Partner = partner.DisplayName,
			MyOffer = relicsFor(p, session.offers[p]),
			TheirOffer = relicsFor(partner, session.offers[partner]),
			MyConfirm = session.confirmed[p] == true,
			TheirConfirm = session.confirmed[partner] == true,
			Countdown = if session.countdownEnd then math.max(0, session.countdownEnd - os.clock()) else nil,
		})
	end
end

local function close(session, reason: string)
	for _, p in { session.a, session.b } do
		if sessions[p] == session then
			sessions[p] = nil
			if p.Parent then
				Net.TradeUpdated:FireClient(p, { Kind = "Closed", Reason = reason })
			end
		end
	end
	session.closed = true
end

local function validOffer(player: Player, uids: { string }): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local seen = {}
	for _, uid in uids do
		if seen[uid] then
			return false
		end
		seen[uid] = true
		local found = false
		for _, r in data.Storage do
			if r.uid == uid and not r.locked then
				found = true
			end
		end
		if not found then
			return false
		end
	end
	return true
end

local function execute(session)
	local a, b = session.a, session.b
	if not (validOffer(a, session.offers[a]) and validOffer(b, session.offers[b])) then
		close(session, "Trade items changed — cancelled.")
		return
	end
	local da, db = services.DataService.GetData(a), services.DataService.GetData(b)
	-- Take from both first, then give (same server step, no yields)
	local fromA, fromB = {}, {}
	for _, uid in session.offers[a] do
		table.insert(fromA, (services.InventoryService.Take(da, uid)))
	end
	for _, uid in session.offers[b] do
		table.insert(fromB, (services.InventoryService.Take(db, uid)))
	end
	for _, r in fromA do
		table.insert(db.Storage, r)
		services.InventoryService.RecordCodex(b, r)
	end
	for _, r in fromB do
		table.insert(da.Storage, r)
		services.InventoryService.RecordCodex(a, r)
	end
	local stamp = os.time()
	local function log(data, partner: Player, gave, got)
		data.TradeLog = data.TradeLog or {}
		local names = function(list)
			local n = {}
			for _, r in list do
				table.insert(n, Relics.ById[r.id].Name)
			end
			return table.concat(n, ", ")
		end
		table.insert(data.TradeLog, { t = stamp, with = partner.UserId, gave = names(gave), got = names(got) })
		while #data.TradeLog > 20 do
			table.remove(data.TradeLog, 1)
		end
	end
	log(da, b, fromA, fromB)
	log(db, a, fromB, fromA)
	services.DataService.Replicate(a, "Storage", "TradeLog")
	services.DataService.Replicate(b, "Storage", "TradeLog")
	services.AnalyticsService.Custom(a, "TradeCompleted", #fromA + #fromB)
	services.AnalyticsService.Custom(b, "TradeCompleted", #fromA + #fromB)
	close(session, "Trade complete!")
	-- Save both right away so a crash can't roll back one side only
	task.spawn(services.DataService.SaveNow, a)
	task.spawn(services.DataService.SaveNow, b)
end

local function canTrade(player: Player): (boolean, string?)
	local data = services.DataService.GetData(player)
	if not data then
		return false, "Loading"
	end
	if data.Level < Economy.Social.TradeMinLevel then
		return false, `Trading unlocks at level {Economy.Social.TradeMinLevel}`
	end
	if services.RaidService.IsCarrying(player) then
		return false, "Busy"
	end
	return true, nil
end

function TradeService.Start()
	Net.TradeRequest.OnServerEvent:Connect(function(player, targetUserId)
		if not limiter:Check(player) or typeof(targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or target == player or sessions[player] or sessions[target] then
			return
		end
		local ok, why = canTrade(player)
		if not ok then
			return Net.Notify:FireClient(player, why, "error")
		end
		ok, why = canTrade(target)
		if not ok then
			return Net.Notify:FireClient(player, `{target.DisplayName} can't trade yet.`, "error")
		end
		invites[target] = invites[target] or {}
		invites[target][player] = os.clock()
		Net.TradeUpdated:FireClient(target, { Kind = "Invite", From = player.DisplayName, FromUserId = player.UserId })
		Net.Notify:FireClient(player, `Trade request sent to {target.DisplayName}`, "info")
	end)

	Net.TradeRespond.OnServerEvent:Connect(function(player, fromUserId, accept)
		if not limiter:Check(player) or typeof(fromUserId) ~= "number" then
			return
		end
		local from = Players:GetPlayerByUserId(fromUserId)
		local inv = invites[player]
		if not from or not inv or not inv[from] or os.clock() - inv[from] > 60 then
			return
		end
		inv[from] = nil
		if accept ~= true then
			return Net.Notify:FireClient(from, `{player.DisplayName} declined the trade.`, "info")
		end
		if sessions[player] or sessions[from] then
			return
		end
		local session = { a = from, b = player, offers = { [from] = {}, [player] = {} }, confirmed = {}, countdownEnd = nil }
		sessions[from] = session
		sessions[player] = session
		push(session)
	end)

	Net.TradeSetOffer.OnServerEvent:Connect(function(player, uids)
		local session = sessions[player]
		if not session or not limiter:Check(player) or typeof(uids) ~= "table" then
			return
		end
		local clean = {}
		for i, uid in uids do
			if typeof(uid) == "string" and i <= MAX_ITEMS then
				table.insert(clean, uid)
			end
		end
		if not validOffer(player, clean) then
			return
		end
		session.offers[player] = clean
		session.confirmed = {}
		session.countdownEnd = nil
		push(session)
	end)

	Net.TradeConfirm.OnServerEvent:Connect(function(player)
		local session = sessions[player]
		if not session or not limiter:Check(player) then
			return
		end
		session.confirmed[player] = true
		if session.confirmed[session.a] and session.confirmed[session.b] then
			local token = {}
			session.token = token
			session.countdownEnd = os.clock() + Economy.Social.TradeCountdown
			push(session)
			task.delay(Economy.Social.TradeCountdown, function()
				if not session.closed and session.token == token and session.confirmed[session.a] and session.confirmed[session.b] then
					execute(session)
				end
			end)
		else
			push(session)
		end
	end)

	Net.TradeCancel.OnServerEvent:Connect(function(player)
		local session = sessions[player]
		if session then
			close(session, `{player.DisplayName} cancelled the trade.`)
		end
	end)

	services.DataService.OnRelease(function(player)
		local session = sessions[player]
		if session then
			close(session, "Partner left.")
		end
		invites[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return TradeService
