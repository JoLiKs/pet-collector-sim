--!strict
-- Батл-пасс: опыт копится от боёв, добычи, крафта и квестов. Free-награды доступны всем, Premium — владельцам геймпасса.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

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
	local bp = data.BattlePass
	if bp.Season ~= BattlePassData.Season then
		bp.Season = BattlePassData.Season
		bp.Xp = 0
		bp.ClaimedFree = {}
		bp.ClaimedPremium = {}
	end
end

local function claim(player: Player, track: any, level: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or (track ~= "Free" and track ~= "Premium") or type(level) ~= "number" then
		return false, "Bad request"
	end
	BattlePassService.sync(data)
	level = math.floor(level)
	local bp = data.BattlePass
	local current = BattlePassData.progress(bp.Xp)
	if level < 1 or level > current then
		return false, "Level not reached yet"
	end
	if track == "Premium" and not Session.hasPass(player, "BATTLE_PASS") then
		return false, "Premium track needs the Battle Pass"
	end
	local claimed = if track == "Premium" then bp.ClaimedPremium else bp.ClaimedFree
	local key = tostring(level)
	if claimed[key] then
		return false, "Already claimed"
	end
	local reward = BattlePassData.reward(track, level)
	if not reward then
		return false, "No reward"
	end
	claimed[key] = true
	Economy.grant(player, reward)
	Notify.send(player, ("Battle Pass L%d (%s): %s"):format(level, track, Economy.describe(reward)), "reward")
	State.markPets(player)
	return true, nil
end

local function claimAll(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not loaded"
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
		return false, "Nothing to claim"
	end
	return true, nil
end

function BattlePassService.init()
	Router.register("BpClaim", 6, 6, claim)
	Router.register("BpClaimAll", 1, 2, claimAll)
	Economy.onBpLevelUp = function(player: Player, level: number)
		Notify.send(player, ("Battle Pass level %d reached!"):format(level), "reward")
	end
end

return BattlePassService
