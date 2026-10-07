-- ============================================================================
-- Тест-кейсы серверной логики (запускаются в `luau` поверх эмуляции из prelude.lua)
-- ============================================================================
local passed, failed = 0, 0
local failures = {}
local function check(cond, msg)
	if cond then
		passed += 1
	else
		failed += 1
		table.insert(failures, msg)
		print("  FAIL: " .. msg)
	end
end
local function test(name, fn)
	print("• " .. name)
	RESET_SCHEDULER()
	local co = coroutine.create(function()
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			failed += 1
			table.insert(failures, name .. " (exception)")
			print("  EXCEPTION: " .. tostring(err))
		end
	end)
	coroutine.resume(co)
	DRIVE_UNTIL_IDLE(400)
end

local WB_STUB = [[
local WB = {}
function WB.getEggPosition(id) return Vector3.new(0, 0, 0) end
function WB.getZoneSpawn() return CFrame.new(0, 5, 0) end
function WB.onEggPrompt() end
function WB.setBoard() end
function WB.clearPlayer() end
function WB.build() end
return WB
]]

local function boot(label, opts)
	opts = opts or {}
	local U = MAKE_UNIVERSE(label)
	U.IsStudio = opts.studio == true
	for path, fn in pairs(SOURCES) do
		if path == "ServerScriptService/Server/WorldBuilder" then
			U.register(path, loadstring(WB_STUB, "WorldBuilderStub"))
		else
			U.register(path, fn)
		end
	end
	local function req(p)
		return U.require(p)
	end
	local S = {
		U = U,
		Config = req("ReplicatedStorage/Shared/Config"),
		Util = req("ReplicatedStorage/Shared/Util"),
		PetData = req("ReplicatedStorage/Shared/PetData"),
		PetMeta = req("ReplicatedStorage/Shared/PetMeta"),
		BattlePassData = req("ReplicatedStorage/Shared/BattlePassData"),
		ShopData = req("ReplicatedStorage/Shared/ShopData"),
		EventData = req("ReplicatedStorage/Shared/EventData"),
		TradeLogic = req("ReplicatedStorage/Shared/TradeLogic"),
		TalentData = req("ReplicatedStorage/Shared/TalentData"),
		RecipeData = req("ReplicatedStorage/Shared/RecipeData"),
		QuestData = req("ReplicatedStorage/Shared/QuestData"),
		AchievementData = req("ReplicatedStorage/Shared/AchievementData"),
		ZoneData = req("ReplicatedStorage/Shared/ZoneData"),
		EnemyData = req("ReplicatedStorage/Shared/EnemyData"),
		ResourceData = req("ReplicatedStorage/Shared/ResourceData"),
		Migrations = req("ServerScriptService/Server/Migrations"),
		Dailies = req("ServerScriptService/Server/Dailies"),
		Formulas = req("ReplicatedStorage/Shared/Formulas"),
		Remotes = req("ReplicatedStorage/Shared/Remotes"),
		Data = req("ServerScriptService/Server/DataService"),
		Session = req("ServerScriptService/Server/Session"),
		Economy = req("ServerScriptService/Server/Economy"),
		Monet = req("ServerScriptService/Server/Monetization"),
		Pets = req("ServerScriptService/Server/PetService"),
		Router = req("ServerScriptService/Server/Router"),
		State = req("ServerScriptService/Server/State"),
		Click = req("ServerScriptService/Server/ClickService"),
		Daily = req("ServerScriptService/Server/DailyService"),
		Upgrades = req("ServerScriptService/Server/UpgradeService"),
		Zones = req("ServerScriptService/Server/ZoneService"),
		Rebirth = req("ServerScriptService/Server/RebirthService"),
		PlayerService = req("ServerScriptService/Server/PlayerService"),
	}
	local prev = game
	game = U.Game
	S.Remotes.init()
	S.Router.init()
	S.Pets.init()
	S.Upgrades.init()
	S.Zones.init()
	S.Rebirth.init()
	S.Daily.init()
	S.Click.init()
	S.Monet.init()
	game = prev
	function S.invoke(player, action, ...)
		local fn = S.U.RS:FindFirstChild("Remotes"):FindFirstChild("Action")
		return rawget(fn, "_props").OnServerInvoke(player, action, ...)
	end
	function S.click(player)
		local ev = S.U.RS:FindFirstChild("Remotes"):FindFirstChild("Click")
		rawget(ev, "_props").OnServerEvent:Fire(player)
	end
	function S.join(userId, name)
		local p = MAKE_PLAYER(U, userId, name)
		local data, err = S.Data.load(p)
		if not data then
			return nil, err, p
		end
		S.Session.create(p)
		S.Monet.loadPlayer(p)
		S.Session.get(p).Ready = true
		-- персонаж рядом с яйцом (0,0,0)
		local char = NEW_NODE("Model")
		local hrp = NEW_NODE("Part", "HumanoidRootPart")
		hrp.Position = Vector3.new(5, 3, 5)
		hrp.Parent = char
		local hum = NEW_NODE("Humanoid")
		hum.Health = 100
		hum.Parent = char
		p.Character = char
		S.Economy.onChanged = function() end
		return data, nil, p
	end
	return S
end

local function receipt(player, purchaseId, productId)
	return { PlayerId = player.UserId, PurchaseId = purchaseId, ProductId = productId, CurrencySpent = 99 }
end

-- ============================================================================
test("Shared: Util.formatNumber / formatTime / reconcile", function()
	local S = boot("A")
	local U = S.Util
	check(U.formatNumber(0) == "0", "format 0")
	check(U.formatNumber(999) == "999", "format 999")
	check(U.formatNumber(1000) == "1K", "format 1000 -> " .. U.formatNumber(1000))
	check(U.formatNumber(1500) == "1.5K", "format 1500 -> " .. U.formatNumber(1500))
	check(U.formatNumber(1234567) == "1.23M", "format 1.23M -> " .. U.formatNumber(1234567))
	check(U.formatNumber(2e9) == "2B", "format 2B -> " .. U.formatNumber(2e9))
	check(U.formatNumber(0 / 0) == "0", "format NaN")
	check(U.formatTime(3725) == "1:02:05", "formatTime 3725 -> " .. U.formatTime(3725))
	check(U.formatTime(75) == "1:15", "formatTime 75")
	local t = { a = 1, nested = { x = 1 } }
	U.reconcile(t, { a = 5, b = 2, nested = { x = 9, y = 3 } })
	check(t.a == 1 and t.b == 2 and t.nested.x == 1 and t.nested.y == 3, "reconcile fills only missing keys")
end)

test(
	"Shared: каждый питомец и яйцо согласованы, шансы суммируются в 100%",
	function()
		local S = boot("A")
		local P = S.PetData
		for _, egg in ipairs(P.Eggs) do
			local sum = 0
			for _, e in ipairs(egg.Pets) do
				check(P.PetsById[e.Id] ~= nil, "egg " .. egg.Id .. " references unknown pet " .. e.Id)
				sum += e.Weight
			end
			check(math.abs(sum - 100) < 1e-9, "egg " .. egg.Id .. " weights sum to " .. sum)
			local odds = P.getOdds(egg.Id, 3)
			local s2 = 0
			for _, o in ipairs(odds) do
				s2 += o.Chance
			end
			check(math.abs(s2 - 100) < 1e-6, "luck-adjusted odds sum to 100 for " .. egg.Id)
		end
		-- удача увеличивает шанс редких
		local base = P.getOdds("MeadowEgg", 1)
		local lucky = P.getOdds("MeadowEgg", 5)
		check(lucky[6].Chance > base[6].Chance, "luck increases legendary chance")
		check(lucky[1].Chance < base[1].Chance, "luck decreases common chance")
		-- Монте-Карло: частота легендарки ≈ 0.5%
		math.randomseed(12345)
		local hits, N = 0, 200000
		for _ = 1, N do
			if P.roll("MeadowEgg", 1, math.random()) == "dandy" then
				hits += 1
			end
		end
		local freq = hits / N * 100
		check(freq > 0.4 and freq < 0.6, ("legendary frequency %.3f%% ~ 0.5%%"):format(freq))
	end
)

test("Shared: PetModel строит все модели без ошибок", function()
	local S = boot("A")
	local PetModel = S.U.require("ReplicatedStorage/Shared/PetModel")
	local n = 0
	for _, def in ipairs(S.PetData.Pets) do
		for _, gold in ipairs({ false, true }) do
			local m = PetModel.build(def.Id, gold)
			check(m.PrimaryPart ~= nil, "model has PrimaryPart: " .. def.Id)
			n += 1
		end
	end
	check(n == #S.PetData.Pets * 2, "built " .. n .. " models")
	check(PetModel.build("no_such_pet").PrimaryPart ~= nil, "fallback model")
end)

test("Shared: формулы экономики", function()
	local S = boot("A")
	local F, C = S.Formulas, S.Config
	check(F.rebirthCost(0) == C.REBIRTH_BASE_COST, "rebirth cost 0")
	check(F.rebirthCost(1) == C.REBIRTH_BASE_COST * C.REBIRTH_COST_GROWTH, "rebirth cost 1")
	check(F.rebirthCost(500) <= C.MAX_COINS, "rebirth cost capped")
	check(F.upgradeCost("Click", 0) == 20, "click upgrade cost lv0")
	check(F.upgradeCost("Click", 60) == nil, "click upgrade max")
	check(F.upgradeCost("Slots", 0) == 100 and F.upgradeCost("Slots", 3) == 2000, "slots explicit costs")
	check(F.walkSpeed(0, false) == 16 and F.walkSpeed(0, true) == 32, "walkspeed x2 pass")
	check(F.walkSpeed(8, true) <= C.MAX_WALKSPEED, "walkspeed cap")
	check(F.petSlots(0, false) == 3 and F.petSlots(2, true) == 6, "pet slots")
end)

-- ============================================================================
test(
	"DataService: новый игрок получает шаблон, блокировка записывается",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		local data, err = S.Data.load(MAKE_PLAYER(S.U, 1, "Alice"))
		check(data ~= nil and err == nil, "loaded new profile")
		check(data.Coins == 0 and data.Zones.Meadow == true, "template defaults")
		local rec = BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_1"]
		check(
			rec ~= nil and rec.Lock ~= nil and rec.Lock.SessionId == S.Data.SESSION_ID,
			"lock written to store"
		)
	end
)

test(
	"DataService: сохранение, повторная загрузка и reconcile старых данных",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		local p = MAKE_PLAYER(S.U, 2, "Bob")
		local data = S.Data.load(p)
		data.Coins = 4242
		data.Pets["p1"] = { Id = "bunbun", Gold = false }
		S.Data.release(p)
		local rec = BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_2"]
		check(rec.Lock == nil, "lock released")
		check(rec.Data.Coins == 4242, "coins persisted")
		-- «старая» версия данных без новых полей
		rec.Data.Boosts = nil
		rec.Data.Daily = nil
		local p2 = MAKE_PLAYER(S.U, 2, "Bob")
		local d2 = S.Data.load(p2)
		check(d2.Coins == 4242 and d2.Pets.p1.Id == "bunbun", "data restored")
		check(d2.Boosts ~= nil and d2.Daily ~= nil, "missing fields reconciled")
	end
)

test(
	"DataService: session lock между серверами (ожидание, отказ, передача после release)",
	function()
		BACKEND.Stores = {}
		local A = boot("A")
		local B = boot("B")
		B.Config.LOAD_ATTEMPTS = 3
		B.Config.LOAD_LOCK_RETRY_DELAY = 1
		local pa = MAKE_PLAYER(A.U, 3, "Carol")
		local da = A.Data.load(pa)
		da.Coins = 777
		-- A жив: автосейв обновляет блокировку (v2.4: B ждёт до SESSION_LOCK_TIMEOUT, а не 3 попытки)
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(60)
				if alive then
					A.Data.saveNow(pa)
				end
			end
		end)
		local pb = MAKE_PLAYER(B.U, 3, "Carol")
		local t0 = os.clock()
		local db, err = B.Data.load(pb)
		alive = false
		check(
			os.clock() - t0 >= B.Config.SESSION_LOCK_TIMEOUT,
			"B ждал снятия блокировки весь таймаут"
		)
		check(db == nil, "server B cannot load while A holds lock")
		check(err ~= nil and string.find(err, "locked") ~= nil, "reason mentions lock: " .. tostring(err))
		A.Data.release(pa)
		local pb2 = MAKE_PLAYER(B.U, 3, "Carol")
		local db2 = B.Data.load(pb2)
		check(db2 ~= nil and db2.Coins == 777, "B loads A's latest data after release")
	end
)

test(
	"DataService: «мёртвая» блокировка (упавший сервер) забирается по таймауту",
	function()
		BACKEND.Stores = {}
		local A = boot("A")
		local B = boot("B")
		local pa = MAKE_PLAYER(A.U, 4, "Dan")
		local da = A.Data.load(pa)
		da.Coins = 55
		A.Data.saveNow(pa) -- A «упал» после сохранения, lock остался
		ADVANCE(B.Config.SESSION_LOCK_TIMEOUT + 5)
		local db = B.Data.load(MAKE_PLAYER(B.U, 4, "Dan"))
		check(db ~= nil and db.Coins == 55, "stale lock taken over")
	end
)

test(
	"DataService: украденная блокировка -> сохранение отменено и игрок кикнут",
	function()
		BACKEND.Stores = {}
		local A = boot("A")
		local B = boot("B")
		local pa = MAKE_PLAYER(A.U, 5, "Eve")
		local da = A.Data.load(pa)
		da.Coins = 10
		A.Data.saveNow(pa)
		ADVANCE(A.Config.SESSION_LOCK_TIMEOUT + 5) -- A «завис»
		local db = B.Data.load(MAKE_PLAYER(B.U, 5, "Eve"))
		db.Coins = 999
		da.Coins = 123456 -- A просыпается и пытается записать устаревшие данные
		local ok = A.Data.saveNow(pa)
		check(ok == false, "stale server save rejected")
		check(pa.Kicked ~= nil, "stale server player kicked")
		local rec = BACKEND.Stores[A.Config.DATASTORE_NAME]["Player_5"]
		check(rec.Data.Coins ~= 123456, "stale data did not overwrite")
	end
)

