--!strict
--[[
	Badges — значки Roblox (BadgeService). ID в Config.BADGES; 0 = значок выключен (BadgeService не трогаем).
	award(player, key) не блокирует вызывающего (task.spawn), ошибки сети гасятся pcall, повторно в той же сессии не выдаёт.
	Где выдаются: WELCOME — вход (PlayerService), FIRST_BOSS — первый босс (CombatService),
	FIRST_REBIRTH — перерождение (RebirthService), SUPERPOWER — получил суперсилу (SuperpowerService).
]]
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Badges = {}

local given: { [Player]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

function Badges.id(key: string): number
	local v = (Config.BADGES :: any)[key]
	return if type(v) == "number" and v > 0 then v else 0
end

-- Синхронная выдача (для тестов); возвращает true, если значок выдан сейчас или уже был
function Badges.awardNow(player: Player, key: string): boolean
	local id = Badges.id(key)
	if id == 0 or player.UserId <= 0 then
		return false
	end
	local mine = given[player]
	if not mine then
		mine = {}
		given[player] = mine
	end
	if mine[key] then
		return true
	end
	mine[key] = true
	local BadgeService = game:GetService("BadgeService")
	local okHas, has = pcall(function()
		return BadgeService:UserHasBadgeAsync(player.UserId, id)
	end)
	if okHas and has then
		return true
	end
	local ok, res = pcall(function()
		return BadgeService:AwardBadge(player.UserId, id)
	end)
	if not ok or res == false then
		mine[key] = nil -- попробуем ещё раз при следующем событии
		warn(("[Badges] %s (%d): %s"):format(key, id, tostring(res)))
		return false
	end
	return true
end

function Badges.award(player: Player, key: string)
	if Badges.id(key) == 0 then
		return
	end
	task.spawn(Badges.awardNow, player, key)
end

return Badges
