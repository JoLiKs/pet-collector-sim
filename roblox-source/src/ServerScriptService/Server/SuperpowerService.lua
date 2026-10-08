--!strict
--[[
	SuperpowerService — событие «Суперсила / Охота».
	Раз в INTERVAL секунд сервер выбирает случайного подходящего участника (живой, данные загружены, не в обмене,
	по возможности не тот же, что в прошлый раз). Он получает суперсилу на DURATION секунд (но не дольше, чем до
	следующего выбора): крупнее (Model:ScaleTo), быстрее, выше прыжок, x урон и x монеты, удар по площади с ударной
	волной и «PvP-HP» охоты. Остальные получают задание «Останови его!» и могут бить его своей атакой (Attack /
	CombatService) и питомцами. Исходы: HP цели = 0 → «остановлен» (награда охотникам по вкладу + бонус за последний
	удар), таймер истёк → «продержался» (крупная награда ему, утешительная охотникам). Всё считается только здесь.

	Участники (Unit) — игроки и, при Config.DEMO_BOTS, серверные боты (SuperBots регистрирует их через addUnit).
	Тестовые переключатели (только сервер, атрибуты Workspace): SuperpowerTimeScale (ускорение цикла),
	SuperpowerPaused (не начинать новые раунды), SuperpowerForce = "me" | "bot" | ключ (начать раунд сейчас).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local Remotes = require(Shared.Remotes)
local Logic = require(Shared.SuperpowerLogic)

local Badges = require(script.Parent.Badges)
local AntiExploit = require(script.Parent.AntiExploit)
local Knockback = require(script.Parent.Knockback)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local TradeService = require(script.Parent.TradeService)

local C = Config.SUPERPOWER

local SuperpowerService = {}

export type Unit = {
	Key: string,
	Name: string,
	IsBot: boolean,
	Player: Player?,
	GetModel: () -> Model?,
	Eligible: () -> boolean,
	Knock: ((dir: Vector3, dist: number, stun: number) -> ())?,
	StunnedUntil: number,
	ImmuneUntil: number,
	LastHit: number,
	LastSlam: number,
}

export type Round = {
	Id: number,
	Active: boolean,
	Done: boolean,
	TargetKey: string,
	TargetName: string,
	TargetIsBot: boolean,
	Hp: number,
	MaxHp: number,
	Started: number,
	Ends: number,
	Duration: number,
	Damage: { [string]: number },
	LastHitKey: string?,
	Hits: { [string]: number }, -- ручные удары охотников (игроки — Attack, боты — botHit); питомцы не считаются
	Slams: number, -- ударные волны суперигрока
	Moved: number, -- студов пройдено суперигроком (по горизонтали)
	LastPos: Vector3?,
	Tag: BillboardGui?,
	Fill: Frame?,
}

export type Outcome = { Kind: string, Target: string, Round: number, At: number }

local units: { [string]: Unit } = {}
local round: Round? = nil
local roundId = 0
local lastKey: string? = nil
local nextPickAt = 0
local lastOutcome: Outcome? = nil
local lastBroadcast = 0
local rng = Random.new()
local FX_RADIUS = 200

-- ---------------------------------------------------------------------------
-- Вспомогательное
-- ---------------------------------------------------------------------------

function SuperpowerService.keyOf(player: Player): string
	return "p" .. tostring(player.UserId)
end

local function timeScale(): number
	local v = Workspace:GetAttribute("SuperpowerTimeScale")
	return if type(v) == "number" then v else 1
end

local function rootOf(u: Unit?): BasePart?
	local m = u and u.GetModel()
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function combatFx(pos: Vector3?, ...: any)
	local ev = Remotes.getEvent("CombatFx")
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local r = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if pos == nil or (r and (r.Position - pos).Magnitude <= FX_RADIUS) then
			ev:FireClient(p, ...)
		end
	end
end

local function refreshMovement(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if data and hum then
		hum.WalkSpeed = Economy.getWalkSpeed(player, data)
		hum.JumpPower = Economy.getJumpPower(player)
	end
end

-- ---------------------------------------------------------------------------
-- Участники
-- ---------------------------------------------------------------------------

function SuperpowerService.addUnit(u: Unit)
	units[u.Key] = u
end

function SuperpowerService.removeUnit(key: string)
	local r = round
	if r and r.TargetKey == key and not r.Done then
		-- суперигрок вышел: охотники с вкладом получают награду как за остановку (аудит В5)
		SuperpowerService.finish("fled")
	end
	units[key] = nil
end

function SuperpowerService.getUnit(key: string): Unit?
	return units[key]
end

local function playerUnit(player: Player): Unit
	local u: Unit = {
		Key = SuperpowerService.keyOf(player),
		Name = player.DisplayName,
		IsBot = false,
		Player = player,
		GetModel = function()
			return player.Character
		end,
		Eligible = function()
			local s = Session.get(player)
			local character = player.Character
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			return player.Parent ~= nil
				and s ~= nil
				and s.Ready
				and DataService.get(player) ~= nil
				and hum ~= nil
				and hum.Health > 0
				and (character :: Model):FindFirstChild("HumanoidRootPart") ~= nil
				and not TradeService.isTrading(player)
		end,
		StunnedUntil = 0,
		ImmuneUntil = 0,
		LastHit = -1e9,
		LastSlam = -1e9,
	}
	u.Knock = function(dir: Vector3, dist: number, stun: number)
		local s = Session.get(player)
		local root = rootOf(u)
		if not s or not root then
			return
		end
		AntiExploit.markTeleport(player)
		-- v2.4 (аудит С3): не сквозь стены и не в пропасть
		local ignore: { Instance } = {}
		if player.Character then
			table.insert(ignore, player.Character)
		end
		local shift = Knockback.offset(root.Position, dir, dist, ignore)
		pcall(function()
			root.CFrame = root.CFrame + shift + Vector3.new(0, 1.5, 0)
		end)
		s.StunnedUntil = os.clock() + stun
		refreshMovement(player)
		task.delay(stun + 0.05, function()
			if player.Parent then
				refreshMovement(player)
			end
		end)
	end
	return u
end

local function participants(): { Unit }
	local list = {}
	for _, u in pairs(units) do
		if u.Eligible() then
			table.insert(list, u)
		end
	end
	table.sort(list, function(a, b)
		return a.Key < b.Key
	end)
	return list
end

-- ---------------------------------------------------------------------------
-- Суперсила: включение/выключение
-- ---------------------------------------------------------------------------

local function makeTag(model: Model): (BillboardGui?, Frame?)
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head then
		return nil, nil
	end
	local g = Instance.new("BillboardGui")
	g.Name = "SuperTag"
	g.Size = UDim2.fromOffset(170, 40)
	g.StudsOffset = Vector3.new(0, 4.8, 0) -- над именем игрока (имя на 2.6)
	g.MaxDistance = 160
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.6)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 70)
	title.TextStrokeTransparency = 0.2
	title.ZIndex = 1
	Locale.setWorld(title, "super.tag")
	title.Parent = g
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromScale(0.08, 0.66)
	back.Size = UDim2.fromScale(0.84, 0.26)
	back.ZIndex = 1
	back.Parent = g
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 2
	fill.Parent = back
	g.Parent = head
	return g, fill
end

local GROW_STEPS = 6

-- ScaleTo масштабирует вокруг центра: поднимаем, чтобы ноги остались на земле (R6: 3 стада до ступней)
local function scaleModel(model: Model, scale: number)
	pcall(function()
		local before = model:GetScale()
		if math.abs(before - scale) < 1e-3 then
			return
		end
		model:ScaleTo(scale)
		local lift = 3 * (model:GetScale() - before)
		if lift > 0 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, lift + 0.1, 0))
		end
	end)
