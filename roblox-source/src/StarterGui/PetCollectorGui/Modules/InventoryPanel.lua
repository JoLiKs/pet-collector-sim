--!nonstrict
--[[
	InventoryPanel (v2.6) — окно «Инвентарь» (кнопка в правой колонке HUD).
	Слева сетка: все ресурсы ResourceData и предметы RecipeData (лут, крафт); в ячейке — своя иконка (Icons.lua,
	без эмодзи), название и количество; чего нет — приглушено. Справа (на телефоне в портрете — снизу) карточка
	выбранного: описание, где добыть (миры, сундуки, враги, верстак) и для чего нужно (рецепты). Данные — InventoryData.
	v2.9: у предметов «одним нажатием» (зелье удачи, эликсир монет, билеты) в карточке кнопки «В слот 3 / 4 / 5»
	(у уже назначенного — «Убрать из слота N»), действие SetHotbar; у угощения и катализатора — пояснение,
	что они применяются в окне «Питомцы». Пустой быстрый слот открывает окно с подсказкой «Выберите предмет для слота N».
	v3.1 (баг «не назначается в пустой слот»): карточка больше не пересоздаётся при каждом изменении количеств —
	только при смене ключа HotbarData.cardKey (предмет / режим выбора / слот предмета); счётчик «У вас» обновляется
	на месте. В режиме «для слота N» тап по подходящему предмету сразу кладёт его в слот N. Подтверждённое
	назначение сразу применяется в ClientState (patchCore), слот хотбара перерисовывается без ожидания снимка.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local HotbarData = require(Shared:WaitForChild("HotbarData"))
local Icons = require(Shared:WaitForChild("Icons"))
local InventoryData = require(Shared:WaitForChild("InventoryData"))
local RecipeData = require(Shared:WaitForChild("RecipeData"))
local ResourceData = require(Shared:WaitForChild("ResourceData"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Toasts = require(script.Parent.Toasts)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local InventoryPanel = {}

local ITEM_ACCENT = Color3.fromRGB(180, 120, 255)

-- «Дерево ×4 + Камень ×2 + 500 монет»
local function costText(recipe): string
	local parts = {}
	for _, res in ipairs(ResourceData.Order) do
		local n = recipe.Cost[res]
		if n then
			table.insert(parts, L.t("reward.res", { n = n, res = L.n(ResourceData.Resources[res].Name) }))
		end
	end
	if recipe.Coins then
		table.insert(
			parts,
			L.t("reward.coins_fmt", { price = Util.formatNumber(recipe.Coins), n = recipe.Coins })
		)
	end
	return table.concat(parts, " + ")
end

function InventoryPanel.lineText(line): string
	if line.Key == "inv.src_nodes" then
		local names = {}
		for _, z in ipairs(line.Zones or {}) do
			table.insert(names, L.n(z))
		end
		return L.t(line.Key, { zones = table.concat(names, ", ") })
	elseif line.Key == "inv.src_craft" then
		return L.t(line.Key, { cost = costText(line.Recipe) })
	elseif line.Key == "inv.use_recipe" then
		local it = RecipeData.Items[line.Recipe.Item]
		return L.t(line.Key, {
			item = L.t(
				"reward.item",
				{ n = line.Recipe.Count, item = L.n(it and it.Name or line.Recipe.Item) }
			),
			cost = costText(line.Recipe),
		})
	end
	return L.t(line.Key)
end

function InventoryPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Inventory", nil, { MinH = 470 }) -- v3.1: плотная раскладка — уменьшается меньше
	local body = panel.Body

	local grid = Widgets.scroller(body, {
		Name = "Grid",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(0.58, -14, 1, -12),
	})
	Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(86, 98),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	Widgets.New("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		Parent = grid,
	})

	local info = Widgets.New("Frame", {
		Name = "Info",
		Position = UDim2.new(0.58, 0, 0, 4),
		Size = UDim2.new(0.42, -10, 1, -12),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.corner(info, 12)

	Layout.onChanged(function(lay)
		if lay.Mode == "portrait" then
			grid.Size = UDim2.new(1, -20, 0.5, -8)
			info.Position = UDim2.new(0, 10, 0.5, 2)
			info.Size = UDim2.new(1, -20, 0.5, -10)
		else
			grid.Size = UDim2.new(0.58, -14, 1, -12)
			info.Position = UDim2.new(0.58, 0, 0, 4)
			info.Size = UDim2.new(0.42, -10, 1, -12)
		end
	end)

	local selected: string? = nil
	local cells = {}
	local pendingSlot: number? = nil -- v2.9: окно открыто из пустого быстрого слота
	local refreshAll: () -> () = function() end
	local cardKey: string? = nil -- v3.1: ключ отрисованной карточки (HotbarData.cardKey)
	local busy = false -- v3.1: одно назначение за раз (двойной тап не шлёт два запроса)

	-- назначить предмет в быстрый слот ("" — убрать); подтверждение — тостом.
	-- v3.1: после «ok» новое назначение сразу применяется локально (тем же HotbarData.assign, что и на сервере).
	local function assign(slot: number, id: string)
		if busy then
			return
		end
		busy = true
		local item = RecipeData.Items[id]
		local ok = Actions.call("SetHotbar", slot, id)
		busy = false
		if ok then
			pendingSlot = nil
			local core = ClientState.Core
			local hb = HotbarData.assign(core and core.Hotbar, slot, id)
			if hb then
				ClientState.patchCore("Hotbar", hb)
			end
			if id == "" then
				Toasts.show(L.m("hotbar.cleared", { n = slot }), "info")
			else
				Toasts.show(
					L.m("hotbar.assigned", { item = L.n(item and item.Name or id), n = slot }),
					"success"
				)
			end
		end
	end

	local function showInfo(id: string?, force: boolean?)
		local core = ClientState.Core
		local key = HotbarData.cardKey(id, pendingSlot, core and core.Hotbar)
		if not force and key == cardKey then
			-- та же карточка: только счётчик «У вас», кнопки остаются теми же экземплярами
			local have = info:FindFirstChild("Have")
			if id and have and have:IsA("TextLabel") then
				have.Text = L.t("inv.have", { n = Util.formatNumber(InventoryData.count(core, id)) })
			end
			return
		end
		cardKey = key
		Widgets.clear(info, { "UICorner" })
		if not id then
			local hint = UiKit.text(
				info,
				if pendingSlot then L.t("hotbar.pick_slot", { n = pendingSlot }) else L.t("inv.hint"),
				UDim2.fromOffset(12, 12),
				UDim2.new(1, -24, 0, 60),
				{ TextColor3 = if pendingSlot then Theme.Gold else Theme.TextDim, MaxSize = 16 }
			)
			hint.Name = "Hint"
			return
		end
		local kind = InventoryData.kindOf(id)
		Icons.make(id, {
			Name = "BigIcon",
			Px = 60,
			Size = UDim2.fromOffset(60, 60),
			Position = UDim2.fromOffset(10, 8),
			ZIndex = 23,
			Parent = info,
		})
		local title = UiKit.text(
			info,
			L.n(InventoryData.name(id)),
			UDim2.fromOffset(78, 10),
			UDim2.new(1, -86, 0, 28),
			{ Font = Theme.Font, MaxSize = 22 }
		)
		title.Name = "Title"
		local have = UiKit.text(
			info,
			L.t("inv.have", { n = Util.formatNumber(InventoryData.count(core, id)) }),
			UDim2.fromOffset(78, 40),
			UDim2.new(1, -86, 0, 22),
			{ TextColor3 = Theme.Gold, Font = Theme.Font, MaxSize = 17 }
		)
		have.Name = "Have"
		-- v2.9: быстрые слоты хотбара
		local listTop = 76
		if HotbarData.canAssign(id) then
			local row = Widgets.New("Frame", {
				Name = "SlotRow",
				Position = UDim2.fromOffset(8, 74),
				Size = UDim2.new(1, -16, 0, 32),
				BackgroundTransparency = 1,
				ZIndex = 23,
				Parent = info,
			})
			local hb = core and core.Hotbar
			local inSlot = HotbarData.slotOf(hb, id)
			if inSlot then
				local rm = Widgets.button({
					Text = L.t("inv.remove_slot", { n = inSlot }),
					Color = Theme.Red,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 24,
					MaxTextSize = 15,
					OnClick = function()
						assign(inSlot, "")
					end,
					Parent = row,
				})
				rm.Name = "RemoveSlot"
			else
				local n = HotbarData.LAST - HotbarData.FIRST + 1
				for i = 0, n - 1 do
					local slot = HotbarData.FIRST + i
					local b = Widgets.button({
						Text = L.t("inv.to_slot", { n = slot }),
						Color = if pendingSlot == slot then Theme.Gold else Theme.Purple,
						Size = UDim2.new(1 / n, -4, 1, 0),
						Position = UDim2.new(i / n, 2, 0, 0),
						ZIndex = 24,
						MaxTextSize = 15,
						OnClick = function()
							assign(slot, id)
						end,
						Parent = row,
					})
					b.Name = "ToSlot" .. slot
				end
			end
			listTop = 112
		end
		local list = Widgets.scroller(info, {
			Name = "Lines",
			Position = UDim2.fromOffset(8, listTop),
			Size = UDim2.new(1, -16, 1, -(listTop + 6)),
			ZIndex = 23,
		})
		UiKit.list(list, 4)
		local order = 0
		local function line(text: string, opts)
			order += 1
			local o = opts or {}
			-- высота по длине текста (~34 символа в строке при 14 px), чтобы длинные строки не мельчили
			local chars = utf8.len(text) or #text
			local h = o.H or math.clamp(math.ceil(chars / 34) * 17 + 6, 22, 76)
			local l = UiKit.text(list, text, UDim2.new(), UDim2.new(1, -8, 0, h), {
				TextColor3 = o.Color or Theme.Text,
				Font = o.Font,
				MaxSize = o.Max or 14,
				LayoutOrder = order,
				ZIndex = 24,
			})
			l.Name = o.Name or ("Line" .. order)
			return l
		end
		local desc = if kind == "Res" then L.t("inv.desc." .. id) else L.n((RecipeData.Items[id] :: any).Desc)
		line(desc, { Color = Theme.TextDim, Name = "Desc" })
		if HotbarData.isPetItem(id) then
			line(L.t("inv.slot_pets"), { Color = Theme.Gold, Name = "SlotNote" })
		end
		line(
			L.t("inv.where"),
			{ Font = Theme.Font, Color = Theme.Gem, Max = 16, H = 22, Name = "WhereTitle" }
		)
		for _, ln in ipairs(InventoryData.sources(id)) do
			line("• " .. InventoryPanel.lineText(ln))
		end
		line(
			L.t("inv.used_for"),
			{ Font = Theme.Font, Color = Theme.Green, Max = 16, H = 22, Name = "UseTitle" }
		)
		for _, ln in ipairs(InventoryData.uses(id)) do
			line("• " .. InventoryPanel.lineText(ln))
		end
	end

	local function paintSelection()
		for id, c in pairs(cells) do
			local st = c.Cell:FindFirstChild("Sel")
			if st then
				st.Enabled = id == selected
			end
		end
	end

	local function selectId(id: string)
		selected = id
		paintSelection()
		showInfo(id)
		-- v3.1: окно открыто из пустого слота N — подходящий предмет сразу кладётся в этот слот
		local slot = pendingSlot
		if slot and HotbarData.canAssign(id) then
			local core = ClientState.Core
			if HotbarData.slotOf(core and core.Hotbar, id) ~= slot then
				assign(slot, id)
			end
		end
	end

	local function build()
		Widgets.clear(grid)
		cells = {}
		for i, e in ipairs(InventoryData.list()) do
			local accent = if e.Kind == "Res" then ResourceData.Resources[e.Id].Color else ITEM_ACCENT
			local cell = Widgets.New("TextButton", {
				Name = "Cell_" .. e.Id,
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = Theme.BgCard,
				LayoutOrder = i,
				ZIndex = 22,
				Parent = grid,
			})
			Widgets.corner(cell, 12)
			Widgets.stroke(cell, accent, 2)
			Widgets.New("UIStroke", {
				Name = "Sel",
				Color = Theme.Gold,
				Thickness = 4,
				Enabled = false,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = cell,
			})
			Icons.make(e.Id, {
				Px = 52,
				Size = UDim2.fromOffset(52, 52),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 6),
				ZIndex = 23,
				Parent = cell,
			})
			local dim = Widgets.New("Frame", {
				Name = "Dim",
				BackgroundColor3 = Theme.BgCard,
				BackgroundTransparency = 0.4,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 40,
				Visible = false,
				Parent = cell,
			})
			Widgets.corner(dim, 12)
			local count = Widgets.bold({
				Name = "Count",
				Text = "0",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 2),
				Size = UDim2.new(0.7, 0, 0, 22),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxTextSize = 20,
				Stroke = 2,
				ZIndex = 41,
				Parent = cell,
			})
			local name = UiKit.text(
				cell,
				L.n(InventoryData.name(e.Id)),
				UDim2.new(0, 4, 1, -34),
				UDim2.new(1, -8, 0, 30),
				{ TextXAlignment = Enum.TextXAlignment.Center, MaxSize = 13, ZIndex = 41 }
			)
			name.Name = "Name"
			cell.Activated:Connect(function()
				selectId(e.Id)
			end)
			cells[e.Id] = { Cell = cell, Count = count, Dim = dim }
		end
	end

	function panel.Refresh()
		local core = ClientState.Core
		for id, c in pairs(cells) do
			local n = InventoryData.count(core, id)
			c.Count.Text = Util.formatNumber(n)
			c.Count.TextColor3 = if n > 0 then Theme.Gold else Theme.TextDim
			c.Dim.Visible = n <= 0
		end
		paintSelection()
		showInfo(selected)
	end
	refreshAll = panel.Refresh

	build()
	local sig = ""
	ClientState.onCore(function(core)
		if not panel.IsOpen() then
			return
		end
		local parts: { any } = {}
		for _, e in ipairs(InventoryData.list()) do
			table.insert(parts, InventoryData.count(core, e.Id))
		end
		local hb = core.Hotbar or {}
		table.insert(parts, tostring(hb.S3) .. tostring(hb.S4) .. tostring(hb.S5))
		local s = table.concat(parts, ",")
		if s ~= sig then
			sig = s
			panel.Refresh()
		end
	end)
	L.onChanged(function()
		build()
		sig = ""
		cardKey = nil
		if panel.IsOpen() then
			panel.Refresh()
		end
	end)
	local open = panel.Open
	local close = panel.Close
	panel.Close = function()
		pendingSlot = nil
		close()
	end
	panel.Open = function()
		pendingSlot = nil
		open()
		if not selected then
			-- по умолчанию — первый ресурс, который уже есть (или дерево)
			local core = ClientState.Core
			for _, e in ipairs(InventoryData.list()) do
				if InventoryData.count(core, e.Id) > 0 then
					selected = e.Id
					break
				end
			end
			selected = selected or ResourceData.Order[1]
		end
		sig = ""
		panel.Refresh()
	end
	panel.select = selectId
	-- v2.9: открыть для выбора предмета в пустой быстрый слот n
	function panel.ForSlot(n: number)
		pendingSlot = n
		selected = nil
		if not panel.IsOpen() then
			open()
		end
		sig = ""
		refreshAll()
	end
	return panel
end

return InventoryPanel
