--!strict
-- Враги и боссы. Здоровье = ZoneData.Hp * HpMult (боссы — большой множитель). Награды масштабируются зоной.
local ZoneData = require(script.Parent.ZoneData)

export type EnemyDef = {
	Id: string,
	Name: string,
	Zone: string,
	Boss: boolean,
	HpMult: number,
	DamageMult: number, -- множитель урона по игроку (зона задаёт базу)
	Size: number,
	Color: Color3,
	Eye: Color3,
	Shape: string, -- "Ball" | "Block" | "Tall"
	Coins: number, -- множитель к «клику» зоны
	Xp: number, -- множитель опыта питомцам
	Essence: number, -- шанс/кол-во эссенции
	Drops: { { Res: string, Chance: number, Min: number, Max: number } },
}

local EnemyData = {}
local c3 = Color3.fromRGB

local function e(
	id,
	name,
	zone,
	boss,
	hpMult,
	dmg,
	size,
	color,
	eye,
	shape,
	coins,
	xp,
	essence,
	drops
): EnemyDef
	return {
		Id = id,
		Name = name,
		Zone = zone,
		Boss = boss,
		HpMult = hpMult,
		DamageMult = dmg,
		Size = size,
		Color = color,
		Eye = eye,
		Shape = shape,
		Coins = coins,
		Xp = xp,
		Essence = essence,
		Drops = drops,
	}
end

EnemyData.List = {
	e(
		"slimeling",
		"Slimeling",
		"Meadow",
		false,
		1,
		0.6,
		3,
		c3(120, 220, 120),
		c3(20, 40, 20),
		"Ball",
		8,
		1,
		0.05,
		{ { Res = "Herb", Chance = 0.5, Min = 1, Max = 2 } }
	),
	e(
		"boarlet",
		"Wild Boarlet",
		"Meadow",
		false,
		1.6,
		0.9,
		3.4,
		c3(170, 110, 80),
		c3(250, 240, 220),
		"Block",
		12,
		1.4,
		0.08,
		{ { Res = "Wood", Chance = 0.5, Min = 1, Max = 2 } }
	),
	e(
		"meadow_king",
		"Meadow King",
		"Meadow",
		true,
		14,
		1.4,
		7,
		c3(255, 214, 90),
		c3(60, 30, 0),
		"Tall",
		120,
		12,
		1,
		{ { Res = "Crystal", Chance = 1, Min = 1, Max = 2 } }
	),
	e(
		"wisp",
		"Forest Wisp",
		"Forest",
		false,
		1,
		0.7,
		2.6,
		c3(190, 255, 220),
		c3(20, 90, 60),
		"Ball",
		8,
		1,
		0.06,
		{ { Res = "Herb", Chance = 0.6, Min = 1, Max = 3 } }
	),
	e(
		"mossgolem",
		"Moss Golem",
		"Forest",
		false,
		2.2,
		1,
		4,
		c3(80, 130, 70),
		c3(255, 255, 140),
		"Block",
		14,
		1.6,
		0.1,
		{
			{ Res = "Stone", Chance = 0.5, Min = 1, Max = 2 },
			{ Res = "Wood", Chance = 0.4, Min = 1, Max = 2 },
		}
	),
	e(
		"elder_treant",
		"Elder Treant",
		"Forest",
		true,
		16,
		1.5,
		8,
		c3(110, 80, 50),
		c3(120, 255, 120),
		"Tall",
		140,
		14,
		1.2,
		{ { Res = "Crystal", Chance = 1, Min = 2, Max = 3 } }
	),
	e(
		"scorpling",
		"Scorpling",
		"Desert",
		false,
		1,
		0.8,
		3,
		c3(220, 170, 90),
		c3(80, 20, 0),
		"Block",
		9,
		1,
		0.06,
		{ { Res = "Ore", Chance = 0.45, Min = 1, Max = 2 } }
	),
	e(
		"sandwraith",
		"Sand Wraith",
		"Desert",
		false,
		2,
		1.1,
		3.4,
		c3(240, 210, 150),
		c3(120, 40, 160),
		"Tall",
		14,
		1.5,
		0.1,
		{ { Res = "Herb", Chance = 0.5, Min = 1, Max = 2 } }
	),
	e(
		"sand_titan",
		"Sand Titan",
		"Desert",
		true,
		18,
		1.6,
		8,
		c3(210, 160, 80),
		c3(255, 80, 40),
		"Tall",
		160,
		15,
		1.4,
		{ { Res = "Crystal", Chance = 1, Min = 2, Max = 4 } }
	),
	e(
		"frostimp",
		"Frost Imp",
		"Frost",
		false,
		1,
		0.8,
		2.8,
		c3(160, 220, 255),
		c3(10, 40, 100),
		"Ball",
		9,
		1,
		0.07,
		{ { Res = "Crystal", Chance = 0.3, Min = 1, Max = 1 } }
	),
	e(
		"icewolf",
		"Ice Wolf",
		"Frost",
		false,
		2.1,
		1.2,
		3.6,
		c3(225, 240, 255),
		c3(60, 120, 255),
		"Block",
		15,
		1.6,
		0.12,
		{ { Res = "Ore", Chance = 0.5, Min = 1, Max = 2 } }
	),
	e(
		"glacier_lord",
		"Glacier Lord",
		"Frost",
		true,
		20,
		1.7,
		8.5,
		c3(120, 190, 250),
		c3(255, 255, 255),
		"Tall",
		180,
		16,
		1.6,
		{ { Res = "Crystal", Chance = 1, Min = 3, Max = 5 } }
	),
	e(
		"ashbat",
		"Ash Bat",
		"Volcano",
		false,
		1,
		0.9,
		2.6,
		c3(80, 70, 75),
		c3(255, 120, 40),
		"Ball",
		10,
		1,
		0.08,
		{ { Res = "Stone", Chance = 0.5, Min = 1, Max = 3 } }
	),
	e(
		"magmacrab",
		"Magma Crab",
		"Volcano",
		false,
		2.3,
		1.3,
		3.8,
		c3(200, 70, 40),
		c3(255, 230, 90),
		"Block",
		16,
		1.7,
		0.14,
		{ { Res = "Ore", Chance = 0.55, Min = 1, Max = 3 } }
	),
	e(
		"inferno_tyrant",
		"Inferno Tyrant",
		"Volcano",
		true,
		24,
		1.9,
		9,
		c3(150, 40, 30),
		c3(255, 220, 60),
		"Tall",
		220,
		18,
		2,
		{ { Res = "Crystal", Chance = 1, Min = 4, Max = 6 } }
	),
}

