--!strict
--[[
	Prices (v2.7) — цены геймпассов и продуктов для магазина (клиент).
	Источник правды — MarketplaceService:GetProductInfo (цена, выставленная в Creator Hub).
	Пока ответа нет, при ошибке или если Roblox вернул 0/nil (товар снят с продажи, эмулятор) —
	показываем SuggestedPrice из Config. Успешные ответы кэшируются на сессию, одновременные
	запросы одного товара объединяются (магазин и окно пропуска не дёргают API дважды).
]]
local Prices = {}

-- Подменяется в тестах; в игре — MarketplaceService
Prices.market = nil :: any
Prices.ATTEMPTS = 2

local cache: { [string]: number } = {}
local waiting: { [string]: { (number) -> () } } = {}

-- Цена из ответа GetProductInfo или фолбэк
function Prices.pick(info: any, fallback: number): number
	if type(info) == "table" then
		local p = info.PriceInRobux
		if type(p) == "number" and p == p and p > 0 and p < 1e7 then
			return math.floor(p)
		end
	end
	return fallback
end

function Prices.format(price: number): string
	return "R$ " .. tostring(price)
end

function Prices.cached(id: number, kind: string): number?
	return cache[kind .. ":" .. tostring(id)]
end

function Prices.clear()
	table.clear(cache)
	table.clear(waiting)
end

-- kind: "GamePass" | "Product". apply вызывается сразу (кэш или фолбэк) и ещё раз, когда придёт
-- реальная цена. Для id == 0 (товар не настроен) ничего не делает.
function Prices.get(id: number, kind: string, fallback: number, apply: (number) -> ())
	if type(id) ~= "number" or id == 0 then
		return
	end
	local key = kind .. ":" .. tostring(id)
	local hit = cache[key]
	if hit then
		apply(hit)
		return
	end
	apply(fallback)
	local pending = waiting[key]
	if pending then
		table.insert(pending, apply)
		return
	end
	local list: { (number) -> () } = { apply }
	waiting[key] = list
	task.spawn(function()
		local market = Prices.market or game:GetService("MarketplaceService")
		local infoType = if kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local price = fallback
		for attempt = 1, Prices.ATTEMPTS do
			local ok, info = pcall(function()
				return market:GetProductInfo(id, infoType)
			end)
			if ok then
				local real = Prices.pick(info, -1)
				if real > 0 then
					cache[key] = real
					price = real
				end
				break
			end
			if attempt < Prices.ATTEMPTS then
				task.wait(2)
			end
		end
		if waiting[key] == list then
			waiting[key] = nil
		end
		for _, cb in ipairs(list) do
			task.spawn(cb, price)
		end
	end)
end

return Prices
