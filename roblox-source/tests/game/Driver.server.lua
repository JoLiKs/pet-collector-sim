--!nocheck
-- Интеграционный сценарий (запускается в эмуляторе roblox2web как серверный Script рядом с игрой).
-- Идёт по реальным путям кода: Router -> сервисы -> данные. Печатает "OK имя" / "FAIL имя: причина" и "DONE".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Main"):WaitForChild("Server", 5)
	or ServerScriptService:WaitForChild("Server")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local PetMeta = require(Shared.PetMeta)
local ZoneData = require(Shared.ZoneData)
local EventData = require(Shared.EventData)
local BattlePassData = require(Shared.BattlePassData)
local TradeLogic = require(Shared.TradeLogic)

local DataService = require(Server.DataService)
local Economy = require(Server.Economy)
local Session = require(Server.Session)
local Progress = require(Server.Progress)
local WorldBuilder = require(Server.WorldBuilder)
local ShopLogic = require(Server.ShopLogic)
local AntiExploit = require(Server.AntiExploit)
local QuestService = require(Server.QuestService)
local EventService = require(Server.EventService)
local CombatService = require(Server.CombatService)
local TradeService = require(Server.TradeService)
local OfflineService = require(Server.OfflineService)
local Migrations = require(Server.Migrations)

local fails = 0
local function check(name, cond, msg)
	if cond then
		print("OK " .. name)
	else
		fails += 1
		print("FAIL " .. name .. ": " .. tostring(msg or "condition false"))
	end
end

-- «Суперсилу» включаем только в своём разделе (§ 14): случайные раунды не должны мешать остальным проверкам.
-- (run.js применяет патчи roblox2web.config.json, поэтому DEMO_BOTS здесь = true, как в веб-демо.)
Workspace:SetAttribute("SuperpowerPaused", true)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local t0 = os.clock()
while
	not (
		Session.get(player)
		and Session.get(player).Ready
		and player.Character
		and player.Character:FindFirstChild("HumanoidRootPart")
	)
do
	task.wait(0.1)
	if os.clock() - t0 > 30 then
		print("FAIL startup: player never became ready")
		print("DONE")
		return
	end
end
task.wait(0.5)
local data = DataService.get(player)
local function root()
	return player.Character:FindFirstChild("HumanoidRootPart")
end
local function call(action, ...)
	local fn = Remotes.getFunction("Action")
	local res = fn.OnServerInvoke(player, action, ...)
	task.wait(if action == "Teleport" then 1.5 else 0.35) -- лимиты частоты Router
	return res
end
local function solidParts(model)
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			n += 1
		end
	end
	return n
end
local function moveTo(pos)
	AntiExploit.markTeleport(player)
	player.Character:PivotTo(CFrame.new(pos + Vector3.new(0, 4, 0)))
	task.wait(0.2)
end
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end
local function sumTable(t)
	local n = 0
	for _, v in pairs(t) do
		n += v
	end
	return n
end