EnemyData.ById = {} :: { [string]: EnemyDef }
for _, d in ipairs(EnemyData.List) do
	EnemyData.ById[d.Id] = d
end

-- Мировой босс события «Каменный колосс» (появляется в хабе)
EnemyData.RAID_BOSS = e(
	"stone_colossus",
	"Stone Colossus",
	"Hub",
	true,
	1,
	1,
	14,
	c3(150, 150, 165),
	c3(255, 90, 60),
	"Tall",
	0,
	0,
	0,
	{}
)
EnemyData.RAID_BASE_HP = 12000
EnemyData.RAID_HP_PER_PLAYER = 0.6 -- +60% здоровья за каждого дополнительного игрока
-- Лунные существа (появляются в зонах во время «Лунной ночи»)
EnemyData.MOONLING = e(
	"moonling",
	"Moonling",
	"Any",
	false,
	3,
	0.8,
	3,
	c3(210, 220, 255),
	c3(90, 60, 200),
	"Ball",
	30,
	3,
	0.4,
	{}
)

-- Урон врагов по игроку за удар: BASE * 1.6^(индекс зоны-1) * DamageMult
EnemyData.PLAYER_DAMAGE_BASE = 6
EnemyData.ATTACK_INTERVAL = 1.6
EnemyData.AGGRO_RANGE = 28
EnemyData.ATTACK_RANGE = 7
EnemyData.MAX_ALIVE_PER_ZONE = 6
EnemyData.RESPAWN_SECONDS = 12
EnemyData.BOSS_RESPAWN_SECONDS = 180

function EnemyData.maxHp(def: EnemyDef, zoneId: string?): number
	local zone = ZoneData.ById[zoneId or def.Zone]
	local base = zone and zone.Hp or 100
	return math.floor(base * def.HpMult)
end

function EnemyData.damageToPlayer(def: EnemyDef, zoneId: string?): number
	local idx = ZoneData.Index[zoneId or def.Zone] or 1
	return math.max(1, math.floor(EnemyData.PLAYER_DAMAGE_BASE * 1.6 ^ (idx - 1) * def.DamageMult))
end

-- Стихия врага = стихия зоны (Boss тоже)
function EnemyData.element(def: EnemyDef): string
	local zone = ZoneData.ById[def.Zone]
	return zone and zone.Element or "Earth"
end

return EnemyData
