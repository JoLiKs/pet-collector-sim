--!strict
--[[
	LanguageService — язык интерфейса игрока.
	  * ручной выбор (data.Settings.Lang = "en" | "ru") всегда главнее;
	  * "auto": страна из LocalizationService:GetCountryRegionForPlayerAsync (pcall) ->
	    RU/BY/KZ/KG/AM/AZ/MD/TJ/UZ/TM — русский; UA — русский только при русском LocaleId клиента; прочие — английский;
	  * страна недоступна -> player.LocaleId / LocalizationService.RobloxLocaleId ("ru*" -> русский), иначе английский.
	Итог пишется в атрибуты игрока: Lang (действующий язык), LangAuto (что выбрал бы автоопределитель), Country.
	Клиентский Locale следит за атрибутом Lang и перерисовывает интерфейс.
]]
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locale = require(ReplicatedStorage.Shared.Locale)

local DataService = require(script.Parent.DataService)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local LanguageService = {}

LanguageService.CHOICES = { auto = true, en = true, ru = true }

local countries: { [Player]: string | boolean } = {}

-- Код страны (ISO 3166-1 alpha-2) или nil, если сервис недоступен. Кэшируется на сессию.
function LanguageService.country(player: Player): string?
	local cached = countries[player]
	if cached ~= nil then
		return if type(cached) == "string" then cached else nil
	end
	local ok, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	local c = if ok and type(code) == "string" and code ~= "" then string.upper(code) else nil
	countries[player] = c or false
	return c
end

function LanguageService.localeId(player: Player): string?
	local ok, id = pcall(function()
		return (player :: any).LocaleId
	end)
	if ok and type(id) == "string" and id ~= "" then
		return id
	end
	local ok2, id2 = pcall(function()
		return (LocalizationService :: any).RobloxLocaleId
	end)
	if ok2 and type(id2) == "string" and id2 ~= "" then
		return id2
	end
	return nil
end

-- Определяет и применяет язык; возвращает действующий язык
function LanguageService.apply(player: Player): string
	local data = DataService.get(player)
	local manual = data and data.Settings and data.Settings.Lang
	local country = LanguageService.country(player)
	local localeId = LanguageService.localeId(player)
	local auto = Locale.detect(country, localeId, nil)
	local lang = Locale.detect(country, localeId, if manual ~= "auto" then manual else nil)
	player:SetAttribute("Country", country or "")
	player:SetAttribute("LangAuto", auto)
	player:SetAttribute("Lang", lang)
	return lang
end

function LanguageService.init()
	Router.register("SetLanguage", 2, 3, function(player: Player, choice: any)
		local data = DataService.get(player)
		if not data or type(choice) ~= "string" or not LanguageService.CHOICES[choice] then
			return false, "err.bad_request"
		end
		data.Settings.Lang = choice
		LanguageService.apply(player)
		State.markCore(player)
		return true, nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		countries[player] = nil
	end)
end

return LanguageService
