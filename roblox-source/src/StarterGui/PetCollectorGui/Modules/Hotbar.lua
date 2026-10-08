--!nonstrict
--[[
	Hotbar (v2.5) — хотбар инструментов снизу по центру вместо кнопок «УДАР» и «СОБРАТЬ».
	  1 — Меч (Tool "Sword"): выбран → клик/тап по миру = удар (AttackFx + действие Attack). Q бьёт всегда
	      (и сам берёт меч в руку). Удар в воздухе и по суперигроку — то же действие Attack, что и раньше.
	  2 — Магнит (Tool "Collector"): удержание клика/тапа = сбор монет (remote Click, 10 раз/с); F — один сбор.
	  3 — Зелье: не инструмент, а быстрый слот: тап выпивает лучшее зелье из инвентаря (UseItem).
	Стандартный Backpack Roblox скрыт (свой хотбар), клавиши 1–3 выбирают слот, повторный выбор убирает инструмент.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AttackFx = require(Shared:WaitForChild("AttackFx"))
local L = require(Shared:WaitForChild("Locale"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local Widgets = require(script.Parent.Widgets)

local Hotbar = {}

Hotbar.SLOTS = {
	{
		Tool = "Sword",
		IconKind = "Sword",
		Text = "hotbar.sword",
		Color = Color3.fromRGB(235, 80, 80),
		Key = Enum.KeyCode.One,
	},
	{
		Tool = "Collector",
		IconKind = "Magnet",
		Text = "hotbar.collect",
		Color = Color3.fromRGB(255, 190, 40),
		Key = Enum.KeyCode.Two,
	},
	{
		Tool = nil,
		IconKind = "Potion",
		Text = "hotbar.potion",
		Color = Color3.fromRGB(170, 100, 255),
		Key = Enum.KeyCode.Three,
	},
}
-- порядок выбора зелья для быстрого слота
Hotbar.POTIONS = { "luck_potion", "coin_elixir", "xp_treat" }

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

function Hotbar.bestPotion(): (string?, number)
	local core = ClientState.Core
	local items = core and core.Items or {}
	local total = 0
	for _, id in ipairs(Hotbar.POTIONS) do
		total += items[id] or 0
	end
	for _, id in ipairs(Hotbar.POTIONS) do
		if (items[id] or 0) > 0 then
			return id, total
		end
	end
	return nil, 0
end

function Hotbar.init(gui: ScreenGui, onCollect: (number?) -> ())
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local clickRemote = Remotes.getEvent("Click")

	local bar = Widgets.New("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(3 * 72 + 2 * 10, 72),
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

	local function usePotion()
		local id = Hotbar.bestPotion()
		if not id then
			Toasts.show("hotbar.no_potion", "info")
			return
		end
		Actions.call("UseItem", id)
	end

	local function selectSlot(i: number)
		local s = Hotbar.SLOTS[i]
		if not s.Tool then
			usePotion()
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
			Color = Color3.fromRGB(40, 44, 62),
			IconKind = s.IconKind,
			Text = L.k(s.Text),
			Layout = "column",
			MaxTextSize = 15,
			MinTextSize = 9,
			TextStroke = 2,
			Size = UDim2.fromOffset(72, 72),
			Position = UDim2.fromOffset((i - 1) * 82, 0),
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
			ZIndex = 8,
			Parent = b,
		})
		local count = Widgets.bold({
			Name = "Count",
			Text = "",
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(34, 18),
			Position = UDim2.new(1, -4, 0, 2),
			TextXAlignment = Enum.TextXAlignment.Right,
			MaxTextSize = 15,
			Stroke = 2,
			ZIndex = 8,
			Parent = b,
		})
		slots[i] =
			{ Button = b, Key = key, Count = count, Def = s, Stroke = b:FindFirstChildOfClass("UIStroke") }
	end

	local function paint()
		local eq = Hotbar.equipped()
		local _, potions = Hotbar.bestPotion()
		for _, sl in ipairs(slots) do
			local on = sl.Def.Tool ~= nil and sl.Def.Tool == eq
			sl.Button.BackgroundColor3 = if on then sl.Def.Color else Color3.fromRGB(40, 44, 62)
			if sl.Stroke then
				sl.Stroke.Color = if on then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
				sl.Stroke.Thickness = if on then 4 else 3
			end
			sl.Button:SetAttribute("Selected", on)
			if not sl.Def.Tool then
				sl.Count.Text = if potions > 0 then "×" .. Util.formatNumber(potions) else ""
				sl.Button.BackgroundColor3 = if potions > 0
					then Color3.fromRGB(70, 50, 110)
					else Color3.fromRGB(40, 44, 62)
			end
		end
	end
	ClientState.onCore(paint)

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
			for i, s in ipairs(Hotbar.SLOTS) do
				if input.KeyCode == s.Key then
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

	Layout.onChanged(function(lay)
		for _, sl in ipairs(slots) do
			sl.Key.Visible = not lay.Touch
		end
		scale.Scale = Hotbar.scaleFor(lay)
		-- на телефоне в портрете хотбар не заходит под кнопку прыжка (справа внизу)
		local dx = 0
		if lay.Touch and lay.Mode == "portrait" then
			dx = math.min(0, (lay.W - 104) - (lay.W / 2 + 118 * scale.Scale))
		end
		bar.Position = UDim2.new(0.5, dx, 1, if lay.Mode == "wide" then -12 else -8)
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
