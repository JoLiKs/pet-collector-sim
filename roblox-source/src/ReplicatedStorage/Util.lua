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

return Util