end

local function updateBar(r: Round)
	local u = units[r.TargetKey]
	local model = u and u.GetModel()
	if model then
		model:SetAttribute("SuperHp", math.ceil(r.Hp))
		model:SetAttribute("SuperMaxHp", r.MaxHp)
	end
	if r.Fill then
		r.Fill.Size = UDim2.fromScale(math.clamp(r.Hp / r.MaxHp, 0, 1), 1)
	end
end

local function setPower(u: Unit, on: boolean, r: Round?)
	local model = u.GetModel()
	if model then
		model:SetAttribute("Super", if on then true else nil)
		if on then
			-- рост за ~0.5 с (видно всем: сервер масштабирует модель ступенями)
			task.spawn(function()
				for i = 1, GROW_STEPS do
					if model:GetAttribute("Super") ~= true then
						return
					end
					scaleModel(model, 1 + (C.SCALE - 1) * i / GROW_STEPS)
					task.wait(0.08)
				end
			end)
		else
			scaleModel(model, 1)
		end
		if not on then
			model:SetAttribute("SuperHp", nil)
			model:SetAttribute("SuperMaxHp", nil)
		end
		local old = model:FindFirstChild("SuperTag", true)
		if old then
			old:Destroy()
		end
		if on and r then
			r.Tag, r.Fill = makeTag(model)
		end
	end
	local player = u.Player
	if player then
		local s = Session.get(player)
		if s then
			s.IsSuper = on
			s.SuperSpeed = if on then C.SPEED_MULT else 1
			s.SuperJump = if on then C.JUMP_MULT else 1
			s.SuperCoin = if on then C.COIN_MULT else 1
		end
		refreshMovement(player)
		State.markCore(player)
	end
