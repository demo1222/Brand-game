-- Renders every UI/Icon spec into tools/preview/out/icons.html (divs that mimic the Frames,
-- UICorner and outside-drawn UIStroke the game uses) to check icon geometry.
local fs = require("@lune/fs")
if not fs.isDir("tools/preview/out") then
	fs.writeDir("tools/preview/out")
end
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local env = { Color3 = roblox.Color3, Vector2 = roblox.Vector2, UDim2 = roblox.UDim2, UDim = roblox.UDim, Instance = roblox.Instance }
setmetatable(env, { __index = _G })
local Icon = luau.load(fs.readFile("src/client/UI/Icon.luau"), { debugName = "Icon", environment = env })()
local names = {}
for n in Icon.Specs do table.insert(names, n) end
table.sort(names)
local html = { '<!doctype html><html><body style="margin:0;background:#0D1A2C;font-family:sans-serif;color:#EAF4FF"><div style="display:flex;flex-wrap:wrap;gap:10px;padding:12px;width:1180px">' }
local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local bad = 0
for _, n in names do
	local ok, holder = pcall(Icon.new, n, 48, roblox.Color3.fromRGB(63, 214, 230))
	if not ok then bad += 1; print("FAIL", n, holder) continue end
	table.insert(html, '<div style="width:96px;height:84px;background:#16263D;border-radius:10px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:4px"><div style="position:relative;width:48px;height:48px">')
	for _, f in holder:GetChildren() do
		local x, y = f.Position.X.Offset, f.Position.Y.Offset
		local w, h = f.Size.X.Offset, f.Size.Y.Offset
		local corner = f:FindFirstChildOfClass("UICorner")
		local radius = "0"
		if corner then radius = if corner.CornerRadius.Scale > 0 then "50%" else corner.CornerRadius.Offset .. "px" end
		local stroke = f:FindFirstChildOfClass("UIStroke")
		local bg = if f.BackgroundTransparency >= 1 then "transparent" else hex(f.BackgroundColor3)
		local shadow = if stroke then string.format("box-shadow:0 0 0 %.2fpx %s;", stroke.Thickness, hex(stroke.Color)) else ""
		table.insert(html, string.format('<div style="position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;background:%s;border-radius:%s;%stransform:rotate(%.2fdeg)"></div>', x - w / 2, y - h / 2, w, h, bg, radius, shadow, f.Rotation))
	end
	table.insert(html, '</div><span style="font-size:11px">' .. n .. '</span></div>')
end
table.insert(html, "</div></body></html>")
fs.writeFile("tools/preview/out/icons.html", table.concat(html))
print(#names, "icons,", bad, "failures")
