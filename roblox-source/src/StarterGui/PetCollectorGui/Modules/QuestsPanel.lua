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
					local card =
						UiKit.card(scroll, 64, if done and not entry.C then Theme.Green else nil, order)
					card.Name = id
					UiKit.text(
						card,
						L.n(def.Name),
						UDim2.fromOffset(10, 4),
						UDim2.new(0.5, 0, 0, 22),
						{ Font = Theme.Font, MaxSize = 18 }
					)
					UiKit.text(
						card,
						L.t("quests.obj_reward", { obj = objText(def.Obj), reward = rewardText(def.Reward) }),
						UDim2.fromOffset(10, 26),
						UDim2.new(0.7, 0, 0, 16),
						{ TextColor3 = Theme.TextDim, MaxSize = 13 }
					)
					local bar =
						UiKit.bar(card, UDim2.fromOffset(10, 45), UDim2.new(0.65, 0, 0, 14), Theme.Green)
					bar.Set(entry.P / def.Obj.Count, ("%d / %d"):format(entry.P, def.Obj.Count))
					local b = Widgets.button({
						Name = "Claim",
						Text = if entry.C then L.t("quests.claimed") else L.t("quests.claim"),
						Color = Theme.Green,
						Size = UDim2.new(0.2, 0, 0, 36),
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
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
			UiKit.text(
				scroll,
				L.t("quests.refresh_utc"),
				UDim2.fromOffset(4, 0),
				UDim2.new(1, -8, 0, 20),
				{ TextColor3 = Theme.TextDim, MaxSize = 13 }
			)
		elseif view == "Story" then
			for i, npcId in ipairs(QuestData.NpcOrder) do
				local npc = QuestData.Npcs[npcId]
				local chain = QuestData.Chains[npcId]
				local st = core.Quests.Chains[npcId] or { Step = 1, Accepted = false, Progress = 0 }
				local step = chain.Steps[st.Step]
				local card = UiKit.card(scroll, 78, npc.Color, i)
				card.Name = npcId
				UiKit.text(
					card,
					("%s - %s (%d/%d)"):format(
						L.n(npc.Name),
						L.n(chain.Name),
						math.min(st.Step - 1, #chain.Steps),
						#chain.Steps
					),
					UDim2.fromOffset(10, 4),
					UDim2.new(1, -20, 0, 22),
					{ Font = Theme.Font, TextColor3 = npc.Color, MaxSize = 17 }
				)
				if step then
					UiKit.text(
						card,
						L.n(step.Title)
							.. ": "
							.. (
								if st.Accepted
									then objText(step.Obj)
									else L.t("quests.talk_to", { npc = npc.Name })
							),
						UDim2.fromOffset(10, 28),
						UDim2.new(1, -20, 0, 18),
						{ MaxSize = 14 }
					)
					local bar =
						UiKit.bar(card, UDim2.fromOffset(10, 52), UDim2.new(0.6, 0, 0, 16), Theme.Blue)
					bar.Set(
						if st.Accepted then st.Progress / step.Obj.Count else 0,
						if st.Accepted
							then ("%d / %d"):format(st.Progress, step.Obj.Count)
							else L.t("quests.not_started")
					)
					UiKit.text(
						card,
						L.t("quests.reward", { reward = rewardText(step.Reward) }),
						UDim2.new(0.64, 0, 0, 50),
						UDim2.new(0.34, 0, 0, 22),
						{ TextColor3 = Theme.Gold, MaxSize = 12 }
					)
				else
					UiKit.text(
						card,
						L.t("quests.all_done"),
						UDim2.fromOffset(10, 32),
						UDim2.new(1, -20, 0, 22),
						{ TextColor3 = Theme.Green, MaxSize = 15 }
					)
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
				local card = UiKit.card(scroll, 54, if done then Theme.Gold else nil, i)
				card.Name = a.Id
				UiKit.text(
					card,
					L.n(a.Name) .. (if done then L.t("quests.done_suffix") else ""),
					UDim2.fromOffset(10, 3),
					UDim2.new(0.6, 0, 0, 20),
					{ Font = Theme.Font, TextColor3 = if done then Theme.Gold else Theme.Text, MaxSize = 16 }
				)
				UiKit.text(
					card,
					L.n(a.Desc),
					UDim2.fromOffset(10, 22),
					UDim2.new(0.6, 0, 0, 16),
					{ TextColor3 = Theme.TextDim, MaxSize = 13 }
				)
				local bar = UiKit.bar(card, UDim2.fromOffset(10, 39), UDim2.new(0.55, 0, 0, 11), Theme.Gold)
				bar.Set(math.min(1, value / a.Goal), "")
				UiKit.text(
					card,
					("%s / %s"):format(Util.formatNumber(math.min(value, a.Goal)), Util.formatNumber(a.Goal)),
					UDim2.new(0.58, 0, 0, 36),
					UDim2.new(0.2, 0, 0, 14),
					{ MaxSize = 12 }
				)
				UiKit.text(
					card,
					"+" .. L.t("reward.gems", { n = a.Gems }),
					UDim2.new(0.8, 0, 0, 16),
					UDim2.new(0.18, 0, 0, 22),
					{ TextColor3 = Theme.Gem, MaxSize = 15, TextXAlignment = Enum.TextXAlignment.Right }
				)
			end
			UiKit.text(
				scroll,
				L.t("quests.ach_count", { n = got, total = total }),
				UDim2.fromOffset(4, 0),
				UDim2.new(1, -8, 0, 20),
				{ TextColor3 = Theme.TextDim, MaxSize = 14 }
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
