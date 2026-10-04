--!strict
--[[
	PetMeta — «игровые» свойства питомцев поверх PetData: стихия, роль, способность, варианты,
	уровни/опыт, эволюция, итоговая сила. Чистая логика (без Roblox API) — покрыта тестами.
]]
local PetData = require(script.Parent.PetData)
local Abilities = require(script.Parent.Abilities)

export type PetState = {
	Id: string,
	Level: number?,
	Xp: number?,
	Variant: string?,
	Evo: number?,
	Fav: boolean?,
}

local PetMeta = {}

local c3 = Color3.fromRGB

-- ---------------------------------------------------------------------------------------------
-- Стихии: Water > Fire > Earth > Air > Water (x1.5 по слабому, x0.7 по сильному)
-- ---------------------------------------------------------------------------------------------
PetMeta.Elements = {
	Fire = { Color = c3(255, 110, 50), Icon = "F", Beats = "Earth" },
	Water = { Color = c3(70, 160, 255), Icon = "W", Beats = "Fire" },
	Earth = { Color = c3(130, 190, 70), Icon = "E", Beats = "Air" },
	Air = { Color = c3(190, 225, 245), Icon = "A", Beats = "Water" },
} :: { [string]: { Color: Color3, Icon: string, Beats: string } }
PetMeta.ElementOrder = { "Fire", "Water", "Earth", "Air" }
PetMeta.STRONG = 1.5
PetMeta.WEAK = 0.7

function PetMeta.elementMultiplier(attacker: string?, defender: string?): number
	if not attacker or not defender then
		return 1
	end
	local a = PetMeta.Elements[attacker]
	local d = PetMeta.Elements[defender]
	if not a or not d then
		return 1
	end
	if a.Beats == defender then
		return PetMeta.STRONG
	elseif d.Beats == attacker then
		return PetMeta.WEAK
	end
	return 1
end

-- ---------------------------------------------------------------------------------------------
-- Роли
-- ---------------------------------------------------------------------------------------------
PetMeta.Roles = {
	Fighter = { Color = c3(235, 85, 85), Attack = 1.0, Gather = 0.2, Desc = "Full damage in combat." },
	Collector = {
		Color = c3(255, 208, 70),
		Attack = 0.35,
		Gather = 1.0,
		Desc = "Boosts resource gathering and auto-harvests nodes.",
	},
	Support = {
		Color = c3(100, 220, 255),
		Attack = 0.55,
		Gather = 0.4,
		Desc = "Heals, shields and buffs the team.",
	},
} :: { [string]: { Color: Color3, Attack: number, Gather: number, Desc: string } }
PetMeta.RoleOrder = { "Fighter", "Collector", "Support" }

-- ---------------------------------------------------------------------------------------------
-- Варианты (золотой / радужный / сияющий)
-- ---------------------------------------------------------------------------------------------
PetMeta.Variants = {
	Normal = { Order = 1, Mult = 1, Color = c3(235, 235, 245) },
	Golden = { Order = 2, Mult = 2, Color = c3(255, 208, 70) },
	Rainbow = { Order = 3, Mult = 5, Color = c3(255, 120, 220) },
	Shiny = { Order = 4, Mult = 12, Color = c3(120, 255, 240) },
} :: { [string]: { Order: number, Mult: number, Color: Color3 } }
PetMeta.VariantOrder = { "Normal", "Golden", "Rainbow", "Shiny" }

function PetMeta.variantOf(p: PetState): string
	local v = p.Variant
	if v and PetMeta.Variants[v] then
		return v
	end
	return "Normal"
end

