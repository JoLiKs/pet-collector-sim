--!nonstrict
-- Панель питомцев: инвентарь, экипировка, продажа.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local PetData = require(Shared:WaitForChild("PetData"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local PetsPanel = {}

function PetsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Pets")
	local body = panel.Body

	local info = Widgets.label({
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.fromOffset(14, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 20, Parent = info })
	Widgets.button({
		Text = "Equip Best",
		Color = Theme.Green,
		Size = UDim2.fromOffset(130, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 3),
		ZIndex = 22,
		OnClick = function()
			Actions.call("EquipBest")
		end,
		Parent = body,
	})

	local scroll = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 1, -112),
	})
	Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 132),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Widgets.padding(scroll, 4)

	-- Нижняя панель действий для выбранного питомца
	local footer = Widgets.New("Frame", {
		Position = UDim2.new(0, 10, 1, -66),
		Size = UDim2.new(1, -20, 0, 60),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.corner(footer, 12)
	local selLabel = Widgets.label({
		Size = UDim2.new(0.5, -10, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Select a pet",
		ZIndex = 23,
		Parent = footer,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 20, Parent = selLabel })
	local equipBtn = Widgets.button({
		Text = "Equip",
		Color = Theme.Green,
		Size = UDim2.new(0.22, 0, 0, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.74, 0.5),
		ZIndex = 23,
		Parent = footer,
	})
	local sellBtn = Widgets.button({
		Text = "Sell",
		Color = Theme.Red,
		Size = UDim2.new(0.24, 0, 0, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		ZIndex = 23,
		Parent = footer,
	})

	local selected: string? = nil
	local confirmSell = false

	local function equippedIndex(core, uid: string): boolean
		for _, v in ipairs(core.Equipped) do
			if v == uid then
				return true
			end
		end
		return false
	end

	local function refreshFooter()
		local core = ClientState.Core
		local uid = selected
		local pet = uid and ClientState.Pets[uid]
		if not core or not uid or not pet then
			selected = nil
			selLabel.Text = "Select a pet"
			Widgets.setEnabled(equipBtn, false)
			Widgets.setEnabled(sellBtn, false)
			sellBtn.Text = "Sell"
			return
		end
		local def = PetData.PetsById[pet.Id]
		local eq = equippedIndex(core, uid)
		selLabel.Text = ("%s%s  x%s"):format(
			if pet.Gold then "Golden " else "",
			def.Name,
			Util.formatNumber(PetData.getPower(pet.Id, pet.Gold))
		)
		selLabel.TextColor3 = PetData.Rarities[def.Rarity].Color
		equipBtn.Text = if eq then "Unequip" else "Equip"
		Widgets.setEnabled(equipBtn, true, if eq then Theme.Orange else Theme.Green)
		local value = PetData.sellValue(pet.Id, pet.Gold)
		sellBtn.Text = if confirmSell then "Sure?" else ("Sell " .. Util.formatNumber(value))
		Widgets.setEnabled(sellBtn, not eq, Theme.Red)
	end

	equipBtn.Activated:Connect(function()
		local core = ClientState.Core
		if not selected or not core then
			return
		end
		if equippedIndex(core, selected) then
			Actions.call("Unequip", selected)
		else
			Actions.call("Equip", selected)
		end
	end)
	sellBtn.Activated:Connect(function()
		if not selected then
			return
		end
		local pet = ClientState.Pets[selected]
		local def = pet and PetData.PetsById[pet.Id]
		local needsConfirm = def and (PetData.Rarities[def.Rarity].Order >= 3 or pet.Gold)
		if needsConfirm and not confirmSell then
			confirmSell = true
			refreshFooter()
			task.delay(3, function()
				confirmSell = false
				refreshFooter()
			end)
			return
		end
		confirmSell = false
		Actions.call("Sell", selected)
	end)

	local lastSig = ""
	local function signature(core): string
		return table.concat(core.Equipped, ",")
			.. "|"
			.. core.PetCount
			.. "|"
			.. core.Slots
			.. "|"
			.. core.BagSize
	end

	local function rebuild()
		local core = ClientState.Core
		if not core then
			return
		end
		lastSig = signature(core)
		info.Text = ("Pets %d/%d   Equipped %d/%d"):format(
			core.PetCount,
			core.BagSize,
			#core.Equipped,
			core.Slots
		)
		Widgets.clear(scroll)

		local list = {}
		for uid, pet in pairs(ClientState.Pets) do
			table.insert(list, { Uid = uid, Pet = pet, Power = PetData.getPower(pet.Id, pet.Gold) })
		end
		table.sort(list, function(a, b)
			if a.Power ~= b.Power then
				return a.Power > b.Power
			end
			return a.Uid < b.Uid
		end)

		for i, entry in ipairs(list) do
			local def = PetData.PetsById[entry.Pet.Id]
			local rarity = PetData.Rarities[def.Rarity]
			local eq = equippedIndex(core, entry.Uid)
			local card = Widgets.New("TextButton", {
				Name = entry.Uid,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Theme.BgCard,
				LayoutOrder = i,
				ZIndex = 22,
				Parent = scroll,
			})
			Widgets.corner(card, 12)
			Widgets.stroke(
				card,
				if entry.Uid == selected then Color3.new(1, 1, 1) else rarity.Color,
				if entry.Uid == selected then 4 else 2
			)

			local dot = Widgets.New("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(46, 46),
				BackgroundColor3 = if entry.Pet.Gold then Color3.fromRGB(255, 208, 70) else def.Look.Body,
				ZIndex = 23,
				Parent = card,
			})
			Widgets.corner(dot, 23)
			local accent = Widgets.New("Frame", {
				Position = UDim2.fromOffset(28, 28),
				Size = UDim2.fromOffset(16, 16),
				BackgroundColor3 = def.Look.Accent,
				ZIndex = 24,
				Parent = dot,
			})
			Widgets.corner(accent, 8)
			Widgets.label({
				Text = def.Name,
				Size = UDim2.new(1, -8, 0, 24),
				Position = UDim2.fromOffset(4, 58),
				TextColor3 = rarity.Color,
				ZIndex = 23,
				Parent = card,
			})
			Widgets.label({
				Text = "x" .. Util.formatNumber(entry.Power),
				Size = UDim2.new(1, -8, 0, 20),
				Position = UDim2.fromOffset(4, 84),
				ZIndex = 23,
				Parent = card,
			})
			Widgets.label({
				Text = (if entry.Pet.Gold then "GOLD " else "") .. def.Rarity,
				Size = UDim2.new(1, -8, 0, 14),
				Position = UDim2.fromOffset(4, 106),
				TextColor3 = Theme.TextDim,
				ZIndex = 23,
				Parent = card,
			})
			if eq then
				local tag = Widgets.label({
					Text = "ON",
					BackgroundTransparency = 0,
					BackgroundColor3 = Theme.Green,
					Size = UDim2.fromOffset(30, 18),
					Position = UDim2.new(1, -34, 0, 4),
					Font = Theme.Font,
					ZIndex = 25,
					Parent = card,
				})
				Widgets.corner(tag, 6)
			end
			card.Activated:Connect(function()
				selected = entry.Uid
				confirmSell = false
				rebuild()
			end)
		end
		refreshFooter()
	end

	ClientState.onPets(function()
		if panel.IsOpen() then
			rebuild()
		end
	end)
	-- Сервер присылает Core каждую секунду; перестраиваем список только если что-то реально изменилось,
	-- иначе карточки пересоздавались бы под пальцем игрока и клики терялись бы.
	ClientState.onCore(function(core)
		if panel.IsOpen() and signature(core) ~= lastSig then
			rebuild()
		end
	end)

	local open = panel.Open
	panel.Open = function()
		open()
		rebuild()
	end
	return panel
end

return PetsPanel
