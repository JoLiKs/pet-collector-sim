--!strict
--[[
	HotbarData (v2.9) — быстрые слоты 3, 4, 5 хотбара (слоты 1 и 2 — Меч и Магнит). Чистая логика: сервер, клиент, тесты.

	Назначение хранится на сервере: data.Settings.Hotbar = { S3 = id, S4 = id, S5 = id } ("" — пусто).
	  * В слот кладутся только предметы, которые применяются одним нажатием:
	      зелье удачи и эликсир монет (UseItem: буст на 5 минут, повтор продлевает),
	      зелье здоровья (сразу 70% здоровья) и зелье регенерации (x3 на 5 секунд, таймер на слоте) — v3.0,
	      билеты на яйца (у своего яйца — открыть сразу, иначе — окно этого яйца).
	  * Не кладутся: угощение и катализатор (их применяют к питомцу или при слиянии в окне «Питомцы»),
	    кирка и клинок (действуют постоянно), ресурсы.
	  * Один предмет — не больше чем в одном слоте: при повторном назначении он переносится.
	  * Новичкам и старым сохранениям: слот 3 — зелье удачи, слот 4 — эликсир монет, слот 5 — пустой.
]]
local RecipeData = require(script.Parent.RecipeData)

local HotbarData = {}

HotbarData.FIRST = 3
HotbarData.LAST = 5
HotbarData.DEFAULT = { S3 = "luck_potion", S4 = "coin_elixir", S5 = "" }
-- базовая длительность бустов (полоса убывания: минимум полной шкалы)
HotbarData.BASE_SPAN = 300
-- v3.0: своя шкала у коротких бустов (зелье регенерации — 5 секунд)
HotbarData.SPANS = { Luck = 300, Coins = 300, Regen = 5 } :: { [string]: number }

-- Kind предмета -> как он применяется из слота
local SLOT_KINDS =
	{ BoostLuck = "Boost", BoostCoins = "Boost", Heal = "Boost", Regen = "Boost", Ticket = "Ticket" }
-- Предметы, которые применяются в окне «Питомцы» (подсказка в инвентаре вместо кнопок слотов)
local PET_KINDS = { PetXp = true, Catalyst = true }

function HotbarData.key(slot: number): string
	return "S" .. tostring(slot)
end

function HotbarData.isSlot(slot: any): boolean
	return type(slot) == "number"
		and slot == math.floor(slot)
		and slot >= HotbarData.FIRST
		and slot <= HotbarData.LAST
end

-- "Boost" | "Ticket" | nil — можно ли положить предмет в быстрый слот
function HotbarData.useKind(id: any): string?
	if type(id) ~= "string" then
		return nil
	end
	local item = RecipeData.Items[id]
	return item and SLOT_KINDS[item.Kind] or nil
end

function HotbarData.canAssign(id: any): boolean
	return HotbarData.useKind(id) ~= nil
end

-- Применяется ли предмет к питомцу / при слиянии (окно «Питомцы»)
function HotbarData.isPetItem(id: any): boolean
	local item = type(id) == "string" and RecipeData.Items[id] or nil
	return item ~= nil and PET_KINDS[item.Kind] == true
end

-- Какой буст (с таймером) даёт предмет: "Luck" | "Coins" | "Regen" | nil (зелье здоровья — мгновенное)
function HotbarData.boostOf(id: any): string?
	local item = type(id) == "string" and RecipeData.Items[id] or nil
	if not item then
		return nil
	end
	if item.Kind == "BoostLuck" then
		return "Luck"
	elseif item.Kind == "BoostCoins" then
		return "Coins"
	elseif item.Kind == "Regen" then
		return "Regen"
	end
	return nil
end

-- Яйцо билета: ticket_MeadowEgg -> MeadowEgg
function HotbarData.ticketEgg(id: string): string?
	if HotbarData.useKind(id) ~= "Ticket" then
		return nil
	end
	return string.match(id, "^ticket_(.+)$")
end

