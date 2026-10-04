--!strict
-- Описание апгрейдов (за монеты или гемы).
export type UpgradeDef = {
	Id: string,
	Name: string,
	Description: string,
	MaxLevel: number,
	Currency: string, -- "Coins" | "Gems"
	BaseCost: number,
	Growth: number,
	Costs: { number }?, -- если задано, цены берутся из списка
}

local UpgradeData = {}

UpgradeData.CLICK_PER_LEVEL = 1
UpgradeData.SPEED_PER_LEVEL = 1.5
UpgradeData.LUCK_PER_LEVEL = 0.03
UpgradeData.BAG_PER_LEVEL = 10

UpgradeData.List = {
	{
		Id = "Click",
		Name = "Click Power",
		Description = "+1 base coin per collect. (Resets on Rebirth)",
		MaxLevel = 60,
		Currency = "Coins",
		BaseCost = 20,
		Growth = 1.45,
	},
	{
		Id = "Speed",
		Name = "Swift Shoes",
		Description = "+1.5 walk speed per level.",
		MaxLevel = 8,
		Currency = "Coins",
		BaseCost = 500,
		Growth = 2.2,
	},
	{
		Id = "Luck",
		Name = "Lucky Charm",
		Description = "+3% hatch luck per level (better odds for rare pets).",
		MaxLevel = 10,
		Currency = "Coins",
		BaseCost = 2000,
		Growth = 2.1,
	},
	{
		Id = "Bag",
		Name = "Bigger Bag",
		Description = "+10 pet storage per level.",
		MaxLevel = 10,
		Currency = "Coins",
		BaseCost = 300,
		Growth = 1.9,
	},
	{
		Id = "Slots",
		Name = "Pet Slot",
		Description = "+1 equipped pet slot.",
		MaxLevel = 4,
		Currency = "Gems",
		BaseCost = 0,
		Growth = 1,
		Costs = { 100, 300, 800, 2000 },
	},
} :: { UpgradeDef }

UpgradeData.ById = {} :: { [string]: UpgradeDef }
for _, def in ipairs(UpgradeData.List) do
	UpgradeData.ById[def.Id] = def
end

return UpgradeData
