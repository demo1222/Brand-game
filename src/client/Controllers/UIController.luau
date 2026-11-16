-- UIController: root ScreenGuis, window manager (one window at a time), toasts and banners.
-- Windows get a dim backdrop, a striped coloured title band with an outlined title and a red
-- close button, a thick outline, and pop-in / pop-out animations. A window closes only through
-- its X, gamepad B or its own buttons: a click that misses a button does nothing
-- (docs/UI_STYLE_GUIDE.md).

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
local backdrop: Frame
local closeToken = 0

UIController.Root = nil :: ScreenGui?
UIController.Overlay = nil :: ScreenGui?

-- Old place-file GUI ("MainGui" stats panel with a ✨ toggle) sat on top of the HUD rail and
-- swallowed clicks on UPGRADE. The game's UI is built in code; remove the leftover.
local LEGACY_GUIS = { MainGui = true }

function UIController.Init()
	local pg = player:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do
		if LEGACY_GUIS[g.Name] then
			g:Destroy()
		end
	end
	pg.ChildAdded:Connect(function(g)
		if LEGACY_GUIS[g.Name] then
			task.defer(g.Destroy, g)
		end
	end)
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
	-- Active so it swallows clicks (the world and HUD behind can't be clicked) without closing
	backdrop = New("Frame", {
		Name = "Backdrop",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(0, 4, 12),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 60),
		Position = UDim2.fromOffset(0, -60),
		Visible = false,
		ZIndex = 0,
		Parent = UIController.Windows,
	})
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonB and openWindow then
			UIController.Close()
		end
	end)
	toastList = New("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.new(0.9, 0, 0, 300),
		Parent = UIController.Overlay,
	}, {
		Kit.List(6, false, Enum.HorizontalAlignment.Center),
		New("UISizeConstraint", { MaxSize = Vector2.new(440, 300) }),
	})
	bannerFrame = New("Frame", {
		Name = "Banner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.new(0.9, 0, 0, 44),
		Parent = UIController.Overlay,
	}, { New("UISizeConstraint", { MaxSize = Vector2.new(660, 44) }) })
end

-- Register a window: builder(body) fills it, refresh() is called on open.
-- The look (owner reference docs/reference/shop_upgrades): a black panel with a soft glow in
-- the window's colour round it, a slanted colour band that hangs over the top-left corner with
-- the title on it, and a red close button over the top-right corner.
--   opts.Plain   = a charcoal panel with no band or coloured glow (Settings)
--   opts.MaxSize = the largest size (default 820 x 580)
--   opts.Header  = function(holder): add things to the right end of the title band
function UIController.RegisterWindow(
	name: string,
	title: string,
	build: (Frame) -> (),
	refresh: (() -> ())?,
	opts: { Plain: boolean?, MaxSize: Vector2?, Header: ((Frame) -> ())? }?
)
	local o = opts or {}
	local C = Kit.Clean
	local accent = Icons.Colors[name] or T.Accent
	local frame = New("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(0.94, 0, 0.82, 0),
		Visible = false,
		ZIndex = 2,
		Parent = UIController.Windows,
	})
	New("UISizeConstraint", { MaxSize = o.MaxSize or Vector2.new(820, 580), Parent = frame })
	-- the glow: thin rounded layers behind the panel that add up to a smooth falloff
	local hue, sat = accent:ToHSV()
	local glowColor = if o.Plain then Color3.new(0, 0, 0) else Color3.fromHSV(hue, math.max(sat, 0.7), 1)
	local LAYERS, STEP, OUTLINE = 11, 3, 4
	for k, alpha in Kit.GlowLayers(LAYERS, if o.Plain then 0.5 else 0.82, 1.4) do
		local grow = OUTLINE + k * STEP
		New("Frame", {
			Name = "Glow" .. k,
			BackgroundColor3 = glowColor,
			BackgroundTransparency = 1 - alpha,
			Position = UDim2.fromOffset(-grow, -grow),
			Size = UDim2.new(1, grow * 2, 1, grow * 2),
			ZIndex = 0,
			Parent = frame,
		}, { Kit.Corner(16 + grow) })
	end
	-- Active: a click on the panel never reaches the world behind it
	New("Frame", {
		Name = "Panel",
		Active = true,
		BackgroundColor3 = if o.Plain then C.PanelPlain else C.Panel,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = frame,
	}, { Kit.Corner(16), Kit.Stroke(Color3.new(0, 0, 0), OUTLINE, 0) })

	local top = 48
	if o.Plain then
		Kit.Text(title, 27, {
			Name = "Title",
			Outline = 3,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(20, 10),
			Size = UDim2.new(1, -90, 0, 36),
			ZIndex = 4,
			Parent = frame,
		})
		top = 54
	else
		local band = Kit.SlantBand(frame, {
			Position = UDim2.fromOffset(-14, -22),
			Size = UDim2.new(1, -60, 0, 58),
			Colors = Kit.BandColors(accent),
			ZIndex = 3,
		})
		Kit.Text(title, 32, {
			Name = "Title",
			Outline = 4,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(0.6, 0, 1, -4),
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 5,
			Parent = band,
		})
		if o.Header then
			local holder = New("Frame", {
				Name = "HeaderRight",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -46, 0.5, -2),
				Size = UDim2.new(0.5, 0, 0, 44),
				ZIndex = 5,
				Parent = band,
			}, {
				New("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			o.Header(holder)
		end
	end
	local closeHolder, close = Kit.GameButton(T.Bad, Vector2.new(46, 42), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 12, 0, -18),
		ZIndex = 6,
		Parent = frame,
	})
	for _, d in closeHolder:GetDescendants() do
		if d:IsA("UIStroke") then
			d.Color, d.Thickness, d.Transparency = C.Ink, 3, 0
		end
	end
	Icon.new("close", 22, Color3.new(1, 1, 1), {
		Weight = 3.6,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 8,
		Parent = close,
	})
	close.Activated:Connect(function()
		UIController.Close()
	end)

	local body = New("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, top),
		Size = UDim2.new(1, -28, 1, -(top + 14)),
		ZIndex = 2,
		Parent = frame,
	})
	build(body)
	windows[name] = { frame = frame, refresh = refresh }
