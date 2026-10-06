--!strict
--[[
	QuestData — NPC, цепочки квестов с диалогами и ежедневные задания.
	Цель (Obj): { Kind, Key?, Count }.  Kind: gather | kill | boss | hatch | craft | fuse | evolve | collect | level | raid | trade | rain | superstop
	Key для gather = id ресурса; для kill/boss = id врага ИЛИ id зоны; для level = минимальный уровень питомца; иначе nil.
]]
local QuestData = {}

export type Obj = { Kind: string, Key: string?, Count: number }
export type Reward = {
	Coins: number?,
	Gems: number?,
	Res: { [string]: number }?,
	Item: string?,
	ItemCount: number?,
	BpXp: number?,
	Pet: string?,
}
export type Step = {
	Title: string,
	Offer: { string },
	Progress: string,
	Done: string,
	Obj: Obj,
	Reward: Reward,
}

QuestData.Npcs =
	{
		mira = {
			Id = "mira",
			Name = "Mira the Forager",
			Title = "Gatherer",
			Color = Color3.fromRGB(110, 200, 120),
			Pos = Vector3.new(-30, 0, 38),
			Greeting = "Hello, traveler! The world is full of treasure — if you know where to dig.",
		},
		bruno = {
			Id = "bruno",
			Name = "Bruno the Warden",
			Title = "Monster Hunter",
			Color = Color3.fromRGB(220, 90, 80),
			Pos = Vector3.new(34, 0, 36),
			Greeting = "Monsters are growing bolder. Your pets look strong — want to put them to work?",
		},
		pip = {
			Id = "pip",
			Name = "Professor Pip",
			Title = "Pet Scientist",
			Color = Color3.fromRGB(140, 120, 240),
			Pos = Vector3.new(-44, 0, -20),
			Greeting = "Fascinating! Every pet is a world of possibilities. Fuse them, evolve them, study them!",
		},
	} :: { [string]: { Id: string, Name: string, Title: string, Color: Color3, Pos: Vector3, Greeting: string } }
QuestData.NpcOrder = { "mira", "bruno", "pip" }

QuestData.Chains = {
	mira = {
		Name = "The Forager's Path",
		Steps = {
			{
				Title = "Wood for the Bench",
				Offer = {
					"The crafting bench in the plaza needs wood.",
					"Chop 8 Wood from trees in the Sunny Meadow and bring it to me.",
				},
				Progress = "Trees grow all over the Meadow. Hold E near one to chop it.",
				Done = "Perfect! That's good timber. Take this for your trouble.",
				Obj = { Kind = "gather", Key = "Wood", Count = 8 },
				Reward = { Coins = 300, Res = { Herb = 3 }, BpXp = 40 },
			},
			{
				Title = "A Little Alchemy",
				Offer = {
					"Now let's make something useful.",
					"Gather some Herbs and craft a Coin Elixir at the bench.",
				},
				Progress = "Herbs grow in bushes. Ore veins are in the Forest and Desert.",
				Done = "Wonderful! Alchemy will carry you far.",
				Obj = { Kind = "craft", Key = "coin_elixir", Count = 1 },
				Reward = { Gems = 15, Item = "luck_potion", ItemCount = 1, BpXp = 60 },
			},
			{
				Title = "Crystal Clear",
				Offer = {
					"Crystals are rare and radiant.",
					"Find 6 Crystals — bosses and the colder worlds are your best bet.",
				},
				Progress = "Crystal clusters sparkle in Frost and Volcano. Bosses drop them too!",
				Done = "They're beautiful! You've earned a real reward.",
				Obj = { Kind = "gather", Key = "Crystal", Count = 6 },
				Reward = { Coins = 8000, Gems = 40, Item = "catalyst", ItemCount = 1, BpXp = 120 },
			},
		} :: { Step },
	},
	bruno = {
		Name = "Warden's Trials",
		Steps = {
			{
				Title = "First Blood",
				Offer = {
					"Slimelings are pestering the Meadow.",
					"Defeat 6 monsters — your pets fight automatically when you're near.",
				},
				Progress = "Stand near monsters. You can also click them to help.",
				Done = "Ha! Not bad at all.",
				Obj = { Kind = "kill", Count = 6 },
				Reward = { Coins = 500, Res = { Stone = 4 }, BpXp = 40 },
			},
			{
				Title = "King of the Meadow",
				Offer = {
					"The Meadow King rules over the monsters here.",
					"Defeat him and I'll make it worth your while.",
				},
				Progress = "The boss appears in the Meadow every few minutes. Bring your best team!",
				Done = "You felled the King! The Meadow is safe.",
				Obj = { Kind = "boss", Key = "meadow_king", Count = 1 },
				Reward = { Coins = 3000, Gems = 25, Item = "blade", ItemCount = 1, BpXp = 100 },
			},
			{
				Title = "Raid Veteran",
				Offer = {
					"Sometimes a giant stone colossus awakens in our plaza.",
					"Help bring it down — all of us together.",
				},
				Progress = "Watch for the Stone Colossus event banner.",
				Done = "Together we are unstoppable!",
				Obj = { Kind = "raid", Count = 1 },
				Reward = { Gems = 60, Coins = 20000, BpXp = 150 },
			},
		} :: { Step },
	},
	pip = {
		Name = "Research Notes",
		Steps = {
			{
				Title = "Hatching Data",
				Offer = { "I need fresh specimens to study!", "Hatch 5 eggs — any eggs will do." },
				Progress = "Eggs stand in every world. The Meadow egg is cheap.",
				Done = "Wonderful data!",
				Obj = { Kind = "hatch", Count = 5 },
				Reward = { Coins = 400, Item = "xp_treat", ItemCount = 3, BpXp = 40 },
			},
			{
				Title = "The Fusion Hypothesis",
				Offer = {
					"Three identical pets can fuse into one with a chance of a better variant.",
					"Fuse a trio and show me the result.",
				},
				Progress = "Open the Pets panel, select three identical pets and press Fuse.",
				Done = "Remarkable! Golden, Rainbow, Shiny... each stronger than the last.",
				Obj = { Kind = "fuse", Count = 1 },
				Reward = { Gems = 20, Item = "catalyst", ItemCount = 1, BpXp = 80 },
			},
			{
				Title = "Growing Up",
				Offer = { "Pets level up by fighting alongside you.", "Get any pet to level 8." },
				Progress = "Keep your team near monsters — they gain experience from kills.",
				Done = "A well-trained pet is a happy pet.",
				Obj = { Kind = "level", Key = "8", Count = 1 },
				Reward = { Coins = 5000, Res = { Essence = 8 }, BpXp = 100 },
			},
			{
				Title = "Evolution!",
				Offer = {
					"Now for the grand experiment.",
					"Evolve a pet at its level cap. It costs Essence — monsters drop it.",
				},
				Progress = "Essence comes from monsters and bosses.",
				Done = "It evolved! I could cry.",
				Obj = { Kind = "evolve", Count = 1 },
				Reward = { Gems = 80, Coins = 50000, BpXp = 200 },
			},
		} :: { Step },
	},
} :: { [string]: { Name: string, Steps: { Step } } }

