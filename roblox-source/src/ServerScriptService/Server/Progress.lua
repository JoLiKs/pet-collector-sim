--!strict
--[[
	Progress — единая точка учёта игровых событий: счётчики (Stats), прогресс квестов, достижения, опыт батл-пасса.
	Сервисы сообщают о действиях через Progress.record(player, kind, key, amount, zone):
	  kind: gather | kill | boss | hatch | craft | fuse | evolve | collect | trade | raid | rain | level
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local AchievementData = require(Shared.AchievementData)
local Config = require(Shared.Config)
local QuestData = require(Shared.QuestData)

local DataService = require(script.Parent.DataService)
local Dailies = require(script.Parent.Dailies)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local State = require(script.Parent.State)

local Progress = {}

local STAT_OF_KIND = {
	gather = "Gathered",
	kill = "Kills",
	boss = "Bosses",
	hatch = "Hatched",
	craft = "Crafted",
	fuse = "Fused",
	evolve = "Evolved",
	collect = "Collected",
	trade = "Trades",
	raid = "Raids",
	rain = "RainCoins",
}

local BP_XP_OF_KIND = {
	kill = Config.BP_XP_PER_KILL,
	boss = Config.BP_XP_PER_KILL * 10,
	gather = Config.BP_XP_PER_GATHER,
	craft = Config.BP_XP_PER_CRAFT,
}

local function checkAchievements(player: Player, data: DataService.Data, stat: string)
	for _, ach in ipairs(AchievementData.List) do
		if ach.Stat == stat and not data.Achievements[ach.Id] and (data.Stats[stat] or 0) >= ach.Goal then
			data.Achievements[ach.Id] = true
			Economy.addGems(player, ach.Gems)
			Notify.send(player, Locale.m("ach.unlocked", { name = ach.Name, n = ach.Gems }), "reward")
			State.markCore(player)
		end
	end
end

-- Устанавливает счётчик вручную (для «максимумов» вроде уровня питомца)
function Progress.setMax(player: Player, stat: string, value: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	if value > (data.Stats[stat] or 0) then
		data.Stats[stat] = value
		checkAchievements(player, data, stat)
	end
end

function Progress.addStat(player: Player, stat: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Stats[stat] = (data.Stats[stat] or 0) + amount
	checkAchievements(player, data, stat)
end

-- Для kind="level" Obj.Key — минимальный уровень, key события — достигнутый уровень
local function matches(obj: QuestData.Obj, kind: string, key: string?, zone: string?): boolean
	if not QuestData.matches(obj, kind, key, zone) then
		return false
	end
	if kind == "level" then
		return (tonumber(key) or 0) >= (tonumber(obj.Key) or 0)
	end
	return true
end

local function bump(entry: { [string]: any }, obj: QuestData.Obj, amount: number)
	entry.P = math.min(obj.Count, (entry.P or 0) + amount)
end

function Progress.record(player: Player, kind: string, key: string?, amount: number?, zone: string?)
	local data = DataService.get(player)
	if not data then
		return
	end
	local n = amount or 1
	Dailies.ensure(data)
	local stat = STAT_OF_KIND[kind]
	if stat then
		Progress.addStat(player, stat, n)
	end
	local bp = BP_XP_OF_KIND[kind]
	if bp then
		Economy.addBpXp(player, bp * n)
	end

	-- цепочки квестов NPC
	for npcId, state in pairs(data.Quests.Chains) do
		local chain = QuestData.Chains[npcId]
		local step = chain and chain.Steps[state.Step]
		if step and state.Accepted and matches(step.Obj, kind, key, zone) then
			state.Progress = math.min(step.Obj.Count, (state.Progress or 0) + n)
		end
	end
	-- ежедневные
	for id, entry in pairs(data.Quests.Daily.Items) do
		local def = QuestData.DailyById[id]
		if def and not entry.C and matches(def.Obj, kind, key, zone) then
			bump(entry, def.Obj, n)
		end
	end
	State.markCore(player)
end

return Progress
