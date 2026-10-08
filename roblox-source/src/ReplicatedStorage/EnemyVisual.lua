--!strict
--[[
	EnemyVisual: клиентская «рисовка» врагов из примитивов (без внешних ассетов).
	Сервер держит у врага только невидимый хитбокс Body (Workspace.Enemies), а клиент строит
	по EnemyId многосоставную модель и анимирует её (EnemyVisuals.client.lua).

	Координаты рецептов — в долях def.Size (s): начало — центр у земли, перед — -Z.
	Каждая часть принадлежит группе (body, head, leg1..6, armL/R, wingL/R, tail, orbit, flame, aura);
	группа вращается вокруг своей опоры (pivot). Все части Anchored, без коллизий/запросов/касаний.

	build(def, special) -> Rig:
	  Model, Parts = { {Part, Group, Rel, Color, Size, Trans} }, Pivots, Arch,
	  Legs = { {G, Ph} }, Arms, Wings, Height, Anchor (точка для полоски HP).
]]
local EnemyVisual = {}

export type RigPart = {
	Part: BasePart,
	Group: string,
	Rel: CFrame,
	Color: Color3,
	Size: Vector3,
	Trans: number,
}

export type Rig = {
	Model: Model,
	Parts: { RigPart },
	Pivots: { [string]: Vector3 },
	Arch: string,
	Legs: { { G: string, Ph: number } },
	Arms: { string },
	Wings: { string },
	Height: number,
	Scale: number,
	Boss: boolean,
	Accent: Color3,
	Anchor: BasePart,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(22, 22, 28)
local GOLD = Color3.fromRGB(255, 205, 60)

-- Акцент биома (неон/детали)
EnemyVisual.ACCENT = {
	Meadow = Color3.fromRGB(255, 120, 170),
	Forest = Color3.fromRGB(130, 230, 90),
	Desert = Color3.fromRGB(255, 170, 50),
	Frost = Color3.fromRGB(140, 230, 255),
	Volcano = Color3.fromRGB(255, 110, 30),
	Hub = Color3.fromRGB(255, 80, 60),
	Any = Color3.fromRGB(160, 130, 255),
}

-- Архетип каждого врага (силуэт)
EnemyVisual.ARCH = {
	slimeling = "slime",
	moonling = "slime",
	meadow_king = "slime",
	boarlet = "quad",
	icewolf = "quad",
	thornback = "quad",
	buzzfly = "flyer",
	ashbat = "flyer",
	wisp = "wisp",
	sandwraith = "wraith",
	scorpling = "bug",
	dunebeetle = "bug",
	snowmite = "bug",
	magmacrab = "bug",
	frostimp = "imp",
	cinderling = "imp",
	mossgolem = "golem",
	elder_treant = "golem",
	sand_titan = "golem",
	glacier_lord = "golem",
	inferno_tyrant = "golem",
	stone_colossus = "golem",
}

local function lum(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

type Builder = {
	s: number,
	model: Model,
	parts: { RigPart },
	pivots: { [string]: Vector3 },
	add: (
		self: Builder,
		group: string,
		shape: string,
		size: Vector3,
		pos: Vector3,
		color: Color3,
		mat: Enum.Material?,
		rot: CFrame?,
		trans: number?
	) -> BasePart,
}

local function newBuilder(model: Model, s: number): Builder
	local b = { s = s, model = model, parts = {}, pivots = {} } :: any
	function b.add(
		self: Builder,
		group: string,
		shape: string,
		size: Vector3,
		pos: Vector3,
		color: Color3,
		mat: Enum.Material?,
		rot: CFrame?,
		trans: number?
	): BasePart
		local p: BasePart
		if shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = if shape == "Ball"
				then Enum.PartType.Ball
				elseif shape == "Cyl" then Enum.PartType.Cylinder
				else Enum.PartType.Block
			p = part
		end
		local sz = size * self.s
		p.Name = group
		p.Size = sz
		local cf = CFrame.new(pos * self.s)
		if rot then
			cf = cf * rot
		end
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Transparency = trans or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Parent = self.model
		table.insert(self.parts, {
			Part = p,
			Group = group,
			Rel = cf,
			Color = color,
			Size = sz,
			Trans = trans or 0,
		})
		return p
	end
	return b :: Builder
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local rad = math.rad
local ang = CFrame.Angles
local VERT = ang(0, 0, rad(90)) -- цилиндр осью вверх
local ALONG_Z = ang(0, rad(90), 0) -- цилиндр осью вперёд

-- Глаза: белок + радужка + зрачок/блик (3 части на глаз)
local function eyes(b: Builder, group: string, y: number, z: number, spread: number, d: number, iris: Color3)
	local bright = lum(iris) >= 0.3
	for i = -1, 1, 2 do
		local x = i * spread
		b:add(group, "Ball", v(d, d, d), v(x, y, z), WHITE)
		if bright then
			b:add(
				group,
				"Ball",
				v(d * 0.62, d * 0.62, d * 0.62),
				v(x, y, z - d * 0.26),
				iris,
				Enum.Material.Neon
			)
			b:add(group, "Ball", v(d * 0.32, d * 0.32, d * 0.32), v(x, y, z - d * 0.42), BLACK)
		else
			b:add(
				group,
				"Ball",
				v(d * 0.64, d * 0.64, d * 0.64),
				v(x, y - d * 0.04, z - d * 0.26),
				iris:Lerp(BLACK, 0.4)
			)
			b:add(
				group,
				"Ball",
				v(d * 0.2, d * 0.2, d * 0.2),
				v(x + d * 0.12, y + d * 0.12, z - d * 0.5),
				WHITE,
				Enum.Material.Neon
			)
		end
	end
end

local function fangs(
	b: Builder,
	group: string,
	y: number,
	z: number,
	spread: number,
	h: number,
	color: Color3?
)
	for i = -1, 1, 2 do
		b:add(
			group,
			"Wedge",
			v(h * 0.4, h, h * 0.4),
			v(i * spread, y - h / 2, z),
			color or WHITE,
			nil,
			ang(rad(180), 0, 0)
		)
	end
end

local function crown(b: Builder, group: string, top: number, z: number, w: number)
	b:add(group, "Cyl", v(w * 0.28, w, w), v(0, top + w * 0.12, z), GOLD, Enum.Material.Metal, VERT)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		b:add(
			group,
			"Wedge",
			v(w * 0.16, w * 0.34, w * 0.16),
			v(math.cos(a) * w * 0.42, top + w * 0.42, z + math.sin(a) * w * 0.42),
			GOLD,
			Enum.Material.Metal,
			ang(0, -a + rad(90), 0)
		)
	end
	b:add(
		group,
		"Ball",
		v(w * 0.22, w * 0.22, w * 0.22),
		v(0, top + w * 0.16, z - w * 0.48),
		Color3.fromRGB(255, 60, 90),
		Enum.Material.Neon
	)
end

-- ---------------------------------------------------------------------------
-- Архетипы
-- ---------------------------------------------------------------------------
type Ctx = {
	id: string,
	color: Color3,
	belly: Color3,
	dark: Color3,
	eye: Color3,
	accent: Color3,
	boss: boolean,
}

local R = {}

function R.slime(b: Builder, c: Ctx, rig: any)
	local moon = c.id == "moonling"
	local king = c.id == "meadow_king"
	if moon then
		b:add("body", "Ball", v(1, 1, 1), v(0, 0.5, 0), c.color, Enum.Material.Glass, nil, 0.25)
		b:add("body", "Ball", v(0.5, 0.5, 0.5), v(0, 0.5, 0.05), c.accent, Enum.Material.Neon)
	else
		b:add("body", "Ball", v(1, 1, 1), v(0, 0.5, 0), c.color)
		b:add("body", "Ball", v(0.68, 0.68, 0.68), v(0, 0.4, -0.2), c.belly)
	end
	b:add("body", "Ball", v(0.32, 0.32, 0.32), v(0.42, 0.14, 0.12), c.color)
	b:add("body", "Ball", v(0.26, 0.26, 0.26), v(-0.4, 0.12, 0.2), c.color)
	b:add(
		"body",
		"Ball",
		v(0.22, 0.22, 0.22),
		v(0.18, 0.86, -0.18),
		c.color:Lerp(WHITE, 0.6),
		Enum.Material.Neon,
		nil,
		0.35
	)
	eyes(b, "body", 0.62, -0.38, 0.19, 0.25, c.eye)
	b:add("body", "Block", v(0.3, 0.07, 0.05), v(0, 0.38, -0.49), c.dark)
	if king then
		fangs(b, "body", 0.36, -0.5, 0.1, 0.1)
	end
	rig.Top = 1.0
	rig.CrownZ = 0
end

function R.quad(b: Builder, c: Ctx, rig: any)
	local wolf = c.id == "icewolf"
	local boar = c.id == "boarlet"
	local thorn = c.id == "thornback"
	b:add("body", "Block", v(0.72, 0.5, 1.0), v(0, 0.58, 0), c.color)
	b:add("body", "Block", v(0.62, 0.14, 0.82), v(0, 0.33, 0), c.belly)
	-- голова
	b.pivots.head = v(0, 0.7, -0.45) * b.s
	b:add("head", "Block", v(0.56, 0.5, 0.48), v(0, 0.74, -0.66), c.color)
	b:add(
		"head",
		"Block",
		v(0.34, 0.24, if wolf then 0.34 else 0.22),
		v(0, 0.62, if wolf then -1.0 else -0.94),
		c.belly
	)
	b:add("head", "Block", v(0.2, 0.08, 0.04), v(0, 0.66, if wolf then -1.18 else -1.06), BLACK)
	eyes(b, "head", 0.84, -0.9, 0.15, 0.16, c.eye)
	for i = -1, 1, 2 do
		b:add(
			"head",
			"Wedge",
			v(0.07, if wolf then 0.3 else 0.2, 0.16),
			v(i * 0.19, if wolf then 1.12 else 1.06, -0.6),
			if wolf then c.accent else c.dark
		)
	end
	if boar then
		for i = -1, 1, 2 do
			b:add(
				"head",
				"Block",
				v(0.06, 0.2, 0.06),
				v(i * 0.14, 0.58, -1.04),
				WHITE,
				nil,
				ang(rad(-20), 0, rad(i * 15))
			)
		end
		b:add("body", "Block", v(0.14, 0.14, 0.86), v(0, 0.86, 0.02), c.dark)
	elseif wolf then
		fangs(b, "head", 0.52, -1.1, 0.08, 0.1)
		b:add("body", "Block", v(0.66, 0.44, 0.24), v(0, 0.66, -0.3), c.belly)
	elseif thorn then
		for k = 0, 3 do
			b:add(
				"body",
				"Wedge",
				v(0.12, 0.32, 0.22),
				v(0, 0.98, -0.3 + k * 0.24),
				c.eye,
				Enum.Material.Neon
			)
		end
	end
	-- ноги: пары по диагонали в фазе
	local legs =
		{ { -0.24, -0.34, 0 }, { 0.24, -0.34, math.pi }, { -0.24, 0.34, math.pi }, { 0.24, 0.34, 0 } }
	rig.Legs = {}
	for i, l in ipairs(legs) do
		local g = "leg" .. i
		b.pivots[g] = v(l[1], 0.4, l[2]) * b.s
		b:add(g, "Block", v(0.18, 0.38, 0.18), v(l[1], 0.19, l[2]), c.dark)
		table.insert(rig.Legs, { G = g, Ph = l[3] })
	end
	-- хвост
	b.pivots.tail = v(0, 0.72, 0.5) * b.s
	b:add(
		"tail",
		"Block",
		v(if wolf then 0.18 else 0.08, if wolf then 0.18 else 0.08, 0.38),
		v(0, 0.8, 0.66),
		if wolf then c.belly else c.dark,
		nil,
		ang(rad(25), 0, 0)
	)
	if thorn then
		b:add("tail", "Wedge", v(0.08, 0.2, 0.14), v(0, 0.95, 0.8), c.eye, Enum.Material.Neon)
	end
	rig.Top = 1.1
	rig.CrownZ = -0.66
end

function R.flyer(b: Builder, c: Ctx, rig: any)
	local bat = c.id == "ashbat"
	b:add("body", "Ball", v(0.72, 0.72, 0.72), v(0, 0.95, 0.05), c.color)
	b.pivots.head = v(0, 1.0, -0.3) * b.s
	b:add("head", "Ball", v(0.5, 0.5, 0.5), v(0, 1.05, -0.4), if bat then c.color else c.dark)
	eyes(b, "head", 1.1, -0.6, 0.12, 0.17, c.eye)
	if bat then
		for i = -1, 1, 2 do
			b:add("head", "Wedge", v(0.08, 0.26, 0.16), v(i * 0.15, 1.36, -0.38), c.dark)
		end
		fangs(b, "head", 0.95, -0.62, 0.06, 0.08)
		b:add("body", "Ball", v(0.4, 0.4, 0.4), v(0, 0.86, -0.12), c.accent, Enum.Material.Neon, nil, 0.2)
	else
		for k = 0, 1 do
			b:add("body", "Cyl", v(0.1, 0.74, 0.74), v(0, 0.95, 0.0 + k * 0.2), c.dark, nil, ALONG_Z)
		end
		b:add("body", "Wedge", v(0.1, 0.12, 0.24), v(0, 0.9, 0.48), c.dark, nil, ang(rad(-90), 0, 0))
		for i = -1, 1, 2 do
			b:add(
				"head",
				"Block",
				v(0.03, 0.3, 0.03),
				v(i * 0.1, 1.38, -0.46),
				c.dark,
				nil,
				ang(rad(-20), 0, rad(i * -18))
			)
		end
	end
	rig.Wings = {}
	for i = -1, 1, 2 do
		local g = if i < 0 then "wingL" else "wingR"
		b.pivots[g] = v(i * 0.26, 1.1, 0) * b.s
		if bat then
			b:add(g, "Block", v(0.62, 0.04, 0.42), v(i * 0.56, 1.12, 0.02), c.dark)
			b:add(
				g,
				"Wedge",
				v(0.04, 0.3, 0.42),
				v(i * 0.98, 1.12, 0.02),
				c.dark,
				nil,
				ang(0, 0, rad(i * 90))
			)
		else
			b:add(
				g,
				"Block",
				v(0.6, 0.03, 0.34),
				v(i * 0.56, 1.14, 0.08),
				WHITE,
				Enum.Material.Glass,
				ang(0, rad(i * -12), 0),
				0.35
			)
		end
		table.insert(rig.Wings, g)
	end
	rig.Hover = true
	rig.Top = 1.4
	rig.CrownZ = -0.4
end

function R.wisp(b: Builder, c: Ctx, rig: any)
	b:add("body", "Ball", v(0.86, 0.86, 0.86), v(0, 1.1, 0), c.color, Enum.Material.Glass, nil, 0.45)
	b:add("body", "Ball", v(0.56, 0.56, 0.56), v(0, 1.1, 0), c.color, Enum.Material.Neon)
	eyes(b, "body", 1.16, -0.4, 0.13, 0.17, c.eye)
	b.pivots.tail = v(0, 0.85, 0.1) * b.s
	b:add("tail", "Ball", v(0.44, 0.44, 0.44), v(0, 0.76, 0.16), c.color, Enum.Material.Neon, nil, 0.3)
	b:add("tail", "Ball", v(0.3, 0.3, 0.3), v(0, 0.5, 0.3), c.color, Enum.Material.Neon, nil, 0.45)
	b:add("tail", "Ball", v(0.18, 0.18, 0.18), v(0, 0.3, 0.42), c.accent, Enum.Material.Neon, nil, 0.55)
	b.pivots.orbit = v(0, 1.1, 0) * b.s
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		b:add(
			"orbit",
			"Ball",
			v(0.14, 0.14, 0.14),
			v(math.cos(a) * 0.72, 1.1, math.sin(a) * 0.72),
			c.accent,
			Enum.Material.Neon
		)
	end
	rig.Hover = true
	rig.Top = 1.55
	rig.CrownZ = 0
end

function R.wraith(b: Builder, c: Ctx, rig: any)
	b:add("body", "Block", v(0.66, 0.9, 0.5), v(0, 0.9, 0), c.color)
	b:add("body", "Wedge", v(0.66, 0.5, 0.3), v(0, 0.32, 0.12), c.color, nil, ang(rad(180), 0, 0))
	b:add("body", "Block", v(0.7, 0.1, 0.54), v(0, 1.0, 0), c.accent)
	b.pivots.head = v(0, 1.35, 0) * b.s
	b:add("head", "Ball", v(0.64, 0.64, 0.64), v(0, 1.6, 0.02), c.dark)
	b:add("head", "Block", v(0.38, 0.3, 0.06), v(0, 1.56, -0.28), BLACK)
	for i = -1, 1, 2 do
		b:add("head", "Ball", v(0.12, 0.12, 0.12), v(i * 0.09, 1.6, -0.32), c.eye, Enum.Material.Neon)
		b:add("head", "Ball", v(0.05, 0.05, 0.05), v(i * 0.09, 1.6, -0.38), WHITE, Enum.Material.Neon)
	end
	rig.Arms = {}
	for i = -1, 1, 2 do
		local g = if i < 0 then "armL" else "armR"
		b.pivots[g] = v(i * 0.38, 1.25, 0) * b.s
		b:add(g, "Block", v(0.18, 0.6, 0.2), v(i * 0.44, 0.98, -0.06), c.color, nil, ang(rad(-20), 0, 0))
		b:add(g, "Ball", v(0.14, 0.14, 0.14), v(i * 0.44, 0.66, -0.18), c.dark)
		table.insert(rig.Arms, g)
	end
	b.pivots.orbit = v(0, 0.6, 0) * b.s
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		b:add(
			"orbit",
			"Block",
			v(0.1, 0.1, 0.1),
			v(math.cos(a) * 0.6, 0.5 + k * 0.15, math.sin(a) * 0.6),
			c.accent,
			Enum.Material.Neon
		)
	end
	rig.Hover = true
	rig.Top = 1.95
	rig.CrownZ = 0
end

function R.bug(b: Builder, c: Ctx, rig: any)
	local scorp = c.id == "scorpling"
	local beetle = c.id == "dunebeetle"
	local mite = c.id == "snowmite"
	local crab = c.id == "magmacrab"
	if beetle or mite then
		b:add("body", "Ball", v(0.86, 0.86, 0.86), v(0, 0.52, 0.05), if mite then c.color else c.dark)
		if beetle then
			b:add("body", "Block", v(0.04, 0.5, 0.82), v(0, 0.66, 0.05), BLACK)
			b:add("body", "Ball", v(0.5, 0.5, 0.5), v(0.16, 0.8, 0.1), c.color, nil, nil, 0.1)
		else
			b:add("body", "Ball", v(0.4, 0.4, 0.4), v(0.22, 0.78, 0.2), c.belly)
			b:add("body", "Ball", v(0.34, 0.34, 0.34), v(-0.24, 0.74, 0.18), c.belly)
		end
	elseif crab then
		b:add("body", "Block", v(1.0, 0.44, 0.72), v(0, 0.52, 0), c.color)
		b:add(
			"body",
			"Block",
			v(0.6, 0.06, 0.06),
			v(0, 0.75, -0.1),
			c.accent,
			Enum.Material.Neon,
			ang(0, rad(20), 0)
		)
		b:add("body", "Block", v(0.06, 0.06, 0.5), v(0.2, 0.75, 0.05), c.accent, Enum.Material.Neon)
	else
		b:add("body", "Block", v(0.66, 0.34, 0.86), v(0, 0.42, 0), c.color)
		b:add("body", "Block", v(0.54, 0.08, 0.7), v(0, 0.62, 0.02), c.dark)
	end
	-- голова
	b.pivots.head = v(0, 0.45, -0.4) * b.s
	local hz = if crab then -0.42 else -0.5
	b:add("head", "Block", v(0.44, 0.28, 0.3), v(0, if crab then 0.55 else 0.46, hz), c.color)
	if crab then
		for i = -1, 1, 2 do
			b:add("head", "Block", v(0.04, 0.24, 0.04), v(i * 0.14, 0.8, hz - 0.08), c.dark)
		end
		eyes(b, "head", 0.95, hz - 0.08, 0.14, 0.14, c.eye)
	else
		eyes(b, "head", 0.6, hz - 0.14, 0.13, 0.17, c.eye)
	end
	if beetle then
		b:add("head", "Wedge", v(0.08, 0.36, 0.24), v(0, 0.72, hz - 0.08), c.eye, Enum.Material.Neon)
	elseif mite then
		for i = -1, 1, 2 do
			b:add(
				"head",
				"Block",
				v(0.03, 0.28, 0.03),
				v(i * 0.1, 0.72, hz - 0.1),
				c.dark,
				nil,
				ang(rad(-25), 0, rad(i * -20))
			)
		end
	end
	-- клешни
	if scorp or crab then
		rig.Arms = {}
		local big = if crab then 1.45 else 1
		for i = -1, 1, 2 do
			local g = if i < 0 then "armL" else "armR"
			b.pivots[g] = v(i * 0.3, 0.45, -0.4) * b.s
			b:add(g, "Block", v(0.1 * big, 0.1 * big, 0.34), v(i * 0.34, 0.45, -0.62), c.dark)
			b:add(g, "Block", v(0.2 * big, 0.14 * big, 0.22 * big), v(i * 0.36, 0.47, -0.84), c.color)
			b:add(
				g,
				"Wedge",
				v(0.08 * big, 0.08 * big, 0.16 * big),
				v(i * 0.36, 0.56, -1.0),
				if crab then c.accent else c.dark,
				if crab then Enum.Material.Neon else nil
			)
			table.insert(rig.Arms, g)
		end
	end
	-- хвост скорпиона
	if scorp then
		b.pivots.tail = v(0, 0.5, 0.4) * b.s
		b:add("tail", "Block", v(0.16, 0.16, 0.3), v(0, 0.58, 0.54), c.color, nil, ang(rad(30), 0, 0))
		b:add("tail", "Block", v(0.14, 0.3, 0.14), v(0, 0.86, 0.7), c.color)
		b:add("tail", "Block", v(0.12, 0.12, 0.26), v(0, 1.06, 0.6), c.dark, nil, ang(rad(-40), 0, 0))
		b:add(
			"tail",
			"Wedge",
			v(0.08, 0.16, 0.12),
			v(0, 1.08, 0.44),
			c.eye,
			Enum.Material.Neon,
			ang(rad(180), 0, 0)
		)
	end
	-- 6 лапок
	rig.Legs = {}
	local i0 = 0
	local spread = if crab then 0.5 else 0.38
	for _, z in ipairs({ -0.24, 0.02, 0.28 }) do
		for side = -1, 1, 2 do
			i0 += 1
			local g = "leg" .. i0
			b.pivots[g] = v(side * spread, 0.36, z) * b.s
			b:add(
				g,
				"Block",
				v(0.36, 0.06, 0.07),
				v(side * (spread + 0.14), 0.24, z),
				c.dark,
				nil,
				ang(0, 0, rad(side * 35))
			)
			table.insert(rig.Legs, { G = g, Ph = if (i0 % 2) == 0 then 0 else math.pi })
		end
	end
	rig.Top = if scorp then 1.2 else 1.0
	rig.CrownZ = hz
end

function R.imp(b: Builder, c: Ctx, rig: any)
	local frost = c.id == "frostimp"
	b:add("body", "Ball", v(0.7, 0.7, 0.7), v(0, 0.72, 0), c.color)
	b:add("body", "Ball", v(0.46, 0.46, 0.46), v(0, 0.66, -0.16), c.belly)
	b.pivots.head = v(0, 1.0, 0) * b.s
	b:add("head", "Ball", v(0.64, 0.64, 0.64), v(0, 1.24, -0.04), c.color)
	eyes(b, "head", 1.3, -0.3, 0.13, 0.18, c.eye)
	b:add("head", "Block", v(0.24, 0.06, 0.05), v(0, 1.1, -0.34), BLACK)
	fangs(b, "head", 1.09, -0.36, 0.07, 0.07)
	if frost then
		for k = -1, 1 do
			b:add(
				"head",
				"Wedge",
				v(0.1, 0.34 - math.abs(k) * 0.08, 0.16),
				v(k * 0.16, 1.62, 0.0),
				c.accent,
				Enum.Material.Glass,
				ang(0, 0, rad(k * -20)),
				0.15
			)
		end
	else
		b.pivots.flame = v(0, 1.5, 0) * b.s
		b:add("flame", "Ball", v(0.36, 0.36, 0.36), v(0, 1.58, 0.04), c.accent, Enum.Material.Neon, nil, 0.1)
		b:add(
			"flame",
			"Ball",
			v(0.22, 0.22, 0.22),
			v(0.04, 1.8, 0.06),
			Color3.fromRGB(255, 220, 80),
			Enum.Material.Neon,
			nil,
			0.2
		)
		b:add(
			"flame",
			"Ball",
			v(0.12, 0.12, 0.12),
			v(-0.02, 1.96, 0.08),
			Color3.fromRGB(255, 250, 200),
			Enum.Material.Neon,
			nil,
			0.3
		)
		for i = -1, 1, 2 do
			b:add(
				"head",
				"Wedge",
				v(0.07, 0.2, 0.12),
				v(i * 0.24, 1.5, 0.0),
				c.dark,
				nil,
				ang(0, 0, rad(i * -25))
			)
		end
	end
	rig.Legs = {}
	rig.Arms = {}
	for i = -1, 1, 2 do
		local lg = if i < 0 then "leg1" else "leg2"
		b.pivots[lg] = v(i * 0.17, 0.42, 0) * b.s
		b:add(lg, "Block", v(0.16, 0.32, 0.18), v(i * 0.17, 0.18, 0), c.dark)
		table.insert(rig.Legs, { G = lg, Ph = if i < 0 then 0 else math.pi })
		local ag = if i < 0 then "armL" else "armR"
		b.pivots[ag] = v(i * 0.34, 0.9, 0) * b.s
		b:add(
			ag,
			"Block",
			v(0.13, 0.36, 0.13),
			v(i * 0.42, 0.72, -0.02),
			c.color,
			nil,
			ang(0, 0, rad(i * 12))
		)
		table.insert(rig.Arms, ag)
	end
	rig.Top = if frost then 1.75 else 2.0
	rig.CrownZ = -0.04
end

function R.golem(b: Builder, c: Ctx, rig: any)
	local id = c.id
	local mat = if id == "elder_treant"
		then Enum.Material.Wood
		elseif id == "sand_titan" then Enum.Material.Sandstone
		elseif id == "glacier_lord" then Enum.Material.Ice
		elseif id == "inferno_tyrant" then Enum.Material.Basalt
		elseif id == "stone_colossus" then Enum.Material.Slate
		else Enum.Material.SmoothPlastic
	rig.Legs = {}
	rig.Arms = {}
	for i = -1, 1, 2 do
		local lg = if i < 0 then "leg1" else "leg2"
		b.pivots[lg] = v(i * 0.22, 0.46, 0) * b.s
		b:add(lg, "Block", v(0.3, 0.46, 0.32), v(i * 0.22, 0.23, 0), c.dark, mat)
		table.insert(rig.Legs, { G = lg, Ph = if i < 0 then 0 else math.pi })
	end
	b:add("body", "Block", v(0.86, 0.6, 0.56), v(0, 0.76, 0), c.color, mat)
	b:add("body", "Block", v(0.56, 0.3, 0.06), v(0, 0.8, -0.29), c.belly, mat)
	b.pivots.head = v(0, 1.06, 0) * b.s
	b:add("head", "Block", v(0.46, 0.38, 0.42), v(0, 1.25, -0.04), c.color, mat)
	b:add("head", "Block", v(0.5, 0.08, 0.14), v(0, 1.38, -0.22), c.dark, mat)
	eyes(b, "head", 1.27, -0.26, 0.11, 0.13, c.eye)
	b:add("head", "Block", v(0.22, 0.05, 0.04), v(0, 1.13, -0.26), BLACK)
	for i = -1, 1, 2 do
		local ag = if i < 0 then "armL" else "armR"
		b.pivots[ag] = v(i * 0.56, 1.0, 0) * b.s
		b:add(ag, "Ball", v(0.32, 0.32, 0.32), v(i * 0.56, 1.0, 0), c.dark, mat)
		b:add(ag, "Block", v(0.24, 0.5, 0.24), v(i * 0.6, 0.7, 0), c.color, mat)
		b:add(ag, "Block", v(0.32, 0.26, 0.32), v(i * 0.6, 0.38, -0.02), c.dark, mat)
		table.insert(rig.Arms, ag)
	end
	if id == "mossgolem" then
		b:add("body", "Block", v(0.5, 0.1, 0.4), v(0.12, 1.08, 0.02), c.accent, Enum.Material.Grass)
		b:add("armL", "Block", v(0.3, 0.1, 0.3), v(-0.56, 1.16, 0), c.accent, Enum.Material.Grass)
		b:add("body", "Block", v(0.18, 0.06, 0.04), v(0, 0.8, -0.33), c.eye, Enum.Material.Neon)
	elseif id == "elder_treant" then
		for k = -1, 1 do
			b:add(
				"head",
				"Block",
				v(0.08, 0.4, 0.08),
				v(k * 0.16, 1.58, 0.02),
				c.dark,
				mat,
				ang(0, 0, rad(k * -28))
			)
			b:add(
				"head",
				"Ball",
				v(0.34, 0.34, 0.34),
				v(k * 0.28, 1.8 - math.abs(k) * 0.08, 0.02),
				c.accent,
				Enum.Material.Grass
			)
		end
	elseif id == "sand_titan" then
		for i = -1, 1, 2 do
			b:add(
				"head",
				"Wedge",
				v(0.1, 0.5, 0.3),
				v(i * 0.28, 1.2, 0.0),
				c.accent,
				nil,
				ang(0, 0, rad(i * 8))
			)
		end
		b:add("head", "Block", v(0.5, 0.08, 0.46), v(0, 1.46, -0.04), GOLD, Enum.Material.Metal)
		b:add("body", "Block", v(0.3, 0.06, 0.04), v(0, 0.8, -0.33), c.eye, Enum.Material.Neon)
	elseif id == "glacier_lord" then
		for k = 0, 3 do
			local x = if k < 2 then -0.56 else 0.56
			b:add(
				if k < 2 then "armL" else "armR",
				"Wedge",
				v(0.1, 0.36, 0.18),
				v(x + (k % 2) * 0.08, 1.24, -0.06 + (k % 2) * 0.12),
				c.accent,
				Enum.Material.Glass,
				nil,
				0.1
			)
		end
		b:add("body", "Wedge", v(0.12, 0.4, 0.26), v(0, 1.18, 0.2), c.accent, Enum.Material.Glass, nil, 0.1)
	elseif id == "inferno_tyrant" then
		for i = -1, 1, 2 do
			b:add(
				"head",
				"Wedge",
				v(0.1, 0.34, 0.16),
				v(i * 0.24, 1.56, -0.02),
				BLACK,
				nil,
				ang(0, 0, rad(i * -30))
			)
		end
		b:add(
			"body",
			"Block",
			v(0.4, 0.05, 0.04),
			v(0, 0.86, -0.33),
			c.accent,
			Enum.Material.Neon,
			ang(0, 0, rad(25))
		)
		b:add(
			"body",
			"Block",
			v(0.3, 0.05, 0.04),
			v(0.05, 0.7, -0.33),
			c.accent,
			Enum.Material.Neon,
			ang(0, 0, rad(-20))
		)
		rig.Wings = {}
		for i = -1, 1, 2 do
			local g = if i < 0 then "wingL" else "wingR"
			b.pivots[g] = v(i * 0.2, 1.0, 0.28) * b.s
			b:add(g, "Block", v(0.7, 0.5, 0.04), v(i * 0.5, 1.12, 0.32), c.dark, nil, ang(0, rad(i * 20), 0))
			table.insert(rig.Wings, g)
		end
	elseif id == "stone_colossus" then
		b:add("body", "Block", v(0.08, 0.3, 0.04), v(-0.12, 0.8, -0.33), c.eye, Enum.Material.Neon)
		b:add("body", "Block", v(0.08, 0.3, 0.04), v(0.12, 0.8, -0.33), c.eye, Enum.Material.Neon)
		b:add("armL", "Block", v(0.06, 0.3, 0.26), v(-0.73, 0.7, 0), c.eye, Enum.Material.Neon)
		b:add("armR", "Block", v(0.06, 0.3, 0.26), v(0.73, 0.7, 0), c.eye, Enum.Material.Neon)
	end
	rig.Top = 1.46
	rig.CrownZ = -0.04
end

-- ---------------------------------------------------------------------------

function EnemyVisual.archOf(id: string): string
	return EnemyVisual.ARCH[id] or "slime"
end

function EnemyVisual.build(def: any, special: string?): Rig
	local model = Instance.new("Model")
	model.Name = "EV_" .. tostring(def.Id)
	local s = def.Size or 3
	local arch = EnemyVisual.archOf(def.Id)
	local b = newBuilder(model, s)
	local color: Color3 = def.Color or Color3.fromRGB(200, 200, 200)
	local accent = EnemyVisual.ACCENT[def.Zone] or EnemyVisual.ACCENT.Any
	if special == "moonling" then
		accent = EnemyVisual.ACCENT.Any
	end
	local ctx: Ctx = {
		id = def.Id,
		color = color,
		belly = color:Lerp(WHITE, 0.38),
		dark = color:Lerp(BLACK, 0.45),
		eye = def.Eye or BLACK,
		accent = accent,
		boss = def.Boss == true,
	}
	local rig: any = {
		Model = model,
		Parts = b.parts,
		Pivots = b.pivots,
		Arch = arch,
		Legs = {},
		Arms = {},
		Wings = {},
		Scale = s,
		Boss = def.Boss == true,
		Accent = accent,
	}
	local recipe = R[arch] or R.slime
	recipe(b, ctx, rig)
	local top = (rig.Top or 1) * s
	if def.Boss then
		local headGroup = if b.pivots.head then "head" else "body"
		crown(b, headGroup, rig.Top or 1, rig.CrownZ or 0, 0.36)
		top += 0.5 * s
		b.pivots.aura = Vector3.zero
		b:add("aura", "Cyl", v(0.04, 2.0, 2.0), v(0, 0.03, 0), accent, Enum.Material.Neon, VERT, 0.55)
		b:add(
			"aura",
			"Cyl",
			v(0.05, 1.5, 1.5),
			v(0, 0.05, 0),
			def.Eye or accent,
			Enum.Material.Neon,
			VERT,
			0.7
		)
	end
	-- невидимая опора для полоски HP (над макушкой)
	local anchor: BasePart = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(0, top + 0.6, 0)
	anchor.Parent = model
	table.insert(
		b.parts,
		{ Part = anchor, Group = "body", Rel = anchor.CFrame, Color = WHITE, Size = anchor.Size, Trans = 1 }
	)
	model.PrimaryPart = anchor
	rig.Height = top
	rig.Anchor = anchor
	return rig :: Rig
end

-- Поза частей (чистая математика, для тестов и клиента):
-- root — CFrame у земли (перед = -Z), body — смещение корпуса, groups — локальные повороты групп.
function EnemyVisual.pose(rig: Rig, root: CFrame, body: CFrame, groups: { [string]: CFrame }): { CFrame }
	local out = table.create(#rig.Parts)
	local cache: { [string]: CFrame } = {}
	for i, rp in ipairs(rig.Parts) do
		local g = rp.Group
		local t = cache[g]
		if not t then
			local rot = groups[g]
			local p = rig.Pivots[g]
			if rot and p then
				t = CFrame.new(p) * rot * CFrame.new(-p)
			elseif rot then
				t = rot
			else
				t = CFrame.identity
			end
			cache[g] = t
		end
		out[i] = root * body * t * rp.Rel
	end
	return out
end

return EnemyVisual
