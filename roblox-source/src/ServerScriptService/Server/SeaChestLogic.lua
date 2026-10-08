--!strict
--[[
	SeaChestLogic (v3.1) — чистые правила морского сундука (покрыты тестами):
	  * pickSpot — случайная точка в кольце хаба вне «занятых» кругов (спавн, порталы, станции, яйца…)
	    и, если передана проверка isFree, без пересечения с постройками и декором;
	  * loot — состав награды по прогрессу игрока (монеты от силы сбора, ресурсы и билет по открытым мирам).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DailyData = require(ReplicatedStorage.Shared.DailyData)
local RecipeData = require(ReplicatedStorage.Shared.RecipeData)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local SeaChestLogic = {}

export type Blocker = { Pos: Vector3, R: number }

function SeaChestLogic.isClear(pos: Vector3, blockers: { Blocker }, clearance: number): boolean
	local flat = Vector3.new(pos.X, 0, pos.Z)
	for _, b in ipairs(blockers) do
		local bp = Vector3.new(b.Pos.X, 0, b.Pos.Z)
		if (flat - bp).Magnitude < b.R + clearance then
			return false
		end
	end
	return true
end

-- rng: Random; isFree(pos) — необязательная проверка мира (GetPartBoundsInBox на сервере)
function SeaChestLogic.pickSpot(
	rng: Random,
	blockers: { Blocker },
	isFree: ((Vector3) -> boolean)?,
	tries: number?
): Vector3?
	local cfg = Config.SEA_CHEST
	for _ = 1, tries or 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		-- равномерно по площади кольца, а не по радиусу (иначе сундук чаще у центра)
		local r = math.sqrt(rng:NextNumber(cfg.MIN_RADIUS ^ 2, cfg.MAX_RADIUS ^ 2))
		local pos = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if SeaChestLogic.isClear(pos, blockers, cfg.CLEARANCE) and (isFree == nil or isFree(pos)) then
			return pos
		end
	end
	return nil
end

local function zoneIndex(zones: { [string]: any }?): number
	local best = 1
	for i, z in ipairs(ZoneData.List) do
		if i == 1 or (zones and zones[z.Id]) then
			best = math.max(best, i)
		end
	end
	return best
end

-- Награда: список «порций» в формате Economy.grant ({ Coins } | { Gems } | { Res } | { Item, ItemCount }).
-- ctx = { PerClick, Zones }
function SeaChestLogic.loot(rng: Random, ctx: { [string]: any }): { { [string]: any } }
	local cfg = Config.SEA_CHEST
	local per = math.max(1, tonumber(ctx.PerClick) or 1)
	local idx = zoneIndex(ctx.Zones)
	local out: { { [string]: any } } = {}
	table.insert(out, {
		Coins = math.max(
			cfg.COIN_MIN,
			math.floor(per * rng:NextInteger(cfg.COIN_CLICKS[1], cfg.COIN_CLICKS[2]))
		),
	})
	table.insert(out, { Gems = rng:NextInteger(cfg.GEMS[1], cfg.GEMS[2]) })
	table.insert(out, { Item = cfg.POTIONS[rng:NextInteger(1, #cfg.POTIONS)], ItemCount = 1 })
	-- ресурсы: из открытых миров (у лучшего мира — свои), разные виды
	local pool, seen = {}, {}
	for i, z in ipairs(ZoneData.List) do
		if i <= idx then
			for _, res in ipairs(z.Resources) do
				if not seen[res] then
					seen[res] = true
					table.insert(pool, res)
				end
			end
		end
	end
	local res: { [string]: number } = {}
	for _ = 1, math.min(cfg.RES_KINDS, #pool) do
		local k = table.remove(pool, rng:NextInteger(1, #pool)) :: string
		res[k] = rng:NextInteger(cfg.RES_AMOUNT[1], cfg.RES_AMOUNT[2]) + idx
	end
	table.insert(out, { Res = res })
	table.insert(out, { Item = DailyData.ticketFor(ctx.Zones), ItemCount = 1 })
	if rng:NextNumber() < cfg.BONUS_CHANCE then
		local b = cfg.BONUS[rng:NextInteger(1, #cfg.BONUS)]
		if b.Item ~= "" then
			table.insert(out, { Item = b.Item, ItemCount = math.max(1, b.Count), Bonus = true })
		else
			table.insert(out, { Gems = b.Gems, Bonus = true })
		end
	end
	-- страховка: только существующие бесплатные предметы
	for i = #out, 1, -1 do
		local it = out[i].Item
		if it and not RecipeData.Items[it] then
			table.remove(out, i)
		end
	end
	return out
end

return SeaChestLogic
