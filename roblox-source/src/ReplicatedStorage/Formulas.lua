--!strict
-- Формулы экономики. Используются и сервером (авторитетно), и клиентом (только для отображения).
local Config = require(script.Parent.Config)
local UpgradeData = require(script.Parent.UpgradeData)
local PetMeta = require(script.Parent.PetMeta)
local TalentData = require(script.Parent.TalentData)

local Formulas = {}

function Formulas.rebirthCost(rebirths: number): number
	local cost = Config.REBIRTH_BASE_COST * (Config.REBIRTH_COST_GROWTH ^ rebirths)
	return math.floor(math.min(cost, Config.MAX_COINS))
end

function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + Config.REBIRTH_MULT_PER * rebirths
end

function Formulas.rebirthGems(rebirths: number): number
	-- rebirths = значение ДО ребёрта
	return Config.REBIRTH_GEMS_BASE + Config.REBIRTH_GEMS_PER * rebirths
end

function Formulas.upgradeCost(id: string, level: number): number?
	local def = UpgradeData.ById[id]
	if not def or level >= def.MaxLevel then
		return nil
	end
	if def.Costs then
		return def.Costs[level + 1]
	end
	return math.floor(def.BaseCost * (def.Growth ^ level))
end

function Formulas.petSlots(slotUpgrade: number, isVip: boolean): number
	local slots = Config.BASE_PET_SLOTS + slotUpgrade
	if isVip then
		slots += Config.PASS_EFFECTS.VIP_EXTRA_SLOTS
	end
	return slots
end

function Formulas.bagSize(bagUpgrade: number): number
	return Config.BASE_BAG_SIZE + bagUpgrade * UpgradeData.BAG_PER_LEVEL
end

function Formulas.clickBase(clickUpgrade: number): number
	return 1 + clickUpgrade * UpgradeData.CLICK_PER_LEVEL
end

function Formulas.upgradeLuck(luckUpgrade: number): number
	return 1 + luckUpgrade * UpgradeData.LUCK_PER_LEVEL
end

function Formulas.walkSpeed(speedUpgrade: number, hasDoubleSpeed: boolean): number
	local speed = Config.BASE_WALKSPEED + speedUpgrade * UpgradeData.SPEED_PER_LEVEL
	if hasDoubleSpeed then
		speed *= Config.PASS_EFFECTS.SPEED_MULT_DOUBLE
	end
	return math.min(speed, Config.MAX_WALKSPEED)
end

-- Очки талантов за N ребёртов: 1 за каждый + бонус +1 за каждый 5-й
function Formulas.talentPoints(rebirths: number): number
	return rebirths * Config.REBIRTH_TALENT_POINTS + rebirths // 5
end

-- Атака игрока (ручной удар): растёт с силой команды, талантами и клинком
function Formulas.playerAttack(teamPower: number, talentBonus: number, bladeBonus: number): number
	local base = math.max(3, teamPower * 0.6)
	return math.floor(base * (1 + talentBonus) * (1 + bladeBonus))
end

-- Урон питомца за удар по врагу: сила * роль * стихия * множители
function Formulas.petDamage(
	power: number,
	role: string,
	petElement: string,
	enemyElement: string?,
	mult: number
): number
	local r = PetMeta.Roles[role]
	local roleMult = r and r.Attack or 1
	return math.max(
		1,
		math.floor(power * roleMult * PetMeta.elementMultiplier(petElement, enemyElement) * mult)
	)
end

-- Оффлайн-доход: elapsed (сек), income — монет/сек в активной игре (оценка), bonus — таланты
function Formulas.offlineIncome(elapsed: number, incomePerSecond: number, bonus: number): number
	local t = math.min(math.max(elapsed, 0), Config.OFFLINE_MAX_SECONDS)
	if t < Config.OFFLINE_MIN_SECONDS then
		return 0
	end
	return math.floor(t * incomePerSecond * Config.OFFLINE_RATE * (1 + bonus))
end

-- Бонус за друзей на сервере (число друзей уже посчитано)
function Formulas.friendBonus(friends: number): number
	return math.min(friends, Config.FRIEND_BONUS_MAX_FRIENDS) * Config.FRIEND_BONUS_PER
end

function Formulas.talent(levels: { [string]: number }, stat: string): number
	return TalentData.bonus(levels, stat)
end

-- Награда за убийство. clicksValue = монет за «клик» зоны у игрока
function Formulas.killCoins(clicksValue: number, enemyCoins: number): number
	return math.max(1, math.floor(clicksValue * enemyCoins * Config.KILL_COIN_BASE_CLICKS))
end

return Formulas
