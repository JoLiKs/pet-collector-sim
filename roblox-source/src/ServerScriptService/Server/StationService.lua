--!strict
-- Станции хаба (верстак, лавка, алтарь, портал, торговец): ProximityPrompt просит клиента открыть нужную панель.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local DataService = require(script.Parent.DataService)
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

function StationService.init()
	WorldBuilder.onNpcPrompt(function(player: Player, id: string)
		local panel = PANEL_OF[id]
		if panel then
			Remotes.getEvent("OpenUi"):FireClient(player, panel)
		elseif id == "hubReturn" then
			local data = DataService.get(player)
			if data then
				ZoneService.moveToZone(player, ZoneData.HUB)
				State.markCore(player)
			end
		end
	end)
end

return StationService
