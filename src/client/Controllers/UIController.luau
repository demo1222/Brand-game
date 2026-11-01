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
local Icon = require(script.Parent.Parent.UI.Icon)

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
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.94, 0, 0.84, 0),
		Visible = false,
		ZIndex = 2,
		Parent = UIController.Windows,
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(820, 580), Parent = frame })
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
		stroke.Transparency = 0.55
	end

	-- Header: drawn icon, display title, square close button (UI design "Bag & Dock window")
	local header = New("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.new(1, -40, 0, 44),
		Parent = frame,
	})
	Icon.new(Icons.Get(name), 28, accent, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Parent = header })
	Kit.Title({
		Text = title,
		TextSize = 26,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -100, 1, 0),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	local close = New("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = T.PanelLight,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		Parent = header,
	}, { Kit.Corner(12), Kit.Stroke(T.Text, 1, 0.8) })
	Icon.new("close", 18, T.Text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = close })
	Kit.Juice(close)
	close.Activated:Connect(function()
		UIController.Close()
	end)

	local body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 72),
		Size = UDim2.new(1, -40, 1, -90),
		Parent = frame,
	})
	build(body)
	windows[name] = { frame = frame, refresh = refresh }
end

local function showBackdrop(on: boolean)
	if on then
		backdrop.Visible = true
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
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
	coins = T.Gold,
	upgrade = T.Accent,
	info = T.Accent,
}

function UIController.Toast(text: string, kind: string?)
	local k = kind or "info"
	local color = KIND_COLORS[k] or T.Accent
	local toast = New("Frame", {
		BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.06,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toastList,
	}, {
		Kit.Corner(14),
		Kit.Stroke(color, 1, 0.3),
		New("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 46),
			PaddingRight = UDim.new(0, 14),
		}),
	})
	local icon = Icon.new(Icons.Get(k), 22, color, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -34, 0.5, 0),
		Parent = toast,
	})
	local label = Kit.Label({
		Text = text,
		Font = T.Bold,
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toast,
	})
	Kit.Pop(toast)
	task.delay(4, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		icon.Visible = false
		local st = toast:FindFirstChildOfClass("UIStroke")
		if st then
			TweenService:Create(st, fade, { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		toast:Destroy()
	end)
	local kids = {}
	for _, c in toastList:GetChildren() do
		if c:IsA("Frame") then
			table.insert(kids, c)
		end
	end
	if #kids > 4 then
		kids[1]:Destroy()
	end
end

-- Big announcement banner (Mythic finds, events)
function UIController.Banner(text: string, rarity: string?)
	Kit.Clear(bannerFrame)
	local color = Kit.RarityColor(rarity or "Rare", Rarities)
	local r = Rarities[rarity or "Rare"]
	local glyph = if type(r) == "table" and r.Icon then r.Icon else "◆"
	local banner = New("TextLabel", {
		BackgroundColor3 = Kit.Darken(color, 0.82),
		BackgroundTransparency = 0.05,
		Size = UDim2.fromScale(1, 1),
		Text = `{glyph}  {text}  {glyph}`,
		TextScaled = true,
		TextColor3 = Kit.Lighten(color, 0.55),
		Font = T.Title,
		Parent = bannerFrame,
	}, {
		Kit.Round(),
		Kit.Stroke(color, 2, 0),
		New("UITextSizeConstraint", { MaxTextSize = 22 }),
		New("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
	})
	Kit.Shine(banner, 1.2)
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
