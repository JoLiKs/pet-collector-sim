--!nonstrict
--[[
	Hotbar (v2.5, v2.9) — хотбар снизу по центру: 2 инструмента и 3 настраиваемых быстрых слота.
	  1 — Меч (Tool "Sword"): выбран → клик/тап по миру = удар (AttackFx + действие Attack). Q бьёт всегда
	      (и сам берёт меч в руку). Удар в воздухе и по суперигроку — то же действие Attack, что и раньше.
	  2 — Магнит (Tool "Collector"): удержание клика/тапа = сбор монет (remote Click, 10 раз/с); F — один сбор.
	  3, 4, 5 — быстрые слоты предметов (v2.9, HotbarData): что в них лежит, игрок выбирает в «Инвентаре»
	      (кнопки «В слот 3/4/5»), назначение хранится на сервере (Settings.Hotbar, действие SetHotbar).
	      Зелье удачи / эликсир монет — тап выпивает (UseItem), на слоте таймер действия буста (ММ:СС + полоса);
	      билет — у своего яйца открывает его сразу, иначе открывает окно этого яйца.
	      Нет предметов — слот тусклый (назначение сохраняется), тап подсказывает, где взять; пустой слот — «+»,
	      тап открывает инвентарь с подсказкой «Выберите предмет для слота N».
	Стандартный Backpack Roblox скрыт (свой хотбар), клавиши 1–5 выбирают слот, повторный выбор убирает инструмент.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AttackFx = require(Shared:WaitForChild("AttackFx"))
local HotbarData = require(Shared:WaitForChild("HotbarData"))
local Icons = require(Shared:WaitForChild("Icons"))
local L = require(Shared:WaitForChild("Locale"))
local RecipeData = require(Shared:WaitForChild("RecipeData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local Hotbar = {}

local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
Hotbar.SLOTS = {
	{ Tool = "Sword", IconKind = "Sword", Text = "hotbar.sword", Color = Color3.fromRGB(235, 80, 80) },
	{
		Tool = "Collector",
		IconKind = "Magnet",
		Text = "hotbar.collect",
		Color = Color3.fromRGB(255, 190, 40),
	},
	{ Item = 3 },
	{ Item = 4 },
	{ Item = 5 },
}
Hotbar.SIZE = 72
Hotbar.GAP = 8
Hotbar.WIDTH = #Hotbar.SLOTS * Hotbar.SIZE + (#Hotbar.SLOTS - 1) * Hotbar.GAP
-- цвета бустов на слоте
local BOOST_COLOR = { Luck = Color3.fromRGB(90, 220, 110), Coins = Color3.fromRGB(255, 200, 50) }
local IDLE = Color3.fromRGB(40, 44, 62)

-- Что лежит в быстром слоте n (по серверному состоянию) и сколько этого предмета
function Hotbar.itemIn(core, n: number): (string, number)
	local hb = core and core.Hotbar or HotbarData.DEFAULT
	local id = hb[HotbarData.key(n)] or ""
	if id == "" or not HotbarData.canAssign(id) then
		return "", 0
	end
	local items = core and core.Items or {}
	return id, items[id] or 0
end

-- Подпись слота: короткое имя предмета («Удача», «Монеты», «Билет»)
function Hotbar.caption(id: string): string
	if id == "" then
		return L.t("hotbar.empty")
	end
	if HotbarData.useKind(id) == "Ticket" then
		return L.t("hotbar.short.ticket")
	end
	return L.t("hotbar.short." .. id)
end

local player = Players.LocalPlayer
local lastAttack = 0
local holding = false
local preferred = "Sword"

local function character(): Model?
	return player.Character
end

local function humanoid(): Humanoid?
	local c = character()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function findTool(name: string): Tool?
	local c = character()
	local t = c and c:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return t
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return if t and t:IsA("Tool") then t else nil
end

function Hotbar.equipped(): string?
	local c = character()
	local t = c and c:FindFirstChildOfClass("Tool")
	return t and t.Name
end

function Hotbar.equip(name: string)
	local hum, tool = humanoid(), findTool(name)
	if hum and tool and tool.Parent ~= character() then
		hum:EquipTool(tool)
	end
	preferred = name
end

-- Удар: Q, клик/тап с мечом в руке. Замах рисуется сразу (предсказание), урон считает сервер.
function Hotbar.attack()
	if os.clock() - lastAttack < AttackFx.SWING_TIME then
		return
	end
	lastAttack = os.clock()
	if Hotbar.equipped() ~= "Sword" then
		Hotbar.equip("Sword")
	end
	AttackFx.swing(player, true)
	Actions.call("Attack")
end

function Hotbar.init(gui: ScreenGui, onCollect: (number?) -> (), hooks: { [string]: any }?)
	local hk = hooks or {}
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local clickRemote = Remotes.getEvent("Click")
	local SIZE, GAP = Hotbar.SIZE, Hotbar.GAP

	local bar = Widgets.New("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(Hotbar.WIDTH, SIZE),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = gui,
	})
	local scale = Widgets.New("UIScale", { Parent = bar })
	local slots = {}
	local function collectOnce()
		clickRemote:FireServer()
		local core = ClientState.Core
		onCollect(core and core.PerClick)
	end
	local function startHolding()
		if holding then
			return
		end
		holding = true
		task.spawn(function()
			while holding do
				collectOnce()
				task.wait(0.1)
			end
		end)
	end

	-- быстрый слот n: применить предмет, подсказать, где взять, или открыть инвентарь для выбора
	local function useItemSlot(n: number)
		local core = ClientState.Core
		local id, count = Hotbar.itemIn(core, n)
		if id == "" then
			if hk.OpenInventoryForSlot then
				hk.OpenInventoryForSlot(n)
			end
			return
		end
		local item = RecipeData.Items[id]
		local name = L.n(item and item.Name or id)
		local kind = HotbarData.useKind(id)
		if count <= 0 then
			Toasts.show(
				L.m(if kind == "Ticket" then "hotbar.none_ticket" else "hotbar.none_boost", { item = name }),
				"info"
			)
			return
		end
		if kind == "Ticket" then
			if hk.UseTicket then
				hk.UseTicket(id)
			end
		else
			Actions.call("UseItem", id)
		end
	end
	Hotbar.useSlot = useItemSlot

	local function selectSlot(i: number)
		local s = Hotbar.SLOTS[i]
		if s.Item then
			useItemSlot(s.Item)
			return
		end
		local hum = humanoid()
		if not hum then
			return
		end
		if Hotbar.equipped() == s.Tool then
			hum:UnequipTools()
			preferred = ""
		else
			Hotbar.equip(s.Tool)
		end
	end
	Hotbar.select = selectSlot

	for i, s in ipairs(Hotbar.SLOTS) do
		local b = Widgets.hudButton({
			Name = "Slot" .. i,
			Color = IDLE,
			IconKind = s.IconKind,
			Text = L.k(s.Text or "hotbar.empty"),
			Layout = "column",
			MaxTextSize = 15,
			MinTextSize = 8,
			TextStroke = 2,
			Size = UDim2.fromOffset(SIZE, SIZE),
			Position = UDim2.fromOffset((i - 1) * (SIZE + GAP), 0),
			StrokeSize = 3,
			OnClick = function()
				selectSlot(i)
			end,
			Parent = bar,
		})
		local key = Widgets.bold({
			Name = "Key",
			Text = tostring(i),
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromOffset(4, 2),
			MaxTextSize = 15,
			Stroke = 2,
			TextColor3 = Theme.Gold,
			ZIndex = 9,
			Parent = b,
		})
		local count = Widgets.bold({
			Name = "Count",
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(40, 18),
			Position = UDim2.new(1, -4, 0, 2),
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 15,
			Stroke = 2,
			ZIndex = 9,
			Parent = b,
		})
		local sl = {
			Button = b,
			Key = key,
			Count = count,
			Def = s,
			Stroke = b:FindFirstChildOfClass("UIStroke"),
			Caption = b:FindFirstChild("Caption"),
		}
		if s.Item then
			L.unbind(sl.Caption, "Text")
			-- «+» пустого слота
			sl.Plus = Widgets.bold({
				Name = "Plus",
				Text = "+",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.02),
				Size = UDim2.fromScale(0.62, 0.62),
				MaxTextSize = 48,
				TextColor3 = Color3.fromRGB(170, 176, 210),
				Stroke = 2,
				ZIndex = 8,
				Visible = false,
				Parent = b,
			})
			-- затемнение, когда предмета 0 (назначение остаётся)
			sl.Dim = Widgets.New("Frame", {
				Name = "Dim",
				BackgroundColor3 = Color3.fromRGB(20, 22, 34),
				BackgroundTransparency = 0.4,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 8,
				Visible = false,
				Parent = b,
			})
			Widgets.corner(sl.Dim, 12)
			-- полоса убывания буста (снизу внутри слота)
			sl.BarBack = Widgets.New("Frame", {
				Name = "BoostBar",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -3),
				Size = UDim2.new(1, -10, 0, 5),
				BackgroundColor3 = Color3.fromRGB(14, 16, 26),
				ZIndex = 9,
				Visible = false,
				Parent = b,
			})
			Widgets.corner(sl.BarBack, 3)
			sl.BarFill = Widgets.New("Frame", {
				Name = "Fill",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = BOOST_COLOR.Luck,
				ZIndex = 10,
				Parent = sl.BarBack,
			})
			Widgets.corner(sl.BarFill, 3)
			sl.ItemId = nil
			sl.Span, sl.PrevLeft = nil, nil
		end
		slots[i] = sl
	end

	-- иконка предмета в быстром слоте (пересоздаётся только при смене предмета)
	local function setItemIcon(sl, id: string)
		if sl.ItemId == id then
			return
		end
		sl.ItemId = id
		local old = sl.Button:FindFirstChild("Icon")
		if old then
			old:Destroy()
		end
		if id ~= "" then
			Icons.make(id, {
				Name = "Icon",
				Px = 44,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.06),
				Size = UDim2.fromScale(0.62, 0.62),
				ZIndex = 6,
				Parent = sl.Button,
			})
		end
		sl.Span, sl.PrevLeft = nil, nil
	end

	-- таймер буста на слоте: «x2 04:59» вместо подписи + полоса убывания (время — из серверного core.Boosts)
	local function paintBoost(sl, id: string, core)
		local kind = HotbarData.boostOf(id)
		local b = kind and HotbarData.boosts(core and core.Boosts, ClientState.serverNow())[kind]
		sl.Button:SetAttribute("BoostLeft", if b then math.floor(b.Left) else 0)
		if not b then
			sl.BarBack.Visible = false
			sl.Span, sl.PrevLeft = nil, nil
			return false
		end
		sl.Span = HotbarData.span(sl.Span, sl.PrevLeft, b.Left)
		sl.PrevLeft = b.Left
		sl.BarBack.Visible = true
		sl.BarFill.BackgroundColor3 = BOOST_COLOR[kind]
		sl.BarFill.Size = UDim2.fromScale(math.clamp(b.Left / sl.Span, 0, 1), 1)
		sl.Caption.Text = "x" .. b.Mult .. " " .. HotbarData.mmss(b.Left)
		sl.Caption.TextColor3 = BOOST_COLOR[kind]
		return true
	end

	local function paint()
		local eq = Hotbar.equipped()
		local core = ClientState.Core
		for _, sl in ipairs(slots) do
			if sl.Def.Item then
				local id, n = Hotbar.itemIn(core, sl.Def.Item)
				setItemIcon(sl, id)
				sl.Button:SetAttribute("ItemId", id)
				sl.Plus.Visible = id == ""
				sl.Dim.Visible = id ~= "" and n <= 0
				sl.Count.Text = if id ~= "" then "×" .. Util.formatNumber(n) else ""
				sl.Count.TextColor3 = if n > 0 then Theme.Text else Theme.TextDim
				sl.Caption.TextColor3 = if id ~= "" and n > 0 then Theme.Text else Theme.TextDim
				local active = id ~= "" and paintBoost(sl, id, core)
				if not active then
					sl.Caption.Text = Hotbar.caption(id)
				end
				sl.Button.BackgroundColor3 = if active
					then Color3.fromRGB(46, 70, 60)
					elseif id ~= "" and n > 0 then Color3.fromRGB(70, 50, 110)
					else IDLE
				if sl.Stroke then
					local kind = HotbarData.boostOf(id)
					sl.Stroke.Color = if active and kind then BOOST_COLOR[kind] else Color3.new(0, 0, 0)
					sl.Stroke.Thickness = if active then 3.5 else 3
				end
			else
				local on = sl.Def.Tool == eq
				sl.Button.BackgroundColor3 = if on then sl.Def.Color else IDLE
				if sl.Stroke then
					sl.Stroke.Color = if on then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
					sl.Stroke.Thickness = if on then 4 else 3
				end
				sl.Button:SetAttribute("Selected", on)
			end
		end
	end
	ClientState.onCore(paint)
	L.onChanged(paint)
	-- таймеры бустов тикают раз в 0.5 с
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			paint()
		end
	end)

	-- инструменты: подписываемся на Activated/Deactivated каждого нового экземпляра (Backpack заполняется заново при респавне)
	local bound = setmetatable({}, { __mode = "k" })
	local function bind(tool: Instance)
		if not tool:IsA("Tool") or bound[tool] then
			return
		end
		bound[tool] = true
		if tool.Name == "Sword" then
			tool.Activated:Connect(Hotbar.attack)
		elseif tool.Name == "Collector" then
			tool.Activated:Connect(startHolding)
			tool.Deactivated:Connect(function()
				holding = false
			end)
			tool.Unequipped:Connect(function()
				holding = false
			end)
		end
		tool.Equipped:Connect(paint)
		tool.Unequipped:Connect(function()
			task.defer(paint)
		end)
	end
	local function watch(container: Instance)
		for _, c in ipairs(container:GetChildren()) do
			bind(c)
		end
		container.ChildAdded:Connect(function(c)
			bind(c)
			task.defer(paint)
		end)
		container.ChildRemoved:Connect(function()
			task.defer(paint)
		end)
	end
	local function onCharacter(c: Model)
		watch(c)
		task.spawn(function()
			local bp = player:WaitForChild("Backpack", 10)
			if bp then
				watch(bp)
				-- в руку — последний выбранный инструмент (новичку на шаге «сбор» — магнит)
				local core = ClientState.Core
				local want = preferred
				if core and core.Tutorial and core.Tutorial.Step == 1 then
					want = "Collector"
				end
				if want ~= "" then
					local tool = bp:WaitForChild(want, 10)
					if tool and c.Parent and not c:FindFirstChildOfClass("Tool") then
						Hotbar.equip(want)
					end
				end
			end
			paint()
		end)
	end
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			Hotbar.attack()
		elseif input.KeyCode == Enum.KeyCode.F then
			collectOnce()
		else
			for i = 1, #Hotbar.SLOTS do
				if input.KeyCode == KEYS[i] then
					selectSlot(i)
				end
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			holding = false
		end
	end)

	-- раскладка: 5 слотов между кошельком (слева снизу) и таймерами (справа снизу), не под кнопкой прыжка;
	-- если места мало — слоты уменьшаются (Hotbar.fit), полоса сдвигается в свободный промежуток
	local lastFit = ""
	local function relayout()
		local lay = Layout.get()
		local bottom = if lay.Mode == "wide" then 12 else 8
		local base = Hotbar.scaleFor(lay)
		local function rectOf(name: string)
			local f = gui:FindFirstChild(name)
			if not (f and f:IsA("GuiObject") and f.Visible) then
				return nil
			end
			local p, z = f.AbsolutePosition - gui.AbsolutePosition, f.AbsoluteSize
			return p.X, p.Y, p.X + z.X, p.Y + z.Y
		end
		local barTop = lay.H - bottom - SIZE * base
		local left, right = 8, lay.W - 8
		if lay.Touch then
			right = lay.W - 104 -- кнопка прыжка
		end
		local cx0, _, cx1, cy1 = rectOf("Currency")
		if cx0 and cy1 > barTop + 2 and cx1 < lay.W / 2 then
			left = math.max(left, cx1 + 8)
		end
		local tx0, _, _, ty1 = rectOf("Timer")
		if tx0 and ty1 > barTop + 2 and tx0 > lay.W / 2 then
			right = math.min(right, tx0 - 8)
		end
		local s, cx = HotbarData.fit(lay.W, left, right, base, Hotbar.WIDTH)
		local sig = string.format("%d/%d/%.3f/%.1f", lay.W, lay.H, s, cx)
		if sig == lastFit then
			return
		end
		lastFit = sig
		scale.Scale = s
		bar.Position = UDim2.new(0, cx, 1, -bottom)
		for _, sl in ipairs(slots) do
			sl.Key.Visible = not lay.Touch
		end
	end
	Layout.onChanged(function()
		task.defer(relayout)
	end)
	local lacc = 0
	RunService.Heartbeat:Connect(function(dt)
		lacc += dt
		if lacc >= 0.5 then
			lacc = 0
			relayout()
		end
	end)
	paint()
	return bar
end

-- Масштаб кластеров HUD (общий для Hud/Hotbar): десктоп ~1, телефон ~0.8
function Hotbar.scaleFor(lay): number
	if lay.Mode == "portrait" then
		return math.clamp(lay.W / 470, 0.72, 0.9)
	elseif lay.Mode == "landscape" then
		return math.clamp(lay.H / 500, 0.66, 0.85)
	end
	return math.clamp(math.min(lay.W / 1280, lay.H / 720), 0.85, 1.15)
end

return Hotbar
