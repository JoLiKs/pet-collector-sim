--!strict
--[[
	TutorialData — короткое обучение первой сессии (v2.4, аудит Г3).
	Пять шагов: собрать монеты → открыть яйцо → взять питомца в команду → победить врага → собрать ресурс.
	Награда за шаг «собрать» (монеты на первое яйцо) и за прохождение (гемы). Прогресс считает сервер
	(TutorialService), клиент только показывает подсказку. Ветераны (профиль до v2.4 с питомцами) обучение не видят.
]]
local TutorialData = {}

export type Step = { Id: string, Kind: string, Count: number, Text: string, RewardCoins: number? }

TutorialData.Steps = {
	{ Id = "collect", Kind = "click", Count = 25, Text = "tutorial.collect", RewardCoins = 150 },
	{ Id = "hatch", Kind = "hatch", Count = 1, Text = "tutorial.hatch" },
	{ Id = "equip", Kind = "equip", Count = 1, Text = "tutorial.equip" },
	{ Id = "kill", Kind = "kill", Count = 1, Text = "tutorial.kill" },
	{ Id = "gather", Kind = "gather", Count = 1, Text = "tutorial.gather" },
} :: { Step }

TutorialData.REWARD_GEMS = 25 -- за прохождение (≈ треть Кристального яйца; см. BALANCE.md)
TutorialData.DONE = #TutorialData.Steps + 1

-- Чистая функция: продвигает состояние { Step, P } событием kind (n штук).
-- Возвращает: изменилось ли состояние, индекс завершённого шага (или nil), пройдено ли обучение целиком.
function TutorialData.advance(
	state: { Step: number, P: number },
	kind: string,
	n: number
): (boolean, number?, boolean)
	local step = TutorialData.Steps[state.Step]
	if not step or n <= 0 then
		return false, nil, false
	end
	local k = if kind == "boss" then "kill" else kind
	if step.Kind ~= k then
		return false, nil, false
	end
	state.P = math.min(step.Count, (state.P or 0) + n)
	if state.P < step.Count then
		return true, nil, false
	end
	local finished = state.Step
	state.Step += 1
	state.P = 0
	return true, finished, state.Step >= TutorialData.DONE
end

return TutorialData
