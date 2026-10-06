--!strict
-- Экономика: множители, сила кликов, удача, траты и выдача наград. Единственное место, где меняются
-- Coins/Gems/Resources/Items/Pets игрока.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local BattlePassData = require(Shared.BattlePassData)
local Config = require(Shared.Config)
local EventData = require(Shared.EventData)
local Formulas = require(Shared.Formulas)
local PetMeta = require(Shared.PetMeta)
local RecipeData = require(Shared.RecipeData)
local ResourceData = require(Shared.ResourceData)
local TalentData = require(Shared.TalentData)
local ZoneData = require(Shared.ZoneData)
local DataService = require(script.Parent.DataService)
local EventState = require(script.Parent.EventState)
local Session = require(script.Parent.Session)

local Economy = {}

-- Колбэк, который PlayerService подставляет для обновления leaderstats / состояния клиента
Economy.onChanged = nil :: ((Player) -> ())?
-- Колбэк на получение опыта батл-пасса (для уведомлений); подставляет BattlePassService
Economy.onBpLevelUp = nil :: ((Player, number) -> ())?

local function changed(player: Player)
	if Economy.onChanged then
		Economy.onChanged(player)
	end
end

-- ---------------------------------------------------------------------------
-- Питомцы команды: сила и пассивные способности
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
			total += PetMeta.power(p)
		end
	end
	return total
end

-- Сумма пассивных бонусов команды по эффекту. Каждая способность считается один раз (лучший питомец).
function Economy.passive(data: DataService.Data, effect: string): number
	local best: { [string]: number } = {}
	for _, uid in ipairs(data.Equipped) do
		local p = data.Pets[uid]
		local ab = p and PetMeta.ability(p.Id)
		if p and ab and ab.Kind == "Passive" and ab.Effect == effect then
			local v = ab.Value * PetMeta.abilityScale(p.Evo)
			if v > (best[ab.Id] or 0) then
				best[ab.Id] = v
			end
		end
	end
	local total = 0
	for _, v in pairs(best) do
		total += v
	end
	return total
end

function Economy.talent(data: DataService.Data, stat: string): number
	return TalentData.bonus(data.Talents, stat)
end

function Economy.getPetSlots(player: Player, data: DataService.Data): number
	local slots = Formulas.petSlots(data.Upgrades.Slots, Economy.isVip(player))
	slots += math.floor(Economy.talent(data, "Slots"))
	return math.min(slots, Config.TEAM_SLOTS_MAX)
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

-- ---------------------------------------------------------------------------
-- Множители монет
-- ---------------------------------------------------------------------------

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

function Economy.getFriendBonus(player: Player): number
	local s = Session.get(player)
	return Formulas.friendBonus(s and s.Friends or 0)
end

-- Действует ли временный бонус «x2 монет» (эликсир или событие)
function Economy.getCoinBoost(data: DataService.Data): number
	local mult = 1
	if (data.Boosts.Coins2 or 0) > os.time() then
		mult *= 2
	end
	if EventState.isActive("GoldenRain") then
		mult *= EventData.RAIN_COIN_MULT
	end
	return mult
end

-- Полный множитель монет: пассы × таланты × пассивки × друзья × бусты
function Economy.getCoinMultiplier(player: Player, data: DataService.Data): number
	local bonus = 1
		+ Economy.talent(data, "Coins")
		+ Economy.passive(data, "Coins")
		+ Economy.getFriendBonus(player)
	return Economy.getBonusMultiplier(player) * bonus * Economy.getCoinBoost(data)
end

-- Монет за один клик в текущей зоне
function Economy.getPerClick(player: Player, data: DataService.Data): number
	local zone = ZoneData.ById[data.CurrentZone] or ZoneData.ById[ZoneData.DEFAULT]
	local base = Formulas.clickBase(data.Upgrades.Click)
	local pets = 1 + Economy.getPetPower(data)
	local rebirth = Formulas.rebirthMultiplier(data.Rebirths)
	local value = base * pets * zone.Multiplier * rebirth * Economy.getCoinMultiplier(player, data)
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
		+ Economy.talent(data, "Luck")
		+ Economy.passive(data, "Luck")
	local session = Session.get(player)
	if session and session.PaidRandomRestricted then
		-- Платные модификаторы шансов (бусты, VIP) не действуют для игроков с ограничением по PolicyService.
		-- Остаются «заработанные» источники: апгрейд, таланты, питомцы.
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
	local speed = Formulas.walkSpeed(data.Upgrades.Speed, Session.hasPass(player, "DOUBLE_SPEED"))
	speed *= 1 + Economy.talent(data, "Speed") + Economy.passive(data, "Speed")
	return math.min(speed, Config.MAX_WALKSPEED)
end

function Economy.getXpMultiplier(data: DataService.Data): number
	return 1 + Economy.talent(data, "Xp") + Economy.passive(data, "Xp")
end

