# Pet Collector Simulator — браузерная демо-симуляция

▶ **Играть: https://joliks.github.io/pet-collector-sim/**

> ⚠️ Это **браузерная демо-симуляция**, а **не** сама Roblox-игра. Графика упрощена (2D-канвас), нет мультиплеера,
> серверного сохранения и настоящих платежей. Магазин, геймпассы и продукты — **кнопки-демо**, лидерборд — **вымышленные игроки + ваш локальный результат**.

Исходный проект Roblox (Rojo + Luau) лежит в папке [`roblox-source/`](roblox-source/). Числа и формулы в демо взяты именно оттуда.

## Что воспроизведено

| Механика | Откуда взято |
|---|---|
| Клик/сбор монет: `(1 + Click Power) × (1 + сила экипированных питомцев) × множитель мира × множитель ребёрта × бонусы` | `Economy.getPerClick`, `Formulas.clickBase` |
| Лимит кликов (12/с, всплеск 6), автосбор (2 клика/с, геймпасс) | `ClickService`, `Config` |
| 6 яиц и 35 питомцев, 6 редкостей (Common…Mythic), шансы по весам, влияние удачи на Rare+ , 2% золотых питомцев (×2 сила) | `PetData.lua`, `Economy.getLuck` |
| Питомцы следуют за игроком веером (формула `PetFollower`), слоты 3 + апгрейд + VIP, «надеть лучших», продажа | `PetService`, `PetFollower.client.lua` |
| 5 апгрейдов (Click, Speed, Luck, Bag, Slots) с ценами `BaseCost × Growth^level` и списком цен для гемов | `UpgradeData.lua`, `Formulas.upgradeCost` |
| 5 миров (×1/×3/×9/×27/×81), цены открытия, ограничение по ребёртам | `ZoneData.lua` |
| Ребёрт: цена `50000 × 4^n`, +50% к монетам за ребёрт, гемы `20 + 5n` | `Formulas`, `RebirthService` |
| Ежедневная награда: цикл 7 дней, серия (стрик), VIP ×2, Premium +5 гемов (кнопка «перемотать день» — только для демо) | `DailyService`, `Config.DAILY_REWARDS` |
| Геймпассы и продукты (гемы, монеты, лаки-бусты) | `Config.lua`, `Monetization.lua` — **кнопки-демо** |
| Сохранение | `localStorage` браузера (в оригинале — DataStore) |
| Язык интерфейса RU / EN | переключатель вверху |

Названия питомцев, миров и яиц остаются английскими — как в оригинале (в нём UI только на английском).

## Чего здесь НЕТ (честно)

- Это не Roblox: нет 3D-мира, физики, настоящих моделей, звука, других игроков, анти-эксплойта, DataStore, `ProcessReceipt`.
- Политика платных случайных предметов (`PolicyService`) в демо не моделируется: платная удача действует всегда.
- Баланс оригинала не обкатан на людях (см. `roblox-source/docs/HONEST_ASSESSMENT.md`) — демо лишь показывает механику.

## Как это сделано

Сайт — статический (чистые HTML/CSS/JS без сборки). Данные (`data.js`) **сгенерированы** конвертером
[roblox2web](https://github.com/JoLiKs/roblox2web) прямо из Luau-файлов `roblox-source/` (парсер Luau-таблиц + выполнение
функций-конструкторов в песочнице), а формулы `Formulas.lua` при сборке сверены с формулами, реализованными в `game.js`.

Локальный запуск: открыть `index.html` в браузере (работает и с `file://`) или `python3 -m http.server`.

Пересборка из исходников:

```bash
git clone https://github.com/JoLiKs/roblox2web && cd roblox2web
python3 roblox2web.py examples/PetCollectorSimulator.zip -o ../site
```

## Файлы

- `index.html`, `style.css`, `game.js`, `i18n.js`, `data.js` — игра
- `CONVERSION_REPORT.txt`, `conversion-report.json` — отчёт конвертера (что найдено, предупреждения)
- `roblox-source/` — исходный Roblox-проект (Rojo): `src/`, `default.project.json`, `docs/`, `tests/`, `tools/`, `PetCollectorSimulator.rbxlx` (текстовый place-файл)
