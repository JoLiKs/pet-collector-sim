--!strict
-- Данные питомцев и яиц. Все питомцы — оригинальные, собираются из простых частей (см. PetModel).
local Config = require(script.Parent.Config)

export type Look = {
	Body: Color3,
	Accent: Color3,
	Shape: string, -- "Round" | "Tall" | "Wide"
	Ears: string, -- "None" | "Round" | "Long" | "Pointy"
	Extras: { string }, -- "Tail" | "Wings" | "Horn" | "Crown" | "Antenna" | "Fins" | "Flame" | "Beak" | "Halo" | "Leaf"
}

export type PetDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Power: number,
	Look: Look,
}

export type EggPet = { Id: string, Weight: number }

export type EggDef = {
	Id: string,
	Name: string,
	Zone: string,
	Currency: string, -- "Coins" | "Gems"
	Price: number,
	Color: Color3,
	Pattern: Color3,
	Pets: { EggPet },
}

local PetData = {}

local c3 = Color3.fromRGB

PetData.Rarities = {
	Common = { Order = 1, Color = c3(190, 190, 200), Scale = 1.0 },
	Uncommon = { Order = 2, Color = c3(90, 210, 110), Scale = 1.08 },
	Rare = { Order = 3, Color = c3(70, 150, 255), Scale = 1.16 },
	Epic = { Order = 4, Color = c3(180, 90, 255), Scale = 1.26 },
	Legendary = { Order = 5, Color = c3(255, 170, 40), Scale = 1.38 },
	Mythic = { Order = 6, Color = c3(255, 70, 120), Scale = 1.5 },
} :: { [string]: { Order: number, Color: Color3, Scale: number } }

-- Редкости, на которые действует удача (Rare и выше)
PetData.LUCK_MIN_ORDER = 3

local function pet(id: string, name: string, rarity: string, power: number, look: Look): PetDef
	return { Id = id, Name = name, Rarity = rarity, Power = power, Look = look }
end

local function look(body: Color3, accent: Color3, shape: string, ears: string, extras: { string }): Look
	return { Body = body, Accent = accent, Shape = shape, Ears = ears, Extras = extras }
end

