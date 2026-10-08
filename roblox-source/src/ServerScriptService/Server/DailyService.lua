--!strict
--[[
	DailyService — ежедневная награда за вход (v2.8): 7-дневный цикл, правило дней — Shared/DailyData.
	Выдача только здесь (Router: ClaimDaily — с лимитом частоты; повторный забор в те же сутки отклоняется).
	DailySeen — клиент сообщает, что окно открылось само: до следующих суток оно больше не всплывает.
	Гемы ежедневки не входят в дневной потолок «Суперсилы» (Config.SUPERPOWER.DAILY_GEM_CAP касается только события).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Locale = require(ReplicatedStorage.Shared.Locale)
local Config = require(ReplicatedStorage.Shared.Config)
local DailyData = require(ReplicatedStorage.Shared.DailyData)
local PetData = require(ReplicatedStorage.Shared.PetData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)

local DailyService = {}

local function today(): number
	return DailyData.today(os.time())
end

local function daily(data: DataService.Data): { [string]: number }
	local d = DailyData.normalize(data.Daily)
	data.Daily = d
	return d
end

local function context(player: Player?, data: DataService.Data): { [string]: any }
	local session = if player then Session.get(player) else nil
	return {
		PerClick = if player then Economy.getPerClick(player, data) else 1,
		Zones = data.Zones,
		Vip = player ~= nil and Economy.isVip(player),
		Premium = session ~= nil and session.Premium == true,
		PremiumGems = Config.PASS_EFFECTS.PREMIUM_DAILY_GEMS,
	}
end

local function autoOpenEnabled(): boolean
	return Workspace:GetAttribute("DailyAutoOpen") ~= false
end

-- Данные для окна: состояние цикла, 7 карточек с конкретными суммами, время до следующих суток
function DailyService.getInfo(data: DataService.Data, player: Player?): { [string]: any }
	local t = today()
	local st = DailyData.state(daily(data), t)
	return {
		CanClaim = st.CanClaim,
		Day = st.Day,
		Claimed = st.Claimed,
		Streak = st.Streak,
		AutoOpen = st.AutoOpen and autoOpenEnabled(),
		SecondsLeft = (t + 1) * DailyData.DAY - os.time(),
		Rewards = DailyData.preview(context(player, data)),
		Vip = player ~= nil and Economy.isVip(player),
	}
end

local function claim(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	local d = daily(data)
	local ctx = context(player, data)
	-- Сначала фиксируем получение (защита от двойного клика и повторного запроса), потом выдаём
	local day = DailyData.advance(d, today())
	if not day then
		return false, "daily.already"
	end
	d.Popup = math.max(d.Popup, d.LastDay)
	local r = DailyData.resolve(day, ctx)
	if r.Coins then
		Economy.addCoins(player, r.Coins, false)
	end
	local gems = (r.Gems or 0) + (r.PremiumGems or 0)
	if gems > 0 then
		Economy.addGems(player, gems)
	end
	if r.Item then
		Economy.addItem(player, r.Item, r.ItemCount or 1)
	end
	if r.Res then
		for res, n in pairs(r.Res) do
			Economy.addResource(player, res, n)
		end
	end
	if r.Pet and PetData.PetsById[r.Pet] then
		Economy.givePetReward(player, r.Pet, "Normal")
	end
	Economy.addBpXp(player, 40 + 10 * math.min(d.Streak, 7))

	local reward = {
		Coins = r.Coins,
		Gems = if gems > 0 then gems else nil,
		Item = r.Item,
		ItemCount = r.ItemCount,
		Res = r.Res,
		Pet = r.Pet,
	}
	local lang = Locale.langOf(player)
	local what = Economy.describe(reward, lang)
	if r.Pet then
		local def = PetData.PetsById[r.Pet]
		what ..= ": " .. Locale.nameIn(lang, def and def.Name or r.Pet)
	end
	Notify.send(player, Locale.tp(player, "daily.reward", { day = day, what = what }), "reward")
	return true, nil
end

-- Окно открылось само: до следующих суток не открывать автоматически
local function seen(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	local d = daily(data)
	d.Popup = today()
	return true, nil
end

function DailyService.init()
	Router.register("ClaimDaily", 1, 2, claim)
	Router.register("DailySeen", 1, 2, seen)
end

return DailyService
