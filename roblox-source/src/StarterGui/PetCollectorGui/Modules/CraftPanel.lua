--!nonstrict
-- Верстак: ресурсы, рецепты, предметы (применение зелий).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local RecipeData = require(Shared:WaitForChild("RecipeData"))
local ResourceData = require(Shared:WaitForChild("ResourceData"))
local Icons = require(Shared:WaitForChild("Icons"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local CraftPanel = {}

function CraftPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Craft")
	local body = panel.Body

	-- полоса ресурсов
	local resBar = Widgets.New("Frame", {
		Name = "Resources",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 34),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.corner(resBar, 10)
	-- v2.6: у каждого ресурса своя иконка (Icons.lua) + число
	local resLabels = {}
	for i, id in ipairs(ResourceData.Order) do
		local r = ResourceData.Resources[id]
		Icons.make(id, {
			Name = "Icon_" .. id,
			Px = 26,
			Size = UDim2.fromOffset(26, 26),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new((i - 1) / #ResourceData.Order, 4, 0.5, 0),
			ZIndex = 23,
			Parent = resBar,
		})
		local l = UiKit.text(
			resBar,
			"",
			UDim2.new((i - 1) / #ResourceData.Order, 32, 0, 3),
			UDim2.new(1 / #ResourceData.Order, -34, 1, -6),
			{ TextColor3 = r.Color, Font = Theme.Font, MaxSize = 16 }
		)
		l.Name = "Res_" .. id
		resLabels[id] = l
	end

	local tabs
	local view = "Recipes"
	local scroll =
		Widgets.scroller(body, { Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 1, -84) })
	UiKit.list(scroll, 6)
	tabs = UiKit.tabs(body, { "Recipes", "Items" }, function(name)
		view = name
		panel.Refresh()
	end, 42)

	function panel.Refresh()
		local core = ClientState.Core
		if not core then
			return
		end
		for id, l in pairs(resLabels) do
			l.Text = Util.formatNumber(core.Resources[id] or 0)
		end
		Widgets.clear(scroll)
		if view == "Recipes" then
			for i, recipe in ipairs(RecipeData.Recipes) do
				local item = RecipeData.Items[recipe.Item]
				local ok = RecipeData.canCraft(recipe, core.Resources, core.Coins)
				local card = UiKit.card(scroll, 58, if ok then Theme.Green else nil, i)
				card.Name = recipe.Id
				Icons.make(recipe.Item, {
					Px = 44,
					Size = UDim2.fromOffset(44, 44),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					ZIndex = 23,
					Parent = card,
				})
				UiKit.text(
					card,
					L.t("reward.item", { n = recipe.Count, item = item.Name }),
					UDim2.fromOffset(60, 4),
					UDim2.new(0.55, -50, 0, 22),
					{ Font = Theme.Font, MaxSize = 18 }
				)
				local parts = {}
				for _, res in ipairs(ResourceData.Order) do
					local n = recipe.Cost[res]
					if n then
						table.insert(
							parts,
							L.t("reward.res", { n = n, res = ResourceData.Resources[res].Name })
						)
					end
				end
				if recipe.Coins then
					table.insert(
						parts,
						L.t("reward.coins_fmt", { price = Util.formatNumber(recipe.Coins), n = recipe.Coins })
					)
				end
				UiKit.text(
					card,
					table.concat(parts, "  +  "),
					UDim2.fromOffset(60, 28),
					UDim2.new(0.6, -50, 0, 22),
					{ TextColor3 = if ok then Theme.TextDim else Theme.Red, MaxSize = 14 }
				)
				UiKit.text(
					card,
					L.n(item.Desc),
					UDim2.new(0.55, 0, 0, 4),
					UDim2.new(0.25, 0, 1, -8),
					{ TextColor3 = Theme.Gem, MaxSize = 13 }
				)
				local b = Widgets.button({
					Name = "Make",
					Text = L.t("craft.make"),
					Color = Theme.Green,
					Size = UDim2.new(0.16, 0, 0, 38),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					ZIndex = 23,
					MaxTextSize = 18,
					OnClick = function()
						Actions.call("Craft", recipe.Id, 1)
					end,
					Parent = card,
				})
				Widgets.setEnabled(b, ok, Theme.Green)
			end
		else
			local any = false
			for i, id in ipairs(RecipeData.ItemOrder) do
				local n = core.Items[id] or 0
				if n > 0 then
					any = true
					local item = RecipeData.Items[id]
					local card = UiKit.card(scroll, 52, Theme.BgLight, i)
					card.Name = id
					Icons.make(id, {
						Px = 40,
						Size = UDim2.fromOffset(40, 40),
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 8, 0.5, 0),
						ZIndex = 23,
						Parent = card,
					})
					UiKit.text(
						card,
						("%s  x%d"):format(L.n(item.Name), n),
						UDim2.fromOffset(56, 4),
						UDim2.new(0.6, -46, 0, 22),
						{ Font = Theme.Font, MaxSize = 18 }
					)
					UiKit.text(
						card,
						L.n(item.Desc),
						UDim2.fromOffset(56, 28),
						UDim2.new(0.62, -46, 0, 20),
						{ TextColor3 = Theme.TextDim, MaxSize = 13 }
					)
					if item.Kind == "BoostLuck" or item.Kind == "BoostCoins" then
						Widgets.button({
							Name = "Use",
							Text = L.t("craft.use"),
							Color = Theme.Blue,
							Size = UDim2.new(0.16, 0, 0, 34),
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							ZIndex = 23,
							MaxTextSize = 18,
							OnClick = function()
								Actions.call("UseItem", id)
							end,
							Parent = card,
						})
					else
						UiKit.text(
							card,
							if item.Kind == "PetXp"
								then L.t("craft.use_pets")
								elseif item.Kind == "Catalyst" then L.t("craft.use_fusion")
								elseif item.Kind == "Ticket" then L.t("craft.use_egg")
								else L.t("craft.passive"),
							UDim2.new(0.72, 0, 0, 10),
							UDim2.new(0.26, 0, 0, 30),
							{ TextColor3 = Theme.Gold, MaxSize = 13 }
						)
					end
				end
			end
			if not any then
				UiKit.text(
					scroll,
					L.t("craft.no_items"),
					UDim2.fromOffset(10, 10),
					UDim2.new(1, -20, 0, 30),
					{ TextColor3 = Theme.TextDim }
				)
			end
		end
	end

	local sig = ""
	ClientState.onCore(function(core)
		if not panel.IsOpen() then
			return
		end
		local parts = { view, core.Coins // 100 }
		for _, id in ipairs(ResourceData.Order) do
			table.insert(parts, core.Resources[id] or 0)
		end
		for _, id in ipairs(RecipeData.ItemOrder) do
			table.insert(parts, core.Items[id] or 0)
		end
		local s = table.concat(parts, ",")
		if s ~= sig then
			sig = s
			panel.Refresh()
		end
	end)
	L.onChanged(function()
		sig = ""
		if panel.IsOpen() then
			panel.Refresh()
		end
	end)
	local open = panel.Open
	panel.Open = function()
		open()
		sig = ""
		panel.Refresh()
	end
	local _ = tabs
	return panel
end

return CraftPanel
