--!strict
-- Достижения: срабатывают по счётчикам data.Stats. Награда — гемы (выдаётся автоматически).
local AchievementData = {}

export type Ach = { Id: string, Name: string, Desc: string, Stat: string, Goal: number, Gems: number }

local function a(id: string, name: string, desc: string, stat: string, goal: number, gems: number): Ach
	return { Id = id, Name = name, Desc = desc, Stat = stat, Goal = goal, Gems = gems }
end

AchievementData.List = {
	a("kills_1", "Monster Hunter I", "Defeat 25 monsters.", "Kills", 25, 10),
	a("kills_2", "Monster Hunter II", "Defeat 250 monsters.", "Kills", 250, 30),
	a("kills_3", "Monster Hunter III", "Defeat 2,500 monsters.", "Kills", 2500, 120),
	a("boss_1", "Giant Slayer", "Defeat 3 bosses.", "Bosses", 3, 25),
	a("boss_2", "Legend Slayer", "Defeat 25 bosses.", "Bosses", 25, 100),
	a("raid_1", "Raid Hero", "Help defeat the Stone Colossus.", "Raids", 1, 40),
	a("gather_1", "Gatherer I", "Gather 50 resources.", "Gathered", 50, 8),
	a("gather_2", "Gatherer II", "Gather 500 resources.", "Gathered", 500, 40),
	a("craft_1", "Artisan", "Craft 10 items.", "Crafted", 10, 20),
	a("hatch_1", "Egg Fan", "Hatch 25 pets.", "Hatched", 25, 12),
	a("hatch_2", "Egg Addict", "Hatch 300 pets.", "Hatched", 300, 60),
	a("fuse_1", "Fusion Master", "Fuse pets 5 times.", "Fused", 5, 25),
	a("evo_1", "Evolver", "Evolve a pet.", "Evolved", 1, 30),
	a("evo_2", "Ascendant", "Evolve pets 5 times.", "Evolved", 5, 90),
	a("shiny_1", "Shiny!", "Own a Shiny pet.", "Shiny", 1, 100),
	a("trade_1", "Merchant", "Complete a trade.", "Trades", 1, 15),
	a("quest_1", "Helper", "Complete 5 quests.", "Quests", 5, 20),
	a("quest_2", "Hero of the Realm", "Complete 30 quests.", "Quests", 30, 80),
	a("rebirth_1", "Reborn", "Rebirth once.", "Rebirths", 1, 40),
	a("rebirth_2", "Phoenix", "Rebirth 5 times.", "Rebirths", 5, 150),
	a("rain_1", "Golden Touch", "Collect 50 golden coins in a Coin Rain.", "RainCoins", 50, 25),
	a("level_1", "Trainer", "Raise a pet to level 20.", "MaxPetLevel", 20, 35),
	a("super_1", "Hunter", "Stop a superplayer.", "SuperStops", 1, 15),
	a("super_2", "Hero Hunter", "Stop superplayers 10 times.", "SuperStops", 10, 60),
	a("survive_1", "Unstoppable", "Hold out with the superpower until the end.", "SuperSurvived", 1, 30),
}

AchievementData.ById = {} :: { [string]: Ach }
for _, x in ipairs(AchievementData.List) do
	AchievementData.ById[x.Id] = x
end

return AchievementData
