# Pet Collector Simulator v2.2 — веб-демо на реальном Luau-коде

▶ **Играть: https://joliks.github.io/pet-collector-sim/**

Это **не переписанная на JS копия**: страница запускает **исходные Luau-скрипты игры** из [`roblox-source/`](roblox-source/) —
их переводит в JavaScript транспилятор [roblox2web](https://github.com/JoLiKs/roblox2web) (<https://joliks.github.io/roblox2web/>),
а `Workspace`, `Players`, `RemoteEvent`, `DataStore`, GUI, 3D (three.js) эмулирует его же рантайм. Серверные скрипты, клиентский интерфейс и общие модули выполняются в одной вкладке.

## Скачать
* [`PetCollectorSimulator_v2.2.zip`](PetCollectorSimulator_v2.2.zip) — проект целиком (src, документация, тесты, `.rbxlx`)
* [`PetCollectorSimulator.rbxlx`](PetCollectorSimulator.rbxlx) — готовое место для Roblox Studio
* [`PetCollectorSimulator_web.zip`](PetCollectorSimulator_web.zip) — эта веб-версия для самостоятельного хостинга
* Скриншоты: [`roblox-source/docs/screens/`](roblox-source/docs/screens/), документация: [`roblox-source/docs/`](roblox-source/docs/)

![Хаб](roblox-source/docs/screens/01_hub.png)

## Язык
Игра на **русском или английском**: страна определяется по IP (Cloudflare `cdn-cgi/trace` → geojs.io → country.is → ipapi.co, до ~2 с), при неудаче — по языку браузера. RU/BY/KZ/KG/AM/AZ/MD/TJ/UZ/TM → русский; Украина → русский только при русском языке браузера. Переключатель — кнопка **НАСТРОЙКИ / SETTINGS** под валютами.

## Управление
* **WASD / стрелки** — ходьба, **ЛКМ-перетаскивание** — камера, **Пробел** — прыжок
* **E** — действие рядом с объектом (яйца, NPC, верстак, рынок, ресурсы, сундуки)
* **COLLECT / СОБРАТЬ** или **F** — собрать монеты, **ATTACK / УДАР** или **Q** — удар мечом
* Меню слева: Pets · Quests · Craft · Market · Worlds · Talents · Trade · Top · Daily · Upgrades · Rebirth · Store

## Что внутри игры (всё — Luau)
Хаб с NPC и станциями + 5 биомов, добыча ресурсов и сундуки с респавном, враги и боссы с ИИ, автоатака питомцев и ручной удар, события (Золотой дождь, Лунная ночь, рейд-босс Stone Colossus),
39 питомцев (4 стихии, 3 роли, 6 редкостей, варианты Golden/Rainbow/Shiny), уровни и эволюция, слияние 3→1, команда, избранное и фильтры, крафт, квесты с диалогами NPC и ежедневные, достижения, ребёрт с деревом талантов, торговля (в демо — с ботом Tom), ротация магазина, батл-пасс, оффлайн-доход, лидерборды, монетизация (геймпассы/продукты: в демо — диалог «купить» без реальных платежей).

## Параметры URL
`?country=RU` / `?country=US` — страна (язык игры по стране) · `?lang=en` / `?lang=ru` — язык браузера (без гео-запроса) · `?persist=0` — не сохранять прогресс · `?premium=1` — Premium-игрок · `?seed=N` — зерно случайности · `?touch=1` — тач-режим · `?autobuy=1` — демо-покупки без диалога · `?quiet=1` — меньше логов.
Кнопка «Сброс» в шапке стирает сохранение (localStorage). Время в эмуляторе виртуальное (идёт по кадрам), поэтому на слабом компьютере события и таймеры идут медленнее.

## Ограничения демо
Один локальный игрок (торговец Tom и «друг» — серверные боты), нет настоящей сети/DataStore/платежей, MeshPart рисуются коробками, нет звука, анимаций и частиц, SurfaceGui (табло лидеров) не отображается. Подробности — в [README](roblox-source/README.md) проекта.
