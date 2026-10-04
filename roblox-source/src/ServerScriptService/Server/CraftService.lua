--!strict
-- Крафт на верстаке в хабе и применение предметов (зелья, угощения).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local RecipeData = require(Shared.RecipeData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local Stations = require(script.Parent.Stations)

local CraftService = {}

local function craft(player: Player, recipeId: any, times: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(recipeId) ~= "string" then
		return false, "Bad request"
	end
	local n = if type(times) == "number" then math.floor(times) else 1
	if n < 1 or n > 10 then
		return false, "Bad amount"
	end
	local recipe = RecipeData.ById[recipeId]
	if not recipe then
		return false, "Unknown recipe"
	end
	if not Stations.inHub(player) then
		return false, "Crafting is only possible at the Hub workbench"
	end
	if (recipe.Unlock or 0) > data.Rebirths then
		return false, "Recipe locked"
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
		return false, "Not enough coins"
	end
	Economy.trySpendResources(player, need)
	Economy.addItem(player, recipe.Item, recipe.Count * n)
	Progress.record(player, "craft", recipe.Item, n, nil)
	local item = RecipeData.Items[recipe.Item]
	Notify.send(player, ("Crafted %dx %s"):format(recipe.Count * n, item.Name), "success")
	return true, nil
end

-- Применение предмета: зелья/эликсиры. Угощения и катализатор используются через PetService.
local function use(player: Player, itemId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(itemId) ~= "string" then
		return false, "Bad request"
	end
	local item = RecipeData.Items[itemId]
	if not item then
		return false, "Unknown item"
	end
	if not Economy.hasItem(data, itemId) then
		return false, "You don't have this item"
	end
	local now = os.time()
	if item.Kind == "BoostLuck" then
		local key = if (item.Value or 2) >= 5 then "Luck5" else "Luck2"
		Economy.takeItem(player, itemId, 1)
		data.Boosts[key] = math.max(data.Boosts[key] or 0, now) + (item.Seconds or 300)
	elseif item.Kind == "BoostCoins" then
		Economy.takeItem(player, itemId, 1)
		data.Boosts.Coins2 = math.max(data.Boosts.Coins2 or 0, now) + (item.Seconds or 300)
	else
		return false, "Use this item from the Pets or Fusion screen"
	end
	Notify.send(player, item.Name .. " activated!", "reward")
	return true, nil
end

function CraftService.init()
	Router.register("Craft", 4, 4, craft)
	Router.register("UseItem", 4, 4, use)
end

return CraftService
