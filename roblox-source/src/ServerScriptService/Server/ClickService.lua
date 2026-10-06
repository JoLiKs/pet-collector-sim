--!strict
-- Сбор монет (клик) и автосбор. Количество монет считает только сервер.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local Session = require(script.Parent.Session)

local ClickService = {}

-- Начисляет n кликов
function ClickService.award(player: Player, clicks: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local perClick = Economy.getPerClick(player, data)
	Economy.addCoins(player, perClick * clicks)
	data.TotalClicks += clicks
end

function ClickService.init()
	Remotes.getEvent("Click").OnServerEvent:Connect(function(player: Player)
		local s = Session.get(player)
		if not s or not s.Ready then
			return
		end
		-- Token bucket: до MAX_CLICKS_PER_SECOND в секунду, всплеск до CLICK_BURST. Лишнее молча отбрасываем.
		local now = os.clock()
		s.ClickTokens =
			math.min(Config.CLICK_BURST, s.ClickTokens + (now - s.LastRefill) * Config.MAX_CLICKS_PER_SECOND)
		s.LastRefill = now
		if s.ClickTokens < 1 then
			return
		end
		s.ClickTokens -= 1
		ClickService.award(player, 1)
	end)

	-- Автосбор (геймпасс Auto Collect)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				local data = DataService.get(player)
				if s and s.Ready and data and s.Passes.AUTO_COLLECT and data.AutoCollect then
					ClickService.award(player, Config.PASS_EFFECTS.AUTO_CLICKS_PER_SECOND)
				end
			end
		end
	end)

	Router.register("SetAutoCollect", 2, 3, function(player, value)
		local data = DataService.get(player)
		if not data or type(value) ~= "boolean" then
			return false, "err.bad_request"
		end
		if not Session.hasPass(player, "AUTO_COLLECT") then
			return false, "click.need_auto"
		end
		data.AutoCollect = value
		State.markCore(player)
		return true, nil
	end)
end

return ClickService
