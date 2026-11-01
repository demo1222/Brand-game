-- Builds every relic model with Lune's real Roblox datatypes and Instance API, so a typo in a
-- RelicArt recipe (bad property, material or enum name) fails here instead of in Studio.
--   lune run tools/relic_art_check            -> build check only
--   lune run tools/relic_art_check out.json   -> also dump part lists (for preview renders)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Instance = roblox.Instance,
	Enum = roblox.Enum,
}, { __index = _G })

local function loadModule(path: string)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end

local RelicArt = loadModule("src/shared/RelicArt.luau")
local Relics = loadModule("src/shared/Config/Relics.luau")
local Mutations = loadModule("src/shared/Config/Mutations.luau")

local out, errors, built = {}, 0, 0

local function dump(model, label: string)
	local parts = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Root" then
			local cf = p.CFrame
			local rx, ry, rz = cf:ToEulerAnglesXYZ()
			local kind = p.ClassName
			if kind == "Part" then
				kind = if p:FindFirstChildOfClass("SpecialMesh") then "Ellip" else p.Shape.Name
			end
			table.insert(parts, {
				k = kind,
				s = { p.Size.X, p.Size.Y, p.Size.Z },
				p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
				r = { rx, ry, rz },
				c = { p.Color.R, p.Color.G, p.Color.B },
				m = p.Material.Name,
				t = p.Transparency,
			})
		end
	end
	table.insert(out, { id = label, parts = parts })
end

local function try(label: string, fn, ...)
	local ok, res = pcall(fn, ...)
	if ok then
		built += 1
		return res
	end
	errors += 1
	print(`FAIL {label}: {res}`)
	return nil
end

for _, def in Relics.List do
	local m = try(def.Id, RelicArt.Build, def, { forViewport = true, light = false })
	if m then
		dump(m, `{def.Id} {def.Name}`)
	end
	-- World variant (point light, size scaling)
	try(def.Id .. " world", RelicArt.Build, def, { size = 1.4 })
end
for _, mut in Mutations.List do
	for _, vp in { true, false } do
		try(`mutation {mut.Id} vp={vp}`, RelicArt.Build, Relics.ById.R032, {
			mutations = { mut.Id },
			mutationDefs = Mutations.ById,
			forViewport = vp,
		})
	end
end

print(`{built} models built, {errors} failed`)
local outPath = (process.args :: { string })[1]
if outPath then
	fs.writeFile(outPath, serde.encode("json", out))
	print(`wrote {outPath}`)
end
if errors > 0 then
	process.exit(1)
end