-- ===== 1. Старт ===========================================================
local r = root().Position
check("spawn in hub", Vector3.new(r.X, 0, r.Z).Magnitude <= ZoneData.HUB_RADIUS, tostring(r))
check(
	"data template v2",
	data.Version == 2 and data.Resources ~= nil and data.Quests ~= nil and data.BattlePass ~= nil
)
check(
	"world has hub + 5 zones",
	Workspace.World:FindFirstChild("Hub") ~= nil and Workspace.World:FindFirstChild("Volcano") ~= nil
)
check("enemies spawned", #Workspace.Enemies:GetChildren() >= 30, #Workspace.Enemies:GetChildren())
check("nodes spawned", #Workspace.Nodes.Meadow:GetChildren() >= 9)
check("friend bonus counts demo bot", Session.get(player).Friends == 1, Session.get(player).Friends)

data.Coins = 5e6
data.Gems = 600

-- ===== 2. Миры, яйца ======================================================
local res = call("Teleport", "Forest")
check("teleport locked world rejected", res.ok == false)
res = call("Teleport", "Meadow")
check(
	"teleport Meadow",
	res.ok == true and (root().Position - ZoneData.ById.Meadow.Position).Magnitude < 100,
	root().Position
)
res = call("Hatch", "MeadowEgg", 3)
check("hatch needs proximity", res.ok == false, res.msg)
moveTo(WorldBuilder.getEggPosition("MeadowEgg"))
res = call("Hatch", "MeadowEgg", 3)
check("hatch x3", res.ok == true and count(data.Pets) == 3, res.msg)
local anyUid, anyPet = next(data.Pets)
check("pet fields", anyPet.Level == 1 and anyPet.Evo == 0 and anyPet.Variant ~= nil)
res = call("EquipBest")
check("equip best", res.ok and #data.Equipped == 3, #data.Equipped)
res = call("Hatch", "LunarEgg", 1)
check("lunar egg locked outside event", res.ok == false)
res = call("SetFav", anyUid, true)
check("favorite", res.ok and data.Pets[anyUid].Fav == true)
res = call("Unequip", anyUid)
res = call("Sell", anyUid)
check("favorite pet cannot be sold", res.ok == false and data.Pets[anyUid] ~= nil, res.msg)
call("SetFav", anyUid, false)
call("Equip", anyUid)

-- ===== 3. Добыча ==========================================================
local node
for _, m in ipairs(Workspace.Nodes.Meadow:GetChildren()) do
	if m:GetAttribute("Res") == "Wood" then
		node = m
		break
	end
end
check("found wood node", node ~= nil)
local before = data.Resources.Wood or 0
moveTo(node.PrimaryPart.Position + Vector3.new(4, 0, 0))
local prompt = node:FindFirstChildWhichIsA("ProximityPrompt", true)
prompt:InputHoldBegin()
task.wait(0.3)
check("gather wood", (data.Resources.Wood or 0) > before, data.Resources.Wood)
check("gather stat", (data.Stats.Gathered or 0) >= 1)
check("node depleted", node:GetAttribute("Depleted") == true)
check("v2.4 С6: depleted node is not solid", solidParts(node) == 0, solidParts(node))
local chest
for _, m in ipairs(Workspace.Nodes.Meadow:GetChildren()) do
	if m.Name:sub(1, 5) == "Chest" then
		chest = m
		break
	end
end
local coinsBefore, gemsBefore = data.Coins, data.Gems
local resBefore = sumTable(data.Resources) + sumTable(data.Items)
moveTo(chest.PrimaryPart.Position + Vector3.new(4, 0, 0))
chest:FindFirstChildWhichIsA("ProximityPrompt", true):InputHoldBegin()
task.wait(0.3)
check(
	"chest looted",
	data.Coins > coinsBefore
		or data.Gems > gemsBefore
		or sumTable(data.Resources) + sumTable(data.Items) > resBefore
)
task.wait(25)
check("node respawns", node:GetAttribute("Depleted") == false)
check("v2.4 С6: respawned node is solid again", solidParts(node) > 0, solidParts(node))

-- ===== 4. Бой =============================================================
local function nearestEnemy(zone)
	local best, bd = nil, 1e9
	for _, e in ipairs(Workspace.Enemies:GetChildren()) do
		if e:GetAttribute("Zone") == zone and not e:GetAttribute("IsBoss") then
			local d = (e.PrimaryPart.Position - root().Position).Magnitude
			if d < bd then
				best, bd = e, d
			end
		end
	end
	return best
end
local e = nearestEnemy("Meadow")
check("enemy found", e ~= nil)
local killsBefore = data.Stats.Kills or 0
local coinsBefore2 = data.Coins
moveTo(e.PrimaryPart.Position + Vector3.new(5, 0, 0))
local hpBefore = e:GetAttribute("Hp")
for _ = 1, 40 do
	if e.Parent == nil then
		break
	end
	local ar = call("Attack", e:GetAttribute("Id"))
	if not ar.ok then
		print(
			"INFO attack",
			ar.msg,
			e:GetAttribute("Hp"),
			tostring(e.PrimaryPart.Position),
			tostring(root().Position),
			tostring(e:GetPivot().Position)
		)
	end
	task.wait(0.25)
end
task.wait(1.5)
check(
	"enemy killed",
	e.Parent == nil and (data.Stats.Kills or 0) > killsBefore,
	("kills %s hp %s"):format(tostring(data.Stats.Kills), tostring(hpBefore))
)
check("kill coins", data.Coins > coinsBefore2)
-- Луты с убийства: ресурсы и/или фрагменты/гемы (монеты уже проверены)
local resLoot = false
for _, r in ipairs({ "Wood", "Stone", "Ore", "Herb", "Crystal", "Essence", "Fragment" }) do
	if (data.Resources[r] or 0) > 0 then
		resLoot = true
		break
	end
end
check("kill loot resources/fragments", resLoot or data.Gems > 0)
-- Атака в воздух: в хабе без врагов рядом — ok, без тоста «No enemy in range»
moveTo(Vector3.new(0, 3, 0))
task.wait(1.2) -- восстановить token bucket Attack
local air = call("Attack")
check("air swing ok", air.ok == true, tostring(air and air.msg))
check(
	"air swing no range toast",
	air.msg ~= "No enemy in range" and air.msg ~= "Too far",
	tostring(air and air.msg)
)
local xpGained = false
for _, p in pairs(data.Pets) do
	if (p.Xp or 0) > 0 or (p.Level or 1) > 1 then
		xpGained = true
	end
end
check("pets gained xp", xpGained)
check("battle pass xp from combat", data.BattlePass.Xp > 0)
local playerHum = player.Character:FindFirstChildOfClass("Humanoid")
playerHum.Health = playerHum.MaxHealth
local hp0 = playerHum.Health
local boar = nearestEnemy("Meadow")
moveTo(boar.PrimaryPart.Position + Vector3.new(3, 0, 0))
task.wait(6)
check("enemies hurt the player", playerHum.Health < hp0 or boar.Parent == nil, playerHum.Health)
task.wait(6)

-- ===== 5. Крафт и питомцы =================================================
res = call("Teleport", "Hub")
check(
	"back in hub",
	Vector3.new(root().Position.X, 0, root().Position.Z).Magnitude <= ZoneData.HUB_RADIUS,
	tostring(res.msg) .. tostring(root().Position)
)
data.Resources = { Wood = 30, Herb = 20, Ore = 20, Crystal = 10, Stone = 20, Essence = 200 }
res = call("Craft", "r_treat", 1)
check("craft treats", res.ok and data.Items.xp_treat == 3, res.msg)
res = call("Craft", "r_blade", 1)
check("craft blade", res.ok and data.Items.blade == 1, res.msg)
res = call("Craft", "r_luck", 100)
check("craft bad amount rejected", res.ok == false)
data.Resources = {}
res = call("Craft", "r_t_frost", 1)
check("craft needs resources", res.ok == false, res.msg)
moveTo(Vector3.new(ZoneData.ById.Meadow.Position.X, 0, 0))
res = call("Craft", "r_treat", 1)
check("craft only in hub", res.ok == false, res.msg)
call("Teleport", "Hub")
local feedUid
for uid in pairs(data.Pets) do
	feedUid = uid
	break
end
local xp0 = data.Pets[feedUid].Xp + (data.Pets[feedUid].Level - 1) * 1000
res = call("FeedPet", feedUid)
check("feed pet", res.ok and (data.Pets[feedUid].Xp + (data.Pets[feedUid].Level - 1) * 1000) > xp0, res.msg)
res = call("UseItem", "luck_potion")
check("use item missing", res.ok == false)
Economy.addItem(player, "luck_potion", 1)
Economy.addItem(player, "coin_elixir", 1)
check("use luck potion", call("UseItem", "luck_potion").ok and data.Boosts.Luck2 > os.time())
check("use coin elixir", call("UseItem", "coin_elixir").ok and data.Boosts.Coins2 > os.time())

-- слияние
for _ = 1, 3 do
	Economy.addPet(player, "bunbun", "Normal")
end
local fuseUids = {}
for uid, p in pairs(data.Pets) do
	-- Только Normal: среди вылупленных могут быть Golden/Rainbow — canFuse требует один вариант.
	if p.Id == "bunbun" and PetMeta.variantOf(p) == "Normal" and not p.Fav and #fuseUids < 3 then
		table.insert(fuseUids, uid)
	end
end
check("enough normal bunbun for fuse", #fuseUids == 3, #fuseUids)
local petsBefore = count(data.Pets)
res = call("Fuse", { fuseUids[1], fuseUids[2] })
check("fuse needs 3", res.ok == false)
res = call("Fuse", fuseUids)
check("fuse 3 -> 1", res.ok and count(data.Pets) == petsBefore - 2, res.msg)
check("fuse stat", (data.Stats.Fused or 0) == 1)
local mixed = {}
Economy.addPet(player, "bunbun", "Normal")
Economy.addPet(player, "chirpy", "Normal")
Economy.addPet(player, "chirpy", "Golden")
for uid, p in pairs(data.Pets) do
	if (p.Id == "chirpy" and #mixed < 2) or (p.Id == "bunbun" and #mixed < 3 and #mixed >= 2) then
		table.insert(mixed, uid)
	end
end
res = call("Fuse", mixed)
check("fuse rejects mixed pets", res.ok == false, res.msg)

-- эволюция
local evoUid = Economy.addPet(player, "sunfox", "Normal")
res = call("Evolve", evoUid)
check("evolve needs max level", res.ok == false, res.msg)
data.Pets[evoUid].Level = PetMeta.maxLevel(0)
data.Resources.Essence = 50
local powerBefore = PetMeta.power(data.Pets[evoUid])
res = call("Evolve", evoUid)
check(
	"evolve",
	res.ok and data.Pets[evoUid].Evo == 1 and PetMeta.power(data.Pets[evoUid]) > powerBefore,
	res.msg
)

-- ===== 6. Квесты, достижения ==============================================
local dlg = QuestService.dialogFor(data, "mira")
check("dialog offer", dlg.Mode == "offer" and #dlg.Lines >= 2)
res = call("QuestTalk", "mira")
check("talk to npc in hub", res.ok)
res = call("QuestClaim", "mira")
check("claim before accept rejected", res.ok == false)
call("QuestAccept", "mira")
dlg = QuestService.dialogFor(data, "mira")
check("dialog progress", dlg.Mode == "progress")
Progress.record(player, "gather", "Wood", 8, "Meadow")
dlg = QuestService.dialogFor(data, "mira")
check("quest complete -> done dialog", dlg.Mode == "done", dlg.Mode)
local coinsQ = data.Coins
res = call("QuestClaim", "mira")
check("quest claim", res.ok and data.Quests.Chains.mira.Step == 2 and data.Coins > coinsQ, res.msg)
check("quest stat", (data.Stats.Quests or 0) >= 1)
local dailyId
for id in pairs(data.Quests.Daily.Items) do
	dailyId = id
	break
end
check("3 daily quests", count(data.Quests.Daily.Items) == 3, count(data.Quests.Daily.Items))
local def = require(Shared.QuestData).DailyById[dailyId]
data.Quests.Daily.Items[dailyId].P = 0
res = call("DailyQuestClaim", dailyId)
check("daily not complete", res.ok == false)
Progress.record(player, def.Obj.Kind, def.Obj.Key, def.Obj.Count, nil)
res = call("DailyQuestClaim", dailyId)
check("daily claim", res.ok and data.Quests.Daily.Items[dailyId].C == true, res.msg)
res = call("DailyQuestClaim", dailyId)
check("daily double claim rejected", res.ok == false)
local gemsA = data.Gems
Progress.addStat(player, "Kills", 30)
check("achievement kills_1", data.Achievements.kills_1 == true and data.Gems > gemsA)

-- ===== 7. Батл-пасс =======================================================
Economy.addBpXp(player, 1000)
local lvl = BattlePassData.progress(data.BattlePass.Xp)
check("battle pass levels up", lvl >= 3, lvl)
res = call("BpClaim", "Free", 1)
check("bp claim free", res.ok and data.BattlePass.ClaimedFree["1"] == true, res.msg)
res = call("BpClaim", "Free", 1)
check("bp double claim rejected", res.ok == false)
res = call("BpClaim", "Premium", 2)
check("bp premium needs pass", res.ok == false, res.msg)
Session.get(player).Passes.BATTLE_PASS = true
res = call("BpClaim", "Premium", 2)
check("bp premium claim with pass", res.ok, res.msg)
res = call("BpClaim", "Free", 30)
check("bp locked level", res.ok == false)

-- ===== 8. Магазин =========================================================
local view = ShopLogic.view(data)
check("shop has 6 offers", #view.Offers == 6, #view.Offers)
local offer = view.Offers[1]
local cur = offer.Currency
local bal = data[cur]
res = call("ShopBuy", offer.Id)
check("shop buy", res.ok and data[cur] < bal, res.msg)
for _ = 1, offer.Stock do
	call("ShopBuy", offer.Id)
end
res = call("ShopBuy", offer.Id)
check("shop stock limit", res.ok == false, res.msg)
res = call("ShopBuy", "nonexistent")
check("shop unknown offer", res.ok == false)

-- ===== 9. Таланты и ребёрт ================================================
data.Rebirths = 2
res = call("TalentBuy", "eco_start")
check("talent requirement enforced", res.ok == false, res.msg)
res = call("TalentBuy", "eco_coins")
check("talent buy", res.ok and data.Talents.eco_coins == 1)
call("TalentBuy", "eco_coins")
res = call("TalentBuy", "eco_coins")
check("no points left", res.ok == false, res.msg)
local gemsT = data.Gems
res = call("TalentReset")
check("talent respec costs gems", res.ok and data.Gems == gemsT - 50 and next(data.Talents) == nil, res.msg)
data.Rebirths = 0
data.Coins = 1e9
local reb0 = Economy.getPerClick(player, data)
res = call("Rebirth")
check("rebirth", res.ok and data.Rebirths == 1, res.msg)
check("rebirth keeps pets", count(data.Pets) > 0)
check("rebirth achievement", data.Achievements.rebirth_1 == true)

-- ===== 10. Торговля с ботом ===============================================
local want = {}
for i = 1, 3 do
	table.insert(want, Economy.addPet(player, "mushling", "Golden"))
end
do
	local offerPets = TradeService.botOffer(os.time() // 600)
	local v = 0
	for _, p in pairs(offerPets) do
		v += PetMeta.tradeValue(p)
		print("INFO bot pet", p.Id, p.Variant, p.Level, PetMeta.tradeValue(p))
	end
	print("INFO tom value", v, "mine", PetMeta.tradeValue(data.Pets[want[1]]) * 3)
end
res = call("TradeStartBot")
check("trade start", res.ok, res.msg)
res = call("TradeReady", true)
check("tom unhappy with empty offer", res.ok == false, res.msg)
res = call("TradeOffer", want, 0)
check("trade offer", res.ok, res.msg)
task.wait(1.2)
res = call("TradeReady", true)
check("trade ready", res.ok, res.msg)
res = call("TradeConfirm")
check("confirm needs countdown", res.ok == false, res.msg)
task.wait(Config.TRADE_CONFIRM_SECONDS + 0.5)
local petsT = count(data.Pets)
res = call("TradeConfirm")
check("trade confirm", res.ok, res.msg)
task.wait(0.3)
check("trade swapped pets", count(data.Pets) == petsT - 3 + 2, count(data.Pets) .. " vs " .. petsT)
check("trade stat", (data.Stats.Trades or 0) == 1)
-- отмена и сброс при изменении
call("TradeStartBot")
call("TradeOffer", { next(data.Pets) }, 0)
task.wait(1.2)
call("TradeCancel")
res = call("TradeReady", true)
check("cancelled trade is closed", res.ok == false)
-- чистая логика (дублирует cases.lua, но на реальных модулях)
local s = TradeLogic.new(1, 2)
TradeLogic.setOffer(s, 1, { "a" }, 0, 6)
TradeLogic.setReady(s, 1, true, 0, 3)
TradeLogic.setReady(s, 2, true, 0, 3)
TradeLogic.setOffer(s, 2, { "b" }, 5, 6)
check("trade logic resets ready", s.Status == "Open" and not s.A.Ready and not s.B.Ready)

-- ===== 11. События ========================================================
EventService.force("LunarNight", true)
task.wait(2)
check("lunar: night falls", Lighting.ClockTime == 0)
local moon = 0
for _, m in ipairs(Workspace.Enemies:GetChildren()) do
	if m:GetAttribute("EnemyId") == "moonling" then
		moon += 1
	end
end
check("lunar: moonlings spawned", moon >= 5, moon)
moveTo(WorldBuilder.getEggPosition("LunarEgg"))
data.Gems = 500
res = call("Hatch", "LunarEgg", 1)
check("lunar egg sells during event", res.ok, res.msg)
EventService.force("LunarNight", false)
task.wait(2)
check("lunar: day returns", Lighting.ClockTime == 14)
res = call("Hatch", "LunarEgg", 1)
check("lunar egg locked after event", res.ok == false)

EventService.force("GoldenRain", true)
task.wait(3)
local coinPart = Workspace.Rain:FindFirstChild("GoldenCoin")
check("rain: coins fall", coinPart ~= nil)
check("rain: coin multiplier", Economy.getCoinBoost(data) >= 2)
local c0 = data.Coins
task.wait(2)
for _, c in ipairs(Workspace.Rain:GetChildren()) do
	moveTo(c.Position)
	task.wait(0.5)
	break
end
task.wait(1)
check(
	"rain: coin collected",
	(data.Stats.RainCoins or 0) >= 1 and data.Coins > c0,
	tostring(data.Stats.RainCoins)
)
EventService.force("GoldenRain", false)

call("Teleport", "Hub")
local gems0 = data.Gems
local coins0 = data.Coins
EventService.force("BossRaid", true)
task.wait(2)
local boss
for _, m in ipairs(Workspace.Enemies:GetChildren()) do
	if m:GetAttribute("IsRaid") then
		boss = m
	end
end
check("raid boss spawned", boss ~= nil)
check("raid boss hp scales", boss:GetAttribute("MaxHp") == 12000)
CombatService.debugDamage(player, boss:GetAttribute("Id"), 100000)
task.wait(1.5)
check(
	"raid reward",
	data.Gems >= gems0 + EventData.RAID_REWARD.Gems and data.Coins > coins0 and (data.Stats.Raids or 0) == 1
)
EventService.force("BossRaid", false)

-- ===== 12. Оффлайн и миграции ============================================
data.LastSeen = os.time() - 7200
local elapsed, earned = OfflineService.onJoin(player)
check("offline earnings", earned > 0 and data.OfflinePending == earned, earned)
local c1 = data.Coins
res = call("ClaimOffline")
check("claim offline", res.ok and data.Coins >= c1 + earned and data.OfflinePending == 0)
local old = {
	Version = 1,
	Coins = 5,
	Gems = 0,
	Rebirths = 0,
	TotalCoins = 5,
	Pets = { p1 = { Id = "bunbun", Gold = true }, p2 = { Id = "chirpy", Gold = false } },
}
Migrations.run(old)
check(
	"migration v1 -> v2",
	old.Version == 2
		and old.Pets.p1.Variant == "Golden"
		and old.Pets.p2.Variant == "Normal"
		and old.Pets.p1.Level == 1
		and old.Pets.p1.Gold == nil
)

-- ===== 13. Защита =========================================================
local gemsAA = data.Gems
res = call("Hatch", "MeadowEgg", 99)
check("exploit: bad hatch count", res.ok == false)
res = call("Sell", { 1, 2 })
check("exploit: bad sell arg", res.ok == false)
res = call("NoSuchAction")
check("exploit: unknown action", res.ok == false)
res = call("TradeOffer", { "p1" }, -5)
check("exploit: trade without session", res.ok == false)

-- ===== 14. Суперсила / Охота (боты-охотники как в демо) ====================
print(("INFO super section at t=%.1f"):format(os.clock()))
local SuperpowerService = require(Server.SuperpowerService)
local SuperBots = require(Server.SuperBots)
local SC = Config.SUPERPOWER
Workspace:SetAttribute("SuperpowerPaused", true)
call("Teleport", "Hub")
check("super: paused — no automatic round", not SuperpowerService.isActive())
SuperBots.spawn()
task.wait(1)
local bots = SuperBots.list()
check(
	"super: bots spawned as R6 rigs",
	#bots == SC.BOT_COUNT and bots[1].Model:FindFirstChild("Left Arm") ~= nil and bots[1].Humanoid ~= nil
)
local b1 = bots[1]
local bp0 = b1.Root.Position
task.wait(4)
check(
	"super: bots wander (Humanoid:MoveTo)",
	(b1.Root.Position - bp0).Magnitude > 2,
	(b1.Root.Position - bp0).Magnitude
)
-- вне охоты удар по боту ничего не делает
moveTo(b1.Root.Position + Vector3.new(3, 0, 0))
local airRes = call("Attack")
check("super: no PvP outside the hunt", airRes.ok and b1.Model:GetAttribute("SuperHp") == nil)

-- раунд 1: суперсила у бота, игрок охотится
Workspace:SetAttribute("SuperpowerForce", "bot")
task.wait(0.6)
local r = SuperpowerService.current()
check("super: forced bot round", r ~= nil and r.TargetIsBot, r and r.TargetKey)
task.wait(1)
local troot = SuperpowerService.targetRoot()
local tm = troot and troot.Parent
check("super: target grew (ScaleTo)", tm and math.abs(tm:GetScale() - SC.SCALE) < 0.01, tm and tm:GetScale())
check(
	"super: tag and HP attributes",
	tm and tm:FindFirstChild("SuperTag", true) ~= nil and tm:GetAttribute("SuperMaxHp") == r.MaxHp
)
check(
	"super: maxHp scales with hunters (bot = half)",
	r.MaxHp == math.floor(SC.HP_BASE + SC.HP_PER_HUNTER * (1 + 0.5 * (SC.BOT_COUNT - 1))),
	r.MaxHp
)
local gemsH, essH = data.Gems, data.Resources.Essence or 0
local hits, stunned = 0, 0
local actionFn = Remotes.getFunction("Action")
for i = 1, 200 do
	if not SuperpowerService.isActive() then
		break
	end
	local tp = SuperpowerService.targetRoot()
	if tp and (i % 2 == 1 or (tp.Position - player.Character.HumanoidRootPart.Position).Magnitude > 9) then
		AntiExploit.markTeleport(player)
		player.Character:PivotTo(CFrame.new(tp.Position + Vector3.new(4, 1, 0)))
	end
	if SuperpowerService.isStunned(player) then
		stunned += 1
	end
	local hp = r.Hp
	local before = r.Damage[SuperpowerService.keyOf(player)] or 0
	actionFn.OnServerInvoke(player, "Attack") -- как кнопка УДАР с максимальной частотой
	task.wait(0.33)
	if (r.Damage[SuperpowerService.keyOf(player)] or 0) > before and r.Hp < hp then
		hits += 1
	end
end
print(("INFO super hunt: hits=%d stunned=%d hp=%d/%d"):format(hits, stunned, r.Hp, r.MaxHp))
check("super: player hits lower HP", hits >= 2, hits)
check("super: bots dealt damage too", (r.Damage.bot2 or 0) + (r.Damage.bot3 or 0) > 0)
check("super: target stopped", not SuperpowerService.isActive() and r.Done and r.Hp <= 0, r.Hp)
check(
	"super: hunter rewarded by contribution",
	data.Gems > gemsH and (data.Resources.Essence or 0) > essH and (data.Stats.SuperStops or 0) >= 1
)
check(
	"super: bot back to normal",
	tm:GetScale() == 1 and tm:GetAttribute("Super") == nil and not tm:FindFirstChild("SuperTag", true)
)

-- раунд 2: суперсила у игрока, боты охотятся, игрок отбивается ударной волной
task.wait(1)
local ws0 = player.Character.Humanoid.WalkSpeed
local coins2 = data.Coins
Workspace:SetAttribute("SuperpowerForce", "me")
task.wait(1.2)
local r2 = SuperpowerService.current()
check("super: forced player round", r2 ~= nil and not r2.TargetIsBot and SuperpowerService.isSuper(player))
check(
	"super: player grew",
	math.abs(player.Character:GetScale() - SC.SCALE) < 0.01,
	player.Character:GetScale()
)
check(
	"super: faster + higher jump",
	player.Character.Humanoid.WalkSpeed > ws0 and player.Character.Humanoid.JumpPower > Config.JUMP_POWER
)
check("super: coin multiplier", Session.get(player).SuperCoin == SC.COIN_MULT)
task.wait(4) -- боты подбегают и бьют
check("super: bots hunt the player", r2.Hp < r2.MaxHp, r2.Hp)
-- удар игрока = ударная волна: отталкивает и оглушает ботов рядом
local near
for _, b in ipairs(bots) do
	if (b.Root.Position - player.Character.HumanoidRootPart.Position).Magnitude < SC.SLAM_RANGE then
		near = b
	end
end
if not near then
	moveTo(bots[2].Root.Position + Vector3.new(4, 0, 0))
	near = bots[2]
end
local before = near.Root.Position
local hpBefore = r2.Hp
call("Attack")
check("super: shockwave stuns a hunter", near.Unit.StunnedUntil > os.clock() - 0.4, near.Key)
check(
	"super: knockback",
	(near.Root.Position - before).Magnitude > 5,
	(near.Root.Position - before).Magnitude
)
check("super: slam does not heal or steal progress", r2.Hp <= hpBefore and (r2.Damage[near.Key] or 0) >= 0)
-- v2.4 (аудит К1): награда за «продержался» — только активному суперигроку: вторая ударная волна
task.wait(SC.SLAM_COOLDOWN + 0.1)
call("Attack")
check("super: active super (slams counted)", (r2.Slams or 0) >= SC.SURVIVE_MIN_SLAMS, r2.Slams)
-- держимся до конца (сокращаем таймер для теста) — крупная награда
local gemsS = data.Gems
r2.Ends = os.clock() + 0.3
task.wait(1)
check("super: survived", not SuperpowerService.isActive() and r2.Done)
check("super: survive reward", data.Gems >= gemsS + SC.SURVIVE_REWARD.Gems and data.Coins > coins2)
check("super: player normal again", player.Character:GetScale() == 1 and Session.get(player).SuperCoin == 1)
check("super: walk speed restored", math.abs(player.Character.Humanoid.WalkSpeed - ws0) < 0.01)

print(fails == 0 and "ALL GAME CHECKS PASSED" or ("GAME CHECKS FAILED: " .. fails))
print("DONE")
