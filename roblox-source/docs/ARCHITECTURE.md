# Архитектура

## Принципы
1. **Сервер — единственный источник истины.** Клиент отправляет *намерения* (`Click`, `Action("Hatch", eggId, count)`), сервер валидирует и считает.
2. **Один вход для действий** — `RemoteFunction "Action"` + `Router` (rate-limit, проверка готовности, pcall, единый формат ответа `{ok, msg}`). Исключение — высокочастотный `Click` (`RemoteEvent` с собственным token bucket).
3. **Состояние → клиенту одним способом**: `State` формирует снимки (`Core` часто, `Pets` редко) и шлёт не чаще ~6 раз/сек.
4. **Данные только через `DataService`**; изменение валют — только через `Economy`.
5. **Нет внешних ассетов**: мир (`WorldBuilder`), питомцы (`PetModel`), интерфейс (`StarterGui/PetCollectorGui`) строятся кодом.

## Поток «открыть яйцо»
`ProximityPrompt (сервер)` → `OpenEgg` (клиенту) → окно шансов (`EggPanel`) → `Action("Hatch", eggId, 1|3)` → `Router` (rate-limit) → `PetService.hatch`:
проверка аргументов → мир открыт? → игрок рядом с яйцом? → место в сумке? → `Economy.trySpend` → бросок (`PetData.roll` с удачей) → запись питомцев → `State.markPets` → `HatchResult` клиенту (анимация).

## Модули

| Модуль | Роль |
|---|---|
| `Config` | ID пассов/продуктов, баланс, лимиты, параметры античита |
| `PetData` / `ZoneData` / `UpgradeData` / `Formulas` | Данные и формулы (используются и сервером, и клиентом для отображения) |
| `PetModel` | Строит модель питомца из примитивов |
| `Remotes` | Создание/получение Remote-объектов |
| `DataService` | DataStore: session lock, ретраи, автосейв, BindToClose |
| `Session` | Временное состояние игрока (пассы, Premium, политика, лимиты) |
| `Economy` | Множители, удача, трата/начисление валют |
| `State` | Снимки состояния клиенту, атрибут `EquippedPets` для отрисовки питомцев |
| `Router` | Вход для действий клиента |
| `AntiExploit` | Страйки, принудительные WalkSpeed/Jump, проверка скорости |
| `ClickService`, `PetService`, `UpgradeService`, `ZoneService`, `RebirthService`, `DailyService` | Игровые механики |
| `Monetization` | Геймпассы, продукты, `ProcessReceipt`, Premium, `PolicyService` |
| `LeaderboardService` | `OrderedDataStore` + табло в мире |
| `PlayerService` | Жизненный цикл: загрузка → leaderstats → персонаж → выход |
| `WorldBuilder` | Мир, яйца, табло |

## Структура данных игрока (DataStore)

```
{ Version, Coins, Gems, Rebirths, TotalCoins, TotalHatched, TotalClicks,
  Pets = { [uid] = { Id, Gold } }, NextPetId, Equipped = { uid, ... },
  Upgrades = { Click, Speed, Luck, Bag, Slots }, Zones = { [id] = true }, CurrentZone,
  Daily = { LastDay, Streak }, Boosts = { Luck2, Luck5 }, AutoCollect,
  Receipts = { [PurchaseId] = unixTime }, Joined }
```
Запись в хранилище: `{ Data = <выше>, Lock = { SessionId, Time }, SavedAt }`. Новые поля добавляются в шаблон — `reconcile` дополнит старые профили.

## Безопасность — что и как
- Типы/диапазоны аргументов проверяются в каждом обработчике; NaN/inf/таблицы вместо чисел отклоняются.
- Цены/шансы/множители не приходят от клиента.
- Rate-limit на всех действиях; страйки → кик при систематическом злоупотреблении.
- Яйца: проверка расстояния от персонажа (серверная позиция).
- Скорость/прыжок принудительно задаются сервером; горизонтальная скорость контролируется.
- Покупки: идемпотентность по `PurchaseId`, награда и чек записываются вместе и сохраняются до подтверждения.

**Ограничения:** это базовый уровень. От читерства «в духе» автокликеров на стороне клиента защищает лимит частоты; от модифицированных клиентов с нестандартной физикой — только частично. Для крупного проекта добавьте логирование, аномалии по метрикам, бан-лист, серверные проверки полёта/ноклипа.

## Как расширять
- **Новый питомец**: `PetData.Pets` + вес в `Eggs[...].Pets` (сумма весов = 100).
- **Новое яйцо**: `PetData.Eggs` (поле `Zone`), стенд создастся `WorldBuilder` автоматически.
- **Новый мир**: `ZoneData.List` (позиция по оси X с шагом 400), добавьте яйцо.
- **Новый апгрейд**: `UpgradeData.List` + место, где он влияет (`Formulas`/`Economy`) + поле в шаблоне `DataService`.
- **Новый продукт**: `Config.PRODUCT_IDS` + `Config.PRODUCTS` + ветка в `Monetization.grantProduct` (если новый `Kind`) + карточка в `ShopPanel`.
- **Промокоды** (идея): `Action("Redeem", code)` с серверной таблицей кодов и защитой от повторов (хранить использованные коды в данных).
