--!strict
--[[
	CombatService — враги, боссы и бой. Все расчёты урона/наград — на сервере.
	  * Враги живут в Workspace.Enemies (Model + BillboardGui с полосой здоровья, атрибуты Hp/MaxHp для клиентской шкалы босса).
	  * Питомцы бьют автоматически раз в COMBAT_TICK: цель — ближайший враг; урон = сила × роль × стихия × бонусы.
	  * Активные способности питомцев срабатывают по кулдауну (огненный шар, лечение, щит, френзи, «копание» и т.д.).
	  * Игрок помогает ударом (Action "Attack"), урон растёт с силой команды, талантами и клинком.
	  * Награда — монеты, опыт питомцам, ресурсы, эссенция, очки батл-пасса, прогресс квестов.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local EnemyData = require(Shared.EnemyData)
local Formulas = require(Shared.Formulas)
local PetMeta = require(Shared.PetMeta)
local Remotes = require(Shared.Remotes)
local ZoneData = require(Shared.ZoneData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local PetService = require(script.Parent.PetService)
local Progress = require(script.Parent.Progress)
local ResourceService = require(script.Parent.ResourceService)
local Router = require(script.Parent.Router)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local CombatService = {}

export type Enemy = {
	Id: string,
	Def: EnemyData.EnemyDef,
	Zone: string,
	Special: string?, -- "raid" | "moonling" | nil
	Model: Model,
	Body: BasePart,
	Fill: Frame?,
	Hp: number,
	MaxHp: number,
	Home: Vector3,
	Pos: Vector3,
	Half: number, -- половина высоты тела (для стояния на земле)
	Damage: { [Player]: number },
	LastAtk: number,
	Dead: boolean,
}

local enemies: { [string]: Enemy } = {}
local order: { Enemy } = {}
local folder: Folder? = nil
local rng = Random.new()
local counter = 0
local petCd: { [Player]: { [string]: number } } = {}
local lastAttack: { [Player]: number } = {}
local frenzyUntil: { [Player]: number } = {}
local shieldUntil: { [Player]: number } = {}
local raid: Enemy? = nil
local raidEnd: ((boolean, { [Player]: number }, number) -> ())? = nil
local raidDeadline = 0
local lunarOn = false

local ATTACK_SLAM_DAMAGE = 28
local ATTACK_SLAM_RANGE = 22
local ATTACK_SLAM_INTERVAL = 3.2

-- ---------------------------------------------------------------------------
-- Вспомогательное
-- ---------------------------------------------------------------------------

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function fx(player: Player, kind: string, pos: Vector3, text: string, extra: any?)
	Remotes.getEvent("Fx"):FireClient(player, kind, pos, text, extra)
end

local function updateBar(e: Enemy)
	local ratio = math.clamp(e.Hp / e.MaxHp, 0, 1)
	e.Model:SetAttribute("Hp", math.floor(e.Hp))
	if e.Fill then
		e.Fill.Size = UDim2.fromScale(ratio, 1)
	end
end

local function aliveCount(zone: string, boss: boolean, special: string?): number
	local n = 0
	for _, e in ipairs(order) do
		if not e.Dead and e.Zone == zone and e.Def.Boss == boss and e.Special == special then
			n += 1
		end
	end
	return n
end

-- ---------------------------------------------------------------------------
-- Создание врагов
-- ---------------------------------------------------------------------------

local function buildModel(
	def: EnemyData.EnemyDef,
	id: string,
	pos: Vector3,
	maxHp: number,
	special: string?
): (Model, BasePart, Frame, number)
	local m = Instance.new("Model")
	m.Name = "Enemy_" .. id
	local s = def.Size
	local size = if def.Shape == "Tall"
		then Vector3.new(s * 0.7, s * 1.5, s * 0.7)
		elseif def.Shape == "Block" then Vector3.new(s, s * 0.8, s)
		else Vector3.new(s, s, s)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = if def.Shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
	body.Size = size
	body.Color = def.Color
	body.Material = if special == "moonling" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = pos
	body.Parent = m
	for i = -1, 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(s * 0.18, s * 0.18, s * 0.18)
		eye.Color = def.Eye
		eye.Material = Enum.Material.Neon
		eye.Anchored = true
		eye.CanCollide = false
		eye.Position = pos + Vector3.new(i * s * 0.2, size.Y * 0.2, -size.Z * 0.5)
		eye.Parent = m
	end
	m.PrimaryPart = body

	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, size.Y * 0.5 + 2.2, 0)
	gui.MaxDistance = if def.Boss then 160 else 80
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = body
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = if def.Boss then Color3.fromRGB(255, 190, 90) else Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = def.Name
	nameLabel.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	back.BorderSizePixel = 0
	back.Position = UDim2.fromScale(0.05, 0.62)
	back.Size = UDim2.fromScale(0.9, 0.3)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = if def.Boss then Color3.fromRGB(240, 80, 70) else Color3.fromRGB(110, 220, 110)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back

	m:SetAttribute("EnemyName", def.Name)
	m:SetAttribute("EnemyId", def.Id)
	m:SetAttribute("IsBoss", def.Boss)
	m:SetAttribute("IsRaid", special == "raid")
	m:SetAttribute("Zone", def.Zone)
	m:SetAttribute("Hp", maxHp)
	m:SetAttribute("MaxHp", maxHp)
	return m, body, fill, size.Y / 2
end

local function spawnEnemy(
	def: EnemyData.EnemyDef,
	zoneId: string,
	pos: Vector3,
	special: string?,
	maxHpOverride: number?
): Enemy
	counter += 1
	local id = tostring(counter)
	local maxHp = maxHpOverride or EnemyData.maxHp(def, zoneId)
	if special == "moonling" then
		maxHp = EnemyData.maxHp({ HpMult = def.HpMult } :: any, zoneId)
	end
	local m, body, fill, half = buildModel(def, id, pos + Vector3.new(0, 0, 0), maxHp, special)
	local ground = Vector3.new(pos.X, half, pos.Z)
	m:PivotTo(CFrame.new(ground))
	m.Parent = folder
	local e: Enemy = {
		Id = id,
		Def = def,
		Zone = zoneId,
		Special = special,
		Model = m,
		Body = body,
		Fill = fill,
		Hp = maxHp,
		MaxHp = maxHp,
		Home = ground,
		Pos = ground,
		Half = half,
		Damage = {},
		LastAtk = 0,
		Dead = false,
	}
	enemies[id] = e
	table.insert(order, e)
	m:SetAttribute("Id", id)
	return e
end

local function randomSpot(zone: ZoneData.ZoneDef): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(30, 85)
	return zone.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function spawnNormal(zone: ZoneData.ZoneDef)
	local id = zone.Enemies[rng:NextInteger(1, #zone.Enemies)]
	spawnEnemy(EnemyData.ById[id], zone.Id, randomSpot(zone), nil, nil)
end

local function spawnBoss(zone: ZoneData.ZoneDef)
	spawnEnemy(
		EnemyData.ById[zone.Boss],
		zone.Id,
		zone.Position + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-60, -35)),
		nil,
		nil
	)
end

local function removeFromOrder(e: Enemy)
	for i, x in ipairs(order) do
		if x == e then
			table.remove(order, i)
			break
		end
	end
	enemies[e.Id] = nil
end

-- ---------------------------------------------------------------------------
-- Урон, смерть, награды
-- ---------------------------------------------------------------------------

local function reward(player: Player, e: Enemy)
	local data = DataService.get(player)
	if not data then
		return
	end
	local def = e.Def
	local idx = ZoneData.Index[e.Zone] or 3
	local coins = Formulas.killCoins(Economy.getPerClick(player, data), def.Coins)
	Economy.addCoins(player, coins)
	PetService.grantXp(player, def.Xp * 8 * 1.5 ^ (idx - 1))
	for _, drop in ipairs(def.Drops) do
		if rng:NextNumber() < drop.Chance then
			Economy.addResource(player, drop.Res, rng:NextInteger(drop.Min, drop.Max))
		end
	end
	local essenceChance = def.Essence * (1 + Economy.talent(data, "Essence"))
	local essence = math.floor(essenceChance)
	if rng:NextNumber() < essenceChance - essence then
		essence += 1
	end
	if essence > 0 then
		Economy.addResource(player, "Essence", essence)
	end
	if def.Boss and e.Special ~= "raid" then
		Economy.addGems(player, 5 + 3 * idx)
		Economy.addBpXp(player, 20)
	end
	if e.Special ~= "raid" then
		Progress.record(player, "kill", def.Id, 1, e.Zone)
		if def.Boss then
			Progress.record(player, "boss", def.Id, 1, e.Zone)
		end
	end
	fx(
		player,
		"Kill",
		e.Pos + Vector3.new(0, 3, 0),
		"+" .. Economy.describe({ Coins = coins }),
		if def.Boss then "boss" else "kill"
	)
	State.markPets(player)
end

local function die(e: Enemy)
	if e.Dead then
		return
	end
	e.Dead = true
	e.Hp = 0
	updateBar(e)
	if e.Special == "raid" then
		local total = 0
		for _, d in pairs(e.Damage) do
			total += d
		end
		local cb = raidEnd
		raid = nil
		raidEnd = nil
		if cb then
			task.spawn(cb, true, e.Damage, total)
		end
	else
		for player in pairs(e.Damage) do
			if player.Parent then
				reward(player, e)
			end
		end
	end
	-- «Исчезновение»: сжимаем модель и удаляем
	task.delay(0.4, function()
		removeFromOrder(e)
		e.Model:Destroy()
	end)
	-- Возрождение
	local zone = ZoneData.ById[e.Zone]
	if zone and e.Special == nil then
		local wait = if e.Def.Boss then EnemyData.BOSS_RESPAWN_SECONDS else EnemyData.RESPAWN_SECONDS
		task.delay(wait, function()
			if e.Def.Boss then
				if aliveCount(zone.Id, true, nil) == 0 then
					spawnBoss(zone)
				end
			elseif aliveCount(zone.Id, false, nil) < EnemyData.MAX_ALIVE_PER_ZONE then
				spawnNormal(zone)
			end
		end)
	end
end

local function damageEnemy(e: Enemy, amount: number, player: Player, kind: string?)
	if e.Dead or amount <= 0 then
		return
	end
	e.Hp = math.max(0, e.Hp - amount)
	e.Damage[player] = (e.Damage[player] or 0) + amount
	updateBar(e)
	fx(
		player,
		"Hit",
		e.Pos + Vector3.new(rng:NextNumber(-1, 1), e.Half * 2 + 1, rng:NextNumber(-1, 1)),
		tostring(math.floor(amount)),
		kind or "pet"
	)
	if e.Hp <= 0 then
		die(e)
	end
end

-- ---------------------------------------------------------------------------
-- Бой питомцев
-- ---------------------------------------------------------------------------

local function nearbyEnemies(pos: Vector3, range: number): { Enemy }
	local list = {}
	for _, e in ipairs(order) do
		if not e.Dead and (e.Pos - pos).Magnitude <= range then
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		return (a.Pos - pos).Magnitude < (b.Pos - pos).Magnitude
	end)
	return list
end

local function teamTick(player: Player, now: number)
	local data = DataService.get(player)
	local root = rootOf(player)
	local hum = humanoidOf(player)
	if not data or not root or not hum or hum.Health <= 0 or #data.Equipped == 0 then
		return
	end
	local cds = petCd[player]
	if not cds then
		cds = {}
		petCd[player] = cds
	end
	local near = nearbyEnemies(root.Position, Config.COMBAT_RANGE)
	local target = near[1]
	local dmgMult = Economy.getDamageMultiplier(data)
	if (frenzyUntil[player] or 0) > now then
		dmgMult *= 1.5
	end

	for _, uid in ipairs(data.Equipped) do
		local p = data.Pets[uid]
		if p then
			local role = PetMeta.role(p.Id)
			local power = PetMeta.power(p) * Config.PET_DAMAGE_SCALE
			if target then
				local dmg = Formulas.petDamage(
					power,
					role,
					PetMeta.element(p.Id),
					EnemyData.element(target.Def),
					dmgMult
				)
				damageEnemy(target, dmg, player, "pet")
			end
			local ab = PetMeta.ability(p.Id)
			if ab and ab.Kind == "Active" and (cds[uid] or 0) <= now then
				local scale = PetMeta.abilityScale(p.Evo)
				local used = false
				if (ab.Effect == "Damage" or ab.Effect == "AoE") and target and not target.Dead then
					local hits = if ab.Effect == "AoE" then near else { target }
					for _, e in ipairs(hits) do
						local dmg = Formulas.petDamage(
							power,
							role,
							PetMeta.element(p.Id),
							EnemyData.element(e.Def),
							dmgMult * ab.Value * scale
						)
						damageEnemy(e, dmg, player, "ability")
					end
					if ab.Id == "tidal" then
						hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.05)
					end
					used = true
				elseif ab.Effect == "Heal" and hum.Health < hum.MaxHealth * 0.85 then
					hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * ab.Value * scale)
					used = true
				elseif ab.Effect == "Shield" and target then
					shieldUntil[player] = now + 6
					used = true
				elseif ab.Effect == "Frenzy" and target then
					frenzyUntil[player] = now + 6
					dmgMult *= 1.5
					used = true
				elseif ab.Effect == "Mine" then
					used = ResourceService.harvestNearest(player, root.Position, 45)
				end
				if used then
					cds[uid] = now + (ab.Cooldown or 8)
					fx(player, "Ability", root.Position + Vector3.new(0, 4, 0), ab.Name, ab.Id)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- ИИ врагов
