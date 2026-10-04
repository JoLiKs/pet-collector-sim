--!strict
-- Рассылка состояния клиенту. Клиент только отображает то, что прислал сервер.
-- "Core" — часто меняющиеся поля (монеты и т.д.), "Pets" — инвентарь питомцев (меняется редко).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DailyService = require(script.Parent.DailyService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)

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
		Equipped = data.Equipped,
		Upgrades = data.Upgrades,
		Zones = data.Zones,
		CurrentZone = data.CurrentZone,
		AutoCollect = data.AutoCollect,
		Passes = passes,
		Premium = session ~= nil and session.Premium,
		PaidRandomRestricted = session == nil or session.PaidRandomRestricted,
		IsVip = vip,
		Luck = Economy.getLuck(player, data),
		LuckBoost = luckBoost,
		LuckBoostEnds = luckEnds,
		Daily = DailyService.getInfo(data),
		RebirthCost = Formulas.rebirthCost(data.Rebirths),
		ServerTime = os.time(),
	}
end

-- Строка для клиентской отрисовки питомцев у всех игроков: "id:gold,id:gold"
local function buildEquippedAttribute(data: DataService.Data): string
	local parts = {}
	for _, uid in ipairs(data.Equipped) do
		local p = data.Pets[uid]
		if p then
			table.insert(parts, p.Id .. ":" .. (if p.Gold then "1" else "0"))
		end
	end
	return table.concat(parts, ",")
end

local function buildPets(data: DataService.Data)
	local out = {}
	for uid, p in pairs(data.Pets) do
		out[uid] = { Id = p.Id, Gold = p.Gold == true }
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
