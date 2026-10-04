--!strict
-- Проверки «игрок находится в хабе» (верстак, лавка, алтарь и т.д.). Радиус — Hub целиком.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local Stations = {}

function Stations.inHub(player: Player): boolean
	if Config.DISABLE_STATION_CHECK then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = Vector3.new(root.Position.X, 0, root.Position.Z)
		- Vector3.new(ZoneData.HUB_POSITION.X, 0, ZoneData.HUB_POSITION.Z)
	return d.Magnitude <= ZoneData.HUB_RADIUS
end

return Stations