-- Ежедневные задания: из пула выбирается 3 штуки детерминированно по номеру дня.
QuestData.DailyPool = {
	{
		Id = "d_gather_wood",
		Name = "Lumberjack",
		Obj = { Kind = "gather", Key = "Wood", Count = 12 },
		Reward = { Coins = 400, BpXp = 30 },
	},
	{
		Id = "d_gather_herb",
		Name = "Herbalist",
		Obj = { Kind = "gather", Key = "Herb", Count = 10 },
		Reward = { Coins = 400, BpXp = 30 },
	},
	{
		Id = "d_gather_any",
		Name = "Prospector",
		Obj = { Kind = "gather", Count = 25 },
		Reward = { Gems = 8, BpXp = 40 },
	},
	{
		Id = "d_kill",
		Name = "Monster Slayer",
		Obj = { Kind = "kill", Count = 15 },
		Reward = { Gems = 10, BpXp = 40 },
	},
	{
		Id = "d_kill_big",
		Name = "Relentless",
		Obj = { Kind = "kill", Count = 40 },
		Reward = { Gems = 20, Coins = 2000, BpXp = 60 },
	},
	{
		Id = "d_boss",
		Name = "Boss Hunter",
		Obj = { Kind = "boss", Count = 1 },
		Reward = { Gems = 18, BpXp = 60 },
	},
	{
		Id = "d_hatch",
		Name = "Egg Enthusiast",
		Obj = { Kind = "hatch", Count = 3 },
		Reward = { Coins = 800, BpXp = 30 },
	},
	{
		Id = "d_craft",
		Name = "Apprentice Crafter",
		Obj = { Kind = "craft", Count = 2 },
		Reward = { Gems = 8, BpXp = 40 },
	},
	{
		Id = "d_collect",
		Name = "Coin Collector",
		Obj = { Kind = "collect", Count = 120 },
		Reward = { Coins = 600, BpXp = 30 },
	},
	{
		Id = "d_fuse",
		Name = "Fusion Practice",
		Obj = { Kind = "fuse", Count = 1 },
		Reward = { Gems = 15, BpXp = 50 },
	},
	{
		Id = "d_superstop",
		Name = "Superhero Hunter",
		Obj = { Kind = "superstop", Count = 1 },
		Reward = { Gems = 12, BpXp = 50 },
	},
} :: { { Id: string, Name: string, Obj: Obj, Reward: Reward } }
QuestData.DAILY_COUNT = 3
QuestData.DailyById = {} :: { [string]: any }
for _, q in ipairs(QuestData.DailyPool) do
	QuestData.DailyById[q.Id] = q
end

-- Детерминированный выбор: одинаковый результат на любом сервере в один день
function QuestData.dailyFor(dayNumber: number): { string }
	local rng = Random.new(dayNumber * 7919 + 17)
	local pool = {}
	for _, q in ipairs(QuestData.DailyPool) do
		table.insert(pool, q.Id)
	end
	local picked: { string } = {}
	for _ = 1, math.min(QuestData.DAILY_COUNT, #pool) do
		local i = rng:NextInteger(1, #pool)
		table.insert(picked, table.remove(pool, i) :: string)
	end
	return picked
end

-- Подходит ли событие (kind,key,zone) под цель
function QuestData.matches(obj: Obj, kind: string, key: string?, zone: string?): boolean
	if obj.Kind ~= kind then
		return false
	end
	if obj.Key == nil or kind == "level" then
		return true
	end
	return obj.Key == key or (zone ~= nil and obj.Key == zone)
end

return QuestData
