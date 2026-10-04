--!strict
--[[
	Router — единая точка входа для действий клиента (RemoteFunction "Action").
	  * проверяет, что игрок готов (данные загружены);
	  * ограничивает частоту каждого действия (token bucket на игрока);
	  * ловит ошибки обработчиков (pcall), чтобы эксплойтер не мог "уронить" сервер;
	  * возвращает клиенту всегда таблицу { ok = boolean, msg = string? }.
	Обработчик: function(player, ...) -> (ok: boolean, msg: string?)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Session = require(script.Parent.Session)
local AntiExploit = require(script.Parent.AntiExploit)

export type Handler = (player: Player, ...any) -> (boolean, string?)

local Router = {}

local handlers: { [string]: { Fn: Handler, Rate: number, Burst: number } } = {}

function Router.register(name: string, ratePerSecond: number, burst: number, fn: Handler)
	assert(handlers[name] == nil, "duplicate action " .. name)
	handlers[name] = { Fn = fn, Rate = ratePerSecond, Burst = burst }
end

local function takeToken(session: Session.PlayerSession, name: string, rate: number, burst: number): boolean
	local now = os.clock()
	local bucket = session.ActionBuckets[name]
	if not bucket then
		bucket = { Tokens = burst, Last = now }
		session.ActionBuckets[name] = bucket
	end
	bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.Last) * rate)
	bucket.Last = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

function Router.init()
	local fn = Remotes.getFunction("Action")
	fn.OnServerInvoke = function(player: Player, action: any, ...)
		if type(action) ~= "string" then
			AntiExploit.strike(player, "bad action type", 3)
			return { ok = false, msg = "Bad request" }
		end
		local entry = handlers[action]
		if not entry then
			AntiExploit.strike(player, "unknown action", 3)
			return { ok = false, msg = "Unknown action" }
		end
		local session = Session.get(player)
		if not session or not session.Ready then
			return { ok = false, msg = "Still loading..." }
		end
		if not takeToken(session, action, entry.Rate, entry.Burst) then
			AntiExploit.strike(player, "rate limit " .. action, 1)
			return { ok = false, msg = "Slow down!" }
		end
		local ok, success, msg = pcall(entry.Fn, player, ...)
		if not ok then
			warn("[Router] handler error in", action, success)
			return { ok = false, msg = "Server error" }
		end
		return { ok = success == true, msg = msg }
	end
end

return Router
