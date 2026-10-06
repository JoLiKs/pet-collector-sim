--!nonstrict
-- Настройки: выбор языка (Авто / English / Русский). Выбор хранится в данных игрока (Settings.Lang).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local SettingsPanel = {}

function SettingsPanel.init(gui: ScreenGui, panels: { [string]: any }?)
	local panel = Widgets.panel(gui, "Settings")
	local body = panel.Body
	Widgets.padding(body, 14)

	UiKit.text(body, L.k("settings.language"), UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 30), {
		Font = Theme.Font,
		MaxSize = 24,
	})

	local row = Widgets.New("Frame", {
		Name = "LangRow",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 1, 0),
		CellPadding = UDim2.fromOffset(8, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})

	local choices = { "auto", "en", "ru" }
	local buttons = {}
	for i, choice in ipairs(choices) do
		local b = Widgets.button({
			Name = "Lang_" .. choice,
			Text = if choice == "auto" then "" else L.LANG_NAMES[choice],
			Color = Theme.Blue,
			MaxTextSize = 22,
			ZIndex = 23,
			Parent = row,
			OnClick = function()
				Actions.call("SetLanguage", choice)
			end,
		})
		b.LayoutOrder = i
		buttons[choice] = b
	end

	local info = UiKit.text(body, "", UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 24), {
		TextColor3 = Theme.TextDim,
		MaxSize = 18,
	})
	UiKit.text(body, L.k("settings.hint"), UDim2.fromOffset(0, 136), UDim2.new(1, 0, 0, 60), {
		TextColor3 = Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		MaxSize = 16,
	})

	local function render()
		local lp = Players.LocalPlayer
		local auto = lp:GetAttribute("LangAuto")
		local country = lp:GetAttribute("Country")
		local setting = ClientState.Core and ClientState.Core.LangSetting or "auto"
		buttons.auto.Text = L.t("settings.auto", { lang = L.LANG_NAMES[auto] or L.LANG_NAMES[L.lang()] })
		for choice, b in pairs(buttons) do
			b.BackgroundColor3 = if choice == setting then Theme.Green else Theme.BgLight
		end
		info.Text = if type(country) == "string" and country ~= ""
			then L.t("settings.detected", { country = country })
			else L.t("settings.detected_none")
	end
	ClientState.onCore(render)
	L.onChanged(render)
	Players.LocalPlayer:GetAttributeChangedSignal("LangAuto"):Connect(render)

	local api = {
		Root = panel.Root,
		Open = function()
			render()
			panel.Open()
		end,
		Close = panel.Close,
		IsOpen = panel.IsOpen,
	}
	if panels then
		panels.Settings = api
	end
	return api
end

return SettingsPanel
