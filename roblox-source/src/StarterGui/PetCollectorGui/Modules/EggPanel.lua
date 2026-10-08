--!nonstrict
-- Окно яйца: честно показывает шансы выпадения (с учётом удачи игрока) и кнопки открытия.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Config = require(Shared:WaitForChild("Config"))
local PetData = require(Shared:WaitForChild("PetData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local EggPanel = {}

-- Шансы показываем в процентах с достаточной точностью (требование Roblox к платным случайным предметам)
local function formatChance(percent: number): string
	if percent >= 10 then
		return string.format("%.2f%%", percent)
	elseif percent >= 1 then
		return string.format("%.3f%%", percent)
	end
	return string.format("%.4f%%", percent)
end

function EggPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Egg", nil, { MinH = 440 }) -- v3.1: плотная раскладка — уменьшается меньше
	local body = panel.Body
	local titleLabel = panel.Header:FindFirstChild("Title") :: TextLabel
	L.unbind(titleLabel, "Text") -- заголовок — имя яйца (ставится в render)

	-- v2.5: ряд яиц (кнопка «Яйца» на HUD открывает окно и вдали от яиц — смотреть шансы)
	local tabs = Widgets.scroller(body, {
		Name = "EggTabs",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 0, 36),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
	})
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})
	local sub = Widgets.label({
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 40),
		TextColor3 = Theme.TextDim,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 18, Parent = sub })

	local list = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 68),
		Size = UDim2.new(1, -20, 1, -164), -- снизу — сноска об удаче (2 строки) и кнопки
	})
	Widgets.New(
		"UIListLayout",
		{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list }
	)

	local note = Widgets.label({
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.new(0, 12, 1, -92),
		TextColor3 = Theme.TextDim,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8, Parent = note })

	local currentEgg: string? = nil
	local nearEgg = false -- игрок у этого яйца (иначе кнопки открытия подсказывают подойти)
	local buttons = {}
	for i, count in ipairs(Config.HATCH_COUNTS) do
		local n = #Config.HATCH_COUNTS
		local b = Widgets.button({
			Name = "Hatch" .. count,
			Text = "",
			Color = if i == 1 then Theme.Green else Theme.Blue,
			Size = UDim2.new(1 / n, -14, 0, 48),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((i - 1) / n, 8, 1, -10),
			ZIndex = 23,
			OnClick = function()
				if currentEgg then
					Actions.call("Hatch", currentEgg, count)
				end
			end,
			Parent = body,
		})
		buttons[i] = b
	end

	local ticketBtn = Widgets.button({
		Text = L.k("egg.use_ticket"),
		Color = Theme.Purple,
		Size = UDim2.fromOffset(150, 28),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 38), -- строка цены (сверху — ряд яиц)
		ZIndex = 23,
		Visible = false,
		OnClick = function()
			if currentEgg then
				Actions.call("Hatch", currentEgg, 1, true)
			end
		end,
		Parent = body,
	})
	ticketBtn.Name = "TicketButton"

	local function renderHeader()
		local core = ClientState.Core
		local egg = currentEgg and PetData.EggsById[currentEgg]
		if not core or not egg then
			return
		end
		titleLabel.Text = L.n(egg.Name)
		sub.Text = L.t(if egg.Currency == "Gems" then "egg.sub_gems" else "egg.sub_coins", {
			price = Util.formatNumber(egg.Price),
			n = egg.Price,
			have = Util.formatNumber(if egg.Currency == "Gems" then core.Gems else core.Coins),
		})
		for i, count in ipairs(Config.HATCH_COUNTS) do
			buttons[i].Text = if nearEgg
				then L.t("egg.hatch", { n = count, price = Util.formatNumber(egg.Price * count) })
				else L.t("egg.go_closer")
			Widgets.setEnabled(buttons[i], nearEgg, if i == 1 then Theme.Green else Theme.Blue)
		end
		local tickets = core.Items and core.Items["ticket_" .. egg.Id] or 0
		ticketBtn.Visible = tickets > 0
		sub.Size = UDim2.new(1, if tickets > 0 then -184 else -24, 0, 24)
		ticketBtn.Text = L.t("egg.use_ticket_n", { n = tickets })
		note.Text = L.t("egg.note", {
			luck = string.format("%.2f", core.Luck),
			gold = string.format("%.0f", Config.GOLD_CHANCE * 100),
			rainbow = string.format("%.1f", Config.RAINBOW_CHANCE * 100),
		})
	end

	-- v2.4 (аудит С14): список шансов перестраивается только при смене яйца, удачи или языка;
	-- монеты/гемы/билеты обновляют лишь шапку (renderHeader), без пересоздания строк
	local function renderList()
		local core = ClientState.Core
		local egg = currentEgg and PetData.EggsById[currentEgg]
		if not core or not egg then
			return
		end
		Widgets.clear(list)
		local odds = PetData.getOdds(egg.Id, core.Luck)
		-- Сортировка: редкие выше
		table.sort(odds, function(a, b)
			return PetData.PetsById[a.Id].Power > PetData.PetsById[b.Id].Power
		end)
		for i, o in ipairs(odds) do
			local def = PetData.PetsById[o.Id]
			local rarity = PetData.Rarities[def.Rarity]
			local row = Widgets.New("Frame", {
				Size = UDim2.new(1, -8, 0, 38),
				BackgroundColor3 = Theme.BgCard,
				LayoutOrder = i,
				ZIndex = 22,
				Parent = list,
			})
			Widgets.corner(row, 8)
			local dot = Widgets.New("Frame", {
				Position = UDim2.fromOffset(8, 7),
				Size = UDim2.fromOffset(24, 24),
				BackgroundColor3 = def.Look.Body,
				ZIndex = 23,
				Parent = row,
			})
			Widgets.corner(dot, 12)
			local nameLabel = Widgets.label({
				Text = L.n(def.Name),
				Size = UDim2.new(0.44, -44, 1, -8),
				Position = UDim2.fromOffset(40, 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = rarity.Color,
				ZIndex = 23,
				Parent = row,
			})
			-- одинаковый кегль у коротких и длинных имён (длинные переносятся)
			Widgets.New("UITextSizeConstraint", { MaxTextSize = 17, Parent = nameLabel })
			Widgets.label({
				Text = L.n(def.Rarity),
				Size = UDim2.new(0.18, 0, 1, -18),
				Position = UDim2.new(0.44, 0, 0, 9),
				TextColor3 = Theme.TextDim,
				ZIndex = 23,
				Parent = row,
			})
			Widgets.label({
				Text = "x" .. Util.formatNumber(def.Power),
				Size = UDim2.new(0.16, 0, 1, -14),
				Position = UDim2.new(0.63, 0, 0, 7),
				ZIndex = 23,
				Parent = row,
			})
			Widgets.label({
				Text = formatChance(o.Chance),
				Size = UDim2.new(0.16, 0, 1, -14),
				Position = UDim2.new(0.82, 0, 0, 7),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 23,
				Parent = row,
			})
		end
	end

	local lastKey = ""
	local function listKey(core): string
		return tostring(currentEgg) .. "|" .. string.format("%.4f", core.Luck)
	end
	local function render()
		renderHeader()
		renderList()
		local core = ClientState.Core
		lastKey = if core then listKey(core) else ""
	end

	L.onChanged(function()
		lastKey = ""
		if panel.IsOpen() then
			render()
		end
	end)
	ClientState.onCore(function(core)
		if panel.IsOpen() then
			renderHeader()
			local key = listKey(core)
			if key ~= lastKey then
				lastKey = key
				renderList()
			end
		end
	end)

	local function drawTabs()
		Widgets.clear(tabs)
		local core = ClientState.Core
		for i, egg in ipairs(PetData.Eggs) do
			local locked = core ~= nil and egg.Zone ~= "Hub" and not (core.Zones and core.Zones[egg.Zone])
			local b = Widgets.button({
				Name = "Tab_" .. egg.Id,
				Text = L.n(egg.Name),
				Color = if egg.Id == currentEgg then Theme.Orange else Theme.BgCard,
				Size = UDim2.fromOffset(118, 32),
				MaxTextSize = 15,
				ZIndex = 23,
				OnClick = function()
					if egg.Id ~= currentEgg then
						currentEgg = egg.Id
						nearEgg = false
						lastKey = ""
						drawTabs()
						render()
					end
				end,
				Parent = tabs,
			})
			if locked then
				Widgets.buttonIcon(b, "Lock", 18) -- v3.2: замок из примитивов вместо эмодзи
			end
			b.LayoutOrder = i
		end
	end

	local function show(eggId: string, near: boolean)
		currentEgg = eggId
		nearEgg = near
		lastKey = ""
		drawTabs()
		render()
		if not panel.IsOpen() then
			panel.Open()
		end
	end
	Remotes.getEvent("OpenEgg").OnClientEvent:Connect(function(eggId)
		if type(eggId) ~= "string" or not PetData.EggsById[eggId] then
			return
		end
		show(eggId, true)
	end)
	-- v2.5: кнопка «Яйца» на HUD — ближайшее яйцо (если рядом) или яйцо текущего мира для просмотра шансов
	function panel.Show(eggId: string?, near: boolean)
		local id = eggId
		if not id then
			local core = ClientState.Core
			for _, egg in ipairs(PetData.Eggs) do
				if core and egg.Zone == core.CurrentZone then
					id = egg.Id
					break
				end
			end
			id = id or currentEgg or PetData.Eggs[1].Id
		end
		show(id :: string, near and eggId ~= nil)
	end

	return panel
end

return EggPanel
