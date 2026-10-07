--!strict
-- Небольшие общие утилиты (клиент + сервер).

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

-- 1234567 -> "1.23M"
function Util.formatNumber(n: number): string
	if n ~= n then
		return "0"
	end
	if n < 1000 then
		if n == math.floor(n) then
			return tostring(math.floor(n))
		end
		return string.format("%.1f", n)
	end
	local index = 1
	local value = n
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if value >= 100 then
		text = string.format("%.0f", value)
	elseif value >= 10 then
		text = string.format("%.1f", value)
	else
		text = string.format("%.2f", value)
	end
	-- убираем лишние нули: "1.50" -> "1.5", "2.00" -> "2"
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text .. SUFFIXES[index]
end

-- 3725 -> "1:02:05", 75 -> "1:15"
function Util.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Util.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy: any = {}
	for k, v in pairs(value :: any) do
		copy[k] = Util.deepCopy(v)
	end
	return copy
end

-- Заполняет в target отсутствующие ключи значениями из template (рекурсивно). Лишние ключи не трогает.
function Util.reconcile(target: { [any]: any }, template: { [any]: any })
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = Util.deepCopy(v)
		elseif type(target[k]) == "table" and type(v) == "table" then
			Util.reconcile(target[k], v)
		end
	end
end

function Util.isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v > -math.huge and v < math.huge
end

-- v2.4 (аудит В2): целое число в диапазоне [min, max] или nil (NaN, ±inf, дроби и не-числа отсекаются)
function Util.validInt(v: any, min: number, max: number): number?
	if not Util.isFiniteNumber(v) or math.floor(v) ~= v or v < min or v > max then
		return nil
	end
	return v
end

-- v2.4 (аудит В2): все числа в аргументах remote конечны (на верхнем уровне и внутри таблиц
-- до глубины 3); заодно ограничивает размер присланных таблиц
local MAX_ARG_ENTRIES = 256
local function finiteValue(v: any, depth: number, budget: { n: number }): boolean
	local t = type(v)
	if t == "number" then
		return Util.isFiniteNumber(v)
	elseif t == "table" then
		if depth >= 3 then
			return false
		end
		for k, x in pairs(v) do
			budget.n += 1
			if budget.n > MAX_ARG_ENTRIES then
				return false
			end
			if not finiteValue(k, depth + 1, budget) or not finiteValue(x, depth + 1, budget) then
				return false
			end
		end
	end
	return true
end

function Util.argsFinite(...: any): boolean
	local budget = { n = 0 }
	for i = 1, select("#", ...) do
		if not finiteValue((select(i, ...)), 0, budget) then
			return false
		end
	end
	return true
end

return Util
