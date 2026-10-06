--!strict
--[[
	Locale — локализация игры (клиент + сервер). Модуль: ReplicatedStorage/Shared/Locale.

	Таблицы строк лежат рядом: LocaleEn (эталон, ключ -> текст) и LocaleRu (тот же набор ключей).
	Кроме ключей есть словарь Names: перевод «данных» (имена питомцев, врагов, зон, ресурсов, рецептов,
	квестов, достижений, талантов, описания) по исходному английскому тексту — так данные остаются
	читаемыми в коде, а тест паритета проверяет, что у каждого имени из data-модулей есть перевод.

	Шаблоны:
	  {name}            — подстановка аргумента args.name;
	  {n|coin|coins}    — плюрализация по числу args.n (en: 1 / прочее; ru: 1 / 2–4 / 5+, напр. {n|монета|монеты|монет}).
	Строковые аргументы, совпадающие с ключом Names, переводятся автоматически (кроме args.player).

	API:
	  Locale.t(key, args)            — текст на текущем языке (клиент: язык игрока, сервер: en);
	  Locale.tp(player, key, args)   — текст на языке конкретного игрока (сервер шлёт уже локализованные тосты);
	  Locale.n(text) / Locale.np(player, text) — перевод «данных» по исходному тексту;
	  Locale.m(key, args)            — «сообщение» (ключ+аргументы) для Notify/Router: локализуется под игрока;
	  Locale.render(player, msg)     — превращает сообщение (таблицу или строку) в текст на языке игрока;
	  Locale.k(key, args)            — маркер для Widgets.New({ Text = Locale.k(...) }): текст перерисуется при смене языка;
	  Locale.detect(country, localeId, manual) — выбор языка (чистая функция, см. правила ниже).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocaleEn = require(script.Parent.LocaleEn)
local LocaleRu = require(script.Parent.LocaleRu)

export type Lang = string
export type Msg = { key: string, args: { [string]: any }? }

local Locale = {}

Locale.DEFAULT = "en"
Locale.LANGS = { "en", "ru" } -- порядок в переключателе
Locale.LANG_NAMES = { en = "English", ru = "Русский" }
Locale.strings = { en = LocaleEn.Strings, ru = LocaleRu.Strings } :: { [string]: { [string]: string } }
Locale.names = { en = {}, ru = LocaleRu.Names } :: { [string]: { [string]: string } }

-- Страны, где по умолчанию включается русский. Украина — отдельно: только если язык клиента русский.
Locale.RU_COUNTRIES = {
	RU = true,
	BY = true,
	KZ = true,
	KG = true,
	AM = true,
	AZ = true,
	MD = true,
	TJ = true,
	UZ = true,
	TM = true,
}

local function isLang(v: any): boolean
	return type(v) == "string" and Locale.strings[v] ~= nil
end
Locale.isLang = isLang

-- Плюральная форма: en 1/прочее; ru 1 / 2–4 / 5+ (11–14 -> много; дробные -> 2-я форма)
function Locale.pluralIndex(lang: string, n: number): number
	if lang == "ru" then
		if n ~= math.floor(n) then
			return 2
		end
		n = math.abs(n)
		local m10, m100 = n % 10, n % 100
		if m10 == 1 and m100 ~= 11 then
			return 1
		elseif m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then
			return 2
		end
		return 3
	end
	return if n == 1 then 1 else 2
end

function Locale.plural(lang: string, n: number, forms: { string }): string
	local i = Locale.pluralIndex(lang, n)
	return forms[math.min(i, #forms)]
end

local function toNumber(v: any): number?
	if type(v) == "number" then
		return v
	elseif type(v) == "string" then
		local clean = string.gsub(v, ",", "")
		return tonumber(clean) -- "1.5K" -> nil -> считаем «много»
	end
	return nil
end

-- Перевод «данных» по исходному английскому тексту
function Locale.nameIn(lang: string, text: string): string
	local dict = Locale.names[lang]
	return dict and dict[text] or text
end

function Locale.format(lang: string, template: string, args: { [string]: any }?): string
	if not args then
		return template
	end
	local a = args :: { [string]: any }
	local pluralRepl = function(name: string, formsText: string): string
		local forms = string.split(formsText, "|")
		local n = toNumber(a[name])
		if n == nil then
			return forms[#forms]
		end
		return Locale.plural(lang, n, forms)
	end
	local out = string.gsub(template, "{([%w_]+)|([^}]*)}", pluralRepl :: any)
	out = string.gsub(out, "{([%w_]+)}", function(name: string)
		local v = a[name]
		if v == nil then
			return "{" .. name .. "}"
		end
		if type(v) == "table" and v.key then
			return Locale.get(lang, v.key, v.args)
		end
		if type(v) == "string" and name ~= "player" then
			if Locale.strings.en[v] then
				return Locale.get(lang, v) -- аргумент-ключ (например, причина ошибки)
			end
			return Locale.nameIn(lang, v)
		end
		return tostring(v)
	end)
	return out
end

function Locale.get(lang: string, key: string, args: { [string]: any }?): string
	local tbl = Locale.strings[lang] or Locale.strings.en
	local template = tbl[key] or Locale.strings.en[key]
	if template == nil then
		return key -- ключ без перевода виден сразу (и ловится тестом паритета)
	end
	return Locale.format(lang, template, args)
end

-- ---------------------------------------------------------------------------------------------
-- Выбор языка
-- ---------------------------------------------------------------------------------------------
local function langFromLocaleId(localeId: any): string?
	if type(localeId) == "string" and string.sub(string.lower(localeId), 1, 2) == "ru" then
		return "ru"
	end
	return nil
end

--[[ Правила (ручной выбор всегда главнее):
	1) manual = "en"/"ru" -> он;
	2) страна из RU_COUNTRIES -> ru;
	3) UA -> ru, только если язык клиента (LocaleId) русский, иначе en;
	4) любая другая известная страна -> en;
	5) страна неизвестна (сервис недоступен) -> по LocaleId ("ru*" -> ru), иначе en.
]]
function Locale.detect(country: string?, localeId: string?, manual: string?): string
	if manual and isLang(manual) then
		return manual
	end
	local c = if type(country) == "string" and country ~= "" then string.upper(country) else nil
	if c == nil then
		return langFromLocaleId(localeId) or Locale.DEFAULT
	end
	if Locale.RU_COUNTRIES[c] then
		return "ru"
	end
	if c == "UA" then
		return langFromLocaleId(localeId) or Locale.DEFAULT
	end
	return Locale.DEFAULT
