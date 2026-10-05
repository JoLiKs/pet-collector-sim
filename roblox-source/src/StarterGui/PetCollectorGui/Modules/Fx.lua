--!nonstrict
-- Боевой HUD и эффекты: всплывающие числа, полоса босса, баннеры событий, трекер заданий,
-- кнопка Attack (клавиша Q), окно оффлайн-награды, открытие панелей по станциям хаба.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local QuestData = require(Shared:WaitForChild("QuestData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local Fx = {}

local COLORS = {
	Hit = Color3.fromRGB(255, 255, 255),
	Swing = Color3.fromRGB(255, 240, 180),
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
		-- Локальный замах уже показан по клику; серверный Swing с пустым текстом пропускаем.
		if kind == "Swing" and (text == nil or text == "") then
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
		local big = kind == "Kill" or kind == "Ability" or extra == "boss"
		local l = Widgets.label({
			Name = "Fx_" .. tostring(kind),
			Text = if text == nil or text == "" then "•" else tostring(text),
			Size = UDim2.fromOffset(150, if big then 30 else 22),
			Position = UDim2.fromOffset(v.X - base.X - 75, v.Y - base.Y),
			TextColor3 = COLORS[kind] or Theme.Text,
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
	local status = UiKit.text(
		gui,
		"",
		UDim2.new(0.5, -150, 0, 66),
		UDim2.fromOffset(300, 18),
		{ TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.TextDim, MaxSize = 14, ZIndex = 5 }
	)
	status.Name = "Multipliers"

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
	local eventList: any = {}
	local function drawEvents()
		Widgets.clear(events)
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
					e.Name .. "  " .. Util.formatTime(math.max(0, e.Left - (os.clock() - (e.Got or 0)))),
					UDim2.fromOffset(8, 1),
					UDim2.new(1, -16, 0, 18),
					{ Font = Theme.Font, TextColor3 = Theme.Gold, MaxSize = 14, ZIndex = 7 }
				)
				UiKit.text(
					card,
					e.Desc,
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

	-- ---------- кнопка Attack ----------
	local lastAttack = 0
	local function playSwingLocal()
		local character = game:GetService("Players").LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local cam = Workspace.CurrentCamera or camera
		if not cam then
			return
		end
		local v, onScreen = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 2.2, 0))
		if not onScreen then
			return
		end
		active += 1
		local base = layer.AbsolutePosition
		local slash = Widgets.label({
			Name = "Fx_Swing",
			Text = "⚔",
			Size = UDim2.fromOffset(64, 48),
			Position = UDim2.fromOffset(v.X - base.X - 32, v.Y - base.Y - 20),
			TextColor3 = COLORS.Swing,
			TextStrokeTransparency = 0.2,
			Font = Theme.Font,
			ZIndex = 37,
			Parent = layer,
		})
		Widgets.New("UITextSizeConstraint", { MaxTextSize = 36, Parent = slash })
		local tw = Widgets.tween(slash, 0.35, {
			Position = UDim2.fromOffset(v.X - base.X + 30, v.Y - base.Y - 50),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			Rotation = 40,
		})
		tw.Completed:Once(function()
			active -= 1
			slash:Destroy()
		end)
	end
	local function attack()
		if os.clock() - lastAttack < 0.35 then
			return
		end
		lastAttack = os.clock()
		playSwingLocal() -- сразу, даже если врагов нет (без тоста)
		Actions.call("Attack")
	end
	Widgets.button({
		Name = "Attack",
		Text = "ATTACK [Q]",
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
	Widgets.corner(offline, 16)
	Widgets.stroke(offline, Theme.Gold, 3)
	UiKit.text(offline, "Welcome back!", UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 36), {
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
		Text = "Claim",
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
		offText.Text = ("Your pets kept working%s and earned %s coins."):format(
			if seconds then " for " .. Util.formatTime(seconds) else "",
			Util.formatNumber(coins)
		)
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
		local parts = { ("Coins x%.2f"):format(core.CoinMult or 1) }
		if (core.FriendBonus or 0) > 0 then
			table.insert(parts, ("Friends +%d%%"):format(math.floor(core.FriendBonus * 100 + 0.5)))
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
					("%s: %s %d/%d"):format(
						QuestData.Npcs[npcId].Name,
						step.Title,
						st.Progress,
						step.Obj.Count
					)
				)
			end
		end
		tracker.Visible = #lines > 0
		trackerText.Text = table.concat(lines, "\n")
		tracker.Size = UDim2.fromOffset(250, 12 + #lines * 18)
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
			bossName.Text = (if boss:GetAttribute("IsRaid") then "RAID: " else "Boss: ")
				.. tostring(boss:GetAttribute("EnemyName"))
			bossBar.Set(hp / max, ("%s / %s"):format(Util.formatNumber(hp), Util.formatNumber(max)))
			local left = boss:GetAttribute("TimeLeft")
			bossTimer.Text = if left then Util.formatTime(left) else ""
		end
		if #eventList > 0 then
			drawEvents()
		end
	end)
end

return Fx
