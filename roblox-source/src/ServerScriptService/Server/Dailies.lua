--!strict
-- Ежедневные задания: набор из 3 заданий меняется каждый UTC-день. Чистая логика над таблицей data.Quests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestData = require(ReplicatedStorage.Shared.QuestData)

local Dailies = {}

function Dailies.dayNumber(now: number?): number
	return (now or os.time()) // 86400
end

-- Обновляет набор заданий при смене дня. Возвращает true, если набор поменялся.
function Dailies.ensure(data: { [string]: any }, now: number?): boolean
	local day = Dailies.dayNumber(now)
	local daily = data.Quests.Daily
	if daily.Day == day then
		return false
	end
	daily.Day = day
	daily.Items = {}
	for _, id in ipairs(QuestData.dailyFor(day)) do
		daily.Items[id] = { P = 0, C = false }
	end
	return true
end

return Dailies
