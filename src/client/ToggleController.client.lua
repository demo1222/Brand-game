local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local gui = script.Parent
local toggleButton = gui:WaitForChild("ToggleButton")
local panel = gui:WaitForChild("MainPanel")
local closeButton = panel.TitleBar:WaitForChild("CloseButton")
local icon = toggleButton:WaitForChild("Icon")
local statsContainer = panel:WaitForChild("StatsContainer")

local isOpen = false

-- Tween settings
local openTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local closeTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

local closedProps = { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 }
local openProps   = { Size = UDim2.fromOffset(360, 260), BackgroundTransparency = 0 }

local stroke = panel:FindFirstChildOfClass("UIStroke")

-- Обновить статы игрока
local function updateStats()
	local player = Players.LocalPlayer
	if not player then return end
	local char = player.Character

	-- Имя
	local nameCard = statsContainer:FindFirstChild("PlayerNameCard")
	if nameCard then nameCard.Value.Text = player.DisplayName end

	-- Здоровье
	local healthCard = statsContainer:FindFirstChild("HealthCard")
	if healthCard and char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			healthCard.Value.Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
		end
	end

	-- Скорость
	local speedCard = statsContainer:FindFirstChild("WalkSpeedCard")
	if speedCard and char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			speedCard.Value.Text = tostring(hum.WalkSpeed)
		end
	end

	-- Монеты (leaderstats если есть)
	local coinsCard = statsContainer:FindFirstChild("CoinsCard")
	if coinsCard then
		local ls = player:FindFirstChild("leaderstats")
		local coins = ls and (ls:FindFirstChild("Coins") or ls:FindFirstChild("Cash") or ls:FindFirstChild("Points"))
		coinsCard.Value.Text = coins and tostring(coins.Value) or "0"
	end
end

local function setPanelOpen(open)
	isOpen = open
	if open then
		updateStats()
		panel.Visible = true
		panel.Size = closedProps.Size
		panel.BackgroundTransparency = 1
		if stroke then stroke.Transparency = 1 end

		TweenService:Create(panel, openTweenInfo, openProps):Play()
		if stroke then
			TweenService:Create(stroke, openTweenInfo, {Transparency = 0.4}):Play()
		end
		icon.Text = "🔓"
	else
		local tween = TweenService:Create(panel, closeTweenInfo, closedProps)
		tween:Play()
		if stroke then
			TweenService:Create(stroke, closeTweenInfo, {Transparency = 1}):Play()
		end
		tween.Completed:Connect(function()
			if not isOpen then panel.Visible = false end
		end)
		icon.Text = "✨"
	end
end

-- Hover эффект
toggleButton.MouseEnter:Connect(function()
	TweenService:Create(toggleButton, TweenInfo.new(0.15), {Size = UDim2.fromOffset(62, 62)}):Play()
end)
toggleButton.MouseLeave:Connect(function()
	TweenService:Create(toggleButton, TweenInfo.new(0.15), {Size = UDim2.fromOffset(56, 56)}):Play()
end)

toggleButton.MouseButton1Click:Connect(function()
	setPanelOpen(not isOpen)
end)
closeButton.MouseButton1Click:Connect(function()
	setPanelOpen(false)
end)
