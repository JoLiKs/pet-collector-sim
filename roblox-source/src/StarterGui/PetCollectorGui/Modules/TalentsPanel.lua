--!nonstrict
-- Дерево талантов (3 ветки) + ссылка на ребёрт.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local TalentData = require(Shared:WaitForChild("TalentData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
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
		UDim2.new(1, -330, 0, 30),
		{ Font = Theme.Font, TextColor3 = Theme.Gold, MaxSize = 22 }
	)
	local info = UiKit.text(
		body,
		L.k("talents.hint"),
		UDim2.fromOffset(12, 44),
		UDim2.new(1, -24, 0, 22),
		{ TextColor3 = Theme.TextDim, MaxSize = 16 }
	)
	local goBtn = Widgets.button({
		Name = "GoRebirth",
		Text = L.k("talents.go_rebirth"),
		Color = Theme.Purple,
		Size = UDim2.fromOffset(140, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -166, 0, 4),
		ZIndex = 23,
		MaxTextSize = 18,
		OnClick = function()
			panel.Close()
			openRebirth()
		end,
		Parent = body,
	})
	local respecBtn = Widgets.button({
		Name = "Respec",
		Text = L.k("talents.reset", { n = TalentData.RESPEC_GEMS }),
		Color = Theme.Red,
		Size = UDim2.fromOffset(150, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 4),
		ZIndex = 23,
		MaxTextSize = 14,
		OnClick = function()
			Actions.call("TalentReset")
		end,
		Parent = body,
	})

	local cols = Widgets.New("Frame", {
		Position = UDim2.fromOffset(8, 72),
		Size = UDim2.new(1, -16, 1, -78),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = body,
	})
	-- v3.2: узкое окно (телефон вертикально) — кнопки второй строкой, очки талантов — на всю ширину
	Layout.onChanged(function(li)
		local narrow = li.Mode == "portrait"
		points.Size = if narrow then UDim2.new(1, -24, 0, 30) else UDim2.new(1, -330, 0, 30)
		goBtn.AnchorPoint = if narrow then Vector2.new(0, 0) else Vector2.new(1, 0)
		goBtn.Position = if narrow then UDim2.fromOffset(10, 38) else UDim2.new(1, -166, 0, 4)
		goBtn.Size = if narrow then UDim2.new(0.5, -14, 0, 36) else UDim2.fromOffset(140, 36)
		respecBtn.Size = if narrow then UDim2.new(0.5, -14, 0, 36) else UDim2.fromOffset(150, 36)
		respecBtn.Position = if narrow then UDim2.new(1, -10, 0, 38) else UDim2.new(1, -8, 0, 4)
		info.Position = UDim2.fromOffset(12, if narrow then 80 else 44)
		cols.Position = UDim2.fromOffset(8, if narrow then 106 else 72)
		cols.Size = UDim2.new(1, -16, 1, if narrow then -112 else -78)
	end)
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
		UiKit.text(col, L.kn(branch), UDim2.fromOffset(8, 4), UDim2.new(1, -16, 0, 24), {
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
		points.Text = L.t("talents.points", { n = core.TalentPoints })
		info.Text = L.t("talents.info", { n = core.Rebirths })
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
			-- v3.2: карточка выше — название в 2 строки, описание до 3 строк при тексте >= 12 px
			local card = UiKit.card(columns[t.Branch], 154, if lvl > 0 then color else nil, i)
			card.Name = t.Id
			UiKit.text(card, L.n(t.Name), UDim2.fromOffset(6, 2), UDim2.new(1, -12, 0, 44), {
				Font = Theme.Font,
				TextColor3 = if locked then Theme.TextDim else Theme.Text,
				MaxSize = 18,
				TextWrapped = true,
			})
			-- v3.2.1: описание — фиксированный размер с переносом (не TextScaled), одинаковый у всех талантов
			local desc = UiKit.text(card, L.n(t.Desc), UDim2.fromOffset(6, 46), UDim2.new(1, -12, 0, 72), {
				TextColor3 = Theme.TextDim,
				TextScaled = false,
				TextSize = 15,
				NoLimit = true,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			desc.Name = "Desc"
			UiKit.text(
				card,
				("%d / %d"):format(lvl, t.Max),
				UDim2.new(0, 6, 1, -28),
				UDim2.new(0.42, 0, 0, 22),
				{ TextColor3 = color, MaxSize = 16 }
			)
			local b = Widgets.button({
				Name = "Buy",
				Text = if locked
					then L.t("talents.locked")
					elseif lvl >= t.Max then L.t("talents.max")
					else "+1",
				Color = color,
				Size = UDim2.new(0.5, 0, 0, 26),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -5),
				ZIndex = 24,
				MaxTextSize = 16,
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
	L.onChanged(function()
		if panel.IsOpen() then
			panel.Refresh()
		end
	end)
	local open = panel.Open
	panel.Open = function()
		open()
		panel.Refresh()
	end
	return panel
end

return TalentsPanel
