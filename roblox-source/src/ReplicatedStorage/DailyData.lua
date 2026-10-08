--!strict
--[[
	DailyData (v2.8) — ежедневная награда за вход: 7-дневный цикл. Чистая логика (сервер, клиент, тесты).

	Правило дней (дружелюбное для детей):
	  * День — UTC-сутки на сервере: floor(os.time() / 86400). Одна награда в сутки.
	  * Пропуск дня НЕ сбрасывает прогресс: в следующий вход берётся следующий по счёту день цикла
	    (пропустил день 3 — завтра получишь день 3, а не начнёшь с первого).
	  * После дня 7 цикл начинается заново с дня 1.
	  * Streak — сколько дней подряд игрок заходил (только для информации и бонуса опыта пропуска);
	    при пропуске Streak обнуляется, а цикл — нет.

	data.Daily = { LastDay, Streak, Cycle, Popup }
	  LastDay — UTC-день последнего получения; Cycle — сколько дней текущего цикла уже получено (0..7);
	  Popup — UTC-день, когда окно последний раз открывалось само (раз в сутки).

	Награды — только предметы игры, все суммы проходят через resolve():
	  монеты масштабируются по силе сбора (как остальные награды), билет и питомец — от лучшего открытого мира.
]]
local PetData = require(script.Parent.PetData)

local DailyData = {}

DailyData.CYCLE = 7
DailyData.DAY = 86400
DailyData.VIP_MULT = 2 -- VIP: x2 (кроме самого питомца дня 7)

export type Def = { [string]: any }

-- Kind: Coins (Clicks — сборов текущей силы), Gems, Ticket (билет на яйцо лучшего открытого мира),
-- Item (предмет из RecipeData), Res (ресурс), Chest (тайный сундук: питомец Epic лучшего яйца + гемы)
DailyData.Rewards = {
	{ Kind = "Coins", Clicks = 500, Color = "Yellow" },
	{ Kind = "Gems", Gems = 20, Color = "Orange" },
	{ Kind = "Ticket", Count = 1, Color = "Red" },
	{ Kind = "Item", Item = "luck_potion", Count = 2, Color = "Indigo" },
	{ Kind = "Res", Res = "Crystal", Count = 4, Color = "Pink" },
	{ Kind = "Res", Res = "Essence", Count = 6, Color = "Lime" },
	{ Kind = "Chest", Gems = 40, Rarity = "Epic", Color = "Rainbow" },
} :: { Def }

-- Миры по порядку и их «обычные» яйца (за монеты); билеты есть только у части яиц
local ZONE_ORDER = { "Meadow", "Forest", "Desert", "Frost", "Volcano" }
local TICKETS = { Meadow = "ticket_MeadowEgg", Forest = "ticket_ForestEgg", Frost = "ticket_FrostEgg" }

function DailyData.today(now: number?): number
	return (now or os.time()) // DailyData.DAY
end

-- Нормализует таблицу Daily (старые/битые сохранения) — используется миграцией и сервером
function DailyData.normalize(d: any): { [string]: number }
	local function num(v: any, lo: number, hi: number): number
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			return lo
		end
		return math.clamp(math.floor(v), lo, hi)
	end
	if type(d) ~= "table" then
		d = {}
	end
	local out = {
		LastDay = num(d.LastDay, 0, 1e9),
		Streak = num(d.Streak, 0, 1e9),
		Cycle = 0,
		Popup = num(d.Popup, 0, 1e9),
	}
	if d.Cycle == nil then
		-- v2.8: до 7-дневного окна хранился только Streak (дней подряд). Переводим в позицию цикла:
		-- Streak 3 -> получены дни 1..3; Streak 7, 14… -> цикл пройден целиком.
		if out.Streak > 0 then
			local c = out.Streak % DailyData.CYCLE
			out.Cycle = if c == 0 then DailyData.CYCLE else c
		end
	else
		out.Cycle = num(d.Cycle, 0, DailyData.CYCLE)
	end
	return out
end

-- Состояние для UI и сервера.
--   CanClaim — сегодняшняя награда ещё не получена;
--   Claimed — сколько карточек текущего цикла показать полученными (0..7);
--   Day — номер карточки «сегодня» (которую можно забрать или которую забрали сегодня);
--   AutoOpen — окно должно открыться само (раз в сутки, пока награда не получена).
function DailyData.state(d: { [string]: number }, today: number)
	local canClaim = d.LastDay < today
	local claimed = d.Cycle
	local day
	if canClaim then
		if claimed >= DailyData.CYCLE then
			claimed = 0 -- прошлый цикл завершён — показываем новый
		end
		day = claimed + 1
	else
		day = math.max(1, claimed)
	end
	return {
		CanClaim = canClaim,
		Claimed = claimed,
		Day = day,
		AutoOpen = canClaim and d.Popup < today,
		Streak = d.Streak,
	}
