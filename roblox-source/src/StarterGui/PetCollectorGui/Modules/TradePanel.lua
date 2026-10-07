--!nonstrict
-- Обмен: приглашение игрока или торговец Tom (бот в демо). Обе стороны подтверждают.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Config = require(Shared:WaitForChild("Config"))
local PetMeta = require(Shared:WaitForChild("PetMeta"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local TradePanel = {}

local localPlayer = Players.LocalPlayer

function TradePanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Trade")
	local body = panel.Body

	-- ---------- режим «без обмена» ----------
	local idle = Widgets.New("Frame", {
		Name = "Idle",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = body,
	})
	UiKit.text(
		idle,
		L.k("trade.ui.intro"),
		UDim2.fromOffset(12, 6),
		UDim2.new(1, -24, 0, 22),
		{ TextColor3 = Theme.TextDim, MaxSize = 15 }
	)
	Widgets.button({
		Name = "TradeBot",
		Text = L.k("trade.ui.with_bot", { name = Config.DEMO_BOT_NAME }),
		Color = Theme.Purple,
		Size = UDim2.new(1, -24, 0, 48),
		Position = UDim2.fromOffset(12, 34),
		ZIndex = 23,
		MaxTextSize = 20,
		Visible = Config.DEMO_BOT_ENABLED, -- v2.4 (аудит В1): NPC-партнёр только в веб-демо
		OnClick = function()
			Actions.call("TradeStartBot")
		end,
		Parent = idle,
	})
	UiKit.text(
		idle,
		L.k("trade.ui.nearby"),
		UDim2.fromOffset(12, 92),
		UDim2.new(1, -24, 0, 20),
		{ MaxSize = 15 }
	)
	local plist =
		Widgets.scroller(idle, { Position = UDim2.fromOffset(12, 116), Size = UDim2.new(1, -24, 1, -190) })
	UiKit.list(plist, 4)
	local inviteBox = Widgets.New("Frame", {
		Name = "Invite",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -8),
		Size = UDim2.new(1, -24, 0, 56),
		BackgroundColor3 = Theme.BgCard,
		Visible = false,
		ZIndex = 22,
		Parent = idle,
	})
	Widgets.corner(inviteBox, 10)
	Widgets.stroke(inviteBox, Theme.Gold, 2)
	local inviteText =
		UiKit.text(inviteBox, "", UDim2.fromOffset(10, 4), UDim2.new(0.5, 0, 1, -8), { MaxSize = 17 })
	Widgets.button({
		Name = "Accept",
		Text = L.k("trade.ui.accept"),
		Color = Theme.Green,
		Size = UDim2.new(0.2, 0, 0, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -110, 0.5, 0),
		ZIndex = 24,
		MaxTextSize = 17,
		OnClick = function()
			inviteBox.Visible = false
			Actions.call("TradeRespond", true)
		end,
		Parent = inviteBox,
	})
	Widgets.button({
		Name = "Decline",
		Text = L.k("trade.ui.decline"),
		Color = Theme.Red,
		Size = UDim2.new(0.2, 0, 0, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		ZIndex = 24,
		MaxTextSize = 17,
		OnClick = function()
			inviteBox.Visible = false
			Actions.call("TradeRespond", false)
		end,
		Parent = inviteBox,
	})

	local function fillPlayers()
		Widgets.clear(plist)
		local any = false
		for i, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer then
				any = true
				local card = UiKit.card(plist, 40, nil, i)
				UiKit.text(
					card,
					p.DisplayName,
					UDim2.fromOffset(10, 0),
					UDim2.fromScale(0.6, 1),
					{ MaxSize = 17 }
				)
				Widgets.button({
					Name = "Invite",
					Text = L.k("trade.ui.invite"),
					Color = Theme.Blue,
					Size = UDim2.new(0.25, 0, 0, 30),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					ZIndex = 24,
					MaxTextSize = 16,
					OnClick = function()
						Actions.call("TradeInvite", p.UserId)
					end,
					Parent = card,
				})
			end
		end
		if not any then
			UiKit.text(
				plist,
				L.t("trade.ui.nobody"),
				UDim2.fromOffset(4, 4),
				UDim2.new(1, -8, 0, 22),
				{ TextColor3 = Theme.TextDim, MaxSize = 14 }
			)
		end
	end

	-- ---------- режим «идёт обмен» ----------
	local live = Widgets.New("Frame", {
		Name = "Live",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 21,
		Parent = body,
	})
	local partnerLabel = UiKit.text(
		live,
		"",
		UDim2.fromOffset(12, 4),
		UDim2.new(1, -24, 0, 22),
		{ Font = Theme.Font, MaxSize = 19 }
	)
	local msgLabel = UiKit.text(
		live,
		"",
		UDim2.fromOffset(12, 26),
		UDim2.new(1, -24, 0, 18),
		{ TextColor3 = Theme.Gold, MaxSize = 14 }
	)
	local mineBox = Widgets.New("Frame", {
		Name = "MySide",
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(0.5, -14, 1, -112),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 21,
		Parent = live,
	})
	Widgets.corner(mineBox, 10)
	local theirBox = Widgets.New("Frame", {
		Name = "TheirSide",
		Position = UDim2.new(0.5, 4, 0, 48),
		Size = UDim2.new(0.5, -14, 1, -112),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 21,
		Parent = live,
	})
	Widgets.corner(theirBox, 10)
	local mineTitle = UiKit.text(
		mineBox,
		L.t("trade.ui.you_offer"),
		UDim2.fromOffset(8, 2),
		UDim2.new(1, -16, 0, 20),
		{ Font = Theme.Font, MaxSize = 16 }
	)
	local theirTitle = UiKit.text(
		theirBox,
		L.t("trade.ui.they_offer"),
		UDim2.fromOffset(8, 2),
		UDim2.new(1, -16, 0, 20),
		{ Font = Theme.Font, MaxSize = 16 }
	)
	local mineList =
		Widgets.scroller(mineBox, { Position = UDim2.fromOffset(4, 24), Size = UDim2.new(1, -8, 1, -60) })
	UiKit.list(mineList, 3)
	local theirList =
		Widgets.scroller(theirBox, { Position = UDim2.fromOffset(4, 24), Size = UDim2.new(1, -8, 1, -30) })
	UiKit.list(theirList, 3)
	local coinLabel = UiKit.text(
		mineBox,
		"",
		UDim2.new(0, 8, 1, -30),
		UDim2.new(0.4, 0, 0, 24),
		{ TextColor3 = Theme.Gold, MaxSize = 15 }
	)
	local changeCoins
	local function coinBtn(text, delta, x)
		Widgets.button({
			Name = "Coins" .. text,
			Text = text,
			Color = Theme.BgCard,
			Size = UDim2.new(0.14, 0, 0, 24),
			Position = UDim2.new(x, 0, 1, -30),
			ZIndex = 23,
			MaxTextSize = 13,
			OnClick = function()
				changeCoins(delta)
			end,
			Parent = mineBox,
		})
	end
	coinBtn("-1k", -1000, 0.42)
	coinBtn("+1k", 1000, 0.57)
	coinBtn("+10k", 10000, 0.72)
	coinBtn("0", "clear", 0.87)

	local pickTitle = UiKit.text(
		live,
		L.k("trade.ui.tap_pet"),
		UDim2.new(0, 12, 1, -60),
		UDim2.new(0.4, 0, 0, 16),
		{ TextColor3 = Theme.TextDim, MaxSize = 12 }
	)
	local readyBtn = Widgets.button({
		Name = "Ready",
		Text = L.k("trade.ui.ready"),
		Color = Theme.Blue,
		Size = UDim2.new(0.18, 0, 0, 40),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -330, 1, -8),
		ZIndex = 23,
		MaxTextSize = 18,
		Parent = live,
	})
	local confirmBtn = Widgets.button({
		Name = "Confirm",
		Text = L.k("trade.ui.confirm"),
		Color = Theme.Green,
		Size = UDim2.new(0.22, 0, 0, 40),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -8),
		ZIndex = 23,
		MaxTextSize = 18,
		Parent = live,
	})
	Widgets.button({
		Name = "Cancel",
		Text = L.k("trade.ui.cancel"),
		Color = Theme.Red,
		Size = UDim2.new(0.14, 0, 0, 40),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -8),
		ZIndex = 23,
		MaxTextSize = 18,
		OnClick = function()
			Actions.call("TradeCancel")
		end,
		Parent = live,
	})

	local state: any = nil
	local offerUids: { [string]: boolean } = {}
	local offerCoins = 0
	local picker = Widgets.scroller(
		live,
		{ Name = "Picker", Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(0.4, 0, 0, 38) }
	)
	picker.ScrollingDirection = Enum.ScrollingDirection.X
	picker.CanvasSize = UDim2.new(0, 0, 0, 0)
	UiKit.list(picker, 4, true)

	local function sendOffer()
		local list = {}
		for uid in pairs(offerUids) do
			table.insert(list, uid)
		end
		table.sort(list)
		Actions.call("TradeOffer", list, offerCoins)
	end
	function changeCoins(delta)
		local core = ClientState.Core
		if delta == "clear" then
			offerCoins = 0
		else
			offerCoins = math.clamp(offerCoins + delta, 0, core and core.Coins or 0)
		end
		sendOffer()
	end

	local function petLine(parent, p, i, onClick)
		local color = UiKit.rarityColor(p.Id)
		local row = Widgets.New("TextButton", {
			Name = p.Uid or ("Pet" .. i),
			Text = "",
			Size = UDim2.new(1, -6, 0, 30),
			BackgroundColor3 = Theme.BgCard,
			LayoutOrder = i,
			AutoButtonColor = false,
			ZIndex = 22,
			Parent = parent,
		})
		Widgets.corner(row, 6)
		UiKit.petIcon(row, p.Id, p.Variant, 20, UDim2.fromOffset(5, 5))
		UiKit.text(
			row,
			L.t("trade.ui.pet_line", { name = PetMeta.displayName(p), n = p.Level or 1 }),
			UDim2.fromOffset(30, 0),
			UDim2.new(1, -34, 1, 0),
			{ TextColor3 = color, MaxSize = 14, ZIndex = 24 }
		)
		if onClick then
			row.Activated:Connect(onClick)
		end
		return row
	end

	function panel.Refresh()
		local core = ClientState.Core
		live.Visible = state ~= nil and state.Type == "State"
		idle.Visible = not live.Visible
		if not live.Visible then
			fillPlayers()
			return
		end
		local partner = L.n(state.Partner)
		partnerLabel.Text = L.t("trade.ui.with", { name = partner })
		msgLabel.Text = if state.Msg
			then L.renderLocal(state.Msg)
			else (if state.Status == "Confirming"
				then (if state.CountdownLeft > 0
					then L.t("trade.ui.countdown", { n = state.CountdownLeft })
					else L.t("trade.ui.both_ready"))
				else "")
		mineTitle.Text = L.t(if state.Mine.Ready then "trade.ui.you_offer_ready" else "trade.ui.you_offer")
		theirTitle.Text =
			L.t(if state.Theirs.Ready then "trade.ui.offers_ready" else "trade.ui.offers", { name = partner })
		coinLabel.Text = L.t("trade.ui.coins", { v = Util.formatNumber(state.Mine.Coins) })
		offerCoins = state.Mine.Coins
		offerUids = {}
		Widgets.clear(mineList)
		for i, p in ipairs(state.Mine.Pets) do
			offerUids[p.Uid] = true
			petLine(mineList, p, i, function()
				offerUids[p.Uid] = nil
				sendOffer()
			end)
		end
		Widgets.clear(theirList)
		for i, p in ipairs(state.Theirs.Pets) do
			petLine(theirList, p, i)
		end
		UiKit.text(
			theirList,
			L.t("trade.ui.coins", { v = Util.formatNumber(state.Theirs.Coins) }),
			UDim2.fromOffset(4, 0),
			UDim2.new(1, -8, 0, 22),
			{ TextColor3 = Theme.Gold, MaxSize = 15, LayoutOrder = 100 }
		)
		-- кандидаты для добавления
		Widgets.clear(picker)
		local uids = {}
		for uid, p in pairs(ClientState.Pets) do
			if not offerUids[uid] and not p.Fav then
				table.insert(uids, uid)
			end
		end
		table.sort(uids, function(a, b)
			return ClientState.Pets[a].Power > ClientState.Pets[b].Power
		end)
		local shown = 0
		for _, uid in ipairs(uids) do
			if shown >= 8 then
				break
			end
			shown += 1
			local p = ClientState.Pets[uid]
			local btn = Widgets.New("TextButton", {
				Name = "Add_" .. uid,
				Text = "",
				Size = UDim2.fromOffset(36, 34),
				BackgroundColor3 = Theme.BgCard,
				AutoButtonColor = false,
				LayoutOrder = shown,
				ZIndex = 23,
				Parent = picker,
			})
			Widgets.corner(btn, 6)
			UiKit.petIcon(btn, p.Id, p.Variant, 22, UDim2.fromOffset(7, 6))
			btn.Activated:Connect(function()
				offerUids[uid] = true
				sendOffer()
			end)
		end
		pickTitle.Visible = #uids > 0
		local myReady = state.Mine.Ready
		readyBtn.Text = if myReady then L.t("trade.ui.unready") else L.t("trade.ui.ready")
		readyBtn.BackgroundColor3 = if myReady then Theme.Gold else Theme.Blue
		local canConfirm = state.Status == "Confirming"
			and state.CountdownLeft <= 0
			and not state.Mine.Confirmed
		confirmBtn.Text = if state.Mine.Confirmed then L.t("trade.ui.waiting") else L.t("trade.ui.confirm")
		Widgets.setEnabled(confirmBtn, canConfirm, Theme.Green)
		local _ = core
	end
	readyBtn.Activated:Connect(function()
		if state and state.Type == "State" then
			Actions.call("TradeReady", not state.Mine.Ready)
		end
	end)
	confirmBtn.Activated:Connect(function()
		if state and state.Type == "State" and confirmBtn.Active then
			Actions.call("TradeConfirm")
		end
	end)

	L.onChanged(function()
		if panel.IsOpen() then
			panel.Refresh()
		end
	end)

	local countdownThread = nil
	Remotes.getEvent("TradeUpdate").OnClientEvent:Connect(function(d)
		if type(d) ~= "table" then
			return
		end
		if d.Type == "Invite" then
			inviteText.Text = L.t("trade.ui.wants", { player = tostring(d.From) })
			inviteBox.Visible = true
			Toasts.show(L.t("trade.ui.wants_open", { player = tostring(d.From) }), "info")
			if panel.IsOpen() then
				panel.Refresh()
			end
		elseif d.Type == "State" then
			state = d
			if not panel.IsOpen() then
				panel.Open()
			end
			panel.Refresh()
			if countdownThread then
				task.cancel(countdownThread)
				countdownThread = nil
			end
			if d.Status == "Confirming" and d.CountdownLeft > 0 then
				countdownThread = task.spawn(function()
					while state == d and d.CountdownLeft > 0 do
						task.wait(1)
						if state ~= d then
							return
						end
						d.CountdownLeft -= 1
						panel.Refresh()
					end
				end)
			end
		elseif d.Type == "Closed" then
			state = nil
			Toasts.show(d.Reason or "trade.ui.closed", "info")
			if panel.IsOpen() then
				panel.Refresh()
			end
		end
	end)

	local open = panel.Open
	panel.Open = function()
		if not panel.IsOpen() then
			open()
		end
		panel.Refresh()
	end
	return panel
end

return TradePanel
