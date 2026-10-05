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
		local pb = MAKE_PLAYER(B.U, 3, "Carol")
		local db, err = B.Data.load(pb)
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
		check(math.abs(up / N - 0.97 * 0.30) < 0.02, ("доля Golden ≈ 29%% (%.3f)"):format(up / N))
		check(math.abs(shiny / N - 0.03) < 0.01, ("доля Shiny ≈ 3%% (%.3f)"):format(shiny / N))
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

print(("\nRESULT: %d passed, %d failed"):format(passed, failed))
if failed > 0 or (TEST_ERRORS or 0) > 0 then
	print("FAILED:")
	for _, f in ipairs(failures) do
		print(" - " .. f)
	end
	error("tests failed")
end

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