end

-- Фиксирует получение награды в таблице Daily (до выдачи — защита от двойного забора).
-- Возвращает номер выданного дня или nil, если сегодня уже получено.
function DailyData.advance(d: { [string]: number }, today: number): number?
	if d.LastDay >= today then
		return nil
	end
	local cycle = if d.Cycle >= DailyData.CYCLE then 0 else d.Cycle
	cycle += 1
	d.Streak = if d.LastDay == today - 1 then d.Streak + 1 else 1
	d.LastDay = today
	d.Cycle = cycle
	return cycle
end

-- Лучший открытый мир (по порядку миров)
local function bestZone(zones: { [string]: any }?): string
	local best = "Meadow"
	if zones then
		for _, z in ipairs(ZONE_ORDER) do
			if zones[z] then
				best = z
			end
		end
	end
	return best
end
DailyData.bestZone = bestZone

-- Билет на яйцо лучшего открытого мира, у которого есть билеты
function DailyData.ticketFor(zones: { [string]: any }?): string
	local item = TICKETS.Meadow
	local top = bestZone(zones)
	for _, z in ipairs(ZONE_ORDER) do
		if TICKETS[z] and (z == "Meadow" or (zones and zones[z])) then
			item = TICKETS[z]
		end
		if z == top then
			break
		end
	end
	return item
end

-- Питомец тайного сундука: питомец нужной редкости из яйца лучшего открытого мира
-- (детерминированно — это подарок, а не лотерея)
function DailyData.chestPet(zones: { [string]: any }?, rarity: string?): string
	local want = rarity or "Epic"
	local zone = bestZone(zones)
	for _, egg in ipairs(PetData.Eggs) do
		if egg.Zone == zone and egg.Currency == "Coins" then
			for _, ep in ipairs(egg.Pets) do
				local def = PetData.PetsById[ep.Id]
				if def and def.Rarity == want then
					return def.Id
				end
			end
		end
	end
	return "sunfox"
end

-- Конкретная награда дня для игрока.
-- ctx = { PerClick, Zones, Vip, Premium, PremiumGems }
-- Результат: { Day, Kind, Icon, Amount, Coins?, Gems?, Item?, ItemCount?, Res?, Pet?, Vip }
function DailyData.resolve(day: number, ctx: { [string]: any })
	local def = DailyData.Rewards[day] or DailyData.Rewards[1]
	local mult = if ctx.Vip then DailyData.VIP_MULT else 1
	local r: { [string]: any } = { Day = day, Kind = def.Kind, Color = def.Color, Vip = ctx.Vip == true }
	if def.Kind == "Coins" then
		local per = math.max(1, tonumber(ctx.PerClick) or 1)
		r.Coins = math.floor(per * def.Clicks * mult)
		r.Icon, r.Amount = "Coin", r.Coins
	elseif def.Kind == "Gems" then
		r.Gems = def.Gems * mult
		r.Icon, r.Amount = "Gem", r.Gems
	elseif def.Kind == "Ticket" then
		r.Item = DailyData.ticketFor(ctx.Zones)
		r.ItemCount = def.Count * mult
		r.Icon, r.Amount = r.Item, r.ItemCount
	elseif def.Kind == "Item" then
		r.Item = def.Item
		r.ItemCount = def.Count * mult
		r.Icon, r.Amount = r.Item, r.ItemCount
	elseif def.Kind == "Res" then
		r.Res = { [def.Res] = def.Count * mult }
		r.Icon, r.Amount = def.Res, def.Count * mult
	elseif def.Kind == "Chest" then
		r.Pet = DailyData.chestPet(ctx.Zones, def.Rarity)
		r.Gems = def.Gems * mult
		r.Icon, r.Amount = "Mystery", 1
	end
	if ctx.Premium and (ctx.PremiumGems or 0) > 0 then
		r.PremiumGems = ctx.PremiumGems
	end
	return r
end

-- Все 7 наград (для карточек окна)
function DailyData.preview(ctx: { [string]: any })
	local list = {}
	for day = 1, DailyData.CYCLE do
		list[day] = DailyData.resolve(day, ctx)
	end
	return list
end

return DailyData
