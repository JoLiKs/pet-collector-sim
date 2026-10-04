--!strict
--[[
	TradeLogic — чистая модель окна обмена (без Roblox API), покрыта тестами.
	Сессия: { A = Side, B = Side, Status = "Open" | "Confirming" | "Done" | "Cancelled", ConfirmAt = number? }
	Side:   { Id = any, Pets = { uid... }, Coins = number, Ready = boolean, Confirmed = boolean }
	Правила:
	  * любое изменение предложения любой стороной сбрасывает Ready/Confirmed у обеих сторон;
	  * когда обе стороны Ready — начинается отсчёт подтверждения (Status = "Confirming");
	  * обмен завершается только когда обе стороны Confirmed после окончания отсчёта.
]]
local TradeLogic = {}

export type Side = { Id: any, Pets: { string }, Coins: number, Ready: boolean, Confirmed: boolean }
export type Session = { A: Side, B: Side, Status: string, ConfirmAt: number? }

function TradeLogic.new(idA: any, idB: any): Session
	return {
		A = { Id = idA, Pets = {}, Coins = 0, Ready = false, Confirmed = false },
		B = { Id = idB, Pets = {}, Coins = 0, Ready = false, Confirmed = false },
		Status = "Open",
		ConfirmAt = nil,
	}
end

local function reset(s: Session)
	s.A.Ready, s.A.Confirmed, s.B.Ready, s.B.Confirmed = false, false, false, false
	s.Status = "Open"
	s.ConfirmAt = nil
end

function TradeLogic.side(s: Session, id: any): Side?
	if s.A.Id == id then
		return s.A
	elseif s.B.Id == id then
		return s.B
	end
	return nil
end

function TradeLogic.other(s: Session, id: any): Side?
	if s.A.Id == id then
		return s.B
	elseif s.B.Id == id then
		return s.A
	end
	return nil
end

-- Установка предложения. pets — массив uid (без повторов), coins >= 0.
function TradeLogic.setOffer(
	s: Session,
	id: any,
	pets: { string },
	coins: number,
	maxPets: number
): (boolean, string?)
	if s.Status == "Done" or s.Status == "Cancelled" then
		return false, "Trade is over"
	end
	local side = TradeLogic.side(s, id)
	if not side then
		return false, "Not in this trade"
	end
	if #pets > maxPets then
		return false, "Too many pets"
	end
	local seen = {}
	for _, uid in ipairs(pets) do
		if type(uid) ~= "string" or seen[uid] then
			return false, "Bad pet list"
		end
		seen[uid] = true
	end
	if coins ~= coins or coins < 0 or coins ~= math.floor(coins) then
		return false, "Bad coin amount"
	end
	side.Pets = table.clone(pets)
	side.Coins = coins
	reset(s)
	return true, nil
end

function TradeLogic.setReady(
	s: Session,
	id: any,
	ready: boolean,
	now: number,
	confirmSeconds: number
): (boolean, string?)
	local side = TradeLogic.side(s, id)
	if not side or s.Status == "Done" or s.Status == "Cancelled" then
		return false, "Trade is over"
	end
	if s.Status == "Confirming" then
		return false, "Already confirming"
	end
	side.Ready = ready
	if s.A.Ready and s.B.Ready then
		s.Status = "Confirming"
		s.ConfirmAt = now + confirmSeconds
	end
	return true, nil
end

-- Подтверждение после отсчёта. Возвращает (ok, msg, completed)
function TradeLogic.confirm(s: Session, id: any, now: number): (boolean, string?, boolean)
	local side = TradeLogic.side(s, id)
	if not side then
		return false, "Not in this trade", false
	end
	if s.Status ~= "Confirming" then
		return false, "Both players must be ready first", false
	end
	if s.ConfirmAt and now < s.ConfirmAt then
		return false, "Wait for the countdown", false
	end
	side.Confirmed = true
	if s.A.Confirmed and s.B.Confirmed then
		s.Status = "Done"
		return true, nil, true
	end
	return true, nil, false
end

function TradeLogic.cancel(s: Session)
	if s.Status ~= "Done" then
		s.Status = "Cancelled"
	end
end

-- «Ценность» предложения для бота: сумма ценностей питомцев + монеты
function TradeLogic.offerValue(side: Side, petValue: (string) -> number): number
	local v = side.Coins
	for _, uid in ipairs(side.Pets) do
		v += petValue(uid)
	end
	return v
end

-- Решение бота: принимает, если получает не менее чем fairness от своей отдачи
function TradeLogic.botAccepts(valueGiven: number, valueReceived: number, fairness: number): boolean
	if valueReceived <= 0 then
		return false
	end
	return valueReceived >= valueGiven * fairness
end

return TradeLogic
