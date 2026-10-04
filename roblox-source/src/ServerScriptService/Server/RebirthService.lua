--!strict
-- Ребёрт: сброс монет и силы клика в обмен на постоянный множитель, гемы и очки талантов + дерево талантов.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Formulas = require(Shared.Formulas)
local TalentData = require(Shared.TalentData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local Stations = require(script.Parent.Stations)

local RebirthService = {}

function RebirthService.freePoints(data: DataService.Data): number
	return Formulas.talentPoints(data.Rebirths) - TalentData.spent(data.Talents)
end

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
	data.Coins = math.floor(Economy.talent(data, "StartCoins"))
	data.Upgrades.Click = 0
	data.Rebirths += 1
	Economy.addGems(player, gems)
	Progress.setMax(player, "Rebirths", data.Rebirths)
	State.markCore(player)
	Notify.send(
		player,
		("Rebirth %d! Coin multiplier is now x%.1f (+%d gems, +%d talent point%s)"):format(
			data.Rebirths,
			Formulas.rebirthMultiplier(data.Rebirths),
			gems,
			Formulas.talentPoints(data.Rebirths) - Formulas.talentPoints(data.Rebirths - 1),
			if Formulas.talentPoints(data.Rebirths) - Formulas.talentPoints(data.Rebirths - 1) == 1
				then ""
				else "s"
		),
		"reward"
	)
	return true, nil
end

local function buyTalent(player: Player, id: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return false, "Bad request"
	end
	if not Stations.inHub(player) then
		return false, "Visit the Rebirth Altar in the Hub"
	end
	local ok, why = TalentData.canBuy(data.Talents, id, RebirthService.freePoints(data))
	if not ok then
		return false, why
	end
	data.Talents[id] = (data.Talents[id] or 0) + 1
	State.markCore(player)
	return true, nil
end

local function respec(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not Stations.inHub(player) then
		return false, "Visit the Rebirth Altar in the Hub"
	end
	if TalentData.spent(data.Talents) == 0 then
		return false, "Nothing to reset"
	end
	if not Economy.trySpend(player, "Gems", TalentData.RESPEC_GEMS) then
		return false, ("Respec costs %d gems"):format(TalentData.RESPEC_GEMS)
	end
	data.Talents = {}
	State.markCore(player)
	Notify.send(player, "Talents reset — spend your points anew!", "info")
	return true, nil
end

function RebirthService.init()
	Router.register("Rebirth", 1, 2, rebirth)
	Router.register("TalentBuy", 5, 5, buyTalent)
	Router.register("TalentReset", 1, 2, respec)
end

return RebirthService
