--!strict
--[[
	Knockback — безопасное отбрасывание (v2.4, аудит С3).
	Раньше удар суперигрока сдвигал цель на SLAM_KNOCKBACK студов телепортом без проверок —
	у края зоны охотника выбрасывало сквозь тонкую невидимую стену с карты.
	Теперь дистанция ограничивается рейкастом до препятствия, а точка приземления должна стоять на земле
	(иначе дистанция уменьшается вдвое, пока не найдётся опора или не станет нулевой).
]]
local Workspace = game:GetService("Workspace")

local Knockback = {}

local MARGIN = 2.5 -- не прижимать цель вплотную к стене
local GROUND_PROBE = 40 -- насколько вниз ищем опору под точкой приземления

local function cast(origin: Vector3, dir: Vector3, ignore: { Instance }): RaycastResult?
	local ok, res = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		return Workspace:Raycast(origin, dir, params)
	end)
	if not ok then
		return nil
	end
	return res
end

-- Возвращает безопасную дистанцию отбрасывания (0..dist) из точки origin по горизонтальному направлению dir.
-- ignore — модели, сквозь которые луч проходит (персонажи участников).
function Knockback.safeDistance(origin: Vector3, dir: Vector3, dist: number, ignore: { Instance }): number
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 or dist <= 0 then
		return 0
	end
	flat = flat.Unit
	local d = dist
	local hit = cast(origin, flat * (dist + MARGIN), ignore)
	if hit then
		d = math.max(0, (hit.Position - origin).Magnitude - MARGIN)
	end
	-- опора под точкой приземления
	while d > 1 do
		local landing = origin + flat * d
		local ground = cast(landing + Vector3.new(0, 3, 0), Vector3.new(0, -GROUND_PROBE, 0), ignore)
		if ground then
			return d
		end
		if not Knockback.groundCheckAvailable then
			return d
		end
		d /= 2
	end
	return 0
end

-- Вектор безопасного смещения (горизонтальный; нулевой, если двигать некуда)
function Knockback.offset(origin: Vector3, dir: Vector3, dist: number, ignore: { Instance }): Vector3
	local d = Knockback.safeDistance(origin, dir, dist, ignore)
	if d <= 0 then
		return Vector3.new(0, 0, 0)
	end
	return Vector3.new(dir.X, 0, dir.Z).Unit * d
end

-- В среде без физики (юнит-тесты) рейкаст недоступен: тогда опору не проверяем.
Knockback.groundCheckAvailable = (function()
	local ok = pcall(function()
		local params = RaycastParams.new()
		Workspace:Raycast(Vector3.new(0, 0, 0), Vector3.new(0, -1, 0), params)
	end)
	return ok
end)()

return Knockback
