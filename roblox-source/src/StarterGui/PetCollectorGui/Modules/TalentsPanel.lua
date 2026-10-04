--!nonstrict
-- Дерево талантов (3 ветки) + ссылка на ребёрт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local TalentData = require(Shared:WaitForChild("TalentData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local TalentsPanel = {}

function TalentsPanel.init(gui: ScreenGui, openRebirth: () -> ())
	local panel = Widgets.panel(gui, "Talents")
	local body = panel.Body
	local points = UiKit.text(
		body,
		"",
		UDim2.fromOffset(12, 6),
		UDim2.new(0.5, 0, 0, 26),
		{ Font = Theme.Font, TextColor3 = Theme.Gold, MaxSize = 20 }
	)
	local info = UiKit.text(
		body,
		"Rebirth to earn talent points.",
		UDim2.fromOffset(12, 32),
		UDim2.new(0.6, 0, 0, 18),
		{ TextColor3 = Theme.TextDim, MaxSize = 14 }
	)
	Widgets.button({
		Name = "GoRebirth",
		Text = "Rebirth",
		Color = Theme.Purple,
		Size = UDim2.fromOffset(110, 34),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -130, 0, 8),
		ZIndex = 23,
		MaxTextSize = 18,
		OnClick = function()
			panel.Close()
			openRebirth()
		end,
		Parent = body,
	})
	Widgets.button({
		Name = "Respec",
		Text = ("Reset (%d gems)"):format(TalentData.RESPEC_GEMS),
		Color = Theme.Red,
		Size = UDim2.fromOffset(120, 34),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		ZIndex = 23,
		MaxTextSize = 14,
		OnClick = function()
			Actions.call("TalentReset")
		end,
		Parent = body,
	})

	local cols = Widgets.New("Frame", {
		Position = UDim2.fromOffset(8, 56),
		Size = UDim2.new(1, -16, 1, -62),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = body,
	})
	local columns = {}
	for i, branch in ipairs(TalentData.BranchOrder) do
		local col = Widgets.New("Frame", {
			Name = branch,
			Position = UDim2.new((i - 1) / 3, 3, 0, 0),
			Size = UDim2.new(1 / 3, -6, 1, 0),
			BackgroundColor3 = Theme.BgLight,
			ZIndex = 21,
			Parent = cols,
		})
		Widgets.corner(col, 10)
		UiKit.text(col, branch, UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 24), {
			Font = Theme.Font,
			TextColor3 = TalentData.Branches[branch].Color,
			MaxSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local sc =
			Widgets.scroller(col, { Position = UDim2.fromOffset(4, 32), Size = UDim2.new(1, -8, 1, -36) })
		UiKit.list(sc, 5)
		columns[branch] = sc
	end

	function panel.Refresh()
		local core = ClientState.Core
		if not core then
			return
		end
		points.Text = ("Talent points: %d"):format(core.TalentPoints)
		info.Text = ("Rebirths: %d  -  1 point per rebirth"):format(core.Rebirths)
		for _, branch in ipairs(TalentData.BranchOrder) do
			Widgets.clear(columns[branch])
		end
		for i, t in ipairs(TalentData.List) do
			local lvl = core.Talents[t.Id] or 0
			local ok = TalentData.canBuy(core.Talents, t.Id, core.TalentPoints)
			local locked = false
			for req, need in pairs(t.Requires) do
				if (core.Talents[req] or 0) < need then
					locked = true
				end
			end
			local color = TalentData.Branches[t.Branch].Color
			local card = UiKit.card(columns[t.Branch], 84, if lvl > 0 then color else nil, i)
			card.Name = t.Id
			UiKit.text(
				card,
				t.Name,
				UDim2.fromOffset(6, 2),
				UDim2.new(1, -12, 0, 18),
				{ Font = Theme.Font, TextColor3 = if locked then Theme.TextDim else Theme.Text, MaxSize = 15 }
			)
			UiKit.text(card, t.Desc, UDim2.fromOffset(6, 20), UDim2.new(1, -12, 0, 30), {
				TextColor3 = Theme.TextDim,
				MaxSize = 11,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			UiKit.text(
				card,
				("%d / %d"):format(lvl, t.Max),
				UDim2.fromOffset(6, 56),
				UDim2.new(0.4, 0, 0, 20),
				{ TextColor3 = color, MaxSize = 14 }
			)
			local b = Widgets.button({
				Name = "Buy",
				Text = if locked then "Locked" elseif lvl >= t.Max then "Max" else "+1",
				Color = color,
				Size = UDim2.new(0.5, 0, 0, 24),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -5),
				ZIndex = 24,
				MaxTextSize = 14,
				OnClick = function()
					Actions.call("TalentBuy", t.Id)
				end,
				Parent = card,
			})
			Widgets.setEnabled(b, ok, color)
		end
	end

	ClientState.onCore(function(core)
		if panel.IsOpen() then
			panel.Refresh()
		end
		local _ = core
	end)
	local open = panel.Open
	panel.Open = function()
		open()
		panel.Refresh()
	end
	return panel
end

return TalentsPanel
