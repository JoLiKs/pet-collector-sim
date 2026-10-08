--!strict
--[[
	Icons — иконки валют, ресурсов, предметов и инструментов из примитивов GUI (Frame + UICorner + UIGradient + UIStroke).
	Без эмодзи и без загрузок: одинаково в Roblox (любой клиент) и в веб-демо. Эмодзи 🪙 (Unicode 13) не рисуется
	на Windows 10 и в части шрифтов — отсюда «пропавшая» иконка монет в v2.5.
	Если в Config.ASSETS задан ID картинки (COIN, GEM, WOOD, …) — показывается ImageLabel с ней.

	Icons.make(kind, props) -> Frame: квадратный контейнер, всё внутри в долях (масштабируется с размером).
	  kind: Coin, Gem, Wood, Stone, Ore, Herb, Crystal, Essence, Fragment, Sword, Magnet, Potion,
	        id предмета из RecipeData (luck_potion, coin_elixir, xp_treat, catalyst, pickaxe, blade, ticket_*).
	  props: Name, Size, Position, AnchorPoint, ZIndex, LayoutOrder, Parent, Px (примерный размер в пикселях — толщина обводки).
]]
local Assets = require(script.Parent.Assets)

local Icons = {}

local c3 = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)

-- Слой: { x, y, w, h } — центр и размер в долях контейнера.
--   c — цвет, g = { верх/лево, низ/право } — градиент, gr — его Rotation (по умолчанию 90), r — поворот (°, вокруг центра), k — скругление (доля),
--   t — прозрачность, ring = толщина кольца (доля размера: только обводка, без заливки), o = false — без общего контура.
type Layer = { [string]: any }
local function L(x: number, y: number, w: number, h: number, o: any): Layer
	local t: Layer = o or {}
	t.X, t.Y, t.W, t.H = x, y, w, h
	return t
end
type Spec = { Outline: Color3?, Layers: { Layer } }

local function flask(liquid: Color3, liquidDark: Color3): Spec
	return {
		Outline = c3(30, 40, 60),
		Layers = {
			L(0.5, 0.25, 0.22, 0.26, { c = c3(215, 235, 245), k = 0.15 }), -- горлышко
			L(0.5, 0.63, 0.66, 0.62, { g = { c3(225, 240, 250), c3(170, 200, 220) }, gr = 90, k = 0.5 }), -- колба
			L(0.5, 0.67, 0.54, 0.46, { g = { liquid, liquidDark }, gr = 90, k = 0.5, o = false }), -- жидкость
			L(0.5, 0.13, 0.28, 0.1, { c = c3(170, 110, 60), k = 0.3 }), -- пробка
			L(0.37, 0.56, 0.1, 0.18, { c = WHITE, t = 0.35, k = 0.5, r = 20, o = false }), -- блик
			L(0.58, 0.72, 0.07, 0.07, { c = WHITE, t = 0.45, k = 0.5, o = false }), -- пузырёк
			L(0.45, 0.8, 0.05, 0.05, { c = WHITE, t = 0.5, k = 0.5, o = false }),
		},
	}
end

local function ticket(color: Color3, dark: Color3): Spec
	return {
		Outline = c3(40, 30, 20),
		Layers = {
			L(0.5, 0.5, 0.86, 0.56, { g = { color, dark }, gr = 90, k = 0.14, r = -12 }),
			L(0.5, 0.5, 0.7, 0.4, { c = WHITE, t = 0.75, k = 0.1, r = -12, o = false }),
			L(
				0.5,
				0.5,
				0.22,
				0.3,
				{ g = { c3(255, 252, 240), c3(235, 220, 190) }, gr = 90, k = 0.5, r = -12, o = false }
			),
			L(0.47, 0.44, 0.06, 0.07, { c = WHITE, k = 0.5, o = false }),
		},
	}
end