-- ---------------------------------------------------------------------------

local function enemyTick(e: Enemy, dt: number, now: number)
	if e.Dead then
		return
	end
	local isRaid = e.Special == "raid"
	-- ближайший живой игрок в зоне агро
	local target: Player? = nil
	local targetPos: Vector3? = nil
	local best = if isRaid then ATTACK_SLAM_RANGE else EnemyData.AGGRO_RANGE
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		local hum = humanoidOf(player)
		if root and hum and hum.Health > 0 then
			local flat = Vector3.new(root.Position.X - e.Pos.X, 0, root.Position.Z - e.Pos.Z)
			local d = flat.Magnitude
			if d < best and (e.Special ~= nil or (e.Home - root.Position).Magnitude < 80) then
				best, target, targetPos = d, player, root.Position
			end
		end
	end

	if isRaid then
		if target and now - e.LastAtk >= ATTACK_SLAM_INTERVAL then
			e.LastAtk = now
			for _, player in ipairs(Players:GetPlayers()) do
				local root = rootOf(player)
				local hum = humanoidOf(player)
				if
					root
					and hum
					and hum.Health > 0
					and (root.Position - e.Pos).Magnitude <= ATTACK_SLAM_RANGE + 6
				then
					local data = DataService.get(player)
					local defense = if data then Economy.getDefense(data) else 1
					if (shieldUntil[player] or 0) > now then
						defense *= 0.5
					end
					hum:TakeDamage(ATTACK_SLAM_DAMAGE * defense)
					fx(
						player,
						"Hurt",
						root.Position + Vector3.new(0, 3, 0),
						"-" .. tostring(math.floor(ATTACK_SLAM_DAMAGE * defense)),
						"enemy"
					)
				end
			end
		end
		e.Model:SetAttribute("TimeLeft", math.max(0, math.ceil(raidDeadline - now)))
		return
	end

	local speed = Config.ENEMY_SPEED * (if e.Def.Boss then 0.7 else 1)
	local goal: Vector3
	if target and targetPos then
		goal = Vector3.new(targetPos.X, e.Half, targetPos.Z)
	else
		goal = e.Home
	end
	local delta = goal - e.Pos
	local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local stopAt = if target then EnemyData.ATTACK_RANGE * 0.8 else 1
	if dist > stopAt then
		local step = math.min(speed * dt, dist - stopAt)
		local dir = Vector3.new(delta.X, 0, delta.Z).Unit
		e.Pos = e.Pos + dir * step
		e.Model:PivotTo(CFrame.lookAt(e.Pos, e.Pos + dir))
	end
	if target and dist <= EnemyData.ATTACK_RANGE and now - e.LastAtk >= EnemyData.ATTACK_INTERVAL then
		e.LastAtk = now
		local hum = humanoidOf(target)
		local data = DataService.get(target)
		if hum and data then
			local dmg = EnemyData.damageToPlayer(e.Def, e.Zone) * Economy.getDefense(data)
			if (shieldUntil[target] or 0) > now then
				dmg *= 0.5
			end
			hum:TakeDamage(dmg)
			fx(
				target,
				"Hurt",
				targetPos :: Vector3 + Vector3.new(0, 3, 0),
				"-" .. tostring(math.ceil(dmg)),
				"enemy"
			)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Публичный API для событий
