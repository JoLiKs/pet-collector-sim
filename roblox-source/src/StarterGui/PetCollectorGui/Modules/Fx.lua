--!nonstrict
-- Боевой HUD и эффекты: всплывающие числа, полоса босса, баннеры событий, трекер заданий,
-- кнопка Attack (клавиша Q), окно оффлайн-награды, открытие панелей по станциям хаба.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local AttackFx = require(Shared:WaitForChild("AttackFx"))
local QuestData = require(Shared:WaitForChild("QuestData"))
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

	-- ---------- статус множителей ----------
	local status = UiKit.text(gui, "", UDim2.new(0.5, -150, 0, 67), UDim2.fromOffset(300, 19), {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.TextDim,
		MaxSize = 14,
		ZIndex = 5,
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.15,
	})
	status.Name = "Multipliers"
	Widgets.corner(status, 8)

	-- ---------- полоса босса ----------
	local bossBox = Widgets.New("Frame", {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 6,
		Parent = gui,
	})
	Widgets.corner(bossBox, 12)
	Widgets.stroke(bossBox, Theme.Red, 2)
	local bossName = UiKit.text(
		bossBox,
		"",
		UDim2.fromOffset(10, 2),
		UDim2.new(1, -90, 0, 20),
		{ Font = Theme.Font, MaxSize = 17, ZIndex = 7 }
	)
	local bossTimer = UiKit.text(
		bossBox,
		"",
		UDim2.new(1, -90, 0, 2),
		UDim2.fromOffset(80, 20),
		{ TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Gold, MaxSize = 15, ZIndex = 7 }
	)
	local bossBar = UiKit.bar(bossBox, UDim2.fromOffset(10, 24), UDim2.new(1, -20, 0, 14), Theme.Red)

	-- ---------- события ----------
	local events = Widgets.New("Frame", {
		Name = "Events",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(250, 150),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = gui,
	})
	UiKit.list(events, 4)
	local huntCard = HuntHud.init(gui, events)
	local eventList: any = {}
	local seenActive: { [string]: boolean } = {}
	local EVENT_COLORS = { GoldenRain = Theme.Gold, LunarNight = Theme.Purple, BossRaid = Theme.Red }
	local function drawEvents()
		Widgets.clear(events, { "HuntCard" })
		local n = 0
		for _, e in ipairs(eventList) do
			if e.Active then
				n += 1
				local card = Widgets.New("Frame", {
					Name = "Event_" .. e.Id,
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundColor3 = Theme.Bg,
					BackgroundTransparency = 0.1,
					LayoutOrder = n,
					ZIndex = 6,
					Parent = events,
				})
				Widgets.corner(card, 10)
				Widgets.stroke(card, Theme.Gold, 2)
				UiKit.text(
					card,
					L.n(e.Name) .. "  " .. Util.formatTime(math.max(0, e.Left - (os.clock() - (e.Got or 0)))),
					UDim2.fromOffset(8, 1),
					UDim2.new(1, -16, 0, 18),
					{ Font = Theme.Font, TextColor3 = Theme.Gold, MaxSize = 14, ZIndex = 7 }
				)
				UiKit.text(
					card,
					L.n(e.Desc),
					UDim2.fromOffset(8, 19),
					UDim2.new(1, -16, 0, 18),
					{ TextColor3 = Theme.TextDim, MaxSize = 11, ZIndex = 7 }
				)
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

	-- ---------- трекер заданий ----------
	local tracker = Widgets.New("Frame", {
		Name = "Tracker",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 170),
		Size = UDim2.fromOffset(250, 60),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	Widgets.corner(tracker, 10)
	local trackerText = UiKit.text(
		tracker,
		"",
		UDim2.fromOffset(8, 4),
		UDim2.new(1, -16, 1, -8),
		{ MaxSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6 }
	)

	-- трекер — сразу под карточками событий/охоты (колонка справа не перекрывается)
	-- колонка справа: ширина и верх зависят от раскладки (Layout, v2.4)
	local colW, colTop, colRight = 250, 12, -12
	local function relayout()
		local y = colTop
		for _, c in ipairs(events:GetChildren()) do
			if c:IsA("GuiObject") and c.Visible then
				y += c.Size.Y.Offset + 4
			end
		end
		events.Position = UDim2.new(1, colRight, 0, colTop)
		events.Size = UDim2.fromOffset(colW, math.max(1, y - colTop))
		tracker.Position = UDim2.new(1, colRight, 0, y + 4)
		tracker.Size = UDim2.fromOffset(colW, tracker.Size.Y.Offset)
	end
	local _ = huntCard

	-- ---------- кнопка Attack ----------
	local lastAttack = 0
	local function attack()
		if os.clock() - lastAttack < AttackFx.SWING_TIME then
			return
		end
		lastAttack = os.clock()
		-- Замах рисуем сразу (предсказание на клиенте), даже если врагов рядом нет — удар «в воздух», без тоста.
		AttackFx.swing(Players.LocalPlayer, true)
		Actions.call("Attack")
	end
	local attackBtn = Widgets.button({
		Name = "Attack",
		Text = L.k("hud.attack"),
		Color = Theme.Red,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, -380, 1, -24),
		Size = UDim2.fromOffset(120, 56),
		MaxTextSize = 20,
		OnClick = attack,
		Parent = gui,
	})
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			attack()
		end
	end)

	-- ---------- раскладка под экран (v2.4, аудит В6) ----------
	-- десктоп: как раньше; телефон: кнопка удара у правого края над прыжком, колонка справа под плашкой мира
	Layout.onChanged(function(lay)
		L.bind(attackBtn, "Text", L.k(if lay.Touch then "hud.attack_touch" else "hud.attack"))
		if lay.Mode == "wide" then
			attackBtn.AnchorPoint = Vector2.new(0, 1)
			attackBtn.Position = UDim2.new(0.5, -380, 1, -24)
			attackBtn.Size = UDim2.fromOffset(120, 56)
			status.AnchorPoint = Vector2.new(0, 0)
			status.Position = UDim2.new(0.5, -150, 0, 67)
			status.Size = UDim2.fromOffset(300, 19)
			bossBox.Position = UDim2.new(0.5, 0, 0, 90)
			bossBox.Size = UDim2.fromOffset(420, 44)
			colW, colTop, colRight = 250, 12, -12
		else
			local rightW = Layout.rightWidth(lay)
			attackBtn.AnchorPoint = Vector2.new(1, 1)
			attackBtn.Size = UDim2.fromOffset(104, 52)
			if lay.Mode == "portrait" then
				attackBtn.Position = UDim2.new(1, -12, 1, -124)
				bossBox.Position = UDim2.new(0.5, 0, 0, 376)
				bossBox.Size = UDim2.fromOffset(math.min(420, lay.W - 24), 44)
			else
				attackBtn.Position = UDim2.new(1, -130, 1, -16)
				bossBox.Position = UDim2.new(0.5, 0, 0, 114)
				bossBox.Size = UDim2.fromOffset(320, 44)
			end
			status.AnchorPoint = Vector2.new(1, 0)
			status.Position = UDim2.new(1, -8, 0, if lay.Mode == "portrait" then 62 else 58)
			status.Size = UDim2.fromOffset(rightW, 18)
			colW, colTop, colRight = rightW, Layout.eventsTop(lay), -8
		end
		relayout()
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
		local parts = { L.t("hud.coin_mult", { x = ("%.2f"):format(core.CoinMult or 1) }) }
		if (core.FriendBonus or 0) > 0 then
			table.insert(parts, L.t("hud.friends_bonus", { n = math.floor(core.FriendBonus * 100 + 0.5) }))
		end
		status.Text = table.concat(parts, "   |   ")
		-- трекер: принятые задания цепочек
		local lines = {}
		for _, npcId in ipairs(QuestData.NpcOrder) do
			local st = core.Quests.Chains[npcId]
			local step = st and st.Accepted and QuestData.Chains[npcId].Steps[st.Step]
			if step then
				table.insert(
					lines,
					L.t("hud.tracker_line", {
						npc = L.n(QuestData.Npcs[npcId].Name),
						title = L.n(step.Title),
						n = st.Progress,
						max = step.Obj.Count,
					})
				)
			end
		end
		tracker.Visible = #lines > 0
		trackerText.Text = table.concat(lines, "\n")
		tracker.Size = UDim2.fromOffset(colW, 12 + #lines * 18)
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
		local character = game:GetService("Players").LocalPlayer.Character
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
		relayout()
	end)
end

return Fx
