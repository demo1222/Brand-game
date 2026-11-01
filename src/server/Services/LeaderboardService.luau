-- LeaderboardService (Master Plan §14, §21.2): global OrderedDataStore boards written at most
-- once per player per 5 minutes per board, top-10 refreshed every 2 minutes and shown on the
-- plaza boards and in the Leaderboards screen.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local NumberFormat = require(Shared.NumberFormat)
local Formulas = require(Shared.Formulas)

local WRITE_INTERVAL = 300
local READ_INTERVAL = 120

local BOARDS = {
	{ Id = "Deepest", Title = "Deepest Dive", Value = function(data)
		return data.Stats.DeepestDepth
	end, Format = function(v)
		return `{NumberFormat.commas(v)}m`
	end },
	{ Id = "TotalValue", Title = "Dock Value", Value = function(data)
		return math.floor(Formulas.DockValue(data))
	end, Format = function(v)
		return `{NumberFormat.short(v)}/s`
	end },
	{ Id = "Rebirths", Title = "Resurfaces", Value = function(data)
		return data.Rebirths
	end, Format = tostring },
	{ Id = "Steals", Title = "Most Steals", Value = function(data)
		return data.Stats.Steals
	end, Format = tostring },
	{ Id = "Codex", Title = "Codex %", Value = function(data, services)
		return math.floor(services.InventoryService.CodexPercent(data) * 10)
	end, Format = function(v)
		return string.format("%.1f%%", v / 10)
	end },
}

local LeaderboardService = {}
local services
local stores = {}
local lastWrite: { [Player]: number } = {}
local nameCache: { [number]: string } = {}
local latest = {}

function LeaderboardService.Init(s)
	services = s
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

local function writePlayer(player: Player)
	local data = services.DataService.GetData(player)
	if not data then
		return
	end
	for _, board in BOARDS do
		local store = stores[board.Id]
		if store then
			local value = math.floor(board.Value(data, services))
			if value > 0 then
				pcall(store.SetAsync, store, tostring(player.UserId), value)
			end
		end
	end
end

local function refreshBoards()
	local boardsFolder = services.WorldService.Root():FindFirstChild("Plaza")
	boardsFolder = boardsFolder and boardsFolder:FindFirstChild("Leaderboards")
	for _, board in BOARDS do
		local store = stores[board.Id]
		local rows = {}
		if store then
			local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
			if ok and pages then
				for rank, entry in pages:GetCurrentPage() do
					table.insert(rows, { Rank = rank, Name = nameOf(tonumber(entry.key) or 0), Value = board.Format(entry.value) })
				end
			end
		end
		if #rows == 0 then
			-- Fallback: in-server ranking (Studio / DataStore outage)
			local list = {}
			for _, p in Players:GetPlayers() do
				local data = services.DataService.GetData(p)
				if data then
					table.insert(list, { Name = p.DisplayName, Raw = board.Value(data, services) })
				end
			end
			table.sort(list, function(a, b)
				return a.Raw > b.Raw
			end)
			for rank, e in list do
				if rank > 10 then
					break
				end
				table.insert(rows, { Rank = rank, Name = e.Name, Value = board.Format(math.floor(e.Raw)) })
			end
		end
		latest[board.Id] = { Title = board.Title, Rows = rows }
		local part = boardsFolder and boardsFolder:FindFirstChild(board.Id)
		local text = part and part:FindFirstChild("Board") and part.Board:FindFirstChild("Text")
		if text then
			local lines = { board.Title:upper(), "" }
			for _, r in rows do
				table.insert(lines, `{r.Rank}. {r.Name}  —  {r.Value}`)
			end
			text.Text = table.concat(lines, "\n")
		end
	end
	Net.Leaderboards:FireAllClients(latest)
end

function LeaderboardService.Start()
	for _, board in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "AbyssSalvage_LB_" .. board.Id)
		if ok then
			stores[board.Id] = store
		end
	end
	services.DataService.OnRelease(function(player)
		task.spawn(writePlayer, player)
		lastWrite[player] = nil
	end)
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastWrite[player] or 0) >= WRITE_INTERVAL then
					lastWrite[player] = os.clock()
					writePlayer(player)
					task.wait(1) -- spread requests
				end
			end
			refreshBoards()
			task.wait(READ_INTERVAL)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.wait(5)
		if next(latest) then
			Net.Leaderboards:FireClient(p, latest)
		end
	end)
end

return LeaderboardService
