-- AudioController (Master Plan §19.3): adaptive music layers and key SFX.
-- Asset IDs are left empty on purpose: use only Roblox-licensed or commissioned audio (§16).
-- Fill in the ids below; empty entries are skipped silently.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local SOUND_IDS = {
	ReefMusic = "", -- calm reef melody
	DeepDrone = "", -- deep ambient drone
	HuntLayer = "", -- percussion when the Leviathan hunts you
	Heartbeat = "", -- low oxygen
	Roar = "", -- Leviathan wind-up
	Reveal = "", -- rarity reveal (pitched per tier)
	Alarm = "", -- dock intruder bell
}

local AudioController = {}
local controllers
local sounds: { [string]: Sound } = {}
local huntUntil = 0

function AudioController.Init(c)
	controllers = c
end

local function make(name: string, looped: boolean): Sound?
	local id = SOUND_IDS[name]
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = looped
	s.Volume = 0
	s.Parent = SoundService
	sounds[name] = s
	if looped then
		s:Play()
	end
	return s
end

function AudioController.Play(name: string, pitch: number?)
	local s = sounds[name]
	if s then
		local settings = controllers.State.Get("Settings")
		s.Volume = (settings and settings.SFX or 0.8)
		s.PlaybackSpeed = pitch or 1
		s:Play()
	end
end

function AudioController.Start()
	for _, n in { "ReefMusic", "DeepDrone", "HuntLayer", "Heartbeat" } do
		make(n, true)
	end
	for _, n in { "Roar", "Reveal", "Alarm" } do
		make(n, false)
	end
	Net.PredatorHint.OnClientEvent:Connect(function(hint)
		if hint.State == "Hunt" or hint.State == "WindUp" or hint.State == "Lunge" then
			huntUntil = os.clock() + 4
		end
		if hint.State == "WindUp" then
			AudioController.Play("Roar")
		end
	end)
	Net.Intruder.OnClientEvent:Connect(function()
		AudioController.Play("Alarm")
	end)
	RunService.Heartbeat:Connect(function(dt)
		local settings = controllers.State.Get("Settings")
		local music = settings and settings.Music or 0.6
		local depth = controllers.SwimController.Depth
		local o2 = controllers.HUDController and controllers.HUDController.O2Fraction or 1
		local targets = {
			ReefMusic = if depth < 400 then music else 0,
			DeepDrone = if depth >= 300 then music else 0,
			HuntLayer = if huntUntil > os.clock() then music else 0,
			Heartbeat = if depth > 0 and o2 < 0.25 then 0.8 else 0,
		}
		for name, target in targets do
			local s = sounds[name]
			if s then
				s.Volume += (target - s.Volume) * math.clamp(dt * 2, 0, 1)
			end
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		huntUntil = 0
	end)
end

return AudioController
