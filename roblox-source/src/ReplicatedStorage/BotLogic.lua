--!strict
--[[
	BotLogic (v3.0) — чистая логика ИИ-ботов (BotService): численность, имена, прокачка. Без Roblox API — покрыто тестами.

	Численность (step):
	  * живых игроков меньше REAL_THRESHOLD → на сервере TARGET ботов (случайно MIN..MAX);
	    при старте сервера боты «уже играют» (быстрое заполнение), дальше по одному уходят и приходят
	    через случайные CHURN секунд, оставаясь в пределах MIN..MAX;
	  * живых игроков REAL_THRESHOLD и больше → боты уходят по одному раз в STEP секунд (1–2 минуты), пока не уйдут все;
	  * живых снова меньше порога → боты возвращаются так же по одному (раз в STEP), до нового TARGET.
	Боты — только NPC-модели: не объекты Player, без DataStore, не в списке игроков и не в рейтингах (docs/BOTS_POLICY.md).
]]
local BotLogic = {}

export type Cfg = {
	MIN: number,
	MAX: number,
	REAL_THRESHOLD: number,
	FILL_GAP: { number },
	CHURN_GAP: { number },
	STEP_GAP: { number },
}

export type Pop = {
	Count: number,
	Target: number,
	Mode: string, -- "idle" | "fill" | "low" | "return" | "drain"
	NextAt: number,
}

function BotLogic.newPop(): Pop
	return { Count = 0, Target = 0, Mode = "idle", NextAt = 0 }
end

local function gap(range: { number }, rnd: () -> number): number
	return range[1] + (range[2] - range[1]) * rnd()
end

-- Один шаг: вернуть действие "join" | "leave" | nil (и сдвинуть Count). rnd() -> [0,1), rint(a,b) -> целое.
function BotLogic.step(
	p: Pop,
	cfg: Cfg,
	now: number,
	real: number,
	rnd: () -> number,
	rint: (number, number) -> number
): string?
	local low = real < cfg.REAL_THRESHOLD
	if low then
		if p.Mode == "idle" then
			-- старт сервера: боты «уже на сервере» — быстро заполняем
			p.Mode = "fill"
			p.Target = rint(cfg.MIN, cfg.MAX)
			p.NextAt = now
		elseif p.Mode == "drain" then
			-- живых стало меньше порога: боты возвращаются по одному
			p.Mode = "return"
			p.Target = rint(cfg.MIN, cfg.MAX)
			p.NextAt = now + gap(cfg.STEP_GAP, rnd)
		end
	elseif p.Mode ~= "drain" then
		-- живых достаточно: уходят по одному раз в 1–2 минуты
		p.Mode = "drain"
		p.NextAt = now + gap(cfg.STEP_GAP, rnd)
	end
	if now < p.NextAt then
		return nil
	end
	if p.Mode == "drain" then
		if p.Count <= 0 then
			p.NextAt = now + gap(cfg.STEP_GAP, rnd)
			return nil
		end
		p.Count -= 1
		p.NextAt = now + gap(cfg.STEP_GAP, rnd)
		return "leave"
	end
	if p.Mode == "fill" or p.Mode == "return" then
		if p.Count < p.Target then
			p.Count += 1
			p.NextAt = now + gap(if p.Mode == "fill" then cfg.FILL_GAP else cfg.STEP_GAP, rnd)
			if p.Count >= p.Target then
				p.Mode = "low"
				p.NextAt = now + gap(cfg.CHURN_GAP, rnd)
			end
			return "join"
		end
		p.Mode = "low"
	end
	-- "low": обычная жизнь сервера — кто-то уходит, кто-то приходит, в пределах MIN..MAX
	p.NextAt = now + gap(cfg.CHURN_GAP, rnd)
	local join: boolean
	if p.Count <= cfg.MIN then
		join = true
	elseif p.Count >= cfg.MAX then
		join = false
	else
		join = rnd() < 0.5
	end
	if join then
		p.Count += 1
		return "join"
	end
	p.Count -= 1
	return "leave"
end