Icons.SPECS = {
	Coin = {
		Outline = c3(125, 72, 8),
		Layers = {
			L(0.5, 0.5, 0.9, 0.9, { g = { c3(250, 190, 50), c3(205, 120, 20) }, gr = 90, k = 0.5 }), -- ребро
			L(
				0.5,
				0.5,
				0.7,
				0.7,
				{ g = { c3(255, 240, 140), c3(250, 185, 40) }, gr = 45, k = 0.5, o = false }
			), -- лицевая сторона
			L(0.5, 0.5, 0.52, 0.52, { ring = 0.035, c = c3(215, 140, 25), k = 0.5, o = false }), -- внутреннее кольцо
			L(
				0.5,
				0.5,
				0.24,
				0.24,
				{ g = { c3(255, 250, 210), c3(245, 200, 80) }, gr = 90, r = 45, k = 0.12, o = false }
			), -- ромб-чекан
			L(0.33, 0.29, 0.22, 0.1, { c = WHITE, t = 0.3, k = 0.5, r = -40, o = false }), -- блик
		},
	},
	Gem = {
		Outline = c3(10, 60, 125),
		Layers = {
			L(0.5, 0.54, 0.6, 0.6, { g = { c3(150, 245, 255), c3(30, 130, 235) }, gr = 90, r = 45, k = 0.1 }),
			L(
				0.5,
				0.54,
				0.3,
				0.3,
				{ g = { c3(225, 252, 255), c3(110, 210, 255) }, gr = 90, r = 45, k = 0.1, o = false }
			),
			L(0.4, 0.4, 0.14, 0.06, { c = WHITE, t = 0.25, k = 0.5, r = -45, o = false }),
			L(0.78, 0.2, 0.1, 0.1, { c = WHITE, r = 45, k = 0.2, o = false }), -- искры
			L(0.2, 0.84, 0.07, 0.07, { c = WHITE, r = 45, k = 0.2, t = 0.2, o = false }),
		},
	},
	Wood = {
		Outline = c3(65, 35, 12),
		Layers = {
			L(0.44, 0.56, 0.72, 0.44, { g = { c3(185, 120, 62), c3(115, 66, 28) }, gr = 90, k = 0.3 }), -- кора
			L(0.8, 0.56, 0.32, 0.44, { g = { c3(245, 210, 150), c3(215, 165, 100) }, gr = 90, k = 0.5 }), -- спил
			L(0.8, 0.56, 0.16, 0.22, { ring = 0.03, c = c3(180, 125, 70), k = 0.5, o = false }), -- годовое кольцо
			L(0.8, 0.56, 0.05, 0.06, { c = c3(170, 115, 60), k = 0.5, o = false }),
			L(0.4, 0.47, 0.42, 0.04, { c = c3(95, 55, 22), k = 0.5, o = false }), -- полосы коры
			L(0.36, 0.64, 0.34, 0.04, { c = c3(95, 55, 22), k = 0.5, o = false }),
			L(
				0.28,
				0.3,
				0.2,
				0.11,
				{ g = { c3(150, 230, 110), c3(70, 170, 70) }, gr = 90, k = 0.5, r = -35 }
			), -- листик
		},
	},
	Stone = {
		Outline = c3(50, 52, 64),
		Layers = {
			L(0.4, 0.44, 0.48, 0.42, { g = { c3(215, 220, 230), c3(150, 155, 170) }, gr = 90, k = 0.45 }),
			L(0.68, 0.5, 0.36, 0.32, { g = { c3(195, 200, 212), c3(130, 135, 150) }, gr = 90, k = 0.45 }),
			L(0.5, 0.64, 0.8, 0.44, { g = { c3(185, 190, 202), c3(105, 110, 125) }, gr = 90, k = 0.42 }),
			L(0.36, 0.4, 0.18, 0.08, { c = WHITE, t = 0.35, k = 0.5, r = -20, o = false }),
			L(0.62, 0.66, 0.2, 0.035, { c = c3(80, 84, 98), k = 0.5, r = 35, o = false }), -- трещина
		},
	},
	Ore = {
		Outline = c3(45, 35, 35),
		Layers = {
			L(0.5, 0.58, 0.84, 0.62, { g = { c3(140, 128, 125), c3(78, 70, 72) }, gr = 90, k = 0.42 }),
			L(0.36, 0.56, 0.2, 0.2, { g = { c3(255, 205, 140), c3(205, 110, 55) }, gr = 45, k = 0.5 }),
			L(0.62, 0.46, 0.16, 0.16, { g = { c3(255, 205, 140), c3(205, 110, 55) }, gr = 45, k = 0.5 }),
			L(0.6, 0.72, 0.13, 0.13, { g = { c3(255, 205, 140), c3(205, 110, 55) }, gr = 45, k = 0.5 }),
			L(0.33, 0.52, 0.06, 0.05, { c = WHITE, t = 0.2, k = 0.5, o = false }),
			L(0.6, 0.43, 0.05, 0.04, { c = WHITE, t = 0.2, k = 0.5, o = false }),
		},
	},
	Herb = {
		Outline = c3(25, 85, 35),
		Layers = {
			L(0.5, 0.72, 0.06, 0.42, { c = c3(70, 150, 60), k = 0.5 }), -- стебель
			L(
				0.29,
				0.52,
				0.44,
				0.25,
				{ g = { c3(165, 240, 125), c3(55, 165, 70) }, gr = 90, k = 0.5, r = 30 }
			),
			L(
				0.71,
				0.44,
				0.44,
				0.25,
				{ g = { c3(165, 240, 125), c3(55, 165, 70) }, gr = 90, k = 0.5, r = -30 }
			),
			L(
				0.46,
				0.25,
				0.25,
				0.38,
				{ g = { c3(180, 245, 140), c3(70, 180, 80) }, gr = 90, k = 0.5, r = -15 }
			),
			L(0.46, 0.27, 0.025, 0.26, { c = c3(60, 140, 60), r = -15, o = false }), -- прожилки
			L(0.3, 0.52, 0.28, 0.025, { c = c3(60, 140, 60), r = 30, o = false }),
			L(0.7, 0.44, 0.28, 0.025, { c = c3(60, 140, 60), r = -30, o = false }),
			L(0.78, 0.18, 0.15, 0.15, { g = { c3(255, 130, 150), c3(215, 50, 80) }, gr = 90, k = 0.5 }), -- ягодки
			L(0.88, 0.3, 0.11, 0.11, { g = { c3(255, 130, 150), c3(215, 50, 80) }, gr = 90, k = 0.5 }),
			L(0.75, 0.15, 0.05, 0.05, { c = WHITE, t = 0.2, k = 0.5, o = false }),
		},
	},
	Crystal = {
		Outline = c3(15, 70, 130),
		Layers = {
			L(0.28, 0.68, 0.18, 0.3, { g = { c3(200, 250, 255), c3(70, 175, 235) }, gr = 0 }),
			L(0.28, 0.53, 0.127, 0.127, { g = { c3(220, 252, 255), c3(120, 210, 250) }, gr = 0, r = 45 }),
			L(0.72, 0.66, 0.18, 0.34, { g = { c3(200, 250, 255), c3(70, 175, 235) }, gr = 0 }),
			L(0.72, 0.49, 0.127, 0.127, { g = { c3(220, 252, 255), c3(120, 210, 250) }, gr = 0, r = 45 }),
			L(0.5, 0.58, 0.24, 0.5, { g = { c3(215, 252, 255), c3(60, 165, 235) }, gr = 0 }),
			L(0.5, 0.33, 0.17, 0.17, { g = { c3(235, 255, 255), c3(130, 215, 250) }, gr = 0, r = 45 }),
			L(0.44, 0.58, 0.05, 0.38, { c = WHITE, t = 0.35, o = false }), -- грань-блик
			L(0.5, 0.86, 0.78, 0.12, { c = c3(95, 100, 125), k = 0.5 }), -- основание
		},
	},
	Essence = {
		Outline = c3(80, 25, 130),
		Layers = {
			L(0.5, 0.52, 0.96, 0.96, { c = c3(225, 150, 255), t = 0.72, k = 0.5, o = false }), -- свечение
			L(0.5, 0.52, 0.66, 0.66, { g = { c3(250, 205, 255), c3(150, 60, 220) }, gr = 60, k = 0.5 }),
			L(0.56, 0.58, 0.3, 0.3, { c = c3(255, 225, 255), t = 0.35, k = 0.5, o = false }),
			L(0.4, 0.38, 0.16, 0.08, { c = WHITE, t = 0.2, k = 0.5, r = -35, o = false }),
			L(0.82, 0.18, 0.11, 0.11, { c = WHITE, r = 45, k = 0.2, o = false }),
			L(0.17, 0.8, 0.08, 0.08, { c = WHITE, r = 45, k = 0.2, o = false }),
		},
	},
	Fragment = {
		Outline = c3(115, 55, 10),
		Layers = {
			L(0.5, 0.5, 0.8, 0.8, { c = c3(255, 185, 90), t = 0.86, k = 0.5, o = false }),
			L(
				0.48,
				0.48,
				0.34,
				0.72,
				{ g = { c3(255, 228, 150), c3(225, 115, 35) }, gr = 0, r = 28, k = 0.06 }
			),
			L(
				0.74,
				0.74,
				0.14,
				0.3,
				{ g = { c3(255, 228, 150), c3(225, 115, 35) }, gr = 0, r = -24, k = 0.06 }
			),
			L(0.44, 0.44, 0.08, 0.5, { c = c3(255, 245, 210), t = 0.3, r = 28, o = false }),
		},
	},
	Sword = {
		Outline = c3(30, 35, 55),
		Layers = {
			L(0.57, 0.43, 0.15, 0.66, { g = { c3(245, 250, 255), c3(150, 165, 190) }, gr = 0, r = 45 }), -- клинок
			L(0.79, 0.21, 0.106, 0.106, { g = { c3(245, 250, 255), c3(170, 185, 205) }, gr = 0, r = 45 }), -- остриё
			L(0.57, 0.43, 0.035, 0.58, { c = c3(120, 210, 255), r = 45, o = false }), -- дол (неоновая кромка)
			L(
				0.33,
				0.67,
				0.4,
				0.1,
				{ g = { c3(255, 225, 100), c3(210, 145, 30) }, gr = 90, r = 45, k = 0.4 }
			), -- гарда
			L(0.25, 0.75, 0.09, 0.2, { c = c3(120, 75, 40), r = 45, k = 0.3 }), -- рукоять
			L(0.17, 0.83, 0.12, 0.12, { g = { c3(255, 225, 100), c3(210, 145, 30) }, gr = 90, k = 0.5 }), -- навершие
		},
	},
	Magnet = {
		Outline = c3(70, 15, 20),
		Layers = {
			L(0.3, 0.42, 0.2, 0.4, { g = { c3(255, 110, 110), c3(200, 35, 45) }, gr = 0 }),
			L(0.7, 0.42, 0.2, 0.4, { g = { c3(255, 110, 110), c3(200, 35, 45) }, gr = 0 }),
			L(0.3, 0.26, 0.2, 0.12, { g = { c3(245, 248, 255), c3(170, 180, 200) }, gr = 0 }), -- полюса
			L(0.7, 0.26, 0.2, 0.12, { g = { c3(245, 248, 255), c3(170, 180, 200) }, gr = 0 }),
			L(0.5, 0.62, 0.6, 0.6, { arc = true, c = c3(225, 55, 60) }), -- дуга (нижняя половина кольца)
		},
	},
	Egg = {
		Outline = c3(40, 50, 90),
		Layers = {
			L(0.5, 0.54, 0.64, 0.84, { g = { c3(255, 255, 255), c3(185, 205, 240) }, gr = 45, k = 0.5 }),
			L(0.38, 0.42, 0.16, 0.12, { c = c3(127, 200, 255), k = 0.5, o = false }),
			L(0.6, 0.62, 0.2, 0.13, { c = c3(255, 179, 224), k = 0.5, o = false }),
			L(0.42, 0.78, 0.12, 0.09, { c = c3(155, 240, 154), k = 0.5, o = false }),
			L(0.38, 0.27, 0.1, 0.2, { c = WHITE, t = 0.15, k = 0.5, r = 25, o = false }),
		},
	},
	Bag = {
		Outline = c3(70, 38, 15),
		Layers = {
			L(0.5, 0.2, 0.36, 0.2, { ring = 0.07, c = c3(120, 70, 30), k = 0.5, o = false }), -- ручка
			L(0.5, 0.58, 0.74, 0.68, { g = { c3(215, 145, 75), c3(150, 90, 40) }, gr = 90, k = 0.3 }), -- корпус
			L(0.5, 0.4, 0.74, 0.3, { g = { c3(235, 170, 95), c3(185, 115, 55) }, gr = 90, k = 0.35 }), -- клапан
			L(0.5, 0.7, 0.42, 0.24, { g = { c3(200, 130, 65), c3(160, 95, 45) }, gr = 90, k = 0.25 }), -- карман
			L(0.5, 0.52, 0.14, 0.12, { g = { c3(255, 230, 120), c3(220, 160, 40) }, gr = 90, k = 0.25 }), -- застёжка
			L(0.36, 0.33, 0.14, 0.05, { c = WHITE, t = 0.4, k = 0.5, o = false }),
		},
	},
	Potion = flask(c3(120, 245, 200), c3(30, 170, 140)),
	luck_potion = flask(c3(150, 250, 120), c3(40, 170, 60)),
	coin_elixir = flask(c3(255, 230, 110), c3(230, 150, 20)),
	xp_treat = {
		Outline = c3(110, 80, 50),
		Layers = {
			L(0.22, 0.42, 0.22, 0.22, { c = c3(255, 240, 215), k = 0.5 }),
			L(0.22, 0.6, 0.22, 0.22, { c = c3(255, 240, 215), k = 0.5 }),
			L(0.78, 0.42, 0.22, 0.22, { c = c3(255, 240, 215), k = 0.5 }),
			L(0.78, 0.6, 0.22, 0.22, { c = c3(255, 240, 215), k = 0.5 }),
			L(0.5, 0.51, 0.58, 0.2, { g = { c3(255, 248, 232), c3(235, 210, 175) }, gr = 90, k = 0.2 }),
			L(0.5, 0.47, 0.4, 0.04, { c = WHITE, t = 0.3, k = 0.5, o = false }),
		},
	},
	catalyst = {
		Outline = c3(70, 25, 110),
		Layers = {
			L(0.5, 0.5, 0.62, 0.62, { ring = 0.07, c = c3(200, 140, 255), k = 0.5, o = false }),
			L(0.5, 0.5, 0.4, 0.4, { g = { c3(255, 190, 255), c3(140, 60, 220) }, gr = 45, k = 0.5 }),
			L(0.5, 0.12, 0.12, 0.12, { c = c3(255, 220, 120), r = 45, k = 0.2 }),
			L(0.88, 0.5, 0.12, 0.12, { c = c3(120, 230, 255), r = 45, k = 0.2 }),
			L(0.5, 0.88, 0.12, 0.12, { c = c3(255, 140, 170), r = 45, k = 0.2 }),
			L(0.12, 0.5, 0.12, 0.12, { c = c3(150, 250, 140), r = 45, k = 0.2 }),
			L(0.44, 0.42, 0.1, 0.06, { c = WHITE, t = 0.25, k = 0.5, r = -35, o = false }),
		},
	},
	pickaxe = {
		Outline = c3(35, 35, 50),
		Layers = {
			L(0.5, 0.55, 0.11, 0.78, { g = { c3(185, 125, 70), c3(120, 75, 35) }, gr = 0, r = 35, k = 0.4 }), -- рукоять
			L(
				0.66,
				0.31,
				0.74,
				0.15,
				{ g = { c3(235, 240, 250), c3(130, 140, 160) }, gr = 90, r = 35, k = 0.5 }
			), -- кирка
			L(0.66, 0.31, 0.16, 0.2, { c = c3(110, 115, 135), r = 35, k = 0.2 }), -- обух
		},
	},
	blade = {
		Outline = c3(60, 20, 30),
		Layers = {
			L(0.57, 0.43, 0.17, 0.66, { g = { c3(255, 215, 215), c3(200, 70, 90) }, gr = 0, r = 45 }),
			L(0.79, 0.21, 0.12, 0.12, { g = { c3(255, 225, 225), c3(210, 90, 110) }, gr = 0, r = 45 }),
			L(0.57, 0.43, 0.04, 0.56, { c = c3(255, 240, 160), r = 45, o = false }),
			L(0.33, 0.67, 0.42, 0.11, { g = { c3(70, 70, 90), c3(30, 30, 45) }, gr = 90, r = 45, k = 0.4 }),
			L(0.25, 0.75, 0.09, 0.2, { c = c3(60, 40, 30), r = 45, k = 0.3 }),
			L(0.17, 0.83, 0.12, 0.12, { g = { c3(255, 120, 120), c3(180, 30, 50) }, gr = 90, k = 0.5 }),
		},
	},
	ticket_MeadowEgg = ticket(c3(150, 230, 110), c3(70, 165, 70)),
	ticket_ForestEgg = ticket(c3(90, 175, 100), c3(35, 105, 60)),
	ticket_FrostEgg = ticket(c3(170, 225, 255), c3(70, 140, 220)),
	-- v2.8: окно ежедневной награды
	Gift = {
		Outline = c3(70, 15, 40),
		Layers = {
			L(0.5, 0.64, 0.7, 0.5, { g = { c3(255, 110, 150), c3(205, 40, 90) }, gr = 90, k = 0.12 }), -- коробка
			L(0.5, 0.38, 0.84, 0.2, { g = { c3(255, 140, 175), c3(225, 60, 110) }, gr = 90, k = 0.18 }), -- крышка
			L(0.5, 0.64, 0.16, 0.5, { g = { c3(255, 230, 110), c3(240, 170, 30) }, gr = 0, o = false }), -- лента
			L(0.5, 0.38, 0.18, 0.2, { g = { c3(255, 235, 120), c3(240, 175, 35) }, gr = 0, o = false }),
			L(
				0.36,
				0.2,
				0.26,
				0.18,
				{ g = { c3(255, 235, 120), c3(235, 165, 30) }, gr = 90, k = 0.5, r = -30 }
			), -- бант
			L(
				0.64,
				0.2,
				0.26,
				0.18,
				{ g = { c3(255, 235, 120), c3(235, 165, 30) }, gr = 90, k = 0.5, r = 30 }
			),
			L(0.5, 0.26, 0.14, 0.12, { c = c3(245, 175, 40), k = 0.4 }),
			L(0.3, 0.56, 0.06, 0.2, { c = c3(255, 190, 210), t = 0.35, k = 0.5, o = false }), -- блик
		},
	},
	Check = {
		Outline = c3(10, 60, 25),
		Layers = {
			L(0.5, 0.5, 0.86, 0.86, { g = { c3(110, 230, 100), c3(30, 150, 60) }, gr = 90, k = 0.5 }),
			L(0.38, 0.58, 0.14, 0.34, { c = c3(225, 255, 150), r = -45, k = 0.4 }),
			L(0.58, 0.48, 0.14, 0.56, { c = c3(225, 255, 150), r = 38, k = 0.4 }),
		},
	},
	-- тайная награда дня 7: тёмный силуэт питомца («???» рисует окно поверх)
	Mystery = {
		Outline = c3(5, 5, 10),
		Layers = {
			L(0.3, 0.26, 0.18, 0.26, { c = c3(22, 18, 34), r = -20, k = 0.4 }), -- уши
			L(0.7, 0.26, 0.18, 0.26, { c = c3(22, 18, 34), r = 20, k = 0.4 }),
			L(0.84, 0.7, 0.3, 0.14, { c = c3(22, 18, 34), r = -40, k = 0.5 }), -- хвост
			L(0.5, 0.66, 0.6, 0.48, { c = c3(22, 18, 34), k = 0.5 }), -- тело
			L(0.5, 0.42, 0.52, 0.44, { c = c3(22, 18, 34), k = 0.5 }), -- голова
		},
	},
} :: { [string]: Spec }

