-- UIController: root ScreenGuis, window manager (one window at a time), toasts and banners.
-- Windows get a dim backdrop (tap outside to close), a header with an icon badge and a display
-- font, and a pop-in animation (UI/Visual Overhaul Plan, Phase 1).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Rarities = require(Shared.Config.Rarities)
local Kit = require(script.Parent.Parent.UI.Kit)
local Icons = require(script.Parent.Parent.UI.Icons)

local New, T = Kit.New, Kit.Theme
local player = Players.LocalPlayer

local UIController = {}
local windows = {}
local openWindow: string? = nil
local toastList: Frame
local bannerFrame: Frame
local backdrop: TextButton

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
	backdrop = New("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 4, 12),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 60),
		Position = UDim2.fromOffset(0, -60),
		Visible = false,
		ZIndex = 0,
		Parent = UIController.Windows,
	})
	backdrop.Activated:Connect(function()
		UIController.Close()
	end)
	toastList = New(
		"Frame",
		{
			Name = "Toasts",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 100),
			Size = UDim2.new(0.9, 0, 0, 300),
			Parent = UIController.Overlay,
		},
		{
			Kit.List(6, false, Enum.HorizontalAlignment.Center),
			New("UISizeConstraint", { MaxSize = Vector2.new(440, 300) }),
		}
	)
	bannerFrame = New("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.new(0.9, 0, 0, 44),
		Parent = UIController.Overlay,
	}, { New("UISizeConstraint", { MaxSize = Vector2.new(660, 44) }) })
end

-- Register a window: builder(body) fills it, refresh() is called on open
function UIController.RegisterWindow(name: string, title: string, build: (Frame) -> (), refresh: (() -> ())?)
	local accent = Icons.Colors[name] or T.Accent
	local frame = Kit.Panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0.94, 0, 0.8, 0),
		Visible = false,
		ZIndex = 2,
		Parent = UIController.Windows,
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(820, 580), Parent = frame })
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
		stroke.Transparency = 0.25
	end

	-- Header strip
	local headerBar = New("Frame", {
		Name = "Header",
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = frame,
	}, {
		Kit.Corner(16),
		New("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	Kit.IconBadge(Icons.Get(name), accent, 46, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -8, 0, 18),
		ZIndex = 3,
		Parent = frame,
	})
	Kit.Title({
		Text = title,
		TextSize = 26,
		Position = UDim2.fromOffset(48, 8),
		Size = UDim2.new(1, -120, 0, 36),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = headerBar,
	})
	local close = Kit.Button("✕", T.Bad, function()
		UIController.Close()
	end, {
		Size = UDim2.fromOffset(44, 44),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -10),
		TextSize = 20,
		ZIndex = 4,
		Parent = frame,
	})
	close:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)

	local body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 1, -68),
		Parent = frame,
	})
	build(body)
	windows[name] = { frame = frame, refresh = refresh }
end

local function showBackdrop(on: boolean)
	if on then
		backdrop.Visible = true
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 }):Play()
	else
		backdrop.BackgroundTransparency = 1
		backdrop.Visible = false
	end
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
	showBackdrop(true)
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
	showBackdrop(false)
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
	local k = kind or "info"
	local color = KIND_COLORS[k] or T.PanelLight
	local toast = New("Frame", {
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.08,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toastList,
	}, {
		Kit.Corner(14),
		Kit.Stroke(color, 2, 0.1),
		New("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 50),
			PaddingRight = UDim.new(0, 12),
		}),
	})
	local badge = Kit.IconBadge(Icons.Get(k), color, 34, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -42, 0.5, 0),
		Parent = toast,
	})
	local label = Kit.Label({
		Text = text,
		Font = T.Bold,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toast,
	})
	Kit.Pop(toast)
	task.delay(4, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		badge.Visible = false
		local s = toast:FindFirstChildOfClass("UIStroke")
		if s then
			TweenService:Create(s, fade, { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		toast:Destroy()
	end)
	local kids = {}
	for _, c in toastList:GetChildren() do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 5 then
		kids[1]:Destroy()
	end
end

-- Big announcement banner (Mythic finds, events)
function UIController.Banner(text: string, rarity: string?)
	Kit.Clear(bannerFrame)
	local color = Kit.RarityColor(rarity or "Rare", Rarities)
	local r = Rarities[rarity or "Rare"]
	local icon = if type(r) == "table" and r.Icon then r.Icon else "✦"
	local banner = New("TextLabel", {
		BackgroundColor3 = Kit.Darken(color, 0.55),
		BackgroundTransparency = 0.05,
		Size = UDim2.fromScale(1, 1),
		Text = `{icon}  {text}  {icon}`,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Font = T.Title,
		Parent = bannerFrame,
	}, {
		Kit.Round(),
		Kit.Stroke(color, 3, 0),
		Kit.Gradient(Kit.Lighten(color, 0.2), Kit.Darken(color, 0.3), 0),
		New("UITextSizeConstraint", { MaxTextSize = 24 }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	})
	Kit.Shine(banner, 0.8)
	Kit.Pop(banner)
	task.delay(6, function()
		if banner.Parent then
			banner:Destroy()
		end
	end)
end

function UIController.Start()
	Net.Notify.OnClientEvent:Connect(UIController.Toast)
	Net.Announce.OnClientEvent:Connect(UIController.Banner)
end

return UIController
