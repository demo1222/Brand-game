-- PromptController: shows each player only the ProximityPrompts that make sense for them
-- (owners see Display/Take, others see Steal) and applies the player's own salvage hold time.
-- Purely cosmetic: the server validates every trigger regardless.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local PromptController = {}

local function myDock(model: Instance?): boolean
	return model ~= nil and model:GetAttribute("OwnerUserId") == player.UserId
end

local function applyStand(stand: BasePart)
	local dockModel = stand.Parent
	local visible = stand:GetAttribute("Visible") == true
	local hasRelic = stand:GetAttribute("HasRelic") == true
	local mine = myDock(dockModel)
	local place = stand:FindFirstChild("Place") :: ProximityPrompt?
	local steal = stand:FindFirstChild("Steal") :: ProximityPrompt?
	if place then
		place.Enabled = visible and mine
	end
	if steal then
		steal.Enabled = visible and hasRelic and not mine and dockModel:GetAttribute("OwnerUserId") ~= nil
	end
end

function PromptController.Start()
	local root = Workspace:WaitForChild("AbyssWorld", 30)
	if not root then
		return
	end
	local docks = root:WaitForChild("Docks")
	local nodes = root:WaitForChild("Nodes")

	nodes.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") and d.Name == "Salvage" then
			local secs = player.Character and player.Character:GetAttribute("SalvageSeconds")
			if secs then
				d.HoldDuration = secs
			end
		end
	end)

	while true do
		local secs = player.Character and player.Character:GetAttribute("SalvageSeconds")
		if secs then
			for _, d in nodes:GetDescendants() do
				if d:IsA("ProximityPrompt") and d.HoldDuration ~= secs then
					d.HoldDuration = secs
				end
			end
		end
		for _, dock in docks:GetChildren() do
			for _, part in dock:GetChildren() do
				if part:GetAttribute("StandIndex") or part:GetAttribute("VaultIndex") then
					applyStand(part)
				elseif part.Name == "GateButton" then
					local gp = part:FindFirstChild("GatePrompt") :: ProximityPrompt?
					if gp and not myDock(dock) then
						gp.Enabled = false
					end
				end
			end
		end
		task.wait(0.5)
	end
end

return PromptController
