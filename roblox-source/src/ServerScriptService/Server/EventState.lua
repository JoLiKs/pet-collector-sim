--!strict
-- Текущее состояние событий (расписание EventData + принудительное включение для тестов/демо/админов).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventData = require(ReplicatedStorage.Shared.EventData)

local EventState = {}

local forced: { [string]: boolean? } = {}

-- Принудительно включить/выключить событие (nil = вернуться к расписанию)
function EventState.force(id: string, on: boolean?)
	forced[id] = on
end

-- (активно ли, секунд до конца или до начала)
function EventState.status(id: string, now: number): (boolean, number)
	local f = forced[id]
	if f ~= nil then
		return f, 60
	end
	local on, left = EventData.status(id, now)
	return on, left
end

function EventState.isActive(id: string): boolean
	local on = EventState.status(id, os.time())
	return on
end

return EventState
