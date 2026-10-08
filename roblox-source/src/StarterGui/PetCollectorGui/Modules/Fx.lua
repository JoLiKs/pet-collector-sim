--!nonstrict
-- Боевой HUD и эффекты: всплывающие числа, таймеры справа снизу (охота, события, буст, босс),
-- окно оффлайн-награды, открытие панелей по станциям хаба. Удар — инструмент «Меч» в хотбаре (Hotbar, v2.5).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HotbarData = require(Shared:WaitForChild("HotbarData"))
local L = require(Shared:WaitForChild("Locale"))

local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local HuntHud = require(script.Parent.HuntHud)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local Fx = {}

local COLORS = {
	Hit = Color3.fromRGB(255, 255, 255),
	Kill = Theme.Gold,
	Hurt = Color3.fromRGB(255, 80, 80),
	Ability = Theme.Gem,
	Coin = Theme.Gold,
	gather = Color3.fromRGB(120, 235, 140),
}

function Fx.init(gui: ScreenGui, openPanelForce: (string) -> ())
	local camera = Workspace.CurrentCamera
	local layer = Widgets.New("Frame", {
		Name = "FxLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 35,
		Active = false,
		Parent = gui,
	})

	-- ---------- всплывающие числа ----------
	local active = 0
	Remotes.getEvent("Fx").OnClientEvent:Connect(function(kind, pos, text, extra)
		if typeof(pos) ~= "Vector3" or active > 40 then
			return
		end
		local cam = Workspace.CurrentCamera or camera
		if not cam then
			return
		end
		local v, onScreen = cam:WorldToViewportPoint(pos)
		if not onScreen then
			return
		end
		active += 1
		local base = layer.AbsolutePosition
		local big = kind == "Kill" or kind == "Ability" or extra == "boss" or extra == "super"
		local l = Widgets.label({
			Name = "Fx_" .. tostring(kind),
			Text = tostring(text),
			Size = UDim2.fromOffset(150, if big then 30 else 22),
			Position = UDim2.fromOffset(v.X - base.X - 75, v.Y - base.Y),
			TextColor3 = if extra == "super" then Theme.Orange else (COLORS[kind] or Theme.Text),
			TextStrokeTransparency = 0.3,
			Font = Theme.Font,
			ZIndex = 36,
			Parent = layer,
		})
		Widgets.New("UITextSizeConstraint", { MaxTextSize = if big then 26 else 18, Parent = l })
		local tw = Widgets.tween(l, 0.9, {
			Position = UDim2.fromOffset(v.X - base.X - 75, v.Y - base.Y - 60),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tw.Completed:Once(function()
			active -= 1
			l:Destroy()
		end)
	end)

	-- ---------- таймеры справа снизу (v2.5): охота, события, буст удачи, босс — компактные плашки ----------
	local timer = Widgets.New("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -12),
		Size = UDim2.fromOffset(240, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = gui,
	})
	local timerScale = Widgets.New("UIScale", { Parent = timer })
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = timer,
	})
	local function chip(name: string, order: number, accent: Color3): (Frame, TextLabel)
		local f = Widgets.New("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Color3.fromRGB(24, 26, 40),
			BackgroundTransparency = 0.15,
			LayoutOrder = order,
			ZIndex = 6,
			Parent = timer,
		})
		Widgets.corner(f, 10)
		Widgets.stroke(f, accent, 2)
		local t = Widgets.bold({
			Name = "Text",
			Text = "",
			Size = UDim2.new(1, -14, 1, -6),
			Position = UDim2.fromOffset(7, 3),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = accent,
			MaxTextSize = 17,
			MinTextSize = 10,
			Stroke = 2,
			ZIndex = 7,
			Parent = f,
		})
		return f, t
	end

	-- босс / рейд: имя, таймер и полоса
	local bossBox = Widgets.New("Frame", {
		Name = "BossBar",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.fromRGB(24, 26, 40),
		BackgroundTransparency = 0.1,
		Visible = false,
		LayoutOrder = 90,
		ZIndex = 6,
		Parent = timer,
	})
	Widgets.corner(bossBox, 10)
	Widgets.stroke(bossBox, Theme.Red, 2)
	local bossName = Widgets.bold({
		Text = "",
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -70, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 190, 90),
		MaxTextSize = 16,
		MinTextSize = 10,
		Stroke = 2,
		ZIndex = 7,
		Parent = bossBox,
	})
	local bossTimer = Widgets.bold({
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 3),
		Size = UDim2.fromOffset(58, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Gold,
		MaxTextSize = 16,
		Stroke = 2,
		ZIndex = 7,
		Parent = bossBox,
	})
	local bossBar = UiKit.bar(bossBox, UDim2.fromOffset(8, 26), UDim2.new(1, -16, 0, 14), Theme.Red)
	bossBar.Back.ZIndex = 7

	-- бусты (v2.9): таймер виден на быстром слоте с зельем; здесь — только если такого предмета нет в слотах
	-- (например, буст куплен донатом LUCK_2X_15M / LUCK_5X_10M, а зелье удачи убрано из хотбара)
	local luckChip, luckText = chip("LuckChip", 80, Theme.Green)
	luckChip.Visible = false
	local coinChip, coinText = chip("CoinChip", 81, Theme.Gold)
	coinChip.Visible = false
	local function boostChips(core)
		local b = HotbarData.boosts(core.Boosts, ClientState.serverNow())
		local hb = core.Hotbar
		local luckSlot = HotbarData.slotOf(hb, "luck_potion") ~= nil
		local coinSlot = HotbarData.slotOf(hb, "coin_elixir") ~= nil
		luckChip.Visible = b.Luck ~= nil and not luckSlot
		coinChip.Visible = b.Coins ~= nil and not coinSlot
		if b.Luck then
			luckText.Text = L.t("hud.luck_boost", { n = b.Luck.Mult, time = Util.formatTime(b.Luck.Left) })
		end
		if b.Coins then
			coinText.Text = L.t("hud.coin_boost", { n = b.Coins.Mult, time = Util.formatTime(b.Coins.Left) })
		end
	end

	-- события: одна строка на событие «⏱ Имя 1:45»; описание — в баннере при старте
	local huntCard = HuntHud.init(gui, timer)
	local eventList: any = {}
	local seenActive: { [string]: boolean } = {}
	local EVENT_COLORS = { GoldenRain = Theme.Gold, LunarNight = Theme.Purple, BossRaid = Theme.Red }
	local eventChips: { [string]: any } = {}
	-- как в образце: когда ничего не идёт — одна компактная плашка «🌙 Имя через 1:45» (ближайшее событие)
	local nextChip, nextText = chip("NextEvent", 100, Color3.fromRGB(200, 205, 230))
	nextChip.Visible = false
	local function drawEvents()
		local soon, soonLeft, anyOn = nil, math.huge, false
		for _, e in ipairs(eventList) do
			local left = math.max(0, (e.Left or 0) - (os.clock() - (e.Got or 0)))
			if e.Active then
				anyOn = true
			elseif left < soonLeft then
				soon, soonLeft = e, left
			end
		end
		nextChip.Visible = soon ~= nil and not anyOn
		if soon then
			nextText.Text = L.t("event.next", { name = L.n(soon.Name), time = Util.formatTime(soonLeft) })
		end
		for i, e in ipairs(eventList) do
			local c = eventChips[e.Id]
			if e.Active then
				if not c then
					local f, t = chip("Event_" .. e.Id, 10 + i, EVENT_COLORS[e.Id] or Theme.Gold)
					c = { Frame = f, Text = t }
					eventChips[e.Id] = c
				end
				c.Text.Text = "⏱ "
					.. L.n(e.Name)
					.. "  "
					.. Util.formatTime(math.max(0, e.Left - (os.clock() - (e.Got or 0))))
			elseif c then
				c.Frame:Destroy()
				eventChips[e.Id] = nil
			end
		end
	end
	Remotes.getEvent("EventState").OnClientEvent:Connect(function(list)
		if type(list) ~= "table" then
			return
		end
		for _, e in ipairs(list) do
			e.Got = os.clock()
			-- баннер «событие началось» (в общем стеке с баннерами охоты)
			if e.Active and not seenActive[e.Id] then
				Toasts.banner(
					L.t("event.started", { name = L.n(e.Name) }),
					L.n(e.Desc),
					EVENT_COLORS[e.Id],
					4
				)
			end
			seenActive[e.Id] = e.Active == true
		end
		eventList = list
		drawEvents()
	end)
	local _ = huntCard

	-- ---------- раскладка (v2.5): справа снизу; на тач-экране не под кнопкой прыжка ----------
	Layout.onChanged(function(lay)
		local s = if lay.Mode == "wide" then 1 elseif lay.Mode == "portrait" then 0.82 else 0.78
		timerScale.Scale = s
		if lay.Mode == "portrait" then
			timer.Position = UDim2.new(1, -10, 1, -100)
			timer.Size = UDim2.fromOffset(math.min(240, (lay.W - 20) / s * 0.62), timer.Size.Y.Offset)
		elseif lay.Mode == "landscape" then
			timer.Position = UDim2.new(1, if lay.Touch then -104 else -10, 1, -8)
			timer.Size = UDim2.fromOffset(240, timer.Size.Y.Offset)
		else
			timer.Position = UDim2.new(1, if lay.Touch then -190 else -14, 1, -12)
			timer.Size = UDim2.fromOffset(250, timer.Size.Y.Offset)
		end
	end)

	-- ---------- оффлайн-награда ----------
	local offline = Widgets.New("Frame", {
		Name = "OfflinePopup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = Theme.Bg,
		Visible = false,
		ZIndex = 50,
		Parent = gui,
	})
	Layout.onChanged(function(lay)
		offline.Size = UDim2.fromOffset(math.min(420, lay.W - 24), 190)
	end)
	Widgets.corner(offline, 16)
	Widgets.stroke(offline, Theme.Gold, 3)
	UiKit.text(offline, L.k("offline.title"), UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 36), {
		Font = Theme.Font,
		TextColor3 = Theme.Gold,
		MaxSize = 30,
		ZIndex = 51,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local offText = UiKit.text(
		offline,
		"",
		UDim2.fromOffset(16, 52),
		UDim2.new(1, -32, 0, 60),
		{ MaxSize = 20, ZIndex = 51, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true }
	)
	Widgets.button({
		Name = "ClaimOffline",
		Text = L.k("offline.claim"),
		Color = Theme.Green,
		Size = UDim2.fromOffset(180, 50),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		ZIndex = 52,
		MaxTextSize = 24,
		OnClick = function()
			if Actions.call("ClaimOffline") then
				offline.Visible = false
			end
		end,
		Parent = offline,
	})
	local function showOffline(coins: number, seconds: number?)
		offText.Text = if seconds
			then L.t("offline.text_time", { time = Util.formatTime(seconds), n = Util.formatNumber(coins) })
			else L.t("offline.text", { n = Util.formatNumber(coins) })
		offline.Visible = true
	end
	Remotes.getEvent("Offline").OnClientEvent:Connect(function(d)
		if type(d) == "table" and d.Coins and d.Coins > 0 then
			showOffline(d.Coins, d.Seconds)
		end
	end)
	local offlineShown = false
	ClientState.onCore(function(core)
		if core.OfflinePending > 0 and not offlineShown and not offline.Visible then
			offlineShown = true
			showOffline(core.OfflinePending, nil)
		elseif core.OfflinePending == 0 then
			offline.Visible = false
		end
		boostChips(core)
	end)

	-- ---------- станции хаба ----------
	Remotes.getEvent("OpenUi").OnClientEvent:Connect(function(name)
		if type(name) == "string" then
			openPanelForce(name)
		end
	end)

	-- ---------- опрос боссов и таймеров ----------
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local folder = Workspace:FindFirstChild("Enemies")
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local boss = nil
		local bestDist = 140 -- не показываем полосу босса другой зоны
		if folder then
			for _, m in ipairs(folder:GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("IsBoss") then
					if m:GetAttribute("IsRaid") then
						boss = m
						break
					end
					local pos = m:GetPivot().Position
					local d = if root then (pos - root.Position).Magnitude else 1e9
					if d < bestDist then
						bestDist = d
						boss = m
					end
				end
			end
		end
		bossBox.Visible = boss ~= nil
		if boss then
			local hp, max = boss:GetAttribute("Hp") or 0, boss:GetAttribute("MaxHp") or 1
			bossName.Text = L.t(
				if boss:GetAttribute("IsRaid") then "hud.raid" else "hud.boss",
				{ name = L.n(tostring(boss:GetAttribute("EnemyName"))) }
			)
			bossBar.Set(hp / max, ("%s / %s"):format(Util.formatNumber(hp), Util.formatNumber(max)))
			local left = boss:GetAttribute("TimeLeft")
			bossTimer.Text = if left then Util.formatTime(left) else ""
		end
		if #eventList > 0 then
			drawEvents()
		end
		-- высота стека = видимые плашки (пустая рамка не перекрывает соседние кнопки)
		local hgt = 0
		for _, c in ipairs(timer:GetChildren()) do
			if c:IsA("GuiObject") and c.Visible then
				hgt += c.Size.Y.Offset + 5
			end
		end
		timer.Size = UDim2.fromOffset(timer.Size.X.Offset, math.max(1, hgt))
		local core = ClientState.Core
		if core then
			boostChips(core)
		end
	end)
end

return Fx
