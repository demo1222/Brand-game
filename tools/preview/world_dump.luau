-- Builds the runtime world (WorldService) with Lune's Roblox API and dumps every part to
-- tools/preview/out/world.json (render with: node tools/preview/render.js world ...).
-- Lune has no property-changed signals, so the build stops at the first plaza label; the
-- ocean (cliffs, spires, props, landmarks) is complete by then.
local fs = require("@lune/fs")
if not fs.isDir("tools/preview/out") then
	fs.writeDir("tools/preview/out")
end
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local game = roblox.Instance.new("DataModel")
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed)
	return setmetatable({ s = (seed or os.time()) % 2147483647 + 1 }, RandomShim)
end
function RandomShim:_n()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function RandomShim:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_n()
end
function RandomShim:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_n())
end
local cache = {}
local nodeMeta = {}
local function node(path, parent) return setmetatable({ __path = path, __parent = parent }, nodeMeta) end
local function scan(n)
	local dir = rawget(n, "__path"):gsub("%.luau$", "")
	if not fs.isDir(dir) then return end
	for _, name in fs.readDir(dir) do
		local child = dir .. "/" .. name
		if fs.isDir(child) then local c = node(child, n); rawset(n, name, c); scan(c)
		elseif name:match("%.luau$") then local k = name:gsub("%.luau$", ""); if rawget(n, k) == nil then local c = node(child, n); rawset(n, k, c); scan(c) end end
	end
end
nodeMeta.__index = function(self, key)
	if key == "Parent" then return rawget(self, "__parent") end
	if key == "WaitForChild" or key == "FindFirstChild" then return function(s, k) return rawget(s, k) end end
	error("no child " .. key .. " under " .. rawget(self, "__path"))
end
local src = node("src", nil); scan(src)
local RS = { Shared = src.shared }
function RS:WaitForChild(k) return self[k] end
local env
local function load(n)
	local p = rawget(n, "__path")
	if cache[p] ~= nil then return cache[p] end
	local e = { script = n }
	for k, v in env do e[k] = v end
	setmetatable(e, { __index = _G })
	local r = luau.load(fs.readFile(p), { debugName = p, environment = e })()
	cache[p] = r
	return r
end
local gameProxy = setmetatable({}, { __index = function(_, k)
	if k == "GetService" then
		return function(_, name)
			if name == "ReplicatedStorage" then return RS end
			return game:GetService(name)
		end
	end
	return game[k]
end })
env = setmetatable({
	game = gameProxy, workspace = game:GetService("Workspace"),
	Color3 = roblox.Color3, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Instance = roblox.Instance, Enum = roblox.Enum,
	UDim2 = roblox.UDim2, UDim = roblox.UDim, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange, Random = RandomShim,
	RaycastParams = roblox.RaycastParams,
	require = function(t) return load(t) end,
}, { __index = _G })
local WorldService = load(src.server.Services.WorldService)
WorldService.Init({})
local ok, err = pcall(WorldService.Start)
print("WorldService.Start:", ok, err)
local root = WorldService.Root()
local counts, parts = {}, {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		counts[d.Name] = (counts[d.Name] or 0) + 1
		local folderName = d:FindFirstAncestorWhichIsA("Folder") and d:FindFirstAncestorWhichIsA("Folder").Name or ""
		if folderName ~= "Docks" then
			local rx, ry, rz = d.CFrame:ToEulerAnglesXYZ()
			local k = d.ClassName
			if k == "Part" then k = if d:FindFirstChildOfClass("SpecialMesh") then "Ellip" else d.Shape.Name end
			table.insert(parts, { n = d.Name, k = k, t = d.Transparency, m = d.Material.Name, r = { rx, ry, rz }, p = { d.CFrame.Position.X, d.CFrame.Position.Y, d.CFrame.Position.Z }, s = { d.Size.X, d.Size.Y, d.Size.Z }, c = { d.Color.R, d.Color.G, d.Color.B } })
		end
	end
end
local total = 0
for _, c in counts do total += c end
print("parts:", total)
local names = {}
for k, v in counts do table.insert(names, k .. "=" .. v) end
table.sort(names); print(table.concat(names, " "))
local samples = {}
for z = 1, 5 do
	local p = WorldService.RandomPointInZone(z, RandomShim.new(z))
	table.insert(samples, string.format("z%d(%.0f,%.0f,%.0f)", z, p.X, p.Y, p.Z))
end
print("anchored spawn samples:", table.concat(samples, " "))
fs.writeFile("tools/preview/out/world.json", serde.encode("json", parts))