end

-- ---------------------------------------------------------------------------
-- Раунд
-- ---------------------------------------------------------------------------

local function broadcast(now: number)
	lastBroadcast = now
	local ev = Remotes.getEvent("Superpower")
	local r = round
	local target = r and units[r.TargetKey]
	local model = target and target.GetModel()
	local enough = Logic.enoughPlayers(C, #participants())
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Session.get(player)
		if s and s.Ready then
			local key = SuperpowerService.keyOf(player)
			local me = units[key]
			local v: { [string]: any } = {
				Round = roundId,
				Active = r ~= nil and not r.Done,
				NextIn = if r then nil else math.max(0, math.ceil(nextPickAt - now)),
				Waiting = not enough,
				Stunned = me ~= nil and me.StunnedUntil > now,
			}
			local o = lastOutcome
			if o and now - o.At < 8 then
				v.Outcome = { Kind = o.Kind, Target = o.Target, Round = o.Round }
			end
			if r and not r.Done then
				v.Target = r.TargetName
				v.TargetIsBot = r.TargetIsBot
				v.IsYou = r.TargetKey == key
				v.Model = model
				v.Hp = math.ceil(r.Hp)
				v.MaxHp = r.MaxHp
				v.Left = math.max(0, r.Ends - now)
				v.Duration = r.Duration
				v.YourDamage = math.floor(r.Damage[key] or 0)
				v.MinDamage = Logic.minDamage(C, r.MaxHp)
				v.YourHits = r.Hits[key] or 0
				v.MinHits = C.HUNTER_MIN_HITS
			end
			ev:FireClient(player, v)
		end
	end
end

-- Начать раунд (forcedKey — для тестов/админов). Возвращает ключ суперигрока или nil.
function SuperpowerService.start(forcedKey: string?): string?
	if round then
		return nil
	end
	local now = os.clock()
	local list = participants()
	local interval, duration = Logic.timing(C, timeScale())
	if not Logic.enoughPlayers(C, #list) then
		nextPickAt = now + math.min(5, interval)
		return nil
	end
	local key: string?
	if forcedKey and units[forcedKey] and units[forcedKey].Eligible() then
		key = forcedKey
	else
		local cands = {}
		for _, u in ipairs(list) do
			table.insert(cands, { Key = u.Key, Eligible = true, IsBot = u.IsBot })
		end
		local function rint(n: number): number
			return rng:NextInteger(1, n)
		end
		key = if Config.DEMO_BOTS
			then Logic.pickWithBots(cands, lastKey, function()
				return rng:NextNumber()
			end, rint, C.BOT_PLAYER_SUPER_CHANCE)
			else Logic.pick(cands, lastKey, rint)
	end
	if not key then
		nextPickAt = now + math.min(5, interval)
		return nil
	end
	local u = units[key]
	roundId += 1
	-- PvP-HP по числу охотников; бот считается за половину игрока (он слабее живого охотника)
	local hunters = 0
	for _, x in ipairs(list) do
		if x.Key ~= key then
			hunters += if x.IsBot then 0.5 else 1
		end
	end
	local maxHp = Logic.maxHp(C, hunters)
	local r: Round = {
		Id = roundId,
		Active = true,
		Done = false,
		TargetKey = key,
		TargetName = u.Name,
		TargetIsBot = u.IsBot,
		Hp = maxHp,
		MaxHp = maxHp,
		Started = now,
		Ends = now + duration,
		Duration = duration,
		Damage = {},
		LastHitKey = nil,
		Hits = {},
		Slams = 0,
		Moved = 0,
		LastPos = nil,
	}
	local startRoot = rootOf(u)
	r.LastPos = if startRoot then startRoot.Position else nil
	round = r
	lastKey = key
	nextPickAt = now + interval
	for _, x in pairs(units) do
		x.LastHit = -1e9
	end
	setPower(u, true, r)
	updateBar(r)
	if not u.IsBot and u.Player then
		Badges.award(u.Player, "SUPERPOWER")
	end
	local model = u.GetModel()
	local root = rootOf(u)
	combatFx(nil, "SuperStart", model, root and root.Position)
	broadcast(now)
	return key
end

local function grant(player: Player, rw: Logic.Reward, msgKey: string, args: { [string]: any })
	local data = DataService.get(player)
	if not data or player.Parent == nil then
		return
	end
	-- дневной потолок гемов из события (UTC-сутки)
	local today = os.time() // 86400
	local eg = data.EventGems
	if type(eg) ~= "table" or eg.Day ~= today then
		eg = { Day = today, Gems = 0 }
		data.EventGems = eg
	end
	local gems = Logic.capGems(C, eg.Gems, rw.Gems)
	eg.Gems += gems
	local reward: { [string]: any } = {
		Coins = Economy.getPerClick(player, data) * rw.Clicks,
		Gems = if gems > 0 then gems else nil,
		Res = if rw.Essence > 0 then { Essence = rw.Essence } else nil,
		BpXp = rw.BpXp,
	}
	if rw.RareChance > 0 and rng:NextNumber() < rw.RareChance then
		reward.Item = C.STOP_REWARD.RareItem
	end
	Economy.grant(player, reward)
	local a = table.clone(args)
	a.reward = Economy.describe(reward, Locale.langOf(player))
	Notify.send(player, Locale.m(msgKey, a), "reward")
end

-- Завершить раунд: "stopped" | "survived" | "fled" | "cancel". Награды — ровно один раз (r.Done ставится до выдачи).
-- "fled" — суперигрок вышел из игры: охотникам награда как за остановку (без бонуса последнего удара).
function SuperpowerService.finish(outcome: string)
	local r = round
	if not r or r.Done then
		return
	end
	r.Done = true
	r.Active = false
	round = nil
	local now = os.clock()
	local target = units[r.TargetKey]
	local root = rootOf(target)
	local pos = if root then root.Position else nil
	if target then
		setPower(target, false, nil)
	end
	local humans: { [string]: boolean } = {}
	local byKey: { [string]: Player } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local s = Session.get(p)
		if s and s.Ready and DataService.get(p) then
			local k = SuperpowerService.keyOf(p)
			humans[k] = true
			byKey[k] = p
		end
	end
	local who = { player = r.TargetName }
	-- анти-AFK: охотнику нужны ручные удары; «продержался» — только если суперигрок двигался или бил
	local active: { [string]: boolean } = {}
	local contested = false
	for k, n in pairs(r.Hits) do
		local u = units[k]
		if humans[k] and n >= C.HUNTER_MIN_HITS then
			active[k] = true
			contested = true
		elseif u and u.IsBot and n > 0 then
			contested = true -- боты есть только в демо (Config.DEMO_BOTS)
		end
	end
	local superActive = r.Moved >= C.SURVIVE_MIN_MOVE or r.Slams >= C.SURVIVE_MIN_SLAMS
	if outcome == "stopped" or outcome == "fled" then
		local hunters = table.clone(humans)
		hunters[r.TargetKey] = nil
		local frac = math.clamp((r.Ends - now) / math.max(1, r.Duration), 0, 1)
		local lastHit = if outcome == "stopped" then r.LastHitKey else nil
		local rewards, afk = Logic.stopRewards(C, r.Damage, r.MaxHp, lastHit, frac, hunters, active)
		for k, rw in pairs(rewards) do
			local p = byKey[k]
			grant(p, rw, if rw.LastHit then "super.reward_last" else "super.reward_stop", who)
			Progress.record(p, "superstop", nil, 1, nil)
		end
		for k in pairs(afk) do
			Notify.send(byKey[k], Locale.m("super.too_little", who), "info")
		end
		local sp = byKey[r.TargetKey]
		if sp and outcome == "stopped" then
			Notify.send(sp, "super.you_stopped", "info")
		end
	elseif outcome == "survived" then
		local rewards, afk =
			Logic.surviveRewards(C, r.TargetKey, r.Damage, r.MaxHp, humans, active, superActive, contested)
		local sp = byKey[r.TargetKey]
		if sp and not superActive then
			Notify.send(sp, "super.idle", "info")
		end
		for k, rw in pairs(rewards) do
			local p = byKey[k]
			if k == r.TargetKey then
				grant(p, rw, "super.reward_survive", who)
				Progress.record(p, "supersurvive", nil, 1, nil)
			else
				grant(p, rw, "super.reward_consolation", who)
			end
		end
		for k in pairs(afk) do
			Notify.send(byKey[k], Locale.m("super.escaped", who), "info")
		end
	else
		for _, p in pairs(byKey) do
			Notify.send(p, Locale.m("super.cancelled", who), "info")
		end
	end
	lastOutcome = { Kind = outcome, Target = r.TargetName, Round = r.Id, At = now }
	combatFx(nil, "SuperEnd", pos, outcome)
	broadcast(now)
end

-- ---------------------------------------------------------------------------
-- Бой (вызывается из CombatService и SuperBots)
-- ---------------------------------------------------------------------------

local function applyDamage(r: Round, attacker: Unit, amount: number, kind: string)
	if r.Done or amount <= 0 then
		return
	end
	local dealt = math.min(amount, r.Hp)
	r.Hp -= dealt
	r.Damage[attacker.Key] = (r.Damage[attacker.Key] or 0) + dealt
	r.LastHitKey = attacker.Key
	updateBar(r)
	local target = units[r.TargetKey]
	local tRoot = rootOf(target)
	local aRoot = rootOf(attacker)
	if tRoot then
		local dir = if aRoot then flat(tRoot.Position - aRoot.Position) else Vector3.new(0, 0, -1)
		local hitPos = tRoot.Position + Vector3.new(0, 1.5, 0) - dir * 2
		if kind ~= "pet" then
			combatFx(hitPos, "Impact", hitPos, dir)
		end
		if attacker.Player then
			Remotes.getEvent("Fx"):FireClient(
				attacker.Player,
				"Hit",
				hitPos + Vector3.new(0, 3, 0),
				tostring(math.floor(dealt)),
				"super"
			)
		end
	end
	if r.Hp <= 0 then
		SuperpowerService.finish("stopped")
	end
end

function SuperpowerService.isActive(): boolean
	return round ~= nil
end

function SuperpowerService.current(): Round?
	return round
end

function SuperpowerService.isSuperKey(key: string): boolean
	local r = round
	return r ~= nil and not r.Done and r.TargetKey == key
end

function SuperpowerService.isSuper(player: Player): boolean
	return SuperpowerService.isSuperKey(SuperpowerService.keyOf(player))
end

function SuperpowerService.isStunned(player: Player): boolean
	local u = units[SuperpowerService.keyOf(player)]
	return u ~= nil and u.StunnedUntil > os.clock()
end

-- Множитель урона по врагам (суперигрок бьёт сильнее)
function SuperpowerService.damageMult(player: Player): number
	return if SuperpowerService.isSuper(player) then C.DAMAGE_MULT else 1
end

function SuperpowerService.targetRoot(): BasePart?
	local r = round
	return if r then rootOf(units[r.TargetKey]) else nil
end

-- Общая проверка удара охотника. Возвращает (true, урон-цель) или (false, причина)
local function hunterCheck(attacker: Unit?, cooldown: number): (boolean, string?)
	local r = round
	if not attacker then
		return false, "unit"
	end
	if attacker.StunnedUntil > os.clock() then
		return false, "stunned"
	end
	local tRoot = rootOf(r and units[r.TargetKey])
	local aRoot = rootOf(attacker)
	if not tRoot or not aRoot then
		return false, "inactive"
	end
	local dist = (tRoot.Position - aRoot.Position).Magnitude
	local reach = (C.SCALE - 1) * 2.5
	local now = os.clock()
	local ok, why = Logic.canHit(
		{ HIT_RANGE = C.HIT_RANGE, HIT_COOLDOWN = cooldown },
		r :: any,
		attacker.Key,
		now,
		dist,
		reach,
		attacker.LastHit
	)
	if ok then
		attacker.LastHit = now
	end
	return ok, why
end

-- Удар игрока-охотника (Action "Attack"). true — удар ушёл в суперигрока (по врагам не бьём)
function SuperpowerService.tryPlayerHit(player: Player): boolean
	local r = round
	local u = units[SuperpowerService.keyOf(player)]
	if not r or r.Done or not u or u.Key == r.TargetKey then
		return false
	end
	local ok, why = hunterCheck(u, C.HIT_COOLDOWN)
	if not ok then
		return why == "cooldown" or why == "stunned"
	end
	local data = DataService.get(player)
	local power = if data then Economy.getPetPower(data) else 0
	r.Hits[u.Key] = (r.Hits[u.Key] or 0) + 1
	applyDamage(r, u, Logic.hunterHit(C, power, r.MaxHp), "player")
	return true
end

-- Питомцы охотника атакуют суперигрока, если он в радиусе боя. true — тик потрачен на цель
function SuperpowerService.petTick(player: Player, data: any, from: Vector3): boolean
	local r = round
	local u = units[SuperpowerService.keyOf(player)]
	if not r or r.Done or not u or u.Key == r.TargetKey or #data.Equipped == 0 then
		return false
	end
	local tRoot = rootOf(units[r.TargetKey])
	if not tRoot or (tRoot.Position - from).Magnitude > Config.COMBAT_RANGE then
		return false
	end
	applyDamage(r, u, Logic.petHit(C, #data.Equipped, Economy.getPetPower(data), r.MaxHp), "pet")
	return true
end

-- Удар бота-охотника
function SuperpowerService.botHit(key: string): boolean
	local r = round
	local u = units[key]
	if not r or r.Done or not u or not u.IsBot or key == r.TargetKey then
		return false
	end
	local ok = hunterCheck(u, C.BOT_ATTACK_INTERVAL)
	if not ok then
		return false
	end
	r.Hits[u.Key] = (r.Hits[u.Key] or 0) + 1
	applyDamage(r, u, math.min(C.BOT_DAMAGE, math.floor(C.MAX_HIT_SHARE * r.MaxHp)), "bot")
	return true
end

-- Удар суперигрока: ударная волна (по кулдауну) отталкивает и оглушает охотников. Урона охотникам нет.
function SuperpowerService.superSlam(key: string): boolean
	local r = round
	local u = units[key]
	local now = os.clock()
	if not r or r.Done or r.TargetKey ~= key or not u or now - u.LastSlam < C.SLAM_COOLDOWN then
		return false
	end
	u.LastSlam = now
	local root = rootOf(u)
	if not root then
		return false
	end
	r.Slams += 1
	local range = C.SLAM_RANGE * C.SCALE / 1.6
	combatFx(root.Position, "Shockwave", root.Position, range)
	for k, other in pairs(units) do
		local oRoot = rootOf(other)
		if k ~= key and oRoot and other.Eligible() then
			local d = oRoot.Position - root.Position
			if Vector3.new(d.X, 0, d.Z).Magnitude <= range and now >= other.ImmuneUntil then
				other.StunnedUntil = now + C.STUN_SECONDS
				other.ImmuneUntil = now + C.STUN_SECONDS + C.STUN_IMMUNE
				if other.Knock then
					other.Knock(flat(d), C.SLAM_KNOCKBACK, C.STUN_SECONDS)
				end
				combatFx(oRoot.Position, "Stun", other.GetModel(), C.STUN_SECONDS)
			end
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Цикл
-- ---------------------------------------------------------------------------

function SuperpowerService.step(now: number)
	local force = Workspace:GetAttribute("SuperpowerForce")
	if type(force) == "string" and force ~= "" then
		Workspace:SetAttribute("SuperpowerForce", nil)
		if round then
			SuperpowerService.finish("cancel")
		end
		local key: string? = force
		if force == "me" or force == "bot" then
			key = nil
			for _, u in ipairs(participants()) do
				if (force == "bot") == u.IsBot then
					key = u.Key
					break
				end
			end
		end
		SuperpowerService.start(key)
	end
	local r = round
	if r then
		local target = units[r.TargetKey]
		local model = target and target.GetModel()
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local tRoot = rootOf(target)
		if tRoot then
			local pos = tRoot.Position
			local last = r.LastPos
			if last then
				local d = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
				if d <= 60 then -- телепорты не считаем ходьбой
					r.Moved += d
				end
			end
			r.LastPos = pos
		end
		if not target or not model then
			SuperpowerService.finish("cancel")
		elseif hum and hum.Health <= 0 then
			SuperpowerService.finish("stopped") -- погиб от врагов: охота засчитана
		elseif now >= r.Ends then
			SuperpowerService.finish("survived")
		end
	elseif C.ENABLED and now >= nextPickAt and Workspace:GetAttribute("SuperpowerPaused") ~= true then
		SuperpowerService.start(nil)
	end
	if now - lastBroadcast >= (if round then 0.5 else 2) then
		broadcast(now)
	end
end

function SuperpowerService.init()
	local _, _, first = Logic.timing(C, timeScale())
	nextPickAt = os.clock() + first
	local function onPlayer(player: Player)
		SuperpowerService.addUnit(playerUnit(player))
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		SuperpowerService.removeUnit(SuperpowerService.keyOf(player))
	end)
	Workspace:GetAttributeChangedSignal("SuperpowerTimeScale"):Connect(function()
		local interval, _, firstDelay = Logic.timing(C, timeScale())
		if not round then
			nextPickAt = math.min(nextPickAt, os.clock() + math.min(interval, firstDelay))
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			SuperpowerService.step(os.clock())
		end
	end)
end

return SuperpowerService
