--!strict
-- Оффлайн-доход: пока игрока нет, «команда» приносит часть активного дохода. Награда ждёт на экране входа.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local OfflineService = {}

-- Оценка дохода в секунду: ~2 «клика» в секунду
local ASSUMED_CLICKS_PER_SECOND = 2

-- Вызывается при входе: считает награду за время отсутствия. Возвращает (секунд, монет).
function OfflineService.onJoin(player: Player): (number, number)
	local data = DataService.get(player)
	if not data then
		return 0, 0
	end
	local elapsed = math.max(0, os.time() - (data.LastSeen or os.time()))
	data.LastSeen = os.time()
	local perSecond = Economy.getPerClick(player, data) * ASSUMED_CLICKS_PER_SECOND
	local coins = Formulas.offlineIncome(elapsed, perSecond, Economy.talent(data, "Offline"))
	if coins > 0 then
		data.OfflinePending = (data.OfflinePending or 0) + coins
		Remotes.getEvent("Offline"):FireClient(
			player,
			{ Seconds = math.min(elapsed, Config.OFFLINE_MAX_SECONDS), Coins = data.OfflinePending }
		)
	end
	return elapsed, coins
end

local function claim(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	local pending = data.OfflinePending or 0
	if pending <= 0 then
		return false, "err.nothing_to_claim"
	end
	data.OfflinePending = 0
	Economy.addCoins(player, pending, false)
	Notify.send(player, Locale.m("offline.welcome", { n = pending }), "reward")
	State.markCore(player)
	return true, nil
end

function OfflineService.touch(player: Player)
	local data = DataService.get(player)
	if data then
		data.LastSeen = os.time()
	end
end

function OfflineService.init()
	Router.register("ClaimOffline", 1, 2, claim)
end

return OfflineService
