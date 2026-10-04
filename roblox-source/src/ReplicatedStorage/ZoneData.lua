--!strict
-- Миры (зоны). Каждый следующий мир умножает монеты за клик и открывает новое яйцо.
export type ZoneDef = {
	Id: string,
	Name: string,
	Multiplier: number,
	UnlockCost: number, -- монеты (0 = открыта сразу)
	RequiresRebirths: number,
	Position: Vector3, -- центр платформы
	Floor: Color3,
	Accent: Color3,
	Material: Enum.Material,
	Sky: Color3,
	Decor: string, -- "Trees" | "Cacti" | "Crystals" | "Rocks"
	Element: string, -- стихия врагов зоны
	Hp: number, -- базовое здоровье рядовых врагов
	Enemies: { string }, -- Id из EnemyData
	Boss: string, -- Id босса зоны
	Resources: { string }, -- типы узлов (ResourceData)
}

local ZoneData = {}

ZoneData.PLATFORM_SIZE = 220

-- Хаб — центр мира (спавн, NPC, станции). Всегда доступен.
ZoneData.HUB = "Hub"
ZoneData.HUB_POSITION = Vector3.new(0, 0, 0)
ZoneData.HUB_RADIUS = 110

ZoneData.List = {
	{
		Id = "Meadow",
		Name = "Sunny Meadow",
		Multiplier = 1,
		UnlockCost = 0,
		RequiresRebirths = 0,
		Position = Vector3.new(520, 0, 0),
		Floor = Color3.fromRGB(104, 190, 84),
		Accent = Color3.fromRGB(255, 214, 90),
		Material = Enum.Material.Grass,
		Sky = Color3.fromRGB(150, 205, 255),
		Decor = "Trees",
		Element = "Earth",
		Hp = 40,
		Enemies = { "slimeling", "boarlet" },
		Boss = "meadow_king",
		Resources = { "Wood", "Herb", "Stone" },
	},
	{
		Id = "Forest",
		Name = "Whispering Forest",
		Multiplier = 3,
		UnlockCost = 5000,
		RequiresRebirths = 0,
		Position = Vector3.new(0, 0, 520),
		Floor = Color3.fromRGB(58, 132, 70),
		Accent = Color3.fromRGB(139, 94, 60),
		Material = Enum.Material.Grass,
		Sky = Color3.fromRGB(120, 175, 150),
		Decor = "Trees",
		Element = "Air",
		Hp = 400,
		Enemies = { "wisp", "mossgolem" },
		Boss = "elder_treant",
		Resources = { "Wood", "Herb", "Ore" },
	},
	{
		Id = "Desert",
		Name = "Golden Dunes",
		Multiplier = 9,
		UnlockCost = 100000,
		RequiresRebirths = 0,
		Position = Vector3.new(-520, 0, 0),
		Floor = Color3.fromRGB(231, 200, 129),
		Accent = Color3.fromRGB(86, 160, 80),
		Material = Enum.Material.Sand,
		Sky = Color3.fromRGB(255, 220, 160),
		Decor = "Cacti",
		Element = "Fire",
		Hp = 3500,
		Enemies = { "scorpling", "sandwraith" },
		Boss = "sand_titan",
		Resources = { "Stone", "Ore", "Herb" },
	},
	{
		Id = "Frost",
		Name = "Frostpeak Glade",
		Multiplier = 27,
		UnlockCost = 2500000,
		RequiresRebirths = 0,
		Position = Vector3.new(0, 0, -520),
		Floor = Color3.fromRGB(226, 240, 252),
		Accent = Color3.fromRGB(130, 200, 255),
		Material = Enum.Material.Snow,
		Sky = Color3.fromRGB(190, 220, 245),
		Decor = "Crystals",
		Element = "Water",
		Hp = 30000,
		Enemies = { "frostimp", "icewolf" },
		Boss = "glacier_lord",
		Resources = { "Ore", "Crystal", "Stone" },
	},
	{
		Id = "Volcano",
		Name = "Ember Caldera",
		Multiplier = 81,
		UnlockCost = 60000000,
		RequiresRebirths = 1,
		Position = Vector3.new(520, 0, 520),
		Floor = Color3.fromRGB(70, 58, 58),
		Accent = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.Slate,
		Sky = Color3.fromRGB(120, 70, 60),
		Decor = "Rocks",
		Element = "Fire",
		Hp = 250000,
		Enemies = { "ashbat", "magmacrab" },
		Boss = "inferno_tyrant",
		Resources = { "Ore", "Crystal", "Stone" },
	},
} :: { ZoneDef }

ZoneData.ById = {} :: { [string]: ZoneDef }
ZoneData.Index = {} :: { [string]: number }
for i, zone in ipairs(ZoneData.List) do
	ZoneData.ById[zone.Id] = zone
	ZoneData.Index[zone.Id] = i
end

ZoneData.DEFAULT = "Meadow"

return ZoneData
