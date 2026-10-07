--!nonstrict
-- Рынок хаба: ротация предложений за монеты/гемы + батл-пасс (бесплатный и премиум трек).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local BattlePassData = require(Shared:WaitForChild("BattlePassData"))
local Config = require(Shared:WaitForChild("Config"))
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
		Widgets.scroller(body, { Position = UDim2.fromOffset(10, 78), Size = UDim2.new(1, -20, 1, -86) })
	UiKit.list(scroll, 6)
	local header = UiKit.text(
		body,
		"",
		UDim2.fromOffset(10, 38),
		UDim2.new(1, -230, 0, 34),
		{ TextColor3 = Theme.Gold, MaxSize = 16 }
	)
	local bpBar = UiKit.bar(body, UDim2.new(1, -330, 0, 44), UDim2.fromOffset(200, 18), Theme.Blue)
	Widgets.button({
		Name = "ClaimAll",
		Text = L.k("market.claim_all"),
		Color = Theme.Green,
		Size = UDim2.fromOffset(100, 28),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -112, 0, 40),
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
		Size = UDim2.fromOffset(100, 28),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 40),
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
				local card = UiKit.card(scroll, 56, nil, i)
				card.Name = o.Id
				UiKit.text(
					card,
					L.n(o.Name),
					UDim2.fromOffset(10, 4),
					UDim2.new(0.55, 0, 0, 22),
					{ Font = Theme.Font, MaxSize = 18 }
				)
				UiKit.text(
					card,
					L.t("market.left", { desc = o.Desc, n = o.Left, stock = o.Stock }),
					UDim2.fromOffset(10, 28),
					UDim2.new(0.6, 0, 0, 20),
					{ TextColor3 = Theme.TextDim, MaxSize = 13 }
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
					Size = UDim2.new(0.3, 0, 0, 38),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
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
				local row = UiKit.card(scroll, 44, Theme.Gold, 0)
				row.Name = "PremiumBanner"
				UiKit.text(
					row,
					L.t("market.premium_banner"),
					UDim2.fromOffset(10, 0),
					UDim2.fromScale(0.62, 1),
					{ MaxSize = 14, TextColor3 = Theme.Gold }
				)
				Widgets.button({
					Name = "GetPass",
					Text = L.t("market.get_premium"),
					Color = Theme.Gold,
					Size = UDim2.new(0.28, 0, 0, 32),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					ZIndex = 24,
					MaxTextSize = 16,
					OnClick = buyPass,
					Parent = row,
				})
			end
			for lv = 1, BattlePassData.MaxLevel do
				local reached = bp.Level >= lv
				local fr, pr = BattlePassData.Free[lv], BattlePassData.Premium[lv]
				local card = UiKit.card(scroll, 50, if reached then Theme.Blue else nil, lv)
				card.Name = "L" .. lv
				UiKit.text(
					card,
					L.t("market.lv", { n = lv }),
					UDim2.fromOffset(8, 0),
					UDim2.fromOffset(40, 50),
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
						UDim2.new(x, 0, 0, 2),
						UDim2.new(0.28, 0, 0, 24),
						{ TextColor3 = if track == "Free" then Theme.Text else Theme.Gold, MaxSize = 12 }
					)
					local b = Widgets.button({
						Name = "Claim" .. track,
						Text = if done
							then L.t("quests.claimed")
							elseif track == "Premium" and not premium then L.t("talents.locked")
							else L.t("quests.claim"),
						Color = if track == "Free" then Theme.Green else Theme.Gold,
						Size = UDim2.new(0.25, 0, 0, 20),
						Position = UDim2.new(x, 0, 0, 27),
						ZIndex = 24,
						MaxTextSize = 12,
						OnClick = function()
							Actions.call("BpClaim", track, lv)
						end,
						Parent = card,
					})
					Widgets.setEnabled(b, ok, if track == "Free" then Theme.Green else Theme.Gold)
				end
				cell("Free", fr, 0.08)
				cell("Premium", pr, 0.4)
			end
			-- докупка уровней продуктом (v2.4, аудит В3: на максимальном уровне строка скрыта —
			-- покупать уже нечего; при покупке «впритык» сервер компенсирует недостающие уровни гемами)
			local id = Config.PRODUCT_IDS.BP_SKIP
			local row = UiKit.card(scroll, 44, nil, 1000)
			row.Visible = bp.Level < BattlePassData.MaxLevel
			row.Name = "SkipLevels"
			UiKit.text(
				row,
				L.t("market.skip", { n = BattlePassData.SKIP_LEVELS }),
				UDim2.fromOffset(10, 0),
				UDim2.fromScale(0.6, 1),
				{ MaxSize = 16 }
			)
			Widgets.button({
				Name = "BuySkip",
				Text = if id == 0 then L.t("shop.soon") else L.t("market.buy"),
				Color = Theme.Purple,
				Size = UDim2.new(0.28, 0, 0, 32),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
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
