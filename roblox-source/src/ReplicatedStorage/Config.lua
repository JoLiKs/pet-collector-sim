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
	v2.7: все 5 геймпассов и 9 продуктов созданы в universe 10769777582 через Open Cloud
	(tools/roblox_store.py, ID также в tools/store_ids.json). Повторный запуск дубликатов не создаёт.
]]

local Config = {}

-- ============================================================================
-- 1. ID ГЕЙМПАССОВ (Game Passes) — реальные ID (v2.7); 0 = пасс отключён
-- ============================================================================
Config.GAMEPASS_IDS = {
	-- x2 ко всем монетам навсегда. Рекомендуемая цена: ~199-399 R$
	DOUBLE_COINS = 2019872329,
	-- x2 скорость бега навсегда. Рекомендуемая цена: ~99-199 R$
	DOUBLE_SPEED = 2017952343,
	-- Автосбор: монеты собираются сами, пока игрок в игре. Рекомендуемая цена: ~299-499 R$
	AUTO_COLLECT = 2018384337,
	-- VIP: +25% монет, +1 слот питомца, тег [VIP], x2 ежедневные награды. Рекомендуемая цена: ~399-799 R$
	VIP = 2019452336,
	-- Премиум-дорожка батл-пасса сезона (все премиум-награды). Рекомендуемая цена: ~399-599 R$
	BATTLE_PASS = 2018684334,
}

-- ============================================================================
-- 2. ID ДЕВЕЛОПЕРСКИХ ПРОДУКТОВ (Developer Products) — реальные ID (v2.7); 0 = отключён
--    Developer Product можно покупать многократно (в отличие от геймпасса).
-- ============================================================================
Config.PRODUCT_IDS = {
	GEMS_SMALL = 3717220391, -- пакет гемов (маленький), ~49-99 R$
	GEMS_MEDIUM = 3717220423, -- пакет гемов (средний), ~249-399 R$
	GEMS_LARGE = 3717220428, -- пакет гемов (большой), ~799-999 R$
	COINS_SMALL = 3717220436, -- пакет монет (маленький), ~49-99 R$
	COINS_LARGE = 3717220441, -- пакет монет (большой), ~299-499 R$
	LUCK_2X_15M = 3717220447, -- лаки-буст x2 на 15 минут, ~49-99 R$
	LUCK_5X_10M = 3717220452, -- лаки-буст x5 на 10 минут, ~149-249 R$
	BP_SKIP = 3717220455, -- +5 уровней батл-пасса, ~99-149 R$
	ESSENCE_PACK = 3717220458, -- 30 эссенции для эволюции питомцев, ~79-129 R$
}

