--!strict
-- Квесты: NPC с диалогами и цепочками из шагов, ежедневные задания. Прогресс считает Progress, награды — сервер.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local QuestData = require(Shared.QuestData)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Dailies = require(script.Parent.Dailies)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local Stations = require(script.Parent.Stations)
local WorldBuilder = require(script.Parent.WorldBuilder)

local QuestService = {}

local function chainState(data: DataService.Data, npcId: string): { [string]: any }
	local st = data.Quests.Chains[npcId]
	if not st then
		st = { Step = 1, Accepted = false, Progress = 0 }
		data.Quests.Chains[npcId] = st
	end
	return st
end

-- Описание диалога для клиента
function QuestService.dialogFor(data: DataService.Data, npcId: string): { [string]: any }?
	local npc = QuestData.Npcs[npcId]
	local chain = QuestData.Chains[npcId]
	if not npc or not chain then
		return nil
	end
	local st = chainState(data, npcId)
	local step = chain.Steps[st.Step]
	local d: { [string]: any } = {
		Npc = npcId,
		Name = npc.Name,
		Title = npc.Title,
		Chain = chain.Name,
		Total = #chain.Steps,
		Step = math.min(st.Step, #chain.Steps),
	}
	if not step then
		d.Mode = "finished"
		d.Lines = { "quest.npc_finished", npc.Greeting }
		return d
	end
	d.StepTitle = step.Title
	d.Obj = step.Obj
	d.Reward = step.Reward
	d.Progress = st.Progress or 0
	if not st.Accepted then
		d.Mode = "offer"
		d.Lines = if st.Step == 1 then { npc.Greeting, table.unpack(step.Offer) } else step.Offer
	elseif (st.Progress or 0) >= step.Obj.Count then
		d.Mode = "done"
		d.Lines = { step.Done }
	else
		d.Mode = "progress"
		d.Lines = { step.Progress }
	end
	return d
end

local function talk(player: Player, npcId: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(npcId) ~= "string" then
		return false, "err.bad_request"
	end
	if not Stations.inHub(player) then
		return false, "quest.return_hub"
	end
	local d = QuestService.dialogFor(data, npcId)
	if not d then
		return false, "err.unknown"
	end
	Remotes.getEvent("Dialog"):FireClient(player, d)
	return true, nil
end

local function accept(player: Player, npcId: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(npcId) ~= "string" or not QuestData.Chains[npcId] then
		return false, "err.bad_request"
	end
	local st = chainState(data, npcId)
	local step = QuestData.Chains[npcId].Steps[st.Step]
	if not step then
		return false, "quest.no_more"
	end
	if st.Accepted then
		return false, "quest.already_accepted"
	end
	st.Accepted = true
	st.Progress = 0
	State.markCore(player)
	Notify.send(player, Locale.m("quest.accepted", { title = step.Title }), "info")
	return true, nil
end

local function claim(player: Player, npcId: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(npcId) ~= "string" or not QuestData.Chains[npcId] then
		return false, "err.bad_request"
	end
	local st = chainState(data, npcId)
	local step = QuestData.Chains[npcId].Steps[st.Step]
	if not step or not st.Accepted then
		return false, "quest.none_active"
	end
	if (st.Progress or 0) < step.Obj.Count then
		return false, "quest.not_complete"
	end
	-- сначала сдвигаем состояние, потом выдаём награду (защита от двойного клика)
	st.Step += 1
	st.Accepted = false
	st.Progress = 0
	Economy.grant(player, step.Reward)
	Progress.addStat(player, "Quests", 1)
	Notify.send(
		player,
		Locale.m(
			"quest.complete",
			{ title = step.Title, reward = Economy.describe(step.Reward, Locale.langOf(player)) }
		),
		"reward"
	)
	State.markPets(player)
	local d = QuestService.dialogFor(data, npcId)
	if d then
		Remotes.getEvent("Dialog"):FireClient(player, d)
	end
	return true, nil
end

local function claimDaily(player: Player, id: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return false, "err.bad_request"
	end
	Dailies.ensure(data)
	local entry = data.Quests.Daily.Items[id]
	local def = QuestData.DailyById[id]
	if not entry or not def then
		return false, "quest.not_daily"
	end
	if entry.C then
		return false, "err.already_claimed"
	end
	if (entry.P or 0) < def.Obj.Count then
		return false, "quest.not_complete"
	end
	entry.C = true
	Economy.grant(player, def.Reward)
	Progress.addStat(player, "Quests", 1)
	Notify.send(
		player,
		Locale.m(
			"quest.daily_complete",
			{ title = def.Name, reward = Economy.describe(def.Reward, Locale.langOf(player)) }
		),
		"reward"
	)
	State.markCore(player)
	return true, nil
end

function QuestService.init()
	Router.register("QuestTalk", 3, 3, talk)
	Router.register("QuestAccept", 3, 3, accept)
	Router.register("QuestClaim", 3, 3, claim)
	Router.register("DailyQuestClaim", 4, 4, claimDaily)
	WorldBuilder.onNpcPrompt(function(player: Player, npcId: string)
		talk(player, npcId)
	end)
end

return QuestService
