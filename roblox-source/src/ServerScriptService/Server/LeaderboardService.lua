--!strict
-- Глобальный лидерборд (OrderedDataStore) по суммарно заработанным монетам + табло в мире.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
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

local function refreshBoard()
	local st = store
	if not st then
		WorldBuilder.setBoard(nil, "Leaderboard unavailable")
		return
	end
	local ok, pagesOrErr = pcall(function()
		return st:GetSortedAsync(false, 10)
	end)
	if not ok then
		WorldBuilder.setBoard(nil, "Enable API Services to see the board")
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
	WorldBuilder.setBoard(entries, "Lifetime coins earned")
end

function LeaderboardService.init()
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
