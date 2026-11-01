-- SocialService (Master Plan §14): friend boost, group perk, Dive Parties (shared sonar,
-- +10% luck per member) and invite rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Economy = require(Shared.Config.Economy)

local S = Economy.Social
local SocialService = {}
local services
local limiter = RateLimiter.new(5, 1)
local friendCache: { [Player]: { [number]: boolean } } = {}
local inGroup: { [Player]: boolean } = {}
local parties: { [Player]: { Player } } = {} -- member -> shared member list
local partyInvites: { [Player]: { from: Player, t: number } } = {}

function SocialService.Init(s)
	services = s
end

local function isFriend(a: Player, b: Player): boolean
	local cache = friendCache[a]
	if not cache then
		cache = {}
		friendCache[a] = cache
	end
	if cache[b.UserId] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		cache[b.UserId] = ok and result == true
	end
	return cache[b.UserId]
end

function SocialService.FriendCount(player: Player): number
	local n = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and isFriend(player, other) then
			n += 1
		end
	end
	return n
end

function SocialService.GetCoinMultiplier(player: Player): number
	local friendBonus = math.min(SocialService.FriendCount(player) * S.FriendBoostPer, S.FriendBoostMax)
	local group = if inGroup[player] then S.GroupBonus else 0
	return 1 + friendBonus + group
end

function SocialService.GetParty(player: Player): { Player }?
	return parties[player]
end

function SocialService.GetPartyLuck(player: Player): number
	local party = parties[player]
	if not party then
		return 1
	end
	return 1 + (#party - 1) * S.PartyLuckPer
end

local function pushParty(list: { Player })
	local names = {}
	for _, p in list do
		table.insert(names, { Name = p.DisplayName, UserId = p.UserId })
	end
	for _, p in list do
		Net.PartyUpdated:FireClient(p, { Members = names })
	end
end

local function leaveParty(player: Player)
	local party = parties[player]
	if not party then
		return
	end
	parties[player] = nil
	local i = table.find(party, player)
	if i then
		table.remove(party, i)
	end
	if player.Parent then
		Net.PartyUpdated:FireClient(player, { Members = {} })
	end
	if #party <= 1 then
		for _, p in party do
			parties[p] = nil
			Net.PartyUpdated:FireClient(p, { Members = {} })
		end
	else
		pushParty(party)
	end
end

function SocialService.Start()
	services.DataService.ProfileLoaded:Connect(function(player, profile)
		if S.GroupId ~= 0 then
			local ok, result = pcall(player.IsInGroup, player, S.GroupId)
			inGroup[player] = ok and result == true
		end
		-- Invite reward (§14): referred players earn Pearls for both after 10 minutes
		local okJoin, joinData = pcall(player.GetJoinData, player)
		local referrer = okJoin and joinData and joinData.ReferredByPlayerId
		if referrer and referrer ~= 0 and not profile.Data.Flags.InviteRewarded then
			task.delay(600, function()
				if not player.Parent or profile.Data.Flags.InviteRewarded then
					return
				end
				profile.Data.Flags.InviteRewarded = true
				services.CurrencyService.AddPearls(player, 25, "InviteReward")
				Net.Notify:FireClient(player, "Thanks for joining a friend! +25 Pearls", "reward")
				local inviter = Players:GetPlayerByUserId(referrer)
				if inviter then
					services.CurrencyService.AddPearls(inviter, 25, "InviteReward")
					Net.Notify:FireClient(inviter, `{player.DisplayName} played 10 minutes! +25 Pearls`, "reward")
				end
			end)
		end
		-- Friend joined notice
		for _, other in Players:GetPlayers() do
			if other ~= player and isFriend(other, player) then
				Net.Notify:FireClient(other, `Your friend {player.DisplayName} joined! +{math.floor(S.FriendBoostPer * 100)}% Coins`, "info")
				services.AnalyticsService.Custom(other, "FriendJoined", 1)
			end
		end
	end)

	Net.PartyInvite.OnServerEvent:Connect(function(player, targetUserId)
		if not limiter:Check(player) or typeof(targetUserId) ~= "number" then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or target == player or parties[target] then
			return
		end
		local party = parties[player]
		if party and #party >= S.PartyMax then
			return Net.Notify:FireClient(player, "Your party is full.", "error")
		end
		partyInvites[target] = { from = player, t = os.clock() }
		Net.PartyUpdated:FireClient(target, { Invite = player.DisplayName, FromUserId = player.UserId })
	end)

	Net.PartyRespond.OnServerEvent:Connect(function(player, accept)
		local inv = partyInvites[player]
		partyInvites[player] = nil
		if not inv or os.clock() - inv.t > 60 or accept ~= true or not inv.from.Parent then
			return
		end
		if parties[player] then
			leaveParty(player)
		end
		local party = parties[inv.from]
		if not party then
			party = { inv.from }
			parties[inv.from] = party
		end
		if #party >= S.PartyMax then
			return
		end
		table.insert(party, player)
		parties[player] = party
		pushParty(party)
		services.AnalyticsService.Custom(player, "PartyFormed", #party)
	end)

	Net.PartyLeave.OnServerEvent:Connect(leaveParty)

	Players.PlayerRemoving:Connect(function(p)
		leaveParty(p)
		friendCache[p] = nil
		inGroup[p] = nil
		partyInvites[p] = nil
		limiter:Remove(p)
		for _, cache in friendCache do
			cache[p.UserId] = nil
		end
	end)
end

return SocialService
