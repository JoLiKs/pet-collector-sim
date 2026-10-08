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

-- v3.1: всплывающие окна (Widgets.panel) в 1.5 раза меньше, чем в v3.0, при том же масштабе текста k:
-- на ПК окно в 1.5 раза меньше по каждой стороне (было до 760×540 «дизайнерских» px × k), на телефоне —
-- в ~1.5 раза меньше по площади (текст не мельче 0.8, кнопки >= MIN_TAP). Возвращает размер окна
-- в «дизайнерских» пикселях (до UIScale k): видимый размер = результат × k.
Theme.PANEL_SHRINK = 1.5
-- minH — минимальная высота окна в «дизайнерских» px для окон с плотной раскладкой (питомцы, инвентарь,
-- яйцо, обмен): они уменьшаются меньше, чтобы ничего не обрезалось.
function Theme.panelDesign(lay: any, k: number, minH: number?): (number, number)
	local w, h
	if lay.Mode == "portrait" then
		w, h = math.min(lay.W - 30, 360), math.min(lay.H * 0.36, 310)
	elseif lay.Mode == "landscape" and lay.Touch then
		w, h = math.min(lay.W - 170, 500), math.min(lay.H - 60, 300)
	elseif lay.Mode == "landscape" then
		w, h = math.min(lay.W * 0.84, 760 * k), math.min(lay.H - 24, 540 * k)
		w, h = w / Theme.PANEL_SHRINK, math.max(h / Theme.PANEL_SHRINK, math.min(lay.H - 24, 240))
	else
		w = math.min(lay.W * 0.62, 760 * k) / Theme.PANEL_SHRINK
		h = math.min(lay.H * 0.72, 540 * k) / Theme.PANEL_SHRINK
	end
	if minH then
		local maxH = if lay.Mode == "portrait" then lay.H * 0.6 else lay.H - 24
		h = math.min(math.max(h, minH * k), math.max(h, maxH))
	end
	return math.floor(w / k), math.floor(h / k)
end

return Theme
