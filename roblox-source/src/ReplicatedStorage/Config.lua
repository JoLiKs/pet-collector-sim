--!strict
--[[
	Config.lua — ЕДИНСТВЕННОЕ место, где нужно подставить ID геймпассов и продуктов.
	(Single place for all Roblox IDs and the main tuning knobs.)

	Как получить ID:
	  Creator Hub (create.roblox.com) -> Experiences -> ваш плейс -> Monetization
	    * Passes            -> создайте Pass -> скопируйте число из URL / из карточки
	    * Developer Products -> создайте Product -> скопируйте Product ID
	Значение 0 = "не настроено": кнопка в магазине покажет подсказку, покупка невозможна,
	а игра продолжает работать без ошибок.
]]

local Config = {}

-- ============================================================================
-- 1. ID ГЕЙМПАССОВ (Game Passes) — подставьте свои числа вместо 0
-- ============================================================================
Config.GAMEPASS_IDS = {
	-- x2 ко всем монетам навсегда. Рекомендуемая цена: ~199-399 R$
	DOUBLE_COINS = 0,
	-- x2 скорость бега навсегда. Рекомендуемая цена: ~99-199 R$
	DOUBLE_SPEED = 0,
	-- Автосбор: монеты собираются сами, пока игрок в игре. Рекомендуемая цена: ~299-499 R$
	AUTO_COLLECT = 0,
	-- VIP: +25% монет, +1 слот питомца, тег [VIP], x2 ежедневные награды. Рекомендуемая цена: ~399-799 R$
	VIP = 0,
}

-- ============================================================================
-- 2. ID ДЕВЕЛОПЕРСКИХ ПРОДУКТОВ (Developer Products) — подставьте свои числа вместо 0
--    Developer Product можно покупать многократно (в отличие от геймпасса).
-- ============================================================================
Config.PRODUCT_IDS = {
	GEMS_SMALL = 0, -- пакет гемов (маленький), ~49-99 R$
	GEMS_MEDIUM = 0, -- пакет гемов (средний), ~249-399 R$
	GEMS_LARGE = 0, -- пакет гемов (большой), ~799-999 R$
	COINS_SMALL = 0, -- пакет монет (маленький), ~49-99 R$
	COINS_LARGE = 0, -- пакет монет (большой), ~299-499 R$
	LUCK_2X_15M = 0, -- лаки-буст x2 на 15 минут, ~49-99 R$
	LUCK_5X_10M = 0, -- лаки-буст x5 на 10 минут, ~149-249 R$
}

-- ============================================================================
-- 3. ОПИСАНИЕ ТОГО, ЧТО ДАЁТ КАЖДЫЙ ПРОДУКТ (ключи совпадают с PRODUCT_IDS)
--    Kind: "Gems" | "Coins" | "Luck"
--    Gems:  Amount  = количество гемов
--    Coins: Clicks  = сколько "кликов текущей силы" эквивалентно пакету (масштабируется с прогрессом)
--           Min     = минимум монет (чтобы пакет был полезен новичку)
--    Luck:  Boost   = ключ в данных игрока, Seconds = длительность, Multiplier = множитель удачи
--    SuggestedPrice — только подсказка для README/магазина, реальную цену задаёте в Creator Hub.
-- ============================================================================
Config.PRODUCTS = {
	GEMS_SMALL = { Kind = "Gems", Amount = 100, Name = "Pile of Gems", SuggestedPrice = 79 },
	GEMS_MEDIUM = { Kind = "Gems", Amount = 550, Name = "Bag of Gems", SuggestedPrice = 349 },
	GEMS_LARGE = { Kind = "Gems", Amount = 1500, Name = "Chest of Gems", SuggestedPrice = 899 },
	COINS_SMALL = { Kind = "Coins", Clicks = 1500, Min = 2000, Name = "Coin Pouch", SuggestedPrice = 79 },
	COINS_LARGE = { Kind = "Coins", Clicks = 15000, Min = 25000, Name = "Coin Vault", SuggestedPrice = 399 },
	LUCK_2X_15M = {
		Kind = "Luck",
		Boost = "Luck2",
		Multiplier = 2,
		Seconds = 900,
		Name = "Lucky Clover x2 (15m)",
		SuggestedPrice = 79,
	},
	LUCK_5X_10M = {
		Kind = "Luck",
		Boost = "Luck5",
		Multiplier = 5,
		Seconds = 600,
		Name = "Super Clover x5 (10m)",
		SuggestedPrice = 199,
	},
}

-- Описание геймпассов для магазина (ключи совпадают с GAMEPASS_IDS)
Config.GAMEPASSES = {
	DOUBLE_COINS = {
		Name = "2x Coins",
		Description = "Double ALL coins you collect. Forever!",
		SuggestedPrice = 299,
	},
	DOUBLE_SPEED = {
		Name = "2x Speed",
		Description = "Run twice as fast across every world.",
		SuggestedPrice = 149,
	},
	AUTO_COLLECT = {
		Name = "Auto Collect",
		Description = "Coins are collected for you automatically, even while you explore.",
		SuggestedPrice = 399,
	},
	VIP = {
		Name = "VIP",
		Description = "+25% coins, +1 pet slot, [VIP] tag, double daily rewards.",
		SuggestedPrice = 599,
	},
}

-- Порядок отображения в магазине
Config.GAMEPASS_ORDER = { "DOUBLE_COINS", "AUTO_COLLECT", "VIP", "DOUBLE_SPEED" }
Config.PRODUCT_ORDER = {
	"GEMS_SMALL",
	"GEMS_MEDIUM",
	"GEMS_LARGE",
	"COINS_SMALL",
	"COINS_LARGE",
	"LUCK_2X_15M",
	"LUCK_5X_10M",
}

