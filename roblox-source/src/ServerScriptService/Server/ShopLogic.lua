--!strict
-- Состояние магазина игрока: смена слота ротации и данные для клиента (без сетевой части).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopData = require(ReplicatedStorage.Shared.ShopData)

local ShopLogic = {}

-- Сбрасывает покупки при смене слота. Возвращает номер слота.
function ShopLogic.sync(data: { [string]: any }, now: number?): number
	local slot = ShopData.slotAt(now or os.time())
	if data.Shop.Slot ~= slot then
		data.Shop.Slot = slot
		data.Shop.Bought = {}
	end
	return slot
end

-- Данные магазина для клиента
function ShopLogic.view(data: { [string]: any }, now: number?): { [string]: any }
	local t = now or os.time()
	local slot = ShopLogic.sync(data, t)
	local list = {}
	for _, id in ipairs(ShopData.offers(slot, data.Rebirths)) do
		local o = ShopData.ById[id]
		table.insert(list, {
			Id = id,
			Name = o.Name,
			Desc = o.Desc,
			Currency = o.Currency,
			Price = o.Price,
			Left = o.Stock - (data.Shop.Bought[id] or 0),
			Stock = o.Stock,
		})
	end
	return { Offers = list, SecondsLeft = ShopData.secondsLeft(t) }
end

return ShopLogic
