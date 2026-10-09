--!strict
--[[
	События по расписанию.
	EventState передаёт «возраст сервера» (секунды с init) — Offset = задержка до первого запуска после старта сессии.
	Событие активно, если t ∈ [slotStart, slotStart + Duration), где slotStart = Offset + k * Period.
]]
local EventData = {}

export type Event = {
	Id: string,
	Name: string,
	Period: number,
	Duration: number,
	Offset: number,
	Color: Color3,
	Desc: string,
}

EventData.List = {
	{
		Id = "GoldenRain",
		Name = "Coin Rain",
		Period = 480,
		Duration = 60,
		Offset = 180, -- первое появление ~3 мин после старта сервера
		Color = Color3.fromRGB(255, 208, 70),
		Desc = "Golden coins fall over the hub — grab them! Coins x2 everywhere.",
	},
	{
		Id = "LunarNight",
		Name = "Lunar Night",
		Period = 900,
		Duration = 150,
		Offset = 420, -- ~7 мин
		Color = Color3.fromRGB(150, 160, 255),
		Desc = "The moon rises. Rare Moonlings roam the worlds and the Lunar Egg is on sale.",
	},
	{
		Id = "BossRaid",
		Name = "Stone Colossus",
		Period = 600,
		Duration = 180,
		Offset = 300, -- ~5 мин
		Color = Color3.fromRGB(235, 100, 80),
		Desc = "A giant awakens in the hub! Defeat it together before time runs out.",
	},
} :: { Event }

EventData.ById = {} :: { [string]: Event }
for _, e in ipairs(EventData.List) do
	EventData.ById[e.Id] = e
end

-- Состояние события: (active, secondsLeft или secondsUntilStart, slotIndex)
function EventData.status(id: string, now: number): (boolean, number, number)
	local e = EventData.ById[id]
	if not e then
		return false, 0, 0
	end
	local t = now - e.Offset
	if t < 0 then
		return false, -t, 0
	end
	local slot = t // e.Period
	local start = slot * e.Period
	local into = t - start
	if into < e.Duration then
		return true, e.Duration - into, slot
	end
	return false, e.Period - into, slot + 1
end

-- Какое событие активно сейчас (id -> секунд осталось)
function EventData.activeAt(now: number): { [string]: number }
	local out = {}
	for _, e in ipairs(EventData.List) do
		local active, left = EventData.status(e.Id, now)
		if active then
			out[e.Id] = left
		end
	end
	return out
end

EventData.RAIN_COIN_VALUE = 25 -- множитель к «клику» зоны за каждую золотую монету
EventData.RAIN_COIN_MULT = 2
EventData.RAIN_DROP_INTERVAL = 0.45
EventData.LUNAR_ENEMIES_PER_ZONE = 2
EventData.RAID_REWARD = { Gems = 40, Coins = 25000, Essence = 15, BpXp = 150 }
EventData.RAID_MIN_SHARE = 0.02 -- минимальная доля урона для награды

return EventData
