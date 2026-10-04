--!strict
-- Питомцы: открытие яиц, экипировка, продажа. Шансы, цены и вместимость проверяются на сервере.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local PetData = require(Shared.PetData)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
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

local function newUid(data: DataService.Data): string
	local uid = "p" .. tostring(data.NextPetId)
	data.NextPetId += 1
	return uid
end

-- Открытие яиц. Никаких yield между проверкой цены и выдачей — операция атомарна.
local function hatch(player: Player, eggId: any, count: any): (boolean, string?)
	if type(eggId) ~= "string" or not isAllowedCount(count) then
		return false, "Bad request"
	end
	local data = DataService.get(player)
	local egg = PetData.EggsById[eggId]
	if not data or not egg then
		return false, "Unknown egg"
	end
	if not data.Zones[egg.Zone] then
		return false, "Unlock this world first"
	end
	if not isNearEgg(player, eggId) then
		return false, "Stand closer to the egg"
	end
	local n = count :: number
	local free = Economy.getBagSize(data) - Economy.countPets(data)
	if free < n then
		return false, "Not enough pet storage — sell pets or buy Bigger Bag"
	end
	local price = egg.Price * n
	if not Economy.trySpend(player, egg.Currency, price) then
		return false, if egg.Currency == "Gems" then "Not enough gems" else "Not enough coins"
	end

	local luck = Economy.getLuck(player, data)
	local results = {}
	for _ = 1, n do
		local petId = PetData.roll(egg.Id, luck, rng:NextNumber())
		if petId then
			local gold = rng:NextNumber() < Config.GOLD_CHANCE
			local uid = newUid(data)
			data.Pets[uid] = { Id = petId, Gold = gold }
			data.TotalHatched += 1
			table.insert(results, { Uid = uid, Id = petId, Gold = gold })
		end
	end
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

local function equip(player: Player, uid: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or not data.Pets[uid] then
		return false, "Pet not found"
	end
	if isEquipped(data, uid) then
		return false, "Already equipped"
	end
	if #data.Equipped >= Economy.getPetSlots(player, data) then
		return false, "No free pet slots"
	end
	table.insert(data.Equipped, uid)
	State.markPets(player)
	return true, nil
end

local function unequip(player: Player, uid: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" then
		return false, "Bad request"
	end
	local index = isEquipped(data, uid)
	if not index then
		return false, "Not equipped"
	end
	table.remove(data.Equipped, index)
	State.markPets(player)
	return true, nil
end

local function equipBest(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Not loaded"
	end
	local list = {}
	for uid, p in pairs(data.Pets) do
		table.insert(list, { Uid = uid, Power = PetData.getPower(p.Id, p.Gold) })
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

local function sell(player: Player, uid: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" then
		return false, "Bad request"
	end
	local p = data.Pets[uid]
	if not p then
		return false, "Pet not found"
	end
	if isEquipped(data, uid) then
		return false, "Unequip the pet first"
	end
	data.Pets[uid] = nil
	local value = PetData.sellValue(p.Id, p.Gold)
	Economy.addCoins(player, value, false)
	State.markPets(player)
	Notify.send(player, ("Sold for %d coins"):format(value), "success")
	return true, nil
end

function PetService.init()
	Router.register("Hatch", 3, 3, hatch)
	Router.register("Equip", 8, 8, equip)
	Router.register("Unequip", 8, 8, unequip)
	Router.register("EquipBest", 2, 3, equipBest)
	Router.register("Sell", 8, 8, sell)

	-- Серверный ProximityPrompt у яйца -> просим клиента открыть окно яйца (шансы + кнопки)
	WorldBuilder.onEggPrompt(function(player: Player, eggId: string)
		local data = DataService.get(player)
		local egg = PetData.EggsById[eggId]
		if not data or not egg then
			return
		end
		if not data.Zones[egg.Zone] then
			Notify.send(player, "Unlock this world first!", "error")
			return
		end
		Remotes.getEvent("OpenEgg"):FireClient(player, eggId)
	end)
end

return PetService
