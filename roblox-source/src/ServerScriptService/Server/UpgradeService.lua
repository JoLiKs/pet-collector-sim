--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Formulas = require(Shared.Formulas)
local UpgradeData = require(Shared.UpgradeData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local UpgradeService = {}

local function buy(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return false, "Bad request"
	end
	local def = UpgradeData.ById[id]
	if not def then
		return false, "Unknown upgrade"
	end
	local level = data.Upgrades[id]
	if type(level) ~= "number" then
		return false, "Unknown upgrade"
	end
	local cost = Formulas.upgradeCost(id, level)
	if not cost then
		return false, "Max level reached"
	end
	if not Economy.trySpend(player, def.Currency, cost) then
		return false, if def.Currency == "Gems" then "Not enough gems" else "Not enough coins"
	end
	data.Upgrades[id] = level + 1
	State.markCore(player)
	Notify.send(player, def.Name .. " upgraded to level " .. tostring(level + 1), "success")
	return true, nil
end

function UpgradeService.init()
	Router.register("BuyUpgrade", 6, 6, buy)
end

return UpgradeService
