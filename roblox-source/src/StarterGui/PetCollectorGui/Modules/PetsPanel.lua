--!nonstrict
--[[
	Панель питомцев: инвентарь с фильтрами (стихия / роль / редкость), сортировкой и избранным,
	команда (слоты), уровни/опыт, эволюция, продажа и слияние 3→1.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Abilities = require(Shared:WaitForChild("Abilities"))
local PetData = require(Shared:WaitForChild("PetData"))
local PetMeta = require(Shared:WaitForChild("PetMeta"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local PetsPanel = {}

local ELEMENTS = { "All", "Fire", "Water", "Earth", "Air" }
local ROLES = { "All", "Fighter", "Collector", "Support" }
local RARITIES = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local SORTS = { "Power", "Level", "Rarity", "Name", "Newest" }

-- Подпись фильтра: «Стихия: огонь» и т.п.
local function filterText(key: string, value: string): string
	local v = if key == "Sort"
		then L.t("sort." .. value)
		elseif value == "All" then L.t("pets.all")
		else L.n(value)
	return L.t("pets.filter." .. key, { v = v })
end

local function nextOf(list: { string }, current: string): string
	for i, v in ipairs(list) do
		if v == current then
			return list[i % #list + 1]
		end
	end
	return list[1]
end

function PetsPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Pets")
	local body = panel.Body

	local filters = { Element = "All", Role = "All", Rarity = "All", Sort = "Power", FavOnly = false }
	local mode = "Pets" -- "Pets" | "Fusion"
	local selected: string? = nil
	local fuseSet: { [string]: boolean } = {}
	local useCatalyst = false
	local confirmSell = false

	-- Верхняя строка: сводка, режим, лучшая команда
	local info = UiKit.text(body, "", UDim2.fromOffset(14, 4), UDim2.new(1, -330, 0, 24), { MaxSize = 18 })
	local modeBtn = Widgets.button({
		Name = "ModeToggle",
		Text = L.k("pets.fusion_mode"),
		Color = Theme.Purple,
		Size = UDim2.fromOffset(120, 26),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -150, 0, 4),
		ZIndex = 23,
		MaxTextSize = 16,
		Parent = body,
	})
	Widgets.button({
		Name = "EquipBest",
		Text = L.k("hatch.equip_best"),
		Color = Theme.Green,
		Size = UDim2.fromOffset(130, 26),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 4),
		ZIndex = 23,
		MaxTextSize = 16,
		OnClick = function()
			Actions.call("EquipBest")
		end,
		Parent = body,
	})

	-- Фильтры
	local filterBtns = {}
	local function filterButton(key: string, _list: { string }, index: number)
		local b = Widgets.button({
			Name = "Filter" .. key,
			Text = filterText(key, filters[key]),
			Color = Theme.BgLight,
			Size = UDim2.new(0.2, -6, 0, 26),
			Position = UDim2.new((index - 1) * 0.2, 10 + (index - 1) * 0, 0, 34),
			ZIndex = 23,
			MaxTextSize = 15,
			Parent = body,
		})
		filterBtns[key] = b
		return b
	end
	local rebuild
	for i, def in ipairs({
		{ "Element", ELEMENTS },
		{ "Role", ROLES },
		{ "Rarity", RARITIES },
		{ "Sort", SORTS },
	}) do
		local key, list = def[1], def[2]
		local b = filterButton(key, list, i)
		b.Activated:Connect(function()
			filters[key] = nextOf(list, filters[key])
			b.Text = filterText(key, filters[key])
			rebuild()
		end)
	end
	local favBtn = Widgets.button({
		Name = "FilterFav",
		Text = L.k("pets.favorites"),
		Color = Theme.BgLight,
		Size = UDim2.new(0.2, -6, 0, 26),
		Position = UDim2.new(0.8, 10, 0, 34),
		ZIndex = 23,
		MaxTextSize = 15,
		Parent = body,
	})
	favBtn.Activated:Connect(function()
		filters.FavOnly = not filters.FavOnly
		favBtn.BackgroundColor3 = if filters.FavOnly then Theme.Gold else Theme.BgLight
		rebuild()
	end)

	local scroll = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 66),
		Size = UDim2.new(1, -20, 1, -66 - 134),
	})
	Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 112),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Widgets.padding(scroll, 4)

	-- Нижняя панель: сведения и действия
	local footer = Widgets.New("Frame", {
		Name = "Footer",
		Position = UDim2.new(0, 10, 1, -128),
		Size = UDim2.new(1, -20, 0, 124),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.corner(footer, 12)
	local detailName = UiKit.text(
		footer,
		L.t("pets.select"),
		UDim2.fromOffset(12, 6),
		UDim2.new(0.5, 0, 0, 24),
		{ Font = Theme.Font, MaxSize = 22 }
	)
	local detailLine = UiKit.text(
		footer,
		"",
		UDim2.fromOffset(12, 32),
		UDim2.new(0.55, 0, 0, 18),
		{ TextColor3 = Theme.TextDim, MaxSize = 15 }
	)
	local detailAbility = UiKit.text(
		footer,
		"",
		UDim2.fromOffset(12, 52),
		UDim2.new(0.55, 0, 0, 32),
		{ TextColor3 = Theme.Gem, MaxSize = 14 }
	)
	local xpBar = UiKit.bar(footer, UDim2.fromOffset(12, 90), UDim2.new(0.5, 0, 0, 20), Theme.Green)

	local buttons = {}
	local function actionButton(
		name: string,
		text: string,
		color: Color3,
		col: number,
		row: number,
		fn: () -> ()
	)
		local b = Widgets.button({
			Name = name,
			Text = L.k(text),
			Color = color,
			Size = UDim2.new(0.14, -4, 0, 34),
			Position = UDim2.new(0.55 + (col - 1) * 0.15, 4, 0, 8 + (row - 1) * 40),
			ZIndex = 23,
			MaxTextSize = 15,
			OnClick = fn,
			Parent = footer,
		})
		buttons[name] = b
		return b
	end
	actionButton("Equip", "pets.equip", Theme.Green, 1, 1, function()
		if selected then
			local core = ClientState.Core
			local isOn = false
			for _, u in ipairs(core.Equipped) do
				if u == selected then
					isOn = true
				end
			end
			Actions.call(if isOn then "Unequip" else "Equip", selected)
		end
	end)
	actionButton("Fav", "pets.fav", Theme.Gold, 2, 1, function()
		local pet = selected and ClientState.Pets[selected]
		if pet then
			Actions.call("SetFav", selected, not pet.Fav)
		end
	end)
	actionButton("Sell", "pets.sell", Theme.Red, 3, 1, function()
		local pet = selected and ClientState.Pets[selected]
		if not pet then
			return
		end
		local def = PetData.PetsById[pet.Id]
		if
			(def and PetData.Rarities[def.Rarity].Order >= 3 or pet.Variant ~= "Normal") and not confirmSell
		then
			confirmSell = true
			buttons.Sell.Text = L.t("pets.sure")
			task.delay(3, function()
				confirmSell = false
				buttons.Sell.Text = L.t("pets.sell")
			end)
			return
		end
		confirmSell = false
		Actions.call("Sell", selected)
	end)
	actionButton("Feed", "pets.treat", Theme.Orange, 1, 2, function()
		if selected then
			Actions.call("FeedPet", selected)
		end
	end)
	actionButton("Evolve", "pets.evolve", Theme.Purple, 2, 2, function()
		if selected then
			Actions.call("Evolve", selected)
		end
	end)
	actionButton("FuseGo", "pets.fuse3", Theme.Blue, 3, 2, function()
		local uids = {}
		for uid in pairs(fuseSet) do
			table.insert(uids, uid)
		end
		if #uids == PetMeta.FUSE_COUNT then
			if Actions.call("Fuse", uids, useCatalyst) then
				fuseSet = {}
				rebuild()
			end
		end
	end)
	local cataBtn = actionButton("Catalyst", "pets.catalyst_off", Theme.BgCard, 1, 3, function()
		useCatalyst = not useCatalyst
	end)
	cataBtn.Size = UDim2.new(0.29, -4, 0, 34)
	cataBtn.Position = UDim2.new(0.55, 4, 0, 88)
	local autoBtn = actionButton("AutoPick", "pets.autopick", Theme.Blue, 3, 3, function()
		local pet = selected and ClientState.Pets[selected]
		for uid in pairs(fuseSet) do
			pet = ClientState.Pets[uid] or pet -- ориентируемся на уже отмеченного питомца
			break
		end
		if not pet then
			return
		end
		fuseSet = {}
		local n = 0
		for uid, p in pairs(ClientState.Pets) do
			if p.Id == pet.Id and p.Variant == pet.Variant and not p.Fav and n < PetMeta.FUSE_COUNT then
				fuseSet[uid] = true
				n += 1
			end
		end
		rebuild()
	end)
	autoBtn.Position = UDim2.new(0.55 + 0.30, 4, 0, 88)

	local function equippedIndex(core, uid: string): number?
		for i, v in ipairs(core.Equipped) do
			if v == uid then
				return i
			end
		end
		return nil
	end

	local function refreshFooter()
		local core = ClientState.Core
		local pet = selected and ClientState.Pets[selected]
		local fusing = mode == "Fusion"
		buttons.FuseGo.Visible = fusing
		buttons.Catalyst.Visible = fusing
		buttons.AutoPick.Visible = fusing
		buttons.Equip.Visible = not fusing
		buttons.Fav.Visible = not fusing
		buttons.Sell.Visible = not fusing
		buttons.Feed.Visible = not fusing
		buttons.Evolve.Visible = not fusing
		if not core then
			return
		end
		if fusing then
			local n = 0
			for _ in pairs(fuseSet) do
				n += 1
			end
			detailName.Text = L.t("pets.fusion_selected", { n = n })
			detailLine.Text = L.t("pets.fusion_hint")
			local chance = 0
			for uid in pairs(fuseSet) do
				local p = ClientState.Pets[uid]
				chance = (PetMeta.FUSE_CHANCE[p.Variant] or 0)
					+ (if useCatalyst then PetMeta.CATALYST_BONUS else 0)
				break
			end
			detailAbility.Text = L.t("pets.fusion_chance", {
				n = math.floor(chance * 100 + 0.5),
				shiny = math.floor(PetMeta.FUSE_SHINY_BONUS * 100 + 0.5),
			})
			xpBar.Set(n / 3, ("%d/3"):format(n))
			Widgets.setEnabled(buttons.FuseGo, n == 3, Theme.Blue)
			local have = core.Items and core.Items.catalyst or 0
			buttons.Catalyst.Text =
				L.t(if useCatalyst then "pets.catalyst_on_n" else "pets.catalyst_off_n", { n = have })
			buttons.Catalyst.BackgroundColor3 = if useCatalyst then Theme.Purple else Theme.BgCard
			return
		end
		if not pet then
			detailName.Text = L.t("pets.select")
			detailLine.Text = L.t("pets.click_card")
			detailAbility.Text = ""
			xpBar.Set(0, "")
			return
		end
		local state = { Id = pet.Id, Variant = pet.Variant, Level = pet.Level, Evo = pet.Evo }
		local info2 = PetMeta.info(pet.Id)
		local ab = Abilities.ById[info2.Ability]
		detailName.Text = PetMeta.displayName(state)
		detailName.TextColor3 = UiKit.rarityColor(pet.Id)
		detailLine.Text = L.t("pets.detail", {
			element = info2.Element,
			role = info2.Role,
			x = Util.formatNumber(pet.Power),
			n = pet.Level,
			max = pet.Max,
		})
		detailAbility.Text = if ab
			then L.t(
				if ab.Kind == "Active" then "pets.ability_active" else "pets.ability_passive",
				{ name = ab.Name, desc = ab.Desc }
			)
			else ""
		if pet.Level >= pet.Max then
			xpBar.Set(1, if pet.Evo >= PetMeta.MAX_EVO then L.t("pets.max_evo") else L.t("pets.ready_evo"))
		else
			xpBar.Set(pet.Xp / pet.Need, L.t("pets.xp", { n = math.floor(pet.Xp), need = pet.Need }))
		end
		buttons.Equip.Text = if selected and equippedIndex(core, selected)
			then L.t("pets.unequip")
			else L.t("pets.equip")
		buttons.Fav.Text = if pet.Fav then L.t("pets.unfav") else L.t("pets.fav")
		local cost = PetMeta.evoCost(pet.Evo)
		buttons.Evolve.Text = if cost then L.t("pets.evolve") else L.t("talent.maxed")
		Widgets.setEnabled(buttons.Evolve, cost ~= nil and pet.Level >= pet.Max, Theme.Purple)
		Widgets.setEnabled(buttons.Feed, pet.Level < pet.Max, Theme.Orange)
	end

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

	local function passes(pet): boolean
		local i = PetMeta.info(pet.Id)
		local def = PetData.PetsById[pet.Id]
		if filters.Element ~= "All" and i.Element ~= filters.Element then
			return false
		end
		if filters.Role ~= "All" and i.Role ~= filters.Role then
			return false
		end
		if filters.Rarity ~= "All" and def.Rarity ~= filters.Rarity then
			return false
		end
		if filters.FavOnly and not pet.Fav then
			return false
		end
		return true
	end

	local function numericUid(uid: string): number
		return tonumber(string.sub(uid, 2)) or 0
	end

	rebuild = function()
		local core = ClientState.Core
		if not core then
			return
		end
		lastSig = signature(core)
		info.Text = L.t(
			"pets.info",
			{ n = core.PetCount, bag = core.BagSize, team = #core.Equipped, slots = core.Slots }
		)
		modeBtn.Text = if mode == "Fusion" then L.t("pets.back") else L.t("pets.fusion_mode")
		Widgets.clear(scroll)

		local list = {}
		for uid, pet in pairs(ClientState.Pets) do
			if passes(pet) then
				table.insert(list, { Uid = uid, Pet = pet })
			end
		end
		local sortKey = filters.Sort
		table.sort(list, function(a, b)
			local pa, pb = a.Pet, b.Pet
			if sortKey == "Level" and pa.Level ~= pb.Level then
				return pa.Level > pb.Level
			elseif sortKey == "Rarity" then
				local ra = PetData.Rarities[PetData.PetsById[pa.Id].Rarity].Order
				local rb = PetData.Rarities[PetData.PetsById[pb.Id].Rarity].Order
				if ra ~= rb then
					return ra > rb
				end
			elseif sortKey == "Name" then
				local na, nb = PetData.PetsById[pa.Id].Name, PetData.PetsById[pb.Id].Name
				if na ~= nb then
					return na < nb
				end
			elseif sortKey == "Newest" then
				return numericUid(a.Uid) > numericUid(b.Uid)
			end
			if pa.Fav ~= pb.Fav and sortKey ~= "Name" then
				return pa.Fav == true
			end
			if pa.Power ~= pb.Power then
				return pa.Power > pb.Power
			end
			return a.Uid < b.Uid
		end)

		for i, entry in ipairs(list) do
			local pet = entry.Pet
			local def = PetData.PetsById[pet.Id]
			local rarity = PetData.Rarities[def.Rarity]
			local meta = PetMeta.info(pet.Id)
			local picked = (mode == "Fusion" and fuseSet[entry.Uid])
				or (mode == "Pets" and entry.Uid == selected)
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
				if picked then Color3.new(1, 1, 1) else rarity.Color,
				if picked then 4 else 2
			)
			UiKit.petIcon(card, pet.Id, pet.Variant, 44, UDim2.new(0.5, -22, 0, 8))
			UiKit.text(
				card,
				L.n(def.Name),
				UDim2.fromOffset(3, 54),
				UDim2.new(1, -6, 0, 18),
				{ TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Center, MaxSize = 14 }
			)
			UiKit.text(
				card,
				L.t("pets.card_lv", { n = pet.Level, x = Util.formatNumber(pet.Power) }),
				UDim2.fromOffset(3, 73),
				UDim2.new(1, -6, 0, 16),
				{ TextXAlignment = Enum.TextXAlignment.Center, MaxSize = 13 }
			)
			UiKit.text(
				card,
				(if pet.Variant ~= "Normal" then L.n(pet.Variant) .. " " else "")
					.. (if pet.Evo > 0 then string.rep("*", pet.Evo) else ""),
				UDim2.fromOffset(3, 91),
				UDim2.new(1, -6, 0, 14),
				{
					TextColor3 = (PetMeta.Variants[pet.Variant] or PetMeta.Variants.Normal).Color,
					TextXAlignment = Enum.TextXAlignment.Center,
					MaxSize = 12,
				}
			)
			UiKit.badge(
				card,
				L.t("elem_icon." .. meta.Element),
				PetMeta.Elements[meta.Element].Color,
				UDim2.fromOffset(4, 4)
			)
			UiKit.badge(
				card,
				L.t("role_icon." .. meta.Role),
				PetMeta.Roles[meta.Role].Color,
				UDim2.fromOffset(4, 22)
			)
			if equippedIndex(core, entry.Uid) then
				UiKit.badge(card, L.t("pets.on_badge"), Theme.Green, UDim2.new(1, -30, 0, 4), 26)
			end
			if pet.Fav then
				UiKit.badge(card, "*", Theme.Gold, UDim2.new(1, -30, 0, 22), 26)
			end
			card.Activated:Connect(function()
				if mode == "Fusion" then
					if fuseSet[entry.Uid] then
						fuseSet[entry.Uid] = nil
					else
						local n = 0
						for _ in pairs(fuseSet) do
							n += 1
						end
						if n < PetMeta.FUSE_COUNT then
							fuseSet[entry.Uid] = true
						end
					end
				else
					selected = entry.Uid
					confirmSell = false
				end
				rebuild()
			end)
		end
		refreshFooter()
	end

	modeBtn.Activated:Connect(function()
		mode = if mode == "Pets" then "Fusion" else "Pets"
		fuseSet = {}
		rebuild()
	end)
	buttons.Catalyst.Activated:Connect(function()
		refreshFooter()
	end)

	ClientState.onPets(function()
		if selected and not ClientState.Pets[selected] then
			selected = nil
		end
		for uid in pairs(fuseSet) do
			if not ClientState.Pets[uid] then
				fuseSet[uid] = nil
			end
		end
		if panel.IsOpen() then
			rebuild()
		end
	end)
	-- Core приходит каждую секунду; список перестраиваем только при реальных изменениях (иначе клики теряются)
	ClientState.onCore(function(core)
		if panel.IsOpen() and signature(core) ~= lastSig then
			rebuild()
		end
	end)

	L.onChanged(function()
		for key, b in pairs(filterBtns) do
			b.Text = filterText(key, filters[key])
		end
		if panel.IsOpen() then
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