-- Чистит таблицу назначений (старые/битые сохранения): только слоты 3..5, только допустимые id, без повторов
function HotbarData.normalize(t: any): { [string]: string }
	local out = { S3 = "", S4 = "", S5 = "" }
	if type(t) ~= "table" then
		for k, v in pairs(HotbarData.DEFAULT) do
			out[k] = v
		end
		return out
	end
	local used = {}
	for slot = HotbarData.FIRST, HotbarData.LAST do
		local k = HotbarData.key(slot)
		local id = t[k]
		if HotbarData.canAssign(id) and not used[id] then
			out[k] = id
			used[id] = true
		end
	end
	return out
end

-- Назначить предмет в слот ("" — очистить). Возвращает новую таблицу или nil, код ошибки.
-- Если предмет уже лежит в другом слоте — он переносится (старый слот становится пустым).
function HotbarData.assign(hb: any, slot: any, id: any): ({ [string]: string }?, string?)
	if not HotbarData.isSlot(slot) then
		return nil, "err.bad_request"
	end
	if id ~= "" and not HotbarData.canAssign(id) then
		return nil, "hotbar.cant_assign"
	end
	local out = HotbarData.normalize(hb)
	if id ~= "" then
		for s = HotbarData.FIRST, HotbarData.LAST do
			local k = HotbarData.key(s)
			if out[k] == id then
				out[k] = ""
			end
		end
	end
	out[HotbarData.key(slot)] = id
	return out, nil
end

-- В каком слоте лежит предмет (или nil)
function HotbarData.slotOf(hb: any, id: string): number?
	if type(hb) ~= "table" then
		return nil
	end
	for s = HotbarData.FIRST, HotbarData.LAST do
		if hb[HotbarData.key(s)] == id then
			return s
		end
	end
	return nil
end

-- Активные бусты из серверного состояния data.Boosts (unix-время окончания):
-- { Luck = { Mult, Left, Ends } | nil, Coins = { Mult, Left, Ends } | nil }.
-- Удача: действует старший буст (x5 раньше x2, x2 ждёт в очереди) — как Economy.getLuckBoost.
function HotbarData.boosts(b: any, now: number): { [string]: { Mult: number, Left: number, Ends: number } }
	local out = {}
	if type(b) ~= "table" then
		return out
	end
	local l5, l2, c2 = tonumber(b.Luck5) or 0, tonumber(b.Luck2) or 0, tonumber(b.Coins2) or 0
	if l5 > now then
		out.Luck = { Mult = 5, Left = l5 - now, Ends = l5 }
	elseif l2 > now then
		out.Luck = { Mult = 2, Left = l2 - now, Ends = l2 }
	end
	if c2 > now then
		out.Coins = { Mult = 2, Left = c2 - now, Ends = c2 }
	end
	local rg = tonumber(b.Regen) or 0
	if rg > now then
		local def = RecipeData.Items.regen_potion
		out.Regen = { Mult = def and def.Value or 3, Left = rg - now, Ends = rg }
	end
	return out
end

-- Полная шкала полосы убывания: растёт при продлении (время прибавилось), не меньше base (BASE_SPAN).
function HotbarData.span(prevSpan: number?, prevLeft: number?, left: number, base: number?): number
	local b = base or HotbarData.BASE_SPAN
	if left <= 0 then
		return b
	end
	local span = prevSpan or b
	if prevLeft == nil or left > prevLeft + 1 then
		span = math.max(b, left)
	end
	return math.max(span, left)
end

-- Раскладка полосы хотбара шириной width (дизайнерские px) в свободном промежутке [left, right] экрана W:
-- масштаб не больше base и не меньше 0.5, центр — как можно ближе к середине экрана
function HotbarData.fit(W: number, left: number, right: number, base: number, width: number): (number, number)
	local avail = math.max(1, right - left)
	local s = math.clamp(math.min(base, avail / width), 0.5, 2)
	local half = width * s / 2
	local cx = math.clamp(W / 2, left + half, math.max(left + half, right - half))
	return s, cx
end

-- «ММ:СС» (больше часа — «Ч:ММ:СС»)
function HotbarData.mmss(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	end
	return string.format("%02d:%02d", s // 60, s % 60)
end

return HotbarData
