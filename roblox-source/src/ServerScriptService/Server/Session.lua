--!strict
-- Временное (не сохраняемое) состояние игрока на этом сервере: геймпассы, премиум, лимиты и т.п.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type PlayerSession = {
	Passes: { [string]: boolean },
	Premium: boolean,
	TradeAllowed: boolean, -- PolicyService.IsPaidItemTradingAllowed (false, пока политика не получена)
	PaidRandomRestricted: boolean, -- PolicyService: игрок не может участвовать в платных случайных механиках
	ClickTokens: number,
	LastRefill: number,
	LastHatch: number,
	ActionBuckets: { [string]: { Tokens: number, Last: number } },
	Strikes: { number },
	LastTeleport: number,
	Friends: number, -- друзья на этом сервере (+ бот-друг в демо)
	LastPosition: Vector3?,
	LastPositionTime: number,
	Ready: boolean, -- данные загружены, можно играть
}

local Session = {}

local sessions: { [Player]: PlayerSession } = {}

function Session.create(player: Player): PlayerSession
	local passes = {}
	for key in pairs(Config.GAMEPASS_IDS) do
		passes[key] = false
	end
	local s: PlayerSession = {
		Passes = passes,
		Premium = false,
		TradeAllowed = false,
		PaidRandomRestricted = true, -- пока политика не получена — считаем ограничение включённым (безопасный вариант)
		ClickTokens = Config.CLICK_BURST,
		LastRefill = os.clock(),
		LastHatch = 0,
		ActionBuckets = {},
		Strikes = {},
		LastTeleport = 0,
		Friends = 0,
		LastPosition = nil,
		LastPositionTime = 0,
		Ready = false,
	}
	sessions[player] = s
	return s
end

function Session.get(player: Player): PlayerSession?
	return sessions[player]
end

function Session.destroy(player: Player)
	sessions[player] = nil
end

function Session.hasPass(player: Player, key: string): boolean
	local s = sessions[player]
	return s ~= nil and s.Passes[key] == true
end

return Session
