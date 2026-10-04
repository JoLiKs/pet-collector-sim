--!nonstrict
--[[
	UIController — собирает весь интерфейс кодом (никаких ручных ассетов).
	Лежит внутри ScreenGui "PetCollectorGui" (ResetOnSpawn = false), поэтому не дублируется при респавне.
]]
local gui = script.Parent :: ScreenGui
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
require(Modules:WaitForChild("HatchPopup")).init(gui)

local function openPanel(name: string)
	local target = panels[name]
	if not target then
		return
	end
	local wasOpen = target.IsOpen()
	for _, p in pairs(panels) do
		if p.IsOpen() then
			p.Close()
		end
	end
	if not wasOpen then
		target.Open()
	end
end

Hud.init(gui, openPanel)
ClientState.requestResync()
