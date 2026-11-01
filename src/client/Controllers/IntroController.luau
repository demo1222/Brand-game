-- IntroController (Master Plan §17 "opening camera flyover"): a short scripted camera tour for
-- brand-new players: harbour → dock ring → under the surface to the reef → back to the diver,
-- with the title card. Tap anywhere (or press any key) to skip. Runs once per new profile.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local World = require(Shared.Config.World)
local Kit = require(script.Parent.Parent.UI.Kit)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer
local IntroController = {}
local controllers

function IntroController.Init(c)
	controllers = c
end

local function isNewPlayer(): boolean
	local S = controllers.State
	local deadline = os.clock() + 15
	while S.Get("Stats") == nil and os.clock() < deadline do
		task.wait(0.25)
	end
	local stats = S.Get("Stats")
	return stats ~= nil and (stats.Dives or 0) == 0 and (S.Get("LifetimeCoins") or 0) == 0
end

local function play()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local surface = World.WaterSurfaceY
	local r = World.DockRingRadius
	local shots = {
		{ CFrame.lookAt(Vector3.new(0, surface + 160, r * 1.6), Vector3.new(0, surface, 0)), 0 },
		{ CFrame.lookAt(Vector3.new(r * 1.2, surface + 60, r * 0.4), Vector3.new(0, surface + 6, 0)), 2.6 },
		{
			CFrame.lookAt(Vector3.new(r * 0.9, surface + 6, -r * 0.5), Vector3.new(r * 0.5, surface - 60, -r * 0.9)),
			2.2,
		},
		{
			CFrame.lookAt(
				Vector3.new(r * 0.7, surface - 80, -r * 0.7),
				Vector3.new(World.OceanRadius, surface - 130, -World.OceanRadius * 0.6)
			),
			2.4,
		},
	}
	local overlay = controllers.UIController.Overlay
	local card = New("Frame", {
		Name = "Intro",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 60),
		Position = UDim2.fromOffset(0, -60),
		ZIndex = 50,
		Parent = overlay,
	})
	local titleGroup = New("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(600, 110),
		ZIndex = 51,
		Parent = card,
	}, { Kit.List(6, false, Enum.HorizontalAlignment.Center) })
	local title = Kit.Title({
		Text = "ABYSS SALVAGE",
		TextSize = 54,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.6,
		Size = UDim2.new(1, 0, 0, 60),
		TextTransparency = 1,
		ZIndex = 51,
		LayoutOrder = 1,
		Parent = titleGroup,
	})
	local sub = Kit.Label({
		Text = "Dive deep. Salvage relics. Escape the Leviathan.",
		Font = T.Bold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.6,
		Size = UDim2.new(1, 0, 0, 24),
		TextTransparency = 1,
		ZIndex = 51,
		LayoutOrder = 2,
		Parent = titleGroup,
	})
	local skip = Kit.Label({
		Text = "Tap to skip",
		TextSize = 12,
		TextColor3 = T.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(200, 16),
		ZIndex = 51,
		Parent = card,
	})

	local skipped = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.Keyboard
		then
			skipped = true
		end
	end)

	local prevType = cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = shots[1][1]
	local fade = TweenInfo.new(1.2)
	TweenService:Create(title, fade, { TextTransparency = 0 }):Play()
	TweenService:Create(sub, fade, { TextTransparency = 0 }):Play()
	for i = 2, #shots do
		if skipped then
			break
		end
		local tween = TweenService:Create(
			cam,
			TweenInfo.new(shots[i][2], Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ CFrame = shots[i][1] }
		)
		tween:Play()
		local t0 = os.clock()
		while os.clock() - t0 < shots[i][2] and not skipped do
			task.wait()
		end
		tween:Cancel()
	end
	conn:Disconnect()
	skip.Visible = false
	-- Fade to black, hand the camera back, fade in
	TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(title, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(sub, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	task.wait(0.4)
	cam.CameraType = if prevType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else prevType
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	TweenService:Create(card, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.wait(0.65)
	card:Destroy()
end

function IntroController.Start()
	task.spawn(function()
		if not isNewPlayer() then
			return
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(1)
		play()
	end)
end

return IntroController
