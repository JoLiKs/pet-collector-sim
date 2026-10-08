--!strict
--[[
	UiGeometry (v3.2) — чистая геометрия всплывающих окон (Widgets.panel), покрыта тестами.
	  * масштаб содержимого окон PANEL_SCALE (0.8) одинаков на ПК и телефоне: «дизайнерский» текст 15 px
	    виден как 12 px — минимум для основного текста (MIN_BODY), 18 -> 14 px — для заголовков (MIN_TITLE);
	  * ПК (wide): окно компактное, по центру (≈435×317 при 1280×720; плотные окна выше — MinH);
	  * телефон: окно занимает «безопасную область» (area) — над хотбаром/кошельком/плашками событий,
	    между колонками кнопок (горизонтально) или над ними (вертикально), — и не закрывает кнопки HUD.
	    Область считает HUD (Hud.lua) по реальным прямоугольникам кнопок: areaFor.
]]
local UiGeometry = {}

export type Rect = { X: number, Y: number, W: number, H: number }
export type Lay = { Mode: string, W: number, H: number, Touch: boolean? }

UiGeometry.PANEL_SCALE = 0.8
UiGeometry.MIN_BODY = 12
UiGeometry.MIN_TITLE = 14
UiGeometry.GAP = 8
-- ПК: доля экрана и потолок видимого размера окна (px)
UiGeometry.WIDE_W, UiGeometry.WIDE_MAX_W = 0.34, 440
UiGeometry.WIDE_H, UiGeometry.WIDE_MAX_H = 0.44, 320
-- телефон горизонтально: окно не шире (px)
UiGeometry.LAND_MAX_W = 560
-- окно не меньше (видимые px), даже если область тесная
UiGeometry.MIN_W, UiGeometry.MIN_H = 240, 180

-- Минимальный «дизайнерский» размер текста при масштабе k (видимый = результат × k)
function UiGeometry.minText(k: number, title: boolean?): number
	local px = if title then UiGeometry.MIN_TITLE else UiGeometry.MIN_BODY
	return math.ceil(px / k - 1e-6)
end

-- Безопасная область для окна на телефоне (видимые px в координатах ScreenGui).
-- left/right — колонки кнопок, bottoms — элементы внизу (хотбар, кошелёк, плашки событий).
-- portrait: окно над колонками на всю ширину; landscape: между колонками и над нижними элементами.
function UiGeometry.areaFor(
	mode: string,
	W: number,
	H: number,
	left: Rect?,
	right: Rect?,
	bottoms: { Rect },
	top: number?
): Rect?
	if mode == "wide" then
		return nil
	end
	local g = UiGeometry.GAP
	local y0 = (top or 0) + 6
	local x0, x1, y1 = g, W - g, H - g
	if mode == "portrait" then
		if left then
			y1 = math.min(y1, left.Y - g)
		end
		if right then
			y1 = math.min(y1, right.Y - g)
		end
	else
		if left then
			x0 = math.max(x0, left.X + left.W + g)
		end
		if right then
			x1 = math.min(x1, right.X - g)
		end
	end
	for _, b in ipairs(bottoms) do
		-- только то, что под окном по горизонтали
		if b.W > 0 and b.X < x1 and b.X + b.W > x0 then
			y1 = math.min(y1, b.Y - g)
		end
	end
	return { X = x0, Y = y0, W = math.max(0, x1 - x0), H = math.max(0, y1 - y0) }
end

-- Видимый прямоугольник окна (px): центр и размер. minH — «дизайнерская» минимальная высота плотных окон.
function UiGeometry.panelRect(lay: Lay, k: number, minH: number?, area: Rect?): Rect
	local w, h
	if area and lay.Mode ~= "wide" then
		w = math.min(area.W, if lay.Mode == "landscape" then UiGeometry.LAND_MAX_W else area.W)
		h = area.H
		w, h =
			math.max(w, math.min(UiGeometry.MIN_W, lay.W - 16)),
			math.max(h, math.min(UiGeometry.MIN_H, lay.H - 16))
		local cx = area.X + area.W / 2
		return { X = math.floor(cx - w / 2), Y = math.floor(area.Y), W = math.floor(w), H = math.floor(h) }
	end
	w = math.min(lay.W * UiGeometry.WIDE_W, UiGeometry.WIDE_MAX_W)
	h = math.min(lay.H * UiGeometry.WIDE_H, UiGeometry.WIDE_MAX_H)
	if lay.Mode ~= "wide" then
		-- телефон, пока HUD не посчитал область: по центру с полями
		w, h = math.min(lay.W - 32, UiGeometry.LAND_MAX_W), math.min(lay.H * 0.6, lay.H - 120)
	end
	if minH then
		h = math.min(math.max(h, minH * k), lay.H - 24)
	end
	w, h =
		math.max(w, math.min(UiGeometry.MIN_W, lay.W - 16)),
		math.max(h, math.min(UiGeometry.MIN_H, lay.H - 16))
	w, h = math.floor(w), math.floor(h)
	return { X = math.floor((lay.W - w) / 2 + 0.5), Y = math.floor((lay.H - h) / 2 + 0.5), W = w, H = h }
end

return UiGeometry
