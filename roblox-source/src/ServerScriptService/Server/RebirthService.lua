--!strict
-- Ребёрт: сброс монет и силы клика в обмен на постоянный множитель и гемы.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Formulas = require(Shared.Formulas)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local RebirthService = {}

local function rebirth(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not loaded"
	end
	local cost = Formulas.rebirthCost(data.Rebirths)
	if data.Coins < cost then
		return false, "Not enough coins"
	end
	local gems = Formulas.rebirthGems(data.Rebirths)
	data.Coins = 0
	data.Upgrades.Click = 0
	data.Rebirths += 1
	Economy.addGems(player, gems)
	State.markCore(player)
	Notify.send(
		player,
		("Rebirth %d! Coin multiplier is now x%.1f (+%d gems)"):format(
			data.Rebirths,
			Formulas.rebirthMultiplier(data.Rebirths),
			gems
		),
		"reward"
	)
	return true, nil
end

function RebirthService.init()
	Router.register("Rebirth", 1, 2, rebirth)
end

return RebirthService