-- ---------------------------------------------------------------------------

-- Рейд-босс: общий HP на сервере, общий таймер. onEnd(defeated, damageByPlayer, totalDamage)
function CombatService.spawnRaid(
	playerCount: number,
	seconds: number,
	onEnd: (boolean, { [Player]: number }, number) -> ()
)
	if raid then
		return
	end
	local hp =
		math.floor(EnemyData.RAID_BASE_HP * (1 + EnemyData.RAID_HP_PER_PLAYER * math.max(0, playerCount - 1)))
	local e = spawnEnemy(EnemyData.RAID_BOSS, ZoneData.HUB, Vector3.new(0, 0, -65), "raid", hp)
	raid = e
	raidEnd = onEnd
	raidDeadline = os.clock() + seconds
	e.Model:SetAttribute("TimeLeft", seconds)
	e.Model:SetAttribute("RaidTotal", seconds)
end

function CombatService.endRaid()
	local e = raid
	if not e then
		return
	end
	local cb = raidEnd
	raid = nil
	raidEnd = nil
	e.Dead = true
	local total = 0
	for _, d in pairs(e.Damage) do
		total += d
	end
	removeFromOrder(e)
	e.Model:Destroy()
	if cb then
		task.spawn(cb, false, e.Damage, total)
	end
