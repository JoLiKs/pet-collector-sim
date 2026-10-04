--!strict
-- Формулы экономики. Используются и сервером (авторитетно), и клиентом (только для отображения).
local Config = require(script.Parent.Config)
local UpgradeData = require(script.Parent.UpgradeData)

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

return Formulas
