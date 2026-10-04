--!strict
--[[
	ShopData — магазин с ротацией. Каждые ROTATION_SECONDS набор предложений меняется (детерминированно по номеру слота),
	у каждого предложения ограниченный запас на игрока.
	Give: { Coins?, Gems?, Res?, Item?, ItemCount?, Ticket? }
]]
local ShopData = {}

export type Offer = {
	Id: string,
	Name: string,
	Desc: string,
	Currency: string,
	Price: number,
	Stock: number,
	Weight: number,
	Give: { [string]: any },
	MinRebirth: number?,
}

ShopData.ROTATION_SECONDS = 600
ShopData.SLOTS = 6

local function o(id, name, desc, cur, price, stock, weight, give, minReb): Offer
	return {
		Id = id,
		Name = name,
		Desc = desc,
		Currency = cur,
		Price = price,
		Stock = stock,
		Weight = weight,
		Give = give,
		MinRebirth = minReb,
	}
end

ShopData.Pool = {
	o("wood_pack", "Lumber Bundle", "30 Wood", "Coins", 800, 5, 10, { Res = { Wood = 30 } }),
	o("herb_pack", "Herb Basket", "25 Herb", "Coins", 900, 5, 10, { Res = { Herb = 25 } }),
	o("ore_pack", "Ore Crate", "20 Iron Ore", "Coins", 4000, 4, 8, { Res = { Ore = 20 } }),
	o("crystal_pack", "Crystal Shard Set", "6 Crystals", "Gems", 30, 3, 6, { Res = { Crystal = 6 } }),
	o("essence_pack", "Essence Vial", "10 Essence", "Gems", 40, 3, 5, { Res = { Essence = 10 } }),
	o(
		"luck_potion",
		"Luck Potion",
		"x2 luck for 5 minutes",
		"Gems",
		25,
		3,
		8,
		{ Item = "luck_potion", ItemCount = 1 }
	),
	o(
		"coin_elixir",
		"Coin Elixir",
		"x2 coins for 5 minutes",
		"Gems",
		20,
		3,
		8,
		{ Item = "coin_elixir", ItemCount = 1 }
	),
	o(
		"treats",
		"Pet Treat x5",
		"Experience snacks",
		"Coins",
		3000,
		4,
		7,
		{ Item = "xp_treat", ItemCount = 5 }
	),
	o(
		"catalyst",
		"Fusion Catalyst",
		"+15% fusion variant chance",
		"Gems",
		45,
		2,
		6,
		{ Item = "catalyst", ItemCount = 1 }
	),
	o(
		"meadow_tickets",
		"Meadow Egg Tickets x5",
		"Five free Meadow eggs",
		"Coins",
		400,
		4,
		9,
		{ Item = "ticket_MeadowEgg", ItemCount = 5 }
	),
	o(
		"forest_tickets",
		"Forest Egg Tickets x3",
		"Three free Forest eggs",
		"Coins",
		7000,
		3,
		6,
		{ Item = "ticket_ForestEgg", ItemCount = 3 }
	),
	o(
		"frost_tickets",
		"Frost Egg Tickets x2",
		"Two free Frost eggs",
		"Gems",
		60,
		2,
		4,
		{ Item = "ticket_FrostEgg", ItemCount = 2 },
		1
	),
	o("gem_swap", "Gem Exchange", "Trade coins for 25 gems", "Coins", 50000, 2, 5, { Gems = 25 }),
	o("coin_swap", "Coin Exchange", "Trade 20 gems for coins", "Gems", 20, 3, 5, { Coins = 40000 }),
}

ShopData.ById = {} :: { [string]: Offer }
for _, x in ipairs(ShopData.Pool) do
	ShopData.ById[x.Id] = x
end

function ShopData.slotAt(now: number): number
	return now // ShopData.ROTATION_SECONDS
end

function ShopData.secondsLeft(now: number): number
	return ShopData.ROTATION_SECONDS - (now % ShopData.ROTATION_SECONDS)
end

-- Предложения слота (id в порядке отображения). Взвешенная выборка без повторов, детерминированная.
function ShopData.offers(slot: number, rebirths: number?): { string }
	local rng = Random.new(slot * 104729 + 31)
	local candidates = {}
	for _, x in ipairs(ShopData.Pool) do
		if (x.MinRebirth or 0) <= (rebirths or 0) then
			table.insert(candidates, x)
		end
	end
	local result = {}
	for _ = 1, math.min(ShopData.SLOTS, #candidates) do
		local total = 0
		for _, c in ipairs(candidates) do
			total += c.Weight
		end
		local r = rng:NextNumber() * total
		local pick = #candidates
		for i, c in ipairs(candidates) do
			r -= c.Weight
			if r <= 0 then
				pick = i
				break
			end
		end
		table.insert(result, candidates[pick].Id)
		table.remove(candidates, pick)
	end
	return result
end

return ShopData
