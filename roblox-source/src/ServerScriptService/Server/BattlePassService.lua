--!strict
-- Батл-пасс: опыт копится от боёв, добычи, крафта и квестов. Free-награды доступны всем, Premium — владельцам геймпасса.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local BattlePassData = require(Shared.BattlePassData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local BattlePassService = {}

-- Сбрасывает прогресс при смене сезона
function BattlePassService.sync(data: DataService.Data)
	BattlePassData.syncSeason(data.BattlePass)
end

local function claim(player: Player, track: any, level: any): (boolean, any)
	local data = DataService.get(player)
	if not data or (track ~= "Free" and track ~= "Premium") or type(level) ~= "number" then
		return false, "err.bad_request"
	end
	BattlePassService.sync(data)
	level = math.floor(level)
	local bp = data.BattlePass
	local current = BattlePassData.progress(bp.Xp)
	if level < 1 or level > current then
		return false, "bp.level_not_reached"
	end
	if track == "Premium" and not Session.hasPass(player, "BATTLE_PASS") then
		return false, "bp.need_pass"
	end
	local claimed = if track == "Premium" then bp.ClaimedPremium else bp.ClaimedFree
	local key = tostring(level)
	if claimed[key] then
		return false, "err.already_claimed"
	end
	local reward = BattlePassData.reward(track, level)
	if not reward then
		return false, "bp.no_reward"
	end
	claimed[key] = true
	Economy.grant(player, reward)
	Notify.send(
		player,
		Locale.m(
			"bp.claimed",
			{ level = level, track = track, reward = Economy.describe(reward, Locale.langOf(player)) }
		),
		"reward"
	)
	State.markPets(player)
	return true, nil
end

local function claimAll(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	BattlePassService.sync(data)
	local current = BattlePassData.progress(data.BattlePass.Xp)
	local n = 0
	for lv = 1, current do
		for _, track in ipairs({ "Free", "Premium" }) do
			local claimed = if track == "Premium"
				then data.BattlePass.ClaimedPremium
				else data.BattlePass.ClaimedFree
			if not claimed[tostring(lv)] and (track == "Free" or Session.hasPass(player, "BATTLE_PASS")) then
				if claim(player, track, lv) then
					n += 1
				end
			end
		end
	end
	if n == 0 then
		return false, "err.nothing_to_claim"
	end
	return true, nil
end

function BattlePassService.init()
	Router.register("BpClaim", 6, 6, claim)
	Router.register("BpClaimAll", 1, 2, claimAll)
	Economy.onBpLevelUp = function(player: Player, level: number)
		Notify.send(player, Locale.m("bp.level_up", { level = level }), "reward")
	end
end

return BattlePassService
