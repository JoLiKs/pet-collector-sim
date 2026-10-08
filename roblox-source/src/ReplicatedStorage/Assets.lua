--!strict
-- Картинки из Config.ASSETS: id ~= 0 -> "rbxassetid://id", иначе nil (вызывающий рисует запасной вариант из примитивов).
-- В веб-демо ID подставляет патч roblox2web.config.json, а раздел "assets" там же сопоставляет ID с PNG из assets/.
local Config = require(script.Parent.Config)

local Assets = {}

function Assets.id(key: string): number
	local v = (Config.ASSETS :: any)[key]
	return if type(v) == "number" and v > 0 then v else 0
end

function Assets.image(key: string): string?
	local id = Assets.id(key)
	return if id > 0 then "rbxassetid://" .. id else nil
end

return Assets
