--!strict
-- Ребёрт: сброс монет и силы клика в обмен на постоянный множитель, гемы и очки талантов + дерево талантов.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Config = require(Shared.Config)
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

local function rebirth(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	if data.Rebirths >= Config.REBIRTH_MAX then
		return false, "rebirth.max"
	end
	local cost = Formulas.rebirthCost(data.Rebirths)
	if data.Coins < cost then
		return false, "err.not_enough_coins"
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
		Locale.m("rebirth.done", {
			n = data.Rebirths,
			mult = string.format("%.1f", Formulas.rebirthMultiplier(data.Rebirths)),
			gems = gems,
			tp = Formulas.talentPoints(data.Rebirths) - Formulas.talentPoints(data.Rebirths - 1),
		}),
		"reward"
	)
	return true, nil
end

local function buyTalent(player: Player, id: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(id) ~= "string" then
		return false, "err.bad_request"
	end
	if not Stations.inHub(player) then
		return false, "rebirth.visit_altar"
	end
	local ok, why = TalentData.canBuy(data.Talents, id, RebirthService.freePoints(data))
	if not ok then
		return false, why
	end
	data.Talents[id] = (data.Talents[id] or 0) + 1
	State.markCore(player)
	return true, nil
end

local function respec(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	if not Stations.inHub(player) then
		return false, "rebirth.visit_altar"
	end
	if TalentData.spent(data.Talents) == 0 then
		return false, "rebirth.nothing_reset"
	end
	if not Economy.trySpend(player, "Gems", TalentData.RESPEC_GEMS) then
		return false, Locale.m("rebirth.respec_cost", { n = TalentData.RESPEC_GEMS })
	end
	data.Talents = {}
	State.markCore(player)
	Notify.send(player, Locale.m("rebirth.respec_done"), "info")
	return true, nil
end

function RebirthService.init()
	Router.register("Rebirth", 1, 2, rebirth)
	Router.register("TalentBuy", 5, 5, buyTalent)
	Router.register("TalentReset", 1, 2, respec)
end

return RebirthService
