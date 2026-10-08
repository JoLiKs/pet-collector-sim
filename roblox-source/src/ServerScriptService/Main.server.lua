--!strict
--[[
	Main — точка входа сервера. Порядок важен: сначала Remotes и мир, затем сервисы (регистрируют действия),
	и только потом PlayerService (начинает принимать игроков).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false -- персонажей создаём сами, когда данные игрока загружены

local Server = script.Parent:WaitForChild("Server")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.init()

local WorldBuilder = require(Server.WorldBuilder)
WorldBuilder.build()

require(Server.DataService).init()
require(Server.Router).init()
require(Server.State).init()
require(Server.AntiExploit).init()
require(Server.ClickService).init()
require(Server.PetService).init()
require(Server.UpgradeService).init()
require(Server.ZoneService).init()
require(Server.RebirthService).init()
require(Server.DailyService).init()
require(Server.ResourceService).init()
require(Server.CombatService).init()
require(Server.CraftService).init()
require(Server.QuestService).init()
require(Server.StationService).init()
require(Server.ShopService).init()
require(Server.BattlePassService).init()
require(Server.TradeService).init()
require(Server.SuperpowerService).init()
require(Server.SuperBots).init()
require(Server.OfflineService).init()
require(Server.EventService).init()
require(Server.Monetization).init()
require(Server.LeaderboardService).init()
require(Server.LanguageService).init()
require(Server.TutorialService).init()
require(Server.ToolService).init() -- v2.5: меч и магнит в StarterPack (до первого появления персонажа)
require(Server.PlayerService).init()

print("[PetCollector] Server started. JobId:", game.JobId)
