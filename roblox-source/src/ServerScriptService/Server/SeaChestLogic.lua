--!strict
--[[
	SeaChestLogic (v3.1) — чистые правила морского сундука (покрыты тестами):
	  * pickSpot — случайная точка в кольце хаба вне «занятых» кругов (спавн, порталы, станции, яйца…)
	    и, если передана проверка isFree, без пересечения с постройками и декором;
	  * v3.2 validate — проверка места по миру через «пробы» (сервер даёт Raycast/GetPartBoundsInBox, тест — заглушки):
	    твёрдый ровный пол, свободный цилиндр без деталей, ничего сверху, не замкнутое пространство;
	  * loot — состав награды по прогрессу игрока (монеты от силы сбора, ресурсы и билет по открытым мирам).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local DailyData = require(ReplicatedStorage.Shared.DailyData)
local RecipeData = require(ReplicatedStorage.Shared.RecipeData)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local SeaChestLogic = {}

export type Blocker = { Pos: Vector3, R: number }

-- Пробы мира (v3.2). ground(pos) -> y?, normalY?, solid? — первая твёрдая/видимая поверхность под точкой;
-- blocked(base, r, h) -> есть ли деталь в цилиндре r × h над base; overhead(base) -> есть ли что-то над точкой;
-- exits(base, len) -> сколько из 8 горизонтальных направлений упирается в деталь ближе len.
export type Probe = {
	ground: (Vector3) -> (number?, number?, boolean?),
	blocked: (Vector3, number, number) -> boolean,
	overhead: (Vector3) -> boolean,
	exits: (Vector3, number) -> number,
}

-- true или false + причина: nofloor | soft | steep | level | parts | roof | enclosed
function SeaChestLogic.validate(pos: Vector3, probe: Probe): (boolean, string?)
	local cfg = Config.SEA_CHEST
	local y, ny, solid = probe.ground(pos)
	if y == nil then
		return false, "nofloor"
	end
	if not solid then
		return false, "soft"
	end
	if (ny or 0) < cfg.MIN_NORMAL_Y then
		return false, "steep"
	end
	if math.abs(y - cfg.FLOOR_Y) > cfg.FLOOR_TOL then
		return false, "level" -- на крыше, на постаменте, под кроной (луч сверху упёрся в листву)
	end
	local base = Vector3.new(pos.X, y, pos.Z)
	if probe.blocked(base, cfg.PART_CLEARANCE, cfg.CLEAR_HEIGHT) then
		return false, "parts"
	end
	if probe.overhead(base) then
		return false, "roof"
	end
	if probe.exits(base, cfg.EXIT_RAY) > cfg.MAX_BLOCKED_DIRS then
		return false, "enclosed"
	end
	return true, nil
end

function SeaChestLogic.isClear(pos: Vector3, blockers: { Blocker }, clearance: number): boolean
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local cfg = Config.SEA_CHEST
	local sp = cfg.SPAWN_POS
	if sp and (flat - Vector3.new(sp.X, 0, sp.Z)).Magnitude < (cfg.SPAWN_DISTANCE or 0) then
		return false -- не у точки появления: новички не должны спотыкаться о сундук
	end
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
