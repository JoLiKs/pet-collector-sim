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
		local row = Widgets.New("Frame", {
			Size = UDim2.new(1, -8, 0, 74),
			BackgroundColor3 = Theme.BgCard,
			LayoutOrder = i,
			ZIndex = 22,
			Parent = scroll,
		})
		Widgets.corner(row, 12)
		local name = Widgets.label({
			Text = L.kn(def.Name),
			Size = UDim2.new(0.55, 0, 0, 26),
			Position = UDim2.fromOffset(12, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Font,
			ZIndex = 23,
			Parent = row,
		})
		Widgets.label({
			Text = L.kn(def.Description),
			Size = UDim2.new(0.55, 0, 0, 30),
			Position = UDim2.fromOffset(12, 34),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.TextDim,
			ZIndex = 23,
			Parent = row,
		})
		local level = Widgets.label({
			Size = UDim2.new(0.2, 0, 0, 22),
			Position = UDim2.new(0.58, 0, 0, 6),
			ZIndex = 23,
			Parent = row,
		})
		local buy = Widgets.button({
			Text = "",
			Size = UDim2.new(0.34, -8, 0, 40),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 8),
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
