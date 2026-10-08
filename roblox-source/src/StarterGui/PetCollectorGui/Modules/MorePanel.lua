--!nonstrict
--[[
	MorePanel (v2.5) — лист «Ещё»: все разделы, которых больше нет на экране кнопками.
	Каждый раздел есть и физической станцией в хабе (подойти → ProximityPrompt → то же окно).
	Сверху — множители (монеты, друзья, удача), которые раньше висели строкой под плашкой мира.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Util = require(Shared:WaitForChild("Util"))

local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local MorePanel = {}

-- Id панели, иконка, цвет; Where — где эта станция в хабе (подсказка под кнопкой)
MorePanel.ITEMS = {
	{ Id = "Upgrades", Icon = "⬆️", Color = Color3.fromRGB(60, 150, 255) },
	{ Id = "Rebirth", Icon = "♻️", Color = Color3.fromRGB(170, 90, 255) },
	{ Id = "Talents", Icon = "✨", Color = Color3.fromRGB(140, 80, 230) },
	{ Id = "Daily", Icon = "🎁", Color = Color3.fromRGB(255, 180, 40) },
	{ Id = "Zones", Icon = "🌍", Color = Color3.fromRGB(60, 190, 120) },
	{ Id = "Craft", Icon = "⚒️", Color = Color3.fromRGB(200, 130, 70) },
	{ Id = "Market", Icon = "🏪", Color = Color3.fromRGB(240, 90, 110) },
	{ Id = "Trade", Icon = "🤝", Color = Color3.fromRGB(255, 140, 50) },
	{ Id = "Boards", Icon = "🏆", Color = Color3.fromRGB(230, 190, 60) },
	{ Id = "Settings", Icon = "⚙️", Color = Color3.fromRGB(110, 120, 150) },
}

function MorePanel.init(
	gui: ScreenGui,
	openPanel: (string, boolean?) -> (),
	dots: () -> { [string]: boolean }
)
	local panel = Widgets.panel(gui, "More")
	local body = panel.Body

	local info = UiKit.text(body, "", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 0, 22), {
		Name = "Multipliers",
		TextColor3 = Theme.Gold,
		Font = Theme.Font,
		MaxSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local scroll = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 1, -58),
	})
	local grid = Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 64),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Widgets.New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = scroll })
	UiKit.text(body, L.k("more.hint"), UDim2.new(0, 12, 1, -28), UDim2.new(1, -24, 0, 24), {
		TextColor3 = Theme.TextDim,
		MaxSize = 14,
		MinSize = 10,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local dotOf = {}
	for i, item in ipairs(MorePanel.ITEMS) do
		local b = Widgets.hudButton({
			Name = item.Id,
			Color = item.Color,
			Icon = item.Icon,
			Text = L.k("menu." .. item.Id),
			Size = UDim2.fromOffset(150, 64),
			MaxTextSize = 20,
			MinTextSize = 10,
			LayoutOrder = i,
			ZIndex = 23,
			OnClick = function()
				openPanel(item.Id, true)
			end,
			Parent = scroll,
		})
		dotOf[item.Id] = Widgets.dot(b)
	end

	Layout.onChanged(function(lay)
		if lay.Mode == "portrait" then
			grid.CellSize = UDim2.new(0.5, -10, 0, 58)
		elseif lay.Mode == "landscape" then
			grid.CellSize = UDim2.new(0.25, -10, 0, 56)
		else
			grid.CellSize = UDim2.fromOffset(150, 64)
		end
	end)

	local function render()
		local core = ClientState.Core
		if not core then
			return
		end
		local parts = {
			L.t("hud.coin_mult", { x = ("%.2f"):format(core.CoinMult or 1) }),
			L.t("hud.luck", { x = ("%.2f"):format(core.Luck or 1) }),
		}
		if (core.FriendBonus or 0) > 0 then
			table.insert(parts, L.t("hud.friends_bonus", { n = math.floor(core.FriendBonus * 100 + 0.5) }))
		end
		table.insert(parts, L.t("hud.rebirth", { n = Util.formatNumber(core.Rebirths) }))
		info.Text = table.concat(parts, "  ·  ")
		local d = dots()
		for id, dot in pairs(dotOf) do
			dot.Visible = d[id] == true
		end
	end
	ClientState.onCore(function()
		if panel.IsOpen() then
			render()
		end
	end)
	L.onChanged(render)

	return {
		Root = panel.Root,
		Open = function()
			render()
			panel.Open()
		end,
		Close = panel.Close,
		IsOpen = panel.IsOpen,
	}
end

return MorePanel
