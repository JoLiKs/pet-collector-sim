--!strict
-- Всплывающие сообщения игроку (серверный источник правды для текста).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage.Shared.Locale)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

-- kind: "info" | "success" | "error" | "reward"
-- msg: Locale.m(key, args) или ключ строкой — текст локализуется на языке игрока (атрибут Lang).
function Notify.send(player: Player, msg: any, kind: string?)
	if player.Parent == nil then
		return
	end
	Remotes.getEvent("Notify"):FireClient(player, Locale.render(player, msg), kind or "info")
end

return Notify