-- Ключ в Config.ASSETS для картинки (только у валют и ресурсов)
Icons.ASSET_KEYS = {
	Coin = "COIN",
	Gem = "GEM",
	Wood = "WOOD",
	Stone = "STONE",
	Ore = "ORE",
	Herb = "HERB",
	Crystal = "CRYSTAL",
	Essence = "ESSENCE",
	Fragment = "FRAGMENT",
}

function Icons.has(kind: string): boolean
	return Icons.SPECS[kind] ~= nil
end

local function frame(parent: Instance, name: string, l: Layer, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(l.X, l.Y)
	f.Size = UDim2.fromScale(l.W, l.H)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = l.c or WHITE
	f.BackgroundTransparency = l.t or 0
	f.Rotation = l.r or 0
	f.ZIndex = z
	if l.k then
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(l.k, 0)
		cr.Parent = f
	end
	if l.g then
		f.BackgroundColor3 = WHITE
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(l.g[1], l.g[2])
		g.Rotation = l.gr or 90
		g.Parent = f
	end
	f.Parent = parent
	return f
end

local function stroke(f: Instance, color: Color3, px: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = math.max(1, px)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
end

-- Нижняя половина кольца (дуга магнита): кольцо-обводка, обрезанное контейнером с ClipsDescendants.
-- l = { cx, верх дуги, внешний диаметр }: отверстие и толщина дуги — по трети диаметра.
local function arc(root: Frame, l: Layer, z: number, px: number, outline: Color3?)
	local d = l.W
	local cw, ch = d + 0.16, d / 2 + 0.1
	local clip = Instance.new("Frame")
	clip.Name = "ArcClip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(0.5, 0)
	clip.Position = UDim2.fromScale(l.X, l.Y)
	clip.Size = UDim2.fromScale(cw, ch)
	clip.ZIndex = z
	clip.Parent = root
	local function ring(name: string, hole: number, thick: number, color: Color3, zz: number)
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0)
		f.Size = UDim2.fromScale(hole / cw, hole / ch)
		f.ZIndex = zz
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.5, 0)
		cr.Parent = f
		stroke(f, color, thick)
		f.Parent = clip
	end
	local ow = 0.06
	if outline then
		ring("ArcOutline", d / 3 - 2 * ow * 0.5, px * (d / 3 + 2 * ow * 0.5), outline, z)
	end
	ring("Arc", d / 3, px * d / 3, l.c or WHITE, z + 1)
