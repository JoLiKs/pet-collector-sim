--!strict
-- Миграции данных игрока между версиями шаблона. Чистая функция над таблицей — покрыта тестами.
local Migrations = {}

-- v1 -> v2: питомцы { Id, Gold } превращаются в { Id, Variant, Level, Xp, Evo }
function Migrations.run(data: { [string]: any }): boolean
	local changed = false
	local version = data.Version or 1
	if version < 2 then
		local pets = data.Pets
		if type(pets) == "table" then
			for _, p in pairs(pets) do
				if type(p) == "table" then
					if p.Variant == nil then
						p.Variant = if p.Gold == true then "Golden" else "Normal"
					end
					p.Gold = nil
					p.Level = p.Level or 1
					p.Xp = p.Xp or 0
					p.Evo = p.Evo or 0
				end
			end
		end
		data.Version = 2
		changed = true
	end
	-- настройки: язык "auto" | "en" | "ru" (старые сохранения получают "auto")
	if type(data.Settings) ~= "table" then
		data.Settings = { Lang = "auto" }
		changed = true
	end
	local lang = data.Settings.Lang
	if lang ~= "auto" and lang ~= "en" and lang ~= "ru" then
		data.Settings.Lang = "auto"
		changed = true
	end
	-- v2.4 (Г3): профили до обучения — ветеранам с питомцами обучение не показываем
	if type(data.Tutorial) ~= "table" then
		local veteran = (data.TotalHatched or 0) > 0
			or (type(data.Pets) == "table" and next(data.Pets) ~= nil)
		data.Tutorial = { Step = if veteran then 99 else 1, P = 0 }
		changed = true
	end
	-- защита от мусора в числовых полях (v2.4, аудит В2: ещё и ±inf, ресурсы, предметы, XP пропуска)
	local function bad(v: any): boolean
		return type(v) ~= "number" or v ~= v or v < 0 or v == math.huge
	end
	for _, key in ipairs({ "Coins", "Gems", "Rebirths", "TotalCoins" }) do
		if bad(data[key]) then
			data[key] = 0
			changed = true
		end
	end
	for _, key in ipairs({ "Resources", "Items" }) do
		local map = data[key]
		if type(map) == "table" then
			for k, v in pairs(map) do
				if bad(v) then
					map[k] = 0
					changed = true
				end
			end
		end
	end
	if type(data.BattlePass) == "table" and data.BattlePass.Xp ~= nil and bad(data.BattlePass.Xp) then
		data.BattlePass.Xp = 0
		changed = true
	end
	return changed
end

return Migrations
