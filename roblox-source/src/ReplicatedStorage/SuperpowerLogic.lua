--!strict
--[[
	SuperpowerLogic — чистая логика события «Суперсила / Охота» (без инстансов, тестируется в luau).
	Сервис (Server/SuperpowerService) вызывает эти функции; баланс — Config.SUPERPOWER.
	  * timing      — интервал/длительность/первый запуск с ускорением для тестов (Workspace.SuperpowerTimeScale);
	  * pick        — выбор суперигрока: только подходящие, не тот же, что в прошлый раз (если есть выбор);
	  * maxHp, hunterHit, petHit — PvP-HP цели и урон охотников (с потолком доли HP за удар);
	  * canHit      — проверки удара (охота идёт, не по себе, дистанция, кулдаун);
	  * stopRewards / surviveRewards — распределение наград по вкладу (анти-AFK: минимум урона, ручные удары,
	                  активность суперигрока; v2.4);
	  * capGems     — дневной потолок гемов из события.
]]
local SuperpowerLogic = {}

export type Candidate = { Key: string, Eligible: boolean, IsBot: boolean? }
export type Reward = {
	Clicks: number,
	Gems: number,
	Essence: number,
	BpXp: number?,
	RareChance: number,
	Share: number,
	K: number,
	LastHit: boolean,
}

-- Тайминги с ускорением (scale ≥ 1): длительность никогда не доходит до следующего выбора
function SuperpowerLogic.timing(cfg: any, scale: number?): (number, number, number)
	local s = math.clamp(tonumber(scale) or 1, 1, 60)
	local interval = cfg.INTERVAL / s
	local duration = math.min(cfg.DURATION, cfg.INTERVAL - cfg.GAP) / s
	local first = cfg.FIRST_DELAY / s
	return interval, duration, first
end

-- Хватает ли участников (живые игроки + боты) для запуска
function SuperpowerLogic.enoughPlayers(cfg: any, participants: number): boolean
	return participants >= math.max(2, cfg.MIN_PLAYERS)
end