end

function Icons.make(kind: string, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local px: number = p.Px or 40
	local root = Instance.new("Frame")
	root.Name = p.Name or "Icon"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = p.Size or UDim2.fromOffset(px, px)
	root.Position = p.Position or UDim2.new()
	root.AnchorPoint = p.AnchorPoint or Vector2.zero
	if p.LayoutOrder then
		root.LayoutOrder = p.LayoutOrder
	end
	local z0: number = p.ZIndex or 1
	root.ZIndex = z0
	root:SetAttribute("IconKind", kind)
	local akey = Icons.ASSET_KEYS[kind]
	local img = akey and Assets.image(akey)
	if img then
		local il = Instance.new("ImageLabel")
		il.Name = "Image"
		il.BackgroundTransparency = 1
		il.Image = img
		il.ScaleType = Enum.ScaleType.Fit
		il.Size = UDim2.fromScale(1, 1)
		il.ZIndex = z0 + 1
		il.Parent = root
	else
		local spec = Icons.SPECS[kind]
		if not spec then
			-- неизвестный вид — нейтральный кружок (не падаем)
			spec = {
				Outline = c3(40, 40, 60),
				Layers = { L(0.5, 0.5, 0.7, 0.7, { c = c3(170, 180, 205), k = 0.5 }) },
			}
		end
		local outline = spec.Outline
		local ow = px * 0.06
		-- проход 1: общий контур (обводка всех «твёрдых» слоёв), проход 2: сами слои поверх — силуэт без внутренних швов
		if outline then
			for i, l in ipairs(spec.Layers) do
				if l.o ~= false and not l.ring and not l.arc then
					local f = frame(root, "Outline" .. i, l, z0 + 1)
					f.BackgroundColor3 = outline
					for _, ch in ipairs(f:GetChildren()) do
						if ch:IsA("UIGradient") then
							ch:Destroy()
						end
					end
					stroke(f, outline, ow)
				end
			end
		end
		for i, l in ipairs(spec.Layers) do
			local z = z0 + 1 + i -- порядок слоёв = порядок отрисовки
			if l.arc then
				arc(root, l, z, px, outline)
			elseif l.ring then
				local f = frame(root, "Ring" .. i, l, z)
				f.BackgroundTransparency = 1
				stroke(f, l.c or WHITE, px * l.ring)
			else
				frame(root, "L" .. i, l, z)
			end
		end
	end
	if p.Parent then
		root.Parent = p.Parent
	end
	return root
end

return Icons
