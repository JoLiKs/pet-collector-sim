--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Formulas = require(Shared:WaitForChild("Formulas"))
local UpgradeData = require(Shared:WaitForChild("UpgradeData"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local UpgradesPanel = {}

function UpgradesPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Upgrades")
	local scroll =
		Widgets.scroller(panel.Body, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 1, -12) })
	Widgets.New(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll }
	)
	Widgets.padding(scroll, 4)

	local rows = {}
	for i, def in ipairs(UpgradeData.List) do
		-- v3.2.1: карточка растёт по тексту; название и описание — фиксированный размер шрифта с переносом
		-- (раньше TextScaled: короткое описание было крупным, длинное — мелким)
		local row, col = UiKit.flowCard(scroll, 84, nil, i, 12, 150)
		row.Name = def.Id
		local name = UiKit.flowText(col, L.kn(def.Name), {
			Name = "Title",
			Font = Theme.Font,
			TextSize = 18,
			LayoutOrder = 1,
		})
		UiKit.flowText(col, L.kn(def.Description), {
			Name = "Desc",
			TextColor3 = Theme.TextDim,
			TextSize = 15,
			LayoutOrder = 2,
		})
		local level = Widgets.label({
			Name = "Level",
			TextScaled = false,
			TextSize = 15,
			Size = UDim2.fromOffset(136, 22),
			Position = UDim2.new(1, -144, 0, 6),
			ZIndex = 23,
			Parent = row,
		})
		local buy = Widgets.button({
			Text = "",
			Name = "Buy",
			Size = UDim2.fromOffset(136, 40),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 34),
			ZIndex = 23,
			OnClick = function()
				Actions.call("BuyUpgrade", def.Id)
			end,
			Parent = row,
		})
		rows[def.Id] = { Level = level, Buy = buy, Name = name }
	end

	ClientState.onCore(function(core)
		for _, def in ipairs(UpgradeData.List) do
			local r = rows[def.Id]
			local lv = core.Upgrades[def.Id] or 0
			r.Level.Text = L.t("common.level_of", { n = lv, max = def.MaxLevel })
			local cost = Formulas.upgradeCost(def.Id, lv)
			if not cost then
				r.Buy.Text = L.t("common.max")
				Widgets.setEnabled(r.Buy, false)
			else
				local have = if def.Currency == "Gems" then core.Gems else core.Coins
				r.Buy.Text = L.t(
					if def.Currency == "Gems" then "common.price_gems" else "common.price_coins",
					{ price = Util.formatNumber(cost), n = cost }
				)
				Widgets.setEnabled(r.Buy, have >= cost, Theme.Green)
				-- Кнопка остаётся кликабельной всегда (сервер проверит), но цвет подсказывает, хватает ли валюты
				r.Buy.Active = true
			end
		end
	end)
	return panel
end

return UpgradesPanel
