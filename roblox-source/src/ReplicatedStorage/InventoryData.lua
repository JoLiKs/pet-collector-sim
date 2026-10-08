--!strict
--[[
	InventoryData (v2.6) — чистые данные для окна «Инвентарь»: что показывать, где это добыть и для чего оно нужно.
	Всё выводится из ResourceData / RecipeData / ZoneData / Config, поэтому новые рецепты и миры появляются в окне сами.
	Тексты — ключи Locale (inv.*) с аргументами; форматирует окно (InventoryPanel).
]]
local Config = require(script.Parent.Config)
local EnemyData = require(script.Parent.EnemyData)
local RecipeData = require(script.Parent.RecipeData)
local ResourceData = require(script.Parent.ResourceData)
local ZoneData = require(script.Parent.ZoneData)

local InventoryData = {}

export type Entry = { Id: string, Kind: string } -- Kind: "Res" | "Item"
export type Line = { Key: string, Zones: { string }?, Recipe: any? }

-- Как применяется предмет (по Kind из RecipeData)
InventoryData.ITEM_USE = {
	BoostLuck = "inv.use_boost_luck",
	BoostCoins = "inv.use_boost_coins",
	Heal = "inv.use_heal",
	Regen = "inv.use_regen",
	PetXp = "craft.use_pets",
	Catalyst = "craft.use_fusion",
	Tool = "craft.passive",
	Weapon = "craft.passive",
	Ticket = "craft.use_egg",
} :: { [string]: string }

function InventoryData.list(): { Entry }
	local out = {}
	for _, id in ipairs(ResourceData.Order) do
		table.insert(out, { Id = id, Kind = "Res" })
	end
	for _, id in ipairs(RecipeData.ItemOrder) do
		table.insert(out, { Id = id, Kind = "Item" })
	end
	return out
end

function InventoryData.kindOf(id: string): string?
	if ResourceData.Resources[id] then
		return "Res"
	elseif RecipeData.Items[id] then
		return "Item"
	end
	return nil
end

-- Имя (англ., переводится Locale.n) — для ресурса из ResourceData, для предмета из RecipeData
function InventoryData.name(id: string): string
	local r = ResourceData.Resources[id]
	if r then
		return r.Name
	end
	local it = RecipeData.Items[id]
	return if it then it.Name else id
end

function InventoryData.count(core: any, id: string): number
	if not core then
		return 0
	end
	if ResourceData.Resources[id] then
		return (core.Resources and core.Resources[id]) or 0
	end
	return (core.Items and core.Items[id]) or 0
end

-- Миры, где растут узлы ресурса (имена миров по порядку ZoneData)
function InventoryData.zonesFor(res: string): { string }
	local out = {}
	for _, z in ipairs(ZoneData.List) do
		for _, r in ipairs(z.Resources or {}) do
			if r == res then
				table.insert(out, z.Name)
				break
			end
		end
	end
	return out
end

function InventoryData.sources(id: string): { Line }
	local out: { Line } = {}
	if ResourceData.Resources[id] then
		local zones = InventoryData.zonesFor(id)
		if #zones > 0 then
			table.insert(out, { Key = "inv.src_nodes", Zones = zones })
			table.insert(out, { Key = "inv.src_chests" })
		end
		if id == "Essence" then
			table.insert(out, { Key = "inv.src_enemies" })
			if Config.PRODUCTS.ESSENCE_PACK then
				table.insert(out, { Key = "inv.src_shop" })
			end
		elseif id == "Fragment" then
			table.insert(out, { Key = "inv.src_bosses" })
		end
		return out
	end
	for _, r in ipairs(RecipeData.Recipes) do
		if r.Item == id then
			table.insert(out, { Key = "inv.src_craft", Recipe = r })
		end
	end
	for _, pd in ipairs(EnemyData.POTION_DROPS) do
		if pd.Item == id then
			table.insert(out, { Key = "inv.src_potion_drop" })
		end
	end
	if table.find(ResourceData.ChestItems, id) then
		table.insert(out, { Key = "inv.src_chests" })
	end
	local it = RecipeData.Items[id]
	if it and it.Kind == "Ticket" then
		table.insert(out, { Key = "inv.src_tickets" })
	end
	return out
end

function InventoryData.uses(id: string): { Line }
	local out: { Line } = {}
	if ResourceData.Resources[id] then
		for _, r in ipairs(RecipeData.Recipes) do
			if r.Cost[id] then
				table.insert(out, { Key = "inv.use_recipe", Recipe = r })
			end
		end
		if id == "Essence" then
			table.insert(out, { Key = "inv.use_evolve" })
		end
	else
		local it = RecipeData.Items[id]
		local key = it and InventoryData.ITEM_USE[it.Kind]
		if key then
			table.insert(out, { Key = key })
		end
	end
	if #out == 0 then
		table.insert(out, { Key = "inv.use_none" })
	end
	return out
end

return InventoryData
