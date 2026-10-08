--!strict
-- Крафт на верстаке в хабе, применение предметов (зелья, эликсиры) и назначение быстрых слотов хотбара (v2.9).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local HotbarData = require(Shared.HotbarData)
local Locale = require(Shared.Locale)
local RecipeData = require(Shared.RecipeData)
local Util = require(Shared.Util)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)
local Stations = require(script.Parent.Stations)

local CraftService = {}

local function craft(player: Player, recipeId: any, times: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(recipeId) ~= "string" then
		return false, "err.bad_request"
	end
	local n = if times == nil then 1 else Util.validInt(times, 1, 10)
	if not n then
		return false, "err.bad_request"
	end
	local recipe = RecipeData.ById[recipeId]
	if not recipe then
		return false, "err.unknown"
	end
	if not Stations.inHub(player) then
		return false, "craft.hub_only"
	end
	if (recipe.Unlock or 0) > data.Rebirths then
		return false, "craft.locked"
	end
	local need: { [string]: number } = {}
	for res, c in pairs(recipe.Cost) do
		need[res] = c * n
	end
	local coins = (recipe.Coins or 0) * n
	local ok, why = RecipeData.canCraft(
		{ Id = recipe.Id, Item = recipe.Item, Count = recipe.Count, Cost = need, Coins = coins },
		data.Resources,
		data.Coins
	)
	if not ok then
		return false, why
	end
	if coins > 0 and not Economy.trySpend(player, "Coins", coins) then
		return false, "err.not_enough_coins"
	end
	Economy.trySpendResources(player, need)
	Economy.addItem(player, recipe.Item, recipe.Count * n)
	Progress.record(player, "craft", recipe.Item, n, nil)
	local item = RecipeData.Items[recipe.Item]
	Notify.send(player, Locale.m("craft.done", { n = recipe.Count * n, item = item.Name }), "success")
	return true, nil
end

-- Применение предмета: зелья/эликсиры. Угощения и катализатор используются через PetService.
local function use(player: Player, itemId: any): (boolean, any)
	local data = DataService.get(player)
	if not data or type(itemId) ~= "string" then
		return false, "err.bad_request"
	end
	local item = RecipeData.Items[itemId]
	if not item then
		return false, "err.unknown"
	end
	if not Economy.hasItem(data, itemId) then
		return false, "craft.no_item"
	end
	local now = os.time()
	if item.Kind == "BoostLuck" then
		local key = if (item.Value or 2) >= 5 then "Luck5" else "Luck2"
		Economy.takeItem(player, itemId, 1)
		Economy.addLuckBoost(data, key, item.Seconds or 300)
	elseif item.Kind == "BoostCoins" then
		Economy.takeItem(player, itemId, 1)
		data.Boosts.Coins2 = math.max(data.Boosts.Coins2 or 0, now) + (item.Seconds or 300)
	else
		return false, "craft.use_from_pets"
	end
	Notify.send(player, Locale.m("item.activated", { item = item.Name }), "reward")
	return true, nil
end

-- v2.9: быстрые слоты 3..5 — какой предмет лежит в слоте (id или "" — очистить).
-- Валидация в HotbarData.assign: номер слота, только предметы «одним нажатием», без повторов (перенос).
local function setHotbar(player: Player, slot: any, itemId: any): (boolean, any)
	local data = DataService.get(player)
	if not data then
		return false, "err.bad_request"
	end
	local hb, err = HotbarData.assign(data.Settings.Hotbar, slot, itemId)
	if not hb then
		return false, err
	end
	data.Settings.Hotbar = hb
	State.markCore(player)
	return true, nil
end
CraftService.setHotbar = setHotbar

function CraftService.init()
	Router.register("Craft", 4, 4, craft)
	Router.register("UseItem", 4, 4, use)
	Router.register("SetHotbar", 4, 8, setHotbar)
end

return CraftService