function Economy.getDamageMultiplier(data: DataService.Data): number
	return 1 + Economy.talent(data, "Damage") + Economy.passive(data, "Damage")
end

function Economy.getDefense(data: DataService.Data): number
	-- доля урона, которую игрок получает (минимум 25%)
	return math.max(0.25, 1 - Economy.talent(data, "Defense") - Economy.passive(data, "Hp"))
end

function Economy.getGatherMultiplier(data: DataService.Data): number
	return 1 + Economy.talent(data, "Gather") + Economy.passive(data, "Gather")
end

function Economy.hasItem(data: DataService.Data, itemId: string, n: number?): boolean
	return (data.Items[itemId] or 0) >= (n or 1)
end

-- ---------------------------------------------------------------------------
-- Изменение валют и инвентаря (всегда через эти функции)
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

function Economy.addResource(player: Player, res: string, amount: number)
	local data = DataService.get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	data.Resources[res] = math.min((data.Resources[res] or 0) + math.floor(amount), 1e9)
	changed(player)
end

function Economy.addItem(player: Player, itemId: string, amount: number)
	local data = DataService.get(player)
	if not data or not RecipeData.Items[itemId] or amount ~= amount or amount <= 0 then
		return
	end
	data.Items[itemId] = math.min((data.Items[itemId] or 0) + math.floor(amount), 1e6)
	changed(player)
end

function Economy.takeItem(player: Player, itemId: string, amount: number): boolean
	local data = DataService.get(player)
	if not data or (data.Items[itemId] or 0) < amount then
		return false
	end
	data.Items[itemId] -= amount
	if data.Items[itemId] <= 0 then
		data.Items[itemId] = nil
	end
	changed(player)
	return true
end

-- Стоимость в ресурсах: проверка + списание атомарно
function Economy.trySpendResources(player: Player, cost: { [string]: number }): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	for res, n in pairs(cost) do
		if (data.Resources[res] or 0) < n then
			return false
		end
	end
	for res, n in pairs(cost) do
		data.Resources[res] -= n
	end
	changed(player)
	return true
end

function Economy.newPetUid(data: DataService.Data): string
	local uid = "p" .. tostring(data.NextPetId)
	data.NextPetId += 1
	return uid
end

function Economy.addPet(player: Player, petId: string, variant: string?): string?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local uid = Economy.newPetUid(data)
	data.Pets[uid] = { Id = petId, Variant = variant or "Normal", Level = 1, Xp = 0, Evo = 0 }
	changed(player)
	return uid
end

-- Опыт батл-пасса (сезонный прогресс); уровень вычисляется из накопленного опыта
function Economy.addBpXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount ~= amount or amount <= 0 then
		return
	end
	local bp = data.BattlePass
	local before = BattlePassData.progress(bp.Xp)
	bp.Xp += math.floor(amount)
	local after = BattlePassData.progress(bp.Xp)
	if after > before and Economy.onBpLevelUp then
		Economy.onBpLevelUp(player, after)
	end
	changed(player)
end

-- Выдача награды таблицей { Coins, Gems, Res, Item, ItemCount, Pet, BpXp }
function Economy.grant(player: Player, reward: { [string]: any })
	if reward.Coins then
		Economy.addCoins(player, reward.Coins, false)
	end
	if reward.Gems then
		Economy.addGems(player, reward.Gems)
	end
	if reward.Res then
		for res, n in pairs(reward.Res) do
			Economy.addResource(player, res, n)
		end
	end
	if reward.Item then
		Economy.addItem(player, reward.Item, reward.ItemCount or 1)
	end
	if reward.Pet then
		Economy.addPet(player, reward.Pet, "Normal")
	end
	if reward.BpXp then
		Economy.addBpXp(player, reward.BpXp)
	end
end

-- Короткое описание награды для уведомлений (на языке lang, по умолчанию en)
function Economy.describe(reward: { [string]: any }, lang: string?): string
	local l = lang or Locale.DEFAULT
	local parts = {}
	if reward.Coins then
		table.insert(parts, Locale.get(l, "reward.coins", { n = reward.Coins }))
	end
	if reward.Gems then
		table.insert(parts, Locale.get(l, "reward.gems", { n = reward.Gems }))
	end
	if reward.Res then
		for res, n in pairs(reward.Res) do
			local rdef = ResourceData.Resources[res]
			table.insert(parts, Locale.get(l, "reward.res", { n = n, res = rdef and rdef.Name or res }))
		end
	end
	if reward.Item then
		local it = RecipeData.Items[reward.Item]
		table.insert(
			parts,
			Locale.get(l, "reward.item", { n = reward.ItemCount or 1, item = it and it.Name or reward.Item })
		)
	end
	if reward.Pet then
		table.insert(parts, Locale.get(l, "reward.pet"))
	end
	if reward.BpXp then
		table.insert(parts, Locale.get(l, "reward.bpxp", { n = reward.BpXp }))
	end
	return table.concat(parts, ", ")
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
