-- SecurityService (Master Plan §23): movement sanity checks, text filtering helper, and
-- exploit flag logging. Remote rate limits and argument checks live with each handler.
--
-- "Treat the client as a keyboard and a monitor. It only asks; the server decides."

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Upgrades = require(Shared.Config.Upgrades)

local CHECK_INTERVAL = 1
local TOLERANCE = 1.5 -- flag anything faster than 1.5x the expected max (§23)
local FLAGS_BEFORE_KICK = 8

local SecurityService = {}
local services
local lastPos: { [Player]: Vector3 } = {}
local flags: { [Player]: number } = {}
local allowedTeleport: { [Player]: number } = {}

function SecurityService.Init(s)
	services = s
end

-- Services that legitimately teleport a character call this first
function SecurityService.AllowTeleport(player: Player)
	allowedTeleport[player] = os.clock() + 2
end

-- Filters text for display to everyone (dock names). Returns nil if filtering fails.
function SecurityService.FilterForBroadcast(player: Player, text: string): string?
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if ok and typeof(result) == "string" and result ~= "" then
		return result
	end
	return nil
end

local function expectedMax(player: Player): number
	local data = services.DataService.GetData(player)
	if not data then
		return 100
	end
	local swim = Formulas.SwimSpeed(data, services.MonetizationService.OwnedSet(player)) * Upgrades.Base.BoostMult
	return math.max(swim, 32) + 20 -- walking/jumping/falling headroom
end

function SecurityService.Start()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local pos = hrp.Position
					local prev = lastPos[player]
					lastPos[player] = pos
					if prev and (allowedTeleport[player] or 0) < os.clock() then
						-- Horizontal speed only: falling into the ocean from a dock is legit
						local flat = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z).Magnitude / CHECK_INTERVAL
						local vertical = math.abs(pos.Y - prev.Y) / CHECK_INTERVAL
						local limit = expectedMax(player) * TOLERANCE
						if flat > limit or (pos.Y < 0 and vertical > limit * 2) then
							flags[player] = (flags[player] or 0) + 1
							warn(`[Security] {player.Name} moved {math.floor(flat)} studs/s (limit {math.floor(limit)})`)
							if flags[player] >= FLAGS_BEFORE_KICK then
								services.AnalyticsService.Custom(player, "ExploitKick", flags[player])
								player:Kick("Unexpected movement detected.")
							end
						else
							flags[player] = math.max(0, (flags[player] or 0) - 0.25)
						end
					end
				end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			lastPos[p] = nil
			allowedTeleport[p] = os.clock() + 5
		end)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastPos[p] = nil
		flags[p] = nil
		allowedTeleport[p] = nil
	end)
end

return SecurityService
