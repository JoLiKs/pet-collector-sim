--!nonstrict
-- Вызов серверных действий. Любая ошибка от сервера показывается игроку тостом.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Toasts = require(script.Parent.Toasts)

local Actions = {}

-- Возвращает true при успехе. Сервер — единственный источник правды: клиент ничего не "применяет" сам.
function Actions.call(name: string, ...): boolean
	local fn = Remotes.getFunction("Action")
	local ok, result = pcall(fn.InvokeServer, fn, name, ...)
	if not ok or type(result) ~= "table" then
		Toasts.show("err.connection", "error")
		return false
	end
	if not result.ok then
		if result.msg then
			Toasts.show(tostring(result.msg), "error")
		end
		return false
	end
	return true
end

return Actions
