--!strict
--[[
	LabelLayout (v3.2) — чистая раскладка подписей над головами и табличек мира (BillboardGui), покрыта тестами.
	Клиент (WorldLabels.client.lua) раз в ~0.1 с проецирует каждую подпись на экран и вызывает solve:
	  * дальние подписи скрыты (MaxDistance вида), ближе к пределу — плавно гаснут (alpha) и уменьшаются;
	  * размер в пикселях (не в студах): вблизи текст не растёт на пол-экрана; на маленьких экранах — меньше;
	  * перекрытия: важные подписи (своя, игроки, суперсила) ставятся первыми; подписи персонажей при наложении
	    сдвигаются вверх «стопкой» (до STACK_STEPS раз), таблички и подписи ботов — просто скрываются;
	  * подпись, задевающая HUD (хотбар, кнопки, валюты, плашки), скрывается — HUD всегда читается.
	Виды (атрибут LabelKind у BillboardGui, ставит сервер): Own (своя — вычисляется на клиенте), Player, Super,
	Npc, Egg, Zone, Sign, Bot.
]]
local LabelLayout = {}

export type Kind = string
export type Item = {
	Kind: Kind,
	X: number, -- центр подписи на экране (пиксели вьюпорта)
	Y: number,
	W: number, -- базовый размер (пиксели при масштабе 1)
	H: number,
	Dist: number, -- до камеры, студы
	OnScreen: boolean,
}
export type Rect = { X: number, Y: number, W: number, H: number }
export type Result = { Show: boolean, Scale: number, Alpha: number, Shift: number }

-- приоритет (больше — важнее) и дальность (студы) по видам
LabelLayout.KINDS = {
	Own = { Pri = 100, Max = 60, Stack = true },
	Super = { Pri = 90, Max = 160, Stack = true },
	Player = { Pri = 80, Max = 60, Stack = true },
	Npc = { Pri = 60, Max = 45, Stack = true },
	Egg = { Pri = 55, Max = 55, Stack = false },
	Zone = { Pri = 50, Max = 90, Stack = false },
	Sign = { Pri = 45, Max = 60, Stack = false },
	Bot = { Pri = 30, Max = 40, Stack = true },
} :: { [string]: { Pri: number, Max: number, Stack: boolean } }

LabelLayout.FADE_FROM = 0.7 -- доля дальности, с которой подпись гаснет
LabelLayout.FAR_SCALE = 0.7 -- масштаб у предела дальности (вблизи — 1)
LabelLayout.NEAR = 0.3 -- доля дальности, до которой масштаб 1
LabelLayout.STACK_STEPS = 2
LabelLayout.GAP = 2 -- px между подписями в стопке
LabelLayout.MIN_OVERLAP = 0.12 -- доля площади меньшей подписи: меньшее касание не считается наложением

function LabelLayout.kind(k: string?): { Pri: number, Max: number, Stack: boolean }
	return LabelLayout.KINDS[k or ""] or LabelLayout.KINDS.Sign
end

-- масштаб под экран: ПК (короткая сторона >= 720) — 1, телефон — до 0.75
function LabelLayout.viewScale(w: number, h: number): number
	return math.clamp(math.min(w, h) / 720, 0.75, 1)
end

-- масштаб по расстоянию: 1 вблизи, FAR_SCALE у предела
function LabelLayout.distScale(dist: number, maxDist: number): number
	local t = math.clamp((dist / math.max(1, maxDist) - LabelLayout.NEAR) / (1 - LabelLayout.NEAR), 0, 1)
	return 1 - (1 - LabelLayout.FAR_SCALE) * t
end

-- прозрачность (0 — видно полностью, 1 — не видно) по расстоянию
function LabelLayout.alpha(dist: number, maxDist: number): number
	local from = maxDist * LabelLayout.FADE_FROM
	if dist <= from then
		return 0
	end
	return math.clamp((dist - from) / math.max(1e-3, maxDist - from), 0, 1)
end

local function overlap(a: Rect, b: Rect): number
	local w = math.min(a.X + a.W, b.X + b.W) - math.max(a.X, b.X)
	local h = math.min(a.Y + a.H, b.Y + b.H) - math.max(a.Y, b.Y)
	if w <= 0 or h <= 0 then
		return 0
	end
	return w * h
end
LabelLayout.overlap = overlap

local function hits(r: Rect, list: { Rect }): Rect?
	for _, o in ipairs(list) do
		local a = overlap(r, o)
		if a > 0 and a >= LabelLayout.MIN_OVERLAP * math.min(r.W * r.H, o.W * o.H) then
			return o
		end
	end
	return nil
end

local function touchesHud(r: Rect, blocks: { Rect }): boolean
	for _, b in ipairs(blocks) do
		if overlap(r, b) > 0 then
			return true
		end
	end
	return false
end

-- items: подписи; blocks: прямоугольники HUD; view: { W, H } вьюпорта.
-- Возвращает результаты в том же порядке.
function LabelLayout.solve(items: { Item }, blocks: { Rect }, view: { W: number, H: number }): { Result }
	local out: { Result } = {}
	local order: { number } = {}
	local vs = LabelLayout.viewScale(view.W, view.H)
	for i, it in ipairs(items) do
		out[i] = { Show = false, Scale = 1, Alpha = 1, Shift = 0 }
		local k = LabelLayout.kind(it.Kind)
		if it.OnScreen and it.Dist <= k.Max then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a, b)
		local ka, kb = LabelLayout.kind(items[a].Kind), LabelLayout.kind(items[b].Kind)
		if ka.Pri ~= kb.Pri then
			return ka.Pri > kb.Pri
		end
		if items[a].Dist ~= items[b].Dist then
			return items[a].Dist < items[b].Dist
		end
		return a < b
	end)
	local placed: { Rect } = {}
	for _, i in ipairs(order) do
		local it = items[i]
		local k = LabelLayout.kind(it.Kind)
		local s = vs * LabelLayout.distScale(it.Dist, k.Max)
		local w, h = it.W * s, it.H * s
		local r: Rect = { X = it.X - w / 2, Y = it.Y - h / 2, W = w, H = h }
		local shift = 0
		local other = hits(r, placed)
		local steps = 0
		while other and k.Stack and steps < LabelLayout.STACK_STEPS do
			-- поднять над мешающей подписью
			local dy = (r.Y + r.H) - other.Y + LabelLayout.GAP
			shift += dy
			r = { X = r.X, Y = r.Y - dy, W = r.W, H = r.H }
			steps += 1
			other = hits(r, placed)
		end
		local res = out[i]
		res.Scale = s
		res.Alpha = LabelLayout.alpha(it.Dist, k.Max)
		res.Shift = shift
		local offScreen = r.Y + r.H < 0 or r.Y > view.H or r.X + r.W < 0 or r.X > view.W
		if other or offScreen or touchesHud(r, blocks) then
			res.Show = false
		else
			res.Show = true
			table.insert(placed, r)
		end
	end
	return out
end

return LabelLayout
