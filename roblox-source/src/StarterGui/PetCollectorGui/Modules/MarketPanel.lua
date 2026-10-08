--!nonstrict
-- Рынок хаба: ротация предложений за монеты/гемы + батл-пасс (бесплатный и премиум трек).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local BattlePassData = require(Shared:WaitForChild("BattlePassData"))
local Config = require(Shared:WaitForChild("Config"))
local Prices = require(Shared:WaitForChild("Prices"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local MarketPanel = {}

local function rewardLabel(r): string
	if r.Label then
		return L.n(r.Label)
	end
	return UiKit.rewardText(r)
end

function MarketPanel.init(gui: ScreenGui, openStore: () -> ())
	local panel = Widgets.panel(gui, "Market")
	local body = panel.Body
	local view = "Shop"
	local scroll =
		Widgets.scroller(body, { Position = UDim2.fromOffset(10, 108), Size = UDim2.new(1, -20, 1, -116) })
	UiKit.list(scroll, 6)
	local header = UiKit.text(
		body,
		"",
		UDim2.fromOffset(10, 40),
		UDim2.new(1, -20, 0, 28),
		{ TextColor3 = Theme.Gold, MaxSize = 16 }
	)
	-- v3.2: шапка в две строки: текст на всю ширину, ниже — полоса опыта и кнопки (текст >= 12 px не обрезается)
	local bpBar = UiKit.bar(body, UDim2.fromOffset(10, 76), UDim2.new(1, -284, 0, 22), Theme.Blue)
	Widgets.button({
		Name = "ClaimAll",
		Text = L.k("market.claim_all"),
		Color = Theme.Green,
		Size = UDim2.fromOffset(120, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -134, 0, 72),
		ZIndex = 23,
		MaxTextSize = 15,
		OnClick = function()
			Actions.call("BpClaimAll")
		end,
		Parent = body,
	}).Name =
		"ClaimAll"
	Widgets.button({
		Name = "RobuxStore",
		Text = L.k("market.robux_store"),
		Color = Theme.Purple,
		Size = UDim2.fromOffset(120, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 72),
		ZIndex = 23,
		MaxTextSize = 14,
		OnClick = function()
			panel.Close()
			openStore()
		end,
		Parent = body,
	})
	local claimAll = body:FindFirstChild("ClaimAll")
	UiKit.tabs(body, { "Shop", "Battle Pass" }, function(name)
		view = name
		panel.Refresh()
	end, 4, 150)

	local function buyPass()
		local id = Config.GAMEPASS_IDS.BATTLE_PASS
		if id == 0 then
			Toasts.show("market.bp_not_configured", "info")
			return
		end
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
	end

	function panel.Refresh()
		local core = ClientState.Core
		if not core then
			return
		end
		Widgets.clear(scroll)
		claimAll.Visible = view == "Battle Pass"
		bpBar.Back.Visible = view == "Battle Pass"
		if view == "Shop" then
			local left = core.Shop.SecondsLeft - math.floor(os.clock() - ClientState.ReceivedClock)
			header.Text = L.t(
				"market.rotate",
				{ time = ("%d:%02d"):format(math.max(0, left) // 60, math.max(0, left) % 60) }
			)
			for i, o in ipairs(core.Shop.Offers) do
				local sold = o.Left <= 0
				-- v3.2: карточка растёт по тексту (название и описание переносятся, текст >= 12 px)
				local card, col = UiKit.flowCard(scroll, 56, nil, i, 10, 148)
				card.Name = o.Id
				UiKit.flowText(col, L.n(o.Name), { Font = Theme.Font, TextSize = 18, LayoutOrder = 1 })
				UiKit.flowText(
					col,
					L.t("market.left", { desc = o.Desc, n = o.Left, stock = o.Stock }),
					{ TextColor3 = Theme.TextDim, LayoutOrder = 2 }
				)
				local afford = (if o.Currency == "Gems" then core.Gems else core.Coins) >= o.Price
				local b = Widgets.button({
					Name = "Buy",
					Text = if sold
						then L.t("market.sold_out")
						else L.t(
							if o.Currency == "Gems" then "common.price_gems" else "common.price_coins",
							{ price = Util.formatNumber(o.Price), n = o.Price }
						),
					Color = if o.Currency == "Gems" then Theme.Gem else Theme.Gold,
					Size = UDim2.fromOffset(132, 38),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 9),
					ZIndex = 23,
					MaxTextSize = 16,
					OnClick = function()
						Actions.call("ShopBuy", o.Id)
					end,
					Parent = card,
				})
				Widgets.setEnabled(
					b,
					not sold and afford,
					if o.Currency == "Gems" then Theme.Gem else Theme.Gold
				)
			end
		else
			local bp = core.BattlePass
			local premium = core.Passes.BATTLE_PASS == true
			header.Text = L.t(if premium then "market.bp_header_premium" else "market.bp_header_free", {
				name = BattlePassData.Name,
				n = bp.Level,
				max = BattlePassData.MaxLevel,
			})
			bpBar.Set(
				if bp.Need > 0 then bp.Into / bp.Need else 1,
				if bp.Need > 0 then L.t("market.xp", { n = bp.Into, need = bp.Need }) else L.t("common.max")
			)
			if not premium then
				local row, col = UiKit.flowCard(scroll, 48, Theme.Gold, 0, 10, 148)
				row.Name = "PremiumBanner"
				UiKit.flowText(col, L.t("market.premium_banner"), { TextColor3 = Theme.Gold })
				Widgets.button({
					Name = "GetPass",
					Text = L.t("market.get_premium"),
					Color = Theme.Gold,
					Size = UDim2.fromOffset(132, 34),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 7),
					ZIndex = 24,
					MaxTextSize = 16,
					OnClick = buyPass,
					Parent = row,
				})
			end
			for lv = 1, BattlePassData.MaxLevel do
				local reached = bp.Level >= lv
				local fr, pr = BattlePassData.Free[lv], BattlePassData.Premium[lv]
				local card = UiKit.card(scroll, 66, if reached then Theme.Blue else nil, lv)
				card.Name = "L" .. lv
				UiKit.text(
					card,
					L.t("market.lv", { n = lv }),
					UDim2.fromOffset(8, 0),
					UDim2.fromOffset(40, 66),
					{
						Font = Theme.Font,
						TextColor3 = if reached then Theme.Blue else Theme.TextDim,
						MaxSize = 20,
					}
				)
				local function cell(track, r, x)
					if not r then
						return
					end
					local done = (if track == "Free" then bp.Free else bp.Premium)[tostring(lv)] == true
					local ok = reached and not done and (track == "Free" or premium)
					UiKit.text(
						card,
						rewardLabel(r),
						UDim2.new(x, 0, 0, 3),
						UDim2.new(0.42, -10, 0, 24),
						{ TextColor3 = if track == "Free" then Theme.Text else Theme.Gold, MaxSize = 15 }
					)
					local b = Widgets.button({
						Name = "Claim" .. track,
						Text = if done
							then L.t("quests.claimed")
							elseif track == "Premium" and not premium then L.t("talents.locked")
							else L.t("quests.claim"),
						Color = if track == "Free" then Theme.Green else Theme.Gold,
						Size = UDim2.new(0.3, 0, 0, 30),
						Position = UDim2.new(x, 0, 0, 30),
						ZIndex = 24,
						MaxTextSize = 16,
						OnClick = function()
							Actions.call("BpClaim", track, lv)
						end,
						Parent = card,
					})
					Widgets.setEnabled(b, ok, if track == "Free" then Theme.Green else Theme.Gold)
				end
				cell("Free", fr, 0.1)
				cell("Premium", pr, 0.55)
			end
			-- докупка уровней продуктом (v2.4, аудит В3: на максимальном уровне строка скрыта —
			-- покупать уже нечего; при покупке «впритык» сервер компенсирует недостающие уровни гемами)
			local id = Config.PRODUCT_IDS.BP_SKIP
			local row, col = UiKit.flowCard(scroll, 48, nil, 1000, 10, 148)
			row.Visible = bp.Level < BattlePassData.MaxLevel
			row.Name = "SkipLevels"
			UiKit.flowText(col, L.t("market.skip", { n = BattlePassData.SKIP_LEVELS }))
			local skipBtn = Widgets.button({
				Name = "BuySkip",
				Text = if id == 0 then L.t("shop.soon") else L.t("market.buy"),
				Color = Theme.Purple,
				Size = UDim2.fromOffset(132, 34),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 7),
				ZIndex = 24,
				MaxTextSize = 16,
				OnClick = function()
					if id == 0 then
						Toasts.show("market.skip_not_configured", "info")
					else
						MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
					end
				end,
				Parent = row,
			})
			-- v2.7: на кнопке реальная цена (GetProductInfo, фолбэк SuggestedPrice)
			local skipDef = Config.PRODUCTS.BP_SKIP
			Prices.get(id, "Product", skipDef and skipDef.SuggestedPrice or 0, function(price)
				if skipBtn.Parent and price > 0 then
					skipBtn.Text = Prices.format(price)
				end
			end)
		end
	end

	local sig = ""
	ClientState.onCore(function(core)
		if not panel.IsOpen() then
			return
		end
		local parts = {
			view,
			core.Coins // 50,
			core.Gems,
			core.BattlePass.Level,
			core.BattlePass.Into,
			tostring(core.Passes.BATTLE_PASS),
			core.Shop.SecondsLeft // 5,
		}
		for _, o in ipairs(core.Shop.Offers) do
			table.insert(parts, o.Id .. o.Left)
		end
		for k in pairs(core.BattlePass.Free) do
			table.insert(parts, "f" .. k)
		end
		for k in pairs(core.BattlePass.Premium) do
			table.insert(parts, "p" .. k)
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
	panel.Open = function(tab)
		open()
		sig = ""
		panel.Refresh()
		local _ = tab
	end
	return panel
end

return MarketPanel
