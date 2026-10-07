--!strict
--[[
	Router — единая точка входа для действий клиента (RemoteFunction "Action").
	  * проверяет, что игрок готов (данные загружены);
	  * отсекает NaN/±inf в аргументах (Util.argsFinite, v2.4);
	  * ограничивает частоту каждого действия (token bucket на игрока);
	  * ловит ошибки обработчиков (pcall), чтобы эксплойтер не мог "уронить" сервер;
	  * возвращает клиенту всегда таблицу { ok = boolean, msg = string? }; msg уже переведён на язык игрока.
	Обработчик: function(player, ...) -> (ok: boolean, msg: (ключ | Locale.m(...))?)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage.Shared.Locale)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)

local Session = require(script.Parent.Session)
local AntiExploit = require(script.Parent.AntiExploit)

export type Handler = (player: Player, ...any) -> (boolean, any)

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
			return { ok = false, msg = Locale.tp(player, "err.bad_request") }
		end
		local entry = handlers[action]
		if not entry then
			AntiExploit.strike(player, "unknown action", 3)
			return { ok = false, msg = Locale.tp(player, "err.unknown_action") }
		end
		-- v2.4 (аудит В2): общий фильтр числовых аргументов — NaN/±inf (и слишком большие таблицы)
		-- не доходят ни до одного обработчика
		if not Util.argsFinite(...) then
			AntiExploit.strike(player, "non-finite argument " .. action, 3)
			return { ok = false, msg = Locale.tp(player, "err.bad_request") }
		end
		local session = Session.get(player)
		if not session or not session.Ready then
			return { ok = false, msg = Locale.tp(player, "err.loading") }
		end
		if not takeToken(session, action, entry.Rate, entry.Burst) then
			AntiExploit.strike(player, "rate limit " .. action, 1)
			return { ok = false, msg = Locale.tp(player, "err.slow_down") }
		end
		local ok, success, msg = pcall(entry.Fn, player, ...)
		if not ok then
			warn("[Router] handler error in", action, success)
			return { ok = false, msg = Locale.tp(player, "err.server") }
		end
		return { ok = success == true, msg = Locale.render(player, msg) }
	end
end

return Router
