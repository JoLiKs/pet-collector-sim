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
	-- защита от мусора в числовых полях
	for _, key in ipairs({ "Coins", "Gems", "Rebirths", "TotalCoins" }) do
		local v = data[key]
		if type(v) ~= "number" or v ~= v or v < 0 then
			data[key] = 0
			changed = true
		end
	end
	return changed
end

return Migrations
