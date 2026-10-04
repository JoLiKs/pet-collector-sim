--!strict
-- Всплывающие сообщения игроку (серверный источник правды для текста).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

-- kind: "info" | "success" | "error" | "reward"
function Notify.send(player: Player, text: string, kind: string?)
	if player.Parent == nil then
		return
	end
	Remotes.getEvent("Notify"):FireClient(player, text, kind or "info")
end

return Notify
