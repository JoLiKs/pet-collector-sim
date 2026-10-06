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
	local panel = Widgets.panel(gui, "Egg")
	local body = panel.Body
	local titleLabel = panel.Header:FindFirstChild("Title") :: TextLabel
	L.unbind(titleLabel, "Text") -- заголовок — имя яйца (ставится в render)

	local sub = Widgets.label({
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 2),
		TextColor3 = Theme.TextDim,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 18, Parent = sub })

	local list = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 30),
		Size = UDim2.new(1, -20, 1, -112),
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
		Size = UDim2.fromOffset(150, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
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

	local function render()
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
			buttons[i].Text = L.t("egg.hatch", { n = count, price = Util.formatNumber(egg.Price * count) })
		end
		local tickets = core.Items and core.Items["ticket_" .. egg.Id] or 0
		ticketBtn.Visible = tickets > 0
		ticketBtn.Text = L.t("egg.use_ticket_n", { n = tickets })
		note.Text = L.t("egg.note", {
			luck = string.format("%.2f", core.Luck),
			gold = string.format("%.0f", Config.GOLD_CHANCE * 100),
			rainbow = string.format("%.1f", Config.RAINBOW_CHANCE * 100),
		})

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
			Widgets.label({
				Text = L.n(def.Name),
				Size = UDim2.new(0.38, 0, 1, -14),
				Position = UDim2.fromOffset(40, 7),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = rarity.Color,
				ZIndex = 23,
				Parent = row,
			})
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
	L.onChanged(function()
		lastKey = ""
		if panel.IsOpen() then
			render()
		end
	end)
	ClientState.onCore(function(core)
		if panel.IsOpen() then
			-- перерисовываем только при смене валюты/удачи (иначе список мигал бы каждую секунду)
			local key = tostring(core.Coins)
				.. "|"
				.. tostring(core.Gems)
				.. "|"
				.. tostring(core.Luck)
				.. "|"
				.. tostring(core.Items and core.Items["ticket_" .. (currentEgg or "")])
			if key ~= lastKey then
				lastKey = key
				render()
			end
		end
	end)

	Remotes.getEvent("OpenEgg").OnClientEvent:Connect(function(eggId)
		if type(eggId) ~= "string" or not PetData.EggsById[eggId] then
			return
		end
		currentEgg = eggId
		lastKey = ""
		render()
		if not panel.IsOpen() then
			panel.Open()
		end
	end)

	return panel
end

return EggPanel
