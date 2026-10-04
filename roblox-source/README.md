# Pet Collector Simulator — шаблон Roblox-игры (клик → яйца → питомцы → ребёрт)

Готовый проект Roblox-игры в жанре **pet / clicker simulator**: сбор монет, яйца с питомцами пяти уровней редкости (плюс Mythic),
апгрейды, ребёрт, пять миров, ежедневные награды, глобальный лидерборд и полноценная монетизация (геймпассы + девелоперские
продукты + Premium-бонус). Всё сделано кодом на **Luau** — нет ни одного внешнего ассета: мир, интерфейс и питомцы строятся из примитивов.

> ⚠️ **Прочитайте сразу.** Проект собран и проверен линтерами/тестами логики на сервере, но **не запускался в реальной Roblox Studio**
> (нет доступа к Studio в среде сборки). Список проверенного и непроверенного — в [`docs/TESTING.md`](docs/TESTING.md).
> **Никакого дохода проект не гарантирует** — честная оценка в [`docs/HONEST_ASSESSMENT.md`](docs/HONEST_ASSESSMENT.md).

---

## 1. Геймплей

| Что делает игрок | Как устроено |
|---|---|
| **COLLECT** (кнопка, удержание или клавиша `F`) | Сервер считает монеты: `(1 + Click Power) × (1 + сила экипированных питомцев) × множитель мира × множитель ребёрта × бонусы пассов`. |
| **Яйца** (подойти → `E` → окно со шансами → Hatch ×1 / ×3) | 6 яиц: 5 за монеты (по одному на мир) + «Crystal Egg» за гемы. У каждого — честная таблица шансов (с учётом удачи игрока). 2% шанс «Golden» питомца (×2 сила). |
| **Питомцы** | 35 оригинальных питомцев (Common → Mythic), собираются из шаров/блоков. Экипировка по слотам (3 + апгрейды + VIP), «Equip Best», продажа. Видны всем игрокам. |
| **Апгрейды** | Click Power, Swift Shoes (скорость), Lucky Charm (удача), Bigger Bag (вместимость), Pet Slot (за гемы). |
| **Миры** | Sunny Meadow → Whispering Forest → Golden Dunes → Frostpeak Glade → Ember Caldera (x1 / x3 / x9 / x27 / x81 монет). Последний требует 1 ребёрт. |
| **Ребёрт** | Сброс монет и Click Power → постоянный бонус +50% монет за ребёрт + гемы. |
| **Ежедневные награды** | Цикл из 7 дней со стриком (гемы, монеты, буст удачи). |
| **Лидерборд** | `leaderstats` + глобальное табло «Top Collectors» в стартовом мире (OrderedDataStore). |

## 2. Монетизация (всё настраивается в одном файле)

Файл: **`src/ReplicatedStorage/Config.lua`** (в Studio: `ReplicatedStorage → Shared → Config`). Там же комментарии «как получить ID».

| Тип | Ключ | Что даёт | Реком. цена* |
|---|---|---|---|
| Геймпасс | `DOUBLE_COINS` | ×2 ко всем монетам | 299 R$ |
| Геймпасс | `DOUBLE_SPEED` | ×2 скорость бега | 149 R$ |
| Геймпасс | `AUTO_COLLECT` | автосбор (2 клика/сек на сервере, переключатель AUTO) | 399 R$ |
| Геймпасс | `VIP` | +25% монет, +1 слот питомца, тег `[VIP]`, ×2 ежедневные награды, +10% удачи | 599 R$ |
| Продукт | `GEMS_SMALL / MEDIUM / LARGE` | 100 / 550 / 1500 гемов | 79 / 349 / 899 R$ |
| Продукт | `COINS_SMALL / LARGE` | монеты, масштабируемые под прогресс игрока | 79 / 399 R$ |
| Продукт | `LUCK_2X_15M`, `LUCK_5X_10M` | лаки-буст ×2 на 15 мин, ×5 на 10 мин (суммируются по времени) | 79 / 199 R$ |
| Premium | автоматически | +10% монет и +5 гемов к ежедневной награде для подписчиков Roblox Premium | — |

\*Цены — только ориентир; реальную цену вы задаёте в Creator Hub. ID по умолчанию `0` = «не настроено» (кнопка покажет подсказку, ошибок нет).

**Правильный `ProcessReceipt`:** один обработчик; идемпотентность через `PurchaseId`, записанный в данные игрока вместе с наградой;
`PurchaseGranted` возвращается **только после успешного сохранения**; любая неопределённость → `NotProcessedYet`.

