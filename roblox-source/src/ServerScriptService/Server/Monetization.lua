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
local Locale = require(ReplicatedStorage.Shared.Locale)
local BattlePassData = require(ReplicatedStorage.Shared.BattlePassData)
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

-- v2.7: эффекты пассов, которые живут не только в формулах, применяем сразу
-- (скорость бега — без ожидания секундной синхронизации AntiExploit и без перезахода)
local function applyPassEffects(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid and humanoid.Health > 0 then
		humanoid.WalkSpeed = Economy.getWalkSpeed(player, data)
	end
end

-- Возвращает (владеет ли, удалось ли спросить Roblox). yield!
local function ownsPass(userId: number, passId: number): (boolean, boolean)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
		end)
		if ok then
			return result == true, true
		end
		task.wait(attempt)
	end
	return false, false
end

-- v2.7: если Roblox не ответил при входе, купленный пасс не должен «пропасть» на всю сессию —
-- перепроверяем в фоне (PASS_RECHECK_DELAYS секунд после входа).
Monetization.PASS_RECHECK_DELAYS = { 15, 60, 180 }

local function recheckPasses(player: Player, keys: { string }, step: number)
	local delay = Monetization.PASS_RECHECK_DELAYS[step]
	if not delay or #keys == 0 then
		return
	end
	task.delay(delay, function()
		local session = Session.get(player)
		if not session or not player.Parent then
			return
		end
		local failed = {}
		local changed = false
		for _, key in ipairs(keys) do
			local id = Config.GAMEPASS_IDS[key]
			if id and id ~= 0 and not session.Passes[key] then
				local owned, ok = ownsPass(player.UserId, id)
				if owned then
					session.Passes[key] = true
					changed = true
				elseif not ok then
					table.insert(failed, key)
				end
			end
		end
		if changed then
			applyPassEffects(player)
			fireStatusChanged(player)
		end
		recheckPasses(player, failed, step + 1)
	end)
end

-- Политика Roblox для платных случайных предметов (яйца за Robux-валюту). yield!
-- При любой ошибке считаем игрока ограниченным — это безопасная сторона.
-- Возвращает (ограничены ли платные случайные предметы, разрешена ли торговля платными предметами).
local function loadPolicy(player: Player): (boolean, boolean)
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(result) == "table" then
			return result.ArePaidRandomItemsRestricted == true, result.IsPaidItemTradingAllowed ~= false
		end
		task.wait(attempt)
	end
	return true, false
end

-- Проверяет геймпассы, Premium и политику при входе (yield!)
function Monetization.loadPlayer(player: Player)
	local session = Session.get(player)
	if not session then
		return
	end
	session.Premium = player.MembershipType == Enum.MembershipType.Premium
	session.PaidRandomRestricted, session.TradeAllowed = loadPolicy(player)

	local grantAll = RunService:IsStudio() and Config.STUDIO_GRANT_ALL_PASSES
	local failed = {}
	for key, id in pairs(Config.GAMEPASS_IDS) do
		if grantAll then
			session.Passes[key] = true
		elseif id ~= 0 then
			local owned, ok = ownsPass(player.UserId, id)
			-- не затираем пасс, уже выданный покупкой во время загрузки
			session.Passes[key] = session.Passes[key] == true or owned
			if not ok and not owned then
				table.insert(failed, key)
			end
		end
	end
	table.sort(failed)
	recheckPasses(player, failed, 1)
end

-- Выдаёт награду продукта. Возвращает уведомление (сообщение), которое отправляется ПОСЛЕ записи чека:
-- аудит v3.2 — сбой уведомления не должен приводить к NotProcessedYet после уже выданной награды
-- (иначе повтор Roblox выдал бы её второй раз).
local function grantProduct(player: Player, data: DataService.Data, def: { [string]: any }): any
	if def.Kind == "Gems" then
		Economy.addGems(player, def.Amount)
		return Locale.m("shop.thanks_gems", { n = def.Amount })
	elseif def.Kind == "Coins" then
		local amount = math.max(def.Min, Economy.getPerClick(player, data) * def.Clicks)
		Economy.addCoins(player, amount, false)
		return "shop.thanks_coins"
	elseif def.Kind == "Luck" then
		Economy.addLuckBoost(data, def.Boost, def.Seconds)
		return Locale.m("item.activated", { item = def.Name })
	elseif def.Kind == "Res" then
		Economy.addResource(player, def.Res, def.Amount)
		return Locale.m("shop.thanks_res", { n = def.Amount, res = def.Res })
	elseif def.Kind == "BpLevels" then
		local bp = data.BattlePass
		local level = BattlePassData.progress(bp.Xp)
		local target = math.min(BattlePassData.MaxLevel, level + def.Levels)
		local xp = 0
		for lv = level + 1, target do
			xp += BattlePassData.xpForLevel(lv)
		end
		local _, into = BattlePassData.progress(bp.Xp)
		-- v2.4 (аудит В3): платёж нельзя отменить, поэтому уровни сверх максимума не «сгорают»,
		-- а компенсируются гемами (BP_SKIP_FALLBACK_GEMS за каждый недоданный уровень).
		-- Аудит v3.2: сначала гемы (простая операция), затем опыт — меньше шансов на частичную выдачу.
		local missing = def.Levels - (target - level)
		local gems = if missing > 0 then missing * Config.BP_SKIP_FALLBACK_GEMS else 0
		if gems > 0 then
			Economy.addGems(player, gems)
		end
		Economy.addBpXp(player, math.max(0, xp - into))
		if missing > 0 then
			return Locale.m("shop.bp_fallback", { n = missing, gems = gems })
		end
		return Locale.m("shop.thanks_bp", { n = def.Levels })
	end
	-- аудит v3.2: неизвестный вид продукта — ошибка (-> NotProcessedYet), а не «пустая» выдача с записанным чеком
	error("unknown product kind " .. tostring(def.Kind))
end
Monetization._grantProduct = grantProduct

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

	-- Награда и запись о чеке — без yield между ними (атомарно).
	-- v2.7: ошибка при выдаче -> NotProcessedYet (Roblox повторит), чек не записывается.
	local okGrant, note = pcall(grantProduct, player, data, def)
	if not okGrant then
		warn("[Monetization] grant failed for", productKey, note)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	data.Receipts[receiptKey] = os.time()
	pruneReceipts(data)
	-- уведомление и синхронизация — после записи чека и в pcall: их сбой не отменяет выданную награду
	pcall(State.markCore, player)
	if note ~= nil then
		local okNote, errNote = pcall(function()
			Notify.send(player, note, "reward")
		end)
		if not okNote then
			warn("[Monetization] notify failed for", productKey, errNote)
		end
	end

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
			applyPassEffects(player)
			local info = Config.GAMEPASSES[key]
			Notify.send(
				player,
				Locale.m("shop.thanks_pass", { name = (info and info.Name) or key }),
				"reward"
			)
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
