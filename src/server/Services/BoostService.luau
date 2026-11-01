-- BoostService: timed personal boosts stored as expiry timestamps (os.time) in the profile,
-- so they survive rejoining (Master Plan §15.3 potions, §17 free luck potion).

local BoostService = {}
local services

function BoostService.Init(s)
	services = s
end

function BoostService.Active(player: Player, id: string): boolean
	local data = services.DataService.GetData(player)
	return data ~= nil and (data.ActiveBoosts[id] or 0) > os.time()
end

function BoostService.Remaining(player: Player, id: string): number
	local data = services.DataService.GetData(player)
	if not data then
		return 0
	end
	return math.max(0, (data.ActiveBoosts[id] or 0) - os.time())
end

-- Stacks duration on top of any remaining time.
function BoostService.Add(player: Player, id: string, seconds: number): boolean
	local data = services.DataService.GetData(player)
	if not data then
		return false
	end
	local now = os.time()
	data.ActiveBoosts[id] = math.max(data.ActiveBoosts[id] or 0, now) + seconds
	services.DataService.Replicate(player, "ActiveBoosts")
	return true
end

function BoostService.Start()
	-- Clean up expired entries occasionally so the profile doesn't grow
	task.spawn(function()
		while true do
			task.wait(60)
			local now = os.time()
			for player, profile in services.DataService.All() do
				local changed = false
				for id, t in profile.Data.ActiveBoosts do
					if t <= now then
						profile.Data.ActiveBoosts[id] = nil
						changed = true
					end
				end
				if changed then
					services.DataService.Replicate(player, "ActiveBoosts")
				end
			end
		end
	end)
end

return BoostService