end

function CombatService.raidActive(): boolean
	return raid ~= nil
end

function CombatService.setLunar(active: boolean)
	if lunarOn == active then
		return
	end
	lunarOn = active
	if active then
		for _, zone in ipairs(ZoneData.List) do
			for _ = 1, 2 do
				spawnEnemy(EnemyData.MOONLING, zone.Id, randomSpot(zone), "moonling", nil)
			end
		end
	else
		for _, e in ipairs(table.clone(order)) do
			if e.Special == "moonling" then
				e.Dead = true
				removeFromOrder(e)
				e.Model:Destroy()
			end
		end
	end
end

function CombatService.enemyCount(): number
	return #order
end

-- Для тестов и отладки: убить врага с заданным id от имени игрока
function CombatService.debugDamage(player: Player, enemyId: string, amount: number)
	local e = enemies[enemyId]
	if e then
		damageEnemy(e, amount, player, "debug")
	end
end

-- ---------------------------------------------------------------------------
-- Действия игрока
-- ---------------------------------------------------------------------------

local function attack(player: Player, enemyId: any): (boolean, string?)
	local data = DataService.get(player)
	local root = rootOf(player)
	local hum = humanoidOf(player)
	if not data or not root or not hum or hum.Health <= 0 then
		return false, "Not now"
	end
	local now = os.clock()
	if now - (lastAttack[player] or 0) < Config.PLAYER_ATTACK_COOLDOWN * 0.8 then
		return false, "Too fast"
	end
	local target: Enemy? = nil
	if type(enemyId) == "string" then
		target = enemies[enemyId]
	end
	if not target then
		target = nearbyEnemies(root.Position, Config.PLAYER_ATTACK_RANGE)[1]
	end
	if not target or target.Dead then
		return false, "No enemy in range"
	end
	if (target.Pos - root.Position).Magnitude > Config.PLAYER_ATTACK_RANGE + target.Half then
		return false, "Too far"
	end
	lastAttack[player] = now
	local blade = if Economy.hasItem(data, "blade") then 0.5 else 0
	local dmg = Formulas.playerAttack(
		Economy.getPetPower(data) * Config.PET_DAMAGE_SCALE,
		Economy.talent(data, "PlayerDamage") + Economy.getDamageMultiplier(data) - 1,
		blade
	)
	damageEnemy(target, dmg, player, "player")
	return true, nil
end

function CombatService.init()
	local f = Instance.new("Folder")
	f.Name = "Enemies"
	f.Parent = Workspace
	folder = f

	for _, zone in ipairs(ZoneData.List) do
		for _ = 1, EnemyData.MAX_ALIVE_PER_ZONE do
			spawnNormal(zone)
		end
		spawnBoss(zone)
	end

	Router.register("Attack", 5, 5, attack)

	local accAi, accPets = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		accAi += dt
		accPets += dt
		local now = os.clock()
		if accAi >= 0.1 then
			local step = accAi
			accAi = 0
			for _, e in ipairs(table.clone(order)) do
				enemyTick(e, step, now)
			end
			local r = raid
			if r and now >= raidDeadline then
				CombatService.endRaid()
			end
		end
		if accPets >= Config.COMBAT_TICK then
			accPets = 0
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				if s and s.Ready then
					teamTick(player, now)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		petCd[player] = nil
		lastAttack[player] = nil
		frenzyUntil[player] = nil
		shieldUntil[player] = nil
		for _, e in ipairs(order) do
			e.Damage[player] = nil
		end
	end)
end

return CombatService
