--!nonstrict
--[[
	Hud (v2.5) — минимум кнопок на экране, крупно и ярко (жирный шрифт, толстая чёрная обводка):
	  * слева по центру — «Магазин» и «Индекс» + переключатель автосбора (если есть пропуск) + маленькая «Ещё»;
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
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Hud = {}
Hud.eggPanel = nil :: any -- панель яйца (UIController): кнопка «Яйца» вызывает eggPanel.Show
Hud.state = nil :: any -- флаги «есть что забрать» для листа «Ещё»
Hud.buttons = nil :: any

Hud.LEFT = {
	{ Id = "Shop", Name = "ShopBtn", Icon = "🛒", Text = "hud.shop", Color = Color3.fromRGB(70, 200, 80) },
	{
		Id = "Index",
		Name = "IndexBtn",
		Icon = "📖",
		Text = "hud.index",
		Color = Color3.fromRGB(60, 150, 255),
	},
}
Hud.RIGHT = {
	{ Id = "Eggs", Name = "EggsBtn", Icon = "🥚", Text = "hud.eggs", Color = Color3.fromRGB(240, 70, 70) },
	{ Id = "Pets", Name = "PetsBtn", Icon = "🐾", Text = "hud.pets", Color = Color3.fromRGB(255, 150, 40) },
	{
		Id = "Quests",
		Name = "QuestsBtn",
		Icon = "📜",
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
	-- ---------- слева: Магазин / Индекс / авто / Ещё ----------
	local left = Widgets.New("Frame", {
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(176, 236),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = gui,
	})
	local leftScale = Widgets.New("UIScale", { Parent = left })
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = left,
	})
	local buttons = {}
	for i, item in ipairs(Hud.LEFT) do
		buttons[item.Id] = Widgets.hudButton({
			Name = item.Name,
			Color = item.Color,
			Icon = item.Icon,
			Text = L.k(item.Text),
			Size = UDim2.fromOffset(176, 60),
			MaxTextSize = 28,
			LayoutOrder = i,
			OnClick = function()
				openPanel(item.Id)
			end,
			Parent = left,
		})
	end
	local autoBtn = Widgets.hudButton({
		Name = "AutoToggle",
		Color = Theme.Green,
		Text = L.k("hud.auto_on"),
		Size = UDim2.fromOffset(176, 34),
		MaxTextSize = 18,
		Radius = 17,
		LayoutOrder = 3,
		OnClick = function()
			local core = ClientState.Core
			if core then
				Actions.call("SetAutoCollect", not core.AutoCollect)
			end
		end,
		Parent = left,
	})
	autoBtn.Visible = false
	local moreBtn = Widgets.hudButton({
		Name = "MoreBtn",
		Color = Color3.fromRGB(150, 90, 240),
		Icon = "☰",
		Text = L.k("hud.more"),
		Size = UDim2.fromOffset(120, 40),
		MaxTextSize = 20,
		LayoutOrder = 4,
		OnClick = function()
			openPanel("More")
		end,
		Parent = left,
	})
	local moreDot = Widgets.dot(moreBtn)

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
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = right,
	})
	for i, item in ipairs(Hud.RIGHT) do
		buttons[item.Id] = Widgets.hudButton({
			Name = item.Name,
			Color = item.Color,
			Icon = item.Icon,
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
	hotbar = Hotbar.init(gui, popup)

	-- ---------- раскладка (Layout): якоря + UIScale ----------
	Layout.onChanged(function(lay)
		local s = Hotbar.scaleFor(lay)
		-- боковые кнопки компактнее хотбара (как в образце): на телефоне не закрывают персонажа
		local side = s * (if lay.Mode == "wide" then 0.92 else 0.8)
		leftScale.Scale, rightScale.Scale, walletScale.Scale = side, side, s
		if lay.Mode == "portrait" then
			left.Position = UDim2.new(0, 10, 0.45, 0)
			right.Position = UDim2.new(1, -10, 0.42, 0)
			-- над хотбаром: снизу по центру тесно (хотбар + кнопка прыжка)
			wallet.Position = UDim2.new(0, 12, 1, -math.floor(90 * s + 4))
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

	-- ---------- данные ----------
	ClientState.onCore(function(core)
		coinsLabel.Text = Util.formatNumber(core.Coins)
		gemsLabel.Text = Util.formatNumber(core.Gems)
		autoBtn.Visible = core.Passes.AUTO_COLLECT == true
		local cap = autoBtn:FindFirstChild("Caption")
		if cap then
			L.bind(cap, "Text", L.k(if core.AutoCollect then "hud.auto_on" else "hud.auto_off"))
		end
		autoBtn.BackgroundColor3 = if core.AutoCollect then Theme.Green else Theme.Disabled
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
