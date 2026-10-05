--!strict
-- Предметы и рецепты крафта. Результат — предмет в data.Items; use() применяется в CraftService.
local RecipeData = {}

export type Item = { Id: string, Name: string, Desc: string, Kind: string, Value: number?, Seconds: number? }
export type Recipe = {
	Id: string,
	Item: string,
	Count: number,
	Cost: { [string]: number },
	Coins: number?,
	Unlock: number?,
}

-- Kind: "BoostLuck" | "BoostCoins" | "PetXp" | "Catalyst" | "Tool" | "Weapon" | "Ticket"
RecipeData.Items = {
	luck_potion = {
		Id = "luck_potion",
		Name = "Luck Potion",
		Desc = "Hatch luck x2 for 5 minutes.",
		Kind = "BoostLuck",
		Value = 2,
		Seconds = 300,
	},
	coin_elixir = {
		Id = "coin_elixir",
		Name = "Coin Elixir",
		Desc = "Coins x2 for 5 minutes.",
		Kind = "BoostCoins",
		Value = 2,
		Seconds = 300,
	},
	xp_treat = {
		Id = "xp_treat",
		Name = "Pet Treat",
		Desc = "Gives a chosen pet experience.",
		Kind = "PetXp",
		Value = 120,
	},
	catalyst = {
		Id = "catalyst",
		Name = "Fusion Catalyst",
		Desc = "+15% variant chance on your next fusion.",
		Kind = "Catalyst",
		Value = 0.15,
	},
	pickaxe = {
		Id = "pickaxe",
		Name = "Iron Pickaxe",
		Desc = "Permanently +1 resource per gather.",
		Kind = "Tool",
		Value = 1,
	},
	blade = {
		Id = "blade",
		Name = "Hunter's Blade",
		Desc = "Permanently +50% damage when you attack.",
		Kind = "Weapon",
		Value = 0.5,
	},
	ticket_MeadowEgg = {
		Id = "ticket_MeadowEgg",
		Name = "Meadow Egg Ticket",
		Desc = "Hatch one Meadow Egg for free.",
		Kind = "Ticket",
	},
	ticket_ForestEgg = {
		Id = "ticket_ForestEgg",
		Name = "Forest Egg Ticket",
		Desc = "Hatch one Forest Egg for free.",
		Kind = "Ticket",
	},
	ticket_FrostEgg = {
		Id = "ticket_FrostEgg",
		Name = "Frost Egg Ticket",
		Desc = "Hatch one Frost Egg for free.",
		Kind = "Ticket",
	},
} :: { [string]: Item }
RecipeData.ItemOrder = {
	"luck_potion",
	"coin_elixir",
	"xp_treat",
	"catalyst",
	"pickaxe",
	"blade",
	"ticket_MeadowEgg",
	"ticket_ForestEgg",
	"ticket_FrostEgg",
}

RecipeData.Recipes = {
	{ Id = "r_luck", Item = "luck_potion", Count = 1, Cost = { Herb = 5, Crystal = 1 } },
	{ Id = "r_coin", Item = "coin_elixir", Count = 1, Cost = { Herb = 3, Ore = 2 } },
	{ Id = "r_treat", Item = "xp_treat", Count = 3, Cost = { Wood = 4, Herb = 2 } },
	{ Id = "r_catalyst", Item = "catalyst", Count = 1, Cost = { Ore = 5, Crystal = 2 } },
	{ Id = "r_pick", Item = "pickaxe", Count = 1, Cost = { Wood = 10, Ore = 8 }, Coins = 500 },
	{ Id = "r_blade", Item = "blade", Count = 1, Cost = { Ore = 12, Essence = 3, Stone = 10 }, Coins = 2000 },
	{ Id = "r_t_meadow", Item = "ticket_MeadowEgg", Count = 1, Cost = { Wood = 5, Herb = 3 }, Coins = 100 },
	{
		Id = "r_t_forest",
		Item = "ticket_ForestEgg",
		Count = 1,
		Cost = { Wood = 8, Stone = 5, Crystal = 1 },
		Coins = 1500,
	},
	{ Id = "r_shard_catalyst", Item = "catalyst", Count = 1, Cost = { Fragment = 3, Essence = 1 } },
	{
		Id = "r_t_frost",
		Item = "ticket_FrostEgg",
		Count = 1,
		Cost = { Crystal = 5, Ore = 6 },
		Coins = 400000,
	},
} :: { Recipe }

RecipeData.ById = {} :: { [string]: Recipe }
for _, r in ipairs(RecipeData.Recipes) do
	RecipeData.ById[r.Id] = r
end

-- Чистая проверка: хватает ли ресурсов. have — таблица ресурсов, возвращает (ok, missingText)
function RecipeData.canCraft(recipe: Recipe, have: { [string]: number }, coins: number): (boolean, string?)
	for res, n in pairs(recipe.Cost) do
		if (have[res] or 0) < n then
			return false, "Need " .. tostring(n) .. " " .. res
		end
	end
	if recipe.Coins and coins < recipe.Coins then
		return false, "Not enough coins"
	end
	return true, nil
end

return RecipeData
