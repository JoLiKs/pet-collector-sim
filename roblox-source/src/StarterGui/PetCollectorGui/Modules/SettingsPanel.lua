--!nonstrict
-- Настройки: выбор языка (Авто / English / Русский) и звук (v3.1: музыка вкл/выкл, громкость музыки, звуки).
-- Всё хранится в данных игрока (Settings.Lang, Settings.Audio).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioData = require(Shared:WaitForChild("AudioData"))
local Config = require(Shared:WaitForChild("Config"))
local L = require(Shared:WaitForChild("Locale"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local SettingsPanel = {}

function SettingsPanel.init(gui: ScreenGui, panels: { [string]: any }?)
	local panel = Widgets.panel(gui, "Settings")
	-- v3.1: окно стало меньше — содержимое в прокрутке с фиксированной высотой холста
	-- (AutomaticCanvasSize под UIScale в Roblox считает неверно)
	local CANVAS_H = 470
	local body = Widgets.scroller(panel.Body, {
		Name = "SettingsScroll",
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		CanvasSize = UDim2.fromOffset(0, CANVAS_H),
	})
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
	-- ---------- звук (v3.1) ----------
	UiKit.text(body, L.k("settings.audio"), UDim2.fromOffset(0, 140), UDim2.new(1, 0, 0, 30), {
		Font = Theme.Font,
		MaxSize = 24,
	})
	local function setAudio(key: string, value: any)
		Actions.call("SetAudio", key, value)
	end
	local function audio()
		return AudioData.normalize(ClientState.Core and ClientState.Core.Audio)
	end
	local musicBtn = Widgets.button({
		Name = "MusicToggle",
		Text = "",
		Color = Theme.Green,
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(0.5, -4, 0, 44),
		MaxTextSize = 20,
		ZIndex = 23,
		Parent = body,
		OnClick = function()
			setAudio("Music", not audio().Music)
		end,
	})
	Widgets.buttonIcon(musicBtn, "Note", 24) -- v3.2: значок вместо эмодзи
	local sfxBtn = Widgets.button({
		Name = "SfxToggle",
		Text = "",
		Color = Theme.Green,
		Position = UDim2.new(0.5, 4, 0, 178),
		Size = UDim2.new(0.5, -4, 0, 44),
		MaxTextSize = 20,
		ZIndex = 23,
		Parent = body,
		OnClick = function()
			setAudio("Sfx", not audio().Sfx)
		end,
	})
	Widgets.buttonIcon(sfxBtn, "Bell", 24) -- v3.2: значок вместо эмодзи
	UiKit.text(body, L.k("settings.music_volume"), UDim2.fromOffset(0, 236), UDim2.new(0.45, 0, 0, 40), {
		MaxSize = 18,
	})
	local volDown = Widgets.button({
		Name = "VolDown",
		Text = "−",
		Color = Theme.Blue,
		Position = UDim2.new(0.45, 0, 0, 234),
		Size = UDim2.new(0.15, 0, 0, 44),
		MaxTextSize = 24,
		ZIndex = 23,
		Parent = body,
		OnClick = function()
			setAudio("MusicVol", math.max(0, audio().MusicVol - AudioData.VOL_STEP))
		end,
	})
	local volText = UiKit.text(body, "", UDim2.new(0.6, 4, 0, 234), UDim2.new(0.22, -8, 0, 44), {
		Font = Theme.Font,
		MaxSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	volText.Name = "VolValue"
	local volUp = Widgets.button({
		Name = "VolUp",
		Text = "+",
		Color = Theme.Blue,
		Position = UDim2.new(0.82, 0, 0, 234),
		Size = UDim2.new(0.18, 0, 0, 44),
		MaxTextSize = 24,
		ZIndex = 23,
		Parent = body,
		OnClick = function()
			setAudio("MusicVol", math.min(1, audio().MusicVol + AudioData.VOL_STEP))
		end,
	})
	-- ID треков ещё не вписаны в Config.SOUNDS — честно говорим, что музыки пока нет
	local missing = AudioData.soundId(Config.SOUNDS.MUSIC_CALM) == nil
		and AudioData.soundId(Config.SOUNDS.MUSIC_EPIC) == nil
	-- v3.2.2: строка состояния музыки (для диагностики в настоящей игре): играет / загружается / ошибка <код>
	local statusText = UiKit.text(body, "", UDim2.fromOffset(0, 286), UDim2.new(1, 0, 0, 22), {
		TextColor3 = Theme.TextDim,
		MaxSize = 15,
	})
	statusText.Name = "MusicStatus"
	local function renderStatus()
		local st = gui:GetAttribute("MusicStatus")
		local line = if type(st) == "string" then st else ""
		local kind, code = string.match(line, "^(%a+)%s?(.*)$")
		if kind == "playing" or kind == "loading" or kind == "off" then
			statusText.Text = L.t("settings.music_status_" .. kind)
		elseif kind == "error" then
			statusText.Text = L.t("settings.music_status_error", { code = code or "" })
		else
			statusText.Text = L.t("settings.music_status_loading")
		end
	end
	gui:GetAttributeChangedSignal("MusicStatus"):Connect(renderStatus)
	renderStatus()
	local missingText =
		UiKit.text(body, L.k("settings.music_missing"), UDim2.fromOffset(0, 312), UDim2.new(1, 0, 0, 36), {
			TextColor3 = Theme.TextDim,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxSize = 15,
		})
	missingText.Name = "MusicMissing"
	missingText.Visible = missing

	UiKit.text(
		body,
		L.k("settings.hint"),
		UDim2.fromOffset(0, if missing then 356 else 316),
		UDim2.new(1, 0, 0, 60),
		{
			TextColor3 = Theme.TextDim,
			TextYAlignment = Enum.TextYAlignment.Top,
			MaxSize = 16,
		}
	)

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
		local a = audio()
		musicBtn.Text = L.t(if a.Music then "settings.music_on" else "settings.music_off")
		musicBtn.BackgroundColor3 = if a.Music then Theme.Green else Theme.BgLight
		sfxBtn.Text = L.t(if a.Sfx then "settings.sfx_on" else "settings.sfx_off")
		sfxBtn.BackgroundColor3 = if a.Sfx then Theme.Green else Theme.BgLight
		volText.Text = string.format("%d%%", math.floor(a.MusicVol * 100 + 0.5))
		volDown.Active = a.MusicVol > 0
		volUp.Active = a.MusicVol < 1
		renderStatus()
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
