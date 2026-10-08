--!strict
--[[
	BotService (v3.0) — ИИ-боты на малолюдных серверах. Политика: docs/BOTS_POLICY.md.

	  * Живых игроков меньше Config.BOTS.REAL_THRESHOLD — на сервере 10–20 ботов; уходят и приходят по одному
	    через случайные интервалы. Живых стало больше — боты уходят по одному раз в 1–2 минуты (BotLogic.step).
	    Никаких сообщений о входе/выходе.
	  * Бот — только NPC-модель в Workspace.AiBots: НЕ объект Player, поэтому его нет в списке игроков,
	    в рейтингах и в числе игроков; нет профиля в DataStore, чата, покупок и обменов.
	  * Над головой — ник, уровень/ребёрты и метка «ИИ» (Config.BOTS.AI_BADGE).
	  * Ведут себя как игроки: гуляют по хабу и заходят на станции, ходят через порталы в открытые им миры,
	    собирают монеты магнитом, дерутся с «ничьими» врагами (CombatService.botTarget/botHit — добычу у людей
	    не отнимают), открывают яйца (питомцы следуют за ботом — PetFollower), качаются и делают ребёрт у святилища.
	    В «Суперсиле» участвуют как юниты SuperpowerService (охотятся только ближние, не больше MAX_HUNTERS).
	  * Модель: в Roblox — R15 из HumanoidDescription (случайные цвета, рост, простые аксессуары из деталей),
	    анимации ходьбы/покоя через Animator; если R15 недоступен (веб-демо) — R6-риг SuperBots.buildRig.
	  * Нагрузка: решение раз в 0.25 с на всех ботов, Humanoid:MoveTo; питомцы рисуются на клиентах.
	Выключатели: Config.BOTS_ENABLED; атрибут Workspace.BotsDisabled = true — сразу убрать всех (тесты).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local BotLogic = require(Shared.BotLogic)
local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local PetData = require(Shared.PetData)
local Remotes = require(Shared.Remotes)
local ZoneData = require(Shared.ZoneData)

local CombatService = require(script.Parent.CombatService)
local Knockback = require(script.Parent.Knockback)
local SuperBots = require(script.Parent.SuperBots)
local SuperpowerService = require(script.Parent.SuperpowerService)
local WorldBuilder = require(script.Parent.WorldBuilder)

local B = Config.BOTS

local BotService = {}

export type Agent = {
	Key: string,
	Name: string,
	Index: number,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Unit: SuperpowerService.Unit,
	NextWander: number,
	Home: Vector3,
	-- прокачка (только в памяти)
	Level: number,
	Xp: number,
	Rebirths: number,
	Pets: { string },
	-- поведение
	Zone: string,
	ZoneSince: number,
	Task: string,
	TaskUntil: number,
	Goal: Vector3?,
	Station: string?,
	TravelTo: string?,
	EnemyId: string?,
	Egg: string?,
	NextSwing: number,
	Arrived: number?,
	LevelLabel: TextLabel?,
	Anim: { Walk: AnimationTrack?, Idle: AnimationTrack?, Moving: boolean }?,
}

local agents: { Agent } = {}
local used: { [string]: boolean } = {}
local pop = BotLogic.newPop()
local rng = Random.new()
local counter = 0
local folder: Folder? = nil
local started = false

-- для тестов: подменить построение модели (в тестовой среде нет физики и HumanoidDescription)
BotService.makeModel = nil :: ((name: string, index: number) -> (Model, BasePart, Humanoid))?

local function rnd(): number
	return rng:NextNumber()
end
local function rint(a: number, b: number): number
	return rng:NextInteger(a, b)
end

local function realCount(): number
	return #Players:GetPlayers()
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "AiBots"
	f.Parent = Workspace
	folder = f
	return f
end

-- ---------------------------------------------------------------------------
-- Внешний вид
-- ---------------------------------------------------------------------------
local SKINS = {
	Color3.fromRGB(255, 220, 185),
	Color3.fromRGB(240, 195, 150),
	Color3.fromRGB(200, 150, 110),
	Color3.fromRGB(150, 105, 75),
	Color3.fromRGB(105, 70, 50),
	Color3.fromRGB(255, 205, 120),
}
local SHIRTS = {
	Color3.fromRGB(231, 76, 60),
	Color3.fromRGB(46, 204, 113),
	Color3.fromRGB(155, 89, 182),
	Color3.fromRGB(241, 196, 15),
	Color3.fromRGB(52, 152, 219),
	Color3.fromRGB(230, 126, 34),
	Color3.fromRGB(26, 188, 156),
	Color3.fromRGB(236, 100, 160),
	Color3.fromRGB(240, 240, 245),
	Color3.fromRGB(45, 52, 70),
}
local PANTS = {
	Color3.fromRGB(44, 62, 80),
	Color3.fromRGB(60, 60, 70),
	Color3.fromRGB(70, 90, 140),
	Color3.fromRGB(110, 80, 60),
	Color3.fromRGB(30, 30, 35),
}
local HAIR = {
	Color3.fromRGB(40, 30, 25),
	Color3.fromRGB(120, 75, 40),
	Color3.fromRGB(230, 190, 110),
	Color3.fromRGB(200, 70, 50),
	Color3.fromRGB(60, 60, 65),
	Color3.fromRGB(120, 90, 200),
}

local function pick<T>(list: { T }): T
	return list[rint(1, #list)]
end

-- Простые аксессуары из деталей (без ассетов каталога): кепка, шапка-бини или причёска
local function addAccessory(head: BasePart)
	local kind = rint(1, 4)
	if kind == 4 then
		return -- без аксессуара
	end
	local color = if kind == 3 then pick(HAIR) else pick(SHIRTS)
	local function weldPart(name: string, size: Vector3, offset: CFrame, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape or Enum.PartType.Block
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = head.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = p
		w.Parent = p
		p.Parent = head.Parent
		return p
	end
	local h = head.Size.Y
	if kind == 1 then
		weldPart("BotCap", Vector3.new(1.25, 0.45, 1.2), CFrame.new(0, h * 0.5, 0))
		weldPart("BotCapBrim", Vector3.new(1.1, 0.12, 0.7), CFrame.new(0, h * 0.35, -0.75))
	elseif kind == 2 then
		weldPart("BotBeanie", Vector3.new(1.3, 0.6, 1.25), CFrame.new(0, h * 0.45, 0))
		weldPart(
			"BotPompom",
			Vector3.new(0.4, 0.4, 0.4),
			CFrame.new(0, h * 0.45 + 0.45, 0),
			Enum.PartType.Ball
		)
	else
		weldPart("BotHair", Vector3.new(1.25, 0.4, 1.25), CFrame.new(0, h * 0.5, 0.05))
		weldPart("BotHairBack", Vector3.new(1.25, 0.8, 0.3), CFrame.new(0, h * 0.15, 0.55))
	end
end

-- Табличка: ник + метка «ИИ», вторая строка — уровень и ребёрты
local function addTag(head: BasePart, name: string): TextLabel
	local old = head:FindFirstChild("OverheadTag")
	if old then
		old:Destroy()
	end
	local g = Instance.new("BillboardGui")
	g.Name = "OverheadTag"
	g.Size = UDim2.fromOffset(170, 40)
	g.StudsOffset = Vector3.new(0, 2.6, 0)
	g.MaxDistance = 70
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	local n = Instance.new("TextLabel")
	n.Name = "NameLabel"
	n.BackgroundTransparency = 1
	n.Size = UDim2.fromScale(1, 0.58)
	n.Font = Enum.Font.GothamBold
	n.TextScaled = true
	n.TextColor3 = Color3.fromRGB(255, 255, 255)
	n.TextStrokeTransparency = 0.45
	if B.AI_BADGE then
		Locale.setWorld(n, "bot.name_ai", { player = name })
	else
		n.Text = name
	end
	n.Parent = g
	local lv = Instance.new("TextLabel")
	lv.Name = "LevelLabel"
	lv.BackgroundTransparency = 1
	lv.Position = UDim2.fromScale(0, 0.6)
	lv.Size = UDim2.fromScale(1, 0.4)
	lv.Font = Enum.Font.GothamBold
	lv.TextScaled = true
	lv.TextColor3 = Color3.fromRGB(255, 220, 120)
	lv.TextStrokeTransparency = 0.5
	lv.Parent = g
	g.Parent = head
	return lv
end

-- R15 из HumanoidDescription (Roblox). nil — недоступно (веб-демо): тогда R6
local function buildR15(name: string): (Model?, BasePart?, Humanoid?)
	local ok, model = pcall(function()
		local d = Instance.new("HumanoidDescription")
		local skin = pick(SKINS)
		d.HeadColor = skin
		d.LeftArmColor = skin
		d.RightArmColor = skin
		local shirt = pick(SHIRTS)
		d.TorsoColor = shirt
		local pants = pick(PANTS)
		d.LeftLegColor = pants
		d.RightLegColor = pants
		d.HeightScale = 0.92 + rnd() * 0.14
		d.WidthScale = 0.9 + rnd() * 0.15
		d.HeadScale = 0.95 + rnd() * 0.1
		return (Players :: any):CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil, nil, nil
	end
	local m = model :: Model
	m.Name = "Bot_" .. name
	for _, s in ipairs(m:GetChildren()) do
		if s:IsA("Script") or s:IsA("LocalScript") then
			s:Destroy() -- Animate/Health игрока здесь не нужны: анимации ведёт сервер
		end
	end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not (hrp and hrp:IsA("BasePart") and hum) then
		m:Destroy()
		return nil, nil, nil
	end
	return m, hrp, hum
end

local ANIM = { Idle = "rbxassetid://507766388", Walk = "rbxassetid://507777826" }

local function setupAnim(a: Agent)
	if a.Humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	pcall(function()
		local animator: Animator? = a.Humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local made = Instance.new("Animator")
			made.Parent = a.Humanoid
			animator = made
		end
		local function load(id: string): AnimationTrack
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			return (animator :: Animator):LoadAnimation(anim)
		end
		local idle, walk = load(ANIM.Idle), load(ANIM.Walk)
		idle.Looped = true
		walk.Looped = true
		idle:Play()
		a.Anim = { Idle = idle, Walk = walk, Moving = false }
	end)
end

local function updateAnim(a: Agent)
	local an = a.Anim
	if not an then
		return
	end
	local v = a.Root.AssemblyLinearVelocity
	local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 1.5
	if moving ~= an.Moving then
		an.Moving = moving
		if moving then
			if an.Idle then
				an.Idle:Stop(0.2)
			end
			if an.Walk then
				an.Walk:Play(0.2)
			end
		else
			if an.Walk then
				an.Walk:Stop(0.2)
			end
			if an.Idle then
				an.Idle:Play(0.2)
			end
		end
	end
end

local function defaultModel(name: string, index: number): (Model, BasePart, Humanoid)
	local m, hrp, hum = buildR15(name)
	if m and hrp and hum then
		return m, hrp, hum
	end
	return SuperBots.buildRig(name, SHIRTS[(index - 1) % #SHIRTS + 1])
end

-- ---------------------------------------------------------------------------
-- Прокачка и питомцы
-- ---------------------------------------------------------------------------
local function refreshTag(a: Agent)
	local l = a.LevelLabel
	if l then
		if a.Rebirths > 0 then
			Locale.setWorld(l, "bot.level_rb", { lv = a.Level, rb = a.Rebirths })
		else
			Locale.setWorld(l, "bot.level", { lv = a.Level })
		end
	end
end

local function refreshPets(a: Agent)
	local parts = {}
	for _, id in ipairs(a.Pets) do
		table.insert(parts, id .. ":Normal")
	end
	a.Model:SetAttribute("EquippedPets", table.concat(parts, ","))
end

local function eggsIn(zone: string): { PetData.EggDef }
	local out = {}
	for _, egg in ipairs(PetData.Eggs) do
		if egg.Zone == zone and egg.Event == nil and WorldBuilder.getEggPosition(egg.Id) then
			table.insert(out, egg)
		end
	end
	return out
end

local function hatch(a: Agent, eggId: string)
	local id = PetData.roll(eggId, 1, rnd())
	if not id then
		return
	end
	if #a.Pets >= B.MAX_PETS then
		-- заменяем самого слабого, если новый сильнее
		local weakest, wp = 1, math.huge
		for i, pid in ipairs(a.Pets) do
			local p = PetData.getPower(pid)
			if p < wp then
				weakest, wp = i, p
			end
		end
		if PetData.getPower(id) > wp then
			a.Pets[weakest] = id
		end
	else
		table.insert(a.Pets, id)
	end
	refreshPets(a)
end

local function gainXp(a: Agent, xp: number)
	if BotLogic.addXp(a, xp) > 0 then
		refreshTag(a)
	end
end

-- ---------------------------------------------------------------------------
-- Перемещение
-- ---------------------------------------------------------------------------
local function moveTo(a: Agent, pos: Vector3)
	a.Goal = pos
	a.Humanoid:MoveTo(Vector3.new(pos.X, a.Root.Position.Y - 3, pos.Z))
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function near(a: Agent, pos: Vector3, dist: number): boolean
	return flat(a.Root.Position - pos).Magnitude <= dist
end

local function teleport(a: Agent, cf: CFrame)
	pcall(function()
		a.Model:PivotTo(cf + Vector3.new(rnd() * 8 - 4, 0.2, rnd() * 6 - 3))
	end)
end

local function zoneCenter(zone: string): Vector3
	if zone == ZoneData.HUB then
		return ZoneData.HUB_POSITION
	end
	local z = ZoneData.ById[zone]
	return if z then z.Position else ZoneData.HUB_POSITION
end

local function randomPoint(zone: string): Vector3
	local c = zoneCenter(zone)
	local a = rnd() * math.pi * 2
	if zone == ZoneData.HUB then
		local r = 22 + rnd() * 62
		return c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	end
	local r = 8 + rnd() * 70
	return c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end

local function openZones(a: Agent): { string }
	local n = BotLogic.zonesOpen(a, #ZoneData.List)
	local out = {}
	for i = 1, n do
		table.insert(out, ZoneData.List[i].Id)
	end
	return out
end

local function swingFx(a: Agent)
	local ev = Remotes.getEvent("CombatFx")
	local pos = a.Root.Position
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and (r.Position - pos).Magnitude < 150 then
			ev:FireClient(p, "Swing", a.Model)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Выбор занятия
-- ---------------------------------------------------------------------------
local HUB_STATIONS = { "craft", "market", "altar", "upgrades", "daily", "board", "rebirth" }

local function setTask(a: Agent, task_: string, now: number, seconds: number)
	a.Task = task_
	a.TaskUntil = now + seconds
	a.Arrived = nil
	a.EnemyId = nil
end

local function chooseTask(a: Agent, now: number)
	local inHub = a.Zone == ZoneData.HUB
	local opts: { { N: string, W: number } } = {}
	if inHub then
		local stay = now - a.ZoneSince
		table.insert(opts, { N = "wander", W = 20 })
		table.insert(opts, { N = "visit", W = 30 })
		table.insert(opts, { N = "collect", W = 12 })
		if #eggsIn(ZoneData.HUB) > 0 then
			table.insert(opts, { N = "hatch", W = 8 })
		end
		table.insert(opts, { N = "travel", W = if stay > 40 then 45 else 12 })
		if BotLogic.canRebirth(a) then
			table.insert(opts, { N = "rebirth", W = 80 })
		end
	else
		local stay = now - a.ZoneSince
		table.insert(opts, { N = "fight", W = 45 })
		table.insert(opts, { N = "collect", W = 22 })
		table.insert(opts, { N = "hatch", W = 12 })
		table.insert(opts, { N = "wander", W = 8 })
		table.insert(opts, { N = "travel", W = if stay > 150 then 40 else 4 })
		if BotLogic.canRebirth(a) then
			table.insert(opts, { N = "travel", W = 60 })
		end
	end
	local total = 0
	for _, o in ipairs(opts) do
		total += o.W
	end
	local roll = rnd() * total
	local choice = "wander"
	for _, o in ipairs(opts) do
		roll -= o.W
		if roll <= 0 then
			choice = o.N
			break
		end
	end
	if choice == "wander" then
		setTask(a, "wander", now, 6 + rnd() * 6)
		moveTo(a, randomPoint(a.Zone))
	elseif choice == "visit" or choice == "rebirth" then
		local st = if choice == "rebirth" then "rebirth" else pick(HUB_STATIONS)
		local pos = WorldBuilder.getStationPosition(st)
		if not pos then
			setTask(a, "wander", now, 5)
			moveTo(a, randomPoint(a.Zone))
			return
		end
		a.Station = st
		setTask(a, "visit", now, 25)
		moveTo(a, pos + Vector3.new(rnd() * 8 - 4, 0, -7 - rnd() * 3))
	elseif choice == "collect" then
		setTask(a, "collect", now, 6 + rnd() * 8)
		moveTo(a, randomPoint(a.Zone))
	elseif choice == "fight" then
		setTask(a, "fight", now, 20 + rnd() * 20)
	elseif choice == "hatch" then
		local eggs = eggsIn(a.Zone)
		if #eggs == 0 then
			setTask(a, "wander", now, 5)
			moveTo(a, randomPoint(a.Zone))
			return
		end
		local egg = pick(eggs)
		a.Egg = egg.Id
		setTask(a, "hatch", now, 25)
		local ep = WorldBuilder.getEggPosition(egg.Id) :: Vector3
		moveTo(a, ep + Vector3.new(rnd() * 6 - 3, 0, 7))
	elseif choice == "travel" then
		if inHub then
			local zones = openZones(a)
			local to = pick(zones)
			a.TravelTo = to
			setTask(a, "travel", now, 40)
			local portal = WorldBuilder.getPortalPosition(to) or WorldBuilder.getStationPosition("portal")
			moveTo(a, (portal or Vector3.new(0, 0, 64)) + Vector3.new(rnd() * 2 - 1, 0, rnd() * 2 - 1))
		else
			a.TravelTo = ZoneData.HUB
			setTask(a, "travel", now, 30)
			-- v3.0: к арке возврата мира (если её нет — к точке появления)
			local back = WorldBuilder.getStationPosition("return_" .. a.Zone)
			moveTo(a, back or WorldBuilder.getZoneSpawn(a.Zone).Position)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Мысль бота (раз в 0.25 с)
-- ---------------------------------------------------------------------------
local function huntRole(a: Agent, now: number): boolean
	if not SuperpowerService.isActive() then
		return false
	end
	if SuperpowerService.isSuperKey(a.Key) then
		SuperBots.think(a :: any, now)
		return true
	end
	local tr = SuperpowerService.targetRoot()
	if not tr or (tr.Position - a.Root.Position).Magnitude > B.HUNT_RANGE then
		return false
	end
	-- не больше MAX_HUNTERS ближних ботов (по порядку в списке)
	local n = 0
	for _, o in ipairs(agents) do
		if o == a then
			break
		end
		if o.Model.Parent and (tr.Position - o.Root.Position).Magnitude <= B.HUNT_RANGE then
			n += 1
		end
	end
	if n >= B.MAX_HUNTERS then
		return false
	end
	SuperBots.think(a :: any, now)
	return true
end

local function think(a: Agent, now: number)
	if a.Model.Parent == nil then
		return
	end
	updateAnim(a)
	local u = a.Unit
	if u.StunnedUntil > now then
		a.Humanoid.WalkSpeed = 0
		return
	end
	if huntRole(a, now) then
		return
	end
	a.Humanoid.WalkSpeed = B.SPEED
	-- упал с карты / застрял далеко — обратно на точку появления своей зоны
	if a.Root.Position.Y < -30 or flat(a.Root.Position - zoneCenter(a.Zone)).Magnitude > 160 then
		teleport(a, WorldBuilder.getZoneSpawn(a.Zone))
		setTask(a, "idle", now, 1)
		return
	end
	if now >= a.TaskUntil then
		chooseTask(a, now)
		return
	end
	local t = a.Task
	if t == "wander" then
		if a.Goal and near(a, a.Goal, 3) then
			a.TaskUntil = math.min(a.TaskUntil, now + 1 + rnd() * 2)
		end
	elseif t == "visit" then
		if a.Goal and near(a, a.Goal, 3.5) then
			if not a.Arrived then
				a.Arrived = now
				a.TaskUntil = now + 3 + rnd() * 4 -- «смотрит» окно станции
				if a.Station == "rebirth" and BotLogic.rebirth(a) then
					refreshTag(a)
					local ev = Remotes.getEvent("CombatFx")
					for _, p in ipairs(Players:GetPlayers()) do
						ev:FireClient(p, "Impact", a.Root.Position + Vector3.new(0, 2, 0))
					end
				end
			end
		end
	elseif t == "collect" then
		if a.Goal and near(a, a.Goal, 3) and now >= a.NextSwing then
			a.NextSwing = now + 0.55 + rnd() * 0.4
			swingFx(a)
			gainXp(a, 1)
		end
	elseif t == "fight" then
		local id, pos = CombatService.botTarget(a.Root.Position, 80)
		a.EnemyId = id
		if not id or not pos then
			-- врагов нет или их бьют живые игроки — заняться другим
			setTask(a, "wander", now, 4 + rnd() * 3)
			moveTo(a, randomPoint(a.Zone))
			return
		end
		if near(a, pos, 7) then
			a.Humanoid:MoveTo(a.Root.Position)
			a.Root.CFrame = CFrame.lookAt(a.Root.Position, Vector3.new(pos.X, a.Root.Position.Y, pos.Z))
			if now >= a.NextSwing then
				a.NextSwing = now + 0.8 + rnd() * 0.4
				swingFx(a)
				local hit, killed = CombatService.botHit(id, B.BOT_HIT)
				if hit and killed then
					gainXp(a, 25)
					a.EnemyId = nil
				end
			end
		elseif not a.Goal or flat(a.Goal - pos).Magnitude > 3 then
			moveTo(a, pos + flat(a.Root.Position - pos).Unit * 5)
		end
	elseif t == "hatch" then
		if a.Goal and near(a, a.Goal, 3.5) then
			if not a.Arrived then
				a.Arrived = now
				a.TaskUntil = now + 2.5 + rnd() * 1.5
			elseif now - a.Arrived >= 2.2 and a.Egg then
				hatch(a, a.Egg)
				gainXp(a, 10)
				a.Egg = nil
			end
		end
	elseif t == "travel" then
		if a.Goal and near(a, a.Goal, 4) and a.TravelTo then
			local to = a.TravelTo
			a.TravelTo = nil
			a.Zone = to
			a.ZoneSince = now
			teleport(a, WorldBuilder.getZoneSpawn(to))
			setTask(a, "idle", now, 1 + rnd() * 2)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Вход и уход
-- ---------------------------------------------------------------------------
local function spawnBot(initial: boolean): Agent?
	counter += 1
	local index = counter
	local name = BotLogic.makeName(rint, used)
	local maker: (string, number) -> (Model, BasePart, Humanoid) = BotService.makeModel or defaultModel
	local m, root, hum = maker(name, index)
	hum.WalkSpeed = B.SPEED
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	m:SetAttribute("IsBot", true)
	m:SetAttribute("AiBot", true)
	local head = m:FindFirstChild("Head")
	local lvLabel: TextLabel? = nil
	if head and head:IsA("BasePart") then
		if not BotService.makeModel then
			addAccessory(head)
		end
		lvLabel = addTag(head, name)
	end
	local key = "ai" .. index
	local a: Agent
	local unit: SuperpowerService.Unit = {
		Key = key,
		Name = name,
		IsBot = true,
		Player = nil,
		GetModel = function()
			return if m.Parent then m else nil
		end,
		Eligible = function()
			return m.Parent ~= nil and hum.Health > 0
		end,
		Knock = function(dir: Vector3, dist: number, _stun: number)
			local shift = Knockback.offset(m:GetPivot().Position, dir, dist, { m })
			pcall(function()
				m:PivotTo(m:GetPivot() + shift + Vector3.new(0, 1, 0))
			end)
		end,
		StunnedUntil = 0,
		ImmuneUntil = 0,
		LastHit = -1e9,
		LastSlam = -1e9,
	}
	-- новичок или «бывалый»: уровень и ребёрты случайно, как у живых игроков
	local rebirths = if rnd() < 0.35 then rint(1, 3) else 0
	a = {
		Key = key,
		Name = name,
		Index = index,
		Model = m,
		Root = root,
		Humanoid = hum,
		Unit = unit,
		NextWander = 0,
		Home = ZoneData.HUB_POSITION + Vector3.new(0, 0, 30),
		Level = rint(1, 26),
		Xp = 0,
		Rebirths = rebirths,
		Pets = {},
		Zone = ZoneData.HUB,
		ZoneSince = os.clock(),
		Task = "idle",
		TaskUntil = 0,
		Goal = nil,
		Station = nil,
		TravelTo = nil,
		EnemyId = nil,
		Egg = nil,
		NextSwing = 0,
		Arrived = nil,
		LevelLabel = lvLabel,
		Anim = nil,
	}
	-- стартовые питомцы из яиц открытых миров
	local zones = openZones(a)
	for _ = 1, rint(1, B.MAX_PETS) do
		local eggs = eggsIn(pick(zones))
		if #eggs == 0 then
			eggs = eggsIn(ZoneData.HUB)
		end
		if #eggs > 0 then
			hatch(a, pick(eggs).Id)
		end
	end
	refreshTag(a)
	-- при старте сервера боты «уже играют» в разных местах; новые приходят на точку появления хаба
	if initial and rnd() < 0.6 then
		a.Zone = pick(zones)
	end
	local cf = if a.Zone == ZoneData.HUB and not initial
		then WorldBuilder.getZoneSpawn(ZoneData.HUB)
		else CFrame.new(randomPoint(a.Zone) + Vector3.new(0, 3.2, 0))
	m:PivotTo(cf)
	m.Parent = getFolder()
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	setupAnim(a)
	table.insert(agents, a)
	SuperpowerService.addUnit(unit)
	return a
end

local function removeBot(a: Agent)
	local i = table.find(agents, a)
	if i then
		table.remove(agents, i)
	end
	used[a.Name] = nil
	SuperpowerService.removeUnit(a.Key)
	a.Model.Parent = nil
	a.Model:Destroy()
end

-- Кто уходит: не суперигрок и, по возможности, тот, кого сейчас никто не видит рядом
local function pickLeaver(): Agent?
	local best: Agent? = nil
	local bestD = -1
	for _, a in ipairs(agents) do
		if not SuperpowerService.isSuperKey(a.Key) then
			local d = math.huge
			for _, p in ipairs(Players:GetPlayers()) do
				local c = p.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					d = math.min(d, (r.Position - a.Root.Position).Magnitude)
				end
			end
			d += rnd() * 60 -- немного случайности
			if d > bestD then
				best, bestD = a, d
			end
		end
	end
	return best
end

function BotService.list(): { Agent }
	return agents
end

function BotService.population(): BotLogic.Pop
	return pop
end

function BotService.clear()
	for i = #agents, 1, -1 do
		removeBot(agents[i])
	end
	pop = BotLogic.newPop()
end

-- Шаг численности (вызывается раз в секунду; тесты зовут напрямую с виртуальным временем)
function BotService.populationStep(now: number)
	if not Config.BOTS_ENABLED or Workspace:GetAttribute("BotsDisabled") == true then
		if #agents > 0 then
			BotService.clear()
		end
		return
	end
	pop.Count = #agents
	local initial = pop.Mode == "idle" or pop.Mode == "fill"
	local action = BotLogic.step(pop, B, now, realCount(), rnd, rint)
	if action == "join" then
		spawnBot(initial)
	elseif action == "leave" then
		local a = pickLeaver()
		if a then
			removeBot(a)
		end
	end
	pop.Count = #agents
end

function BotService.thinkAll(now: number)
	for _, a in ipairs(agents) do
		local ok, err = pcall(function()
			think(a, now)
		end)
		if not ok then
			warn("[BotService] " .. tostring(err))
		end
	end
end

function BotService.init()
	if started then
		return
	end
	started = true
	local acc, popAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		popAcc += dt
		if popAcc >= 0.5 then
			popAcc = 0
			BotService.populationStep(os.clock())
		end
		if acc >= 0.25 then
			acc = 0
			BotService.thinkAll(os.clock())
		end
	end)
end

return BotService
