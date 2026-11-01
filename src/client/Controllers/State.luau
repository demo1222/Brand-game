-- Client-side mirror of the player's profile + derived values, fed by StateUpdated.
-- Display only: the server is authoritative for everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local State = {}
State.Data = {}
State.Changed = Signal.new() -- (keysTable)

function State.Get(key: string)
	return State.Data[key]
end

function State.Derived(key: string)
	local d = State.Data.Derived
	return d and d[key]
end

function State.Owns(pass: string): boolean
	local passes = State.Data.Passes
	return passes ~= nil and passes[pass] == true
end

function State.Start()
	Net.StateUpdated.OnClientEvent:Connect(function(payload)
		local keys = {}
		for k, v in payload do
			State.Data[k] = v
			keys[k] = true
		end
		State.Changed:Fire(keys)
	end)
end

return State
