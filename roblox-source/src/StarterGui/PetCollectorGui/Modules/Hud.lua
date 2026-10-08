--!nonstrict
--[[
	Hud (v2.5) — минимум кнопок на экране, крупно и ярко (жирный шрифт, толстая чёрная обводка):
	  * слева по центру — «Магазин», «Индекс» и маленькая «Ещё» (v3.2: переключатель автосбора — в листе «Ещё»,
	    только у владельцев пропуска «Автосбор»);
	  * справа по центру — три квадратные иконки: Яйца, Питомцы, Задания (с точкой «!»);
	  * слева снизу — монеты и самоцветы (большие числа с обводкой, без плашек);
	  * снизу по центру — хотбар инструментов (Hotbar), справа снизу — таймеры событий (Fx «Timer»).
	Остальные разделы (улучшения, перерождение, таланты, награды, миры, крафт, рынок, обмен, рейтинги,
	настройки) — в листе «Ещё» (MorePanel) и на станциях хаба (ProximityPrompt + табличка).
	Верх экрана свободен (панель Roblox и GuiInset). Каждый кластер масштабируется UIScale (Hotbar.scaleFor).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local L = require(Shared:WaitForChild("Locale"))
local PetData = require(Shared:WaitForChild("PetData"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local Util = require(Shared:WaitForChild("Util"))
local Config = require(Shared:WaitForChild("Config"))
local Icons = require(Shared:WaitForChild("Icons"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Hotbar = require(script.Parent.Hotbar)
local HotbarData = require(Shared:WaitForChild("HotbarData"))
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local Hud = {}
Hud.eggPanel = nil :: any -- панель яйца (UIController): кнопка «Яйца» вызывает eggPanel.Show
Hud.invPanel = nil :: any -- v2.9: «Инвентарь» (UIController): пустой быстрый слот открывает его для выбора предмета
Hud.state = nil :: any -- флаги «есть что забрать» для листа «Ещё»
Hud.buttons = nil :: any

Hud.LEFT = {
	{
		Id = "Shop",
		Name = "ShopBtn",
		IconKind = "Cart",
		Text = "hud.shop",
		Color = Color3.fromRGB(70, 200, 80),
	},
	{
		Id = "Index",
		Name = "IndexBtn",
		IconKind = "Book",
		Text = "hud.index",
		Color = Color3.fromRGB(60, 150, 255),
	},
}
-- v3.1: левые кнопки компактнее в 2.5 раза. Все одной высоты LEFT_H «дизайнерских» px; ширина зависит от
-- режима (на ПК — под подпись мелким шрифтом, на телефоне — короче, высота упирается в Theme.MIN_TAP).
Hud.LEFT_H = 40
Hud.LEFT_W = { wide = 190, wideMore = 120, touch = 112, touchMore = 84 }
Hud.LEFT_SHRINK = 2.5
-- side — масштаб боковых кнопок v3.0 (кнопка «Магазин» была 60 px высотой × side).
-- Возвращает масштаб левой колонки и ширины кнопок (обычной и «Ещё») в «дизайнерских» px.
function Hud.leftLayout(lay: any, side: number): (number, number, number)
	local k = side * 60 / Hud.LEFT_SHRINK / Hud.LEFT_H
	if lay.Mode == "wide" then
		return k, Hud.LEFT_W.wide, Hud.LEFT_W.wideMore
	end
	return math.max(k, Theme.MIN_TAP / Hud.LEFT_H), Hud.LEFT_W.touch, Hud.LEFT_W.touchMore
end
Hud.RIGHT = {
	{
		Id = "Eggs",
		Name = "EggsBtn",
		IconKind = "Egg",
		Text = "hud.eggs",
		Color = Color3.fromRGB(240, 70, 70),
	},
	{
		Id = "Pets",
		Name = "PetsBtn",
		IconKind = "Paw",
		Text = "hud.pets",
		Color = Color3.fromRGB(255, 150, 40),
	},
	{
		Id = "Quests",
		Name = "QuestsBtn",
		IconKind = "Scroll",
		Text = "hud.quests",
		Color = Color3.fromRGB(80, 200, 100),
	},
	-- v2.6: инвентарь — ресурсы и предметы со своими иконками (InventoryPanel)
	{
		Id = "Inventory",
		Name = "InventoryBtn",
		IconKind = "Bag",
		Text = "hud.inventory",
		Color = Color3.fromRGB(30, 180, 190),
	},
}

-- Ближайшее яйцо в радиусе открытия (клиентская подсказка; сервер всё равно проверяет дистанцию)
function Hud.nearestEgg(): (string?, number)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local world = Workspace:FindFirstChild("World")
	if not root then
		return nil, math.huge
	end
	local best, bd = nil, math.huge
	for _, d in ipairs((world or Workspace):GetDescendants()) do
		if d:IsA("Model") and string.sub(d.Name, 1, 4) == "Egg_" then
			local id = string.sub(d.Name, 5)
			if PetData.EggsById[id] then
				local dist = (d:GetPivot().Position - root.Position).Magnitude
				if dist < bd then
					best, bd = id, dist
				end
			end
		end
	end
	return best, bd
end

local function currencyRow(
	parent: Instance,
	name: string,
	icon: string,
	color: Color3,
	order: number
): TextLabel -- icon: вид Icons.lua (Coin / Gem) — без эмодзи (🪙 не рисуется на Windows 10 и в части шрифтов)
	local row = Widgets.New("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	Icons.make(icon, {
		Name = "Icon",
		Px = 40,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(0, 1),
		ZIndex = 5,
		Parent = row,
	})
	return Widgets.bold({
		Name = "Value",
		Text = "…",
		Size = UDim2.new(1, -48, 1, 0),
		Position = UDim2.fromOffset(48, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Stroke = 3,
		MaxTextSize = 36,
		Parent = row,
	})
end

function Hud.init(gui: ScreenGui, openPanel: (string, boolean?) -> ())
	-- ---------- слева: Магазин / Индекс / Ещё ----------
	local left = Widgets.New("Frame", {
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(Hud.LEFT_W.wide, 3 * Hud.LEFT_H + 2 * 6),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = gui,
	})
	local leftScale = Widgets.New("UIScale", { Parent = left })
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = left,
	})
	local buttons = {}
	-- v3.1: все четыре кнопки одной высоты (Hud.LEFT_H): масштаб считается так, чтобы на ПК они были
	-- в 2.5 раза ниже, чем в v3.0, а на телефоне — не ниже Theme.MIN_TAP; подпись занимает почти всю высоту
	local function compact(b: TextButton)
		local cap = b:FindFirstChild("Caption") :: GuiObject?
		if cap then
			cap.Size = UDim2.new(cap.Size.X.Scale, cap.Size.X.Offset, 0.8, 0)
		end
	end
	for i, item in ipairs(Hud.LEFT) do
		buttons[item.Id] = Widgets.hudButton({
			Name = item.Name,
			Color = item.Color,
			IconKind = item.IconKind,
			Text = L.k(item.Text),
			Size = UDim2.fromOffset(Hud.LEFT_W.wide, Hud.LEFT_H),
			MaxTextSize = 30,
			LayoutOrder = i,
			OnClick = function()
				openPanel(item.Id)
			end,
			Parent = left,
		})
		compact(buttons[item.Id])
	end
	local moreBtn = Widgets.hudButton({
		Name = "MoreBtn",
		Color = Color3.fromRGB(150, 90, 240),
		IconKind = "Menu",
		Text = L.k("hud.more"),
		Size = UDim2.fromOffset(Hud.LEFT_W.wideMore, Hud.LEFT_H),
		MaxTextSize = 30,
		LayoutOrder = 3,
		OnClick = function()
			openPanel("More")
		end,
		Parent = left,
	})
	local moreDot = Widgets.dot(moreBtn)
	compact(moreBtn)

	-- ---------- справа: Яйца / Питомцы / Задания / Инвентарь ----------
	local right = Widgets.New("Frame", {
		Name = "RightButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.42, 0),
		Size = UDim2.fromOffset(76, #Hud.RIGHT * 76 + (#Hud.RIGHT - 1) * 10),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = gui,
	})
	local rightScale = Widgets.New("UIScale", { Parent = right })
	local rightList = Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = right,
	})
	-- v3.2: телефон вертикально — кнопки справа сеткой 2×2 внизу: верх экрана свободен под окна
	local rightGrid = Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(76, 76),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	for i, item in ipairs(Hud.RIGHT) do
		buttons[item.Id] = Widgets.hudButton({
			Name = item.Name,
			Color = item.Color,
			IconKind = item.IconKind,
			Text = L.k(item.Text),
			Layout = "column",
			Size = UDim2.fromOffset(76, 76),
			MaxTextSize = 16,
			MinTextSize = 9,
			TextStroke = 2,
			LayoutOrder = i,
			OnClick = function()
				if item.Id == "Eggs" then
					local egg, dist = Hud.nearestEgg()
					openPanel("Egg", true)
					local eggPanel = Hud.eggPanel
					if eggPanel and eggPanel.Show then
						eggPanel.Show(
							if egg and dist <= Config.EGG_MAX_DISTANCE then egg else nil,
							dist <= Config.EGG_MAX_DISTANCE
						)
					end
				else
					openPanel(item.Id)
				end
			end,
			Parent = right,
		})
	end
	local questDot = Widgets.dot(buttons.Quests)
	local petsDot = Widgets.dot(buttons.Pets)

	-- ---------- слева снизу: валюты ----------
	local wallet = Widgets.New("Frame", {
		Name = "Currency",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -12),
		Size = UDim2.fromOffset(170, 2 * 42 + 4),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = gui,
	})
	local walletScale = Widgets.New("UIScale", { Parent = wallet })
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = wallet,
	})
	local gemsLabel = currencyRow(wallet, "Gems", "Gem", Theme.Gem, 1)
	local coinsLabel = currencyRow(wallet, "Coins", "Coin", Theme.Gold, 2)

	-- ---------- хотбар и всплывающие «+N» над ним ----------
	local hotbar
	local function popup(n: number?)
		if not n or not hotbar then
			return
		end
		local s = Hotbar.scaleFor(Layout.get())
		local l = Widgets.bold({
			Name = "CollectPop",
			Text = "+" .. Util.formatNumber(n),
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.fromOffset(140, 30),
			Position = UDim2.new(0.5, math.random(-70, 70), 1, -(90 * s + 10)),
			TextColor3 = Theme.Gold,
			MaxTextSize = 26,
			Stroke = 2.5,
			ZIndex = 40,
			Parent = gui,
		})
		local p = l.Position
		local tw = Widgets.tween(l, 0.7, { Position = p + UDim2.fromOffset(0, -60), TextTransparency = 1 })
		tw.Completed:Once(function()
			l:Destroy()
		end)
	end
	hotbar = Hotbar.init(gui, popup, {
		-- v2.9: пустой быстрый слот — инвентарь с подсказкой «Выберите предмет для слота N»
		OpenInventoryForSlot = function(n: number)
			openPanel("Inventory", true)
			local inv = Hud.invPanel
			if inv and inv.ForSlot then
				inv.ForSlot(n)
			end
		end,
		-- билет: у своего яйца — открыть сразу (сервер всё равно проверит дистанцию), иначе — окно этого яйца
		UseTicket = function(itemId: string)
			local eggId = HotbarData.ticketEgg(itemId)
			local egg = eggId and PetData.EggsById[eggId]
			if not egg then
				return
			end
			local near, dist = Hud.nearestEgg()
			if near == eggId and dist <= Config.EGG_MAX_DISTANCE then
				Actions.call("Hatch", eggId, 1, true)
				return
			end
			openPanel("Egg", true)
			if Hud.eggPanel and Hud.eggPanel.Show then
				Hud.eggPanel.Show(eggId, false)
			end
			Toasts.show(L.m("hotbar.go_to_egg", { egg = L.n(egg.Name) }), "info")
		end,
	})

	-- ---------- раскладка (Layout): якоря + UIScale ----------
	Layout.onChanged(function(lay)
		local s = Hotbar.scaleFor(lay)
		-- боковые кнопки компактнее хотбара (как в образце): на телефоне не закрывают персонажа
		local side = s * (if lay.Mode == "wide" then 0.92 else 0.8)
		-- v3.0: на телефоне кнопки — не меньше Theme.MIN_TAP пикселей; на ПК (мышь) — честный масштаб 1/1.5
		local rightSide = if lay.Mode ~= "wide" then math.max(side, Theme.MIN_TAP / 48) else side
		-- v3.1: левые кнопки (Магазин/Индекс/Авто/Ещё) в 2.5 раза ниже, чем в v3.0
		local leftSide, w, wm = Hud.leftLayout(lay, side)
		for _, item in ipairs(Hud.LEFT) do
			buttons[item.Id].Size = UDim2.fromOffset(w, Hud.LEFT_H)
		end
		moreBtn.Size = UDim2.fromOffset(wm, Hud.LEFT_H)
		left.Size = UDim2.fromOffset(w, 3 * Hud.LEFT_H + 2 * 6)
		leftScale.Scale, rightScale.Scale, walletScale.Scale = leftSide, rightSide, s
		left.AnchorPoint, right.AnchorPoint = Vector2.new(0, 0.5), Vector2.new(1, 0.5)
		rightGrid.Parent, rightList.Parent = nil, right
		right.Size = UDim2.fromOffset(76, #Hud.RIGHT * 76 + (#Hud.RIGHT - 1) * 10)
		if lay.Mode == "portrait" then
			-- над хотбаром: снизу по центру тесно (хотбар + кнопка прыжка)
			local walletOff = math.floor(90 * s + 4)
			wallet.Position = UDim2.new(0, 12, 1, -walletOff)
			-- v3.2: обе колонки кнопок — внизу, прямо над кошельком: верх экрана целиком под окна (UiGeometry),
			-- открытое окно не закрывает кнопки
			local colBottom = walletOff + math.ceil(88 * s) + 10
			left.AnchorPoint, right.AnchorPoint = Vector2.new(0, 1), Vector2.new(1, 1)
			left.Position = UDim2.new(0, 10, 1, -colBottom)
			right.Position = UDim2.new(1, -10, 1, -colBottom)
			rightList.Parent, rightGrid.Parent = nil, right
			right.Size = UDim2.fromOffset(2 * 76 + 10, 2 * 76 + 10)
		elseif lay.Mode == "landscape" then
			left.Position = UDim2.new(0, 10, 0.45, 0)
			right.Position = UDim2.new(1, -10, 0.4, 0)
			wallet.Position = UDim2.new(0, 12, 1, -6)
		else
			left.Position = UDim2.new(0, 14, 0.45, 0)
			right.Position = UDim2.new(1, -14, 0.42, 0)
			wallet.Position = UDim2.new(0, 16, 1, -12)
		end
	end)

	-- v3.2: безопасная область окон на телефоне — по реальным прямоугольникам кнопок и нижних плашек
	-- (UiGeometry.areaFor). Пересчёт после смены раскладки и раз в секунду (плашки событий появляются и исчезают).
	-- Видимый прямоугольник элемента с UIScale. В Roblox AbsoluteSize уже учитывает UIScale; веб-эмулятор
	-- (roblox2web) отдаёт размер без масштаба и масштабирует вокруг центра — это распознаётся по размеру.
	local function rectOf(o: GuiObject?): any
		if not o or not o.Visible or o.AbsoluteSize.X < 1 then
			return nil
		end
		-- координаты — относительно ScreenGui (в эмуляторе AbsolutePosition включает полосу GuiInset)
		local ap, as = o.AbsolutePosition - gui.AbsolutePosition, o.AbsoluteSize
		local sc = o:FindFirstChildOfClass("UIScale")
		local k = if sc then sc.Scale else 1
		local parent = o.Parent :: any
		local pw = if parent and parent:IsA("GuiBase2d") then parent.AbsoluteSize.X else 0
		local unscaledW = o.Size.X.Scale * pw + o.Size.X.Offset
		if math.abs(k - 1) > 0.01 and math.abs(as.X - unscaledW) < 1 then
			local cx, cy = ap.X + as.X / 2, ap.Y + as.Y / 2
			return { X = cx - as.X * k / 2, Y = cy - as.Y * k / 2, W = as.X * k, H = as.Y * k }
		end
		return { X = ap.X, Y = ap.Y, W = as.X, H = as.Y }
	end
	local function updateArea()
		local lay = Layout.get()
		if lay.Mode == "wide" then
			Layout.setPanelArea(nil)
			gui:SetAttribute("PanelArea", "")
			return
		end
		local bottoms = {}
		for _, name in ipairs({ "Hotbar", "Currency" }) do
			local r = rectOf(gui:FindFirstChild(name) :: GuiObject?)
			if r then
				table.insert(bottoms, r)
			end
		end
		local timer = gui:FindFirstChild("Timer")
		if timer then
			for _, c in ipairs(timer:GetChildren()) do
				local r = if c:IsA("GuiObject") then rectOf(c) else nil
				if r then
					table.insert(bottoms, r)
				end
			end
		end
		local gs = gui.AbsoluteSize
		local area = Theme.Geometry.areaFor(lay.Mode, gs.X, gs.Y, rectOf(left), rectOf(right), bottoms, 0)
		Layout.setPanelArea(area)
		-- для тестов и отладки: область окон в координатах ScreenGui
		gui:SetAttribute(
			"PanelArea",
			if area then string.format("%d,%d,%d,%d", area.X, area.Y, area.W, area.H) else ""
		)
	end
	Hud.updateArea = updateArea
	Layout.onChanged(function()
		task.delay(0.1, updateArea)
	end)
	task.spawn(function()
		while gui.Parent do
			updateArea()
			task.wait(1)
		end
	end)

	-- ---------- данные ----------
	ClientState.onCore(function(core)
		coinsLabel.Text = Util.formatNumber(core.Coins)
		gemsLabel.Text = Util.formatNumber(core.Gems)
		local readyQuest = false
		for id, e in pairs(core.Quests.Daily) do
			local def = QuestData.DailyById[id]
			if def and e.P >= def.Obj.Count and not e.C then
				readyQuest = true
			end
		end
		questDot.Visible = readyQuest
		petsDot.Visible = (core.PetMail or 0) > 0
		local bpReady = false
		for lv = 1, core.BattlePass.Level do
			if not core.BattlePass.Free[tostring(lv)] then
				bpReady = true
				break
			end
		end
		moreDot.Visible = core.Daily.CanClaim or core.TalentPoints > 0 or bpReady
		Hud.state = { Daily = core.Daily.CanClaim, Talents = core.TalentPoints > 0, Market = bpReady }
	end)

	Hud.buttons = buttons
	return buttons
end

return Hud
