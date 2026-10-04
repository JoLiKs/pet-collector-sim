# Архитектура (v2.0)

## 1. Слои
```
src/
  ReplicatedStorage/         "Shared": данные и чистая логика (без Instance там, где можно) — тестируются вне Roblox
    Config, Formulas, Util, Remotes
    PetData, PetMeta, Abilities, PetModel
    ZoneData, EnemyData, ResourceData, RecipeData
    QuestData, AchievementData, TalentData, ShopData, BattlePassData, EventData, UpgradeData, TradeLogic
  ServerScriptService/
    Main.server.lua          порядок инициализации сервисов
    Server/*                 сервисы (см. ниже)
  StarterGui/PetCollectorGui/
    Main.client.lua, Modules/*   клиентский интерфейс
```
`default.project.json` (Rojo) отображает `src/ReplicatedStorage` в `ReplicatedStorage/Shared`, поэтому пути вида `ReplicatedStorage.Shared.Config` одинаковы в Studio, в `.rbxlx` и в веб-версии.

## 2. Серверные сервисы
| Группа | Модули |
|---|---|
| Ядро | `Session` (временное состояние), `DataService` (DataStore, блокировка сессии, автосохранение, миграции `Migrations` v1→v2), `State` (сборка снимка для клиента и событие `State`), `Router` (единый вход действий), `Notify`, `AntiExploit`, `PlayerService` |
| Экономика | `Economy` (монеты/гемы/пределы/множители), `ClickService`, `UpgradeService`, `RebirthService`, `OfflineService`, `DailyService` |
| Питомцы | `PetService` (яйца, команда, продажа, слияние, эволюция, Treat, избранное) |
| Мир | `WorldBuilder` (хаб, биомы, NPC, станции, декор), `Stations` (проверка «игрок в хабе»), `StationService`, `ZoneService` (открытие и телепорт) |
| Геймплей | `ResourceService`, `CombatService` (ИИ врагов, автоатака питомцев, боссы), `CraftService`, `EventService` + `EventState`, `ShopService` + `ShopLogic`, `BattlePassService`, `QuestService`, `Dailies`, `Progress` (единая точка учёта прогресса), `TradeService` |
| Деньги | `Monetization` (геймпассы, `ProcessReceipt`, PolicyService), `LeaderboardService` |

### Router / Action
Клиент не имеет отдельных Remote для каждой функции. Все действия идут через один `RemoteFunction "Action"`:
```lua
Router.register("Craft", 4, 4, function(player, recipeId) ... return ok, msg end)
```
Параметры — имя, частота (токенов/с), «всплеск» и обработчик, возвращающий `ok, msg`. Router сам проверяет типы аргументов на верхнем уровне, ограничивает частоту, ловит ошибки обработчика (`pcall`) и не пускает действия до загрузки данных игрока. Клиент вызывает `Net.action("Craft", id)` и показывает `msg`.

### State
Сервер — единственный источник правды. После любого изменения вызывается `State.push(player)`; клиент получает событие `State` с полным компактным снимком (монеты, питомцы, команда, ресурсы, квесты, таланты, батл-пасс…) и перерисовывает панели. Клиент ничего не «додумывает» локально.

## 3. Поток данных
```
Клиент: клик/кнопка → Action(name,args) → Router (rate-limit, pcall)
  → сервис (проверка условий на сервере) → изменение данных в Session
  → Progress.record(...) (квесты / достижения / батл-пасс)
  → State.push → клиент → перерисовка
Сохранение: DataService (автосейв + при выходе + BindToClose; блокировка сессии против дюпа)
Покупки: MarketplaceService.ProcessReceipt → Monetization (идемпотентно, по PurchaseId)
События: EventData (расписание от os.time) → EventService → атрибуты Workspace/Lighting → клиентские баннеры
```
Данные игрока — таблица версии 2; `Migrations` поднимает старые профили (v1) без потери питомцев/монет.

## 4. Клиент
`UiKit` — общие виджеты (кнопки, панели, тексты с автоподгонкой); `UIController` открывает панели (`openPanel`); `Hud` — кнопки меню и красные точки; панели: Pets (инвентарь + слияние), Egg + HatchPopup, Craft, Quests (Daily/Story/Achievements), Dialog (NPC), Talents, Trade, Market (Shop / Battle Pass / Robux Store), Boards (Leaderboards), Zones, Upgrades; `Fx` — всплывающие числа, баннеры событий, полоса босса, трекер заданий, кнопка атаки, окно оффлайн-награды.

## 5. Веб-версия и эмулятор
Тот же код Luau превращается в JS транспилятором **roblox2web** ([репозиторий](https://github.com/JoLiKs/roblox2web)) и работает в браузере поверх эмулятора Roblox API (Instance, сервисы, Remotes с задержкой, DataStore в памяти, UI → DOM, 3D → three.js). Для тестов в сборку подмешивается `UiDriver.server.lua` (команды через атрибут `Workspace.UiCmd`). `roblox2web.config.json` подставляет демо-ID геймпассов/продуктов regex-патчами `Shared.Config` и описывает каталог цен. Код, проходящий в эмуляторе, не использует ничего, чего нет в настоящем Roblox.

## 6. Инструменты
`tools/build_rbxlx.py` (сборка `.rbxlx` без Rojo), `tools/validate_rbxlx.py` (проверка + сверка с `rojo build`), `tools/check_all.sh` (все проверки), `tools/publish_web.sh` (веб-сборка для Pages). Стиль: stylua, selene, luau-lsp (strict-типы).