-- rngInt(n) -> целое 1..n
function SuperpowerLogic.pick(
	candidates: { Candidate },
	lastKey: string?,
	rngInt: (number) -> number
): string?
	local pool: { string } = {}
	for _, c in ipairs(candidates) do
		if c.Eligible then
			table.insert(pool, c.Key)
		end
	end
	if #pool > 1 and lastKey then
		for i, k in ipairs(pool) do
			if k == lastKey then
				table.remove(pool, i)
				break
			end
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[math.clamp(rngInt(#pool), 1, #pool)]
end

-- Демо с ботами: с шансом humanChance выбираем живого игрока, иначе бота (повтор прошлого — только без выбора)
function SuperpowerLogic.pickWithBots(
	candidates: { Candidate },
	lastKey: string?,
	rngNumber: () -> number,
	rngInt: (number) -> number,
	humanChance: number
): string?
	local humans, bots = {}, {}
	for _, c in ipairs(candidates) do
		if c.Eligible then
			table.insert(if c.IsBot then bots else humans, c)
		end
	end
	if #humans == 0 or #bots == 0 then
		return SuperpowerLogic.pick(candidates, lastKey, rngInt)
	end
	local group = if rngNumber() < humanChance then humans else bots
	-- если в выбранной группе единственный кандидат — прошлый суперигрок, берём другую группу
	if #group == 1 and group[1].Key == lastKey then
		group = if group == humans then bots else humans
	end
	return SuperpowerLogic.pick(group, lastKey, rngInt)
end

function SuperpowerLogic.maxHp(cfg: any, hunters: number): number
	return math.floor(cfg.HP_BASE + cfg.HP_PER_HUNTER * math.max(1, hunters))
end

local function powerFactor(cfg: any, power: number): number
	return 1 + cfg.HIT_POWER_K * math.log(1 + math.max(0, power))
end

-- Урон удара охотника: растёт с силой команды медленно (логарифм), не больше MAX_HIT_SHARE от PvP-HP
function SuperpowerLogic.hunterHit(cfg: any, power: number, maxHp: number): number
	local dmg = cfg.HIT_BASE * powerFactor(cfg, power)
	return math.max(1, math.floor(math.min(dmg, cfg.MAX_HIT_SHARE * maxHp)))
end

-- Урон питомцев охотника за один тик боя
function SuperpowerLogic.petHit(cfg: any, pets: number, power: number, maxHp: number): number
	if pets <= 0 then
		return 0
	end
	local dmg = cfg.PET_HIT * pets * powerFactor(cfg, power)
	return math.max(1, math.floor(math.min(dmg, cfg.PET_MAX_PER_TICK * maxHp)))
end

export type RoundView = { Active: boolean, TargetKey: string, Done: boolean? }

-- Можно ли ударить суперигрока: (ok, причина)
function SuperpowerLogic.canHit(
	cfg: any,
	round: RoundView?,
	attackerKey: string,
	now: number,
	dist: number,
	reach: number?,
	lastHitAt: number?
): (boolean, string?)
	if not round or not round.Active or round.Done then
		return false, "inactive" -- никакого PvP вне охоты
	end
	if attackerKey == round.TargetKey then
		return false, "self"
	end
	if dist ~= dist or dist > cfg.HIT_RANGE + (reach or 0) then
		return false, "far"
	end
	if lastHitAt and now - lastHitAt < cfg.HIT_COOLDOWN then
		return false, "cooldown"
	end
	return true, nil
end

function SuperpowerLogic.minDamage(cfg: any, maxHp: number): number
	return math.ceil(cfg.MIN_DAMAGE_SHARE * maxHp)
end

local function total(damage: { [string]: number }): (number, number)
	local sum, n = 0, 0
	for _, d in pairs(damage) do
		if d > 0 then
			sum += d
			n += 1
		end
	end
	return sum, n
end

--[[ Цель остановлена. damage — урон всех участников (игроки и боты), humans — ключи живых игроков (награды только им).
	Возвращает (награды по ключу, AFK-ключи без награды). Вклад k = доля урона × число нанёсших урон, в [K_MIN, K_MAX];
	быстрая остановка (timeLeftFrac — доля оставшегося времени) даёт до +SPEED_BONUS. ]]
function SuperpowerLogic.stopRewards(
	cfg: any,
	damage: { [string]: number },
	maxHp: number,
	lastHitKey: string?,
	timeLeftFrac: number,
	humans: { [string]: boolean },
	active: { [string]: boolean }? -- охотники с ручными ударами (nil — все); без них урон питомцев не награждается
): ({ [string]: Reward }, { [string]: boolean })
	local sum, hunters = total(damage)
	local out: { [string]: Reward } = {}
	local afk: { [string]: boolean } = {}
	local minDmg = SuperpowerLogic.minDamage(cfg, maxHp)
	local speed = 1 + cfg.SPEED_BONUS * math.clamp(timeLeftFrac, 0, 1)
	local base = cfg.STOP_REWARD
	for key in pairs(humans) do
		local d = damage[key] or 0
		if d < minDmg or sum <= 0 or (active ~= nil and not active[key]) then
			afk[key] = true
		else
			local share = d / sum
			local k = math.clamp(share * hunters, cfg.STOP_K_MIN, cfg.STOP_K_MAX)
			local r: Reward = {
				Clicks = math.floor(base.Clicks * k * speed),
				Gems = math.max(1, math.floor(base.Gems * k * speed + 0.5)),
				Essence = math.max(1, math.floor(base.Essence * k + 0.5)),
				RareChance = math.min(0.5, base.RareChance * k),
				Share = share,
				K = k,
				LastHit = key == lastHitKey,
			}
			if r.LastHit then
				local b = cfg.LAST_HIT_BONUS
				r.Clicks += b.Clicks
				r.Gems += b.Gems
				r.Essence += b.Essence
			end
			out[key] = r
		end
	end
	return out, afk
end

-- Суперигрок продержался: крупная награда ему, утешительная — охотникам, нанёсшим минимум урона
function SuperpowerLogic.surviveRewards(
	cfg: any,
	superKey: string,
	damage: { [string]: number },
	maxHp: number,
	humans: { [string]: boolean },
	active: { [string]: boolean }?, -- охотники с ручными ударами (nil — все)
	superActive: boolean?, -- false: суперигрок стоял (AFK) — награды нет
	contested: boolean? -- false: никто не охотился — малая награда SURVIVE_UNCONTESTED
): ({ [string]: Reward }, { [string]: boolean })
	local out: { [string]: Reward } = {}
	local afk: { [string]: boolean } = {}
	local minDmg = SuperpowerLogic.minDamage(cfg, maxHp)
	for key in pairs(humans) do
		if key == superKey then
			if superActive == false then
				continue
			end
			local s = if contested == false and cfg.SURVIVE_UNCONTESTED
				then cfg.SURVIVE_UNCONTESTED
				else cfg.SURVIVE_REWARD
			out[key] = {
				Clicks = s.Clicks,
				Gems = s.Gems,
				Essence = s.Essence,
				BpXp = s.BpXp,
				RareChance = 0,
				Share = 0,
				K = 1,
				LastHit = false,
			}
		elseif (damage[key] or 0) >= minDmg and (active == nil or active[key] == true) then
			local c = cfg.CONSOLATION
			out[key] = {
				Clicks = c.Clicks,
				Gems = c.Gems,
				Essence = 0,
				RareChance = 0,
				Share = 0,
				K = 0,
				LastHit = false,
			}
		else
			afk[key] = true
		end
	end
	return out, afk
end

-- Дневной потолок гемов из события: сколько из want можно выдать, если сегодня уже выдано already
function SuperpowerLogic.capGems(cfg: any, already: number, want: number): number
	local cap = cfg.DAILY_GEM_CAP
	if type(cap) ~= "number" then
		return want
	end
	return math.max(0, math.min(want, cap - math.max(0, already)))
end

return SuperpowerLogic
