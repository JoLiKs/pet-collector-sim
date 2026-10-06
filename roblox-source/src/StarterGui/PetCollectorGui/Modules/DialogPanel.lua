--!nonstrict
-- Диалог с NPC: реплики по очереди, затем «Принять» или «Сдать квест».
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local QuestData = require(Shared:WaitForChild("QuestData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Actions = require(script.Parent.Actions)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local DialogPanel = {}

function DialogPanel.init(gui: ScreenGui)
	local root = Widgets.New("Frame", {
		Name = "DialogBox",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(640, 190),
		BackgroundColor3 = Theme.Bg,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	Widgets.corner(root, 16)
	local stroke = Widgets.stroke(root, Theme.Gold, 3)
	local nameLabel = UiKit.text(
		root,
		"",
		UDim2.fromOffset(16, 8),
		UDim2.new(1, -60, 0, 28),
		{ Font = Theme.Font, MaxSize = 26, ZIndex = 31 }
	)
	local titleLabel = UiKit.text(
		root,
		"",
		UDim2.fromOffset(16, 36),
		UDim2.new(1, -60, 0, 18),
		{ TextColor3 = Theme.TextDim, MaxSize = 15, ZIndex = 31 }
	)
	local textLabel = UiKit.text(
		root,
		"",
		UDim2.fromOffset(16, 62),
		UDim2.new(1, -32, 0, 66),
		{ MaxSize = 20, ZIndex = 31, TextYAlignment = Enum.TextYAlignment.Top }
	)
	local objLabel = UiKit.text(
		root,
		"",
		UDim2.fromOffset(16, 128),
		UDim2.new(1, -230, 0, 44),
		{ TextColor3 = Theme.Gem, MaxSize = 15, ZIndex = 31 }
	)
	Widgets.button({
		Name = "Close",
		Text = "X",
		Color = Theme.Red,
		Size = UDim2.fromOffset(34, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		ZIndex = 32,
		OnClick = function()
			root.Visible = false
		end,
		Parent = root,
	})
	local actionBtn = Widgets.button({
		Name = "Action",
		Text = L.k("dialog.next"),
		Color = Theme.Green,
		Size = UDim2.fromOffset(190, 44),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		ZIndex = 32,
		MaxTextSize = 20,
		Parent = root,
	})

	local current, line = nil, 1
	local function show()
		if not current then
			return
		end
		local npc = QuestData.Npcs[current.Npc]
		stroke.Color = npc.Color
		nameLabel.Text = L.n(npc.Name)
		nameLabel.TextColor3 = npc.Color
		titleLabel.Text = ("%s  -  %s (%d/%d)"):format(
			L.n(npc.Title),
			L.n(current.Chain),
			current.Step - (if current.Mode == "finished" then 0 else 1),
			current.Total
		)
		local lines = current.Lines
		textLabel.Text = L.renderLocal(lines[math.min(line, #lines)]) or ""
		local last = line >= #lines
		if current.Obj then
			local o = current.Obj
			objLabel.Text = L.t("dialog.quest", {
				title = L.n(current.StepTitle or ""),
				obj = UiKit.objText(o),
				p = current.Progress or 0,
				count = o.Count,
			})
		else
			objLabel.Text = ""
		end
		if not last then
			actionBtn.Text = L.t("dialog.next")
			actionBtn.BackgroundColor3 = Theme.Blue
		elseif current.Mode == "offer" then
			actionBtn.Text = L.t("dialog.accept")
			actionBtn.BackgroundColor3 = Theme.Green
		elseif current.Mode == "done" then
			local r = current.Reward or {}
			actionBtn.Text = L.t("dialog.claim")
			actionBtn.BackgroundColor3 = Theme.Gold
			objLabel.Text = objLabel.Text .. "  " .. L.t("quests.reward", { reward = UiKit.rewardText(r) })
		else
			actionBtn.Text = L.t("dialog.bye")
			actionBtn.BackgroundColor3 = Theme.BgLight
		end
	end
	actionBtn.Activated:Connect(function()
		if not current then
			return
		end
		local last = line >= #current.Lines
		if not last then
			line += 1
			show()
		elseif current.Mode == "offer" then
			if Actions.call("QuestAccept", current.Npc) then
				Actions.call("QuestTalk", current.Npc)
			end
		elseif current.Mode == "done" then
			if Actions.call("QuestClaim", current.Npc) then
				root.Visible = false
			end
		else
			root.Visible = false
		end
	end)

	L.onChanged(function()
		if root.Visible then
			show()
		end
	end)
	Remotes.getEvent("Dialog").OnClientEvent:Connect(function(d)
		if type(d) ~= "table" then
			return
		end
		local sameStep = current
			and current.Npc == d.Npc
			and current.Mode == d.Mode
			and current.Step == d.Step
		current = d
		if not sameStep or not root.Visible then
			line = 1
		end
		root.Visible = true
		show()
	end)
	return {
		IsOpen = function()
			return root.Visible
		end,
		Close = function()
			root.Visible = false
		end,
		Open = function() end,
		Root = root,
	}
end

return DialogPanel