**Соответствие правилам Roblox для платных случайных предметов** (яйца за Robux-валюту): шансы показываются численно
до покупки, удача отображается и динамически меняет шансы, используется `PolicyService.ArePaidRandomItemsRestricted`
(для ограниченных игроков пакеты гемов/монет/лаки-бусты скрыты, платная удача не действует).
Подробности и ограничения — в [`docs/HONEST_ASSESSMENT.md`](docs/HONEST_ASSESSMENT.md).

## 3. Что в архиве

```
roblox-game/
├── PetCollectorSimulator.rbxlx      ← готовый place-файл: открыть в Studio двойным кликом, Rojo не нужен
├── default.project.json             ← Rojo-проект
├── src/
│   ├── ReplicatedStorage/           ← общие модули: Config, PetData, ZoneData, UpgradeData, Formulas, PetModel, Remotes, Util
│   ├── ServerScriptService/
│   │   ├── Main.server.lua          ← точка входа сервера
│   │   └── Server/                  ← DataService, Economy, State, Router, AntiExploit, PetService, ClickService,
│   │                                   UpgradeService, ZoneService, RebirthService, DailyService, Monetization,
│   │                                   LeaderboardService, PlayerService, WorldBuilder, Session, Notify
│   ├── StarterPlayer/StarterPlayerScripts/PetFollower.client.lua   ← питомцы за игроками (клиентская отрисовка)
│   └── StarterGui/PetCollectorGui/  ← ScreenGui + UIController.client.lua + Modules/ (HUD, панели, магазин, анимация яиц)
├── tools/                           ← build_rbxlx.py, validate_rbxlx.py, check_all.sh
├── tests/                           ← тесты серверной логики (Luau + эмуляция Roblox API)
├── docs/                            ← документация (см. ниже)
├── stylua.toml, selene.toml, rokit.toml
└── build/PetCollectorSimulator.rbxlx
```

## 4. Быстрый старт (без Rojo) — пошагово

### Шаг 1. Установите Roblox Studio
1. Зайдите на <https://create.roblox.com> (или roblox.com → **Create**), войдите в аккаунт (создайте, если нет).
2. Нажмите **Download Studio** / **Start Creating**, установите и войдите в Studio тем же аккаунтом.

### Шаг 2. Откройте готовый файл
1. Распакуйте zip.
2. Studio → **File → Open from File…** → выберите `PetCollectorSimulator.rbxlx`.
3. В Explorer должны быть: `ReplicatedStorage/Shared/…`, `ServerScriptService/Main` + `Server/…`, `StarterPlayer/StarterPlayerScripts/PetFollower`, `StarterGui/PetCollectorGui`.
   (Если Explorer/Properties скрыты: вкладка **View**.)

### Шаг 3. Быстрый тест
1. Вкладка **Home → Play** (или **Test → Local Server** с 2 игроками для проверки питомцев).
2. Нажмите **COLLECT** (или удерживайте), накопите 150 монет, подойдите к яйцу в центре → `E` → **Hatch**.
3. Пока игра не опубликована, DataStore недоступен — игра автоматически работает в режиме «без сохранения» (в Output будет предупреждение). Это нормально.

### Шаг 4. Опубликуйте (нужно для сохранений и покупок)
1. **File → Publish to Roblox As…** → введите название и описание (шаблоны — [`docs/STORE_PAGE.md`](docs/STORE_PAGE.md)) → **Create**.
2. Откройте Creator Hub → **Creations → Experiences** → ваш опыт. (Названия пунктов меню Roblox время от времени меняет.)

### Шаг 5. Включите API Services (для теста сохранений в Studio)
В Studio: **Home → Game Settings → Security → Enable Studio Access to API Services = ON → Save**.
Это нужно **только для тестов в Studio**. В опубликованной игре DataStore работает без этого переключателя.
> ⚠️ При включённом переключателе тесты в Studio пишут в **настоящее хранилище** игры. Для первых экспериментов используйте отдельную копию игры
> (или временно поменяйте `Config.DATASTORE_NAME`), чтобы не смешать тестовые данные с боевыми.

### Шаг 6. Создайте геймпассы
Creator Hub → ваш опыт → **Monetization → Passes → Create a Pass**:
1. Загрузите иконку (квадрат, рекомендуется 512×512 — любая своя картинка/скриншот), введите название и описание (можно взять из `Config.GAMEPASSES`).
2. Создайте 4 геймпасса: **2x Coins, 2x Speed, Auto Collect, VIP**.
3. Откройте каждый → включите **Item for Sale**, задайте цену (ориентиры в таблице выше) → сохраните.
4. Скопируйте числовой **ID** (он есть в URL страницы пасса и в списке).

### Шаг 7. Создайте девелоперские продукты
**Monetization → Developer Products → Create** (7 штук): `GEMS_SMALL`, `GEMS_MEDIUM`, `GEMS_LARGE`, `COINS_SMALL`, `COINS_LARGE`, `LUCK_2X_15M`, `LUCK_5X_10M`.
Название/описание — из `Config.PRODUCTS`, цену задайте в Creator Hub. Скопируйте **Product ID** каждого.

