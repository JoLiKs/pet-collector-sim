--!strict
-- Ежедневные награды (цикл из 7 дней). День считается по UTC: floor(os.time() / 86400).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage.Shared.Locale)
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)

local DailyService = {}

local DAY = 86400

local function today(): number
	return os.time() // DAY
end

-- Данные для UI: можно ли забрать, какой день цикла следующий, сколько до сброса
function DailyService.getInfo(
	data: DataService.Data
): { CanClaim: boolean, Day: number, Streak: number, SecondsLeft: number }
	local t = today()
	local daily = data.Daily
	local canClaim = daily.LastDay < t
	local streakIfClaimed = if daily.LastDay == t - 1 then daily.Streak + 1 else 1
	if not canClaim then
		streakIfClaimed = daily.Streak + 1
	end
	local day = ((streakIfClaimed - 1) % #Config.DAILY_REWARDS) + 1
	return {
		CanClaim = canClaim,
		Day = day,
		Streak = daily.Streak,
		SecondsLeft = (t + 1) * DAY - os.time(),
	}
end

local function claim(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	local t = today()
	if data.Daily.LastDay >= t then
		return false, "daily.already"
	end
	local streak = if data.Daily.LastDay == t - 1 then data.Daily.Streak + 1 else 1
	local day = ((streak - 1) % #Config.DAILY_REWARDS) + 1
	local reward = Config.DAILY_REWARDS[day]

	-- Сначала фиксируем получение (защита от двойного клика), потом выдаём
	data.Daily.LastDay = t
	data.Daily.Streak = streak

	local mult = if Economy.isVip(player) then Config.PASS_EFFECTS.VIP_DAILY_MULT else 1
	local gems = reward.Gems * mult
	local s = Session.get(player)
	if s and s.Premium then
		gems += Config.PASS_EFFECTS.PREMIUM_DAILY_GEMS
	end
	local coins = Economy.getPerClick(player, data) * reward.Clicks * mult

	Economy.addGems(player, gems)
	Economy.addCoins(player, coins, false)

	local text = Locale.tp(player, "daily.reward", { day = day, n = gems })
	if reward.Luck2Minutes then
		Economy.addLuckBoost(data, "Luck2", reward.Luck2Minutes * 60 * mult)
		text ..= Locale.tp(player, "daily.reward_luck", { n = reward.Luck2Minutes * mult })
	end
	Economy.addBpXp(player, 40 + 10 * math.min(streak, 7))
	Notify.send(player, text, "reward")
	return true, nil
end

function DailyService.init()
	Router.register("ClaimDaily", 1, 2, claim)
end

return DailyService
