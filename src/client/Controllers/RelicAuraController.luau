-- RelicAuraController: animates the Spin_ and Aura_ parts of relics shown in the world (dock
-- stands, the thief's carried relic). The server builds and tags them (RelicAura.Decorate);
-- each client moves the parts locally, only for relics near the camera.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RelicAura = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RelicAura"))

local RelicAuraController = {}

local RANGE = 160 -- studs from the camera
local tracked: { [Model]: boolean } = {}

local function add(inst: Instance)
	if inst:IsA("Model") then
		tracked[inst] = true
	end
end

function RelicAuraController.Start()
	for _, m in CollectionService:GetTagged(RelicAura.Tag) do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal(RelicAura.Tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(RelicAura.Tag):Connect(function(inst)
		tracked[inst :: Model] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		local t = os.clock()
		for model in tracked do
			if model.Parent == nil then
				tracked[model] = nil
			else
				-- PrimaryPart can replicate a moment after the model: wait for it, don't drop it
				local root = model.PrimaryPart
				if root and (root.Position - camPos).Magnitude < RANGE then
					RelicAura.Animate(model, t)
				end
			end
		end
	end)
end

return RelicAuraController
