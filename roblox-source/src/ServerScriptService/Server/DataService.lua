--!strict
--[[
	DataService — сохранение данных игроков.

	Особенности:
	  * Session lock: запись в DataStore содержит Lock = { SessionId, Time }. Сервер, который хочет загрузить
	    данные, видит чужую свежую блокировку и ждёт (с ретраями) её снятия. Это защищает от дюпа
	    при одновременной игре на двух серверах и от перезаписи более новых данных.
	  * Блокировка продлевается каждым автосейвом; если она старше SESSION_LOCK_TIMEOUT — считается
	    брошенной (сервер упал), и её можно забрать.
	  * Все обращения к DataStore — через UpdateAsync в pcall, с ретраями и экспоненциальной паузой.
	  * Если блокировку у нас "украли" (старый сервер завис), сохранение отменяется, игрок кикается.
	  * В Studio при выключенном API Services (или недоступном DataStore) — режим без сохранения (ephemeral).
	  * BindToClose сохраняет всех игроков параллельно.
]]
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage.Shared.Locale)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local Migrations = require(script.Parent.Migrations)

export type Data = { [string]: any }

type Profile = {
	Player: Player,
	Key: string,
	Data: Data,
	Ephemeral: boolean,
	Saving: boolean,
	Released: boolean,
	LockLost: boolean,
	IsNew: boolean,
}

local DataService = {}

DataService.SESSION_ID = HttpService:GenerateGUID(false)

local TEMPLATE_VERSION = 2

local function makeTemplate(): Data
	return {
		Version = TEMPLATE_VERSION,
		Coins = 0,
		Gems = 0,
		Rebirths = 0,
		TotalCoins = 0,
		TotalHatched = 0,
		TotalClicks = 0,
		Pets = {}, -- [uid] = { Id, Variant, Level, Xp, Evo, Fav }
		NextPetId = 1,
		Equipped = {}, -- массив uid
		Upgrades = { Click = 0, Speed = 0, Luck = 0, Bag = 0, Slots = 0 },
		Zones = { [ZoneData.DEFAULT] = true },
		CurrentZone = ZoneData.DEFAULT,
		Daily = { LastDay = 0, Streak = 0 },
		Boosts = { Luck2 = 0, Luck5 = 0, Coins2 = 0 }, -- unix-время окончания
		Resources = {}, -- [Wood|Stone|Ore|Herb|Crystal|Essence] = n
		Items = {}, -- [itemId] = n (зелья, билеты, инструменты)
		Talents = {}, -- [talentId] = уровень
		Stats = {}, -- счётчики для квестов и достижений
		Achievements = {}, -- [id] = true
		Quests = { Chains = {}, Daily = { Day = 0, Items = {} } },
		BattlePass = { Season = 1, Xp = 0, ClaimedFree = {}, ClaimedPremium = {} },
		Shop = { Slot = 0, Bought = {} },
		LastSeen = os.time(),
		OfflinePending = 0,
		AutoCollect = true,
		Settings = { Lang = "auto" }, -- "auto" | "en" | "ru" (см. LanguageService)
		Receipts = {}, -- [tostring(PurchaseId)] = unix-время (идемпотентность ProcessReceipt)
		Joined = os.time(),
	}
end
DataService.makeTemplate = makeTemplate

local store: DataStore? = nil
local storeOk = true
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)
	if ok then
		store = result :: DataStore
	else
		storeOk = false
		warn("[DataService] GetDataStore failed:", result)
	end
end

local profiles: { [Player]: Profile } = {}
local isShuttingDown = false

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

-- Studio без включённых API Services: повторять бессмысленно, сразу переходим в режим без сохранения
local function isApiDisabledError(message: string): boolean
	local lower = string.lower(message)
	return string.find(lower, "studio access to apis", 1, true) ~= nil
		or string.find(lower, "enable studio access", 1, true) ~= nil
end

local function isLockedByOther(record: any): boolean
	if type(record) ~= "table" then
		return false
	end
	local lock = record.Lock
	if type(lock) ~= "table" then
		return false
	end
	if lock.SessionId == DataService.SESSION_ID then
		return false
	end
	local t = lock.Time
	if type(t) ~= "number" then
		return false
	end
	return os.time() - t < Config.SESSION_LOCK_TIMEOUT
end
DataService._isLockedByOther = isLockedByOther

-- ---------------------------------------------------------------------------
-- Загрузка
-- ---------------------------------------------------------------------------

