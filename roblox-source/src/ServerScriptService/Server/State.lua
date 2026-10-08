--!strict
-- Рассылка состояния клиенту. Клиент только отображает то, что прислал сервер.
-- "Core" — часто меняющиеся поля (монеты и т.д.), "Pets" — инвентарь питомцев (меняется редко).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local BattlePassData = require(Shared.BattlePassData)
local Formulas = require(Shared.Formulas)
local PetMeta = require(Shared.PetMeta)
local Remotes = require(Shared.Remotes)
local TalentData = require(Shared.TalentData)

local DailyService = require(script.Parent.DailyService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Router = require(script.Parent.Router)
local Dailies = require(script.Parent.Dailies)
local Session = require(script.Parent.Session)
local ShopLogic = require(script.Parent.ShopLogic)

local State = {}

local dirtyCore: { [Player]: boolean } = {}
local dirtyPets: { [Player]: boolean } = {}
local lastAttr: { [Player]: string } = {}

function State.markCore(player: Player)
	dirtyCore[player] = true
end

function State.markPets(player: Player)
	dirtyPets[player] = true
	dirtyCore[player] = true
end

local function buildQuests(data: DataService.Data)
	Dailies.ensure(data)
	local chains = {}
	for npcId, st in pairs(data.Quests.Chains) do
		chains[npcId] = { Step = st.Step, Accepted = st.Accepted, Progress = st.Progress }
	end
	local daily = {}
	for id, entry in pairs(data.Quests.Daily.Items) do
		daily[id] = { P = entry.P, C = entry.C }
	end
	return { Chains = chains, Daily = daily }
end

local function buildBattlePass(data: DataService.Data)
	local bp = data.BattlePass
	if bp.Season ~= BattlePassData.Season then
		return {
			Season = BattlePassData.Season,
			Level = 0,
			Into = 0,
			Need = BattlePassData.xpForLevel(1),
			Free = {},
			Premium = {},
		}
	end
	local level, into, need = BattlePassData.progress(bp.Xp)
	return {
		Season = bp.Season,
		Level = level,
		Into = into,
		Need = need,
		Free = bp.ClaimedFree,
		Premium = bp.ClaimedPremium,
	}
end

-- v2.5: «Индекс» — отмечаем открытыми всех питомцев в инвентаре (любой источник: яйцо, обмен, крафт, награда)
local function syncIndex(data: DataService.Data): { [string]: boolean }
	local index = data.Index
	if type(index) ~= "table" then
		index = {}
		data.Index = index
	end
	for _, p in pairs(data.Pets) do
		if type(p) == "table" and type(p.Id) == "string" and not index[p.Id] then
			index[p.Id] = true
		end
	end
	return index
end
State.syncIndex = syncIndex

local function buildCore(player: Player, data: DataService.Data)
	local session = Session.get(player)
	local luckBoost, luckEnds = Economy.getLuckBoost(data)
	local passes = {}
	if session then
		for k, v in pairs(session.Passes) do
			passes[k] = v
		end
	end
	local vip = Economy.isVip(player)
	return {
		Coins = data.Coins,
		Gems = data.Gems,
		Rebirths = data.Rebirths,
		TotalCoins = data.TotalCoins,
		TotalHatched = data.TotalHatched,
		PerClick = Economy.getPerClick(player, data),
		BonusMult = Economy.getBonusMultiplier(player),
		PetPower = Economy.getPetPower(data),
		Slots = Economy.getPetSlots(player, data),
		BagSize = Economy.getBagSize(data),
		PetCount = Economy.countPets(data),
		Tutorial = { Step = data.Tutorial.Step, P = data.Tutorial.P }, -- v2.4 (Г3)
		PetMail = #data.PetMail, -- v2.4: питомцы-награды, ждущие места в инвентаре
		Equipped = data.Equipped,
		Upgrades = data.Upgrades,
		Zones = data.Zones,
		CurrentZone = data.CurrentZone,
		AutoCollect = data.AutoCollect,
		LangSetting = data.Settings and data.Settings.Lang or "auto",
		Hotbar = data.Settings and data.Settings.Hotbar, -- v2.9: быстрые слоты 3..5
		Audio = data.Settings and data.Settings.Audio, -- v3.1: музыка/звуки
		Passes = passes,
		Premium = session ~= nil and session.Premium,
		PaidRandomRestricted = session == nil or session.PaidRandomRestricted,
		IsVip = vip,
		Luck = Economy.getLuck(player, data),
		LuckBoost = luckBoost,
		LuckBoostEnds = luckEnds,
		Daily = DailyService.getInfo(data, player),
		RebirthCost = Formulas.rebirthCost(data.Rebirths),
		ServerTime = os.time(),
		-- v2
		Resources = data.Resources,
		Items = data.Items,
		Talents = data.Talents,
		TalentPoints = Formulas.talentPoints(data.Rebirths) - TalentData.spent(data.Talents),
		Stats = data.Stats,
		Achievements = data.Achievements,
		Quests = buildQuests(data),
		BattlePass = buildBattlePass(data),
		Shop = ShopLogic.view(data),
		Boosts = data.Boosts,
		FriendBonus = Economy.getFriendBonus(player),
		CoinMult = Economy.getCoinMultiplier(player, data),
		TeamPower = Economy.getPetPower(data),
		OfflinePending = data.OfflinePending or 0,
		Index = syncIndex(data), -- v2.5
	}
end

-- Строка для клиентской отрисовки питомцев у всех игроков: "id:Variant,id:Variant"
local function buildEquippedAttribute(data: DataService.Data): string
	local parts = {}
	for _, uid in ipairs(data.Equipped) do
		local p = data.Pets[uid]
		if p then
			table.insert(parts, p.Id .. ":" .. PetMeta.variantOf(p))
		end
	end
	return table.concat(parts, ",")
end

local function buildPets(data: DataService.Data)
	local out = {}
	for uid, p in pairs(data.Pets) do
		out[uid] = {
			Id = p.Id,
			Variant = PetMeta.variantOf(p),
			Level = p.Level or 1,
			Xp = p.Xp or 0,
			Evo = p.Evo or 0,
			Fav = p.Fav == true,
			Power = PetMeta.power(p),
			Max = PetMeta.maxLevel(p.Evo),
			Need = PetMeta.xpForNext(p.Level or 1),
		}
	end
	return out
end

function State.push(player: Player, includePets: boolean)
	local data = DataService.get(player)
	if not data or player.Parent == nil then
		return
	end
	local payload: { [string]: any } = { Core = buildCore(player, data) }
	if includePets then
		payload.Pets = buildPets(data)
	end
	Remotes.getEvent("State"):FireClient(player, payload)

	local attr = buildEquippedAttribute(data)
	if lastAttr[player] ~= attr then
		lastAttr[player] = attr
		player:SetAttribute("EquippedPets", attr)
	end
	player:SetAttribute("Rebirths", data.Rebirths)
end

function State.init()
	-- Клиент мог подключиться к событию State позже первой отправки — он просит полный снимок
	Router.register("Resync", 0.5, 2, function(player: Player)
		State.markPets(player)
		return true, nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		for _, player in ipairs(Players:GetPlayers()) do
			if dirtyCore[player] or dirtyPets[player] then
				local withPets = dirtyPets[player] == true
				dirtyCore[player] = nil
				dirtyPets[player] = nil
				State.push(player, withPets)
			end
		end
	end)

	-- Раз в секунду отправляем снимок всем (таймеры бустов/ежедневной награды, истечение бустов)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				if s and s.Ready then
					dirtyCore[player] = true
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		dirtyCore[player] = nil
		dirtyPets[player] = nil
		lastAttr[player] = nil
	end)
end

return State