end

-- ---------------------------------------------------------------------------------------------
-- Текущий язык (клиент) и язык игрока (сервер)
-- ---------------------------------------------------------------------------------------------
local isClient = false
pcall(function()
	isClient = RunService:IsClient()
end)

local current: string? = nil
local listeners: { () -> () } = {}

function Locale.langOf(player: any): string
	if player then
		local ok, v = pcall(function()
			return player:GetAttribute("Lang")
		end)
		if ok and isLang(v) then
			return v
		end
	end
	return Locale.DEFAULT
end

function Locale.lang(): string
	if current then
		return current
	end
	if isClient then
		local lp = Players.LocalPlayer
		if lp then
			local v = lp:GetAttribute("Lang")
			if isLang(v) then
				return v
			end
			local ok, id = pcall(function()
				return lp.LocaleId
			end)
			return langFromLocaleId(ok and id or nil) or Locale.DEFAULT
		end
	end
	return Locale.DEFAULT
end

function Locale.t(key: string, args: { [string]: any }?): string
	return Locale.get(Locale.lang(), key, args)
end

function Locale.tp(player: any, key: string, args: { [string]: any }?): string
	return Locale.get(Locale.langOf(player), key, args)
end

function Locale.n(text: string): string
	return Locale.nameIn(Locale.lang(), text)
end

function Locale.np(player: any, text: string): string
	return Locale.nameIn(Locale.langOf(player), text)
end

function Locale.m(key: string, args: { [string]: any }?): Msg
	return { key = key, args = args }
end

-- Сообщение -> текст на языке игрока. Строка, совпадающая с ключом, тоже переводится.
function Locale.render(player: any, msg: any): string?
	if msg == nil then
		return nil
	end
	local lang = Locale.langOf(player)
	if type(msg) == "table" and type(msg.key) == "string" then
		return Locale.get(lang, msg.key, msg.args)
	end
	if type(msg) == "string" then
		if Locale.strings.en[msg] then
			return Locale.get(lang, msg)
		end
		return Locale.nameIn(lang, msg)
	end
	return tostring(msg)
end

-- Клиент: локализует сообщение по текущему языку
function Locale.renderLocal(msg: any): string?
	if type(msg) == "table" and type(msg.key) == "string" then
		return Locale.t(msg.key, msg.args)
	end
	if type(msg) == "string" then
		if Locale.strings.en[msg] then
			return Locale.t(msg)
		end
		return Locale.n(msg) -- исходный текст «данных» (реплики NPC и т.п.)
	end
	return if msg == nil then nil else tostring(msg)
