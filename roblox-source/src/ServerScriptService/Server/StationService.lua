--!strict
-- Станции хаба (v3.0: арки порталов миров portal_<Zone>; верстак, лавка, алтарь, портал, торговец; v2.5: сундук наград, мастерская, святилище, табло): ProximityPrompt просит клиента открыть нужную панель.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Locale = require(ReplicatedStorage.Shared.Locale)
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
	-- v2.5: разделы, убранные с экрана
	daily = "Daily",
	upgrades = "Upgrades",
	rebirth = "Rebirth",
	board = "Boards",
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
	elseif string.sub(id, 1, 7) == "portal_" then
		-- v3.0: арка мира в хабе: открыт — телепорт, закрыт — окно «Миры» и подсказка с требованием
		local zoneId = string.sub(id, 8)
		local zone = ZoneData.ById[zoneId]
		local data = DataService.get(player)
		if not zone or not data then
			return
		end
		if data.Zones[zoneId] then
			local ok, err = ZoneService.travel(player, zoneId)
			if not ok and type(err) == "string" then
				Notify.send(player, err, "error")
			end
		else
			Remotes.getEvent("OpenUi"):FireClient(player, "Worlds")
			Notify.send(player, Locale.m("zone.portal_locked", { zone = zone.Name }), "info")
		end
	end
end

StationService._onPrompt = onPrompt

function StationService.init()
	WorldBuilder.onNpcPrompt(onPrompt)
end

return StationService
