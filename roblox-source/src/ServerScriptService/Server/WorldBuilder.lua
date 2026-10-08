--!strict
-- Строит весь мир скриптом из примитивов (нет внешних ассетов): платформы миров, декор, яйца, табло лидеров.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Logo = require(Shared.Logo)
local PetData = require(Shared.PetData)
local QuestData = require(Shared.QuestData)
local Util = require(Shared.Util)
local ZoneData = require(Shared.ZoneData)

local WorldBuilder = {}

local zoneSpawns: { [string]: CFrame } = {}
local eggPositions: { [string]: Vector3 } = {}
local eggCallbacks: { (Player, string) -> () } = {}
local npcCallbacks: { (Player, string) -> () } = {}
local stationPositions: { [string]: Vector3 } = {}
local hubSpawn = CFrame.new(0, 5, 24)
local lastPrompt: { [Player]: number } = {}
local boardRows: { TextLabel } = {}
local boardStatus: TextLabel? = nil
local built = false

local function mk(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
)
	return mk(parent, name, Enum.PartType.Block, size, CFrame.new(pos), color, material, true)
end

-- text — ключ Locale или исходный текст «данных»; на клиенте его переводит WorldLocalizer
local function makeLabel(
	parent: Instance,
	text: string,
	size: UDim2,
	color: Color3,
	args: { [string]: any }?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	Locale.setWorld(l, text, args)
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.ZIndex = 1
	l.Parent = parent
	return l
end

local function billboard(parent: BasePart, offset: Vector3, width: number, height: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	-- размер в студах: подпись уменьшается с расстоянием и не закрывает HUD на телефоне
	gui.Size = UDim2.fromScale(width / 16, height / 16)
	gui.StudsOffset = offset
	gui.MaxDistance = 70 -- дальние подписи не налезают на верхний HUD
	gui.LightInfluence = 0
	gui.Parent = parent
	return gui
end

-- ---------------------------------------------------------------------------
-- Декор
-- ---------------------------------------------------------------------------
local function decorTree(folder: Folder, pos: Vector3, rng: Random, leaf: Color3, trunk: Color3)
	local h = rng:NextNumber(7, 12)
	local m = Instance.new("Model")
	m.Name = "Tree"
	mk(
		m,
		"Trunk",
		Enum.PartType.Cylinder,
		Vector3.new(h, 2, 2),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		trunk,
		Enum.Material.Wood,
		true
	)
	local d = rng:NextNumber(9, 13)
	mk(
		m,
		"Leaves",
		Enum.PartType.Ball,
		Vector3.new(d, d, d),
		CFrame.new(pos + Vector3.new(0, h + d * 0.3, 0)),
		leaf,
		Enum.Material.Grass,
		false
	)
	m.Parent = folder
end

local function decorCactus(folder: Folder, pos: Vector3, rng: Random, color: Color3)
	local h = rng:NextNumber(6, 10)
	local m = Instance.new("Model")
	m.Name = "Cactus"
	mk(
		m,
		"Stem",
		Enum.PartType.Cylinder,
		Vector3.new(h, 2.2, 2.2),
		CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.SmoothPlastic,
		true
	)
	mk(
		m,
		"ArmL",
		Enum.PartType.Cylinder,
		Vector3.new(3, 1.2, 1.2),
		CFrame.new(pos + Vector3.new(-1.8, h * 0.55, 0)),
		color,
		nil,
		false
	)
	mk(
		m,
		"ArmR",
		Enum.PartType.Cylinder,
		Vector3.new(3, 1.2, 1.2),
		CFrame.new(pos + Vector3.new(1.8, h * 0.7, 0)),
		color,
		nil,
		false
	)
	m.Parent = folder
end

local function decorCrystal(folder: Folder, pos: Vector3, rng: Random, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Crystal"
	for i = 1, 3 do
		local h = rng:NextNumber(5, 11)
		local part = mk(
			m,
			"Shard" .. i,
			Enum.PartType.Block,
			Vector3.new(2, h, 2),
			CFrame.new(pos + Vector3.new(rng:NextNumber(-2, 2), h / 2 - 0.5, rng:NextNumber(-2, 2)))
				* CFrame.Angles(
					math.rad(rng:NextNumber(-12, 12)),
					rng:NextNumber(0, 6),
					math.rad(rng:NextNumber(-12, 12))
				),
			color,
			Enum.Material.Glass,
			false
		)
		part.Transparency = 0.25
	end
	m.Parent = folder
end

local function decorRock(folder: Folder, pos: Vector3, rng: Random, color: Color3, glow: Color3)
	local d = rng:NextNumber(5, 10)
	local m = Instance.new("Model")
	m.Name = "Rock"
	mk(
		m,
		"Rock",
		Enum.PartType.Ball,
		Vector3.new(d, d, d),
		CFrame.new(pos + Vector3.new(0, d * 0.3, 0)),
		color,
		Enum.Material.Slate,
		true
	)
	if rng:NextNumber() < 0.5 then
		mk(
			m,
			"Lava",
			Enum.PartType.Ball,
			Vector3.new(d * 0.4, d * 0.4, d * 0.4),
			CFrame.new(pos + Vector3.new(d * 0.2, d * 0.7, 0)),
			glow,
			Enum.Material.Neon,
			false
		)
	end
	m.Parent = folder
end

-- ---------------------------------------------------------------------------
-- Яйцо
-- ---------------------------------------------------------------------------
local function buildEgg(parent: Instance, egg: PetData.EggDef, pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "Egg_" .. egg.Id

	mk(
		m,
		"Base",
		Enum.PartType.Cylinder,
		Vector3.new(1.4, 11, 11),
		CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(235, 235, 240),
		Enum.Material.Marble,
		true
	)
	mk(
		m,
		"BaseRing",
		Enum.PartType.Cylinder,
		Vector3.new(0.4, 12, 12),
		CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		egg.Pattern,
		Enum.Material.Neon,
		false
	)

	local eggCenter = pos + Vector3.new(0, 5.6, 0)
	local shell = mk(
		m,
		"Shell",
		Enum.PartType.Ball,
		Vector3.new(7, 7, 7),
		CFrame.new(eggCenter),
		egg.Color,
		Enum.Material.SmoothPlastic,
		true
	)
	-- пятна на скорлупе
	local spots = {
		Vector3.new(1.2, 2.4, -2.4),
		Vector3.new(-2.2, 0.6, -2.5),
		Vector3.new(2.5, -0.8, -2.2),
		Vector3.new(-0.6, -2.2, -2.6),
		Vector3.new(0.4, 0.2, -3.5),
		Vector3.new(-2.8, 2.0, 1.2),
		Vector3.new(2.9, 1.6, 1.0),
	}
	for i, offset in ipairs(spots) do
		local dir = offset.Unit * 3.45
		mk(
			m,
			"Spot" .. i,
			Enum.PartType.Ball,
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(eggCenter + dir),
			egg.Pattern,
			Enum.Material.SmoothPlastic,
			false
		)
	end

	local prompt = Instance.new("ProximityPrompt")
	Locale.setWorld(prompt, "prompt.open", nil, "ActionText")
	Locale.setWorld(prompt, egg.Name, nil, "ObjectText")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = shell
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.5 then
			return
		end
		lastPrompt[player] = now
		for _, cb in ipairs(eggCallbacks) do
			task.spawn(cb, player, egg.Id)
		end
	end)

	local gui = billboard(shell, Vector3.new(0, 6, 0), 220, 70)
	makeLabel(gui, egg.Name, UDim2.fromScale(1, 0.55), Color3.fromRGB(255, 255, 255))
	local priceColor = if egg.Currency == "Gems"
		then Color3.fromRGB(120, 230, 255)
		else Color3.fromRGB(255, 220, 90)
	local priceLabel = makeLabel(
		gui,
		if egg.Currency == "Gems" then "world.price_gems" else "world.price_coins",
		UDim2.fromScale(1, 0.4),
		priceColor,
		{ price = Util.formatNumber(egg.Price), n = egg.Price }
	)
	priceLabel.Position = UDim2.fromScale(0, 0.58)

	eggPositions[egg.Id] = pos
	m.Parent = parent
end

-- ---------------------------------------------------------------------------
-- Табло лидеров
-- ---------------------------------------------------------------------------
local function buildBoard(parent: Instance, center: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Leaderboard"
	local face = Color3.fromRGB(30, 34, 48)
	local board = mk(
		m,
		"Board",
		Enum.PartType.Block,
		Vector3.new(30, 18, 1),
		CFrame.new(center + Vector3.new(0, 11, 0)) * CFrame.Angles(0, math.pi, 0),
		face,
		Enum.Material.SmoothPlastic,
		true
	)
	block(
		m,
		"PostL",
		Vector3.new(1.5, 11, 1.5),
		center + Vector3.new(-10, 5.5, 0.2),
		Color3.fromRGB(110, 80, 60),
		Enum.Material.Wood
	)
	block(
		m,
		"PostR",
		Vector3.new(1.5, 11, 1.5),
		center + Vector3.new(10, 5.5, 0.2),
		Color3.fromRGB(110, 80, 60),
		Enum.Material.Wood
	)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = makeLabel(gui, "world.top_title", UDim2.fromScale(0.9, 0.12), Color3.fromRGB(255, 214, 90))
	title.Position = UDim2.fromScale(0.05, 0.02)
	local sub = makeLabel(gui, "board.subtitle", UDim2.fromScale(0.6, 0.05), Color3.fromRGB(190, 200, 220))
	sub.Position = UDim2.fromScale(0.2, 0.135)
	boardStatus = sub

	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Name = "Row" .. i
		row.BackgroundTransparency = if i % 2 == 0 then 0.92 else 1
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.Size = UDim2.fromScale(0.9, 0.07)
		row.Position = UDim2.fromScale(0.05, 0.2 + (i - 1) * 0.078)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 214, 90) else Color3.fromRGB(235, 240, 250)
		row.Text = string.format("%d.  ---", i)
		row.Parent = gui
		boardRows[i] = row
	end
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------------------
-- Хаб: площадь, NPC, станции
-- ---------------------------------------------------------------------------
local function addPrompt(target: BasePart, id: string, action: string, object: string, hold: number?)
	local prompt = Instance.new("ProximityPrompt")
	Locale.setWorld(prompt, action, nil, "ActionText")
	Locale.setWorld(prompt, object, nil, "ObjectText")
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = target
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.4 then
			return
		end
		lastPrompt[player] = now
		for _, cb in ipairs(npcCallbacks) do
			task.spawn(cb, player, id)
		end
	end)
end

local function sign(
	target: BasePart,
	text: string,
	subtext: string?,
	color: Color3,
	height: number,
	w: number?,
	h: number?
)
	local gui = billboard(target, Vector3.new(0, height, 0), w or 240, h or 76)
	gui.MaxDistance = 60
	makeLabel(gui, text, UDim2.fromScale(1, if subtext then 0.56 else 0.9), Color3.fromRGB(255, 255, 255))
	if subtext then
		local sub = makeLabel(gui, subtext, UDim2.fromScale(1, 0.38), color)
		sub.Position = UDim2.fromScale(0, 0.6)
	end
end

local function buildNpc(
	parent: Instance,
	id: string,
	name: string,
	title: string,
	color: Color3,
	pos: Vector3,
	action: string
)
	local m = Instance.new("Model")
	m.Name = "Npc_" .. id
	local skin = Color3.fromRGB(245, 205, 165)
	mk(
		m,
		"Legs",
		Enum.PartType.Block,
		Vector3.new(1.8, 2.4, 1.2),
		CFrame.new(pos + Vector3.new(0, 1.2, 0)),
		Color3.fromRGB(60, 62, 80),
		nil,
		true
	)
	local torso = mk(
		m,
		"Torso",
		Enum.PartType.Block,
		Vector3.new(2.6, 2.8, 1.5),
		CFrame.new(pos + Vector3.new(0, 3.8, 0)),
		color,
		nil,
		true
	)
	mk(
		m,
		"ArmL",
		Enum.PartType.Block,
		Vector3.new(0.9, 2.6, 0.9),
		CFrame.new(pos + Vector3.new(-1.8, 3.8, 0)),
		color,
		nil,
		false
	)
	mk(
		m,
		"ArmR",
		Enum.PartType.Block,
		Vector3.new(0.9, 2.6, 0.9),
		CFrame.new(pos + Vector3.new(1.8, 3.8, 0)),
		color,
		nil,
		false
	)
	mk(
		m,
		"Head",
		Enum.PartType.Ball,
		Vector3.new(2, 2, 2),
		CFrame.new(pos + Vector3.new(0, 6, 0)),
		skin,
		nil,
		false
	)
	mk(
		m,
		"Hat",
		Enum.PartType.Block,
		Vector3.new(2.3, 0.8, 2.3),
		CFrame.new(pos + Vector3.new(0, 7.2, 0)),
		color:Lerp(Color3.new(0, 0, 0), 0.25),
		nil,
		false
	)
	mk(
		m,
		"EyeL",
		Enum.PartType.Ball,
		Vector3.new(0.3, 0.3, 0.3),
		CFrame.new(pos + Vector3.new(-0.4, 6.2, -0.9)),
		Color3.fromRGB(30, 30, 40),
		nil,
		false
	)
	mk(
		m,
		"EyeR",
		Enum.PartType.Ball,
		Vector3.new(0.3, 0.3, 0.3),
		CFrame.new(pos + Vector3.new(0.4, 6.2, -0.9)),
		Color3.fromRGB(30, 30, 40),
		nil,
		false
	)
	m.PrimaryPart = torso
	m:SetAttribute("NpcId", id)
	sign(torso, name, title, color, 5.5)
	addPrompt(torso, id, action, name, 0)
	m.Parent = parent
	stationPositions[id] = pos
end

-- v2.6: табличка с логотипом игры за фонтаном (над табло и яйцами хаба): две стойки, рамка, на ней BillboardGui с Logo
-- (картинка Config.ASSETS.LOGO или логотип из примитивов). SurfaceGui не используем — billboard виден и в веб-демо.
local function buildLogoSign(parent: Instance, base: Vector3)
	local m = Instance.new("Model")
	m.Name = "LogoSign"
	m.Parent = parent
	local wood = Color3.fromRGB(120, 78, 45)
	block(m, "PostL", Vector3.new(1.4, 22, 1.4), base + Vector3.new(-9.5, 11, 0), wood, Enum.Material.Wood)
	block(m, "PostR", Vector3.new(1.4, 22, 1.4), base + Vector3.new(9.5, 11, 0), wood, Enum.Material.Wood)
	local frame = block(
		m,
		"Frame",
		Vector3.new(19, 19, 0.8),
		base + Vector3.new(0, 19, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Neon
	)
	local board = block(
		m,
		"Board",
		Vector3.new(17.6, 17.6, 1),
		base + Vector3.new(0, 19, 0.1),
		Color3.fromRGB(30, 34, 70),
		Enum.Material.SmoothPlastic
	)
	local _ = frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "LogoGui"
	gui.Size = UDim2.fromScale(16, 16) -- в студах
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = board
	Logo.make({ Name = "Logo", Px = 256, Size = UDim2.fromScale(1, 1), Parent = gui })
	return m
end

local function buildHub(world: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world
	local size = ZoneData.HUB_RADIUS * 2 + 16
	local floorColor = Color3.fromRGB(196, 190, 176)
	block(
		hub,
		"Floor",
		Vector3.new(size, 2, size),
		Vector3.new(0, -1, 0),
		floorColor,
		Enum.Material.Cobblestone
	)
	local plaza = mk(
		hub,
		"Plaza",
		Enum.PartType.Cylinder,
		Vector3.new(0.3, 150, 150),
		CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(226, 218, 196),
		Enum.Material.Marble,
		false
	)
	plaza.Transparency = 0.1
	local half = size / 2
	for _, side in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local sx, sz = side[1], side[2]
		local wallSize = if sx == 0 then Vector3.new(size, 40, 1) else Vector3.new(1, 40, size)
		local wall =
			block(hub, "Wall", wallSize, Vector3.new(sx * half, 20, sz * half), Color3.new(1, 1, 1), nil)
		wall.Transparency = 1
		block(
			hub,
			"Rim",
			if sx == 0 then Vector3.new(size, 1.5, 1) else Vector3.new(1, 1.5, size),
			Vector3.new(sx * half, 0.75, sz * half),
			Color3.fromRGB(255, 214, 120),
			Enum.Material.Neon
		)
	end

	-- Фонтан в центре
	mk(
		hub,
		"FountainBase",
		Enum.PartType.Cylinder,
		Vector3.new(2.4, 26, 26),
		CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(170, 170, 180),
		Enum.Material.Marble,
		true
	)
	local water = mk(
		hub,
		"FountainWater",
		Enum.PartType.Cylinder,
		Vector3.new(0.5, 22, 22),
		CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(90, 190, 255),
		Enum.Material.Neon,
		false
	)
	water.Transparency = 0.35
	mk(
		hub,
		"FountainSpire",
		Enum.PartType.Cylinder,
		Vector3.new(7, 3, 3),
		CFrame.new(0, 5.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(190, 190, 205),
		Enum.Material.Marble,
		true
	)
	local orb = mk(
		hub,
		"FountainOrb",
		Enum.PartType.Ball,
		Vector3.new(3, 3, 3),
		CFrame.new(0, 10, 0),
		Color3.fromRGB(255, 220, 120),
		Enum.Material.Neon,
		false
	)
	-- ниже и компактнее: с точки спавна вывеска не упирается в верхнюю панель HUD
	sign(orb, "world.hub", "world.hub_sub", Color3.fromRGB(255, 214, 90), 1.2, 210, 60)

	-- Точка появления
	local sp = Instance.new("SpawnLocation")
	sp.Name = "SpawnLocation"
	sp.Anchored = true
	sp.Neutral = true
	sp.Size = Vector3.new(14, 1, 14)
	sp.Position = Vector3.new(0, 0.5, 26)
	sp.Color = Color3.fromRGB(255, 214, 120)
	sp.Material = Enum.Material.Neon
	sp.Duration = 0
	sp.Parent = hub
	hubSpawn = CFrame.lookAt(Vector3.new(0, 3.5, 26), Vector3.new(0, 3.5, 0))

	-- Деревья и фонари по кольцу
	local rng = Random.new(77)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = hub
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2
		local radius = rng:NextNumber(100, 106)
		local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if i % 2 == 0 then
			decorTree(decor, pos, rng, Color3.fromRGB(90, 175, 80), Color3.fromRGB(120, 80, 50))
		else
			block(
				decor,
				"LampPost",
				Vector3.new(0.8, 9, 0.8),
				pos + Vector3.new(0, 4.5, 0),
				Color3.fromRGB(60, 60, 70),
				Enum.Material.Metal
			)
			mk(
				decor,
				"Lamp",
				Enum.PartType.Ball,
				Vector3.new(2, 2, 2),
				CFrame.new(pos + Vector3.new(0, 9.5, 0)),
				Color3.fromRGB(255, 235, 170),
				Enum.Material.Neon,
				false
			)
		end
	end

	-- NPC квестов
	for _, npcId in ipairs(QuestData.NpcOrder) do
		local npc = QuestData.Npcs[npcId]
		buildNpc(hub, npc.Id, npc.Name, npc.Title, npc.Color, npc.Pos, "prompt.talk")
	end
	-- Торговец Том
	buildNpc(
		hub,
		"tom",
		"Trader Tom",
		"world.tom_title",
		Color3.fromRGB(240, 170, 60),
		Vector3.new(44, 0, -22),
		"prompt.trade"
	)

	-- Верстак
	local benchPos = Vector3.new(-62, 0, 8)
	local top = block(
		hub,
		"BenchTop",
		Vector3.new(10, 1, 5),
		benchPos + Vector3.new(0, 3.5, 0),
		Color3.fromRGB(150, 105, 62),
		Enum.Material.Wood
	)
	for _, dx in ipairs({ -4, 4 }) do
		block(
			hub,
			"BenchLeg",
			Vector3.new(1, 3.5, 4),
			benchPos + Vector3.new(dx, 1.75, 0),
			Color3.fromRGB(110, 78, 48),
			Enum.Material.Wood
		)
	end
	block(
		hub,
		"Anvil",
		Vector3.new(2.5, 1.6, 1.4),
		benchPos + Vector3.new(-2.5, 4.8, 0),
		Color3.fromRGB(70, 72, 80),
		Enum.Material.Metal
	)
	mk(
		hub,
		"Cauldron",
		Enum.PartType.Ball,
		Vector3.new(2.6, 2.2, 2.6),
		CFrame.new(benchPos + Vector3.new(2.5, 5, 0)),
		Color3.fromRGB(60, 60, 70),
		Enum.Material.Metal,
		false
	)
	sign(top, "world.workbench", "world.workbench_sub", Color3.fromRGB(255, 200, 120), 6)
	addPrompt(top, "craft", "prompt.craft", "world.workbench", 0)
	stationPositions.craft = benchPos

	-- Лавка с ротацией
	local stallPos = Vector3.new(62, 0, 8)
	local counter = block(
		hub,
		"StallCounter",
		Vector3.new(11, 3, 4),
		stallPos + Vector3.new(0, 1.5, 0),
		Color3.fromRGB(190, 70, 80),
		Enum.Material.Wood
	)
	for _, dx in ipairs({ -5, 5 }) do
		block(
			hub,
			"StallPole",
			Vector3.new(0.8, 9, 0.8),
			stallPos + Vector3.new(dx, 4.5, 2),
			Color3.fromRGB(240, 235, 225),
			Enum.Material.Wood
		)
	end
	block(
		hub,
		"StallRoof",
		Vector3.new(12.5, 0.8, 6),
		stallPos + Vector3.new(0, 9, 1),
		Color3.fromRGB(240, 90, 90),
		Enum.Material.Fabric
	)
	sign(counter, "world.market", "world.market_sub", Color3.fromRGB(255, 200, 120), 8)
	addPrompt(counter, "market", "prompt.browse", "world.market", 0)
	stationPositions.market = stallPos

	-- Алтарь ребёрта и талантов
	local altarPos = Vector3.new(-70, 0, -50)
	mk(
		hub,
		"AltarStep1",
		Enum.PartType.Cylinder,
		Vector3.new(1.2, 16, 16),
		CFrame.new(altarPos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(110, 90, 160),
		Enum.Material.Marble,
		true
	)
	mk(
		hub,
		"AltarStep2",
		Enum.PartType.Cylinder,
		Vector3.new(1.2, 10, 10),
		CFrame.new(altarPos + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(140, 110, 200),
		Enum.Material.Marble,
		true
	)
	local altarOrb = mk(
		hub,
		"AltarOrb",
		Enum.PartType.Ball,
		Vector3.new(4, 4, 4),
		CFrame.new(altarPos + Vector3.new(0, 6, 0)),
		Color3.fromRGB(190, 120, 255),
		Enum.Material.Neon,
		false
	)
	sign(altarOrb, "world.altar", "world.altar_sub", Color3.fromRGB(210, 160, 255), 4)
	addPrompt(altarOrb, "altar", "prompt.pray", "world.altar", 0)
	stationPositions.altar = altarPos

	-- Портал в миры
	local portalPos = Vector3.new(0, 0, 80)
	for _, dx in ipairs({ -8, 8 }) do
		block(
			hub,
			"PortalPillar",
			Vector3.new(2.4, 18, 2.4),
			portalPos + Vector3.new(dx, 9, 0),
			Color3.fromRGB(80, 80, 110),
			Enum.Material.Marble
		)
	end
	local ring = mk(
		hub,
		"PortalRing",
		Enum.PartType.Cylinder,
		Vector3.new(1, 18, 18),
		CFrame.new(portalPos + Vector3.new(0, 10, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(120, 200, 255),
		Enum.Material.Neon,
		false
	)
	ring.Transparency = 0.25
	sign(ring, "world.portal", "world.portal_sub", Color3.fromRGB(150, 220, 255), 11)
	local portalPad = mk(
		hub,
		"PortalPad",
		Enum.PartType.Cylinder,
		Vector3.new(0.6, 10, 10),
		CFrame.new(portalPos + Vector3.new(0, 0.3, -4)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(120, 200, 255),
		Enum.Material.Neon,
		false
	)
	addPrompt(portalPad, "portal", "prompt.travel", "world.portal", 0)
	stationPositions.portal = portalPos

	-- v2.5: станции разделов, убранных с экрана (лист «Ещё» дублирует их кнопками)
	-- Сундук ежедневной награды — слева от фонтана
	local chestPos = Vector3.new(-26, 0, 8)
	block(
		hub,
		"ChestBase",
		Vector3.new(5, 2.6, 3.4),
		chestPos + Vector3.new(0, 1.3, 0),
		Color3.fromRGB(150, 90, 45),
		Enum.Material.Wood
	)
	local lid = block(
		hub,
		"ChestLid",
		Vector3.new(5.2, 1.2, 3.6),
		chestPos + Vector3.new(0, 3.2, 0),
		Color3.fromRGB(175, 105, 55),
		Enum.Material.Wood
	)
	for _, dx in ipairs({ -2.2, 0, 2.2 }) do
		block(
			hub,
			"ChestBand",
			Vector3.new(0.4, 3.9, 3.7),
			chestPos + Vector3.new(dx, 1.95, 0),
			Color3.fromRGB(255, 200, 60),
			Enum.Material.Metal
		)
	end
	mk(
		hub,
		"ChestGlow",
		Enum.PartType.Ball,
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(chestPos + Vector3.new(0, 2.4, -1.9)),
		Color3.fromRGB(255, 230, 120),
		Enum.Material.Neon,
		false
	)
	sign(lid, "world.daily_chest", "world.daily_chest_sub", Color3.fromRGB(255, 210, 90), 4.5)
	addPrompt(lid, "daily", "prompt.claim", "world.daily_chest", 0)
	stationPositions.daily = chestPos

	-- Мастерская улучшений — справа от фонтана: станок с шестернёй
	local shopPos = Vector3.new(26, 0, 8)
	local bench = block(
		hub,
		"WorkshopBase",
		Vector3.new(6, 3, 4),
		shopPos + Vector3.new(0, 1.5, 0),
		Color3.fromRGB(60, 110, 200),
		Enum.Material.Metal
	)
	mk(
		hub,
		"WorkshopGear",
		Enum.PartType.Cylinder,
		Vector3.new(0.8, 4.6, 4.6),
		CFrame.new(shopPos + Vector3.new(0, 5.6, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.Metal,
		false
	)
	mk(
		hub,
		"WorkshopCore",
		Enum.PartType.Ball,
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(shopPos + Vector3.new(0, 5.6, -0.5)),
		Color3.fromRGB(120, 220, 255),
		Enum.Material.Neon,
		false
	)
	block(
		hub,
		"WorkshopArrow",
		Vector3.new(0.8, 2.2, 0.6),
		shopPos + Vector3.new(0, 3.3, -2),
		Color3.fromRGB(120, 255, 140),
		Enum.Material.Neon
	)
	sign(bench, "world.upgrades", "world.upgrades_sub", Color3.fromRGB(140, 200, 255), 8)
	addPrompt(bench, "upgrades", "prompt.upgrade", "world.upgrades", 0)
	stationPositions.upgrades = shopPos

	-- Святилище перерождения — напротив алтаря талантов
	local shrinePos = Vector3.new(70, 0, -50)
	mk(
		hub,
		"ShrineStep",
		Enum.PartType.Cylinder,
		Vector3.new(1.2, 14, 14),
		CFrame.new(shrinePos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(90, 80, 130),
		Enum.Material.Marble,
		true
	)
	local obelisk = block(
		hub,
		"ShrineObelisk",
		Vector3.new(3, 10, 3),
		shrinePos + Vector3.new(0, 6.2, 0),
		Color3.fromRGB(60, 50, 90),
		Enum.Material.Marble
	)
	local halo = mk(
		hub,
		"ShrineRing",
		Enum.PartType.Cylinder,
		Vector3.new(0.5, 8, 8),
		CFrame.new(shrinePos + Vector3.new(0, 12.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(200, 120, 255),
		Enum.Material.Neon,
		false
	)
	halo.Transparency = 0.3
	sign(obelisk, "world.rebirth", "world.rebirth_sub", Color3.fromRGB(210, 160, 255), 9)
	addPrompt(obelisk, "rebirth", "prompt.rebirth", "world.rebirth", 0)
	stationPositions.rebirth = shrinePos

	-- Яйца хаба и табло
	local hubEggs = {}
	for _, egg in ipairs(PetData.Eggs) do
		if egg.Zone == ZoneData.HUB then
			table.insert(hubEggs, egg)
		end
	end
	for k, egg in ipairs(hubEggs) do
		buildEgg(hub, egg, Vector3.new((k - (#hubEggs + 1) / 2) * 44, 0, -84))
	end
	buildLogoSign(hub, Vector3.new(0, 0, -50))
	local boardModel = buildBoard(hub, Vector3.new(0, 0, -98))
	local boardPart = boardModel and boardModel:FindFirstChild("Board")
	if boardPart and boardPart:IsA("BasePart") then
		addPrompt(boardPart, "board", "prompt.view", "world.boards", 0) -- v2.5: окно рейтингов
	end
	stationPositions.board = Vector3.new(0, 0, -98)
end

-- ---------------------------------------------------------------------------
-- Публичный API
-- ---------------------------------------------------------------------------
function WorldBuilder.build()
	if built then
		return
	end
	built = true

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(110, 110, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 135, 150)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmo = Instance.new("Atmosphere")
		atmo.Density = 0.25
		atmo.Haze = 1
		atmo.Color = Color3.fromRGB(200, 220, 245)
		atmo.Parent = Lighting
	end

	local old = Workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace

	local size = ZoneData.PLATFORM_SIZE
	for index, zone in ipairs(ZoneData.List) do
		local folder = Instance.new("Folder")
		folder.Name = zone.Id
		folder.Parent = world
		local center = zone.Position
		local rng = Random.new(1000 + index)

		-- пол
		block(
			folder,
			"Floor",
			Vector3.new(size, 2, size),
			center + Vector3.new(0, -1, 0),
			zone.Floor,
			zone.Material
		)
		-- декоративный центр
		local plaza = mk(
			folder,
			"Plaza",
			Enum.PartType.Cylinder,
			Vector3.new(0.3, 70, 70),
			CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			zone.Accent,
			Enum.Material.SmoothPlastic,
			false
		)
		plaza.Transparency = 0.5
		-- видимый бортик и невидимые стены
		local half = size / 2
		for _, side in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
			local sx, sz = side[1], side[2]
			local along = if sx == 0 then Vector3.new(size, 1.5, 1) else Vector3.new(1, 1.5, size)
			block(
				folder,
				"Rim",
				along,
				center + Vector3.new(sx * half, 0.75, sz * half),
				zone.Accent,
				Enum.Material.Neon
			)
			local wallSize = if sx == 0 then Vector3.new(size, 40, 1) else Vector3.new(1, 40, size)
			local wall = block(
				folder,
				"Wall",
				wallSize,
				center + Vector3.new(sx * half, 20, sz * half),
				Color3.new(1, 1, 1),
				nil
			)
			wall.Transparency = 1
		end

		-- декор по кольцу
		local decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = folder
		for i = 1, 22 do
			local angle = (i / 22) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local radius = rng:NextNumber(52, 82)
			local pos = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			if zone.Decor == "Trees" then
				local leaf = if zone.Id == "Meadow"
					then Color3.fromRGB(80, 170, 70)
					else Color3.fromRGB(40, 110, 60)
				decorTree(decor, pos, rng, leaf, Color3.fromRGB(120, 80, 50))
			elseif zone.Decor == "Cacti" then
				decorCactus(decor, pos, rng, Color3.fromRGB(70, 150, 80))
			elseif zone.Decor == "Crystals" then
				decorCrystal(decor, pos, rng, zone.Accent)
			else
				decorRock(decor, pos, rng, Color3.fromRGB(60, 50, 52), zone.Accent)
			end
		end

		-- точка появления
		local spawnPos = center + Vector3.new(0, 0, 38)
		zoneSpawns[zone.Id] =
			CFrame.lookAt(spawnPos + Vector3.new(0, 3.5, 0), center + Vector3.new(0, 3.5, 0))
		local pad = mk(
			folder,
			"SpawnPad",
			Enum.PartType.Cylinder,
			Vector3.new(0.6, 14, 14),
			CFrame.new(spawnPos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			zone.Accent,
			Enum.Material.Neon,
			false
		)
		addPrompt(pad, "hubReturn", "prompt.return", "prompt.to_hub", 0)

		-- вывеска
		local signPost = block(
			folder,
			"SignPost",
			Vector3.new(1, 12, 1),
			center + Vector3.new(0, 6, 62),
			Color3.fromRGB(110, 80, 60),
			Enum.Material.Wood
		)
		local gui = billboard(signPost, Vector3.new(0, 8, 0), 320, 90)
		gui.MaxDistance = 90
		makeLabel(gui, zone.Name, UDim2.fromScale(1, 0.58), Color3.fromRGB(255, 255, 255))
		local mult =
			makeLabel(gui, "world.zone_mult", UDim2.fromScale(1, 0.38), zone.Accent, { n = zone.Multiplier })
		mult.Position = UDim2.fromScale(0, 0.6)

		-- яйца этой зоны
		local eggsHere = {}
		for _, egg in ipairs(PetData.Eggs) do
			if egg.Zone == zone.Id then
				table.insert(eggsHere, egg)
			end
		end
		for k, egg in ipairs(eggsHere) do
			local x = (k - (#eggsHere + 1) / 2) * 32
			buildEgg(folder, egg, center + Vector3.new(x, 0, -14))
		end
	end
	buildHub(world)
end

function WorldBuilder.getZoneSpawn(zoneId: string): CFrame
	if zoneId == ZoneData.HUB then
		return hubSpawn
	end
	return zoneSpawns[zoneId] or zoneSpawns[ZoneData.DEFAULT] or CFrame.new(0, 5, 0)
end

function WorldBuilder.getEggPosition(eggId: string): Vector3?
	return eggPositions[eggId]
end

-- Колбэк на ProximityPrompt NPC и станций: (player, id). id: mira|bruno|pip|tom|craft|market|altar|portal|hubReturn|daily|upgrades|rebirth|board
function WorldBuilder.onNpcPrompt(cb: (Player, string) -> ())
	table.insert(npcCallbacks, cb)
end

function WorldBuilder.getStationPosition(id: string): Vector3?
	return stationPositions[id]
end

function WorldBuilder.onEggPrompt(cb: (Player, string) -> ())
	table.insert(eggCallbacks, cb)
end

-- Обновление табло: entries = { { Name, Value } } (до 10 строк) или nil + статус
function WorldBuilder.setBoard(entries: { { Name: string, Value: number } }?, status: string?)
	if boardStatus and status then
		Locale.setWorld(boardStatus, status)
	end
	for i, row in ipairs(boardRows) do
		local e = entries and entries[i]
		if e then
			row.Text = string.format("%d.  %s  —  %s", i, e.Name, Util.formatNumber(e.Value))
		else
			row.Text = string.format("%d.  ---", i)
		end
	end
end

function WorldBuilder.clearPlayer(player: Player)
	lastPrompt[player] = nil
end

return WorldBuilder