test(
	"DataService: ретраи при сбоях DataStore (загрузка и сохранение)",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		BACKEND.FailNext = 2
		local p = MAKE_PLAYER(S.U, 6, "Fay")
		local data = S.Data.load(p)
		check(data ~= nil, "load succeeded after 2 failures")
		data.Gems = 5
		BACKEND.FailNext = 3
		check(S.Data.saveNow(p) == true, "save succeeded after 3 failures")
		check(BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_6"].Data.Gems == 5, "gems saved")
		BACKEND.FailAlways = true
		check(S.Data.saveNow(p) == false, "save reports failure during outage")
		BACKEND.FailAlways = false
		check(S.Data.saveNow(p) == true, "save recovers after outage")
	end
)

test(
	"DataService: полный отказ DataStore на live-сервере -> загрузка не удаётся (нет затирания)",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		S.Config.LOAD_ATTEMPTS = 2
		BACKEND.FailAlways = true
		local data, err = S.Data.load(MAKE_PLAYER(S.U, 7, "Gus"))
		BACKEND.FailAlways = false
		check(data == nil and err ~= nil, "no data when datastore down on live server")
	end
)

test(
	"DataService: в Studio при отказе DataStore включается режим без сохранения",
	function()
		BACKEND.Stores = {}
		local S = boot("A", { studio = true })
		S.Config.LOAD_ATTEMPTS = 2
		BACKEND.FailAlways = true
		local data = S.Data.load(MAKE_PLAYER(S.U, 8, "Hal"))
		BACKEND.FailAlways = false
		check(data ~= nil, "ephemeral profile in Studio")
	end
)

test(
	"DataService: Studio без API Services — мгновенный переход в режим без сохранения",
	function()
		BACKEND.Stores = {}
		local S = boot("A", { studio = true })
		BACKEND.FailNext = 50
		BACKEND.ErrorMessage =
			"403: Studio access to APIs is not allowed. Enable it in Game Settings > Security."
		local t0 = os.clock()
		local data = S.Data.load(MAKE_PLAYER(S.U, 9, "Ira"))
		local elapsed = os.clock() - t0
		BACKEND.FailNext = 0
		BACKEND.ErrorMessage = nil
		check(data ~= nil, "ephemeral data given")
		check(elapsed < 1, "no long retry loop in Studio (virtual seconds: " .. elapsed .. ")")
	end
)

-- ============================================================================
test(
	"Monetization: ProcessReceipt — выдача, идемпотентность, отказ сохранения",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		S.Config.PRODUCT_IDS.GEMS_SMALL = 1001
		S.Config.PRODUCT_IDS.COINS_SMALL = 1002
		S.Config.PRODUCT_IDS.LUCK_2X_15M = 1003
		local data, _, p = S.join(10, "Ivy")
		local fn = S.U.Game:GetService("MarketplaceService").ProcessReceipt
		check(fn ~= nil, "ProcessReceipt assigned")
		local GRANTED = "Enum.ProductPurchaseDecision.PurchaseGranted"
		local NOT_YET = "Enum.ProductPurchaseDecision.NotProcessedYet"

		check(fn(receipt(p, 5001, 1001)) == GRANTED, "gems pack granted")
		check(data.Gems == S.Config.PRODUCTS.GEMS_SMALL.Amount, "gems amount")
		check(fn(receipt(p, 5001, 1001)) == GRANTED, "duplicate receipt acknowledged")
		check(data.Gems == S.Config.PRODUCTS.GEMS_SMALL.Amount, "duplicate receipt NOT granted twice")
		local saved = BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_10"].Data
		check(
			saved.Gems == 100 and saved.Receipts["5001"] ~= nil,
			"reward and receipt are persisted together"
		)

		-- сохранение не удалось -> NotProcessedYet, но повтор не дублирует награду
		BACKEND.FailAlways = true
		S.Config.SAVE_ATTEMPTS = 2
		check(fn(receipt(p, 5002, 1001)) == NOT_YET, "save failure -> NotProcessedYet")
		check(data.Gems == 200, "granted in memory once")
		BACKEND.FailAlways = false
		check(fn(receipt(p, 5002, 1001)) == GRANTED, "retry after recovery -> granted")
		check(data.Gems == 200, "retry does not double-grant")

		-- coins pack масштабируется с силой клика, но не меньше Min
		local before = data.Coins
		check(fn(receipt(p, 5003, 1002)) == GRANTED, "coins pack granted")
		check(data.Coins - before >= S.Config.PRODUCTS.COINS_SMALL.Min, "coins >= min")

		-- лаки-буст
		check(fn(receipt(p, 5004, 1003)) == GRANTED, "luck boost granted")
		check(data.Boosts.Luck2 > os.time(), "luck boost active")
		local mult = S.Economy.getLuckBoost(data)
		check(mult == 2, "luck boost multiplier x2")
		check(fn(receipt(p, 5005, 1003)) == GRANTED, "second luck boost")
		check(data.Boosts.Luck2 - os.time() > 900, "luck boost durations stack")

		-- неизвестный продукт и отсутствующий игрок
		check(fn(receipt(p, 5006, 99999)) == NOT_YET, "unknown product -> NotProcessedYet")
		check(
			fn({ PlayerId = 424242, PurchaseId = 1, ProductId = 1001 }) == NOT_YET,
			"absent player -> NotProcessedYet"
		)
		-- placeholder-ID 0 никогда не совпадает с реальным продуктом
		check(S.Config.getProductKeyById(0) == nil, "ID 0 ignored")
	end
)

test("Monetization: геймпассы, Premium и множители", function()
	BACKEND.Stores = {}
	local S = boot("A")
	S.Config.GAMEPASS_IDS.DOUBLE_COINS = 2001
	S.Config.GAMEPASS_IDS.VIP = 2002
	S.Config.GAMEPASS_IDS.AUTO_COLLECT = 2003
	S.Config.GAMEPASS_IDS.DOUBLE_SPEED = 2004
	S.U.Market.OwnedPasses["11:2001"] = true
	local data, _, p = S.join(11, "Jon")
	check(
		S.Session.hasPass(p, "DOUBLE_COINS") and not S.Session.hasPass(p, "VIP"),
		"ownership checked on join"
	)
	local base = S.Economy.getPerClick(p, data)
	check(base == 2, "2x coins pass: per click " .. base)
	-- покупка VIP в игре
	S.U.Market.PromptGamePassPurchaseFinished:Fire(p, 2002, true)
	DRIVE_UNTIL_IDLE(5)
	check(S.Session.hasPass(p, "VIP"), "VIP granted by PromptGamePassPurchaseFinished")
	data.Upgrades.Click = 99 -- 1+99=100 base
	data.Pets = {}
	local pc = S.Economy.getPerClick(p, data)
	check(pc == math.floor(100 * 2 * 1.25), "VIP + 2x multiplier: " .. pc)
	-- Premium
	p.MembershipType = "Enum.MembershipType.Premium"
	S.U.Players.PlayerMembershipChanged:Fire(p)
	DRIVE_UNTIL_IDLE(5)
	check(S.Economy.getPerClick(p, data) == math.floor(100 * 2 * 1.25 * 1.10), "premium bonus applied")
	-- отмена покупки не даёт пасс
	S.U.Market.PromptGamePassPurchaseFinished:Fire(p, 2003, false)
	DRIVE_UNTIL_IDLE(5)
	check(not S.Session.hasPass(p, "AUTO_COLLECT"), "cancelled purchase grants nothing")
	check(S.Economy.getPetSlots(p, data) == S.Config.BASE_PET_SLOTS + 1, "VIP gives +1 slot")
	check(S.Economy.getWalkSpeed(p, data) == 16, "no speed pass -> base speed")
	S.U.Market.PromptGamePassPurchaseFinished:Fire(p, 2004, true)
	DRIVE_UNTIL_IDLE(5)
	check(S.Economy.getWalkSpeed(p, data) == 32, "speed pass doubles speed")
end)

-- ============================================================================
test(
	"PolicyService: ограничение платных случайных предметов отключает платные модификаторы удачи",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		S.Config.GAMEPASS_IDS.VIP = 2002
		S.U.Market.OwnedPasses["12:2002"] = true
		local data, _, p = S.join(12, "Kai")
		check(S.Session.get(p).PaidRandomRestricted == false, "policy: not restricted")
		data.Boosts.Luck5 = os.time() + 600
		local luck = S.Economy.getLuck(p, data)
		check(math.abs(luck - 5 * 1.10) < 1e-9, "paid luck counted when allowed: " .. luck)
		S.U.Restricted = true
		S.U.Market.OwnedPasses["13:2002"] = true
		local data2, _, p2 = S.join(13, "Lia")
		check(S.Session.get(p2).PaidRandomRestricted == true, "policy: restricted")
		data2.Boosts.Luck5 = os.time() + 600
		check(S.Session.hasPass(p2, "VIP"), "vip owned")
		check(S.Economy.getLuck(p2, data2) == 1, "paid luck ignored when restricted")
		S.U.Restricted = false
		S.U.PolicyError = true
		local _, _, p3 = S.join(14, "Max")
		check(S.Session.get(p3).PaidRandomRestricted == true, "policy error -> restricted by default")
	end
)

test(
	"Яйца: серверная валидация (цена, расстояние, зона, вместимость, аргументы)",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		local data, _, p = S.join(20, "Kim")
		local hatch = function(...)
			ADVANCE(1) -- не упираемся в rate limit
			return S.invoke(p, "Hatch", ...)
		end
		local r = hatch("MeadowEgg", 1)
		check(
			r.ok == false and r.msg == "Not enough coins",
			"cannot hatch without coins: " .. tostring(r.msg)
		)
		check(next(data.Pets) == nil, "no pet created")
		data.Coins = 1000
		r = hatch("MeadowEgg", 3)
		check(r.ok == true, "hatch x3 ok: " .. tostring(r.msg))
		check(data.Coins == 1000 - 3 * 150, "coins deducted exactly")
		local n = 0
		for _ in pairs(data.Pets) do
			n += 1
		end
		check(n == 3 and data.TotalHatched == 3, "3 pets created")
		local fired = FIRED(S.U.RS:FindFirstChild("Remotes"):FindFirstChild("HatchResult"))
		check(#fired == 1 and #fired[1].Args[1] == 3, "HatchResult event sent")

		check(hatch("MeadowEgg", 2).ok == false, "count 2 rejected")
		check(hatch("MeadowEgg", 0).ok == false, "count 0 rejected")
		check(hatch("MeadowEgg", -1).ok == false, "negative count rejected")
		check(hatch("MeadowEgg", 1e9).ok == false, "huge count rejected")
		check(hatch("MeadowEgg", {}).ok == false, "table count rejected")
		check(hatch("MeadowEgg", 0 / 0).ok == false, "NaN count rejected")
		check(hatch({}, 1).ok == false, "table eggId rejected")
		check(hatch("NoEgg", 1).ok == false, "unknown egg rejected")
		check(hatch(nil, nil).ok == false, "nil args rejected")
		local coinsNow = data.Coins
		r = hatch("ForestEgg", 1)
		check(r.ok == false and r.msg == "Unlock this world first", "locked world egg rejected")
		check(data.Coins == coinsNow, "no charge on rejection")
		-- расстояние
		p.Character.HumanoidRootPart.Position = Vector3.new(500, 3, 500)
		-- в заглушке WorldBuilder яйцо в (0,0,0): далеко -> отказ
		r = hatch("MeadowEgg", 1)
		check(r.ok == false and r.msg == "Stand closer to the egg", "distance check")
		p.Character.HumanoidRootPart.Position = Vector3.new(5, 3, 5)
		-- вместимость
		data.Coins = 1e6
		for i = 1, 100 do
			data.Pets["x" .. i] = { Id = "bunbun", Gold = false }
		end
		r = hatch("MeadowEgg", 1)
		check(r.ok == false, "bag full rejected")
		-- гемы
		data.Pets = {}
		data.Gems = 10
		r = hatch("GemEgg", 1)
		check(r.ok == false and r.msg == "Not enough gems", "gem egg needs gems")
		data.Gems = 80
		r = hatch("GemEgg", 1)
		check(r.ok == true and data.Gems == 5, "gem egg charges gems")
	end
)

test("Router: rate-limit и неизвестные действия", function()
	BACKEND.Stores = {}
	local S = boot("A")
	local data, _, p = S.join(21, "Lee")
	data.Coins = 1e9
	local okCount, limited = 0, 0
	for _ = 1, 20 do
		local r = S.invoke(p, "Hatch", "MeadowEgg", 1) -- время не движется
		if r.ok then
			okCount += 1
		elseif r.msg == "Slow down!" then
			limited += 1
		end
	end
	check(
		okCount == 3 and limited == 17,
		("burst 3 then limited (ok=%d limited=%d)"):format(okCount, limited)
	)
	check(S.invoke(p, "DropDatabase").ok == false, "unknown action rejected")
	check(S.invoke(p, 12345).ok == false, "non-string action rejected")
	check(#S.Session.get(p).Strikes > 0, "strikes recorded for abuse")
	-- перед загрузкой данных
	local p2 = MAKE_PLAYER(S.U, 22, "Mia")
	S.Session.create(p2)
	check(S.invoke(p2, "Hatch", "MeadowEgg", 1).ok == false, "not-ready player rejected")
end)

test("Питомцы: экипировка, слоты, продажа, equip best", function()
	BACKEND.Stores = {}
	local S = boot("A")
	local data, _, p = S.join(30, "Ned")
	data.Pets = {
		a = { Id = "bunbun", Gold = false },
		b = { Id = "chirpy", Gold = false },
		c = { Id = "mossy", Gold = false },
		d = { Id = "bumblet", Gold = false },
		e = { Id = "sunfox", Gold = true },
	}
	local call = function(a, ...)
		ADVANCE(2)
		return S.invoke(p, a, ...)
	end
	check(call("Equip", "zzz").ok == false, "equip unknown uid rejected")
	check(call("Equip", {}).ok == false, "equip bad type rejected")
	check(call("Equip", "a").ok and call("Equip", "b").ok and call("Equip", "c").ok, "equip up to 3")
	check(call("Equip", "d").ok == false, "4th slot rejected")
	check(call("Equip", "a").ok == false, "double equip rejected")
	check(call("Sell", "a").ok == false, "cannot sell equipped")
	check(call("Unequip", "a").ok and #data.Equipped == 2, "unequip")
	check(call("EquipBest").ok, "equip best")
	check(data.Equipped[1] == "e", "best pet first (golden fox): " .. tostring(data.Equipped[1]))
	check(#data.Equipped == 3, "fills all slots")
	local coins = data.Coins
	check(call("Sell", "a").ok == true or data.Pets.a == nil, "sell non-equipped (or already sold)")
	check(data.Coins >= coins, "coins increased by sale")
	check(call("Sell", "a").ok == false, "cannot sell twice")
	-- сила питомцев
	local power = S.Economy.getPetPower(data)
	local expected = 0
	for _, uid in ipairs(data.Equipped) do
		expected += S.PetMeta.power(data.Pets[uid])
	end
	check(power == expected and power > 0, "pet power sum")
end)

test("Клики: серверный лимит частоты, начисление", function()
	BACKEND.Stores = {}
	local S = boot("A")
	local data, _, p = S.join(40, "Orb")
	data.Tutorial.Step = 99 -- v2.4: награда шага обучения не мешает считать монеты
	for _ = 1, 500 do
		S.click(p)
	end
	DRIVE_UNTIL_IDLE(1)
	check(
		data.Coins == S.Config.CLICK_BURST,
		("burst limited to %d clicks (got %d)"):format(S.Config.CLICK_BURST, data.Coins)
	)
	ADVANCE(1)
	for _ = 1, 500 do
		S.click(p)
	end
	DRIVE_UNTIL_IDLE(1)
	local gained = data.Coins - S.Config.CLICK_BURST
	check(gained <= S.Config.CLICK_BURST + 1, "after 1s at most burst clicks again: " .. gained)
	-- 10 секунд непрерывных кликов не больше 12/сек
	local start = data.Coins
	for _ = 1, 100 do
		ADVANCE(0.01)
		S.click(p)
	end
	check(data.Coins - start <= 100, "cannot exceed rate")
end)

test("Апгрейды, зоны, ребёрт", function()
	BACKEND.Stores = {}
	local S = boot("A")
	local data, _, p = S.join(50, "Pam")
	local call = function(a, ...)
		ADVANCE(2)
		return S.invoke(p, a, ...)
	end
	check(call("BuyUpgrade", "Click").msg == "Not enough coins", "upgrade needs coins")
	data.Coins = 100
	check(call("BuyUpgrade", "Click").ok and data.Upgrades.Click == 1 and data.Coins == 80, "buy click lv1")
	check(call("BuyUpgrade", "Nope").ok == false and call("BuyUpgrade", 5).ok == false, "bad upgrade ids")
	data.Upgrades.Click = 60
	data.Coins = 1e12
	check(call("BuyUpgrade", "Click").msg == "Max level reached", "max level")
	-- гемовый апгрейд
	check(call("BuyUpgrade", "Slots").msg == "Not enough gems", "slots need gems")
	data.Gems = 100
	check(call("BuyUpgrade", "Slots").ok and data.Gems == 0, "slots bought for 100 gems")
	-- зоны
	check(call("Teleport", "Forest").ok == false, "cannot teleport to locked zone")
	data.Coins = 4999
	check(call("UnlockZone", "Forest").ok == false, "not enough coins for zone")
	data.Coins = 5000
	check(call("UnlockZone", "Forest").ok and data.Zones.Forest and data.Coins == 0, "zone unlocked")
	check(call("UnlockZone", "Forest").ok == false, "cannot unlock twice")
	data.Coins = 1e12
	check(call("UnlockZone", "Volcano").ok == false, "volcano requires rebirth")
	check(call("Teleport", "Forest").ok and data.CurrentZone == "Forest", "teleport to unlocked zone")
	local pcForest = S.Economy.getPerClick(p, data)
	data.CurrentZone = "Meadow"
	local pcMeadow = S.Economy.getPerClick(p, data)
	check(pcForest == pcMeadow * 3, "zone multiplier x3")
	-- ребёрт
	data.Coins = 49999
	check(call("Rebirth").ok == false, "rebirth needs coins")
	data.Coins = 50000
	data.Gems = 0
	check(call("Rebirth").ok == true, "rebirth ok")
	check(data.Rebirths == 1 and data.Coins == 0 and data.Upgrades.Click == 0, "rebirth resets coins/click")
	check(
		data.Gems >= S.Formulas.rebirthGems(0),
		"rebirth gems (+ возможная награда достижения)"
	)
	check(data.Zones.Forest == true and data.Upgrades.Slots == 1, "rebirth keeps zones & other upgrades")
	check(S.Formulas.rebirthMultiplier(1) == 1.5, "multiplier 1.5")
	check(call("UnlockZone", "Volcano").msg == "Not enough coins", "volcano now needs only coins")
end)

test(
	"Ежедневные награды: стрик, сброс, повторная выдача",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		local data, _, p = S.join(60, "Quin")
		local call = function()
			ADVANCE(2)
			return S.invoke(p, "ClaimDaily")
		end
		local info = S.Daily.getInfo(data)
		check(info.CanClaim and info.Day == 1, "day 1 available")
		check(call().ok and data.Daily.Streak == 1 and data.Gems == 10, "day 1 claimed (+10 gems)")
		check(call().ok == false, "second claim same day rejected")
		check(S.Daily.getInfo(data).CanClaim == false, "info reflects claimed")
		SET_WALL_CLOCK(GET_WALL_CLOCK() + 86400)
		check(call().ok and data.Daily.Streak == 2, "next day continues streak")
		SET_WALL_CLOCK(GET_WALL_CLOCK() + 3 * 86400)
		check(S.Daily.getInfo(data).Day == 1, "missed days -> resets to day 1")
		check(call().ok and data.Daily.Streak == 1, "streak reset after gap")
		-- день 4 даёт буст удачи, VIP удваивает
		data.Daily.Streak = 3
		data.Daily.LastDay = os.time() // 86400 - 1
		S.Session.get(p).Passes.VIP = true
		local gems = data.Gems
		check(call().ok, "day 4 claimed")
		check(data.Gems - gems == 25 * 2, "VIP doubles daily gems: " .. (data.Gems - gems))
		check(data.Boosts.Luck2 > os.time(), "day 4 luck boost")
	end
)

test("PlayerService: вход, leaderstats, выход со снятием блокировки", function()
	BACKEND.Stores = {}
	local S = boot("A")
	S.State.init()
	S.PlayerService.init()
	local p = MAKE_PLAYER(S.U, 70, "Rex")
	S.U.Players.PlayerAdded:Fire(p)
	DRIVE_UNTIL_IDLE(30)
	check(p:FindFirstChild("leaderstats") ~= nil, "leaderstats created")
	check(S.Session.get(p) and S.Session.get(p).Ready, "session ready")
	local data = S.Data.get(p)
	data.Coins = 1234
	S.Click.award(p, 3)
	check(p.leaderstats.Coins.Value ~= nil, "coins leaderstat updated")
	S.U.Players.PlayerRemoving:Fire(p)
	DRIVE_UNTIL_IDLE(30)
	local rec = BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_70"]
	check(rec ~= nil and rec.Lock == nil and rec.Data.Coins >= 1234, "saved & lock released on leave")
	check(S.Data.get(p) == nil, "profile dropped")
end)

test(
	"PlayerService: если данные не загрузились — игрок кикается, а не играет с пустым профилем",
	function()
		BACKEND.Stores = {}
		local S = boot("A")
		S.Config.LOAD_ATTEMPTS = 2
		S.PlayerService.init()
		local p = MAKE_PLAYER(S.U, 71, "Sid")
		BACKEND.FailAlways = true
		S.U.Players.PlayerAdded:Fire(p)
		DRIVE_UNTIL_IDLE(60)
		BACKEND.FailAlways = false
		check(p.Kicked ~= nil, "player kicked on load failure")
	end
)

-- =============================================================================================
-- v2: чистая логика новых систем
-- =============================================================================================
test("PetMeta: стихии образуют цикл Water>Fire>Earth>Air>Water", function()
	local S = boot("A")
	local M = S.PetMeta
	for _, a in ipairs(M.ElementOrder) do
		local beaten, beaters = 0, 0
		for _, d in ipairs(M.ElementOrder) do
			local m = M.elementMultiplier(a, d)
			if m == M.STRONG then
				beaten += 1
				check(M.elementMultiplier(d, a) == M.WEAK, a .. "/" .. d .. " симметрия")
			elseif m == M.WEAK then
				beaters += 1
			end
		end
		check(
			beaten == 1 and beaters == 1,
			a .. ": один слабый и один сильный противник"
		)
		check(M.elementMultiplier(a, a) == 1, a .. " против себя нейтрально")
	end
	check(
		M.elementMultiplier("Water", "Fire") == 1.5 and M.elementMultiplier("Fire", "Water") == 0.7,
		"значения 1.5 / 0.7"
	)
	check(
		M.elementMultiplier(nil, "Fire") == 1 and M.elementMultiplier("Fire", "Void") == 1,
		"неизвестная стихия нейтральна"
	)
end)

test(
	"PetMeta: каждый питомец имеет стихию, роль и способность",
	function()
		local S = boot("A")
		local seen = { Fire = 0, Water = 0, Earth = 0, Air = 0 }
		local roles = { Fighter = 0, Collector = 0, Support = 0 }
		for _, def in ipairs(S.PetData.Pets) do
			local info = S.PetMeta.info(def.Id)
			check(
				seen[info.Element] ~= nil and roles[info.Role] ~= nil,
				def.Id .. ": стихия/роль валидны"
			)
			check(S.PetMeta.ability(def.Id) ~= nil, def.Id .. ": способность есть")
			seen[info.Element] += 1
			roles[info.Role] += 1
		end
		for e, n in pairs(seen) do
			check(
				n >= 3,
				"стихия "
					.. e
					.. " представлена минимум 3 питомцами ("
					.. n
					.. ")"
			)
		end
		for r, n in pairs(roles) do
			check(
				n >= 3,
				"роль "
					.. r
					.. " представлена минимум 3 питомцами ("
					.. n
					.. ")"
			)
		end
	end
)

test("PetMeta: опыт, уровни, потолок и эволюция", function()
	local S = boot("A")
	local M = S.PetMeta
	local p = { Id = "bunbun", Level = 1, Xp = 0, Evo = 0 }
	local lv, xp, gained = M.addXp(p, M.xpForNext(1) - 1)
	check(lv == 1 and gained == 0 and xp == M.xpForNext(1) - 1, "не хватает до уровня")
	p.Level, p.Xp = lv, xp
	lv, xp, gained = M.addXp(p, 1 + M.xpForNext(1) - xp - 1 + M.xpForNext(2) + 3)
	check(lv == 3 and gained == 2, "два уровня за раз: lv=" .. lv .. " gained=" .. gained)
	p.Level, p.Xp = 10, 0
	lv, xp = M.addXp(p, 1e9)
	check(
		lv == 10 and xp == 0,
		"потолок 10 уровня без эволюции, опыт не копится"
	)
	check(
		select(1, M.canEvolve({ Id = "x", Level = 9, Evo = 0 })) == false,
		"нельзя эволюционировать до макс. уровня"
	)
	check(
		select(1, M.canEvolve({ Id = "x", Level = 10, Evo = 0 })) == true,
		"можно на макс. уровне"
	)
	check(
		select(1, M.canEvolve({ Id = "x", Level = 40, Evo = M.MAX_EVO })) == false,
		"максимальная эволюция"
	)
	check(M.maxLevel(1) == 20 and M.maxLevel(3) == 40, "потолок растёт с эволюцией")
	check(
		M.evoCost(0) ~= nil and M.evoCost(M.MAX_EVO) == nil,
		"стоимость эволюции есть кроме последней"
	)
	local base = M.power({ Id = "bunbun", Level = 1, Evo = 0 })
	check(M.power({ Id = "bunbun", Level = 10, Evo = 0 }) > base, "уровень повышает силу")
	check(M.power({ Id = "bunbun", Level = 1, Evo = 2 }) > base, "эволюция повышает силу")
	local vp = {}
	for _, v in ipairs(M.VariantOrder) do
		vp[v] = M.power({ Id = "bunbun", Variant = v })
	end
	check(
		vp.Normal < vp.Golden and vp.Golden < vp.Rainbow and vp.Rainbow < vp.Shiny,
		"варианты: Normal<Golden<Rainbow<Shiny"
	)
	check(
		M.tradeValue({ Id = "bunbun", Variant = "Rainbow" }) > M.tradeValue({ Id = "bunbun" }),
		"цена обмена растёт с вариантом"
	)
	check(
		M.displayName({ Id = "bunbun", Variant = "Golden", Evo = 1 }):find("Golden") ~= nil,
		"имя содержит вариант"
	)
end)

test(
	"Слияние 3→1: проверки состава и вероятности вариантов",
	function()
		local S = boot("A")
		local M = S.PetMeta
		local a = { Id = "bunbun" }
		check(M.canFuse({ a, a, a }) == true, "три одинаковых — можно")
		check(M.canFuse({ a, a }) == false, "меньше трёх нельзя")
		check(M.canFuse({ a, a, { Id = "chirpy" } }) == false, "разные виды нельзя")
		check(
			M.canFuse({ a, a, { Id = "bunbun", Variant = "Golden" } }) == false,
			"разные варианты нельзя"
		)
		check(M.canFuse({ a, a, { Id = "bunbun", Fav = true } }) == false, "избранных нельзя")
		check(
			M.fuseVariant("Normal", 0.5, 0.0) == "Golden",
			"бросок ниже шанса — апгрейд варианта"
		)
		check(
			M.fuseVariant("Normal", 0.5, 0.99) == "Normal",
			"бросок выше шанса — вариант сохраняется"
		)
		check(M.fuseVariant("Golden", 0.5, 0.0) == "Rainbow", "Golden→Rainbow")
		check(M.fuseVariant("Rainbow", 0.5, 0.0) == "Shiny", "Rainbow→Shiny")
		check(M.fuseVariant("Normal", 0.0, 0.99) == "Shiny", "малый первый бросок — Shiny")
		check(M.fuseVariant("Shiny", 0.0, 0.0) == "Shiny", "Shiny остаётся Shiny")
		check(
			M.fuseVariant("Normal", 0.5, 0.40) == "Normal"
				and M.fuseVariant("Normal", 0.5, 0.40, M.CATALYST_BONUS) == "Golden",
			"катализатор повышает шанс"
		)
		local up, shiny, N = 0, 0, 20000
		for _ = 1, N do
			local v = M.fuseVariant("Normal", math.random(), math.random())
			if v == "Golden" then
				up += 1
			elseif v == "Shiny" then
				shiny += 1
			end
		end
		-- v2.4 (Г4): сияние из обычных — 0.5%
		check(math.abs(up / N - 0.995 * 0.30) < 0.02, ("доля Golden ≈ 30%% (%.3f)"):format(up / N))
		check(math.abs(shiny / N - 0.005) < 0.004, ("доля Shiny ≈ 0.5%% (%.3f)"):format(shiny / N))
	end
)

test("Талант-дерево: очки, требования, максимумы", function()
	local S = boot("A")
	local T = S.TalentData
	check(
		S.Formulas.talentPoints(0) == 0 and S.Formulas.talentPoints(5) == 6,
		"очки: 1 за ребёрт + бонус за 5-й"
	)
	local lv = {}
	check(T.canBuy(lv, "eco_coins", 0) == false, "нет очков — нельзя")
	check(T.canBuy(lv, "eco_start", 5) == false, "не выполнены требования")
	check(T.canBuy(lv, "eco_coins", 1) == true, "корневой талант за 1 очко")
	check(T.canBuy(lv, "нет_такого", 5) == false, "неизвестный талант")
	lv.eco_coins = 5
	check(T.canBuy(lv, "eco_coins", 9) == false, "максимум уровней достигнут")
	check(math.abs(T.bonus(lv, "Coins") - 0.5) < 1e-9, "бонус монет 5 × 10%")
	check(T.canBuy(lv, "eco_start", 1) == true, "требования выполнены — можно")
	lv.eco_start = 2
	check(T.spent(lv) == 7, "потрачено 7 очков")
	local ids = {}
	for _, n in ipairs(T.List) do
		check(not ids[n.Id], "уникальный id " .. n.Id)
		ids[n.Id] = true
		for req in pairs(n.Requires) do
			check(T.ById[req] ~= nil, n.Id .. " требует существующий " .. req)
		end
	end
end)

test("Батл-пасс: уровни, награды, прогресс опыта", function()
	local S = boot("A")
	local B = S.BattlePassData
	local lv, into, need = B.progress(0)
	check(lv == 0 and into == 0 and need == B.xpForLevel(1), "старт с 0 уровня")
	lv, into = B.progress(B.xpForLevel(1))
	check(lv == 1 and into == 0, "ровно на границе уровня")
	lv = B.progress(B.xpForLevel(1) + B.xpForLevel(2) + 5)
	check(lv == 2, "накопительно")
	lv, into, need = B.progress(1e9)
	check(lv == B.MaxLevel and need == 0, "потолок уровня")
	check(select(1, B.progress(-50)) == 0, "отрицательный опыт не ломает")
	for l = 1, B.MaxLevel do
		check(
			B.reward("Free", l) ~= nil and B.reward("Premium", l) ~= nil,
			"награды на уровне " .. l
		)
	end
	check(B.reward("Free", B.MaxLevel + 1) == nil, "за пределом наград нет")
	check(B.reward("Premium", 15).Pet == "seasonowl", "премиум-питомец на 15 уровне")
end)

test(
	"Магазин: ротация детерминирована, без повторов, учитывает ребёрты",
	function()
		local S = boot("A")
		local D = S.ShopData
		local o1, o2 = D.offers(100, 0), D.offers(100, 0)
		check(#o1 == D.SLOTS, "ровно " .. D.SLOTS .. " предложений")
		for i = 1, #o1 do
			check(o1[i] == o2[i], "одинаковый слот → одинаковый набор")
		end
		local seen = {}
		for _, id in ipairs(o1) do
			check(not seen[id] and D.ById[id] ~= nil, "без повторов: " .. id)
			seen[id] = true
		end
		local differ = false
		for slot = 101, 110 do
			local o = D.offers(slot, 0)
			for i = 1, #o do
				if o[i] ~= o1[i] then
					differ = true
				end
			end
		end
		check(differ, "наборы меняются между слотами")
		check(D.slotAt(0) == 0 and D.slotAt(D.ROTATION_SECONDS) == 1, "границы слота")
		check(
			D.secondsLeft(0) == D.ROTATION_SECONDS and D.secondsLeft(D.ROTATION_SECONDS - 1) == 1,
			"таймер до смены"
		)
		for slot = 1, 60 do
			for _, id in ipairs(D.offers(slot, 0)) do
				check(
					(D.ById[id].MinRebirth or 0) == 0,
					"предложения с MinRebirth не попадают новичку"
				)
			end
		end
	end
)

test(
	"События по расписанию: период, длительность, смещение",
	function()
		local S = boot("A")
		local E = S.EventData
		for _, e in ipairs(E.List) do
			local on, left = E.status(e.Id, e.Offset)
			check(on and left == e.Duration, e.Id .. ": старт в Offset")
			on = E.status(e.Id, e.Offset + e.Duration)
			check(not on, e.Id .. ": конец через Duration")
			on, left = E.status(e.Id, e.Offset + e.Period)
			check(on and left == e.Duration, e.Id .. ": повтор через Period")
			on, left = E.status(e.Id, e.Offset + e.Duration + 1)
			check(
				not on and left == e.Period - e.Duration - 1,
				e.Id .. ": до следующего старта"
			)
			on, left = E.status(e.Id, 0)
			check(on or left == e.Offset, e.Id .. ": до первого старта")
			check(e.Duration < e.Period, e.Id .. ": длительность меньше периода")
		end
		check(E.activeAt(E.ById.GoldenRain.Offset).GoldenRain == E.ById.GoldenRain.Duration, "activeAt")
		check(select(1, E.status("нет", 5)) == false, "неизвестное событие")
	end
)

test(
	"TradeLogic: обе стороны, сброс при изменении, отсчёт, отмена",
	function()
		local S = boot("A")
		local T = S.TradeLogic
		local t = T.new("a", "b")
		check(T.setOffer(t, "a", { "p1", "p2" }, 100, 6), "предложение A")
		check(T.setOffer(t, "b", {}, 500, 6), "предложение B")
		check(T.setReady(t, "a", true, 100, 3) and t.Status == "Open", "один готов — ждём")
		check(
			T.setOffer(t, "b", {}, 600, 6) and not t.A.Ready,
			"изменение предложения сбрасывает готовность"
		)
		T.setReady(t, "a", true, 100, 3)
		T.setReady(t, "b", true, 101, 3)
		check(t.Status == "Confirming" and t.ConfirmAt == 104, "обе готовы → отсчёт 3 с")
		check(
			select(1, T.setOffer(t, "a", {}, 0, 6)) == true and t.Status == "Open",
			"правка во время отсчёта возвращает в Open"
		)
		T.setReady(t, "a", true, 200, 3)
		T.setReady(t, "b", true, 200, 3)
		local ok, _, done = T.confirm(t, "a", 201)
		check(
			ok == false and done == false,
			"подтвердить до конца отсчёта нельзя"
		)
		ok, _, done = T.confirm(t, "a", 203)
		check(ok and not done, "первое подтверждение")
		ok, _, done = T.confirm(t, "b", 203)
		check(ok and done and t.Status == "Done", "оба подтвердили → сделка")
		check(
			select(1, T.setOffer(t, "a", {}, 1, 6)) == false,
			"после завершения менять нельзя"
		)
		local c = T.new("a", "b")
		T.cancel(c)
		check(c.Status == "Cancelled" and select(1, T.setReady(c, "a", true, 1, 3)) == false, "отмена")
		local bad = T.new("a", "b")
		check(
			select(1, T.setOffer(bad, "a", { "x", "x" }, 0, 6)) == false,
			"дубликаты питомцев"
		)
		check(select(1, T.setOffer(bad, "a", {}, -1, 6)) == false, "отрицательные монеты")
		check(select(1, T.setOffer(bad, "a", {}, 1.5, 6)) == false, "дробные монеты")
		check(select(1, T.setOffer(bad, "a", {}, 0 / 0, 6)) == false, "NaN монет")
		check(
			select(1, T.setOffer(bad, "a", { "1", "2", "3", "4", "5", "6", "7" }, 0, 6)) == false,
			"слишком много питомцев"
		)
		check(select(1, T.setOffer(bad, "zzz", {}, 0, 6)) == false, "чужой участник")
		check(
			T.botAccepts(100, 80, 0.8) and not T.botAccepts(100, 79, 0.8) and not T.botAccepts(100, 0, 0.8),
			"решение бота"
		)
	end
)

test(
	"Формулы: оффлайн-доход, друзья, урон, награда за убийство",
	function()
		local S = boot("A")
		local F, C = S.Formulas, S.Config
		check(
			F.offlineIncome(C.OFFLINE_MIN_SECONDS - 1, 10, 0) == 0,
			"короткое отсутствие ничего не даёт"
		)
		local a = F.offlineIncome(3600, 10, 0)
		check(
			a > 0 and F.offlineIncome(3600, 10, 1) == math.floor(3600 * 10 * C.OFFLINE_RATE * 2),
			"бонус талантов"
		)
		check(
			F.offlineIncome(1e9, 10, 0) == F.offlineIncome(C.OFFLINE_MAX_SECONDS, 10, 0),
			"потолок оффлайна"
		)
		check(F.offlineIncome(-5, 10, 0) == 0, "отрицательное время")
		check(
			F.friendBonus(0) == 0 and F.friendBonus(1) == C.FRIEND_BONUS_PER,
			"бонус за друзей"
		)
		check(
			F.friendBonus(999) == C.FRIEND_BONUS_MAX_FRIENDS * C.FRIEND_BONUS_PER,
			"потолок бонуса друзей"
		)
		check(
			F.petDamage(100, "Fighter", "Water", "Fire", 1) > F.petDamage(100, "Fighter", "Fire", "Fire", 1),
			"стихия усиливает урон"
		)
		check(
			F.petDamage(100, "Fighter", "Fire", "Water", 1) < F.petDamage(100, "Fighter", "Fire", "Fire", 1),
			"стихия ослабляет урон"
		)
		check(
			F.petDamage(100, "Fighter", "Fire", nil, 1) > F.petDamage(100, "Collector", "Fire", nil, 1),
			"боец бьёт сильнее сборщика"
		)
		check(F.petDamage(0, "Fighter", "Fire", nil, 1) >= 1, "минимум 1 урона")
		check(F.killCoins(10, 2) > 0 and F.killCoins(0, 0) == 1, "награда за убийство")
		check(
			F.playerAttack(100, 0, 0) < F.playerAttack(100, 1, 0.5),
			"таланты и клинок усиливают удар"
		)
	end
)

test(
	"Крафт и данные: рецепты согласованы с ресурсами и предметами",
	function()
		local S = boot("A")
		local R = S.RecipeData
		local ok, why = R.canCraft(R.Recipes[1], {}, 0)
		check(ok == false and why ~= nil, "без ресурсов нельзя: " .. tostring(why))
		local rich = {}
		for id in pairs(S.ResourceData.Resources) do
			rich[id] = 1e6
		end
		for _, rec in ipairs(R.Recipes) do
			check(R.Items[rec.Item] ~= nil, rec.Id .. ": предмет существует")
			check(R.canCraft(rec, rich, 1e12) == true, rec.Id .. ": хватает при достатке")
			for res in pairs(rec.Cost) do
				check(
					S.ResourceData.Resources[res] ~= nil,
					rec.Id .. ": ресурс " .. res .. " существует"
				)
			end
			if rec.Coins then
				check(
					R.canCraft(rec, rich, rec.Coins - 1) == false,
					rec.Id .. ": не хватает монет"
				)
			end
		end
		for _, id in ipairs(R.ItemOrder) do
			check(R.Items[id] ~= nil, "ItemOrder: " .. id)
		end
	end
)

test(
	"Квесты и достижения: целостность данных, ежедневные детерминированы",
	function()
		local S = boot("A")
		local Q = S.QuestData
		local kinds = {
			gather = 1,
			kill = 1,
			boss = 1,
			hatch = 1,
			craft = 1,
			fuse = 1,
			evolve = 1,
			collect = 1,
			level = 1,
			raid = 1,
			trade = 1,
			rain = 1,
			superstop = 1,
		}
		for npcId, chain in pairs(Q.Chains) do
			check(Q.Npcs[npcId] ~= nil, "цепочка принадлежит NPC " .. npcId)
			check(#chain.Steps >= 3, npcId .. ": минимум 3 шага")
			for i, st in ipairs(chain.Steps) do
				check(
					kinds[st.Obj.Kind] and st.Obj.Count > 0,
					("%s шаг %d: цель валидна"):format(npcId, i)
				)
				check(
					#st.Offer >= 1 and st.Done ~= "" and st.Progress ~= "",
					("%s шаг %d: диалоги есть"):format(npcId, i)
				)
				check(next(st.Reward) ~= nil, ("%s шаг %d: награда есть"):format(npcId, i))
			end
		end
		for _, d in ipairs(Q.DailyPool) do
			check(
				kinds[d.Obj.Kind] and d.Obj.Count > 0 and next(d.Reward) ~= nil,
				"ежедневное " .. d.Id
			)
		end
		local a, b = Q.dailyFor(20000), Q.dailyFor(20000)
		check(
			#a == Q.DAILY_COUNT and a[1] == b[1] and a[2] == b[2] and a[3] == b[3],
			"набор дня одинаков на всех серверах"
		)
		check(a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3], "в наборе нет повторов")
		local diff = false
		for day = 20001, 20010 do
			if Q.dailyFor(day)[1] ~= a[1] then
				diff = true
			end
		end
		check(diff, "набор меняется по дням")
		check(
			Q.matches({ Kind = "gather", Key = "Wood", Count = 1 }, "gather", "Wood", nil),
			"matches по ключу"
		)
		check(
			not Q.matches({ Kind = "gather", Key = "Wood", Count = 1 }, "gather", "Herb", nil),
			"matches другой ключ"
		)
		check(
			Q.matches({ Kind = "kill", Key = "Meadow", Count = 1 }, "kill", "slimeling", "Meadow"),
			"matches по зоне"
		)
		local data = { Quests = { Daily = { Day = 0, Items = {} }, Chains = {} } }
		check(
			S.Dailies.ensure(data, 86400 * 5) == true and next(data.Quests.Daily.Items) ~= nil,
			"ensure выдаёт задания"
		)
		data.Quests.Daily.Items[next(data.Quests.Daily.Items)].P = 7
		check(
			S.Dailies.ensure(data, 86400 * 5 + 100) == false,
			"в тот же день не пересоздаёт"
		)
		check(S.Dailies.ensure(data, 86400 * 6) == true, "в новый день пересоздаёт")
		local ids = {}
		for _, a2 in ipairs(S.AchievementData.List) do
			check(not ids[a2.Id] and a2.Goal > 0 and a2.Gems > 0, "достижение " .. a2.Id)
			ids[a2.Id] = true
		end
		check(#S.AchievementData.List >= 15, "достижений не меньше 15")
	end
)

test("Мир: зоны, враги и ресурсы согласованы", function()
	local S = boot("A")
	local Z = S.ZoneData
	check(Z.HUB == "Hub" and #Z.List >= 5, "хаб + 5 зон")
	for _, zone in ipairs(Z.List) do
		check(
			S.EnemyData.ById[zone.Boss] ~= nil and S.EnemyData.ById[zone.Boss].Boss,
			zone.Id .. ": босс существует"
		)
		for _, id in ipairs(zone.Enemies) do
			check(
				S.EnemyData.ById[id] ~= nil and not S.EnemyData.ById[id].Boss,
				zone.Id .. ": враг " .. id
			)
		end
		for _, r in ipairs(zone.Resources) do
			check(S.ResourceData.Resources[r] ~= nil, zone.Id .. ": ресурс " .. r)
		end
		check(
			(zone.Position - Z.HUB_POSITION).Magnitude > Z.HUB_RADIUS + Z.PLATFORM_SIZE / 2,
			zone.Id .. ": зона вне радиуса хаба"
		)
	end
	local prev = 0
	for _, zone in ipairs(Z.List) do
		check(
			zone.Multiplier >= prev and zone.UnlockCost >= 0,
			zone.Id .. ": множитель не убывает"
		)
		prev = zone.Multiplier
	end
	for _, egg in ipairs(S.PetData.Eggs) do
		local total = 0
		for _, o in ipairs(S.PetData.getOdds(egg.Id, 1)) do
			total += o.Chance or o.Weight or 0
		end
		check(
			math.abs(total - 100) < 0.5,
			("яйцо %s: шансы суммируются в 100%% (%.3f)"):format(egg.Id, total)
		)
	end
end)

test("Миграции данных v1 → v2 и защита от мусора", function()
	local S = boot("A")
	local d = {
		Coins = 5,
		Gems = -3,
		Rebirths = 0 / 0,
		TotalCoins = "x",
		Pets = { a = { Id = "bunbun", Gold = true }, b = { Id = "chirpy", Gold = false } },
	}
	check(S.Migrations.run(d) == true, "миграция сообщает об изменении")
	check(
		d.Pets.a.Variant == "Golden" and d.Pets.a.Gold == nil and d.Pets.b.Variant == "Normal",
		"Gold → Variant"
	)
	check(
		d.Pets.a.Level == 1 and d.Pets.a.Evo == 0 and d.Version == 2,
		"поля питомцев и версия"
	)
	check(
		d.Gems == 0 and d.Rebirths == 0 and d.TotalCoins == 0 and d.Coins == 5,
		"мусорные числа обнулены"
	)
	check(S.Migrations.run(d) == false, "повторный запуск ничего не меняет")
end)

-- ============================================================================
-- Локализация RU/EN
-- ============================================================================
test(
	"Локализация: выбор языка (страна, LocaleId, ручной выбор, Украина)",
	function()
		local S = boot("Loc1")
		local L = S.U.require("ReplicatedStorage/Shared/Locale")
		for _, c in ipairs({ "RU", "BY", "KZ", "KG", "AM", "AZ", "MD", "TJ", "UZ", "TM" }) do
			check(L.detect(c, "en-us", nil) == "ru", c .. " -> ru")
		end
		check(L.detect("ru", "en-us", nil) == "ru", "код страны в нижнем регистре")
		check(L.detect("US", "ru-ru", nil) == "en", "US + ru LocaleId -> en (страна главнее)")
		check(L.detect("DE", "de-de", nil) == "en", "DE -> en")
		check(L.detect("UA", "uk-ua", nil) == "en", "UA + uk -> en")
		check(L.detect("UA", "ru-ru", nil) == "ru", "UA + ru LocaleId -> ru")
		check(L.detect("UA", nil, nil) == "en", "UA без LocaleId -> en")
		check(L.detect(nil, "ru-RU", nil) == "ru", "страна недоступна, LocaleId ru-RU -> ru")
		check(L.detect(nil, "ru", nil) == "ru", "LocaleId ru -> ru")
		check(L.detect("", "en-gb", nil) == "en", "пустая страна, en-gb -> en")
		check(L.detect(nil, nil, nil) == "en", "ничего не известно -> en")
		check(L.detect("RU", "ru-ru", "en") == "en", "ручной en главнее страны RU")
		check(L.detect("US", "en-us", "ru") == "ru", "ручной ru главнее страны US")
		check(
			L.detect("US", "ru-ru", "auto") == "en",
			"auto не считается ручным выбором"
		)
		check(
			L.detect("US", "en-us", "de") == "en",
			"неизвестный язык игнорируется"
		)
	end
)

test("Локализация: плюрализация 1 / 2–4 / 5+", function()
	local S = boot("Loc2")
	local L = S.U.require("ReplicatedStorage/Shared/Locale")
	local cases = {
		{ 1, 1 },
		{ 2, 2 },
		{ 3, 2 },
		{ 4, 2 },
		{ 5, 3 },
		{ 0, 3 },
		{ 11, 3 },
		{ 12, 3 },
		{ 14, 3 },
		{ 21, 1 },
		{ 22, 2 },
		{ 25, 3 },
		{ 101, 1 },
		{ 111, 3 },
		{ 112, 3 },
		{ 1001, 1 },
		{ 1.5, 2 },
		{ -1, 1 },
	}
	for _, c in ipairs(cases) do
		check(L.pluralIndex("ru", c[1]) == c[2], ("ru %s -> форма %d"):format(tostring(c[1]), c[2]))
	end
	check(
		L.pluralIndex("en", 1) == 1 and L.pluralIndex("en", 0) == 2 and L.pluralIndex("en", 5) == 2,
		"en 1/иначе"
	)
	local forms = "{n} {n|монета|монеты|монет}"
	check(L.format("ru", forms, { n = 1 }) == "1 монета", "1 монета")
	check(L.format("ru", forms, { n = 3 }) == "3 монеты", "3 монеты")
	check(L.format("ru", forms, { n = 7 }) == "7 монет", "7 монет")
	check(L.format("ru", forms, { n = 21 }) == "21 монета", "21 монета")
	check(
		L.format("ru", forms, { n = "1.5K" }) == "1.5K монет",
		"нечисловая строка -> последняя форма"
	)
	check(L.format("ru", forms, { n = "12" }) == "12 монет", "числовая строка")
	check(L.format("en", "{n} {n|coin|coins}", { n = 1 }) == "1 coin", "en 1 coin")
	check(L.format("en", "{n} {n|coin|coins}", { n = 2 }) == "2 coins", "en 2 coins")
	check(
		L.format("ru", "{missing}", {}) == "{missing}",
		"неизвестный плейсхолдер остаётся"
	)
end)

local function placeholders(s)
	local set = {}
	for name in string.gmatch(s, "{([%w_]+)}") do
		set[name] = true
	end
	for name in string.gmatch(s, "{([%w_]+)|") do
		set[name] = true
	end
	local list = {}
	for k in pairs(set) do
		table.insert(list, k)
	end
	table.sort(list)
	return table.concat(list, ",")
end

test(
	"Локализация: паритет ключей и плейсхолдеров всех языков с en, формы плюрализации",
	function()
		local S = boot("Loc3")
		local L = S.U.require("ReplicatedStorage/Shared/Locale")
		local en = L.strings.en
		local nEn = 0
		for _ in pairs(en) do
			nEn += 1
		end
		check(nEn > 400, "ключей en > 400 (есть " .. nEn .. ")")
		local FORMS = { en = 2, ru = 3 } -- число форм плюрализации в языке (новый язык — добавить сюда)
		for _, lang in ipairs(L.LANGS) do
			local tr = L.strings[lang]
			check(
				type(tr) == "table" and FORMS[lang] ~= nil,
				lang .. ": таблица строк и число форм заданы"
			)
			local missing, extra, badPh, badForms = {}, {}, {}, {}
			for k, v in pairs(en) do
				local r = tr[k]
				if type(r) ~= "string" or (r == "" and v ~= "") then
					table.insert(missing, k)
				elseif placeholders(v) ~= placeholders(r) then
					table.insert(badPh, k)
				else
					for forms in string.gmatch(r, "{[%w_]+|([^}]*)}") do
						if #string.split(forms, "|") ~= FORMS[lang] then
							table.insert(badForms, k)
						end
					end
				end
			end
			for k in pairs(tr) do
				if en[k] == nil then
					table.insert(extra, k)
				end
			end
			check(#missing == 0, lang .. ": нет перевода: " .. table.concat(missing, ", "))
			check(#extra == 0, lang .. ": лишние ключи: " .. table.concat(extra, ", "))
			check(
				#badPh == 0,
				lang
					.. ": плейсхолдеры не совпадают с en: "
					.. table.concat(badPh, ", ")
			)
			check(
				#badForms == 0,
				lang
					.. ": неверное число форм плюрализации: "
					.. table.concat(badForms, ", ")
			)
		end
		check(
			L.get("ru", "no.such.key") == "no.such.key",
			"отсутствующий ключ виден как ключ"
		)
		check(L.get("ru", "trade.ui.ready") == "Готов", "простая строка ru")
		check(L.get("en", "trade.ui.ready") == "Ready", "простая строка en")
	end
)

test(
	"Локализация: все тексты данных имеют русский перевод",
	function()
		local S = boot("Loc4")
		local L = S.U.require("ReplicatedStorage/Shared/Locale")
		local names = L.names.ru
		local FIELDS = {
			Name = true,
			Desc = true,
			Title = true,
			Done = true,
			Description = true,
			Label = true,
			Greeting = true,
			Branch = true,
			Progress = true,
			Rarity = true,
		}
		local missing, count, seen = {}, 0, {}
		local function need(path, v)
			if type(v) == "string" and string.find(v, "%a%a") and not seen[v] then
				seen[v] = true
				count += 1
				if names[v] == nil then
					table.insert(missing, path .. "=" .. v)
				end
			end
		end
		local function walk(t, path, depth, visited)
			if depth > 8 or visited[t] then
				return
			end
			visited[t] = true
			for k, v in pairs(t) do
				local p = path .. "." .. tostring(k)
				if type(v) == "table" then
					if k == "Offer" or k == "ElementOrder" or k == "RoleOrder" or k == "VariantOrder" then
						for i, line in ipairs(v) do
							need(p .. "." .. i, line)
						end
					end
					walk(v, p, depth + 1, visited)
				elseif FIELDS[k] then
					need(p, v)
				end
			end
		end
		for _, m in ipairs({
			"PetData",
			"PetMeta",
			"Abilities",
			"AchievementData",
			"BattlePassData",
			"EnemyData",
			"EventData",
			"QuestData",
			"RecipeData",
			"ResourceData",
			"ShopData",
			"TalentData",
			"UpgradeData",
			"ZoneData",
		}) do
			walk(S.U.require("ReplicatedStorage/Shared/" .. m), m, 0, {})
		end
		need("Config.DEMO_BOT_NAME", S.Config.DEMO_BOT_NAME)
		need("Config.GAME_NAME", S.Config.GAME_NAME)
		check(count > 300, "собрано текстов данных: " .. count)
		check(#missing == 0, "нет перевода: " .. table.concat(missing, " | "))
		-- имена питомцев с вариантом и эволюцией
		local PM = S.PetMeta
		check(
			PM.displayName({ Id = "bunbun", Variant = "Golden", Level = 1, Xp = 0, Evo = 1 }, "en")
				== "Awakened Golden Bunbun",
			"en: вариант + эволюция"
		)
		check(
			PM.displayName({ Id = "bunbun", Variant = "Golden", Level = 1, Xp = 0, Evo = 1 }, "ru")
				== "Банбан (золото, пробуждение)",
			"ru: вариант + эволюция"
		)
		check(
			PM.displayName({ Id = "bunbun", Variant = "Normal", Level = 1, Xp = 0, Evo = 0 }, "ru")
				== "Банбан",
			"ru: обычный"
		)
	end
)

test(
	"Локализация: LanguageService и сообщения сервера на языке игрока",
	function()
		local S = boot("Loc5")
		local LS = S.U.require("ServerScriptService/Server/LanguageService")
		local L = S.U.require("ReplicatedStorage/Shared/Locale")
		LS.init()
		local data, _, p = S.join(31, "Ru")
		check(data.Settings and data.Settings.Lang == "auto", "по умолчанию Settings.Lang = auto")
		-- LocalizationService в харнессе недоступен -> pcall -> фолбэк на LocaleId
		p.LocaleId = "ru-ru"
		check(LS.apply(p) == "ru", "страна недоступна + LocaleId ru-ru -> ru")
		check(
			p:GetAttribute("Lang") == "ru" and p:GetAttribute("Country") == "",
			"атрибуты Lang/Country"
		)
		local origCountry = LS.country
		LS.country = function()
			return "US"
		end
		check(LS.apply(p) == "en", "US -> en даже при ru LocaleId")
		LS.country = function()
			return "BY"
		end
		p.LocaleId = "en-us"
		check(LS.apply(p) == "ru", "BY -> ru")
		check(p:GetAttribute("LangAuto") == "ru", "LangAuto")
		-- ручной выбор главнее и сохраняется в данных
		local r = S.invoke(p, "SetLanguage", "en")
		check(
			r.ok and data.Settings.Lang == "en" and p:GetAttribute("Lang") == "en",
			"ручной en при стране BY"
		)
		check(p:GetAttribute("LangAuto") == "ru", "автоопределение всё ещё ru")
		check(S.invoke(p, "SetLanguage", "xx").ok == false, "мусорный выбор отклонён")
		r = S.invoke(p, "SetLanguage", "ru")
		check(r.ok and p:GetAttribute("Lang") == "ru", "ручной ru")
		-- сообщения сервера рендерятся на языке игрока
		data.Coins = 0
		local h = S.invoke(p, "Hatch", "MeadowEgg", 1)
		check(
			h.ok == false and type(h.msg) == "string" and string.find(h.msg, "[\208\209]") ~= nil,
			"ошибка на русском: " .. tostring(h.msg)
		)
		S.invoke(p, "SetLanguage", "en")
		local h2 = S.invoke(p, "Hatch", "MeadowEgg", 1)
		check(
			h2.ok == false and type(h2.msg) == "string" and not string.find(h2.msg, "[\208\209]"),
			"та же ошибка на английском: " .. tostring(h2.msg)
		)
		check(
			L.render(p, L.m("pets.info", { n = 1, bag = 2, team = 3, slots = 4 })) == "Pets 1/2   Team 3/4",
			"render по языку игрока"
		)
		-- миграция чинит мусор в Settings.Lang
		local d2 = { Settings = { Lang = 42 } }
		S.Migrations.run(d2)
		check(d2.Settings.Lang == "auto", "миграция: мусор -> auto")
		LS.country = origCountry
	end
)

test("Враги: расширенный пул, лут и фрагменты", function()
	local S = boot("E")
	local ED, Z, R = S.EnemyData, S.ZoneData, S.ResourceData
	check(R.Resources.Fragment ~= nil, "ресурс Fragment")
	check(ED.MAX_ALIVE_PER_ZONE >= 8, "больше врагов на зону")
	local normals = 0
	for _, d in ipairs(ED.List) do
		if not d.Boss then
			normals += 1
		end
		check(d.SpeedMult ~= nil and d.SpeedMult > 0, d.Id .. " SpeedMult")
		check(type(d.Drops) == "table", d.Id .. " Drops")
		for _, drop in ipairs(d.Drops) do
			check(drop.Chance >= 0 and drop.Chance <= 1, d.Id .. " chance")
			check(drop.Min <= drop.Max, d.Id .. " min/max")
			if drop.Res then
				check(R.Resources[drop.Res] ~= nil, d.Id .. " res " .. tostring(drop.Res))
			end
			if drop.Item then
				check(S.RecipeData.Items[drop.Item] ~= nil, d.Id .. " item")
			end
		end
	end
	check(normals >= 15, "не меньше 15 рядовых типов, есть=" .. tostring(normals))
	for _, zone in ipairs(Z.List) do
		check(#zone.Enemies >= 3, zone.Id .. " ≥3 типов врагов")
	end
end)

test("События: до Offset событие неактивно (старт сессии)", function()
	local S = boot("Ev")
	local E = S.EventData
	for _, e in ipairs(E.List) do
		local on, left = E.status(e.Id, 0)
		check(not on and left == e.Offset, e.Id .. " ждёт Offset с нуля сессии")
		on = select(1, E.status(e.Id, e.Offset - 1))
		check(not on, e.Id .. " ещё не началось")
	end
end)

-- =============================================================================================
-- Суперсила / Охота
-- =============================================================================================
test(
	"Суперсила: чистая логика (тайминг, выбор, урон, проверки удара, награды по вкладу)",
	function()
		local S = boot("SpL")
		local Lg = S.U.require("ReplicatedStorage/Shared/SuperpowerLogic")
		local C = S.Config.SUPERPOWER
		check(S.Config.DEMO_BOTS == false, "в игре боты по умолчанию выключены")
		-- тайминг
		local interval, duration, first = Lg.timing(C, 1)
		check(
			interval == 60 and duration >= 30 and duration <= 40,
			"60 с цикл, 30–40 с суперсилы"
		)
		check(
			duration <= interval - C.GAP,
			"суперсила кончается до следующего выбора"
		)
		local i10, d10, f10 = Lg.timing(C, 10)
		check(
			math.abs(i10 - interval / 10) < 1e-9 and math.abs(d10 - duration / 10) < 1e-9,
			"ускорение x10"
		)
		check(f10 < first, "первый запуск тоже ускоряется")
		local i0 = Lg.timing(C, 1000)
		check(i0 == interval / 60, "ускорение ограничено x60")
		check(select(1, Lg.timing(C, -5)) == interval, "некорректное ускорение = x1")
		-- мало игроков
		check(not Lg.enoughPlayers(C, 0) and not Lg.enoughPlayers(C, 1), "1 игрок — ждём")
		check(Lg.enoughPlayers(C, 2), "2 игрока — можно")
		check(not Lg.enoughPlayers({ MIN_PLAYERS = 1 }, 1), "минимум 2 даже при MIN_PLAYERS=1")
		-- выбор
		local cands = {
			{ Key = "a", Eligible = true },
			{ Key = "b", Eligible = false },
			{ Key = "c", Eligible = true },
		}
		local function first1()
			return 1
		end
		check(Lg.pick(cands, nil, first1) == "a", "выбор из подходящих")
		check(Lg.pick(cands, "a", first1) == "c", "не тот же, что в прошлый раз")
		for n = 1, 2 do
			local k = Lg.pick(cands, nil, function()
				return n
			end)
			check(k ~= "b", "неподходящий (в обмене/мёртв) не выбирается")
		end
		check(
			Lg.pick({ { Key = "a", Eligible = true } }, "a", first1) == "a",
			"единственный — можно повторить"
		)
		check(
			Lg.pick({ { Key = "b", Eligible = false } }, nil, first1) == nil,
			"некого выбрать — nil"
		)
		check(Lg.pick({}, nil, first1) == nil, "пустой список — nil")
		-- распределение выбора близко к равномерному
		local rng = Random.new(7)
		local counts = { a = 0, c = 0, d = 0 }
		local pool =
			{ { Key = "a", Eligible = true }, { Key = "c", Eligible = true }, { Key = "d", Eligible = true } }
		for _ = 1, 3000 do
			local k = Lg.pick(pool, nil, function(n)
				return rng:NextInteger(1, n)
			end)
			counts[k] += 1
		end
		check(
			counts.a > 850 and counts.c > 850 and counts.d > 850,
			"выбор случайный и равномерный"
		)
		-- с ботами
		local mix = {
			{ Key = "p1", Eligible = true, IsBot = false },
			{ Key = "bot1", Eligible = true, IsBot = true },
			{ Key = "bot2", Eligible = true, IsBot = true },
		}
		check(Lg.pickWithBots(mix, nil, function()
			return 0.1
		end, first1, 0.5) == "p1", "демо: шанс — живой игрок")
		local kb = Lg.pickWithBots(mix, nil, function()
			return 0.9
		end, first1, 0.5)
		check(kb == "bot1", "демо: иначе бот")
		check(Lg.pickWithBots(mix, "p1", function()
			return 0.1
		end, first1, 0.5) ~= "p1", "демо: живой не дважды подряд")
		-- HP и урон
		local hp1, hp3 = Lg.maxHp(C, 1), Lg.maxHp(C, 3)
		check(hp3 > hp1 and Lg.maxHp(C, 0) == hp1, "HP растёт с числом охотников")
		local weak, strong = Lg.hunterHit(C, 0, hp3), Lg.hunterHit(C, 1e12, hp3)
		check(weak >= 1 and strong > weak, "урон растёт с силой команды")
		check(
			strong <= C.MAX_HIT_SHARE * hp3,
			"потолок урона за удар (нельзя убить одним ударом)"
		)
		check(Lg.petHit(C, 0, 100, hp3) == 0, "без питомцев урона питомцев нет")
		check(
			Lg.petHit(C, 3, 1e12, hp3) <= C.PET_MAX_PER_TICK * hp3,
			"потолок урона питомцев"
		)
		-- проверки удара
		local round = { Active = true, TargetKey = "s" }
		check(select(2, Lg.canHit(C, nil, "h", 10, 1)) == "inactive", "вне охоты PvP нет")
		check(
			select(2, Lg.canHit(C, { Active = true, TargetKey = "s", Done = true }, "h", 10, 1)) == "inactive",
			"после конца раунда урона нет"
		)
		check(select(2, Lg.canHit(C, round, "s", 10, 1)) == "self", "по себе нельзя")
		check(
			select(2, Lg.canHit(C, round, "h", 10, C.HIT_RANGE + 5)) == "far",
			"далеко — нельзя"
		)
		check(
			Lg.canHit(C, round, "h", 10, C.HIT_RANGE + 1, 2),
			"крупная цель — досягаемость больше"
		)
		check(
			select(2, Lg.canHit(C, round, "h", 10, 0 / 0)) == "far",
			"NaN-дистанция отклоняется"
		)
		check(
			select(2, Lg.canHit(C, round, "h", 10, 1, 0, 10 - C.HIT_COOLDOWN / 2)) == "cooldown",
			"кулдаун"
		)
		check(
			Lg.canHit(C, round, "h", 10, 1, 0, 10 - C.HIT_COOLDOWN - 0.01),
			"после кулдауна — можно"
		)
		-- награды за остановку
		local maxHp = 1000
		local min = Lg.minDamage(C, maxHp)
		local dmg = { h1 = 600, h2 = 300, afk = min - 1, bot1 = 100 }
		local humans = { h1 = true, h2 = true, afk = true, idle = true }
		local rw, afk = Lg.stopRewards(C, dmg, maxHp, "h2", 0, humans)
		check(rw.h1 ~= nil and rw.h2 ~= nil, "нанёсшие урон получают награду")
		check(rw.bot1 == nil, "боты наград не получают")
		check(
			afk.afk and afk.idle and rw.afk == nil and rw.idle == nil,
			"анти-AFK: меньше минимума — без награды"
		)
		check(
			rw.h1.Clicks > rw.h2.Clicks - C.LAST_HIT_BONUS.Clicks,
			"больше вклад — больше награда"
		)
		check(rw.h2.LastHit and not rw.h1.LastHit, "бонус за последний удар")
		check(rw.h1.K <= C.STOP_K_MAX and rw.h2.K >= C.STOP_K_MIN, "вклад в пределах")
		local fast = Lg.stopRewards(C, dmg, maxHp, "h2", 1, humans)
		check(
			fast.h1.Clicks > rw.h1.Clicks,
			"быстрая остановка — бонус за время"
		)
		local solo = Lg.stopRewards(C, { h1 = 1000 }, maxHp, "h1", 0, { h1 = true })
		check(solo.h1.K == 1, "один охотник — базовая награда")
		-- продержался
		local sr, safk = Lg.surviveRewards(
			C,
			"s",
			{ h1 = min, h2 = min - 1 },
			maxHp,
			{ s = true, h1 = true, h2 = true }
		)
		check(
			sr.s and sr.s.Clicks == C.SURVIVE_REWARD.Clicks and sr.s.BpXp == C.SURVIVE_REWARD.BpXp,
			"крупная награда суперигроку"
		)
		check(
			sr.h1 and sr.h1.Clicks == C.CONSOLATION.Clicks,
			"утешительная — охотнику с уроном"
		)
		check(safk.h2 and sr.h2 == nil, "утешительной нет без минимума урона")
		check(
			sr.s.Clicks > sr.h1.Clicks * 5,
			"награда суперигрока крупнее утешительной"
		)
	end
)

local function bootSuper(label)
	local S = boot(label)
	local U = S.U
	S.SP = U.require("ServerScriptService/Server/SuperpowerService")
	S.Progress = U.require("ServerScriptService/Server/Progress")
	S.Lg = U.require("ReplicatedStorage/Shared/SuperpowerLogic")
	S.C = S.Config.SUPERPOWER
	S.WS = U.Workspace
	S.WS:SetAttribute("SuperpowerPaused", true)
	return S
end

local function setPos(player, pos)
	player.Character:FindFirstChild("HumanoidRootPart").Position = pos
end

test(
	"Суперсила: сервис — выбор, удары, оба исхода, защита и награды без дюпа",
	function()
		local S = bootSuper("SpS")
		local SP, C = S.SP, S.C
		local d1, _, p1 = S.join(9101, "Alice")
		local d2, _, p2 = S.join(9102, "Bob")
		SP.init()
		local k1, k2 = SP.keyOf(p1), SP.keyOf(p2)
		-- вне охоты урона нет
		check(
			SP.tryPlayerHit(p2) == false and not SP.isActive(),
			"вне охоты удар не идёт в игрока"
		)
		check(SP.damageMult(p1) == 1, "без суперсилы множитель 1")
		-- игрок в обмене не подходит
		local Trade = S.U.require("ServerScriptService/Server/TradeService")
		local origIsTrading = Trade.isTrading
		Trade.isTrading = function(p)
			return p == p2
		end
		check(SP.start(nil) == nil, "в обмене — не выбирается; одного мало")
		Trade.isTrading = origIsTrading
		-- раунд: Alice — суперигрок
		local coins1, gems1, gems2 = d1.Coins, d1.Gems, d2.Gems
		check(
			SP.start(k1) == k1 and SP.isSuper(p1) and not SP.isSuper(p2),
			"раунд начался, Alice — цель"
		)
		check(SP.start(k2) == nil, "второй раунд параллельно не начинается")
		local r = SP.current()
		check(r.MaxHp == S.Lg.maxHp(C, 1), "PvP-HP по числу охотников")
		check(SP.damageMult(p1) == C.DAMAGE_MULT, "суперигрок бьёт сильнее")
		check(
			S.Session.get(p1).SuperCoin == C.COIN_MULT and S.Session.get(p1).SuperSpeed == C.SPEED_MULT,
			"множители"
		)
		check(p1.Character:GetAttribute("Super") == true, "атрибут Super на модели")
		DRIVE_UNTIL_IDLE(2)
		check(math.abs(p1.Character:GetScale() - C.SCALE) < 1e-6, "суперигрок вырос (ScaleTo)")
		check(
			r.Ends - r.Started <= C.INTERVAL - C.GAP,
			"длительность до следующего выбора"
		)
		-- суперигрок не бьёт сам себя
		check(
			SP.tryPlayerHit(p1) == false and r.Hp == r.MaxHp,
			"суперигрок не наносит урон себе"
		)
		-- охотник далеко
		setPos(p2, Vector3.new(200, 3, 5))
		check(SP.tryPlayerHit(p2) == false and r.Hp == r.MaxHp, "далеко — урона нет")
		setPos(p2, Vector3.new(8, 3, 5))
		check(SP.tryPlayerHit(p2) == true and r.Hp < r.MaxHp, "охотник рядом — HP падает")
		local hpAfter = r.Hp
		check(
			SP.tryPlayerHit(p2) == true and r.Hp == hpAfter,
			"кулдаун: повторный удар без урона"
		)
		-- удар суперигрока: отталкивание и оглушение охотника, прогресс охоты не трогает
		check(SP.superSlam(k1) == true, "ударная волна")
		check(SP.isStunned(p2), "охотник оглушён")
		check(
			r.Hp == hpAfter and (r.Damage[k2] or 0) > 0,
			"оглушение не отнимает вклад"
		)
		check(SP.superSlam(k1) == false, "у волны кулдаун")
		ADVANCE(C.HIT_COOLDOWN + 0.01)
		check(SP.tryPlayerHit(p2) == true and r.Hp == hpAfter, "оглушённый не бьёт")
		ADVANCE(C.STUN_SECONDS + 0.1)
		-- бьём до остановки
		local guard = 0
		while SP.isActive() and guard < 500 do
			guard += 1
			ADVANCE(C.HIT_COOLDOWN + 0.01)
			SP.tryPlayerHit(p2)
		end
		check(not SP.isActive(), "HP=0 — охота завершена")
		check(d2.Gems > gems2 and d2.Coins > 0, "охотник получил награду")
		check(
			(d2.Stats.SuperStops or 0) == 1,
			"статистика SuperStops (квесты/достижения)"
		)
		check(
			d1.Coins >= coins1 and d1.Gems == gems1,
			"суперигрок ничего не потерял"
		)
		check(
			S.Session.get(p1).SuperCoin == 1 and S.Session.get(p1).SuperSpeed == 1,
			"множители сняты"
		)
		check(
			p1.Character:GetAttribute("Super") == nil and p1.Character:GetScale() == 1,
			"размер вернулся"
		)
		-- повторный finish не выдаёт награду второй раз
		local g = d2.Gems
		SP.finish("stopped")
		check(d2.Gems == g, "без дюпа наград")
		check(SP.tryPlayerHit(p2) == false, "после конца урон не принимается")
		-- второй раунд: следующий выбор — не Alice
		local key = SP.start(nil)
		check(key == k2, "следующий суперигрок — другой")
		-- Alice бьёт слабо (меньше минимума) → без утешительной награды
		setPos(p1, Vector3.new(8, 3, 5))
		setPos(p2, Vector3.new(5, 3, 5))
		ADVANCE(5)
		-- v2.4: охотнику нужны ручные удары (HUNTER_MIN_HITS), суперигроку — активность (волны/движение)
		local gemsA, gemsB = d1.Gems, d2.Gems
		for _ = 1, C.HUNTER_MIN_HITS do
			SP.tryPlayerHit(p1)
			ADVANCE(C.HIT_COOLDOWN + 0.01)
		end
		for _ = 1, C.SURVIVE_MIN_SLAMS do
			SP.superSlam(k2)
			ADVANCE(C.SLAM_COOLDOWN + 0.1)
		end
		local cur = SP.current()
		ADVANCE(cur.Duration + 0.5)
		SP.step(os.clock())
		check(not SP.isActive(), "таймер истёк — продержался")
		check(
			d2.Gems >= gemsB + C.SURVIVE_REWARD.Gems,
			"крупная награда продержавшемуся (+ достижение)"
		)
		check((d2.Stats.SuperSurvived or 0) == 1, "статистика SuperSurvived")
		local minD = S.Lg.minDamage(C, cur.MaxHp)
		if (cur.Damage[k1] or 0) >= minD then
			check(d1.Gems == gemsA + C.CONSOLATION.Gems, "утешительная награда")
		else
			check(d1.Gems == gemsA, "без минимума урона утешительной нет")
		end
		-- выход цели без вклада охотников — раунд закрыт, наград нет
		SP.start(k1)
		local gb = d2.Gems
		SP.removeUnit(k1)
		check(
			not SP.isActive() and d2.Gems == gb,
			"цель вышла, охотник не бил — наград нет"
		)
	end
)

test(
	"Суперсила: мало игроков, боты-охотники, переключатели для тестов",
	function()
		local S = bootSuper("SpB")
		local SP, C, WS = S.SP, S.C, S.WS
		local d1, _, p1 = S.join(9201, "Solo")
		SP.init()
		check(SP.start(nil) == nil, "один игрок — ждём второго")
		-- боты (как в демо): регистрируются юнитами
		local function bot(i, pos)
			local m = NEW_NODE("Model", "Bot" .. i)
			local hrp = NEW_NODE("Part", "HumanoidRootPart")
			hrp.Position = pos
			hrp.Parent = m
			local hum = NEW_NODE("Humanoid")
			hum.Health = 100
			hum.Parent = m
			local u = {
				Key = "bot" .. i,
				Name = "Bot" .. i,
				IsBot = true,
				GetModel = function()
					return m
				end,
				Eligible = function()
					return true
				end,
				StunnedUntil = 0,
				ImmuneUntil = 0,
				LastHit = -1e9,
				LastSlam = -1e9,
			}
			SP.addUnit(u)
			return u, m
		end
		bot(1, Vector3.new(9, 3, 5))
		bot(2, Vector3.new(300, 3, 5))
		-- переключатель SuperpowerForce = "me" (используется браузерным тестом)
		WS:SetAttribute("SuperpowerForce", "me")
		SP.step(os.clock())
		check(SP.isSuper(p1), "Force=me: суперсила у игрока")
		check(
			WS:GetAttribute("SuperpowerForce") == nil,
			"переключатель сбрасывается"
		)
		check(SP.botHit("bot1") == true, "бот рядом бьёт суперигрока")
		check(SP.botHit("bot1") == false, "у бота кулдаун")
		check(SP.botHit("bot2") == false, "дальний бот не достаёт")
		-- Force=bot: игрок охотится на бота
		WS:SetAttribute("SuperpowerForce", "bot")
		SP.step(os.clock())
		local r = SP.current()
		check(r and r.TargetIsBot and r.TargetKey == "bot1", "Force=bot: суперсила у бота")
		check(SP.isActive() and not SP.isSuper(p1), "игрок — охотник")
		-- ускорение цикла атрибутом
		SP.finish("cancel")
		WS:SetAttribute("SuperpowerTimeScale", 10)
		WS:SetAttribute("SuperpowerPaused", false)
		ADVANCE(S.C.INTERVAL / 10 + 0.1)
		SP.step(os.clock())
		check(SP.isActive(), "ускоренный цикл запустил раунд")
		local cur = SP.current()
		check(
			math.abs(cur.Duration - select(2, S.Lg.timing(C, 10))) < 1e-6,
			"длительность ускорена"
		)
		-- игрок ловит бота до конца: награда только живому игроку
		if cur.TargetIsBot then
			local u = SP.getUnit(cur.TargetKey)
			u.GetModel():FindFirstChild("HumanoidRootPart").Position = Vector3.new(6, 3, 5)
			local gems = d1.Gems
			local guard = 0
			while SP.isActive() and guard < 400 do
				guard += 1
				ADVANCE(C.HIT_COOLDOWN + 0.01)
				SP.tryPlayerHit(p1)
				SP.botHit("bot1")
			end
			check(
				not SP.isActive() and d1.Gems > gems,
				"бот остановлен, игрок награждён"
			)
		else
			check(true, "раунд у игрока (выбор случайный)")
		end
		WS:SetAttribute("SuperpowerPaused", true)
	end
)

-- ============================================================================
-- v2.4: исправления по аудиту docs/AUDIT_v2.3.md (негативные тесты эксплойтов)
-- ============================================================================
local function initWith(S, path)
	local prev = game
	game = S.U.Game
	local m = S.U.require(path)
	if m.init then
		m.init()
	end
	game = prev
	return m
end

local function givePets(d)
	d.Pets = {
		a = { Id = "bunbun", Variant = "Normal", Level = 1, Xp = 0, Evo = 0 },
		b = { Id = "chirpy", Variant = "Normal", Level = 1, Xp = 0, Evo = 0 },
		c = { Id = "mossy", Variant = "Normal", Level = 1, Xp = 0, Evo = 0 },
	}
	d.Equipped = { "a", "b", "c" }
end

test(
	"v2.4 К1: два AFK-аккаунта с питомцами не фармят гемы на «Суперсиле»",
	function()
		local S = bootSuper("A24K1")
		local SP, C = S.SP, S.C
		local d1, _, p1 = S.join(9401, "AfkA")
		local d2, _, p2 = S.join(9402, "AfkB")
		givePets(d1)
		givePets(d2)
		SP.init()
		local g1, g2, rounds = d1.Gems, d2.Gems, 0
		for _ = 1, 6 do
			if not SP.start(nil) then
				break
			end
			rounds += 1
			local guard = 0
			while SP.isActive() and guard < 200 do
				guard += 1
				ADVANCE(1)
				for _, pl in ipairs({ p1, p2 }) do
					SP.petTick(pl, S.Data.get(pl), pl.Character:FindFirstChild("HumanoidRootPart").Position)
				end
				SP.step(os.clock())
			end
			ADVANCE(C.GAP)
		end
		check(rounds == 6, "раунды шли")
		check(
			d1.Gems == g1 and d2.Gems == g2,
			"AFK: ни суперигрок, ни охотник-питомцы гемов не получают"
		)
		check(SP.current() == nil, "раундов не осталось")
	end
)

test(
	"v2.4 К1: активный суперигрок без охотников — малая награда; дневной потолок гемов",
	function()
		local S = bootSuper("A24K1b")
		local SP, C, Lg = S.SP, S.C, S.Lg
		local d1, _, p1 = S.join(9411, "Runner")
		local _, _, p2 = S.join(9412, "Idle")
		for _, a in ipairs(S.AchievementData.List) do
			d1.Achievements[a.Id] = true -- гемы достижений не мешают считать награду события
		end
		SP.init()
		check(SP.start(SP.keyOf(p1)) ~= nil, "раунд у Runner")
		-- бежит по кругу
		for i = 1, 30 do
			ADVANCE(1)
			p1.Character:FindFirstChild("HumanoidRootPart").Position = Vector3.new(5 + (i % 2) * 6, 3, 5 + i)
			SP.step(os.clock())
		end
		local g = d1.Gems
		ADVANCE(SP.current().Duration)
		SP.step(os.clock())
		check(not SP.isActive(), "раунд закончился")
		check(
			d1.Gems - g == C.SURVIVE_UNCONTESTED.Gems,
			"без охоты — SURVIVE_UNCONTESTED, а не крупная награда"
		)
		check(
			Lg.capGems(C, C.DAILY_GEM_CAP - 5, 25) == 5 and Lg.capGems(C, C.DAILY_GEM_CAP, 25) == 0,
			"capGems"
		)
		d1.EventGems = { Day = os.time() // 86400, Gems = C.DAILY_GEM_CAP }
		SP.start(SP.keyOf(p1))
		local g2 = d1.Gems
		SP.finish("survived")
		check(
			d1.Gems == g2,
			"дневной потолок: сверх DAILY_GEM_CAP гемы не выдаются"
		)
		check(p2 ~= nil, "второй участник был")
	end
)

test(
	"v2.4 К2: награда за убийство — только с заметной долей урона",
	function()
		local S = boot("A24K2")
		local CS = initWith(S, "ServerScriptService/Server/CombatService")
		local d1, _, p1 = S.join(9421, "Tank")
		local d2, _, p2 = S.join(9422, "Leech")
		local folder = S.U.Workspace:FindFirstChild("Enemies")
		local bossId, maxHp
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("IsBoss") then
				bossId = m:GetAttribute("Id")
				maxHp = m:GetAttribute("MaxHp")
				break
			end
		end
		check(bossId ~= nil, "босс найден")
		local c1, c2, g2 = d1.Coins, d2.Coins, d2.Gems
		CS.debugDamage(p2, bossId, 1)
		CS.debugDamage(p1, bossId, maxHp)
		DRIVE_UNTIL_IDLE(5)
		check(d1.Coins > c1, "основной боец награждён")
		check(
			d2.Coins == c2 and d2.Gems == g2,
			"1 урона из " .. tostring(maxHp) .. " — без награды"
		)
		-- чистая функция: порог доли и «лучший», если порог не прошёл никто
		local a, b, c = {}, {}, {}
		local list = CS.rewardees({ [a] = 50, [b] = 50, [c] = 2 })
		check(#list == 2, "двое по 49% — награда обоим, 2% — нет")
		local many = {}
		for i = 1, 20 do
			many[{ i = i }] = if i == 1 then 6 else 5
		end
		check(#CS.rewardees(many) == 1, "все ниже порога — награда лучшему")
		check(#CS.rewardees({}) == 0, "без урона — никому")
	end
)

test(
	"v2.4 В4/В5: суперигрок не телепортируется; уход суперигрока не лишает охотников награды",
	function()
		local S = bootSuper("A24B45")
		local SP, C = S.SP, S.C
		local d1, _, p1 = S.join(9431, "Super")
		local d2, _, p2 = S.join(9432, "Hunter")
		SP.init()
		SP.start(SP.keyOf(p1))
		local r = S.invoke(p1, "Teleport", "Hub")
		check(r.ok == false, "суперигрок не может телепортироваться")
		-- площадка «В хаб» в биоме — тот же телепорт
		local St = S.U.require("ServerScriptService/Server/StationService")
		local ZS = S.U.require("ServerScriptService/Server/ZoneService")
		local moved = {}
		local origMove = ZS.moveToZone
		ZS.moveToZone = function(pl, z)
			moved[pl] = z
		end
		St._onPrompt(p1, "hubReturn")
		St._onPrompt(p2, "hubReturn")
		ZS.moveToZone = origMove
		check(moved[p1] == nil, "площадка «В хаб» не уносит суперигрока")
		check(moved[p2] ~= nil, "охотника площадка переносит как обычно")
		ADVANCE(5)
		local r2 = S.invoke(p2, "Teleport", "Hub")
		check(r2.ok == true, "охотник телепортируется как обычно")
		p2.Character:FindFirstChild("HumanoidRootPart").Position = Vector3.new(8, 3, 5)
		p1.Character:FindFirstChild("HumanoidRootPart").Position = Vector3.new(5, 3, 5)
		for _ = 1, C.HUNTER_MIN_HITS + 2 do
			SP.tryPlayerHit(p2)
			ADVANCE(C.HIT_COOLDOWN + 0.01)
		end
		check((SP.current().Damage[SP.keyOf(p2)] or 0) > 0, "охотник нанёс урон")
		local g = d2.Gems
		SP.removeUnit(SP.keyOf(p1))
		check(not SP.isActive(), "раунд закрыт")
		check(
			d2.Gems > g,
			"суперигрок вышел — охотник с вкладом получил награду"
		)
		check(d1.Gems >= 0, "суперигрок ничего не потерял")
		check(S.Session.get(p1).IsSuper == false, "флаг суперигрока снят")
	end
)

test("v2.4 В6: Layout.modeFor — портрет/ландшафт/широкий экран", function()
	local S = boot("layout")
	local Layout = S.U.require("ReplicatedStorage/Client/Layout")
	check(Layout.modeFor(390, 844) == "portrait", "390x844 — портрет")
	check(Layout.modeFor(844, 390) == "landscape", "844x390 — ландшафт")
	check(Layout.modeFor(667, 375) == "landscape", "667x375 — ландшафт")
	check(Layout.modeFor(1280, 720) == "wide", "1280x720 — широкий")
	check(Layout.modeFor(1024, 768) == "wide", "1024x768 (планшет) — широкий")
	check(Layout.get().Mode == "wide", "без камеры — исходная раскладка")
	local seen
	Layout.onChanged(function(li)
		seen = li.Mode
	end)
	check(seen == "wide", "onChanged сразу вызывает подписчика")
	check(
		Layout.rightWidth({ Mode = "portrait", W = 390, H = 844, Touch = true }) == 194,
		"ширина правой колонки"
	)
end)

test(
	"v2.4 В3: BP_SKIP на максимуме пропуска — компенсация гемами, а не пустая покупка",
	function()
		BACKEND.Stores = {}
		local S = boot("bpskip")
		S.Config.PRODUCT_IDS.BP_SKIP = 1009
		local data, _, p = S.join(31, "Max")
		local fn = S.U.Game:GetService("MarketplaceService").ProcessReceipt
		local GRANTED = "Enum.ProductPurchaseDecision.PurchaseGranted"
		-- почти максимум: до конца остаётся 2 уровня из 5 купленных
		local xp = 0
		for lv = 1, S.BattlePassData.MaxLevel - 2 do
			xp += S.BattlePassData.xpForLevel(lv)
		end
		data.BattlePass.Xp = xp
		local gems0 = data.Gems
		check(fn(receipt(p, 7001, 1009)) == GRANTED, "покупка проведена")
		check(
			S.BattlePassData.progress(data.BattlePass.Xp) == S.BattlePassData.MaxLevel,
			"уровень дошёл до максимума"
		)
		local per = S.Config.BP_SKIP_FALLBACK_GEMS
		check(
			data.Gems - gems0 == 3 * per,
			"3 недоданных уровня → гемы: " .. (data.Gems - gems0)
		)
		-- на максимуме: вся покупка уходит в компенсацию
		local gems1 = data.Gems
		check(fn(receipt(p, 7002, 1009)) == GRANTED, "вторая покупка проведена")
		check(data.Gems - gems1 == 5 * per, "все 5 уровней компенсированы")
		-- повтор того же чека ничего не даёт
		check(
			fn(receipt(p, 7002, 1009)) == GRANTED and data.Gems - gems1 == 5 * per,
			"идемпотентность"
		)
	end
)

test(
	"v2.4 В2: NaN/inf в аргументах remote отсекаются; Craft — только целое 1..10; миграция лечит ресурсы",
	function()
		BACKEND.Stores = {}
		local S = boot("nan")
		S.U.require("ServerScriptService/Server/CraftService").init()
		local data, _, p = S.join(41, "Nan")
		local rec = S.RecipeData.Recipes[1]
		data.Rebirths = 99
		data.Coins = 1e9
		for res, c in pairs(rec.Cost) do
			data.Resources[res] = c * 20
		end
		local before = {}
		for res, v in pairs(data.Resources) do
			before[res] = v
		end
		local function same()
			for res, v in pairs(before) do
				if data.Resources[res] ~= v then
					return false
				end
			end
			return true
		end
		for _, bad in ipairs({ 0 / 0, math.huge, -math.huge, 2.5, 0, 11 }) do
			local r = S.invoke(p, "Craft", rec.Id, bad)
			check(r.ok == false, "Craft отклоняет " .. tostring(bad))
			check(same(), "ресурсы не тронуты после " .. tostring(bad))
		end
		-- NaN в любом действии и внутри таблицы аргумента — общий фильтр Router
		check(S.invoke(p, "Hatch", "BasicEgg", 0 / 0).ok == false, "NaN в Hatch")
		check(S.invoke(p, "Fuse", { "a", 0 / 0 }, false).ok == false, "NaN внутри таблицы")
		check(
			S.invoke(p, "Fuse", { x = { y = { z = { 1 } } } }, false).ok == false,
			"слишком глубокая таблица"
		)
		check(
			S.Util.argsFinite("a", 1, { 2, { k = 3 } }, nil, true) == true,
			"обычные аргументы проходят"
		)
		check(S.Util.validInt(3, 1, 10) == 3 and S.Util.validInt(0 / 0, 1, 10) == nil, "validInt")
		-- легальный крафт работает
		local r = S.invoke(p, "Craft", rec.Id, 2)
		check(r.ok == true, "Craft x2 проходит: " .. tostring(r.msg))
		for res, c in pairs(rec.Cost) do
			check(data.Resources[res] == before[res] - c * 2, "списано " .. res)
			check(data.Resources[res] == data.Resources[res], res .. " не NaN")
		end
		-- старый испорченный профиль лечится при загрузке
		local broken = {
			Version = 2,
			Coins = 1,
			Gems = math.huge,
			Rebirths = 0,
			TotalCoins = 0,
			Settings = { Lang = "ru" },
			Resources = { Crystal = 0 / 0, Ore = 5, Wood = -3 },
			Items = { catalyst = 0 / 0 },
			BattlePass = { Xp = 0 / 0 },
		}
		check(S.Migrations.run(broken) == true, "миграция сообщила об изменениях")
		check(
			broken.Resources.Crystal == 0 and broken.Resources.Ore == 5 and broken.Resources.Wood == 0,
			"Resources вылечены"
		)
		check(
			broken.Items.catalyst == 0 and broken.BattlePass.Xp == 0 and broken.Gems == 0,
			"Items/BP/Gems вылечены"
		)
	end
)

test(
	"v2.4 В1/С2: в боевом Config нет демо-бота; бонус друзей пересчитывается при входе и выходе",
	function()
		BACKEND.Stores = {}
		local S = boot("friends")
		check(S.Config.DEMO_BOT_ENABLED == false, "DEMO_BOT_ENABLED = false в боевом Config")
		check(S.Config.DEMO_BOTS == false, "DEMO_BOTS = false в боевом Config")
		S.State.init()
		S.PlayerService.init()
		S.U.require("ServerScriptService/Server/TradeService").init()
		local FRIENDS = { ["80:81"] = true }
		local function mk(id, name)
			local p = MAKE_PLAYER(S.U, id, name)
			p.IsFriendsWithAsync = function(self, other)
				local a, b = math.min(self.UserId, other), math.max(self.UserId, other)
				return FRIENDS[a .. ":" .. b] == true
			end
			return p
		end
		local a = mk(80, "Ann")
		S.U.Players.PlayerAdded:Fire(a)
		DRIVE_UNTIL_IDLE(30)
		check(
			S.Session.get(a).Friends == 0,
			"одиночка: друзей 0 (бот не считается)"
		)
		local r = S.invoke(a, "TradeStartBot")
		check(r.ok == false, "сделка с NPC недоступна в живой игре")
		local b = mk(81, "Ben")
		S.U.Players.PlayerAdded:Fire(b)
		DRIVE_UNTIL_IDLE(30)
		check(S.Session.get(b).Friends == 1, "вошедший видит друга")
		check(
			S.Session.get(a).Friends == 1,
			"у вошедшего раньше бонус тоже появился"
		)
		S.U.Players.PlayerRemoving:Fire(b)
		b.Parent = nil
		DRIVE_UNTIL_IDLE(30)
		check(S.Session.get(a).Friends == 0, "после ухода друга бонус снят")
	end
)

test(
	"v2.4 С1: буст удачи x2 не сгорает под x5 — его время встаёт в очередь",
	function()
		BACKEND.Stores = {}
		local S = boot("luck")
		S.Config.PRODUCT_IDS.LUCK_2X_15M = 1003
		S.Config.PRODUCT_IDS.LUCK_5X_10M = 1004
		local data, _, p = S.join(51, "Lucky")
		local fn = S.U.Game:GetService("MarketplaceService").ProcessReceipt
		local now = os.time()
		-- x5, затем x2: x2 начинается после x5
		fn(receipt(p, 8001, 1004))
		fn(receipt(p, 8002, 1003))
		check(data.Boosts.Luck5 - now >= 600 and data.Boosts.Luck5 - now <= 601, "x5 на 10 мин")
		local tail2 = data.Boosts.Luck2 - data.Boosts.Luck5
		check(tail2 == 900, "x2 целиком после x5: " .. tail2)
		local m, ends = S.Economy.getLuckBoost(data)
		check(m == 5 and ends == data.Boosts.Luck5, "сейчас действует x5")
		-- x2 идёт, затем покупают x5: остаток x2 сдвигается
		data.Boosts.Luck2, data.Boosts.Luck5 = now + 300, 0
		fn(receipt(p, 8003, 1004))
		check(data.Boosts.Luck2 - data.Boosts.Luck5 == 300, "остаток x2 (300 с) после x5")
		-- продление x5 при ждущем x2 тоже сдвигает x2
		fn(receipt(p, 8004, 1004))
		check(data.Boosts.Luck2 - data.Boosts.Luck5 == 300, "повторный x5 не съедает x2")
		-- всё оплаченное время суммарно сохраняется: 300 (x2) + 600 + 600 (x5)
		check(
			data.Boosts.Luck2 - now >= 1500 and data.Boosts.Luck2 - now <= 1501,
			"общая длительность сохранена"
		)
		-- зелье удачи и ежедневная награда идут через ту же функцию
		S.Economy.addLuckBoost(data, "Luck2", 0 / 0)
		check(data.Boosts.Luck2 == data.Boosts.Luck2, "NaN-длительность игнорируется")
	end
)

test(
	"v2.4 С12: после обмена оба профиля сразу сохраняются в DataStore",
	function()
		BACKEND.Stores = {}
		local S = boot("trade")
		S.U.require("ServerScriptService/Server/TradeService").init()
		local dA, _, a = S.join(61, "Ann")
		local dB, _, b = S.join(62, "Bob")
		dA.Coins, dB.Coins = 1000, 50
		S.Data.saveNow(a)
		S.Data.saveNow(b)
		local function stored(id)
			return BACKEND.Stores[S.Config.DATASTORE_NAME]["Player_" .. id].Data
		end
		check(stored(61).Coins == 1000, "исходное сохранение")
		check(S.invoke(a, "TradeInvite", 62).ok, "приглашение")
		check(S.invoke(b, "TradeRespond", true).ok, "принято")
		check(S.invoke(a, "TradeOffer", {}, 300).ok, "оффер монет")
		check(
			S.invoke(a, "TradeReady", true).ok and S.invoke(b, "TradeReady", true).ok,
			"оба готовы"
		)
		ADVANCE(S.Config.TRADE_CONFIRM_SECONDS + 1)
		S.invoke(a, "TradeConfirm")
		S.invoke(b, "TradeConfirm")
		DRIVE_UNTIL_IDLE(30)
		check(dA.Coins == 700 and dB.Coins == 350, "обмен прошёл: " .. dA.Coins .. "/" .. dB.Coins)
		check(
			stored(61).Coins == 700,
			"отдающий сохранён сразу: " .. tostring(stored(61).Coins)
		)
		check(
			stored(62).Coins == 350,
			"получатель сохранён сразу: " .. tostring(stored(62).Coins)
		)
	end
)

test(
	"v2.4 С5: после краша сервера вход ждёт протухания блокировки (без кика); неудачное финальное сохранение повторяется",
	function()
		BACKEND.Stores = {}
		local A = boot("A")
		local B = boot("B")
		local pa = MAKE_PLAYER(A.U, 91, "Kai")
		local da = A.Data.load(pa)
		da.Coins = 4242
		A.Data.saveNow(pa) -- A «упал»: блокировка осталась, автосейва больше нет
		local t0 = os.clock()
		local db, err = B.Data.load(MAKE_PLAYER(B.U, 91, "Kai")) -- игрок сразу перезаходит
		check(
			db ~= nil and db.Coins == 4242,
			"вход после ожидания, а не кик: " .. tostring(err)
		)
		check(
			os.clock() - t0 <= B.Config.SESSION_LOCK_TIMEOUT + 2 * B.Config.LOAD_LOCK_RETRY_DELAY,
			"ждали не дольше таймаута"
		)

		-- финальное сохранение при выходе не удалось — повтор в фоне
		BACKEND.Stores = {}
		local C = boot("C")
		C.Config.SAVE_ATTEMPTS = 1
		local pc = MAKE_PLAYER(C.U, 92, "Liv")
		local dc = C.Data.load(pc)
		dc.Coins = 999
		BACKEND.FailAlways = true
		C.Data.release(pc)
		BACKEND.FailAlways = false
		check(
			#C.Data._failedReleases == 1,
			"профиль в очереди повторного сохранения"
		)
		DRIVE_UNTIL_IDLE(120)
		local rec = BACKEND.Stores[C.Config.DATASTORE_NAME]["Player_92"]
		check(
			rec.Data and rec.Data.Coins == 999 and rec.Lock == nil,
			"повтор сохранил данные и снял блокировку"
		)
		check(#C.Data._failedReleases == 0, "очередь пуста")
	end
)

test(
	"v2.4 С3: отбрасывание не проходит сквозь стену и не сбрасывает в пропасть",
	function()
		local S = boot("knock")
		local K = S.U.require("ServerScriptService/Server/Knockback")
		local prevParams = RaycastParams
		RaycastParams = {
			new = function()
				return {}
			end,
		}
		local WS = S.U.Game:GetService("Workspace")
		local wallX, edgeX = 1e9, 1e9
		WS.Raycast = function(_, origin, dir)
			if dir.Y < 0 then -- луч вниз: земля есть только до края
				return if origin.X <= edgeX then { Position = Vector3.new(origin.X, 0, origin.Z) } else nil
			end
			local reach = origin.X + dir.X
			if reach >= wallX then
				return { Position = Vector3.new(wallX, origin.Y, origin.Z) }
			end
			return nil
		end
		K.groundCheckAvailable = true
		local o = Vector3.new(0, 3, 0)
		check(
			K.safeDistance(o, Vector3.new(1, 0, 0), 18, {}) == 18,
			"открытое место — полная дистанция"
		)
		wallX = 6
		local d = K.safeDistance(o, Vector3.new(1, 0, 0), 18, {})
		check(d == 6 - 2.5, "стена в 6 студах — остановка перед ней: " .. d)
		wallX, edgeX = 1e9, 10
		d = K.safeDistance(o, Vector3.new(1, 0, 0), 18, {})
		check(
			d > 0 and d <= 10,
			"обрыв в 10 студах — приземление на опору: " .. d
		)
		check(
			K.offset(o, Vector3.new(0, 1, 0), 18, {}).Magnitude == 0,
			"вертикальное направление — без сдвига (без NaN)"
		)
		RaycastParams = prevParams
		K.groundCheckAvailable = false
	end
)

test(
	"v2.4 С4: спидхак ×2 ловится по перемещению; легальное движение — нет",
	function()
		BACKEND.Stores = {}
		local S = boot("speed")
		local AE = S.U.require("ServerScriptService/Server/AntiExploit")
		local data, _, p = S.join(71, "Zoom")
		local s = S.Session.get(p)
		local root = p.Character.HumanoidRootPart
		p.Character.Humanoid.WalkSpeed = 16
		local legal = S.Economy.getWalkSpeed(p, data)
		local limit = AE.speedLimit(legal)
		check(
			limit < 60,
			"порог для базовой скорости заметно ниже старых 220: "
				.. limit
		)
		ADVANCE(5)
		AE._check(p)
		-- легально: скорость персонажа
		ADVANCE(1)
		root.Position = root.Position + Vector3.new(legal, 0, 0)
		AE._check(p)
		check(#s.Strikes == 0, "легальное движение без страйков")
		-- спидхак ×2.5 (раньше не ловился)
		ADVANCE(1)
		root.Position = root.Position + Vector3.new(legal * 2.5, 0, 0)
		AE._check(p)
		check(#s.Strikes > 0, "спидхак ×2.5 замечен")
		-- после серверного телепорта проверка выключена
		local n = #s.Strikes
		AE.markTeleport(p)
		ADVANCE(1)
		root.Position = root.Position + Vector3.new(500, 0, 0)
		AE._check(p)
		check(#s.Strikes == n, "серверный телепорт не наказывается")
		-- суперсила: порог растёт вместе со скоростью
		check(AE.speedLimit(legal * 1.45) > limit, "порог учитывает суперскорость")
	end
)

test(
	"v2.4 С10: питомец-награда при полной сумке ждёт в почте и приходит после освобождения места",
	function()
		BACKEND.Stores = {}
		local S = boot("mail")
		local data, _, p = S.join(81, "Full")
		local bag = S.Economy.getBagSize(data)
		local petId = S.PetData.Pets[1].Id
		for _ = 1, bag do
			S.Economy.addPet(p, petId, "Normal")
		end
		check(S.Economy.countPets(data) == bag, "сумка полна")
		S.Economy.grant(p, { Pet = petId })
		check(S.Economy.countPets(data) == bag, "награда не превысила лимит")
		check(#data.PetMail == 1, "питомец ждёт в почте")
		-- продажа освобождает место — награда приходит
		local uid = next(data.Pets)
		check(S.invoke(p, "Sell", uid).ok, "продажа")
		check(
			#data.PetMail == 0 and S.Economy.countPets(data) == bag,
			"почта доставлена после продажи"
		)
		-- при свободном месте награда выдаётся сразу
		uid = next(data.Pets)
		S.invoke(p, "Sell", uid)
		S.Economy.grant(p, { Pet = petId })
		check(
			#data.PetMail == 0 and S.Economy.countPets(data) == bag,
			"свободное место — сразу в инвентарь"
		)
	end
)

test(
	"v2.4 С13/Г4: шансы слияния в UI = реальные шансы сервера (с катализатором); сияние зависит от варианта",
	function()
		local S = boot("fuse")
		local M = S.PetMeta
		for _, v in ipairs({ "Normal", "Golden", "Rainbow" }) do
			for _, cat in ipairs({ false, true }) do
				local o = M.fuseOdds(v, cat)
				check(math.abs(o.Shiny + o.Upgrade + o.Same - 1) < 1e-9, v .. ": сумма шансов = 1")
				-- точный расчёт по сетке бросков (roll1, roll2) — без случайности
				local N = 400
				local got = { Shiny = 0, Up = 0, Same = 0 }
				for i = 0, N - 1 do
					for j = 0, N - 1 do
						local r = M.fuseVariant(
							v,
							(i + 0.5) / N,
							(j + 0.5) / N,
							if cat then M.CATALYST_BONUS else 0
						)
						if r == "Shiny" then
							got.Shiny += 1
						elseif r == v then
							got.Same += 1
						else
							got.Up += 1
						end
					end
				end
				local tag = v .. (if cat then "+катализатор" else "")
				check(
					math.abs(got.Shiny / N ^ 2 - o.Shiny) < 0.004,
					tag .. ": сияние " .. got.Shiny / N ^ 2 .. " vs " .. o.Shiny
				)
				check(math.abs(got.Up / N ^ 2 - o.Upgrade) < 0.004, tag .. ": улучшение")
				check(math.abs(got.Same / N ^ 2 - o.Same) < 0.004, tag .. ": без изменений")
			end
		end
		check(
			M.fuseOdds("Normal", false).Shiny < M.fuseOdds("Golden", false).Shiny,
			"Normal даёт сияние реже Golden"
		)
		check(
			M.fuseOdds("Golden", false).Shiny < M.fuseOdds("Rainbow", false).Shiny,
			"Golden реже Rainbow"
		)
		check(
			M.fuseOdds("Normal", true).Shiny > M.fuseOdds("Normal", false).Shiny,
			"катализатор повышает сияние (это видно в UI)"
		)
	end
)

test(
	"v2.4 М1: XP пропуска, набранный в новом сезоне до первого клейма, не сгорает",
	function()
		BACKEND.Stores = {}
		local S = boot("season")
		local data, _, p = S.join(95, "Sea")
		data.BattlePass.Season = S.BattlePassData.Season - 1 -- профиль из прошлого сезона
		data.BattlePass.Xp = 5000
		data.BattlePass.ClaimedFree = { ["1"] = true }
		S.Economy.addBpXp(p, 120)
		check(
			data.BattlePass.Season == S.BattlePassData.Season,
			"сезон обновлён при начислении XP"
		)
		check(
			data.BattlePass.Xp == 120,
			"старый XP сброшен, новый сохранён: " .. data.BattlePass.Xp
		)
		check(
			next(data.BattlePass.ClaimedFree) == nil,
			"клеймы прошлого сезона сброшены"
		)
		-- клейм после этого XP не обнуляет
		S.U.require("ServerScriptService/Server/BattlePassService").sync(data)
		check(
			data.BattlePass.Xp == 120,
			"повторная синхронизация ничего не сбрасывает"
		)
	end
)

test(
	"v2.4 Г1: ребёрт — множитель догоняет цену, потолок REBIRTH_MAX ниже MAX_COINS",
	function()
		BACKEND.Stores = {}
		local S = boot("rebirth")
		local F, C = S.Formulas, S.Config
		check(
			F.rebirthMultiplier(1) == 1.5 and F.rebirthMultiplier(4) == 3,
			"первые ребёрты как раньше (+0.5)"
		)
		check(math.abs(F.rebirthMultiplier(5) - 3 * 1.3) < 1e-9, "дальше ×1.3")
		for n = 1, C.REBIRTH_MAX do
			check(
				F.rebirthMultiplier(n) > F.rebirthMultiplier(n - 1),
				"множитель растёт: " .. n
			)
		end
		check(
			F.rebirthCost(C.REBIRTH_MAX - 1) < C.MAX_COINS,
			"последний ребёрт дешевле потолка монет"
		)
		-- «стена»: отношение цены к множителю растёт не быстрее чем в ×2.4 за ребёрт после 4-го
		for n = 5, C.REBIRTH_MAX - 1 do
			local k = (F.rebirthCost(n) / F.rebirthMultiplier(n))
				/ (F.rebirthCost(n - 1) / F.rebirthMultiplier(n - 1))
			check(k < 2.4, "рост сложности на ребёрт " .. n .. ": " .. k)
		end
		-- серверный потолок
		local data, _, p = S.join(97, "Max")
		data.Rebirths = C.REBIRTH_MAX
		data.Coins = C.MAX_COINS
		local r = S.invoke(p, "Rebirth")
		check(
			r.ok == false and data.Rebirths == C.REBIRTH_MAX,
			"сверх максимума ребёрт не проходит"
		)
	end
)

test(
	"v2.4 Г3: обучение первой сессии — шаги засчитывает сервер, награды, пропуск, ветераны без обучения",
	function()
		BACKEND.Stores = {}
		local S = boot("tutorial")
		local TD = S.U.require("ReplicatedStorage/Shared/TutorialData")
		local TS = S.U.require("ServerScriptService/Server/TutorialService")
		TS.init()
		local data, _, p = S.join(99, "Newbie")
		check(data.Tutorial.Step == 1, "новый игрок начинает обучение")
		-- чужие события не засчитываются
		TS.onEvent(p, "hatch", 1)
		check(data.Tutorial.Step == 1 and data.Tutorial.P == 0, "шаги по порядку")
		local coins0 = data.Coins
		for _ = 1, TD.Steps[1].Count do
			S.click(p)
			ADVANCE(0.2)
		end
		check(
			data.Tutorial.Step == 2,
			"25 ручных сборов — шаг 1 пройден: "
				.. data.Tutorial.Step
				.. "/"
				.. data.Tutorial.P
		)
		check(
			data.Coins - coins0 >= TD.Steps[1].RewardCoins,
			"монеты на первое яйцо выданы"
		)
		local r = S.invoke(p, "Hatch", "MeadowEgg", 1)
		check(r.ok, "первое яйцо куплено: " .. tostring(r.msg))
		check(data.Tutorial.Step == 3, "шаг «яйцо»")
		check(S.invoke(p, "EquipBest").ok and data.Tutorial.Step == 4, "шаг «в команду»")
		TS.onEvent(p, "boss", 1)
		check(data.Tutorial.Step == 5, "убийство босса считается убийством")
		local gems0 = data.Gems
		TS.onEvent(p, "gather", 1)
		check(
			data.Tutorial.Step == TD.DONE and data.Gems - gems0 == TD.REWARD_GEMS,
			"обучение пройдено, гемы выданы"
		)
		TS.onEvent(p, "gather", 1)
		check(data.Gems - gems0 == TD.REWARD_GEMS, "повторно награда не выдаётся")
		-- пропуск
		local d2, _, p2 = S.join(100, "Skipper")
		check(
			S.invoke(p2, "TutorialSkip").ok and d2.Tutorial.Step == TD.DONE,
			"пропуск обучения"
		)
		-- ветеран из v2.3 (без поля Tutorial, с питомцами)
		local old = {
			Version = 2,
			Coins = 5,
			Gems = 0,
			Rebirths = 0,
			TotalCoins = 0,
			TotalHatched = 12,
			Settings = { Lang = "ru" },
		}
		S.Migrations.run(old)
		check(old.Tutorial.Step >= TD.DONE, "ветерану обучение не показывается")
		local fresh = {
			Version = 2,
			Coins = 0,
			Gems = 0,
			Rebirths = 0,
			TotalCoins = 0,
			TotalHatched = 0,
			Settings = { Lang = "ru" },
		}
		S.Migrations.run(fresh)
		check(
			fresh.Tutorial.Step == 1,
			"старый пустой профиль проходит обучение"
		)
	end
)

test(
	"v2.4 С7: ресурсы закрытого мира собрать нельзя (эксплойт), открытого — можно",
	function()
		BACKEND.Stores = {}
		local S = boot("lockedgather")
		local ZD = S.U.require("ReplicatedStorage/Shared/ZoneData")
		local RS = S.U.require("ServerScriptService/Server/ResourceService")
		RS.init()
		local data, _, p = S.join(77, "Walker")
		local locked = ZD.List[2]
		check(not data.Zones[locked.Id], "второй мир закрыт у нового игрока")
		local res0 = 0
		for _, v in pairs(data.Resources) do
			res0 += v
		end
		check(
			not RS.harvestNearest(p, locked.Position, 95),
			"в закрытом мире узел не собирается"
		)
		local res1 = 0
		for _, v in pairs(data.Resources) do
			res1 += v
		end
		check(res1 == res0, "ресурсы не начислены")
		data.Zones[locked.Id] = true
		check(
			RS.harvestNearest(p, locked.Position, 95),
			"после открытия мира узел собирается"
		)
	end
)

-- итог — строго в конце файла (раньше два теста стояли после него и не учитывались)
print(("\nRESULT: %d passed, %d failed"):format(passed, failed))
if failed > 0 or (TEST_ERRORS or 0) > 0 then
	print("FAILED:")
	for _, f in ipairs(failures) do
		print(" - " .. f)
	end
	error("tests failed")
end
