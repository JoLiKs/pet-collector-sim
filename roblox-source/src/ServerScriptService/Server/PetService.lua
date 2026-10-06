--!strict
-- Питомцы: яйца, команда, избранное, слияние 3→1, эволюция, опыт. Шансы, цены и вместимость проверяются на сервере.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Config = require(Shared.Config)
local PetData = require(Shared.PetData)
local PetMeta = require(Shared.PetMeta)
local RecipeData = require(Shared.RecipeData)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local EventState = require(script.Parent.EventState)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local PetService = {}

local rng = Random.new()

local function isAllowedCount(n: any): boolean
	if type(n) ~= "number" then
		return false
	end
	for _, allowed in ipairs(Config.HATCH_COUNTS) do
		if allowed == n then
			return true
		end
	end
	return false
end

local function isNearEgg(player: Player, eggId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local eggPos = WorldBuilder.getEggPosition(eggId)
	if not root or not eggPos then
		return false
	end
	return (root.Position - eggPos).Magnitude <= Config.EGG_MAX_DISTANCE
end

local function isUnlocked(data: DataService.Data, zone: string): boolean
	return zone == "Hub" or data.Zones[zone] == true
end

local function rollVariant(): string
	local r = rng:NextNumber()
	if r < Config.RAINBOW_CHANCE then
		return "Rainbow"
	elseif r < Config.RAINBOW_CHANCE + Config.GOLD_CHANCE then
		return "Golden"
	end
	return "Normal"
end

-- Открытие яиц. Никаких yield между проверкой цены и выдачей — операция атомарна.
-- useTicket: потратить билет (ticket_<EggId>) вместо валюты — только для одного яйца.
local function hatch(player: Player, eggId: any, count: any, useTicket: any): (boolean, any)
	if type(eggId) ~= "string" or not isAllowedCount(count) then
		return false, "err.bad_request"
	end
	local data = DataService.get(player)
	local egg = PetData.EggsById[eggId]
	if not data or not egg then
		return false, "err.unknown"
	end
	if not isUnlocked(data, egg.Zone) then
		return false, "egg.locked_world"
	end
	if egg.Event and not EventState.isActive(egg.Event) then
		return false, Locale.m("egg.event_only", { event = egg.Event })
	end
	if not isNearEgg(player, eggId) then
		return false, "egg.closer"
	end
	local n = count :: number
	if useTicket == true and n ~= 1 then
		return false, "egg.ticket_one"
	end
	local free = Economy.getBagSize(data) - Economy.countPets(data)
	if free < n then
		return false, "egg.storage_full"
	end
	if useTicket == true then
		if not Economy.takeItem(player, "ticket_" .. eggId, 1) then
			return false, "egg.no_ticket"
		end
	else
		local price = egg.Price * n
		if not Economy.trySpend(player, egg.Currency, price) then
			return false, if egg.Currency == "Gems" then "err.not_enough_gems" else "err.not_enough_coins"
		end
	end

	local luck = Economy.getLuck(player, data)
	local results = {}
	for _ = 1, n do
		local petId = PetData.roll(egg.Id, luck, rng:NextNumber())
		if petId then
			local variant = rollVariant()
			local uid = Economy.addPet(player, petId, variant)
			data.TotalHatched += 1
			table.insert(results, { Uid = uid, Id = petId, Variant = variant, Gold = variant == "Golden" })
			if variant == "Shiny" then
				Progress.addStat(player, "Shiny", 1)
			end
		end
	end
	Progress.record(player, "hatch", eggId, #results, egg.Zone)
	State.markPets(player)
	Remotes.getEvent("HatchResult"):FireClient(player, results)
	return true, nil
end

local function isEquipped(data: DataService.Data, uid: string): number?
	for i, v in ipairs(data.Equipped) do
		if v == uid then
			return i
		end
	end
	return nil
end

local function equip(player: Player, uid: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or not data.Pets[uid] then
		return false, "err.pet_not_found"
	end
	if isEquipped(data, uid) then
		return false, "pet.already_equipped"
	end
	if #data.Equipped >= Economy.getPetSlots(player, data) then
		return false, "pet.no_slots"
	end
	table.insert(data.Equipped, uid)
	State.markPets(player)
	return true, nil
end

local function unequip(player: Player, uid: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" then
		return false, "err.bad_request"
	end
	local index = isEquipped(data, uid)
	if not index then
		return false, "pet.not_equipped"
	end
	table.remove(data.Equipped, index)
	State.markPets(player)
	return true, nil
end

local function equipBest(player: Player): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.not_loaded"
	end
	local list = {}
	for uid, p in pairs(data.Pets) do
		table.insert(list, { Uid = uid, Power = PetMeta.power(p) })
	end
	table.sort(list, function(a, b)
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return a.Uid < b.Uid
	end)
	local slots = Economy.getPetSlots(player, data)
	local equipped = {}
	for i = 1, math.min(slots, #list) do
		equipped[i] = list[i].Uid
	end
	data.Equipped = equipped
	State.markPets(player)
	return true, nil
end

local function sell(player: Player, uid: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" then
		return false, "err.bad_request"
	end
	local p = data.Pets[uid]
	if not p then
		return false, "err.pet_not_found"
	end
	if p.Fav then
		return false, "pet.unfav_first"
	end
	if isEquipped(data, uid) then
		return false, "pet.unequip_first"
	end
	data.Pets[uid] = nil
	local value = PetMeta.sellValue(p)
	Economy.addCoins(player, value, false)
	State.markPets(player)
	Notify.send(player, Locale.m("pet.sold", { n = value }), "success")
	return true, nil
end

local function setFav(player: Player, uid: any, value: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or type(value) ~= "boolean" then
		return false, "err.bad_request"
	end
	local p = data.Pets[uid]
	if not p then
		return false, "err.pet_not_found"
	end
	p.Fav = if value then true else nil
	State.markPets(player)
	return true, nil
end

-- Слияние: три одинаковых питомца (вид + вариант) -> один, возможно более высокого варианта.
-- Уровень результата — лучший из трёх (чтобы слияние не обнуляло прогресс), эволюция — максимальная.
local function fuse(player: Player, uids: any, useCatalyst: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uids) ~= "table" or #uids ~= PetMeta.FUSE_COUNT then
		return false, "fuse.choose3"
	end
	local seen = {}
	local pets = {}
	for _, uid in ipairs(uids) do
		if type(uid) ~= "string" or seen[uid] or not data.Pets[uid] then
			return false, "err.pet_not_found"
		end
		seen[uid] = true
		table.insert(pets, data.Pets[uid])
	end
	local ok, err = PetMeta.canFuse(pets)
	if not ok then
		return false, err
	end
	local bonus = 0
	if useCatalyst == true then
		if not Economy.hasItem(data, "catalyst") then
			return false, "fuse.no_catalyst"
		end
		bonus = PetMeta.CATALYST_BONUS
	end
	if Config.FUSE_COST_COINS > 0 and not Economy.trySpend(player, "Coins", Config.FUSE_COST_COINS) then
		return false, "err.not_enough_coins"
	end
	if useCatalyst == true then
		Economy.takeItem(player, "catalyst", 1)
	end

	local variant = PetMeta.variantOf(pets[1])
	local level, evo = 1, 0
	for _, p in ipairs(pets) do
		level = math.max(level, p.Level or 1)
		evo = math.max(evo, p.Evo or 0)
	end
	local result = PetMeta.fuseVariant(variant, rng:NextNumber(), rng:NextNumber(), bonus)
	for _, uid in ipairs(uids) do
		local index = isEquipped(data, uid)
		if index then
			table.remove(data.Equipped, index)
		end
		data.Pets[uid] = nil
	end
	local newUid = Economy.newPetUid(data)
	data.Pets[newUid] = { Id = pets[1].Id, Variant = result, Level = level, Xp = 0, Evo = evo }
	if result == "Shiny" then
		Progress.addStat(player, "Shiny", 1)
	end
	Progress.setMax(player, "MaxPetLevel", level)
	Progress.record(player, "fuse", pets[1].Id, 1, nil)
	State.markPets(player)
	local upgraded = result ~= variant
	Notify.send(
		player,
		if upgraded then Locale.m("fuse.success", { variant = result }) else "fuse.same",
		if upgraded then "reward" else "info"
	)
	Remotes.getEvent("HatchResult"):FireClient(
		player,
		{ { Uid = newUid, Id = pets[1].Id, Variant = result, Gold = result == "Golden", Fused = true } }
	)
	return true, nil
end

local function evolve(player: Player, uid: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or not data.Pets[uid] then
		return false, "err.pet_not_found"
	end
	local p = data.Pets[uid]
	local ok, err = PetMeta.canEvolve(p)
	if not ok then
		return false, err
	end
	local cost = PetMeta.evoCost(p.Evo or 0)
	if not cost then
		return false, "evo.cannot"
	end
	if (data.Resources.Essence or 0) < cost.Essence then
		return false, Locale.m("evo.need_essence", { n = cost.Essence })
	end
	if data.Coins < cost.Coins then
		return false, "err.not_enough_coins"
	end
	Economy.trySpend(player, "Coins", cost.Coins)
	Economy.trySpendResources(player, { Essence = cost.Essence })
	p.Evo = (p.Evo or 0) + 1
	Progress.record(player, "evolve", p.Id, 1, nil)
	State.markPets(player)
	Notify.send(
		player,
		Locale.m("evo.done", { pet = PetMeta.displayName(p, Locale.langOf(player)) }),
		"reward"
	)
	return true, nil
end

-- Опыт питомцам; обрабатывает повышение уровня. Возвращает количество повышений.
local function addPetXp(player: Player, p: PetMeta.PetState, amount: number): number
	local level, xp, gained = PetMeta.addXp(p, amount)
	p.Level, p.Xp = level, xp
	if gained > 0 then
		Progress.setMax(player, "MaxPetLevel", level)
		Progress.record(player, "level", nil, 1, nil)
		State.markPets(player)
	end
	return gained
end

-- Награда за бой: опыт делится между питомцами команды (у Fighter больше). Вызывается CombatService.
function PetService.grantXp(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or #data.Equipped == 0 then
		return
	end
	local xp = amount * Economy.getXpMultiplier(data)
	for _, uid in ipairs(data.Equipped) do
		local p = data.Pets[uid]
		if p then
			local share = if PetMeta.role(p.Id) == "Fighter" then xp else xp * 0.6
			addPetXp(player, p, share)
		end
	end
	State.markCore(player)
end

local function feed(player: Player, uid: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or not data.Pets[uid] then
		return false, "err.pet_not_found"
	end
	local p = data.Pets[uid]
	if (p.Level or 1) >= PetMeta.maxLevel(p.Evo) then
		return false, "pet.max_level"
	end
	if not Economy.takeItem(player, "xp_treat", 1) then
		return false, "pet.no_treats"
	end
	local value = RecipeData.Items.xp_treat.Value or 100
	addPetXp(player, p, value * Economy.getXpMultiplier(data))
	State.markPets(player)
	return true, nil
end

function PetService.init()
	Router.register("Hatch", 3, 3, hatch)
	Router.register("Equip", 8, 8, equip)
	Router.register("Unequip", 8, 8, unequip)
	Router.register("EquipBest", 2, 3, equipBest)
	Router.register("Sell", 8, 8, sell)
	Router.register("SetFav", 10, 10, setFav)
	Router.register("Fuse", 2, 3, fuse)
	Router.register("Evolve", 2, 3, evolve)
	Router.register("FeedPet", 6, 6, feed)

	-- Серверный ProximityPrompt у яйца -> просим клиента открыть окно яйца (шансы + кнопки)
	WorldBuilder.onEggPrompt(function(player: Player, eggId: string)
		local data = DataService.get(player)
		local egg = PetData.EggsById[eggId]
		if not data or not egg then
			return
		end
		if not isUnlocked(data, egg.Zone) then
			Notify.send(player, "egg.locked_world", "error")
			return
		end
		if egg.Event and not EventState.isActive(egg.Event) then
			Notify.send(player, "egg.lunar_only", "info")
			return
		end
		Remotes.getEvent("OpenEgg"):FireClient(player, eggId)
	end)
end

return PetService
