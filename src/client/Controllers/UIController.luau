-- UIController: root ScreenGuis, window manager (one window at a time), toasts and banners.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Rarities = require(Shared.Config.Rarities)
local Kit = require(script.Parent.Parent.UI.Kit)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local UIController = {}
local windows = {}
local openWindow: string? = nil
local toastList: Frame
local bannerFrame: Frame

UIController.Root = nil :: ScreenGui?
UIController.Overlay = nil :: ScreenGui?

function UIController.Init()
	local pg = player:WaitForChild("PlayerGui")
	UIController.Root = New("ScreenGui", {
		Name = "AbyssHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	UIController.Windows = New("ScreenGui", {
		Name = "AbyssWindows",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	UIController.Overlay = New("ScreenGui", {
		Name = "AbyssOverlay",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	toastList = New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(420, 300),
		Parent = UIController.Overlay,
	}, { Kit.List(6, false, Enum.HorizontalAlignment.Center) })
	bannerFrame = New("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(640, 40),
		Parent = UIController.Overlay,
	})
end

-- Register a window: builder(frame) fills it, refresh() is called on open
function UIController.RegisterWindow(name: string, title: string, build: (Frame) -> (), refresh: (() -> ())?)
	local frame = Kit.Panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.92, 0, 0.78, 0),
		Visible = false,
		Parent = UIController.Windows,
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(760, 560), Parent = frame })
	Kit.Label({
		Text = title,
		Font = T.Bold,
		TextSize = 22,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 30),
		Parent = frame,
	})
	Kit.Button("✕", T.Bad, function()
		UIController.Close()
	end, { Size = UDim2.fromOffset(48, 40), Position = UDim2.new(1, -56, 0, 8), Parent = frame })
	local body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 1, -58),
		Parent = frame,
	})
	build(body)
	windows[name] = { frame = frame, refresh = refresh }
end

function UIController.Open(name: string)
	if openWindow and windows[openWindow] then
		windows[openWindow].frame.Visible = false
	end
	local w = windows[name]
	if not w then
		return
	end
	openWindow = name
	if w.refresh then
		w.refresh()
	end
	w.frame.Visible = true
	Kit.Pop(w.frame)
end

function UIController.Toggle(name: string)
	if openWindow == name then
		UIController.Close()
	else
		UIController.Open(name)
	end
end

function UIController.Close()
	if openWindow and windows[openWindow] then
		windows[openWindow].frame.Visible = false
	end
	openWindow = nil
end

function UIController.IsOpen(name: string): boolean
	return openWindow == name
end

function UIController.Refresh(name: string)
	if openWindow == name and windows[name].refresh then
		windows[name].refresh()
	end
end

local KIND_COLORS = {
	error = T.Bad,
	reward = T.Gold,
	coins = T.Good,
	upgrade = T.Accent,
	info = T.PanelLight,
}

function UIController.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or T.PanelLight
	local toast = New("TextLabel", {
		BackgroundColor3 = color,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextWrapped = true,
		TextColor3 = if kind == "reward" then Color3.fromRGB(30, 20, 0) else T.Text,
		Font = T.Bold,
		TextSize = 16,
		Parent = toastList,
	}, { Kit.Corner(10), Kit.Padding(8) })
	Kit.Pop(toast)
	task.delay(4, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		task.wait(0.45)
		toast:Destroy()
	end)
	local kids = toastList:GetChildren()
	if #kids > 6 then
		for _, k in kids do
			if k:IsA("TextLabel") then
				k:Destroy()
				break
			end
		end
	end
end

-- Big announcement banner (Mythic finds, events)
function UIController.Banner(text: string, rarity: string?)
	Kit.Clear(bannerFrame)
	local r = Rarities[rarity or "Rare"]
	local color = if type(r) == "table" and r.Color then r.Color else T.Accent
	local label = New("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(10, 10, 20),
		BackgroundTransparency = 0.2,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextScaled = true,
		TextColor3 = if rarity == "Secret" then Color3.new(1, 1, 1) else color,
		Font = T.Bold,
		Parent = bannerFrame,
	}, { Kit.Corner(10), Kit.Stroke(color, 2), New("UITextSizeConstraint", { MaxTextSize = 24 }) })
	Kit.Pop(label)
	task.delay(6, function()
		if label.Parent then
			label:Destroy()
		end
	end)
end

function UIController.Start()
	Net.Notify.OnClientEvent:Connect(UIController.Toast)
	Net.Announce.OnClientEvent:Connect(UIController.Banner)
end

return UIController