-- Возвращает Data или nil, причина. Блокирует (yield) вызывающий поток.
function DataService.load(player: Player): (Data?, string?)
	local key = keyFor(player)
	local st = store

	if st == nil then
		if RunService:IsStudio() and Config.STUDIO_FALLBACK_TO_EPHEMERAL then
			warn(
				"[DataService] DataStore unavailable in Studio — using temporary data (progress will NOT be saved)."
			)
			local data = makeTemplate()
			profiles[player] = {
				Player = player,
				Key = key,
				Data = data,
				Ephemeral = true,
				Saving = false,
				Released = false,
				LockLost = false,
				IsNew = true,
			}
			return data, nil
		end
		return nil, "DataStore unavailable"
	end

	local lastError = "unknown"
	for attempt = 1, Config.LOAD_ATTEMPTS do
		if not player.Parent then
			return nil, "player left"
		end
		local wasLocked = false
		local ok, result = pcall(function()
			return st:UpdateAsync(key, function(old)
				if isLockedByOther(old) then
					wasLocked = true
					return nil -- отмена обновления
				end
				local record = if type(old) == "table" then old else {}
				record.Lock = { SessionId = DataService.SESSION_ID, Time = os.time() }
				return record
			end)
		end)

		if ok and not wasLocked and type(result) == "table" then
			local data: Data
			local isNew = false
			if type(result.Data) == "table" then
				data = result.Data
				Migrations.run(data)
				Util.reconcile(data, makeTemplate())
			else
				data = makeTemplate()
				isNew = true
			end
			if not player.Parent then
				-- игрок вышел во время загрузки: сразу снимаем блокировку
				profiles[player] = {
					Player = player,
					Key = key,
					Data = data,
					Ephemeral = false,
					Saving = false,
					Released = false,
					LockLost = false,
					IsNew = isNew,
				}
				task.spawn(DataService.release, player)
				return nil, "player left"
			end
			profiles[player] = {
				Player = player,
				Key = key,
				Data = data,
				Ephemeral = false,
				Saving = false,
				Released = false,
				LockLost = false,
				IsNew = isNew,
			}
			return data, nil
		elseif ok and wasLocked then
			lastError = "session locked by another server"
			task.wait(Config.LOAD_LOCK_RETRY_DELAY)
		else
			lastError = tostring(result)
			warn(("[DataService] load attempt %d failed for %s: %s"):format(attempt, player.Name, lastError))
			if RunService:IsStudio() and isApiDisabledError(lastError) then
				break
			end
			task.wait(math.min(2 ^ attempt, 15))
		end
	end

	if RunService:IsStudio() and Config.STUDIO_FALLBACK_TO_EPHEMERAL and not isShuttingDown then
		warn("[DataService] Could not load data in Studio (" .. lastError .. "). Using temporary data.")
		local data = makeTemplate()
		profiles[player] = {
			Player = player,
			Key = key,
			Data = data,
			Ephemeral = true,
			Saving = false,
			Released = false,
			LockLost = false,
			IsNew = true,
		}
		return data, nil
	end
	return nil, lastError
end

-- ---------------------------------------------------------------------------
-- Сохранение
-- ---------------------------------------------------------------------------

local function write(profile: Profile, releaseLock: boolean): boolean
	if profile.Ephemeral then
		return true
	end
	local st = store
	if st == nil then
		return false
	end

	-- Ждём завершения параллельного сохранения того же игрока
	local waited = 0
	while profile.Saving and waited < 30 do
		task.wait(0.1)
		waited += 0.1
	end
	if profile.LockLost then
		return false
	end

	profile.Saving = true
	-- Снимок данных ДО вызова UpdateAsync: функция-трансформер может вызываться несколько раз и не должна yield-ить.
	local snapshot = Util.deepCopy(profile.Data)
	local success = false
	for attempt = 1, Config.SAVE_ATTEMPTS do
		local stolen = false
		local ok, err = pcall(function()
			st:UpdateAsync(profile.Key, function(old)
				if isLockedByOther(old) then
					stolen = true
					return nil
				end
				local record = if type(old) == "table" then old else {}
				record.Data = snapshot
				record.SavedAt = os.time()
				if releaseLock then
					record.Lock = nil
				else
					record.Lock = { SessionId = DataService.SESSION_ID, Time = os.time() }
				end
				return record
			end)
		end)
		if ok then
			if stolen then
				profile.LockLost = true
				warn("[DataService] Session lock lost for", profile.Player.Name, "- save cancelled")
				break
			end
			success = true
			break
		end
		warn(
			("[DataService] save attempt %d failed for %s: %s"):format(
				attempt,
				profile.Player.Name,
				tostring(err)
			)
		)
		task.wait(math.min(2 ^ attempt, 10))
	end
	profile.Saving = false
	return success
end

function DataService.get(player: Player): Data?
	local p = profiles[player]
	if p and not p.Released then
		return p.Data
	end
	return nil
end

function DataService.isNewPlayer(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.IsNew
end

-- Немедленное сохранение (например, после покупки). Возвращает true при успехе.
function DataService.saveNow(player: Player): boolean
	local p = profiles[player]
	if not p or p.Released then
		return false
	end
	local ok = write(p, false)
	if p.LockLost and player.Parent then
		player:Kick(Locale.tp(player, "kick.session"))
	end
	return ok
end

-- Финальное сохранение + снятие блокировки при выходе игрока
function DataService.release(player: Player)
	local p = profiles[player]
	if not p or p.Released then
		return
	end
	p.Released = true
	profiles[player] = nil
	write(p, true)
end

-- Подтверждение того, что у игрока есть живой профиль (для проверок в других сервисах)
function DataService.isLoaded(player: Player): boolean
	return DataService.get(player) ~= nil
end

-- Ждёт загрузки данных (до timeout секунд). Нужен для ProcessReceipt.
function DataService.waitForData(player: Player, timeout: number): Data?
	local t = 0
	while t < timeout do
		local d = DataService.get(player)
		if d then
			return d
		end
		if not player.Parent then
			return nil
		end
		task.wait(0.25)
		t += 0.25
	end
	return DataService.get(player)
end

-- ---------------------------------------------------------------------------
-- Автосейв и закрытие сервера
-- ---------------------------------------------------------------------------

function DataService.init()
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			local list = {}
			for player, profile in pairs(profiles) do
				if not profile.Released then
					table.insert(list, player)
				end
			end
			for i, player in ipairs(list) do
				task.spawn(DataService.saveNow, player)
				-- растягиваем запросы, чтобы не упереться в лимиты DataStore
				if i % 5 == 0 then
					task.wait(1)
				end
			end
		end
	end)

	game:BindToClose(function()
		isShuttingDown = true
		local pending = 0
		local all = {}
		for player in pairs(profiles) do
			table.insert(all, player)
		end
		for _, player in ipairs(all) do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local t = 0
		while pending > 0 and t < 25 do
			task.wait(0.2)
			t += 0.2
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Основной путь освобождения — PlayerService; это страховка.
		task.defer(DataService.release, player)
	end)
end

DataService.storeOk = storeOk

return DataService
