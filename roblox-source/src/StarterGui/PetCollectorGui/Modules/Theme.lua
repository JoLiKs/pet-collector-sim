--!strict
local Theme = {}

local c3 = Color3.fromRGB

Theme.Bg = c3(28, 32, 48)
Theme.BgLight = c3(44, 50, 74)
Theme.BgCard = c3(56, 64, 94)
Theme.Text = c3(245, 247, 255)
Theme.TextDim = c3(170, 180, 205)
Theme.Gold = c3(255, 208, 70)
Theme.Gem = c3(100, 220, 255)
Theme.Purple = c3(180, 110, 255)
Theme.Green = c3(80, 205, 110)
Theme.Red = c3(235, 85, 85)
Theme.Blue = c3(70, 140, 250)
Theme.Orange = c3(255, 150, 50)
Theme.Disabled = c3(90, 96, 120)
Theme.Font = Enum.Font.FredokaOne
Theme.FontBody = Enum.Font.GothamBold

-- v3.0: общий масштаб интерфейса. На ПК всё в 1.5 раза меньше (1/1.5),
-- на телефонах мягче (1/1.25), чтобы текст читался и кнопки оставались >= 36 px.
Theme.UI_SCALE = 1 / 1.5
Theme.UI_SCALE_TOUCH = 0.8
Theme.MIN_TAP = 36

function Theme.uiScale(lay: any?): number
	if lay and (lay.Mode == "portrait" or lay.Mode == "landscape") then
		return Theme.UI_SCALE_TOUCH
	end
	return Theme.UI_SCALE
end

-- v3.2: окна (Widgets.panel) — своя геометрия и масштаб (UiGeometry): содержимое в PANEL_SCALE (0.8) и на ПК,
-- чтобы основной текст был не мельче 12 px, заголовки — 14 px; окно на ПК компактное, на телефоне — в безопасной
-- области над хотбаром и не закрывает кнопки HUD. Возвращает размер окна в «дизайнерских» px (видимый = × k).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiGeometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiGeometry"))
Theme.Geometry = UiGeometry
Theme.PANEL_SCALE = UiGeometry.PANEL_SCALE

function Theme.panelScale(_lay: any?): number
	return UiGeometry.PANEL_SCALE
end

function Theme.panelDesign(lay: any, k: number, minH: number?, area: any?): (number, number)
	local r = UiGeometry.panelRect(lay, k, minH, area)
	return math.floor(r.W / k), math.floor(r.H / k)
end

return Theme