### Шаг 8. Подставьте ID
Studio → Explorer → `ReplicatedStorage → Shared → Config` (двойной клик) → в таблицах `GAMEPASS_IDS` и `PRODUCT_IDS` замените `0` на ваши числа
→ **File → Publish to Roblox** (сохранить опубликованную версию).
> ID привязаны к опыту (universe). Если вы публикуете копию в другой опыт — создавайте пассы/продукты заново и подставляйте новые ID.

### Шаг 9. Проверьте покупки
- В Studio покупки идут через настоящий диалог Roblox; внимательно читайте текст диалога (режим тестовой покупки зависит от версии Studio и вашего аккаунта).
- Надёжная проверка — опубликованная игра + отдельный тестовый аккаунт, **с учётом реального списания Robux**. Покупки пассов/продуктов проверьте по уведомлению в игре и по `Output`/Creator Hub → Analytics → Revenue.

### Шаг 10. Страница игры: иконка, описание, тэги
Creator Hub → ваш опыт → **Settings / Basic info**, **Media**, **Access**: см. подробный чек-лист в [`docs/STORE_PAGE.md`](docs/STORE_PAGE.md)
(иконка 512×512, 3–5+ превью 1920×1080, жанр, устройства, анкета возрастного рейтинга — **отметьте наличие платных случайных предметов**).

### Шаг 11. Откройте игру публично
**Settings → Access / Permissions → Public** (по умолчанию Private) → сохранить. Затем — раскрутка: [`docs/MONETIZATION_GUIDE.md`](docs/MONETIZATION_GUIDE.md).

---

## 5. Работа через Rojo (по желанию)

```bash
rokit install                      # или установите rojo/stylua/selene/luau-lsp вручную (версии в rokit.toml)
rojo serve                         # в Studio поставьте плагин Rojo и нажмите Connect
rojo build -o MyGame.rbxlx         # официальная сборка Rojo
python3 tools/build_rbxlx.py       # то же без Rojo (своя утилита, только Python 3)
bash tools/check_all.sh            # формат + линт + типы + тесты + сборка + валидация .rbxlx
```

## 6. Настройка баланса и контента

- **Цены, множители, лимиты** — `Config.lua`, `UpgradeData.lua`, `ZoneData.lua`, `Formulas.lua`.
- **Добавить питомца** — запись в `PetData.Pets` + строка в `Weight` нужного яйца (сумма весов яйца = 100; тест это проверяет).
- **Добавить яйцо** — `PetData.Eggs` (поле `Zone` определяет, где оно стоит). **Добавить мир** — `ZoneData.List` (мир и яйца появятся сами).
- Баланс (скорость прогрессии, цены) **не обкатан на реальных игроках** — запланируйте итерации по аналитике.

## 7. Документы

| Файл | О чём |
|---|---|
| [`docs/MONETIZATION_GUIDE.md`](docs/MONETIZATION_GUIDE.md) | Монетизация и раскрутка: цены, воронка, Roblox Ads, группы, ивенты, коды, DevEx (правила и ставки) |
| [`docs/HONEST_ASSESSMENT.md`](docs/HONEST_ASSESSMENT.md) | Честная оценка: что нужно для заработка/продажи, риски (модерация, авторские права, правила про лутбоксы), без обещаний |
| [`docs/STORE_PAGE.md`](docs/STORE_PAGE.md) | Название, описание, иконка, тэги, анкета рейтинга, шаблоны текстов |
| [`docs/TESTING.md`](docs/TESTING.md) | Что и как проверено, что НЕ проверено, чек-лист ручного теста в Studio |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Устройство кода: потоки данных, безопасность, как расширять |

## 8. Частые проблемы

| Симптом | Причина / решение |
|---|---|
| В Output: `DataStore unavailable… using temporary data` | В Studio выключены API Services или игра не опубликована — это режим «без сохранения». Включите (шаг 5) после публикации. |
| Кикает с «Could not load your data» на живом сервере | DataStore временно недоступен или данные заняты другим сервером >30 сек. Это защита от потери данных: перезайдите. |
| Кнопка магазина пишет «Soon»/«Not available yet» | ID в `Config` остался `0`. |
| Покупка прошла, награды нет | Смотрите Output: `[Monetization] Unknown ProductId` → ID продукта не добавлен в `PRODUCT_IDS`. Roblox повторит чек автоматически (`NotProcessedYet`). |
| Не видно питомцев | Экипируйте их в панели PETS (слоты: 3 + апгрейды). |
| Нет раздела с гемами/монетами в магазине | Для вашего аккаунта/региона `ArePaidRandomItemsRestricted = true` — так и задумано. |