PetData.Pets = {
	-- Meadow Egg
	pet(
		"bunbun",
		"Bunbun",
		"Common",
		1,
		look(c3(250, 240, 225), c3(255, 170, 185), "Round", "Long", { "Tail" })
	),
	pet(
		"chirpy",
		"Chirpy",
		"Common",
		1.5,
		look(c3(255, 226, 90), c3(255, 150, 50), "Round", "None", { "Beak", "Wings" })
	),
	pet("mossy", "Mossy Frog", "Uncommon", 3, look(c3(110, 200, 90), c3(60, 140, 60), "Wide", "Round", {})),
	pet(
		"bumblet",
		"Bumblet",
		"Rare",
		8,
		look(c3(255, 205, 50), c3(40, 40, 40), "Round", "None", { "Wings", "Antenna" })
	),
	pet(
		"sunfox",
		"Sunny Fox",
		"Epic",
		25,
		look(c3(255, 140, 50), c3(255, 245, 225), "Tall", "Pointy", { "Tail" })
	),
	pet(
		"dandy",
		"Dandy King",
		"Legendary",
		90,
		look(c3(255, 190, 60), c3(255, 120, 30), "Round", "Round", { "Crown", "Tail" })
	),

	-- Forest Egg
	pet(
		"acorny",
		"Acorny",
		"Common",
		4,
		look(c3(176, 120, 70), c3(110, 70, 40), "Round", "None", { "Leaf" })
	),
	pet(
		"pinecub",
		"Pinecub",
		"Common",
		6,
		look(c3(140, 95, 60), c3(220, 190, 150), "Wide", "Round", { "Tail" })
	),
	pet(
		"owlet",
		"Owlet",
		"Uncommon",
		14,
		look(c3(160, 130, 100), c3(255, 235, 200), "Tall", "Pointy", { "Beak", "Wings" })
	),
	pet(
		"mushling",
		"Mushling",
		"Rare",
		36,
		look(c3(240, 230, 215), c3(230, 70, 70), "Round", "None", { "Leaf" })
	),
	pet(
		"deerling",
		"Deerling",
		"Epic",
		110,
		look(c3(200, 150, 100), c3(255, 240, 220), "Tall", "Long", { "Horn", "Tail" })
	),
	pet(
		"elderwood",
		"Elderwood",
		"Legendary",
		400,
		look(c3(120, 85, 55), c3(70, 190, 90), "Tall", "None", { "Leaf", "Crown" })
	),

	-- Desert Egg
	pet(
		"gecko",
		"Dune Gecko",
		"Common",
		18,
		look(c3(200, 190, 100), c3(150, 130, 60), "Wide", "None", { "Tail" })
	),
	pet(
		"scarab",
		"Sandy Scarab",
		"Common",
		26,
		look(c3(60, 130, 160), c3(240, 200, 80), "Wide", "None", { "Antenna", "Wings" })
	),
	pet(
		"cactling",
		"Cactling",
		"Uncommon",
		60,
		look(c3(80, 170, 90), c3(255, 120, 170), "Tall", "None", { "Leaf" })
	),
	pet(
		"mirage",
		"Mirage Cat",
		"Rare",
		150,
		look(c3(235, 205, 150), c3(120, 80, 160), "Round", "Pointy", { "Tail" })
	),
	pet(
		"serpent",
		"Sun Serpent",
		"Epic",
		450,
		look(c3(255, 190, 70), c3(220, 80, 40), "Wide", "None", { "Flame", "Tail" })
	),
	pet(
		"sphinx",
		"Golden Sphinx",
		"Legendary",
		1600,
		look(c3(255, 215, 90), c3(60, 90, 200), "Wide", "Round", { "Crown", "Wings" })
	),

	-- Frost Egg
	pet(
		"snowpup",
		"Snowy Pup",
		"Common",
		80,
		look(c3(245, 250, 255), c3(150, 200, 240), "Round", "Round", { "Tail" })
	),
	pet(
		"penguin",
		"Icicle Penguin",
		"Common",
		110,
		look(c3(50, 60, 80), c3(255, 245, 235), "Tall", "None", { "Beak", "Fins" })
	),
	pet(
		"yeti",
		"Yeti Cub",
		"Uncommon",
		260,
		look(c3(225, 240, 250), c3(120, 170, 220), "Wide", "Round", { "Horn" })
	),
	pet(
		"aurora",
		"Aurora Fox",
		"Rare",
		650,
		look(c3(160, 230, 220), c3(190, 120, 255), "Tall", "Pointy", { "Tail", "Halo" })
	),
	pet(
		"stag",
		"Crystal Stag",
		"Epic",
		1900,
		look(c3(150, 210, 255), c3(255, 255, 255), "Tall", "Long", { "Horn", "Halo" })
	),
	pet(
		"blizzdrake",
		"Blizzard Drake",
		"Legendary",
		7000,
		look(c3(120, 190, 250), c3(255, 255, 255), "Wide", "Pointy", { "Wings", "Horn", "Tail" })
	),

	-- Volcano Egg
	pet(
		"embermouse",
		"Ember Mouse",
		"Common",
		350,
		look(c3(255, 140, 90), c3(90, 40, 30), "Round", "Round", { "Tail", "Flame" })
	),
	pet(
		"lavaslug",
		"Lava Slug",
		"Common",
		480,
		look(c3(230, 90, 40), c3(255, 220, 90), "Wide", "None", { "Antenna" })
	),
	pet(
		"magmashell",
		"Magma Turtle",
		"Uncommon",
		1100,
		look(c3(90, 70, 70), c3(255, 120, 40), "Wide", "None", { "Flame" })
	),
	pet(
		"cinderwolf",
		"Cinder Wolf",
		"Rare",
		2800,
		look(c3(70, 60, 65), c3(255, 100, 30), "Tall", "Pointy", { "Tail", "Flame" })
	),
	pet(
		"phoenix",
		"Phoenix Chick",
		"Epic",
		8500,
		look(c3(255, 90, 50), c3(255, 220, 80), "Round", "None", { "Wings", "Flame", "Beak" })
	),
	pet(
		"infernodrake",
		"Inferno Drake",
		"Legendary",
		30000,
		look(c3(180, 40, 30), c3(255, 170, 40), "Wide", "Pointy", { "Wings", "Horn", "Flame", "Tail" })
	),

	-- Gem Egg (премиум-яйцо за гемы)
	pet(
		"slime",
		"Sparkle Slime",
		"Rare",
		220,
		look(c3(120, 230, 240), c3(255, 255, 255), "Wide", "None", { "Antenna" })
	),
	pet(
		"prismcat",
		"Prism Cat",
		"Epic",
		1300,
		look(c3(250, 150, 220), c3(130, 220, 255), "Round", "Pointy", { "Tail", "Halo" })
	),
	pet(
		"starbunny",
		"Star Bunny",
		"Epic",
		2000,
		look(c3(255, 245, 160), c3(255, 190, 60), "Round", "Long", { "Tail", "Crown" })
	),
	pet(
		"cosmicwhale",
		"Cosmic Whale",
		"Legendary",
		13000,
		look(c3(60, 70, 180), c3(255, 230, 120), "Wide", "None", { "Fins", "Halo" })
	),
	pet(
		"nebuladrake",
		"Nebula Dragon",
		"Mythic",
		70000,
		look(
			c3(110, 50, 190),
			c3(255, 120, 230),
			"Wide",
			"Pointy",
			{ "Wings", "Horn", "Halo", "Tail", "Crown" }
		)
	),
} :: { PetDef }

PetData.PetsById = {} :: { [string]: PetDef }
for _, p in ipairs(PetData.Pets) do
	PetData.PetsById[p.Id] = p
end

local function egg(
	id: string,
	name: string,
	zone: string,
	currency: string,
	price: number,
	color: Color3,
	pattern: Color3,
	pets: { EggPet }
): EggDef
	return {
		Id = id,
		Name = name,
		Zone = zone,
		Currency = currency,
		Price = price,
		Color = color,
		Pattern = pattern,
		Pets = pets,
	}
