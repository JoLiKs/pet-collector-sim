--!nonstrict
-- Таблицы лидеров: сервер (Live — игроки на сервере) и глобальная по заработанным монетам.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local BoardsPanel = {}

local TABS = { "Coins", "Kills", "Rebirths", "Power", "Hatched", "Global" }

function BoardsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Leaderboards")
	local body = panel.Body
	local data: any = nil
	local view = "Coins"
	local scroll =
		Widgets.scroller(body, { Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 1, -50) })
	UiKit.list(scroll, 4)
	UiKit.tabs(body, TABS, function(name)
		view = name
		panel.Refresh()
	end, 4, 100)

	function panel.Refresh()
		Widgets.clear(scroll)
		if not data then
			UiKit.text(
				scroll,
				L.t("common.loading"),
				UDim2.fromOffset(4, 4),
				UDim2.new(1, -8, 0, 24),
				{ TextColor3 = Theme.TextDim }
			)
			return
		end
		local list = if view == "Global" then data.Global else data.Live[view]
		if not list or #list == 0 then
			UiKit.text(
				scroll,
				if view == "Global" then L.t("boards.global_empty") else L.t("boards.no_data"),
				UDim2.fromOffset(4, 4),
				UDim2.new(1, -8, 0, 24),
				{ TextColor3 = Theme.TextDim }
			)
			return
		end
		for i, e in ipairs(list) do
			local card = UiKit.card(scroll, 34, if i == 1 then Theme.Gold else nil, i)
			UiKit.text(
				card,
				"#" .. i,
				UDim2.fromOffset(8, 0),
				UDim2.fromOffset(40, 34),
				{ Font = Theme.Font, TextColor3 = if i == 1 then Theme.Gold else Theme.TextDim }
			)
			UiKit.text(card, tostring(e.Name), UDim2.fromOffset(54, 0), UDim2.fromScale(0.55, 1))
			UiKit.text(
				card,
				Util.formatNumber(e.Value),
				UDim2.fromScale(0.6, 0),
				UDim2.fromScale(0.38, 1),
				{ TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Gold }
			)
		end
	end

	Remotes.getEvent("Boards").OnClientEvent:Connect(function(d)
		data = d
		panel.Refresh()
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
		Actions.call("GetBoards")
	end
	return panel
end

return BoardsPanel
