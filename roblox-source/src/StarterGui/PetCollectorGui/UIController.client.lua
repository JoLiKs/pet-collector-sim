--!nonstrict
--[[
	UIController — собирает весь интерфейс кодом (никаких ручных ассетов).
	Лежит внутри ScreenGui "PetCollectorGui" (ResetOnSpawn = false), поэтому не дублируется при респавне.
]]
local gui = script.Parent :: ScreenGui
gui.DisplayOrder = 50 -- поверх BillboardGui мира (HP врагов, таблички)
gui.IgnoreGuiInset = false
local Modules = script.Parent:WaitForChild("Modules")

local ClientState = require(Modules:WaitForChild("ClientState"))
local Toasts = require(Modules:WaitForChild("Toasts"))
local Hud = require(Modules:WaitForChild("Hud"))

ClientState.init()
Toasts.init(gui)

local panels = {}
panels.Pets = require(Modules:WaitForChild("PetsPanel")).init(gui)
panels.Upgrades = require(Modules:WaitForChild("UpgradesPanel")).init(gui)
panels.Zones = require(Modules:WaitForChild("ZonesPanel")).init(gui)
panels.Rebirth = require(Modules:WaitForChild("RebirthPanel")).init(gui)
panels.Daily = require(Modules:WaitForChild("DailyPanel")).init(gui)
panels.Shop = require(Modules:WaitForChild("ShopPanel")).init(gui)
panels.Egg = require(Modules:WaitForChild("EggPanel")).init(gui)
panels.Quests = require(Modules:WaitForChild("QuestsPanel")).init(gui)
panels.Craft = require(Modules:WaitForChild("CraftPanel")).init(gui)
panels.Boards = require(Modules:WaitForChild("BoardsPanel")).init(gui)
panels.Trade = require(Modules:WaitForChild("TradePanel")).init(gui)
panels.Index = require(Modules:WaitForChild("IndexPanel")).init(gui) -- v2.5: индекс питомцев
panels.Inventory = require(Modules:WaitForChild("InventoryPanel")).init(gui) -- v2.6: ресурсы и предметы
local Dialog = require(Modules:WaitForChild("DialogPanel")).init(gui)
require(Modules:WaitForChild("HatchPopup")).init(gui)

local function openPanel(name: string, force: boolean?)
	if name == "Worlds" then
		name = "Zones"
	end
	local target = panels[name]
	if not target then
		return
	end
	local wasOpen = target.IsOpen()
	Dialog.Close()
	for _, p in pairs(panels) do
		if p.IsOpen() then
			p.Close()
		end
	end
	if not wasOpen or force then
		target.Open()
	end
end
-- v2.8: окно ежедневной награды открывается само при входе (раз в сутки) — тем же путём, что и вручную
panels.Daily.SetOpener(function()
	openPanel("Daily", true)
end)
panels.Talents = require(Modules:WaitForChild("TalentsPanel")).init(gui, function()
	openPanel("Rebirth", true)
end)
panels.Market = require(Modules:WaitForChild("MarketPanel")).init(gui, function()
	openPanel("Shop", true)
end)
require(Modules:WaitForChild("Fx")).init(gui, function(name: string)
	openPanel(name, true)
end)

-- v2.5: лист «Ещё» — все разделы, убранные с экрана (они же — станции хаба)
panels.More = require(Modules:WaitForChild("MorePanel")).init(gui, openPanel, function()
	return Hud.state or {}
end)
Hud.eggPanel = panels.Egg
Hud.init(gui, openPanel)
require(Modules:WaitForChild("TutorialHud")).init(gui) -- v2.4 (Г3): обучение первой сессии
require(Modules:WaitForChild("SettingsPanel")).init(gui, panels)

-- Смена языка: привязанные тексты (L.k) перерисовывает сам Locale, остальное — повторный снимок состояния
local L = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Locale"))
L.onChanged(ClientState.refresh)
ClientState.requestResync()