-- ---------------------------------------------------------------------------
-- Имена: правдоподобные ники (имя/слово + иногда цифры). Повторы на сервере исключаются.
-- ---------------------------------------------------------------------------
BotLogic.NAME_A = {
	"Pixel",
	"Lucky",
	"Sunny",
	"Frosty",
	"Ninja",
	"Cosmo",
	"Mango",
	"Shadow",
	"Turbo",
	"Cookie",
	"Milo",
	"Luna",
	"Kira",
	"Zack",
	"Nova",
	"Bunny",
	"Rocky",
	"Sky",
	"Toby",
	"Leo",
	"Mira",
	"Dino",
	"Echo",
	"Peach",
	"Blaze",
	"Coco",
	"Ember",
	"Kiwi",
	"Rex",
	"Tiny",
}
BotLogic.NAME_B = {
	"Fox",
	"Gamer",
	"Cat",
	"Hero",
	"Wolf",
	"Bear",
	"Star",
	"Play",
	"Pro",
	"Panda",
	"Bee",
	"Dash",
	"Bolt",
	"Hunter",
	"Pup",
	"Owl",
	"Toast",
	"Byte",
	"Rider",
	"Puff",
}

function BotLogic.makeName(rint: (number, number) -> number, used: { [string]: boolean }): string
	for _ = 1, 40 do
		local a = BotLogic.NAME_A[rint(1, #BotLogic.NAME_A)]
		local style = rint(1, 4)
		local name: string
		if style == 1 then
			name = a .. BotLogic.NAME_B[rint(1, #BotLogic.NAME_B)]
		elseif style == 2 then
			name = a .. BotLogic.NAME_B[rint(1, #BotLogic.NAME_B)] .. tostring(rint(1, 99))
		elseif style == 3 then
			name = string.lower(a) .. "_" .. string.lower(BotLogic.NAME_B[rint(1, #BotLogic.NAME_B)])
		else
			name = a .. tostring(rint(10, 999))
		end
		if not used[name] then
			used[name] = true
			return name
		end
	end
	local n = "Player" .. tostring(rint(1000, 9999))
	used[n] = true
	return n
end

-- ---------------------------------------------------------------------------
-- Прокачка бота (только в памяти сервера; не сохраняется)
-- ---------------------------------------------------------------------------
BotLogic.REBIRTH_LEVEL = 30
BotLogic.MAX_REBIRTHS = 6

function BotLogic.xpToNext(level: number): number
	return 40 + level * 12
end

-- Добавить опыт: возвращает число полученных уровней
function BotLogic.addXp(b: { Level: number, Xp: number }, xp: number): number
	b.Xp += xp
	local ups = 0
	while b.Xp >= BotLogic.xpToNext(b.Level) and b.Level < BotLogic.REBIRTH_LEVEL do
		b.Xp -= BotLogic.xpToNext(b.Level)
		b.Level += 1
		ups += 1
	end
	return ups
end

function BotLogic.canRebirth(b: { Level: number, Rebirths: number }): boolean
	return b.Level >= BotLogic.REBIRTH_LEVEL and b.Rebirths < BotLogic.MAX_REBIRTHS
end

function BotLogic.rebirth(b: { Level: number, Xp: number, Rebirths: number }): boolean
	if not BotLogic.canRebirth(b) then
		return false
	end
	b.Rebirths += 1
	b.Level = 1
	b.Xp = 0
	return true
end

-- Сколько миров (по порядку ZoneData.List) доступно боту: как у игрока — растёт с уровнем и ребёртами
function BotLogic.zonesOpen(b: { Level: number, Rebirths: number }, total: number): number
	return math.clamp(1 + b.Level // 10 + b.Rebirths, 1, total)
end

-- ---------------------------------------------------------------------------
-- v3.2: доля врагов для ботов (живым игрокам всегда остаются свободные враги)
-- s.MobClaims — сколько ДРУГИХ ботов уже занимают этого врага; s.ZoneClaimed — сколько врагов мира занято ботами;
-- s.ZoneFree — сколько в мире «ничьих» врагов (не били игроки, рядом нет игрока), включая занятые ботами.
-- ---------------------------------------------------------------------------
function BotLogic.canClaim(
	s: { MobClaims: number, ZoneClaimed: number, ZoneFree: number },
	cfg: { [string]: any }
): boolean
	if s.MobClaims >= (cfg.MAX_PER_MOB or 1) then
		return false
	end
	if s.ZoneClaimed >= (cfg.MAX_FIGHTERS_PER_ZONE or 3) then
		return false
	end
	-- после захвата остаётся не меньше RESERVE_FREE свободных (никем не занятых) врагов
	return s.ZoneFree - s.ZoneClaimed - 1 >= (cfg.RESERVE_FREE or 3)
end

-- миры, куда ещё можно пойти: ботов там меньше cap (exempt — без лимита, например хаб)
function BotLogic.roomyZones(
	zones: { string },
	counts: { [string]: number },
	cap: number,
	exempt: string?
): { string }
	local out = {}
	for _, z in ipairs(zones) do
		if z == exempt or (counts[z] or 0) < cap then
			table.insert(out, z)
		end
	end
	return out
end

return BotLogic
