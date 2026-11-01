-- LightingController (Master Plan §19.1): depth-based atmosphere, tweened on the client only.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)

local LightingController = {}
local controllers
local cc: ColorCorrectionEffect
local bloom: BloomEffect
local surface = {
	FogColor = Color3.fromRGB(190, 220, 240),
	FogEnd = 2500,
	Ambient = Color3.fromRGB(130, 130, 140),
	Brightness = 2,
}

function LightingController.Init(c)
	controllers = c
end

local function lerpZone(depth: number)
	local zone = Zones.ForDepth(depth)
	if not zone then
		return surface.FogColor, surface.FogEnd, surface.Ambient, surface.Brightness
	end
	-- blend toward the next zone as you approach its boundary
	local nextZone = Zones.List[zone.Index + 1]
	local t = (depth - zone.MinDepth) / (zone.MaxDepth - zone.MinDepth)
	local fogColor, fogEnd, ambient = zone.FogColor, zone.FogEnd, zone.Ambient
	if nextZone and t > 0.7 then
		local a = (t - 0.7) / 0.3
		fogColor = fogColor:Lerp(nextZone.FogColor, a)
		fogEnd = fogEnd + (nextZone.FogEnd - fogEnd) * a
		ambient = ambient:Lerp(nextZone.Ambient, a)
	end
	local brightness = math.clamp(2 - depth / 600, 0.05, 2)
	return fogColor, fogEnd, ambient, brightness
end

function LightingController.Start()
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DepthCC"
	cc.Parent = Lighting
	bloom = Instance.new("BloomEffect")
	bloom.Name = "DepthBloom"
	bloom.Intensity = 0.6
	bloom.Threshold = 1.2
	bloom.Size = 30
	bloom.Parent = Lighting
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Parent = Lighting

	RunService.RenderStepped:Connect(function(dt)
		local depth = controllers.SwimController.Depth
		local fogColor, fogEnd, ambient, brightness = lerpZone(depth)
		local a = math.clamp(dt * 3, 0, 1)
		Lighting.FogColor = Lighting.FogColor:Lerp(fogColor, a)
		Lighting.FogEnd = Lighting.FogEnd + (fogEnd - Lighting.FogEnd) * a
		Lighting.FogStart = if depth > 0 then 0 else 200
		Lighting.Ambient = Lighting.Ambient:Lerp(ambient, a)
		Lighting.OutdoorAmbient = Lighting.Ambient
		Lighting.Brightness = Lighting.Brightness + (brightness - Lighting.Brightness) * a
		atmosphere.Density = if depth > 0 then 0.6 else 0.3
		atmosphere.Color = Lighting.FogColor
		cc.TintColor = if depth > 0 then Color3.new(1, 1, 1):Lerp(fogColor, 0.35) else Color3.new(1, 1, 1)
		cc.Saturation = if depth > 400 then -0.2 else 0.1
		-- emissive rare items pop in the dark (bloom stronger at depth)
		bloom.Intensity = if depth > 400 then 1.2 else 0.5
	end)
end

return LightingController
