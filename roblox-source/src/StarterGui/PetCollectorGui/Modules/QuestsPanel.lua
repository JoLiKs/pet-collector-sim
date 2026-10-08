--!nonstrict
-- Задания: ежедневные, цепочки NPC, достижения.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local AchievementData = require(Shared:WaitForChild("AchievementData"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local QuestsPanel = {}

local rewardText = UiKit.rewardText
local objText = UiKit.objText

function QuestsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Quests")
	local body = panel.Body
	local view = "Daily"
	local scroll =
		Widgets.scroller(body, { Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 1, -50) })
	UiKit.list(scroll, 6)
	UiKit.tabs(body, { "Daily", "Story", "Achievements" }, function(name)
		view = name
		panel.Refresh()
	end, 4, 130)

	function panel.Refresh()
		local core = ClientState.Core
		if not core then
			return
		end
		Widgets.clear(scroll)
		if view == "Daily" then
			local order = 0
			for id, entry in pairs(core.Quests.Daily) do
				local def = QuestData.DailyById[id]
				if def then
					order += 1
					local done = entry.P >= def.Obj.Count
					-- v3.2: карточка растёт по тексту (перенос, текст >= 12 px), полоса прогресса — с подписью
					local card, col = UiKit.flowCard(
						scroll,
						64,
						if done and not entry.C then Theme.Green else nil,
						order,
						10,
						120
					)
					card.Name = id
					UiKit.flowText(col, L.n(def.Name), { Font = Theme.Font, TextSize = 18, LayoutOrder = 1 })
					UiKit.flowText(
						col,
						L.t("quests.obj_reward", { obj = objText(def.Obj), reward = rewardText(def.Reward) }),
						{ TextColor3 = Theme.TextDim, LayoutOrder = 2 }
					)
					local bar = UiKit.bar(col, UDim2.new(), UDim2.new(1, 0, 0, 20), Theme.Green)
					bar.Back.LayoutOrder = 3
					bar.Set(entry.P / def.Obj.Count, ("%d / %d"):format(entry.P, def.Obj.Count))
					local b = Widgets.button({
						Name = "Claim",
						Text = if entry.C then L.t("quests.claimed") else L.t("quests.claim"),
						Color = Theme.Green,
						Size = UDim2.fromOffset(104, 36),
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -8, 0, 12),
						ZIndex = 23,
						MaxTextSize = 18,
						OnClick = function()
							Actions.call("DailyQuestClaim", id)
						end,
						Parent = card,
					})
					Widgets.setEnabled(b, done and not entry.C, Theme.Green)
				end
			end
			UiKit.flowText(scroll, L.t("quests.refresh_utc"), { TextColor3 = Theme.TextDim, LayoutOrder = 0 })
		elseif view == "Story" then
			for i, npcId in ipairs(QuestData.NpcOrder) do
				local npc = QuestData.Npcs[npcId]
				local chain = QuestData.Chains[npcId]
				local st = core.Quests.Chains[npcId] or { Step = 1, Accepted = false, Progress = 0 }
				local step = chain.Steps[st.Step]
				local card, col = UiKit.flowCard(scroll, 60, npc.Color, i, 10, 10)
				card.Name = npcId
				UiKit.flowText(
					col,
					("%s - %s (%d/%d)"):format(
						L.n(npc.Name),
						L.n(chain.Name),
						math.min(st.Step - 1, #chain.Steps),
						#chain.Steps
					),
					{ Font = Theme.Font, TextColor3 = npc.Color, TextSize = 18, LayoutOrder = 1 }
				)
				if step then
					UiKit.flowText(
						col,
						L.n(step.Title)
							.. ": "
							.. (
								if st.Accepted
									then objText(step.Obj)
									else L.t("quests.talk_to", { npc = npc.Name })
							),
						{ LayoutOrder = 2 }
					)
					local bar = UiKit.bar(col, UDim2.new(), UDim2.new(1, 0, 0, 20), Theme.Blue)
					bar.Back.LayoutOrder = 3
					bar.Set(
						if st.Accepted then st.Progress / step.Obj.Count else 0,
						if st.Accepted
							then ("%d / %d"):format(st.Progress, step.Obj.Count)
							else L.t("quests.not_started")
					)
					UiKit.flowText(
						col,
						L.t("quests.reward", { reward = rewardText(step.Reward) }),
						{ TextColor3 = Theme.Gold, LayoutOrder = 4 }
					)
				else
					UiKit.flowText(col, L.t("quests.all_done"), { TextColor3 = Theme.Green, LayoutOrder = 2 })
				end
			end
		else
			local total, got = #AchievementData.List, 0
			for i, a in ipairs(AchievementData.List) do
				local value = core.Stats[a.Stat] or 0
				local done = core.Achievements[a.Id] == true
				if done then
					got += 1
				end
				local card, col = UiKit.flowCard(scroll, 54, if done then Theme.Gold else nil, i, 10, 96)
				card.Name = a.Id
				UiKit.flowText(col, L.n(a.Name) .. (if done then L.t("quests.done_suffix") else ""), {
					Font = Theme.Font,
					TextColor3 = if done then Theme.Gold else Theme.Text,
					TextSize = 18,
					LayoutOrder = 1,
				})
				UiKit.flowText(col, L.n(a.Desc), { TextColor3 = Theme.TextDim, LayoutOrder = 2 })
				local bar = UiKit.bar(col, UDim2.new(), UDim2.new(1, 0, 0, 20), Theme.Gold)
				bar.Back.LayoutOrder = 3
				bar.Set(
					math.min(1, value / a.Goal),
					("%s / %s"):format(Util.formatNumber(math.min(value, a.Goal)), Util.formatNumber(a.Goal))
				)
				UiKit.text(
					card,
					"+" .. L.t("reward.gems", { n = a.Gems }),
					UDim2.new(1, -92, 0, 8),
					UDim2.fromOffset(84, 24),
					{ TextColor3 = Theme.Gem, MaxSize = 16, TextXAlignment = Enum.TextXAlignment.Right }
				)
			end
			UiKit.flowText(
				scroll,
				L.t("quests.ach_count", { n = got, total = total }),
				{ TextColor3 = Theme.TextDim, LayoutOrder = 0 }
			)
		end
	end

	local sig = ""
	ClientState.onCore(function(core)
		if not panel.IsOpen() then
			return
		end
		local parts = { view }
		for id, e in pairs(core.Quests.Daily) do
			table.insert(parts, id .. e.P .. tostring(e.C))
		end
		for id, s in pairs(core.Quests.Chains) do
			table.insert(parts, id .. s.Step .. tostring(s.Accepted) .. s.Progress)
		end
		for _, a in ipairs(AchievementData.List) do
			table.insert(parts, tostring(core.Stats[a.Stat] or 0) .. tostring(core.Achievements[a.Id]))
		end
		local s = table.concat(parts, ",")
		if s ~= sig then
			sig = s
			panel.Refresh()
		end
	end)
	L.onChanged(function()
		sig = ""
		if panel.IsOpen() then
			panel.Refresh()
		end
	end)
	local open = panel.Open
	panel.Open = function()
		open()
		sig = ""
		panel.Refresh()
	end
	return panel
end

return QuestsPanel