end

-- ---------------------------------------------------------------------------------------------
-- Тексты мира (билборды, таблички, ProximityPrompt), которые создаёт сервер и видят все игроки.
-- Сервер пишет английский текст + атрибут Loc_<свойство> = encode(key, args); клиентский
-- WorldLocalizer перерисовывает такие свойства на языке своего игрока.
-- ---------------------------------------------------------------------------------------------
local SEP_LINE, SEP_KV = "\n", "\t"

-- key может быть ключом строки или исходным английским текстом «данных» (имя врага и т.п.)
function Locale.encode(key: string, args: { [string]: any }?): string
	local parts = { key }
	if args then
		local names = {}
		for k in pairs(args) do
			table.insert(names, k)
		end
		table.sort(names)
		for _, k in ipairs(names) do
			local v = string.gsub(tostring(args[k]), "[\n\t]", " ")
			table.insert(parts, k .. SEP_KV .. v)
		end
	end
	return table.concat(parts, SEP_LINE)
end

function Locale.decode(s: string): (string, { [string]: any }?)
	local lines = string.split(s, SEP_LINE)
	local key = lines[1]
	if #lines == 1 then
		return key, nil
	end
	local args = {}
	for i = 2, #lines do
		local k, v = string.match(lines[i], "^([^\t]*)\t(.*)$")
		if k then
			args[k] = tonumber(v) or v
		end
	end
	return key, args
end

-- Текст закодированного значения на языке lang
function Locale.renderEncoded(lang: string, s: string): string
	local key, args = Locale.decode(s)
	if Locale.strings.en[key] then
		return Locale.get(lang, key, args)
	end
	return Locale.nameIn(lang, key)
end

-- Сервер: ставит свойство (по умолчанию Text) на английском и атрибут для клиентов
function Locale.setWorld(inst: Instance, key: string, args: { [string]: any }?, prop: string?)
	local p = prop or "Text"
	local enc = Locale.encode(key, args)
	inst:SetAttribute("Loc_" .. p, enc);
	(inst :: any)[p] = Locale.renderEncoded(Locale.DEFAULT, enc)
end

-- ---------------------------------------------------------------------------------------------
-- Привязки текста к инстансам (перерисовка при смене языка)
-- ---------------------------------------------------------------------------------------------
export type Marker = { __k: string, __a: { [string]: any }?, __n: boolean? }

local bindings: { [Instance]: { [string]: Marker } } = setmetatable({}, { __mode = "k" }) :: any

function Locale.k(key: string, args: { [string]: any }?): Marker
	return { __k = key, __a = args }
end

-- Маркер для текста «данных» (имя/описание из data-модулей): переводится через Names
function Locale.kn(text: string): Marker
	return { __k = text, __n = true }
end

local function markerText(m: Marker): string
	if m.__n then
		return Locale.n(m.__k)
	end
	return Locale.t(m.__k, m.__a)
end

function Locale.isMarker(v: any): boolean
	return type(v) == "table" and type(v.__k) == "string"
end

function Locale.bind(inst: Instance, prop: string, marker: Marker)
	local set = bindings[inst]
	if not set then
		set = {}
		bindings[inst] = set
	end
	set[prop] = marker;
	(inst :: any)[prop] = markerText(marker)
end

function Locale.unbind(inst: Instance, prop: string)
	local set = bindings[inst]
	if set then
		set[prop] = nil
	end
end

function Locale.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

function Locale.setLang(lang: string)
	if not isLang(lang) or lang == current then
		return
	end
	current = lang
	for inst, set in pairs(bindings) do
		if inst.Parent ~= nil then
			for prop, marker in pairs(set) do
				(inst :: any)[prop] = markerText(marker)
			end
		end
	end
	for _, fn in ipairs(listeners) do
		task.spawn(fn)
	end
end

-- Клиент: следим за атрибутом Lang, который ставит сервер
if isClient then
	task.spawn(function()
		local lp = Players.LocalPlayer
		if not lp then
			return
		end
		local function sync()
			local v = lp:GetAttribute("Lang")
			if isLang(v) and v ~= current then
				Locale.setLang(v)
			end
		end
		lp:GetAttributeChangedSignal("Lang"):Connect(sync)
		sync()
	end)
end

return Locale
