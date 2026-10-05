--!strict
-- Текущее состояние событий (расписание EventData + принудительное включение для тестов/демо/админов).
-- По умолчанию «часы» событий отсчитываются от старта сервера (epoch), чтобы новая сессия
-- не попадала сразу в середину Golden Rain / рейда. force() по-прежнему перекрывает расписание.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventData = require(ReplicatedStorage.Shared.EventData)

local EventState = {}

local forced: { [string]: boolean? } = {}
local epoch: number? = nil -- os.time() старта сервера; nil = wall-clock (как раньше)

-- Зафиксировать «час ноль» (обычно os.time() в EventService.init)
function EventState.setEpoch(t: number)
	epoch = t
end

function EventState.getEpoch(): number?
	return epoch
end

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
	local t = if epoch ~= nil then math.max(0, now - epoch) else now
	local on, left = EventData.status(id, t)
	return on, left
end

function EventState.isActive(id: string): boolean
	local on = EventState.status(id, os.time())
	return on
end

return EventState