end

PetData.Eggs = {
	egg("MeadowEgg", "Meadow Egg", "Meadow", "Coins", 150, c3(255, 245, 215), c3(120, 200, 100), {
		{ Id = "bunbun", Weight = 40 },
		{ Id = "chirpy", Weight = 30 },
		{ Id = "mossy", Weight = 18 },
		{ Id = "bumblet", Weight = 8 },
		{ Id = "sunfox", Weight = 3.5 },
		{ Id = "dandy", Weight = 0.5 },
	}),
	egg("GemEgg", "Crystal Egg", "Meadow", "Gems", 75, c3(140, 230, 255), c3(255, 255, 255), {
		{ Id = "slime", Weight = 50 },
		{ Id = "prismcat", Weight = 28 },
		{ Id = "starbunny", Weight = 16.5 },
		{ Id = "cosmicwhale", Weight = 5 },
		{ Id = "nebuladrake", Weight = 0.5 },
	}),
	egg("ForestEgg", "Forest Egg", "Forest", "Coins", 2500, c3(150, 210, 140), c3(90, 60, 40), {
		{ Id = "acorny", Weight = 40 },
		{ Id = "pinecub", Weight = 30 },
		{ Id = "owlet", Weight = 18 },
		{ Id = "mushling", Weight = 8 },
		{ Id = "deerling", Weight = 3.5 },
		{ Id = "elderwood", Weight = 0.5 },
	}),
	egg("DesertEgg", "Dune Egg", "Desert", "Coins", 60000, c3(245, 215, 140), c3(200, 120, 60), {
		{ Id = "gecko", Weight = 40 },
		{ Id = "scarab", Weight = 30 },
		{ Id = "cactling", Weight = 18 },
		{ Id = "mirage", Weight = 8 },
		{ Id = "serpent", Weight = 3.5 },
		{ Id = "sphinx", Weight = 0.5 },
	}),
	egg("FrostEgg", "Frost Egg", "Frost", "Coins", 1500000, c3(200, 235, 255), c3(100, 170, 240), {
		{ Id = "snowpup", Weight = 40 },
		{ Id = "penguin", Weight = 30 },
		{ Id = "yeti", Weight = 18 },
		{ Id = "aurora", Weight = 8 },
		{ Id = "stag", Weight = 3.5 },
		{ Id = "blizzdrake", Weight = 0.5 },
	}),
	egg("VolcanoEgg", "Magma Egg", "Volcano", "Coins", 30000000, c3(90, 60, 60), c3(255, 120, 40), {
		{ Id = "embermouse", Weight = 40 },
		{ Id = "lavaslug", Weight = 30 },
		{ Id = "magmashell", Weight = 18 },
		{ Id = "cinderwolf", Weight = 8 },
		{ Id = "phoenix", Weight = 3.5 },
		{ Id = "infernodrake", Weight = 0.5 },
	}),
} :: { EggDef }

PetData.EggsById = {} :: { [string]: EggDef }
for _, e in ipairs(PetData.Eggs) do
	PetData.EggsById[e.Id] = e
end

-- Сила питомца с учётом "золотого" варианта
function PetData.getPower(petId: string, gold: boolean?): number
	local def = PetData.PetsById[petId]
	if not def then
		return 0
	end
	if gold then
		return def.Power * Config.GOLD_POWER_MULT
	end
	return def.Power
end

function PetData.sellValue(petId: string, gold: boolean?): number
	return math.floor(PetData.getPower(petId, gold) * Config.SELL_VALUE_PER_POWER)
end

-- Нормированные шансы выпадения (проценты) с учётом удачи. luck = 1 -> базовые шансы (то, что видно игроку).
-- Удача увеличивает вес питомцев редкости Rare и выше.
function PetData.getOdds(eggId: string, luck: number): { { Id: string, Chance: number } }
	local eggDef = PetData.EggsById[eggId]
	if not eggDef then
		return {}
	end
	local total = 0
	local weights: { number } = {}
	for i, entry in ipairs(eggDef.Pets) do
		local def = PetData.PetsById[entry.Id]
		local w = entry.Weight
		if def and PetData.Rarities[def.Rarity].Order >= PetData.LUCK_MIN_ORDER then
			w *= math.max(luck, 1)
		end
		weights[i] = w
		total += w
	end
	local result = {}
	for i, entry in ipairs(eggDef.Pets) do
		result[i] = { Id = entry.Id, Chance = weights[i] / total * 100 }
	end
	return result
end

-- Выбор питомца. rand01 — число из [0,1) (серверный Random).
function PetData.roll(eggId: string, luck: number, rand01: number): string?
	local odds = PetData.getOdds(eggId, luck)
	local acc = 0
	for _, o in ipairs(odds) do
		acc += o.Chance / 100
		if rand01 < acc then
			return o.Id
		end
	end
	if #odds > 0 then
		return odds[#odds].Id
	end
	return nil
end

return PetData
