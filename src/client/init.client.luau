-- Client boot (Master Plan §20.2): loads controllers, then tells the server the UI is ready.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

ReplicatedStorage:WaitForChild("Remotes") -- server creates every remote before parenting this
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local ORDER = {
	"State",
	"UIController",
	"SwimController",
	"LightingController",
	"AudioController",
	"PromptController",
	"HUDController",
	"SonarController",
	"RevealController",
	"ShopController",
	"MenuController",
	"OfferController",
	"TutorialController",
}

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(script.Controllers:WaitForChild(name))
end
for _, name in ORDER do
	local c = controllers[name]
	if c.Init then
		local ok, err = pcall(c.Init, controllers)
		if not ok then
			warn(`[Client] {name}.Init failed: {err}`)
		end
	end
end
for _, name in ORDER do
	local c = controllers[name]
	if c.Start then
		task.spawn(function()
			local ok, err = pcall(c.Start)
			if not ok then
				warn(`[Client] {name}.Start failed: {err}`)
			end
		end)
	end
end

Net.ClientReady:FireServer()