end

-- The world behind an open window is dimmed and blurred
local blur: BlurEffect? = nil
local function showBackdrop(on: boolean)
	if not blur then
		blur = New("BlurEffect", { Name = "AbyssWindowBlur", Size = 0, Enabled = false, Parent = Lighting })
	end
	local b = blur :: BlurEffect
	if on then
		backdrop.Visible = true
		b.Enabled = true
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.5 }):Play()
		TweenService:Create(b, TweenInfo.new(0.2), { Size = 14 }):Play()
	else
		backdrop.BackgroundTransparency = 1
		backdrop.Visible = false
		b.Size = 0
		b.Enabled = false
	end
end

function UIController.Open(name: string)
	closeToken += 1 -- cancels a close animation still running
	for _, other in windows do
		other.frame.Visible = false
	end
	local w = windows[name]
	if not w then
		return
	end
	openWindow = name
	if w.refresh then
		-- a render error must never stop a window from opening
		local ok, err = pcall(w.refresh)
		if not ok then
			warn(`[UI] {name} refresh failed: {err}`)
		end
	end
	w.frame.Visible = true
	showBackdrop(true)
	Kit.Pop(w.frame, 0.85, 0.22)
end

function UIController.Toggle(name: string)
	if openWindow == name then
		UIController.Close()
	else
		UIController.Open(name)
	end
end

function UIController.Close()
	local w = openWindow and windows[openWindow]
	openWindow = nil
	if not w then
		showBackdrop(false)
		return
	end
	closeToken += 1
	local token = closeToken
	TweenService:Create(backdrop, TweenInfo.new(0.14), { BackgroundTransparency = 1 }):Play()
	if blur then
		TweenService:Create(blur, TweenInfo.new(0.14), { Size = 0 }):Play()
	end
	Kit.PopOut(w.frame, function()
		if token == closeToken then
			w.frame.Visible = false
			showBackdrop(false)
		end
	end)
end

function UIController.IsOpen(name: string): boolean
	return openWindow == name
end

function UIController.AnyOpen(): boolean
	return openWindow ~= nil
end

function UIController.Refresh(name: string)
	if openWindow == name and windows[name].refresh then
		local ok, err = pcall(windows[name].refresh)
		if not ok then
			warn(`[UI] {name} refresh failed: {err}`)
		end
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
		New("UIPadding", {
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
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
