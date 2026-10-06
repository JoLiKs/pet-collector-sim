--!nonstrict
-- Магазин: геймпассы и девелоперские продукты. Покупка проходит через Roblox (Prompt*),
-- а выдачу награды делает только сервер (ProcessReceipt / PromptGamePassPurchaseFinished).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local ShopPanel = {}

local localPlayer = Players.LocalPlayer

local function section(parent: Instance, title: any, order: number): (Frame, TextLabel)
	local header = Widgets.label({
		Text = title,
		Size = UDim2.new(1, -8, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font,
		TextColor3 = Theme.Gold,
		LayoutOrder = order,
		ZIndex = 22,
		Parent = parent,
	})
	local grid = Widgets.New("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
		ZIndex = 22,
		Parent = parent,
	})
	Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 150),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	return grid, header
end

local function card(parent: Instance, name: any, desc: any, color: Color3): (Frame, TextButton)
	local c = Widgets.New("Frame", { BackgroundColor3 = Theme.BgCard, ZIndex = 23, Parent = parent })
	Widgets.corner(c, 12)
	Widgets.stroke(c, color, 2)
	Widgets.label({
		Text = name,
		Size = UDim2.new(1, -10, 0, 26),
		Position = UDim2.fromOffset(5, 5),
		Font = Theme.Font,
		TextColor3 = color,
		ZIndex = 24,
		Parent = c,
	})
	local d = Widgets.label({
		Text = desc,
		Size = UDim2.new(1, -12, 0, 54),
		Position = UDim2.fromOffset(6, 34),
		TextColor3 = Theme.TextDim,
		ZIndex = 24,
		Parent = c,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8, Parent = d })
	local buy = Widgets.button({
		Text = "...",
		Color = Theme.Green,
		Size = UDim2.new(1, -16, 0, 36),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		ZIndex = 24,
		Parent = c,
	})
	return c, buy
end

-- Цена из Marketplace (с запасным вариантом — подсказка из Config)
local function fetchPrice(id: number, infoType: Enum.InfoType, fallback: number, apply: (number) -> ())
	if id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			apply(info.PriceInRobux)
		else
			apply(fallback)
		end
	end)
end

local function notConfigured()
	Toasts.show("shop.not_configured", "error")
end

function ShopPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Shop")
	local scroll =
		Widgets.scroller(panel.Body, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 1, -12) })
	Widgets.New(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll }
	)
	Widgets.padding(scroll, 4)

	-- Геймпассы
	local passGrid = section(scroll, L.k("shop.passes"), 1)
	local passButtons = {}
	for _, key in ipairs(Config.GAMEPASS_ORDER) do
		local info = Config.GAMEPASSES[key]
		local id = Config.GAMEPASS_IDS[key]
		local _, buy = card(passGrid, L.kn(info.Name), L.kn(info.Description), Theme.Gold)
		passButtons[key] = buy
		if id == 0 then
			L.bind(buy, "Text", L.k("shop.soon"))
		else
			buy.Text = "R$ ?"
		end
		fetchPrice(id, Enum.InfoType.GamePass, info.SuggestedPrice, function(price)
			if passButtons[key] and not (ClientState.Core and ClientState.Core.Passes[key]) then
				passButtons[key].Text = "R$ " .. tostring(price)
			end
		end)
		buy.Activated:Connect(function()
			if ClientState.Core and ClientState.Core.Passes[key] then
				return
			end
			if id == 0 then
				notConfigured()
				return
			end
			MarketplaceService:PromptGamePassPurchase(localPlayer, id)
		end)
	end

	-- Продукты по видам. Валюта и бусты удачи — это "платные случайные предметы" (через яйца),
	-- поэтому для игроков с PolicyService.ArePaidRandomItemsRestricted эти разделы скрываются.
	local groups = {
		{ Title = L.k("shop.group_gems"), Kind = "Gems", Color = Theme.Gem },
		{ Title = L.k("shop.group_coins"), Kind = "Coins", Color = Theme.Gold },
		{ Title = L.k("shop.group_luck"), Kind = "Luck", Color = Theme.Green },
	}
	local order = 10
	local restrictedNote = Widgets.label({
		Text = L.k("shop.restricted"),
		Size = UDim2.new(1, -8, 0, 40),
		TextColor3 = Theme.TextDim,
		LayoutOrder = 9,
		Visible = false,
		ZIndex = 22,
		Parent = scroll,
	})
	local groupFrames = {}
	for _, group in ipairs(groups) do
		local grid, header = section(scroll, group.Title, order)
		table.insert(groupFrames, { Grid = grid, Header = header })
		order += 10
		for _, key in ipairs(Config.PRODUCT_ORDER) do
			local def = Config.PRODUCTS[key]
			if def.Kind == group.Kind then
				local id = Config.PRODUCT_IDS[key]
				local desc
				if def.Kind == "Gems" then
					desc = L.k("shop.desc_gems", { amount = Util.formatNumber(def.Amount), n = def.Amount })
				elseif def.Kind == "Coins" then
					desc = L.k("shop.desc_coins", { n = Util.formatNumber(def.Clicks) })
				else
					desc = L.k("shop.desc_luck", { x = def.Multiplier, n = def.Seconds // 60 })
				end
				local _, buy = card(grid, L.kn(def.Name), desc, group.Color)
				if id == 0 then
					L.bind(buy, "Text", L.k("shop.soon"))
				else
					buy.Text = "R$ ?"
				end
				fetchPrice(id, Enum.InfoType.Product, def.SuggestedPrice, function(price)
					buy.Text = "R$ " .. tostring(price)
				end)
				buy.Activated:Connect(function()
					if id == 0 then
						notConfigured()
						return
					end
					MarketplaceService:PromptProductPurchase(localPlayer, id)
				end)
			end
		end
	end

	Widgets.label({
		Text = L.k("shop.disclaimer"),
		Size = UDim2.new(1, -8, 0, 36),
		TextColor3 = Theme.TextDim,
		LayoutOrder = 1000,
		ZIndex = 22,
		Parent = scroll,
	})

	ClientState.onCore(function(core)
		local restricted = core.PaidRandomRestricted == true
		restrictedNote.Visible = restricted
		for _, g in ipairs(groupFrames) do
			g.Grid.Visible = not restricted
			g.Header.Visible = not restricted
		end
		for key, btn in pairs(passButtons) do
			if core.Passes[key] then
				L.unbind(btn, "Text")
				btn.Text = L.t("shop.owned")
				btn.BackgroundColor3 = Theme.Disabled
			end
		end
	end)
	return panel
end

return ShopPanel
