--!strict
--[[
	TutorialService — серверный учёт обучения первой сессии (v2.4, аудит Г3). Шаги — TutorialData.
	Сервисы сообщают события через TutorialService.onEvent(player, kind, n):
	  click (ClickService, ручной сбор), hatch/kill/boss/gather (Progress.record), equip (PetService).
	Действие "TutorialSkip" — пропустить обучение (без награды).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local TutorialData = require(Shared.TutorialData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local TutorialService = {}

function TutorialService.onEvent(player: Player, kind: string, n: number?)
	local data = DataService.get(player)
	if not data then
		return
	end
	local t = data.Tutorial
	if t.Step >= TutorialData.DONE then
		return
	end
	local changed, finished, all = TutorialData.advance(t, kind, n or 1)
	if not changed then
		return
	end
	if finished then
		local step = TutorialData.Steps[finished]
		if step.RewardCoins then
			Economy.addCoins(player, step.RewardCoins, false)
		end
		if all then
			Economy.addGems(player, TutorialData.REWARD_GEMS)
			Notify.send(player, Locale.m("tutorial.done", { n = TutorialData.REWARD_GEMS }), "reward")
		else
			Notify.send(
				player,
				if step.RewardCoins
					then Locale.m("tutorial.step_done_coins", { n = step.RewardCoins })
					else "tutorial.step_done",
				"success"
			)
		end
	end
	State.markCore(player)
end

local function skip(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	data.Tutorial.Step = TutorialData.DONE
	data.Tutorial.P = 0
	State.markCore(player)
	return true, nil
end

function TutorialService.init()
	Router.register("TutorialSkip", 1, 2, skip)
end

return TutorialService
