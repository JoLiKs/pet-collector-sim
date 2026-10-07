--!strict
-- Батл-пасс сезона: бесплатные и премиум-награды (премиум = геймпасс BATTLE_PASS).
local BattlePassData = {}

export type Reward = {
	Coins: number?,
	Gems: number?,
	Res: { [string]: number }?,
	Item: string?,
	ItemCount: number?,
	Pet: string?,
	Label: string?,
}

BattlePassData.Season = 1
BattlePassData.Name = "Season of Embers"
BattlePassData.MaxLevel = 30

function BattlePassData.xpForLevel(level: number): number
	return 100 + 15 * (level - 1)
end

-- Накопленный опыт -> (уровень, опыт внутри уровня, нужно до следующего)
-- v2.4 (аудит М1): сброс прогресса при смене сезона — общий для начисления XP, клейма и входа в игру.
-- Возвращает true, если сезон сменился.
function BattlePassData.syncSeason(bp: { [string]: any }): boolean
	if bp.Season == BattlePassData.Season then
		return false
	end
	bp.Season = BattlePassData.Season
	bp.Xp = 0
	bp.ClaimedFree = {}
	bp.ClaimedPremium = {}
	return true
end

function BattlePassData.progress(totalXp: number): (number, number, number)
	local level = 0
	local xp = math.max(0, totalXp)
	while level < BattlePassData.MaxLevel do
		local need = BattlePassData.xpForLevel(level + 1)
		if xp < need then
			return level, xp, need
		end
		xp -= need
		level += 1
	end
	return level, 0, 0
end

local FREE: { [number]: Reward } = {}
local PREMIUM: { [number]: Reward } = {}
for lv = 1, BattlePassData.MaxLevel do
	if lv % 5 == 0 then
		FREE[lv] = { Gems = 20 + lv, Label = "Gem Cache" }
	elseif lv % 3 == 0 then
		FREE[lv] = { Res = { Wood = 5 + lv, Herb = 3 + lv // 2 }, Label = "Supplies" }
	else
		FREE[lv] = { Coins = 300 * lv * lv, Label = "Coins" }
	end
	if lv % 10 == 0 then
		PREMIUM[lv] = { Gems = 100, Item = "catalyst", ItemCount = 2, Label = "Grand Chest" }
	elseif lv % 5 == 0 then
		PREMIUM[lv] = { Gems = 40 + lv, Item = "luck_potion", ItemCount = 1, Label = "Premium Chest" }
	elseif lv % 2 == 0 then
		PREMIUM[lv] = { Item = "xp_treat", ItemCount = 4, Coins = 500 * lv * lv, Label = "Treats & Coins" }
	else
		PREMIUM[lv] =
			{ Res = { Ore = 4 + lv // 2, Crystal = 1 + lv // 6 }, Gems = 10, Label = "Rare Materials" }
	end
end
PREMIUM[15] = { Pet = "seasonowl", Gems = 50, Label = "Season Owl (pet)" }
PREMIUM[30] = { Gems = 300, Item = "blade", ItemCount = 1, Label = "Ember Crown Chest" }
BattlePassData.Free = FREE
BattlePassData.Premium = PREMIUM

function BattlePassData.reward(track: string, level: number): Reward?
	if track == "Premium" then
		return PREMIUM[level]
	end
	return FREE[level]
end

-- Цена пропуска уровней продуктом BP_SKIP: сколько уровней даёт покупка
BattlePassData.SKIP_LEVELS = 5

return BattlePassData
