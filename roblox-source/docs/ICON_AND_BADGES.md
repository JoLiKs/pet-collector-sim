# Иконка, превью, значки (badges) и логотип — v2.6

Все картинки уже лежат в репозитории, их нужно только загрузить в Roblox и вписать полученные ID
в `src/ReplicatedStorage/Config.lua`. Пока ID равен `0`, игра работает без ошибок: логотип рисуется
примитивами, значки просто не выдаются.

| Файл | Размер | Куда |
|---|---|---|
| `assets/icon_512.png` | 512×512 | иконка игры (Experience Icon) и логотип в самой игре (`Config.ASSETS.LOGO`) |
| `assets/badge_512.png` | 512×512, важное — в центральном круге | картинка значка «Добро пожаловать» (Roblox обрезает значки кругом) |
| `assets/thumbnail_1920x1080.png` | 1920×1080 | превью (Thumbnail) на странице игры |
| `assets/variants/icon_b.png`, `icon_c.png` | 512×512 | запасные варианты иконки (основной — вариант A) |
| `assets/*.svg` | — | исходники, пересборка: `python3 tools/art/make_art.py` (нужен google-chrome + playwright) |

## 1. Иконка и превью игры

1. Creator Hub (create.roblox.com) → **Creations** → ваша игра → **Configure** → **Basic Info** (в некоторых
   версиях интерфейса — раздел **Places / Icon / Thumbnails**).
2. **Icon** → загрузите `assets/icon_512.png`.
3. **Thumbnails** → загрузите `assets/thumbnail_1920x1080.png` (можно добавить и скриншоты из `docs/screens/`).
4. Иконка и превью проходят модерацию (обычно минуты). Это не требует правок в коде.

## 2. Логотип внутри игры (экран загрузки и табличка в хабе)

1. Studio → **View → Asset Manager → Images → Bulk Import** (или Creator Hub → Development Items →
   Decals → Upload Asset) → `assets/icon_512.png`.
2. В Asset Manager: ПКМ по картинке → **Copy Asset ID**.
   Важно: нужен ID именно **Image**, а не Decal. Если загружали как Decal, ID картинки обычно другой
   (откройте Decal в Studio: в свойстве `Texture` будет `rbxassetid://<ID картинки>`).
3. Впишите ID: `Config.ASSETS.LOGO = <ID>`.

Где виден логотип: `src/ReplicatedFirst/LoadingScreen.client.lua` (экран загрузки) и табличка
`Workspace/World/Hub/LogoSign` за фонтаном (BillboardGui). Без ID (`0`) — логотип из примитивов
(`src/ReplicatedStorage/Logo.lua`). Так же можно (необязательно) задать PNG для иконок валют/ресурсов:
`Config.ASSETS.COIN`, `GEM`, `WOOD`, `STONE`, … — без них иконки рисуются примитивами (`Icons.lua`).

## 3. Значки (Badges)

1. Creator Hub → **Creations** → игра → **Engagement → Badges** → **Create a Badge**.
2. Имя/описание, например:
   - WELCOME — «Добро пожаловать! / Welcome!» — картинка `assets/badge_512.png`;
   - FIRST_BOSS — «Победитель босса / Boss Slayer» (необязательно);
   - FIRST_REBIRTH — «Первое перерождение / First Rebirth» (необязательно);
   - SUPERPOWER — «Суперсила / Superpower» (необязательно).
   Для необязательных можно взять ту же картинку или сделать свою (512×512, всё важное — в круге).
3. Roblox даёт бесплатно создавать ограниченное число значков в сутки, сверх лимита — за Robux
   (условия смотрите при создании).
4. ID значка: меню «…» у значка → **Copy Asset ID** (или число в адресе `roblox.com/badges/<ID>/...`).
5. Впишите в `Config.BADGES`:

```lua
Config.BADGES = {
	WELCOME = 1234567890, -- выдаётся при первом входе
	FIRST_BOSS = 0, -- первый побеждённый босс
	FIRST_REBIRTH = 0, -- первое перерождение
	SUPERPOWER = 0, -- игрок впервые получил Суперсилу
}
```

Выдача: `src/ServerScriptService/Server/Badges.lua` — `UserHasBadgeAsync` → `AwardBadge` в `pcall`
(с повтором при ошибке сервиса), значки с ID `0` пропускаются. Вызовы: PlayerService (WELCOME),
CombatService (FIRST_BOSS), RebirthService (FIRST_REBIRTH), SuperpowerService (SUPERPOWER).
Значки выдаются только в опубликованной игре (в Studio `AwardBadge` может вернуть ошибку — она
перехватывается и пишется в Output как предупреждение).

## 4. Веб-демо

В демо картинка логотипа показывается через сопоставление ассетов roblox2web (с v2.4.0):
`roblox2web.config.json` → `"assets": { "920001": "assets/icon_512.png" }` и патч
`Config.ASSETS.LOGO = 920001`. Исходники игры при этом не меняются.
