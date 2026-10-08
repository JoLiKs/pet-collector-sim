--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local PetData = require(Shared:WaitForChild("PetData"))
local Util = require(Shared:WaitForChild("Util"))
local ZoneData = require(Shared:WaitForChild("ZoneData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local ZonesPanel = {}

function ZonesPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Worlds")
	local scroll =
		Widgets.scroller(panel.Body, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 1, -12) })
	Widgets.New(
		"UIListLayout",
		{ Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll }
	)
	Widgets.padding(scroll, 4)

	local rows = {}
	local eggLabels = {}
	for i, zone in ipairs(ZoneData.List) do
		local row = Widgets.New("Frame", {
			Size = UDim2.new(1, -8, 0, 78),
			BackgroundColor3 = Theme.BgCard,
			LayoutOrder = i,
			ZIndex = 22,
			Parent = scroll,
		})
		Widgets.corner(row, 12)
		Widgets.stroke(row, zone.Accent, 2)
		local swatch = Widgets.New("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(58, 58),
			BackgroundColor3 = zone.Floor,
			ZIndex = 23,
			Parent = row,
		})
		Widgets.corner(swatch, 12)
		Widgets.stroke(swatch, zone.Accent, 3)
		Widgets.label({
			Text = L.kn(zone.Name),
			Size = UDim2.new(0.5, 0, 0, 26),
			Position = UDim2.fromOffset(80, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Font,
			ZIndex = 23,
			Parent = row,
		})
		local eggNames = {}
		for _, egg in ipairs(PetData.Eggs) do
			if egg.Zone == zone.Id then
				table.insert(eggNames, egg.Name)
			end
		end
		local eggsLabel = Widgets.label({
			Name = "Desc",
			Text = "",
			-- v3.2.1: список яиц — фиксированный размер с переносом (не TextScaled), одинаковый во всех мирах
			TextScaled = false,
			TextSize = 15,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(0.5, 0, 0, 38),
			Position = UDim2.fromOffset(80, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.TextDim,
			ZIndex = 23,
			Parent = row,
		})
		local btn = Widgets.button({
			Text = "",
			Size = UDim2.new(0.3, -8, 0, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			ZIndex = 23,
			OnClick = function()
				local core = ClientState.Core
				if not core then
					return
				end
				if core.Zones[zone.Id] then
					if Actions.call("Teleport", zone.Id) then
						panel.Close()
					end
				else
					Actions.call("UnlockZone", zone.Id)
				end
			end,
			Parent = row,
		})
		rows[zone.Id] = btn
		eggLabels[zone.Id] = { Label = eggsLabel, Eggs = eggNames, Mult = zone.Multiplier }
	end

	ClientState.onCore(function(core)
		for _, info in pairs(eggLabels) do
			local names = {}
			for _, n in ipairs(info.Eggs) do
				table.insert(names, L.n(n))
			end
			info.Label.Text = L.t("zones.info", { n = info.Mult, eggs = table.concat(names, ", ") })
		end
		for _, zone in ipairs(ZoneData.List) do
			local btn = rows[zone.Id]
			if core.Zones[zone.Id] then
				btn.Text = if core.CurrentZone == zone.Id
					then L.t("zones.go_spawn")
					else L.t("zones.teleport")
				Widgets.setEnabled(btn, true, Theme.Blue)
			elseif core.Rebirths < zone.RequiresRebirths then
				btn.Text = L.t("zones.needs_rebirth", { n = zone.RequiresRebirths })
				Widgets.setEnabled(btn, false)
			else
				btn.Text = L.t("zones.unlock", { price = Util.formatNumber(zone.UnlockCost) })
				Widgets.setEnabled(btn, core.Coins >= zone.UnlockCost, Theme.Green)
				btn.Active = true
			end
		end
	end)
	return panel
end

return ZonesPanel