-- ============================================================================
-- 2a. КАРТИНКИ (Image asset ID) — логотип и иконки. 0 = нет картинки: рисуем из примитивов GUI
--     (Frame + UICorner + UIGradient + UIStroke) — игра выглядит цельно и без загрузок.
--     Как получить ID: Creator Hub -> Development Items -> Decals -> Upload (assets/icon_512.png и т.п.)
--     -> откройте декаль -> ID картинки (Image) из Toolbox/Asset Manager (Studio: View -> Asset Manager -> Images
--     -> ПКМ -> Copy Asset ID). Подробно: docs/ICON_AND_BADGES.md.
-- ============================================================================
-- ============================================================================
-- 2b. ЗВУКИ (Audio asset ID, v3.1). 0 = звука нет: игра работает молча, без ошибок.
--     Файлы — оригинальная процедурная музыка из tools/music/synth.py (assets/audio/*.ogg).
--     Загрузка: Creator Hub -> Development Items -> Audio -> Upload, или
--     python3 tools/upload_audio.py assets/audio/<файл>.ogg "<название>" (Open Cloud, ключ с правом asset:write).
--     Затем впишите ID сюда.
-- ============================================================================
Config.SOUNDS = {
	MUSIC_CALM = 125236318818944, -- assets/audio/calm_meadow.ogg — спокойная фоновая тема (классика + 8-бит)
	MUSIC_EPIC = 81894939449988, -- assets/audio/epic_surge.ogg — эпичная тема на время «Суперсилы»
	CHEST_SPAWN = 102022045018776, -- assets/audio/chest_spawn.ogg — тихий сигнал появления морского сундука
	CHEST_OPEN = 121756761410700,
	MUSIC_RAIN = 133055317816585, -- v3.3: assets/audio/coin_rain.ogg — весёлая тема события «Дождь монет» -- assets/audio/chest_open.ogg — открытие сундука
}
Config.MUSIC = {
	CALM_VOLUME = 0.35, -- базовая громкость (умножается на ползунок игрока)
	EPIC_VOLUME = 0.45,
	RAIN_VOLUME = 0.4,
	FADE = 2.5, -- секунд кроссфейда между темами
	SFX_VOLUME = 0.5,
	CHEST_SPAWN_VOLUME = 0.25, -- сигнал сундука намеренно тихий (слышен рядом)
}

Config.ASSETS = {
	LOGO = 0, -- логотип (assets/icon_512.png): экран загрузки и табличка в хабе
	-- иконки валют/ресурсов (необязательно: без ID рисуются примитивами Icons.lua)
	COIN = 0,
	GEM = 0,
	WOOD = 0,
	STONE = 0,
	ORE = 0,
	HERB = 0,
	CRYSTAL = 0,
	ESSENCE = 0,
	FRAGMENT = 0,
}

-- ============================================================================
-- 2b. ЗНАЧКИ (Badges) — ID из Creator Hub -> ваш опыт -> Engagement -> Badges -> Create a Badge.
--     0 = значок выключен (никаких вызовов BadgeService и ошибок). Картинка: assets/badge_512.png.
-- ============================================================================
Config.BADGES = {
	WELCOME = 0, -- «Добро пожаловать!» — первый вход в игру
	FIRST_BOSS = 0, -- первый побеждённый босс
	FIRST_REBIRTH = 0, -- первое перерождение
	SUPERPOWER = 0, -- игрок впервые получил суперсилу
}

-- ============================================================================
-- 3. ОПИСАНИЕ ТОГО, ЧТО ДАЁТ КАЖДЫЙ ПРОДУКТ (ключи совпадают с PRODUCT_IDS)
--    Kind: "Gems" | "Coins" | "Luck"
--    Gems:  Amount  = количество гемов
--    Coins: Clicks  = сколько "кликов текущей силы" эквивалентно пакету (масштабируется с прогрессом)
--           Min     = минимум монет (чтобы пакет был полезен новичку)
--    Luck:  Boost   = ключ в данных игрока, Seconds = длительность, Multiplier = множитель удачи
--    Description — описание продукта (англ.) для Creator Hub (tools/roblox_store.py создаёт продукты с ним).
--    SuggestedPrice — цена при создании (tools/roblox_store.py) и запасная цена в магазине, если GetProductInfo недоступен.
-- ============================================================================
Config.PRODUCTS = {
	GEMS_SMALL = {
		Kind = "Gems",
		Amount = 100,
		Name = "Pile of Gems",
		Description = "100 gems to hatch eggs and buy upgrades.",
		SuggestedPrice = 79,
	},
	GEMS_MEDIUM = {
		Kind = "Gems",
		Amount = 550,
		Name = "Bag of Gems",
		Description = "550 gems - great value for hatching more eggs.",
		SuggestedPrice = 349,
	},
	GEMS_LARGE = {
		Kind = "Gems",
		Amount = 1500,
		Name = "Chest of Gems",
		Description = "1500 gems - the best value gem chest!",
		SuggestedPrice = 899,
	},
	COINS_SMALL = {
		Kind = "Coins",
		Clicks = 1500,
		Min = 2000,
		Name = "Coin Pouch",
		Description = "A pouch of coins that grows with your progress (at least 2,000).",
		SuggestedPrice = 79,
	},
	COINS_LARGE = {
		Kind = "Coins",
		Clicks = 15000,
		Min = 25000,
		Name = "Coin Vault",
		Description = "A vault of coins that grows with your progress (at least 25,000).",
		SuggestedPrice = 399,
	},
	LUCK_2X_15M = {
		Kind = "Luck",
		Boost = "Luck2",
		Multiplier = 2,
		Seconds = 900,
		Name = "Lucky Clover x2 (15m)",
		Description = "Double egg hatch luck for 15 minutes.",
		SuggestedPrice = 79,
	},
	BP_SKIP = {
		Kind = "BpLevels",
		Levels = 5,
		Name = "Battle Pass +5 Levels",
		Description = "Instantly gain 5 Battle Pass levels.",
		SuggestedPrice = 129,
	},
	ESSENCE_PACK = {
		Kind = "Res",
		Res = "Essence",
		Amount = 30,
		Name = "Essence Pack",
		Description = "30 essence to evolve your pets.",
		SuggestedPrice = 99,
	},
	LUCK_5X_10M = {
		Kind = "Luck",
		Boost = "Luck5",
		Multiplier = 5,
		Seconds = 600,
		Name = "Super Clover x5 (10m)",
		Description = "5x egg hatch luck for 10 minutes!",
		SuggestedPrice = 199,
	},
}
-- v2.4 (аудит В3): компенсация за уровни BP_SKIP, которые не поместились до максимума пропуска
-- (100 гемов ≈ 79 R$, 5 уровней ≈ 129 R$ → ~30 гемов за уровень)
Config.BP_SKIP_FALLBACK_GEMS = 30

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
	BATTLE_PASS = {
		Name = "Battle Pass (Premium)",
		Description = "Unlock every premium reward on the season track, including an exclusive pet.",
		SuggestedPrice = 499,
	},
	VIP = {
		Name = "VIP",
		Description = "+25% coins, +1 pet slot, [VIP] tag, double daily rewards.",
		SuggestedPrice = 599,
	},
}

-- Порядок отображения в магазине
Config.GAMEPASS_ORDER = { "DOUBLE_COINS", "AUTO_COLLECT", "VIP", "BATTLE_PASS", "DOUBLE_SPEED" }
Config.PRODUCT_ORDER = {
	"GEMS_SMALL",
	"GEMS_MEDIUM",
	"GEMS_LARGE",
	"COINS_SMALL",
	"COINS_LARGE",
	"LUCK_2X_15M",
	"LUCK_5X_10M",
	"BP_SKIP",
	"ESSENCE_PACK",
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
Config.DATASTORE_NAME = "PetCollector_Data_v2"
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
Config.VERSION = "3.3.0"
Config.MAX_CLICKS_PER_SECOND = 12 -- серверный лимит кликов
Config.CLICK_BURST = 6 -- "ведро токенов" для коротких всплесков
Config.BASE_PET_SLOTS = 3
Config.BASE_BAG_SIZE = 30
Config.BASE_WALKSPEED = 16
Config.MAX_WALKSPEED = 56
Config.JUMP_POWER = 50
Config.GOLD_CHANCE = 0.02 -- шанс "золотого" питомца (x2 сила)
Config.RAINBOW_CHANCE = 0.002 -- шанс «радужного» питомца из яйца (x5 сила)
Config.GOLD_POWER_MULT = 2
Config.SELL_VALUE_PER_POWER = 40 -- монет за 1 силы питомца при продаже
Config.MAX_COINS = 1e15 -- защита от переполнения
Config.MAX_GEMS = 1e9
Config.EGG_MAX_DISTANCE = 45 -- студов: насколько близко нужно стоять к яйцу
Config.HATCH_COUNTS = { 1, 3 } -- разрешённые количества за раз

-- v2.4 (аудит Г1, BALANCE.md §2): цена ×3 за ребёрт (было ×4); множитель первые 4 ребёрта растёт
-- линейно (+0.5), дальше — ×1.3 за ребёрт (было +0.5 навсегда). Потолок REBIRTH_MAX = 21: цена 21-го
-- ребёрта (~5.2e14) ещё ниже MAX_COINS, поэтому «стены на 1e15» больше нет — есть честный максимум.
Config.REBIRTH_BASE_COST = 50000
Config.REBIRTH_COST_GROWTH = 3
Config.REBIRTH_MULT_PER = 0.5 -- +50% монет за каждый из первых REBIRTH_MULT_LINEAR_UNTIL ребёртов
Config.REBIRTH_MULT_LINEAR_UNTIL = 4
Config.REBIRTH_MULT_GROWTH = 1.3 -- дальше множитель ×1.3 за каждый ребёрт
Config.REBIRTH_MAX = 21
Config.REBIRTH_GEMS_BASE = 20
Config.REBIRTH_GEMS_PER = 5

-- Ежедневные награды за вход (v2.8): 7-дневный цикл, награды и правило пропуска дня — ReplicatedStorage/Shared/DailyData.
-- Окно открывается само при входе раз в сутки, пока награда не получена (выключить для тестов:
-- атрибут Workspace DailyAutoOpen = false).

-- ============================================================================
-- 6b. МЕХАНИКИ v2 (баланс — см. docs/BALANCE.md)
-- ============================================================================
Config.TEAM_SLOTS_MAX = 8 -- жёсткий потолок слотов команды
Config.DISABLE_STATION_CHECK = false -- true: можно крафтить/торговать/покупать везде (для отладки)
Config.FRIEND_BONUS_PER = 0.05 -- +5% монет за каждого друга на сервере
Config.FRIEND_BONUS_MAX_FRIENDS = 5
-- NPC «Trader Tom»: партнёр по обмену и «друг» только для веб-демо. В живой игре — false
-- (v2.4, аудит В1); в демо включается патчем roblox2web.config.json, как DEMO_BOTS.
Config.DEMO_BOT_ENABLED = false
Config.DEMO_BOT_NAME = "Trader Tom"
Config.OFFLINE_MAX_SECONDS = 8 * 3600
Config.OFFLINE_RATE = 0.15 -- доля «активного» дохода в секунду, начисляемая оффлайн
Config.OFFLINE_MIN_SECONDS = 120 -- меньше этого — не показываем награду
Config.FUSE_COST_COINS = 0
Config.TRADE_MAX_PETS = 6
Config.TRADE_CONFIRM_SECONDS = 3
Config.TRADE_RANGE = 30 -- студов между игроками (для запроса обмена)
Config.COMBAT_TICK = 1.0 -- секунда между атаками питомцев
Config.COMBAT_RANGE = 40 -- радиус боя вокруг игрока
Config.PET_DAMAGE_SCALE = 2.5 -- множитель урона питомцев (сила -> урон за удар)
Config.ENEMY_SPEED = 9
-- v3.0: регенерация здоровья игрока (доля максимума в секунду; как стандартный скрипт Roblox), см. HealthService
Config.HP_REGEN_RATE = 0.01
Config.PLAYER_ATTACK_RANGE = 22
Config.PLAYER_ATTACK_COOLDOWN = 0.35
Config.KILL_COIN_BASE_CLICKS = 1 -- награда за убийство = Coins * PerClick зоны
-- Награда за убийство только тем, кто нанёс заметную долю урона (v2.4, аудит К2). Если таких нет — лучшему по урону.
Config.KILL_MIN_SHARE = 0.1
Config.TELEPORT_COOLDOWN = 3
Config.BP_XP_PER_KILL = 3
Config.BP_XP_PER_GATHER = 1
Config.BP_XP_PER_CRAFT = 6
Config.REBIRTH_TALENT_POINTS = 1 -- очков талантов за ребёрт (+1 за каждый 5-й)

-- ============================================================================
-- 6c. СОБЫТИЕ «СУПЕРСИЛА / ОХОТА» (SuperpowerService, баланс — docs/BALANCE.md §6)
--     Раз в INTERVAL секунд случайный подходящий игрок получает суперсилу на DURATION секунд,
--     остальные получают задание «Останови его!». Урон и награды считает только сервер.
-- ============================================================================
-- Серверные боты-игроки для событий (охотники/суперигроки), когда на сервере мало людей.
-- В настоящей игре — false; в веб-демо (один игрок) включается патчем roblox2web.config.json.
Config.DEMO_BOTS = false

-- v3.0: ИИ-боты на малолюдных серверах (BotService, Shared/BotLogic, docs/BOTS_POLICY.md).
-- Это NPC-модели (не объекты Player): нет в списке игроков, рейтингах и счётчиках, нет DataStore, чата и покупок.
Config.BOTS_ENABLED = true
Config.BOTS = {
	MIN = 10, -- ботов на сервере, пока живых игроков меньше REAL_THRESHOLD (случайно MIN..MAX)
	MAX = 20,
	REAL_THRESHOLD = 5, -- от стольких живых игроков боты постепенно уходят
	FILL_GAP = { 0.4, 1.2 }, -- старт сервера: боты «уже играют» — появляются быстро
	CHURN_GAP = { 25, 75 }, -- обычная жизнь: по одному уходят/приходят через столько секунд
	STEP_GAP = { 60, 120 }, -- уход при наплыве живых и возвращение: по одному раз в 1–2 минуты
	MAX_PETS = 3,
	MAX_HUNTERS = 4, -- сколько ботов одновременно охотятся на суперигрока (только находящиеся рядом)
	HUNT_RANGE = 140,
	SPEED = 16,
	AI_BADGE = true, -- метка «ИИ» у имени над головой
	BOT_HIT = 0.14, -- доля здоровья врага за удар бота (только враги, которых не бьют живые игроки)
	-- v3.2: живым игрокам всегда хватает врагов. Бот бьёт только «ничьего» врага (его не били игроки, рядом
	-- нет игрока ближе YIELD_RADIUS) и занимает его один (MAX_PER_MOB); в одном мире дерутся не больше
	-- MAX_FIGHTERS_PER_ZONE ботов, и после захвата в мире остаётся не меньше RESERVE_FREE свободных врагов.
	-- Подошёл игрок — бот уступает: отпускает врага и отходит. В одном мире (кроме хаба) — не больше MAX_IN_ZONE ботов.
	MAX_PER_MOB = 1,
	MAX_FIGHTERS_PER_ZONE = 3,
	RESERVE_FREE = 3,
	YIELD_RADIUS = 35,
	MAX_IN_ZONE = 4,
	CLAIM_TTL = 3, -- секунд: занятость врага без подтверждения (бот ушёл/исчез) снимается сама
}
-- v3.1: морской сундук в хабе — появляется раз в INTERVAL секунд в случайном свободном месте, о нём сообщает
-- только тихий звук. Забирает первый открывший (ProximityPrompt или касание); всё решает сервер.
-- Награда средняя: монеты по прогрессу (сборов текущей силы), немного гемов, зелье, ресурсы, билет на яйцо
-- и маленький шанс бонуса. Только то, что можно добыть в игре бесплатно (никаких платных предметов).
Config.SEA_CHEST = {
	ENABLED = true,
	INTERVAL = 300, -- 5 минут
	FIRST_DELAY = 90, -- первый сундук после старта сервера
	OPEN_DISTANCE = 12, -- проверка сервера: игрок не дальше (studs) от сундука
	PROMPT_HOLD = 0.5,
	MIN_RADIUS = 24, -- кольцо хаба, где ищется место (центр — фонтан)
	MAX_RADIUS = 92,
	CLEARANCE = 6, -- свободный радиус вокруг сундука (не в зданиях и декоре)
	-- v3.2: проверка места по миру (сервер): свободный цилиндр радиуса PART_CLEARANCE высотой CLEAR_HEIGHT
	-- без единой детали (деревья, колонны, здания, NPC), твёрдый ровный пол хаба на уровне FLOOR_Y (луч вниз),
	-- ничего сверху (луч вверх), не «в коробке» (из 8 горизонтальных лучей длиной EXIT_RAY упираются
	-- не больше MAX_BLOCKED_DIRS) и не ближе SPAWN_DISTANCE к центру точки появления
	PART_CLEARANCE = 6,
	CLEAR_HEIGHT = 12,
	FLOOR_Y = 0,
	FLOOR_TOL = 1.5,
	MIN_NORMAL_Y = 0.9,
	EXIT_RAY = 18,
	MAX_BLOCKED_DIRS = 4,
	SPAWN_POS = Vector3.new(0, 0, 26),
	SPAWN_DISTANCE = 34,
	COIN_CLICKS = { 80, 140 }, -- монеты = сила сбора × случайно из диапазона (ежедневная награда — 500)
	COIN_MIN = 50,
	GEMS = { 3, 6 },
	POTIONS = { "luck_potion", "coin_elixir", "health_potion", "regen_potion" },
	RES_KINDS = 2, -- сколько видов ресурсов
	RES_AMOUNT = { 3, 6 }, -- + номер лучшего открытого мира
	BONUS_CHANCE = 0.07, -- «что-то получше»
	BONUS = { -- Item = "" — бонус гемами
		{ Item = "catalyst", Count = 1, Gems = 0 },
		{ Item = "", Count = 0, Gems = 15 },
		{ Item = "xp_treat", Count = 3, Gems = 0 },
	},
}

Config.SUPERPOWER = {
	ENABLED = true,
	INTERVAL = 120, -- секунд между выборами суперигрока (v3.1: в 2 раза реже, было 60)
	DURATION = 35, -- длительность суперсилы (обрезается до INTERVAL - GAP)
	GAP = 5, -- минимальная пауза между концом суперсилы и следующим выбором
	FIRST_DELAY = 25, -- первый выбор после старта сервера
	MIN_PLAYERS = 2, -- минимум участников (игроки + боты); один живой игрок без ботов событие не запускает
	-- суперигрок
	SCALE = 1.6, -- Model:ScaleTo
	SPEED_MULT = 1.45,
	JUMP_MULT = 1.35,
	DAMAGE_MULT = 2.5, -- урон по врагам (удар и питомцы)
	COIN_MULT = 2, -- множитель монет
	HP_BASE = 700, -- «PvP-HP» охоты (не Humanoid.Health): база + за каждого охотника
	HP_PER_HUNTER = 450,
	SLAM_RANGE = 16, -- удар по площади: радиус ударной волны
	SLAM_COOLDOWN = 2.2,
	SLAM_KNOCKBACK = 18, -- студов отталкивания охотников
	STUN_SECONDS = 1.2, -- оглушение охотника (без потери прогресса)
	STUN_IMMUNE = 2.5, -- после оглушения охотника нельзя оглушить снова N секунд
	-- охотники
	HIT_RANGE = 12, -- дистанция удара по суперигроку (+ радиус увеличенного тела)
	HIT_COOLDOWN = 0.3, -- серверный лимит ударов по цели на охотника
	HIT_BASE = 30, -- урон удара охотника (растёт логарифмически от силы команды)
	HIT_POWER_K = 0.12,
	MAX_HIT_SHARE = 0.08, -- один удар не больше 8% PvP-HP (никаких ваншотов)
	PET_HIT = 6, -- урон одного питомца за тик боя по суперигроку
	PET_MAX_PER_TICK = 0.03, -- все питомцы охотника за тик — не больше 3% HP
	MIN_DAMAGE_SHARE = 0.04, -- анти-AFK: награда только если нанесено ≥ 4% PvP-HP
	-- награды (Coins — в «кликах» текущей силы, как ежедневная награда)
	STOP_REWARD = { Clicks = 300, Gems = 10, Essence = 3, RareChance = 0.12, RareItem = "luck_potion" },
	STOP_K_MIN = 0.3, -- множитель вклада: доля урона × число охотников, в пределах [MIN, MAX]
	STOP_K_MAX = 2.5,
	SPEED_BONUS = 0.5, -- до +50% за быструю остановку (по оставшемуся времени)
	LAST_HIT_BONUS = { Clicks = 150, Gems = 5, Essence = 2 },
	SURVIVE_REWARD = { Clicks = 800, Gems = 25, Essence = 6, BpXp = 60 },
	CONSOLATION = { Clicks = 60, Gems = 2 },
	-- анти-AFK (v2.4, аудит К1)
	HUNTER_MIN_HITS = 3, -- охотнику нужны ручные удары: урон одних питомцев награды не даёт
	SURVIVE_MIN_MOVE = 40, -- суперигрок должен пройти столько студов за раунд …
	SURVIVE_MIN_SLAMS = 2, -- … или сделать столько ударных волн; иначе награды за «продержался» нет
	-- никто не охотился (ни один охотник не бил вручную, боты не в счёт в живой игре) — малая награда вместо крупной
	SURVIVE_UNCONTESTED = { Clicks = 200, Gems = 3, Essence = 1, BpXp = 15 },
	DAILY_GEM_CAP = 150, -- не больше N гемов в сутки (UTC) из этого события на игрока
	-- боты (только при DEMO_BOTS)
	BOT_COUNT = 3,
	BOT_NAMES = { "Max", "Lina", "Rex" },
	BOT_DAMAGE = 26, -- урон удара бота по суперигроку
	BOT_ATTACK_INTERVAL = 1.0,
	BOT_SPEED = 15,
	BOT_PLAYER_SUPER_CHANCE = 0.5, -- в демо: шанс, что суперсилу получит живой игрок, а не бот
}

-- ============================================================================
-- 7. АНТИ-ЭКСПЛОЙТ (базовый)
-- ============================================================================
Config.ANTICHEAT = {
	STRIKE_WINDOW = 60, -- секунд, за которые считаются нарушения
	STRIKE_KICK_THRESHOLD = 60, -- сколько "страйков" за окно до кика
	MAX_HORIZONTAL_SPEED = 220, -- studs/sec; абсолютный потолок (на случай очень больших бонусов скорости)
	-- v2.4 (аудит С4): реальный порог — от легальной скорости игрока: скорость × TOLERANCE + SLACK
	-- (запас на рывки сети и физику). База 16 → 36 студ/с, максимум (56 × 1.45 супер ≈ 81) → ~134.
	SPEED_TOLERANCE = 1.5,
	SPEED_SLACK = 12,
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
