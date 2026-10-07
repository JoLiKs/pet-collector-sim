--!strict
-- Станции хаба (верстак, лавка, алтарь, портал, торговец): ProximityPrompt просит клиента открыть нужную панель.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local DataService = require(script.Parent.DataService)
local Notify = require(script.Parent.Notify)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)
local ZoneService = require(script.Parent.ZoneService)

local StationService = {}

local PANEL_OF = {
	craft = "Craft",
	market = "Market",
	altar = "Talents",
	tom = "Trade",
	portal = "Worlds",
}

local function onPrompt(player: Player, id: string)
	local panel = PANEL_OF[id]
	if panel then
		Remotes.getEvent("OpenUi"):FireClient(player, panel)
	elseif id == "hubReturn" then
		local session = Session.get(player)
		if session and session.IsSuper then
			-- площадка «В хаб» — тоже телепорт: суперигрок не сбегает (аудит В4)
			Notify.send(player, "super.no_teleport", "error")
			return
		end
		local data = DataService.get(player)
		if data then
			ZoneService.moveToZone(player, ZoneData.HUB)
			State.markCore(player)
		end
	end
end

StationService._onPrompt = onPrompt

function StationService.init()
	WorldBuilder.onNpcPrompt(onPrompt)
end

return StationService
