-- Dresses a test R15 rig in every suit tier (shared/SuitArt), checks the visibility toggles
-- restore the outfit, and dumps parts to tools/preview/out/suits.json.
local fs = require("@lune/fs")
if not fs.isDir("tools/preview/out") then
	fs.writeDir("tools/preview/out")
end
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local env = { Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Instance = roblox.Instance, Enum = roblox.Enum, typeof = roblox.typeof or typeof }
setmetatable(env, { __index = _G })
local SuitArt = luau.load(fs.readFile("src/shared/SuitArt.luau"), { debugName = "SuitArt", environment = env })()
local I, V, C = roblox.Instance, roblox.Vector3, roblox.CFrame
-- Minimal R15-like rig (sizes from the default R15 blocky rig)
local function rig()
	local char = I.new("Model")
	local function part(name, size, pos)
		local p = I.new("Part"); p.Name = name; p.Size = size; p.CFrame = C.new(pos); p.Parent = char; return p
	end
	part("HumanoidRootPart", V.new(2, 2, 1), V.new(0, 3, 0))
	part("Head", V.new(1.2, 1.2, 1.2), V.new(0, 4.6, 0))
	part("UpperTorso", V.new(2, 1.6, 1), V.new(0, 3.4, 0))
	part("LowerTorso", V.new(2, 0.4, 1), V.new(0, 2.4, 0))
	for _, s in { "Left", "Right" } do
		local x = if s == "Left" then -1.5 else 1.5
		part(s .. "UpperArm", V.new(1, 1.2, 1), V.new(x, 3.6, 0))
		part(s .. "LowerArm", V.new(1, 1.1, 1), V.new(x, 2.5, 0))
		part(s .. "Hand", V.new(1, 0.3, 1), V.new(x, 1.8, 0))
		part(s .. "UpperLeg", V.new(1, 1.2, 1), V.new(x / 3, 1.6, 0))
		part(s .. "LowerLeg", V.new(1, 1.1, 1), V.new(x / 3, 0.6, 0))
		part(s .. "Foot", V.new(1, 0.3, 1), V.new(x / 3, -0.1, 0))
	end
	local shirt = I.new("Shirt"); shirt.Parent = char
	return char
end
local out = {}
local bad = 0
for tier = 1, 6 do
	local char = rig()
	local ok, err = pcall(SuitArt.Apply, char, tier, roblox.Color3.fromRGB(40, 90, 220), { SuitColors = true })
	if not ok then bad += 1; print("FAIL tier", tier, err) else
		local parts = {}
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				local rx, ry, rz = d.CFrame:ToEulerAnglesXYZ()
				local k = d.ClassName
				if k == "Part" then k = d.Shape.Name end
				table.insert(parts, { k = k, s = { d.Size.X, d.Size.Y, d.Size.Z }, p = { d.CFrame.Position.X, d.CFrame.Position.Y, d.CFrame.Position.Z }, r = { rx, ry, rz }, c = { d.Color.R, d.Color.G, d.Color.B }, m = d.Material.Name, t = d.Transparency })
			end
		end
		table.insert(out, { id = "Tier " .. tier, parts = parts })
		-- toggles off: suit pieces gone, outfit restored
		local ok2, err2 = pcall(SuitArt.Apply, char, tier, roblox.Color3.fromRGB(40, 90, 220), { SuitHelmet = false, SuitTank = false, SuitFins = false, SuitGear = false, SuitColors = false })
		local pieces = 0
		for _, d in char.DiverSuit:GetDescendants() do if d:IsA("BasePart") then pieces += 1 end end
		local shirtBack = char:FindFirstChildOfClass("Shirt") ~= nil
		if not ok2 or pieces > 0 or not shirtBack then bad += 1; print("FAIL toggles tier", tier, err2, pieces, shirtBack) end
	end
end
print(#out, "tiers built,", bad, "failures")
fs.writeFile("tools/preview/out/suits.json", serde.encode("json", out))
