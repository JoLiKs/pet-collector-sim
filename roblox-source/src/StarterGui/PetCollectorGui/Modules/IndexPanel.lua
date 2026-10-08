--!nonstrict
--[[
	IndexPanel (v2.5) — «Индекс» питомцев: все питомцы по яйцам, открытые (когда-либо полученные) цветные
	с именем и редкостью, закрытые — тёмный силуэт «???». Открытые считает сервер (data.Index, core.Index).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local PetData = require(Shared:WaitForChild("PetData"))

local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local IndexPanel = {}

-- Все питомцы яиц (без повторов, в порядке яиц) — чистая функция, покрыта тестом
function IndexPanel.entries(): { { Egg: string, Pets: { string } } }
	local out, seen = {}, {}
	for _, egg in ipairs(PetData.Eggs) do
		local list = {}
		for _, e in ipairs(egg.Pets) do
			if not seen[e.Id] and PetData.PetsById[e.Id] then
				seen[e.Id] = true
				table.insert(list, e.Id)
			end
		end
		if #list > 0 then
			table.insert(out, { Egg = egg.Id, Pets = list })
		end
	end
	return out
end

function IndexPanel.count(index: { [string]: boolean }?): (number, number)
	local open, total = 0, 0
	for _, sec in ipairs(IndexPanel.entries()) do
		for _, id in ipairs(sec.Pets) do
			total += 1
			if index and index[id] then
				open += 1
			end
		end
	end
	return open, total
end

function IndexPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Index")
	local body = panel.Body
	local head = UiKit.text(body, "", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 0, 26), {
		Name = "Progress",
		Font = Theme.Font,
		TextColor3 = Theme.Gold,
		MaxSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local bar = UiKit.bar(body, UDim2.fromOffset(40, 28), UDim2.new(1, -80, 0, 10), Theme.Gold)
	local scroll = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 44),
		Size = UDim2.new(1, -20, 1, -50),
	})
	UiKit.list(scroll, 8)
	local cell = 96

	local lastKey = ""
	local function render(force: boolean?)
		local core = ClientState.Core
		local index = core and core.Index or {}
		local open, total = IndexPanel.count(index)
		head.Text = L.t("index.progress", { n = open, max = total })
		bar.Set(open / math.max(1, total))
		local keyParts = { tostring(cell), L.lang() }
		for id in pairs(index) do
			table.insert(keyParts, id)
		end
		table.sort(keyParts)
		local key = table.concat(keyParts, ",")
		if key == lastKey and not force then
			return
		end
		lastKey = key
		Widgets.clear(scroll)
		for si, sec in ipairs(IndexPanel.entries()) do
			local egg = PetData.EggsById[sec.Egg]
			local frame = Widgets.New("Frame", {
				Name = "Sec_" .. sec.Egg,
				Size = UDim2.new(1, -8, 0, 26),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = si,
				ZIndex = 22,
				Parent = scroll,
			})
			UiKit.text(frame, L.n(egg.Name), UDim2.fromOffset(4, 0), UDim2.new(1, -8, 0, 24), {
				Font = Theme.Font,
				MaxSize = 18,
			})
			local grid = Widgets.New("Frame", {
				Name = "Grid",
				Position = UDim2.fromOffset(0, 28),
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				ZIndex = 22,
				Parent = frame,
			})
			Widgets.New("UIGridLayout", {
				CellSize = UDim2.fromOffset(cell, cell + 14),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = grid,
			})
			for pi, petId in ipairs(sec.Pets) do
				local def = PetData.PetsById[petId]
				local known = index[petId] == true
				local rarity = PetData.Rarities[def.Rarity]
				local c = Widgets.New("Frame", {
					Name = "Pet_" .. petId,
					BackgroundColor3 = if known then Theme.BgCard else Color3.fromRGB(22, 25, 38),
					LayoutOrder = pi,
					ZIndex = 22,
					Parent = grid,
				})
				c:SetAttribute("Known", known)
				Widgets.corner(c, 12)
				Widgets.stroke(c, if known then rarity.Color else Theme.BgLight, 3)
				if known then
					UiKit.petIcon(c, petId, nil, 46, UDim2.new(0.5, -23, 0, 8))
				else
					local q = Widgets.bold({
						Text = "?",
						Size = UDim2.fromOffset(46, 46),
						Position = UDim2.new(0.5, -23, 0, 8),
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.fromRGB(20, 22, 32),
						TextColor3 = Theme.TextDim,
						MaxTextSize = 30,
						ZIndex = 23,
						Parent = c,
					})
					Widgets.corner(q, 23)
				end
				UiKit.text(
					c,
					if known then L.n(def.Name) else "???",
					UDim2.fromOffset(4, 58),
					UDim2.new(1, -8, 0, 22),
					{
						Font = Theme.Font,
						MaxSize = 15,
						MinSize = 9,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextColor3 = if known then Theme.Text else Theme.TextDim,
					}
				)
				UiKit.text(c, L.n(def.Rarity), UDim2.fromOffset(4, 82), UDim2.new(1, -8, 0, 20), {
					MaxSize = 13,
					MinSize = 9,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = if known then rarity.Color else Theme.TextDim,
				})
			end
		end
	end
	Layout.onChanged(function(lay)
		cell = if lay.Mode == "wide" then 96 else 84
		if panel.IsOpen() then
			render(true)
		end
	end)
	ClientState.onCore(function()
		if panel.IsOpen() then
			render()
		end
	end)
	L.onChanged(function()
		if panel.IsOpen() then
			render(true)
		end
	end)

	return {
		Root = panel.Root,
		Open = function()
			panel.Open()
			render(true)
		end,
		Close = panel.Close,
		IsOpen = panel.IsOpen,
	}
end

return IndexPanel
