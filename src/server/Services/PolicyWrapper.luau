-- PolicyWrapper (Master Plan §16, §22.4): PolicyService lookups, cached per player.
-- Fails CLOSED: if the lookup errors, paid random items are treated as restricted.

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")

local PolicyWrapper = {}
local cache: { [Player]: any } = {}

local function fetch(player: Player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if ok and info then
		cache[player] = info
	end
	return cache[player]
end

function PolicyWrapper.CanBuyRandomItems(player: Player): boolean
	local info = cache[player] or fetch(player)
	if not info then
		return false
	end
	return not info.ArePaidRandomItemsRestricted
end

function PolicyWrapper.IsSubjectToChinaPolicies(player: Player): boolean
	local info = cache[player] or fetch(player)
	return info ~= nil and info.IsSubjectToChinaPolicies == true
end

function PolicyWrapper.Start()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(fetch, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(fetch, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		cache[p] = nil
	end)
end

return PolicyWrapper
