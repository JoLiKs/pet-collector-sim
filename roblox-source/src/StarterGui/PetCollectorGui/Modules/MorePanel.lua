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

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local MorePanel = {}

-- Id панели, иконка, цвет; Where — где эта станция в хабе (подсказка под кнопкой)
MorePanel.ITEMS = {
	{ Id = "Upgrades", IconKind = "Up", Color = Color3.fromRGB(60, 150, 255) },
	{ Id = "Rebirth", IconKind = "Rebirth", Color = Color3.fromRGB(170, 90, 255) },
	{ Id = "Talents", IconKind = "Sparkle", Color = Color3.fromRGB(140, 80, 230) },
	{ Id = "Daily", IconKind = "Gift", Color = Color3.fromRGB(255, 180, 40) },
	{ Id = "Zones", IconKind = "Globe", Color = Color3.fromRGB(60, 190, 120) },
	{ Id = "Craft", IconKind = "Hammer", Color = Color3.fromRGB(200, 130, 70) },
	{ Id = "Market", IconKind = "Store", Color = Color3.fromRGB(240, 90, 110) },
	{ Id = "Trade", IconKind = "Trade", Color = Color3.fromRGB(255, 140, 50) },
	{ Id = "Boards", IconKind = "Trophy", Color = Color3.fromRGB(230, 190, 60) },
	{ Id = "Settings", IconKind = "Gear", Color = Color3.fromRGB(110, 120, 150) },
}

function MorePanel.init(
	gui: ScreenGui,
	openPanel: (string, boolean?) -> (),
	dots: () -> { [string]: boolean }
)
	local panel = Widgets.panel(gui, "More")
	local body = panel.Body

	-- v3.2: строки выше — при тексте >= 12 px множители и подсказка переносятся, а не обрезаются
	local info = UiKit.text(body, "", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 0, 44), {
		Name = "Multipliers",
		TextColor3 = Theme.Gold,
		Font = Theme.Font,
		MaxSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- v3.2: переключатель автосбора — здесь, а не на экране: он нужен редко (настройка сохраняется), а левая
	-- колонка HUD остаётся из трёх кнопок. Виден только владельцам пропуска «Автосбор» (сервер тоже проверяет).
	local autoBtn = Widgets.button({
		Name = "AutoToggle",
		Text = L.k("hud.auto_on"),
		Color = Theme.Green,
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 32),
		MaxTextSize = 18,
		Visible = false,
		ZIndex = 23,
		Parent = body,
		OnClick = function()
			local core = ClientState.Core
			if core and core.Passes.AUTO_COLLECT == true then
				Actions.call("SetAutoCollect", not core.AutoCollect)
			end
		end,
	})
	local scroll = Widgets.scroller(body, {
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(1, -20, 1, -94),
	})
	local function renderAuto(core: any)
		local owner = core ~= nil and core.Passes.AUTO_COLLECT == true
		autoBtn.Visible = owner
		if owner then
			L.bind(autoBtn, "Text", L.k(if core.AutoCollect then "hud.auto_on" else "hud.auto_off"))
			autoBtn.BackgroundColor3 = if core.AutoCollect then Theme.Green else Theme.Disabled
		end
		local top = if owner then 84 else 48
		scroll.Position = UDim2.fromOffset(10, top)
		scroll.Size = UDim2.new(1, -20, 1, -(top + 46))
	end
	local grid = Widgets.New("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 64),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	Widgets.New("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = scroll })
	UiKit.text(body, L.k("more.hint"), UDim2.new(0, 12, 1, -44), UDim2.new(1, -24, 0, 40), {
		TextColor3 = Theme.TextDim,
		MaxSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local dotOf = {}
	for i, item in ipairs(MorePanel.ITEMS) do
		local b = Widgets.hudButton({
			Name = item.Id,
			Color = item.Color,
			IconKind = item.IconKind,
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
		-- v3.2: телефон в альбомной ориентации — три колонки; вертикально и на ПК — две
		-- (подписи >= 14 px помещаются)
		if lay.Mode == "landscape" then
			grid.CellSize = UDim2.new(1 / 3, -10, 0, 54)
		else
			grid.CellSize = UDim2.new(0.5, -10, 0, 58)
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
	ClientState.onCore(function(core)
		renderAuto(core)
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
