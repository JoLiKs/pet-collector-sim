--!strict
-- Экономика: множители, сила кликов, удача, траты. Единственное место, где меняются Coins/Gems.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local PetData = require(Shared.PetData)
local ZoneData = require(Shared.ZoneData)
local DataService = require(script.Parent.DataService)
local Session = require(script.Parent.Session)

local Economy = {}

-- Колбэк, который PlayerService подставляет для обновления leaderstats / состояния клиента
Economy.onChanged = nil :: ((Player) -> ())?

local function changed(player: Player)
	if Economy.onChanged then
		Economy.onChanged(player)
	end
end

-- ---------------------------------------------------------------------------
-- Чтение множителей
-- ---------------------------------------------------------------------------

function Economy.isVip(player: Player): boolean
	return Session.hasPass(player, "VIP")
end

function Economy.getPetPower(data: DataService.Data): number
	local total = 0
	local pets = data.Pets
	for _, uid in ipairs(data.Equipped) do
		local p = pets[uid]
		if p then
			total += PetData.getPower(p.Id, p.Gold)
		end
	end
	return total
end

function Economy.getPetSlots(player: Player, data: DataService.Data): number
	return Formulas.petSlots(data.Upgrades.Slots, Economy.isVip(player))
end

function Economy.getBagSize(data: DataService.Data): number
	return Formulas.bagSize(data.Upgrades.Bag)
end

function Economy.countPets(data: DataService.Data): number
	local n = 0
	for _ in pairs(data.Pets) do
		n += 1
	end
	return n
end

-- Множитель от геймпассов/премиума (без учёта питомцев/зоны/ребёрта)
function Economy.getBonusMultiplier(player: Player): number
	local mult = 1
	if Session.hasPass(player, "DOUBLE_COINS") then
		mult *= Config.PASS_EFFECTS.COIN_MULT_DOUBLE
	end
	if Session.hasPass(player, "VIP") then
		mult *= 1 + Config.PASS_EFFECTS.VIP_COIN_BONUS
	end
	local s = Session.get(player)
	if s and s.Premium then
		mult *= 1 + Config.PASS_EFFECTS.PREMIUM_COIN_BONUS
	end
	return mult
end

-- Монет за один клик в текущей зоне
function Economy.getPerClick(player: Player, data: DataService.Data): number
	local zone = ZoneData.ById[data.CurrentZone] or ZoneData.ById[ZoneData.DEFAULT]
	local base = Formulas.clickBase(data.Upgrades.Click)
	local pets = 1 + Economy.getPetPower(data)
	local rebirth = Formulas.rebirthMultiplier(data.Rebirths)
	local value = base * pets * zone.Multiplier * rebirth * Economy.getBonusMultiplier(player)
	return math.max(1, math.floor(math.min(value, Config.MAX_COINS)))
end

-- Множитель буста удачи, если активен (возвращает множитель и время окончания)
function Economy.getLuckBoost(data: DataService.Data): (number, number)
	local now = os.time()
	local boosts = data.Boosts
	if boosts.Luck5 > now then
		return 5, boosts.Luck5
	elseif boosts.Luck2 > now then
		return 2, boosts.Luck2
	end
	return 1, 0
end

function Economy.getLuck(player: Player, data: DataService.Data): number
	local luck = Formulas.upgradeLuck(data.Upgrades.Luck)
	local session = Session.get(player)
	if session and session.PaidRandomRestricted then
		-- Платные модификаторы шансов (бусты, VIP) не действуют для игроков с ограничением по PolicyService.
		-- Остаётся только "заработанная" удача от апгрейда.
		return luck
	end
	local boost = Economy.getLuckBoost(data)
	luck *= boost
	if Economy.isVip(player) then
		luck *= 1 + Config.PASS_EFFECTS.VIP_LUCK_BONUS
	end
	return luck
end

function Economy.getWalkSpeed(player: Player, data: DataService.Data): number
	return Formulas.walkSpeed(data.Upgrades.Speed, Session.hasPass(player, "DOUBLE_SPEED"))
end

-- ---------------------------------------------------------------------------
-- Изменение валют (всегда через эти функции)
-- ---------------------------------------------------------------------------

function Economy.addCoins(player: Player, amount: number, countTowardsTotal: boolean?)
	local data = DataService.get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.Coins = math.min(data.Coins + amount, Config.MAX_COINS)
	if countTowardsTotal ~= false then
		data.TotalCoins = math.min(data.TotalCoins + amount, Config.MAX_COINS)
	end
	changed(player)
end

function Economy.addGems(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Gems = math.min(data.Gems + math.floor(amount), Config.MAX_GEMS)
	changed(player)
end

function Economy.canAfford(data: DataService.Data, currency: string, amount: number): boolean
	if currency == "Gems" then
		return data.Gems >= amount
	end
	return data.Coins >= amount
end

-- Списывает валюту, если хватает. Не содержит yield — проверка и списание атомарны.
function Economy.trySpend(player: Player, currency: string, amount: number): boolean
	local data = DataService.get(player)
	if not data or amount ~= amount or amount < 0 then
		return false
	end
	if currency == "Gems" then
		if data.Gems < amount then
			return false
		end
		data.Gems -= amount
	elseif currency == "Coins" then
		if data.Coins < amount then
			return false
		end
		data.Coins -= amount
	else
		return false
	end
	changed(player)
	return true
end

return Economy
