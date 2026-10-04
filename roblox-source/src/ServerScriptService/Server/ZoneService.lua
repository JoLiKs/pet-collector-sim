--!strict
-- Миры: покупка доступа и телепортация. Позиция/доступ проверяются на сервере.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local ZoneData = require(Shared.ZoneData)

local AntiExploit = require(script.Parent.AntiExploit)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local ZoneService = {}

local rng = Random.new()

-- Перемещает персонажа в текущую зону игрока (вызывается при спавне и после телепорта)
function ZoneService.moveToZone(player: Player, zoneId: string)
	local character = player.Character
	if not character then
		return
	end
	local spawnCf = WorldBuilder.getZoneSpawn(zoneId)
	local offset = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-4, 4))
	AntiExploit.markTeleport(player)
	character:PivotTo(spawnCf + offset)
end

local function unlock(player: Player, zoneId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(zoneId) ~= "string" then
		return false, "Bad request"
	end
	local zone = ZoneData.ById[zoneId]
	if not zone then
		return false, "Unknown world"
	end
	if data.Zones[zoneId] then
		return false, "Already unlocked"
	end
	if data.Rebirths < zone.RequiresRebirths then
		return false, ("Requires %d rebirth(s)"):format(zone.RequiresRebirths)
	end
	if not Economy.trySpend(player, "Coins", zone.UnlockCost) then
		return false, "Not enough coins"
	end
	data.Zones[zoneId] = true
	State.markCore(player)
	Notify.send(player, zone.Name .. " unlocked!", "success")
	return true, nil
end

local function teleport(player: Player, zoneId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(zoneId) ~= "string" then
		return false, "Bad request"
	end
	if zoneId == ZoneData.HUB then
		ZoneService.moveToZone(player, ZoneData.HUB)
		State.markCore(player)
		return true, nil
	end
	local zone = ZoneData.ById[zoneId]
	if not zone or not data.Zones[zoneId] then
		return false, "World is locked"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Not now"
	end
	data.CurrentZone = zoneId
	ZoneService.moveToZone(player, zoneId)
	State.markCore(player)
	return true, nil
end

function ZoneService.init()
	Router.register("UnlockZone", 3, 3, unlock)
	Router.register("Teleport", 1.5, 2, teleport)
end

return ZoneService