-- ---------------------------------------------------------------------------------------------
-- Таблица «питомец -> стихия / роль / способность»
-- ---------------------------------------------------------------------------------------------
local INFO: { [string]: { string } } = {
	-- Meadow
	bunbun = { "Earth", "Collector", "forager" },
	chirpy = { "Air", "Support", "swift" },
	mossy = { "Water", "Support", "mend" },
	bumblet = { "Air", "Fighter", "gust" },
	sunfox = { "Fire", "Fighter", "fireball" },
	dandy = { "Earth", "Support", "frenzy" },
	-- Forest
	acorny = { "Earth", "Collector", "forager" },
	pinecub = { "Earth", "Fighter", "slayer" },
	owlet = { "Air", "Support", "scholar" },
	mushling = { "Earth", "Collector", "dig" },
	deerling = { "Air", "Support", "ward" },
	elderwood = { "Earth", "Fighter", "quake" },
	-- Desert
	gecko = { "Fire", "Collector", "greed" },
	scarab = { "Earth", "Fighter", "slayer" },
	cactling = { "Earth", "Support", "sturdy" },
	mirage = { "Air", "Fighter", "gust" },
	serpent = { "Fire", "Fighter", "fireball" },
	sphinx = { "Fire", "Support", "frenzy" },
	-- Frost
	snowpup = { "Water", "Fighter", "slayer" },
	penguin = { "Water", "Collector", "forager" },
	yeti = { "Water", "Support", "sturdy" },
	aurora = { "Water", "Support", "mend" },
	stag = { "Air", "Support", "ward" },
	blizzdrake = { "Water", "Fighter", "tidal" },
	-- Volcano
	embermouse = { "Fire", "Collector", "greed" },
	lavaslug = { "Fire", "Collector", "dig" },
	magmashell = { "Fire", "Support", "sturdy" },
	cinderwolf = { "Fire", "Fighter", "fireball" },
	phoenix = { "Fire", "Support", "mend" },
	infernodrake = { "Fire", "Fighter", "frenzy" },
	-- Crystal / Cosmic
	slime = { "Water", "Collector", "lucky" },
	prismcat = { "Air", "Support", "lucky" },
	starbunny = { "Air", "Fighter", "gust" },
	cosmicwhale = { "Water", "Fighter", "tidal" },
	nebuladrake = { "Air", "Fighter", "frenzy" },
	-- Lunar (event egg)
	moonbun = { "Water", "Support", "lucky" },
	lunafox = { "Air", "Fighter", "gust" },
	eclipsewolf = { "Fire", "Fighter", "frenzy" },
	-- Battle pass
	seasonowl = { "Air", "Support", "scholar" },
}

function PetMeta.info(petId: string): { Element: string, Role: string, Ability: string }
	local i = INFO[petId]
	if not i then
		return { Element = "Earth", Role = "Fighter", Ability = "slayer" }
	end
	return { Element = i[1], Role = i[2], Ability = i[3] }
end

function PetMeta.element(petId: string): string
	return PetMeta.info(petId).Element
end
function PetMeta.role(petId: string): string
	return PetMeta.info(petId).Role
end
function PetMeta.ability(petId: string): Abilities.Ability?
	return Abilities.ById[PetMeta.info(petId).Ability]
end

-- ---------------------------------------------------------------------------------------------
-- Уровни, опыт, эволюция
-- ---------------------------------------------------------------------------------------------
PetMeta.MAX_EVO = 3
PetMeta.EVO_POWER = { [0] = 1, [1] = 1.6, [2] = 2.5, [3] = 4 }
PetMeta.EVO_NAMES = { [0] = "", [1] = "Awakened ", [2] = "Ascended ", [3] = "Celestial " }
PetMeta.LEVEL_POWER_STEP = 0.06 -- +6% силы за уровень
PetMeta.EVO_COST = {
	[0] = { Coins = 5000, Essence = 10 },
	[1] = { Coins = 80000, Essence = 40 },
	[2] = { Coins = 1500000, Essence = 150 },
}

function PetMeta.maxLevel(evo: number?): number
	return 10 + 10 * (evo or 0)
end

function PetMeta.xpForNext(level: number): number
	return math.floor(20 * level ^ 1.5)
end

-- Добавляет опыт; возвращает новые (level, xp, levelsGained). На максимуме опыт не копится.
function PetMeta.addXp(p: PetState, amount: number): (number, number, number)
	local level = p.Level or 1
	local xp = (p.Xp or 0) + math.max(0, amount)
	local cap = PetMeta.maxLevel(p.Evo)
	local gained = 0
	while level < cap and xp >= PetMeta.xpForNext(level) do
		xp -= PetMeta.xpForNext(level)
		level += 1
		gained += 1
	end
	if level >= cap then
		xp = 0
	end
	return level, xp, gained
