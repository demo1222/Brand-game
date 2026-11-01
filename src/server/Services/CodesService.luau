-- CodesService (Master Plan §27.1): redeemable promo codes, once per player.
-- Codes live in Config/Economy.Codes and can be added live through LiveConfig (AdminService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local RateLimiter = require(Shared.RateLimiter)
local Economy = require(Shared.Config.Economy)

local CodesService = {}
local services
local limiter = RateLimiter.new(3, 0.2)
local liveCodes = {}

function CodesService.Init(s)
	services = s
end

function CodesService.SetLiveCodes(codes)
	liveCodes = if typeof(codes) == "table" then codes else {}
end

function CodesService.Start()
	Net.RequestRedeemCode.OnServerEvent:Connect(function(player, code)
		if not limiter:Check(player) then
			return Net.Notify:FireClient(player, "Slow down!", "error")
		end
		if typeof(code) ~= "string" or #code > 32 then
			return
		end
		code = code:upper():gsub("%s", "")
		local reward = liveCodes[code] or Economy.Codes[code]
		local data = services.DataService.GetData(player)
		if not reward or not data then
			return Net.Notify:FireClient(player, "Invalid code.", "error")
		end
		if data.RedeemedCodes[code] then
			return Net.Notify:FireClient(player, "Code already redeemed.", "error")
		end
		data.RedeemedCodes[code] = true
		local lines = services.CurrencyService.GrantReward(player, reward, "Code")
		services.DataService.Replicate(player, "RedeemedCodes")
		services.AnalyticsService.Custom(player, "CodeRedeemed", 1, { CustomField01 = code })
		Net.Notify:FireClient(player, `Code redeemed: {table.concat(lines, ", ")}`, "reward")
	end)
	Players.PlayerRemoving:Connect(function(p)
		limiter:Remove(p)
	end)
end

return CodesService
