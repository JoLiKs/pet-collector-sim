--!strict
-- Магазин с ротацией: предложения меняются каждые ShopData.ROTATION_SECONDS, у каждого — лимит покупок на игрока.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local ShopData = require(Shared.ShopData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Router = require(script.Parent.Router)
local ShopLogic = require(script.Parent.ShopLogic)
local State = require(script.Parent.State)
local Stations = require(script.Parent.Stations)

local ShopService = {}

local function buy(player: Player, offerId: any): (boolean, string?)
	local data = DataService.get(player)
	if not data or type(offerId) ~= "string" then
		return false, "Bad request"
	end
	if not Stations.inHub(player) then
		return false, "The market stall is in the Hub"
	end
	local slot = ShopLogic.sync(data)
	local allowed = false
	for _, id in ipairs(ShopData.offers(slot, data.Rebirths)) do
		if id == offerId then
			allowed = true
		end
	end
	local offer = ShopData.ById[offerId]
	if not allowed or not offer then
		return false, "This offer is no longer available"
	end
	if (data.Shop.Bought[offerId] or 0) >= offer.Stock then
		return false, "Sold out until the next rotation"
	end
	if not Economy.trySpend(player, offer.Currency, offer.Price) then
		return false, if offer.Currency == "Gems" then "Not enough gems" else "Not enough coins"
	end
	data.Shop.Bought[offerId] = (data.Shop.Bought[offerId] or 0) + 1
	Economy.grant(player, offer.Give)
	State.markCore(player)
	Notify.send(player, "Purchased: " .. offer.Name, "success")
	return true, nil
end

function ShopService.init()
	Router.register("ShopBuy", 4, 4, buy)
end

return ShopService
