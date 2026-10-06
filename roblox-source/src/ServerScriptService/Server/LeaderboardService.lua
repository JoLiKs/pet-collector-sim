--!strict
-- Глобальный лидерборд (OrderedDataStore) по суммарно заработанным монетам + табло в мире.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local PetMeta = require(ReplicatedStorage.Shared.PetMeta)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Router = require(script.Parent.Router)
local WorldBuilder = require(script.Parent.WorldBuilder)

local LeaderboardService = {}

local REFRESH_INTERVAL = 60
local MAX_SCORE = 9e15 -- OrderedDataStore хранит целые числа

local store: OrderedDataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LEADERBOARD_DATASTORE)
	end)
	if ok then
		store = result :: OrderedDataStore
	end
end

local lastSubmitted: { [number]: number } = {}
local nameCache: { [number]: string } = {}

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and type(name) == "string" then name else ("Player" .. tostring(userId))
	nameCache[userId] = result
	return result
end

-- Отправка результата игрока (если изменился)
function LeaderboardService.submit(userId: number, totalCoins: number)
	local st = store
	if not st then
		return
	end
	local score = math.floor(math.clamp(totalCoins, 0, MAX_SCORE))
	if lastSubmitted[userId] == score then
		return
	end
	local ok, err = pcall(function()
		st:SetAsync(tostring(userId), score)
	end)
	if ok then
		lastSubmitted[userId] = score
	else
		warn("[Leaderboard] SetAsync failed:", err)
	end
end

local globalEntries: { { Name: string, Value: number } } = {}

-- Таблицы по игрокам этого сервера (обновляются «вживую»)
function LeaderboardService.live(): { [string]: { { Name: string, Value: number } } }
	local boards: { [string]: { { Name: string, Value: number } } } =
		{ Coins = {}, Kills = {}, Rebirths = {}, Power = {}, Hatched = {} }
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			local power = 0
			for _, p in pairs(data.Pets) do
				power = math.max(power, PetMeta.power(p))
			end
			table.insert(boards.Coins, { Name = player.DisplayName, Value = data.TotalCoins })
			table.insert(boards.Kills, { Name = player.DisplayName, Value = data.Stats.Kills or 0 })
			table.insert(boards.Rebirths, { Name = player.DisplayName, Value = data.Rebirths })
			table.insert(boards.Power, { Name = player.DisplayName, Value = math.floor(power * 10) / 10 })
			table.insert(boards.Hatched, { Name = player.DisplayName, Value = data.TotalHatched })
		end
	end
	for _, list in pairs(boards) do
		table.sort(list, function(a, b)
			return a.Value > b.Value
		end)
	end
	return boards
end

local function refreshBoard()
	local st = store
	if not st then
		WorldBuilder.setBoard(nil, "board.unavailable")
		return
	end
	local ok, pagesOrErr = pcall(function()
		return st:GetSortedAsync(false, 10)
	end)
	if not ok then
		WorldBuilder.setBoard(nil, "board.enable_api")
		return
	end
	local okPage, page = pcall(function()
		return (pagesOrErr :: DataStorePages):GetCurrentPage()
	end)
	if not okPage then
		return
	end
	local entries = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(entries, { Name = nameFor(userId), Value = entry.value :: number })
		end
	end
	globalEntries = entries
	WorldBuilder.setBoard(entries, "board.subtitle")
end

function LeaderboardService.init()
	Router.register("GetBoards", 1, 2, function(player: Player)
		Remotes.getEvent("Boards")
			:FireClient(player, { Global = globalEntries, Live = LeaderboardService.live() })
		return true, nil
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data then
					LeaderboardService.submit(player.UserId, data.TotalCoins)
					task.wait(0.5)
				end
			end
			refreshBoard()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return LeaderboardService
