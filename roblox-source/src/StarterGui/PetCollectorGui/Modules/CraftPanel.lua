--!nonstrict
-- Верстак: ресурсы, рецепты, предметы (применение зелий).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local RecipeData = require(Shared:WaitForChild("RecipeData"))
local ResourceData = require(Shared:WaitForChild("ResourceData"))
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
	local resLabels = {}
	for i, id in ipairs(ResourceData.Order) do
		local r = ResourceData.Resources[id]
		local l = UiKit.text(
			resBar,
			"",
			UDim2.new((i - 1) / #ResourceData.Order, 6, 0, 3),
			UDim2.new(1 / #ResourceData.Order, -8, 1, -6),
			{ TextColor3 = r.Color, Font = Theme.Font, MaxSize = 16 }
		)
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
			l.Text = ("%s %s"):format(
				string.sub(ResourceData.Resources[id].Name, 1, 5),
				Util.formatNumber(core.Resources[id] or 0)
			)
		end
		Widgets.clear(scroll)
		if view == "Recipes" then
			for i, recipe in ipairs(RecipeData.Recipes) do
				local item = RecipeData.Items[recipe.Item]
				local ok = RecipeData.canCraft(recipe, core.Resources, core.Coins)
				local card = UiKit.card(scroll, 58, if ok then Theme.Green else nil, i)
				card.Name = recipe.Id
				UiKit.text(
					card,
					("%dx %s"):format(recipe.Count, item.Name),
					UDim2.fromOffset(10, 4),
					UDim2.new(0.55, 0, 0, 22),
					{ Font = Theme.Font, MaxSize = 18 }
				)
				local parts = {}
				for _, res in ipairs(ResourceData.Order) do
					local n = recipe.Cost[res]
					if n then
						table.insert(parts, ("%d %s"):format(n, res))
					end
				end
				if recipe.Coins then
					table.insert(parts, Util.formatNumber(recipe.Coins) .. " coins")
				end
				UiKit.text(
					card,
					table.concat(parts, "  +  "),
					UDim2.fromOffset(10, 28),
					UDim2.new(0.6, 0, 0, 22),
					{ TextColor3 = if ok then Theme.TextDim else Theme.Red, MaxSize = 14 }
				)
				UiKit.text(
					card,
					item.Desc,
					UDim2.new(0.55, 0, 0, 4),
					UDim2.new(0.25, 0, 1, -8),
					{ TextColor3 = Theme.Gem, MaxSize = 13 }
				)
				local b = Widgets.button({
					Name = "Make",
					Text = "Craft",
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
					UiKit.text(
						card,
						("%s  x%d"):format(item.Name, n),
						UDim2.fromOffset(10, 4),
						UDim2.new(0.6, 0, 0, 22),
						{ Font = Theme.Font, MaxSize = 18 }
					)
					UiKit.text(
						card,
						item.Desc,
						UDim2.fromOffset(10, 28),
						UDim2.new(0.62, 0, 0, 20),
						{ TextColor3 = Theme.TextDim, MaxSize = 13 }
					)
					if item.Kind == "BoostLuck" or item.Kind == "BoostCoins" then
						Widgets.button({
							Name = "Use",
							Text = "Use",
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
								then "Use in Pets"
								elseif item.Kind == "Catalyst" then "Use in Fusion"
								elseif item.Kind == "Ticket" then "Use at the egg"
								else "Passive bonus",
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
					"No items yet — craft something!",
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
