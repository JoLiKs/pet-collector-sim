--!strict
--[[
	Monetization — геймпассы, девелоперские продукты, ProcessReceipt, Premium.

	ProcessReceipt реализован по рекомендациям Roblox:
	  * единственный обработчик (MarketplaceService.ProcessReceipt назначается только здесь);
	  * идемпотентность: PurchaseId записывается в данные игрока (Receipts) вместе с наградой;
	  * PurchaseGranted возвращается ТОЛЬКО после успешного сохранения данных с наградой;
	  * любая неопределённость (игрок вышел, данные не загрузились, сохранение не удалось,
	    продукт неизвестен) -> NotProcessedYet, Roblox повторит вызов позже.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local Monetization = {}

-- Подписчики на изменение статуса (PlayerService обновляет VIP-тег)
Monetization.onStatusChanged = {} :: { (Player) -> () }

local MAX_RECEIPTS = 300

local function fireStatusChanged(player: Player)
	for _, cb in ipairs(Monetization.onStatusChanged) do
		task.spawn(cb, player)
	end
	State.markCore(player)
end

local function ownsPass(userId: number, passId: number): boolean
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
		end)
		if ok then
			return result == true
		end
		task.wait(attempt)
	end
	return false
end

-- Политика Roblox для платных случайных предметов (яйца за Robux-валюту). yield!
-- При любой ошибке считаем игрока ограниченным — это безопасная сторона.
local function loadPolicy(player: Player): boolean
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(result) == "table" then
			return result.ArePaidRandomItemsRestricted == true
		end
		task.wait(attempt)
	end
	return true
end

-- Проверяет геймпассы, Premium и политику при входе (yield!)
function Monetization.loadPlayer(player: Player)
	local session = Session.get(player)
	if not session then
		return
	end
	session.Premium = player.MembershipType == Enum.MembershipType.Premium
	session.PaidRandomRestricted = loadPolicy(player)

	local grantAll = RunService:IsStudio() and Config.STUDIO_GRANT_ALL_PASSES
	for key, id in pairs(Config.GAMEPASS_IDS) do
		if grantAll then
			session.Passes[key] = true
		elseif id ~= 0 then
			session.Passes[key] = ownsPass(player.UserId, id)
		end
	end
end

local function grantProduct(player: Player, data: DataService.Data, def: { [string]: any })
	if def.Kind == "Gems" then
		Economy.addGems(player, def.Amount)
		Notify.send(player, ("+%d gems! Thank you!"):format(def.Amount), "reward")
	elseif def.Kind == "Coins" then
		local amount = math.max(def.Min, Economy.getPerClick(player, data) * def.Clicks)
		Economy.addCoins(player, amount, false)
		Notify.send(player, "Coins delivered! Thank you!", "reward")
	elseif def.Kind == "Luck" then
		local boosts = data.Boosts
		local base = math.max(boosts[def.Boost] or 0, os.time())
		boosts[def.Boost] = base + def.Seconds
		Notify.send(player, ("%s activated!"):format(def.Name), "reward")
	end
end

local function pruneReceipts(data: DataService.Data)
	local count = 0
	for _ in pairs(data.Receipts) do
		count += 1
	end
	if count <= MAX_RECEIPTS then
		return
	end
	local list = {}
	for key, t in pairs(data.Receipts) do
		table.insert(list, { Key = key, Time = t })
	end
	table.sort(list, function(a, b)
		return a.Time < b.Time
	end)
	for i = 1, count - MAX_RECEIPTS + 50 do
		if list[i] then
			data.Receipts[list[i].Key] = nil
		end
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitForData(player, 20)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(info.PurchaseId)
	if data.Receipts[receiptKey] then
		-- Награда уже выдана в этой или прошлой сессии. Подтверждаем только если она точно сохранена.
		if DataService.saveNow(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productKey = Config.getProductKeyById(info.ProductId)
	local def = if productKey then Config.PRODUCTS[productKey] else nil
	if not def then
		warn(
			"[Monetization] Unknown ProductId",
			info.ProductId,
			"- add it to Config.PRODUCT_IDS / Config.PRODUCTS"
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Награда и запись о чеке — без yield между ними (атомарно)
	grantProduct(player, data, def)
	data.Receipts[receiptKey] = os.time()
	pruneReceipts(data)
	State.markCore(player)

	if DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Monetization.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			local key = Config.getPassKeyById(passId)
			local session = Session.get(player)
			if not key or not session then
				return
			end
			session.Passes[key] = true
			local info = Config.GAMEPASSES[key]
			Notify.send(player, ((info and info.Name) or key) .. " unlocked! Thank you!", "reward")
			fireStatusChanged(player)
		end
	)

	Players.PlayerMembershipChanged:Connect(function(player: Player)
		local session = Session.get(player)
		if session then
			session.Premium = player.MembershipType == Enum.MembershipType.Premium
			fireStatusChanged(player)
		end
	end)
end

return Monetization
