--!strict
-- Ресурсы и типы узлов добычи в мире.
local ResourceData = {}
local c3 = Color3.fromRGB

ResourceData.Resources = {
	Wood = { Name = "Wood", Color = c3(160, 110, 60), Order = 1 },
	Stone = { Name = "Stone", Color = c3(150, 150, 160), Order = 2 },
	Ore = { Name = "Iron Ore", Color = c3(200, 140, 110), Order = 3 },
	Herb = { Name = "Herb", Color = c3(100, 210, 110), Order = 4 },
	Crystal = { Name = "Crystal", Color = c3(130, 230, 255), Order = 5 },
	Essence = { Name = "Essence", Color = c3(220, 150, 255), Order = 6 },
} :: { [string]: { Name: string, Color: Color3, Order: number } }
ResourceData.Order = { "Wood", "Stone", "Ore", "Herb", "Crystal", "Essence" }

-- Узлы. Yield — разброс количества; HoldTime — удержание ProximityPrompt; Respawn — секунд до возрождения.
ResourceData.Nodes = {
	Wood = {
		Name = "Tree",
		Res = "Wood",
		Min = 2,
		Max = 4,
		Hold = 0.8,
		Respawn = 25,
		Color = c3(110, 170, 80),
		Shape = "Tree",
	},
	Stone = {
		Name = "Boulder",
		Res = "Stone",
		Min = 2,
		Max = 4,
		Hold = 0.8,
		Respawn = 25,
		Color = c3(140, 140, 150),
		Shape = "Rock",
	},
	Ore = {
		Name = "Ore Vein",
		Res = "Ore",
		Min = 1,
		Max = 3,
		Hold = 1.1,
		Respawn = 35,
		Color = c3(190, 120, 90),
		Shape = "Rock",
	},
	Herb = {
		Name = "Herb Bush",
		Res = "Herb",
		Min = 2,
		Max = 5,
		Hold = 0.5,
		Respawn = 18,
		Color = c3(90, 200, 120),
		Shape = "Bush",
	},
	Crystal = {
		Name = "Crystal Cluster",
		Res = "Crystal",
		Min = 1,
		Max = 2,
		Hold = 1.4,
		Respawn = 60,
		Color = c3(120, 220, 255),
		Shape = "Crystal",
	},
} :: {
	[string]: {
		Name: string,
		Res: string,
		Min: number,
		Max: number,
		Hold: number,
		Respawn: number,
		Color: Color3,
		Shape: string,
	},
}

ResourceData.NODES_PER_ZONE = 9
ResourceData.GATHER_RANGE = 20
ResourceData.CHEST_RESPAWN = 120
ResourceData.CHESTS_PER_ZONE = 2
-- Сундук: случайная добыча
ResourceData.ChestLoot = {
	{ Kind = "Coins", Weight = 40 },
	{ Kind = "Gems", Weight = 12 },
	{ Kind = "Res", Weight = 40 },
	{ Kind = "Item", Weight = 8 },
}

return ResourceData