end

function PetMeta.canEvolve(p: PetState): (boolean, string?)
	local evo = p.Evo or 0
	if evo >= PetMeta.MAX_EVO then
		return false, "Already at maximum evolution"
	end
	if (p.Level or 1) < PetMeta.maxLevel(evo) then
		return false, ("Reach level %d first"):format(PetMeta.maxLevel(evo))
	end
	return true, nil
end

function PetMeta.evoCost(evo: number): { Coins: number, Essence: number }?
	return PetMeta.EVO_COST[evo]
end

function PetMeta.abilityScale(evo: number?): number
	return 1 + 0.25 * (evo or 0)
end

-- Итоговая сила питомца (идёт в формулу монет, урон и ценность)
function PetMeta.power(p: PetState): number
	local base = PetData.PetsById[p.Id] and PetData.PetsById[p.Id].Power or 0
	local level = p.Level or 1
	local v = PetMeta.Variants[PetMeta.variantOf(p)].Mult
	local evo = PetMeta.EVO_POWER[p.Evo or 0] or 1
	return base * v * (1 + PetMeta.LEVEL_POWER_STEP * (level - 1)) * evo
end

function PetMeta.displayName(p: PetState): string
	local def = PetData.PetsById[p.Id]
	local name = def and def.Name or p.Id
	local variant = PetMeta.variantOf(p)
	local prefix = if variant == "Normal" then "" else variant .. " "
	return PetMeta.EVO_NAMES[p.Evo or 0] .. prefix .. name
end

function PetMeta.sellValue(p: PetState): number
	return math.max(1, math.floor(PetMeta.power(p) * 40))
end

-- Стоимость питомца для обмена (бот-торговец сравнивает «ценности»)
function PetMeta.tradeValue(p: PetState): number
	local def = PetData.PetsById[p.Id]
	local rarity = def and PetData.Rarities[def.Rarity].Order or 1
	return math.floor(PetMeta.power(p) * (1 + rarity * 0.25) * 60)
end

-- ---------------------------------------------------------------------------------------------
-- Слияние 3 -> 1
-- ---------------------------------------------------------------------------------------------
PetMeta.FUSE_COUNT = 3
PetMeta.FUSE_CHANCE = { Normal = 0.30, Golden = 0.20, Rainbow = 0.12, Shiny = 0 }
PetMeta.FUSE_SHINY_BONUS = 0.03 -- шанс сразу «Shiny» при любом слиянии (кроме Shiny)
PetMeta.CATALYST_BONUS = 0.15

-- roll1, roll2 ∈ [0,1). Возвращает вариант результата.
function PetMeta.fuseVariant(inputVariant: string, roll1: number, roll2: number, bonus: number?): string
	if inputVariant == "Shiny" then
		return "Shiny"
	end
	if roll1 < PetMeta.FUSE_SHINY_BONUS + (bonus or 0) * 0.1 then
		return "Shiny"
	end
	local chance = (PetMeta.FUSE_CHANCE[inputVariant] or 0) + (bonus or 0)
	if roll2 < chance then
		local order = PetMeta.Variants[inputVariant].Order
		return PetMeta.VariantOrder[math.min(order + 1, #PetMeta.VariantOrder)]
	end
	return inputVariant
end

-- Проверка трёх питомцев перед слиянием. pets — массив PetState (без Fav).
function PetMeta.canFuse(pets: { PetState }): (boolean, string?)
	if #pets ~= PetMeta.FUSE_COUNT then
		return false, "Choose exactly 3 pets"
	end
	local first = pets[1]
	for i = 2, #pets do
		local p = pets[i]
		if p.Id ~= first.Id or PetMeta.variantOf(p) ~= PetMeta.variantOf(first) then
			return false, "Pets must be the same species and variant"
		end
	end
	for _, p in ipairs(pets) do
		if p.Fav then
			return false, "Unfavorite pets before fusing"
		end
	end
	return true, nil
end

return PetMeta