-- ============================================================================
-- 4. ЭФФЕКТЫ (баланс). Менять можно свободно — формулы читают эти значения.
-- ============================================================================
Config.PASS_EFFECTS = {
	COIN_MULT_DOUBLE = 2, -- 2x Coins
	SPEED_MULT_DOUBLE = 2, -- 2x Speed
	VIP_COIN_BONUS = 0.25, -- VIP: +25% монет
	VIP_EXTRA_SLOTS = 1, -- VIP: +1 слот питомца
	VIP_LUCK_BONUS = 0.10, -- VIP: +10% удачи
	VIP_DAILY_MULT = 2, -- VIP: x2 ежедневные награды
	PREMIUM_COIN_BONUS = 0.10, -- Roblox Premium: +10% монет (бонус для подписчиков)
	PREMIUM_DAILY_GEMS = 5, -- Roblox Premium: +5 гемов к ежедневной награде
	AUTO_CLICKS_PER_SECOND = 2, -- Auto Collect: сколько "кликов" в секунду делает сервер
}

-- В Roblox Studio (и ТОЛЬКО в Studio) можно включить выдачу всех геймпассов для теста интерфейса.
-- В опубликованной игре это поле игнорируется.
Config.STUDIO_GRANT_ALL_PASSES = false

-- ============================================================================
-- 5. ДАННЫЕ И СЕССИИ
-- ============================================================================
Config.DATASTORE_NAME = "PetCollector_Data_v1"
Config.LEADERBOARD_DATASTORE = "PetCollector_TopCoins_v1"
Config.AUTOSAVE_INTERVAL = 60 -- секунд (также продлевает session lock)
Config.SESSION_LOCK_TIMEOUT = 180 -- секунд; "мёртвая" блокировка (упавший сервер) считается свободной
Config.LOAD_ATTEMPTS = 8 -- попыток загрузки (с учётом ожидания снятия блокировки)
Config.LOAD_LOCK_RETRY_DELAY = 4 -- пауза, если данные заняты другим сервером
Config.SAVE_ATTEMPTS = 5
-- В Studio, если DataStore недоступен (API Services выключены), играем без сохранения.
-- На живых серверах игрока в этом случае кикает — чтобы не затереть данные.
Config.STUDIO_FALLBACK_TO_EPHEMERAL = true

-- ============================================================================
-- 6. ГЕЙМПЛЕЙ
-- ============================================================================
Config.GAME_NAME = "Pet Collector Simulator"
Config.MAX_CLICKS_PER_SECOND = 12 -- серверный лимит кликов
Config.CLICK_BURST = 6 -- "ведро токенов" для коротких всплесков
Config.BASE_PET_SLOTS = 3
Config.BASE_BAG_SIZE = 30
Config.BASE_WALKSPEED = 16
Config.MAX_WALKSPEED = 56
Config.JUMP_POWER = 50
Config.GOLD_CHANCE = 0.02 -- шанс "золотого" питомца (x2 сила)
Config.GOLD_POWER_MULT = 2
Config.SELL_VALUE_PER_POWER = 40 -- монет за 1 силы питомца при продаже
Config.MAX_COINS = 1e15 -- защита от переполнения
Config.MAX_GEMS = 1e9
Config.EGG_MAX_DISTANCE = 45 -- студов: насколько близко нужно стоять к яйцу
Config.HATCH_COUNTS = { 1, 3 } -- разрешённые количества за раз

Config.REBIRTH_BASE_COST = 50000
Config.REBIRTH_COST_GROWTH = 4
Config.REBIRTH_MULT_PER = 0.5 -- +50% монет за каждый ребёрт
Config.REBIRTH_GEMS_BASE = 20
Config.REBIRTH_GEMS_PER = 5

-- Ежедневные награды (цикл из 7 дней). Clicks = кликов текущей силы монетами; Luck2Minutes = минут x2 удачи.
Config.DAILY_REWARDS = {
	{ Gems = 10, Clicks = 300 },
	{ Gems = 15, Clicks = 500 },
	{ Gems = 20, Clicks = 800 },
	{ Gems = 25, Clicks = 1200, Luck2Minutes = 10 },
	{ Gems = 35, Clicks = 2000 },
	{ Gems = 50, Clicks = 3000, Luck2Minutes = 15 },
	{ Gems = 120, Clicks = 6000, Luck2Minutes = 30 },
}

-- ============================================================================
-- 7. АНТИ-ЭКСПЛОЙТ (базовый)
-- ============================================================================
Config.ANTICHEAT = {
	STRIKE_WINDOW = 60, -- секунд, за которые считаются нарушения
	STRIKE_KICK_THRESHOLD = 60, -- сколько "страйков" за окно до кика
	MAX_HORIZONTAL_SPEED = 220, -- studs/sec; больше = подозрение на телепорт/спидхак
	TELEPORT_GRACE = 2.5, -- секунд после серверного телепорта, когда проверка выключена
}

-- ============================================================================
-- Вспомогательные функции (только чтение конфигурации)
-- ============================================================================

-- Возвращает ключ геймпасса по числовому ID (или nil). ID = 0 игнорируются.
function Config.getPassKeyById(passId: number): string?
	if passId == 0 then
		return nil
	end
	for key, id in pairs(Config.GAMEPASS_IDS) do
		if id == passId then
			return key
		end
	end
	return nil
end

-- Возвращает ключ продукта по числовому ID (или nil). ID = 0 игнорируются.
function Config.getProductKeyById(productId: number): string?
	if productId == 0 then
		return nil
	end
	for key, id in pairs(Config.PRODUCT_IDS) do
		if id == productId then
			return key
		end
	end
	return nil
end

return Config
