-- RelicMeshService: makes sure every Blender mesh in Config.RelicMeshes has a template in
-- ReplicatedStorage.RelicMeshes. Studio normally already holds them (saved with the place);
-- this only reloads missing ones from their asset IDs, so the place can be rebuilt from src.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local RelicMeshes = require(ReplicatedStorage.Shared.Config.RelicMeshes)

local RelicMeshService = {}

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("RelicMeshes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "RelicMeshes"
		f.Parent = ReplicatedStorage
	end
	return f
end

local function ensure(name: string, assetId: number?)
	local f = folder()
	if f:FindFirstChild(name) or not assetId then
		return
	end
	local ok, container = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok then
		warn(`[RelicMeshService] could not load {name} ({assetId}): {container}`)
		return
	end
	local model = container:FindFirstChildWhichIsA("Model")
	if not model then
		model = Instance.new("Model")
		for _, c in container:GetChildren() do
			c.Parent = model
		end
	end
	model.Name = name
	model.Parent = f
	container:Destroy()
end

-- Pull every model a bundle holds that the folder is still missing.
local function ensureFromBundle(assetId: number, missing: { [string]: boolean })
	local ok, container = pcall(InsertService.LoadAsset, InsertService, assetId)
	if not ok then
		warn(`[RelicMeshService] could not load bundle {assetId}: {container}`)
		return
	end
	local f = folder()
	for _, d in container:GetDescendants() do
		if d:IsA("Model") and missing[d.Name] and not f:FindFirstChild(d.Name) then
			missing[d.Name] = nil
			d.Parent = f
		end
	end
	container:Destroy()
end

-- World meshes (Config.WorldMeshes): guardians and reef props into ReplicatedStorage.WorldMeshes.
-- WorldService calls this before it builds the reef, so props can use the Blender models.
local worldLoaded = false
function RelicMeshService.EnsureWorldMeshes()
	if worldLoaded then
		return
	end
	worldLoaded = true
	local WorldMeshes = require(ReplicatedStorage.Shared.Config.WorldMeshes)
	local f = ReplicatedStorage:FindFirstChild("WorldMeshes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "WorldMeshes"
		f.Parent = ReplicatedStorage
	end
	local missing = {}
	for _, name in WorldMeshes.Names do
		if not f:FindFirstChild(name) then
			missing[name] = true
		end
	end
	for _, bundleId in WorldMeshes.Bundles do
		if not next(missing) then
			break
		end
		local ok, container = pcall(InsertService.LoadAsset, InsertService, bundleId)
		if not ok then
			warn(`[RelicMeshService] could not load world bundle {bundleId}: {container}`)
			continue
		end
		for _, d in container:GetDescendants() do
			if d:IsA("Model") and missing[d.Name] then
				missing[d.Name] = nil
				d.Parent = f
			end
		end
		container:Destroy()
	end
end

function RelicMeshService.Start()
	local f = folder()
	local missing = {}
	for id, entry in RelicMeshes.Relics do
		if entry.AssetId then
			ensure(id, entry.AssetId)
		elseif not f:FindFirstChild(id) then
			missing[id] = true
		end
	end
	for _, entry in RelicMeshes.Caches do
		if entry.AssetId then
			ensure(entry.Name, entry.AssetId)
		elseif not f:FindFirstChild(entry.Name) then
			missing[entry.Name] = true
		end
	end
	if next(missing) then
		for _, bundleId in RelicMeshes.Bundles or {} do
			ensureFromBundle(bundleId, missing)
			if not next(missing) then
				break
			end
		end
	end
end

return RelicMeshService
