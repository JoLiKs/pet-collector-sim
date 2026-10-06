--!strict
--[[
	TradeService — обмен питомцами и монетами между двумя сторонами с подтверждением обеих.
	Логика состояний — в Shared/TradeLogic (чистая, покрыта тестами). Здесь — сеть, валидация и атомарное исполнение.
	Партнёр: другой игрок на сервере или бот «Trader Tom» (демо — один игрок может проверить механику).
	Защита: любое изменение предложения сбрасывает готовность обеих сторон; финальное подтверждение возможно только после
	отсчёта; перед обменом всё перепроверяется (питомцы существуют, не в команде, не избранные, монеты на месте, есть место в сумке).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Config = require(Shared.Config)
local PetData = require(Shared.PetData)
local PetMeta = require(Shared.PetMeta)
local Remotes = require(Shared.Remotes)
local TradeLogic = require(Shared.TradeLogic)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local Stations = require(script.Parent.Stations)

local TradeService = {}

local BOT = "bot"
local INVITE_SECONDS = 30
local BOT_FAIRNESS = 0.9 -- Том согласен, если получает не менее 90% ценности того, что отдаёт

type Trade = {
	Logic: TradeLogic.Session,
	A: Player,
	B: Player?, -- nil = бот
	BotPets: { [string]: PetMeta.PetState },
	BotGen: number,
	Msg: any,
}

local trades: { [Player]: Trade } = {}
local invites: { [Player]: { From: Player, Time: number } } = {} -- ключ — приглашённый

-- Предложение бота: детерминированно по 10-минутному слоту, не дороже Epic
function TradeService.botOffer(slot: number): { [string]: PetMeta.PetState }
	local rng = Random.new(slot * 31 + 7)
	-- Том торгует питомцами из первых двух миров (Uncommon-Rare): ценность остаётся в «человеческих» пределах
	local pool = {}
	for _, eggId in ipairs({ "MeadowEgg", "ForestEgg" }) do
		for _, ep in ipairs(PetData.EggsById[eggId].Pets) do
			local def = PetData.PetsById[ep.Id]
			local order = PetData.Rarities[def.Rarity].Order
			if order >= 2 and order <= 3 then
				table.insert(pool, def.Id)
			end
		end
	end
	local out: { [string]: PetMeta.PetState } = {}
	for i = 1, 2 do
		local id = pool[rng:NextInteger(1, #pool)]
		local variant = if rng:NextNumber() < 0.25 then "Golden" else "Normal"
		out["bot" .. i] = { Id = id, Variant = variant, Level = 1 + rng:NextInteger(0, 4), Xp = 0, Evo = 0 }
	end
	return out
end

local function petView(p: PetMeta.PetState): { [string]: any }
	return {
		Id = p.Id,
		Variant = PetMeta.variantOf(p),
		Level = p.Level or 1,
		Evo = p.Evo or 0,
		Value = PetMeta.tradeValue(p),
	}
end

local function sideView(t: Trade, side: TradeLogic.Side, owner: Player?): { [string]: any }
	local pets = {}
	for _, uid in ipairs(side.Pets) do
		local p: PetMeta.PetState?
		if owner then
			local d = DataService.get(owner)
			p = d and d.Pets[uid]
		else
			p = t.BotPets[uid]
		end
		if p then
			local v = petView(p)
			v.Uid = uid
			table.insert(pets, v)
		end
	end
	return { Pets = pets, Coins = side.Coins, Ready = side.Ready, Confirmed = side.Confirmed }
end

local function push(t: Trade)
	local now = os.time()
	local left = if t.Logic.ConfirmAt then math.max(0, t.Logic.ConfirmAt - now) else 0
	local function send(
		me: Player,
		mySide: TradeLogic.Side,
		other: TradeLogic.Side,
		otherOwner: Player?,
		name: string
	)
		Remotes.getEvent("TradeUpdate"):FireClient(me, {
			Type = "State",
			Partner = name,
			IsBot = t.B == nil,
			Status = t.Logic.Status,
			CountdownLeft = left,
			Msg = t.Msg,
			Mine = sideView(t, mySide, me),
			Theirs = sideView(t, other, otherOwner),
		})
	end
	send(t.A, t.Logic.A, t.Logic.B, t.B, if t.B then t.B.DisplayName else Config.DEMO_BOT_NAME)
	if t.B then
		send(t.B, t.Logic.B, t.Logic.A, t.A, t.A.DisplayName)
	end
end

local function participants(t: Trade): { Player }
	local list = { t.A }
	if t.B then
		table.insert(list, t.B)
	end
	return list
end

local function closeTrade(t: Trade, reason: any)
	TradeLogic.cancel(t.Logic)
	trades[t.A] = nil
	if t.B then
		trades[t.B] = nil
	end
	for _, p in ipairs(participants(t)) do
		if p.Parent then
			Remotes.getEvent("TradeUpdate"):FireClient(p, { Type = "Closed", Reason = reason })
		end
	end
end

local function sideOf(t: Trade, player: Player): (TradeLogic.Side, TradeLogic.Side)
	if t.A == player then
		return t.Logic.A, t.Logic.B
	end
	return t.Logic.B, t.Logic.A
end

-- Проверка состава предложения игрока (без побочных эффектов)
local function validateSide(owner: Player, side: TradeLogic.Side): (boolean, any)
	local d = DataService.get(owner)
	if not d then
		return false, "err.not_loaded"
	end
	if d.Coins < side.Coins then
		return false, Locale.m("trade.no_coins", { player = owner.DisplayName })
	end
	local equipped = {}
	for _, uid in ipairs(d.Equipped) do
		equipped[uid] = true
	end
	for _, uid in ipairs(side.Pets) do
		local p = d.Pets[uid]
		if not p then
			return false, "trade.pet_gone"
		end
		if p.Fav then
			return false, "trade.fav"
		end
		if equipped[uid] then
			return false, "trade.unequip"
		end
	end
	return true, nil
end

-- Атомарное исполнение (без yield между проверкой и изменением)
local function execute(t: Trade): (boolean, any)
	local ok, why = validateSide(t.A, t.Logic.A)
	if not ok then
		return false, why
	end
	local dA = DataService.get(t.A) :: DataService.Data
	if t.B then
		local ok2, why2 = validateSide(t.B, t.Logic.B)
		if not ok2 then
			return false, why2
		end
		local dB = DataService.get(t.B) :: DataService.Data
		local incomingA = #t.Logic.B.Pets - #t.Logic.A.Pets
		local incomingB = #t.Logic.A.Pets - #t.Logic.B.Pets
		if Economy.countPets(dA) + incomingA > Economy.getBagSize(dA) then
			return false, Locale.m("trade.no_room", { player = t.A.DisplayName })
		end
		if Economy.countPets(dB) + incomingB > Economy.getBagSize(dB) then
			return false, Locale.m("trade.no_room", { player = t.B.DisplayName })
		end
		local moveA, moveB = {}, {}
		for _, uid in ipairs(t.Logic.A.Pets) do
			table.insert(moveA, dA.Pets[uid])
			dA.Pets[uid] = nil
		end
		for _, uid in ipairs(t.Logic.B.Pets) do
			table.insert(moveB, dB.Pets[uid])
			dB.Pets[uid] = nil
		end
		for _, p in ipairs(moveA) do
			dB.Pets[Economy.newPetUid(dB)] = p
		end
		for _, p in ipairs(moveB) do
			dA.Pets[Economy.newPetUid(dA)] = p
		end
		dA.Coins = dA.Coins - t.Logic.A.Coins + t.Logic.B.Coins
		dB.Coins = dB.Coins - t.Logic.B.Coins + t.Logic.A.Coins
		for _, pl in ipairs({ t.A, t.B }) do
			Progress.record(pl, "trade", nil, 1, nil)
			State.markPets(pl)
		end
		return true, nil
	end
	-- бот
	local incoming = #t.Logic.B.Pets - #t.Logic.A.Pets
	if Economy.countPets(dA) + incoming > Economy.getBagSize(dA) then
		return false, "err.storage_full"
	end
	for _, uid in ipairs(t.Logic.A.Pets) do
		dA.Pets[uid] = nil
	end
	for _, uid in ipairs(t.Logic.B.Pets) do
		local p = t.BotPets[uid]
		dA.Pets[Economy.newPetUid(dA)] =
			{ Id = p.Id, Variant = p.Variant, Level = p.Level, Xp = 0, Evo = p.Evo }
	end
	dA.Coins = dA.Coins - t.Logic.A.Coins + t.Logic.B.Coins
	Progress.record(t.A, "trade", nil, 1, nil)
	State.markPets(t.A)
	return true, nil
end

local function petValueOf(owner: Player): (string) -> number
	return function(uid: string): number
		local d = DataService.get(owner)
		local p = d and d.Pets[uid]
		return if p then PetMeta.tradeValue(p) else 0
	end
end

-- Бот оценивает предложение игрока и (не)готов к обмену
local function botThink(t: Trade)
	t.BotGen += 1
	local gen = t.BotGen
	task.delay(0.8, function()
		if
			trades[t.A] ~= t
			or t.BotGen ~= gen
			or t.Logic.Status == "Done"
			or t.Logic.Status == "Cancelled"
		then
			return
		end
		local given = TradeLogic.offerValue(t.Logic.B, function(uid: string): number
			local p = t.BotPets[uid]
			return if p then PetMeta.tradeValue(p) else 0
		end)
		local received = TradeLogic.offerValue(t.Logic.A, petValueOf(t.A))
		if TradeLogic.botAccepts(given, received, BOT_FAIRNESS) then
			t.Msg = Locale.m("trade.tom_deal")
			if t.Logic.A.Ready then
				TradeLogic.setReady(t.Logic, BOT, true, os.time(), Config.TRADE_CONFIRM_SECONDS)
			else
				t.Logic.B.Ready = true
			end
		else
			t.Msg = Locale.m(
				"trade.tom_want",
				{ want = math.floor(given * BOT_FAIRNESS), offer = math.floor(received) }
			)
			t.Logic.B.Ready = false
		end
		push(t)
	end)
end

local function finishIfDone(t: Trade)
	if t.Logic.Status ~= "Done" then
		return
	end
	local ok, why = execute(t)
	if ok then
		closeTrade(t, Locale.m("trade.done"))
		for _, p in ipairs(participants(t)) do
			Notify.send(p, Locale.m("trade.done"), "reward")
		end
	else
		closeTrade(t, Locale.m("trade.failed", { why = why }))
	end
end

-- ---------------------------------------------------------------------------
-- Действия
-- ---------------------------------------------------------------------------

-- Политика Roblox: торговля платными предметами доступна не во всех регионах/возрастах.
local function tradeAllowed(player: Player): boolean
	local s = Session.get(player)
	return s ~= nil and s.TradeAllowed
end

local function startBot(player: Player): (boolean, any)
	if not tradeAllowed(player) then
		return false, "trade.policy_self"
	end
	if not Config.DEMO_BOT_ENABLED then
		return false, "trade.bot_disabled"
	end
	if trades[player] then
		return false, "trade.already"
	end
	if not Stations.inHub(player) then
		return false, "trade.tom_hub"
	end
	local t: Trade = {
		Logic = TradeLogic.new(player, BOT),
		A = player,
		B = nil,
		BotPets = TradeService.botOffer(os.time() // 600),
		BotGen = 0,
	}
	t.Logic.B.Pets = { "bot1", "bot2" }
	trades[player] = t
	t.Msg = Locale.m("trade.tom_hello")
	push(t)
	return true, nil
end

local function invite(player: Player, userId: any): (boolean, any)
	if type(userId) ~= "number" then
		return false, "err.bad_request"
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == player then
		return false, "trade.no_player"
	end
	if not tradeAllowed(player) or not tradeAllowed(target) then
		return false, "trade.policy_other"
	end
	if trades[player] or trades[target] then
		return false, "trade.busy"
	end
	local r1 = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local r2 = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r1 or not r2 or (r1.Position - r2.Position).Magnitude > Config.TRADE_RANGE then
		return false, "trade.closer"
	end
	invites[target] = { From = player, Time = os.time() }
	Remotes.getEvent("TradeUpdate")
		:FireClient(target, { Type = "Invite", From = player.DisplayName, FromId = player.UserId })
	Notify.send(player, Locale.m("trade.sent", { player = target.DisplayName }), "info")
	return true, nil
end

local function respond(player: Player, accept: any): (boolean, any)
	local inv = invites[player]
	invites[player] = nil
	if not inv or os.time() - inv.Time > INVITE_SECONDS then
		return false, "trade.expired"
	end
	if accept ~= true then
		Notify.send(inv.From, Locale.m("trade.declined", { player = player.DisplayName }), "info")
		return true, nil
	end
	if trades[player] or trades[inv.From] or inv.From.Parent == nil then
		return false, "trade.unavailable"
	end
	local t: Trade =
		{ Logic = TradeLogic.new(inv.From, player), A = inv.From, B = player, BotPets = {}, BotGen = 0 }
	trades[inv.From] = t
	trades[player] = t
	push(t)
	return true, nil
end

local function offer(player: Player, pets: any, coins: any): (boolean, any)
	local t = trades[player]
	if not t then
		return false, "trade.none"
	end
	if type(pets) ~= "table" or type(coins) ~= "number" then
		return false, "err.bad_request"
	end
	local list = {}
	for _, uid in ipairs(pets) do
		table.insert(list, uid)
	end
	local d = DataService.get(player)
	if not d then
		return false, "err.not_loaded"
	end
	if coins > d.Coins then
		return false, "trade.not_that_many"
	end
	local ok, why = TradeLogic.setOffer(
		t.Logic,
		if t.A == player then t.Logic.A.Id else t.Logic.B.Id,
		list,
		coins,
		Config.TRADE_MAX_PETS
	)
	if not ok then
		return false, why
	end
	for _, uid in ipairs(list) do
		if not d.Pets[uid] then
			TradeLogic.setOffer(
				t.Logic,
				if t.A == player then t.Logic.A.Id else t.Logic.B.Id,
				{},
				0,
				Config.TRADE_MAX_PETS
			)
			return false, "err.pet_not_found"
		end
	end
	t.Msg = nil
	push(t)
	if not t.B then
		botThink(t)
	end
	return true, nil
end

local function ready(player: Player, value: any): (boolean, any)
	local t = trades[player]
	if not t or type(value) ~= "boolean" then
		return false, "trade.none"
	end
	local id = if t.A == player then t.Logic.A.Id else t.Logic.B.Id
	if value then
		local mine = sideOf(t, player)
		local good, why = validateSide(player, mine)
		if not good then
			return false, why
		end
		if not t.B and not t.Logic.B.Ready then
			return false, "trade.tom_unhappy"
		end
	end
	local ok, why = TradeLogic.setReady(t.Logic, id, value, os.time(), Config.TRADE_CONFIRM_SECONDS)
	if not ok then
		return false, why
	end
	push(t)
	if t.Logic.Status == "Confirming" then
		-- По окончании отсчёта обновляем окно, бот подтверждает сам
		task.delay(Config.TRADE_CONFIRM_SECONDS + 0.2, function()
			if trades[t.A] == t and t.Logic.Status == "Confirming" then
				if not t.B then
					TradeLogic.confirm(t.Logic, BOT, os.time())
				end
				push(t)
			end
		end)
	end
	return true, nil
end

local function confirm(player: Player): (boolean, any)
	local t = trades[player]
	if not t then
		return false, "trade.none"
	end
	local id = if t.A == player then t.Logic.A.Id else t.Logic.B.Id
	local ok, why, done = TradeLogic.confirm(t.Logic, id, os.time())
	if not ok then
		return false, why
	end
	if not t.B then
		TradeLogic.confirm(t.Logic, BOT, os.time() + 999)
		done = t.Logic.Status == "Done"
	end
	if done then
		finishIfDone(t)
	else
		push(t)
	end
	return true, nil
end

local function cancel(player: Player): (boolean, any)
	local t = trades[player]
	if not t then
		return true, nil
	end
	closeTrade(t, Locale.m("trade.cancelled", { player = player.DisplayName }))
	return true, nil
end

function TradeService.init()
	Router.register("TradeStartBot", 1, 2, startBot)
	Router.register("TradeInvite", 1, 2, invite)
	Router.register("TradeRespond", 2, 2, respond)
	Router.register("TradeOffer", 6, 6, offer)
	Router.register("TradeReady", 4, 4, ready)
	Router.register("TradeConfirm", 3, 3, confirm)
	Router.register("TradeCancel", 3, 3, cancel)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
		local t = trades[player]
		if t then
			closeTrade(t, Locale.m("trade.left", { player = player.DisplayName }))
		end
	end)
end

return TradeService
