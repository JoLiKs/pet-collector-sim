--!nonstrict
-- Мелкие помощники для панелей: карточки, вкладки, полосы прогресса, иконки питомцев.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local PetMeta = require(Shared:WaitForChild("PetMeta"))
local RecipeData = require(Shared:WaitForChild("RecipeData"))
local ResourceData = require(Shared:WaitForChild("ResourceData"))
local Util = require(Shared:WaitForChild("Util"))
local L = require(Shared:WaitForChild("Locale"))

local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local UiKit = {}
local New = Widgets.New

function UiKit.list(parent: Instance, padding: number?, horizontal: boolean?)
	return New("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Parent = parent,
	})
end

function UiKit.card(parent: Instance, height: number, accent: Color3?, order: number?): Frame
	local f = New("Frame", {
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Theme.BgCard,
		LayoutOrder = order or 0,
		ZIndex = 22,
		Parent = parent,
	})
	Widgets.corner(f, 10)
	if accent then
		Widgets.stroke(f, accent, 2)
	end
	return f
end

-- Текст с позицией/размером; opts — любые свойства TextLabel
function UiKit.text(
	parent: Instance,
	text: any, -- строка или маркер L.k(...)
	pos: UDim2,
	size: UDim2,
	opts: { [string]: any }?
): TextLabel
	local p = {
		Text = text,
		Position = pos,
		Size = size,
		ZIndex = 23,
		Parent = parent,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	if opts then
		for k, v in pairs(opts) do
			if k ~= "MaxSize" and k ~= "MinSize" and k ~= "NoLimit" then
				p[k] = v
			end
		end
	end
	local l = Widgets.label(p)
	if not (opts and opts.NoLimit) then
		New("UITextSizeConstraint", {
			MaxTextSize = (opts and opts.MaxSize) or 18,
			MinTextSize = (opts and opts.MinSize) or 8,
			Parent = l,
		})
	end
	return l
end

function UiKit.bar(parent: Instance, pos: UDim2, size: UDim2, color: Color3)
	local back = New(
		"Frame",
		{ Position = pos, Size = size, BackgroundColor3 = Theme.Bg, ZIndex = 23, Parent = parent }
	)
	Widgets.corner(back, 6)
	local fill = New(
		"Frame",
		{ Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, ZIndex = 24, Parent = back }
	)
	Widgets.corner(fill, 6)
	local label = Widgets.label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 25,
		Text = "",
		Font = Theme.FontBody,
		Parent = back,
	})
	New("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 6, Parent = label })
	return {
		Back = back,
		Set = function(ratio: number, text: string?)
			fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
			label.Text = text or ""
		end,
	}
end

-- Горизонтальные вкладки. Возвращает { Select(name), Current() }
function UiKit.tabs(parent: Instance, names: { string }, onSelect: (string) -> (), y: number?, width: number?)
	local buttons = {}
	local current = names[1]
	local w = width or 110
	local function paint()
		for name, b in pairs(buttons) do
			b.BackgroundColor3 = if name == current then Theme.Blue else Theme.BgLight
		end
	end
	for i, name in ipairs(names) do
		buttons[name] = Widgets.button({
			Name = "Tab_" .. name,
			Text = L.k("tab." .. name),
			Color = Theme.BgLight,
			Size = UDim2.fromOffset(w, 30),
			Position = UDim2.fromOffset(10 + (i - 1) * (w + 6), y or 4),
			ZIndex = 23,
			MaxTextSize = 18,
			OnClick = function()
				current = name
				paint()
				onSelect(name)
			end,
			Parent = parent,
		})
	end
	paint()
	-- На узком экране вкладки делят ширину родителя поровну, а не по фиксированной ширине.
	local n = #names
	Layout.onChanged(function(li)
		local c = (20 + 6 * (n - 1)) / n
		for i, name in ipairs(names) do
			local b = buttons[name]
			-- v3.1: окна стали меньше — делим ширину и на ПК, если вкладки не влезают в окно
			local pw = Theme.panelDesign(li, Theme.uiScale(li))
			if (10 + n * (w + 6)) > math.min(pw, li.W - 40) then
				b.Size = UDim2.new(1 / n, -c, 0, 30)
				b.Position = UDim2.new((i - 1) / n, 10 + (i - 1) * (6 - c), 0, y or 4)
			else
				b.Size = UDim2.fromOffset(w, 30)
				b.Position = UDim2.fromOffset(10 + (i - 1) * (w + 6), y or 4)
			end
		end
	end)
	return {
		Select = function(name: string)
			current = name
			paint()
			onSelect(name)
		end,
		Current = function()
			return current
		end,
	}
end

function UiKit.rarityColor(petId: string): Color3
	local def = PetData.PetsById[petId]
	return def and PetData.Rarities[def.Rarity].Color or Theme.Text
end

-- Цветной кружок-иконка питомца (дёшево; полноценные 3D-превью — только в окне вылупления)
function UiKit.petIcon(parent: Instance, petId: string, variant: string?, size: number, pos: UDim2?): Frame
	local def = PetData.PetsById[petId]
	local vcol = PetMeta.Variants[variant or "Normal"] and PetMeta.Variants[variant or "Normal"].Color
	local dot = New("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = pos or UDim2.fromOffset(0, 0),
		BackgroundColor3 = if variant and variant ~= "Normal"
			then vcol
			else (def and def.Look.Body or Theme.Text),
		ZIndex = 23,
		Parent = parent,
	})
	Widgets.corner(dot, size // 2)
	if variant and variant ~= "Normal" then
		Widgets.stroke(dot, vcol, 2)
	end
	local accent = New("Frame", {
		Position = UDim2.fromOffset(size * 0.55, size * 0.55),
		Size = UDim2.fromOffset(size * 0.34, size * 0.34),
		BackgroundColor3 = def and def.Look.Accent or Theme.Text,
		ZIndex = 24,
		Parent = dot,
	})
	Widgets.corner(accent, size // 4)
	return dot
end

function UiKit.badge(parent: Instance, text: any, color: Color3, pos: UDim2, w: number?): TextLabel
	local b = Widgets.label({
		Text = text,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(w or 22, 16),
		Position = pos,
		Font = Theme.Font,
		ZIndex = 26,
		Parent = parent,
	})
	Widgets.corner(b, 5)
	New("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 6, Parent = b })
	return b
end

-- Текст награды квеста/предмета на текущем языке
function UiKit.rewardText(r): string
	local parts = {}
	if r.Coins then
		table.insert(parts, L.t("reward.coins_fmt", { price = Util.formatNumber(r.Coins), n = r.Coins }))
	end
	if r.Gems then
		table.insert(parts, L.t("reward.gems", { n = r.Gems }))
	end
	if r.Res then
		for k, v in pairs(r.Res) do
			local rd = ResourceData.Resources[k]
			table.insert(parts, L.t("reward.res", { n = v, res = rd and rd.Name or k }))
		end
	end
	if r.Item then
		local it = RecipeData.Items[r.Item]
		table.insert(parts, L.t("reward.item", { n = r.ItemCount or 1, item = it and it.Name or r.Item }))
	end
	if r.Pet then
		local pd = PetData.PetsById[r.Pet]
		table.insert(parts, L.t("reward.pet_named", { pet = pd and pd.Name or r.Pet }))
	end
	if r.BpXp then
		table.insert(parts, L.t("reward.bpxp", { n = r.BpXp }))
	end
	return table.concat(parts, ", ")
end

-- Текст цели квеста на текущем языке
function UiKit.objText(obj): string
	if obj.Kind == "gather" then
		local rd = obj.Key and ResourceData.Resources[obj.Key]
		return if rd then L.t("obj.gather_res", { res = rd.Name }) else L.t("obj.gather")
	elseif obj.Kind == "level" then
		return L.t("obj.level", { n = obj.Key })
	end
	local key = "obj." .. tostring(obj.Kind)
	return if L.strings.en[key] then L.t(key) else tostring(obj.Kind)
end

return UiKit
