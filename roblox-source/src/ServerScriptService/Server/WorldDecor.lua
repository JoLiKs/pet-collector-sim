--!strict
-- v3.0: декор хаба из примитивов — рунные арки порталов миров (спокойное свечение, мягкий вихрь,
-- табличка с названием мира и требованием, декор у основания) и площадь спавна (узор, фонтан со
-- статуей питомца, клумбы, фонари, флаги, указатели к станциям и порталам).
-- Вихрь вращает клиент (PortalSwirl.client.lua) по атрибуту модели PortalSwirl (рад/с).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Util = require(Shared.Util)
local ZoneData = require(Shared.ZoneData)

local WorldDecor = {}

export type Hooks = {
	prompt: (BasePart, string, string, string, number?) -> (),
	label: (Instance, string, UDim2, Color3, { [string]: any }?) -> TextLabel,
	billboard: (BasePart, Vector3, number, number) -> BillboardGui,
}

export type Style = {
	Stone: Color3,
	Trim: Color3,
	Material: Enum.Material,
	Glow: Color3, -- руны и вихрь
	Base: string, -- декор у основания: Flowers | Mushrooms | Cacti | Crystals | Embers
}

WorldDecor.STYLES = {
	Meadow = {
		Stone = Color3.fromRGB(196, 188, 166),
		Trim = Color3.fromRGB(150, 140, 118),
		Material = Enum.Material.Cobblestone,
		Glow = Color3.fromRGB(255, 222, 120),
		Base = "Flowers",
	},
	Forest = {
		Stone = Color3.fromRGB(104, 112, 96),
		Trim = Color3.fromRGB(86, 70, 52),
		Material = Enum.Material.Slate,
		Glow = Color3.fromRGB(130, 225, 150),
		Base = "Mushrooms",
	},
	Desert = {
		Stone = Color3.fromRGB(222, 184, 128),
		Trim = Color3.fromRGB(184, 140, 90),
		Material = Enum.Material.Sandstone,
		Glow = Color3.fromRGB(255, 186, 110),
		Base = "Cacti",
	},
	Frost = {
		Stone = Color3.fromRGB(200, 218, 236),
		Trim = Color3.fromRGB(150, 176, 205),
		Material = Enum.Material.Marble,
		Glow = Color3.fromRGB(150, 214, 255),
		Base = "Crystals",
	},
	Volcano = {
		Stone = Color3.fromRGB(72, 64, 66),
		Trim = Color3.fromRGB(46, 40, 42),
		Material = Enum.Material.Basalt,
		Glow = Color3.fromRGB(255, 132, 70),
		Base = "Embers",
	},
} :: { [string]: Style }

-- Яркость: Neon только на мелких рунах и с прозрачностью; свет — слабый и короткий
WorldDecor.RUNE_TRANSPARENCY = 0.45
WorldDecor.LIGHT_BRIGHTNESS = 0.6
WorldDecor.LIGHT_RANGE = 12
WorldDecor.PARTICLE_RATE = 3

local function part(
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
	p.CanCollide = collide == true
	p.CastShadow = collide == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local BLOCK = Enum.PartType.Block
local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- ось цилиндра X → вертикаль

local function lerp(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

local function rune(parent: Instance, cf: CFrame, color: Color3, size: Vector3?)
	local r = part(parent, "Rune", BLOCK, size or Vector3.new(0.7, 1, 0.12), cf, color, Enum.Material.Neon)
	r.Transparency = WorldDecor.RUNE_TRANSPARENCY
	return r
end

-- Декор у основания арки (в локальных координатах арки: X — вбок, Z — вперёд от арки к хабу = -Z)
local function baseDecor(m: Model, at: CFrame, style: Style, rng: Random)
	local kind = style.Base
	for _, sx in ipairs({ -1, 1 }) do
		for k = 1, 3 do
			local off = Vector3.new(sx * (9.6 + k * 1.3), 0, -1.5 + (k - 2) * 2.4 + rng:NextNumber(-0.4, 0.4))
			local cf = at * CFrame.new(off)
			if kind == "Flowers" then
				part(
					m,
					"Bush",
					BALL,
					Vector3.new(2.2, 1.6, 2.2),
					cf * CFrame.new(0, 0.6, 0),
					Color3.fromRGB(86, 160, 72)
				)
				local petal = ({
					Color3.fromRGB(255, 120, 160),
					Color3.fromRGB(255, 220, 90),
					Color3.fromRGB(170, 140, 255),
				})[k]
				for j = 1, 3 do
					local a = j * 2.1 + k
					part(
						m,
						"Flower",
						BALL,
						Vector3.new(0.6, 0.6, 0.6),
						cf * CFrame.new(math.cos(a) * 0.7, 1.35, math.sin(a) * 0.7),
						petal
					)
				end
			elseif kind == "Mushrooms" then
				local h = rng:NextNumber(0.9, 1.6)
				part(
					m,
					"Stem",
					CYL,
					Vector3.new(h, 0.5, 0.5),
					cf * CFrame.new(0, h / 2, 0) * UP,
					Color3.fromRGB(235, 225, 205)
				)
				part(
					m,
					"Cap",
					BALL,
					Vector3.new(1.6, 0.8, 1.6),
					cf * CFrame.new(0, h + 0.1, 0),
					if k == 2 then Color3.fromRGB(200, 70, 60) else Color3.fromRGB(170, 120, 80)
				)
				part(
					m,
					"Fern",
					BLOCK,
					Vector3.new(0.2, 1.2, 1.6),
					cf * CFrame.new(0.9, 0.5, 0) * CFrame.Angles(0, k, 0.4),
					Color3.fromRGB(70, 130, 70)
				)
			elseif kind == "Cacti" then
				local h = rng:NextNumber(1.4, 2.6)
				part(
					m,
					"Cactus",
					CYL,
					Vector3.new(h, 0.8, 0.8),
					cf * CFrame.new(0, h / 2, 0) * UP,
					Color3.fromRGB(80, 150, 85)
				)
				part(
					m,
					"Pebble",
					BALL,
					Vector3.new(1.2, 0.7, 1),
					cf * CFrame.new(0.9, 0.25, 0.4),
					style.Trim,
					Enum.Material.Sandstone
				)
			elseif kind == "Crystals" then
				local h = rng:NextNumber(1.2, 2.4)
				local c = part(
					m,
					"Shard",
					BLOCK,
					Vector3.new(0.7, h, 0.7),
					cf * CFrame.new(0, h / 2 - 0.2, 0) * CFrame.Angles(0.2 * sx, k, 0.15),
					lerp(style.Glow, Color3.new(1, 1, 1), 0.3),
					Enum.Material.Ice
				)
				c.Transparency = 0.2
			else -- Embers
				part(
					m,
					"Rock",
					BALL,
					Vector3.new(1.8, 1.1, 1.6),
					cf * CFrame.new(0, 0.4, 0),
					style.Stone,
					Enum.Material.Basalt
				)
				local e = part(
					m,
					"Ember",
					BALL,
					Vector3.new(0.5, 0.3, 0.5),
					cf * CFrame.new(0.3, 0.95, 0),
					style.Glow,
					Enum.Material.Neon
				)
				e.Transparency = 0.5
			end
		end
	end
end

export type ArchOpts = {
	Id: string, -- id подсказки (portal_<Zone> / hubReturn)
	Title: string, -- ключ Locale или имя «данных»
	Sub: string?, -- ключ требования
	SubArgs: { [string]: any }?,
	Action: string,
	Object: string,
	Style: Style,
	Seed: number,
	SignHeight: number?,
}

-- Арка: origin — центр у земли; LookVector origin смотрит «наружу» (в сторону хаба/игрока).
function WorldDecor.buildArch(
	parent: Instance,
	name: string,
	origin: CFrame,
	o: ArchOpts,
	hooks: Hooks
): (Model, BasePart)
	local s = o.Style
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Portal", o.Id)
	local rng = Random.new(o.Seed)
	-- ступень
	part(
		m,
		"Step",
		BLOCK,
		Vector3.new(17, 0.5, 7),
		origin * CFrame.new(0, 0.25, -0.5),
		s.Trim,
		s.Material,
		true
	)
	part(
		m,
		"StepFront",
		BLOCK,
		Vector3.new(13, 0.3, 3),
		origin * CFrame.new(0, 0.15, -5),
		s.Stone,
		s.Material,
		false
	)
	-- колонны
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 7
		part(
			m,
			"Plinth",
			BLOCK,
			Vector3.new(4.4, 1.6, 4.4),
			origin * CFrame.new(x, 1.3, 0),
			s.Trim,
			s.Material,
			true
		)
		part(
			m,
			"Pillar",
			BLOCK,
			Vector3.new(3, 13, 3),
			origin * CFrame.new(x, 8.6, 0),
			s.Stone,
			s.Material,
			true
		)
		for k = 1, 3 do
			part(
				m,
				"Band",
				BLOCK,
				Vector3.new(3.3, 0.35, 3.3),
				origin * CFrame.new(x, 2.1 + k * 3.8, 0),
				s.Trim,
				s.Material
			)
		end
		part(
			m,
			"Cap",
			BLOCK,
			Vector3.new(3.9, 1, 3.9),
			origin * CFrame.new(x, 15.6, 0),
			s.Trim,
			s.Material,
			true
		)
		for k = 1, 3 do
			rune(
				m,
				origin * CFrame.new(x, 2.1 + k * 3.8 + 1.9, 1.56) * CFrame.Angles(0, 0, (k % 2) * 0.5),
				s.Glow
			)
			rune(
				m,
				origin * CFrame.new(x, 2.1 + k * 3.8 + 1.9, -1.56) * CFrame.Angles(0, 0, (k % 2) * 0.5),
				s.Glow
			)
		end
	end
	-- полукруглый свод из камней
	local R, cy = 7, 16.1
	local keystone: BasePart? = nil
	for k = 0, 6 do
		local a = math.rad(k * 30)
		local cf = origin
			* CFrame.new(math.cos(a) * R, cy + math.sin(a) * R, 0)
			* CFrame.Angles(0, 0, a + math.pi / 2)
		local isKey = k == 3
		local stone = part(
			m,
			if isKey then "Keystone" else "ArchStone",
			BLOCK,
			if isKey then Vector3.new(3.2, 3, 3.6) else Vector3.new(3.9, 2.4, 3),
			cf,
			if isKey then s.Trim else s.Stone,
			s.Material,
			true
		)
		if isKey then
			keystone = stone
			rune(m, cf * CFrame.new(0, 0, 1.86), s.Glow, Vector3.new(1.2, 1.2, 0.12))
			rune(m, cf * CFrame.new(0, 0, -1.86), s.Glow, Vector3.new(1.2, 1.2, 0.12))
		end
	end
	-- мягкий вихрь: полупрозрачные диски (SmoothPlastic, без Neon) + лепестки спирали
	local swirl = Instance.new("Model")
	swirl.Name = "Swirl"
	swirl:SetAttribute("PortalSwirl", if o.Seed % 2 == 0 then 0.7 else -0.7)
	local center = origin * CFrame.new(0, 10.6, 0)
	local face = center * CFrame.Angles(0, math.rad(90), 0) -- ось диска вдоль Z арки
	local disc = part(
		swirl,
		"Veil",
		CYL,
		Vector3.new(0.2, 11.4, 11.4),
		face,
		lerp(s.Glow, Color3.fromRGB(40, 40, 70), 0.35)
	)
	disc.Transparency = 0.55
	local inner =
		part(swirl, "Core", CYL, Vector3.new(0.3, 5.2, 5.2), face, lerp(s.Glow, Color3.new(1, 1, 1), 0.45))
	inner.Transparency = 0.5
	for k = 1, 5 do
		local a = k * (math.pi * 2 / 5)
		local petal = part(
			swirl,
			"Petal",
			BLOCK,
			Vector3.new(4.2, 0.55, 0.12),
			center * CFrame.Angles(0, 0, a) * CFrame.new(2.9, 0.4, 0) * CFrame.Angles(0, 0, 0.55),
			lerp(s.Glow, Color3.new(1, 1, 1), 0.6)
		)
		petal.Transparency = 0.45
	end
	swirl.WorldPivot = center
	swirl.Parent = m
	local light = Instance.new("PointLight")
	light.Brightness = WorldDecor.LIGHT_BRIGHTNESS
	light.Range = WorldDecor.LIGHT_RANGE
	light.Color = s.Glow
	light.Shadows = false
	light.Parent = inner
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = WorldDecor.PARTICLE_RATE
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Speed = NumberRange.new(0.4, 1)
	pe.Size = NumberSequence.new(0.25, 0)
	pe.Transparency = NumberSequence.new(0.35, 1)
	pe.LightEmission = 0.3
	pe.Color = ColorSequence.new(s.Glow)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = disc
	-- табличка: каменная плита под сводом + подпись (BillboardGui работает и в веб-демо)
	local plaque = part(
		m,
		"Plaque",
		BLOCK,
		Vector3.new(6.4, 1.5, 0.35),
		origin * CFrame.new(0, 19.6, -1.3),
		lerp(s.Trim, Color3.fromRGB(40, 32, 26), 0.4),
		Enum.Material.Wood
	)
	part(
		m,
		"PlaqueRim",
		BLOCK,
		Vector3.new(6.9, 1.9, 0.25),
		origin * CFrame.new(0, 19.6, -1.12),
		s.Stone,
		s.Material
	)
	local gui = hooks.billboard(plaque, Vector3.new(0, o.SignHeight or 5.2, 0), 250, 80)
	gui.MaxDistance = 75
	hooks.label(gui, o.Title, UDim2.fromScale(1, if o.Sub then 0.56 else 0.9), Color3.new(1, 1, 1))
	if o.Sub then
		local sub = hooks.label(
			gui,
			o.Sub,
			UDim2.fromScale(1, 0.38),
			lerp(s.Glow, Color3.new(1, 1, 1), 0.25),
			o.SubArgs
		)
		sub.Position = UDim2.fromScale(0, 0.6)
	end
	baseDecor(m, origin, s, rng)
	m.Parent = parent
	hooks.prompt(disc, o.Id, o.Action, o.Object, 0)
	local _ = keystone
	return m, disc
end

-- Текст требования для таблички мира
function WorldDecor.requirement(zone: ZoneData.ZoneDef): (string, { [string]: any }?)
	if zone.UnlockCost <= 0 and zone.RequiresRebirths <= 0 then
		return "world.portal_free", nil
	end
	if zone.RequiresRebirths > 0 then
		return "world.portal_cost_rb",
			{ price = Util.formatNumber(zone.UnlockCost), n = zone.RequiresRebirths }
	end
	return "world.portal_cost", { price = Util.formatNumber(zone.UnlockCost) }
end

-- Положения арок миров в хабе: дуга за точкой спавна, арки смотрят на центр
WorldDecor.ARC_RADIUS = 90
function WorldDecor.portalOrigins(): { [string]: CFrame }
	local out = {}
	local n = #ZoneData.List
	for i, zone in ipairs(ZoneData.List) do
		local a = math.rad(90 + (i - (n + 1) / 2) * 21)
		local pos = Vector3.new(math.cos(a) * WorldDecor.ARC_RADIUS, 0, math.sin(a) * WorldDecor.ARC_RADIUS)
		out[zone.Id] = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Площадь спавна
-- ---------------------------------------------------------------------------
local PLAZA_TOP = 0.25 -- верх мраморного круга хаба

local function flat(
	parent: Instance,
	name: string,
	d: number,
	at: Vector3,
	color: Color3,
	lift: number,
	mat: Enum.Material?
)
	return part(
		parent,
		name,
		CYL,
		Vector3.new(0.04, d, d),
		CFrame.new(at + Vector3.new(0, PLAZA_TOP + lift, 0)) * UP,
		color,
		mat or Enum.Material.Marble
	)
end

local function flowerbed(m: Instance, at: Vector3, rng: Random)
	part(
		m,
		"BedRim",
		CYL,
		Vector3.new(0.9, 8, 8),
		CFrame.new(at + Vector3.new(0, 0.6, 0)) * UP,
		Color3.fromRGB(176, 168, 150),
		Enum.Material.Cobblestone,
		true
	)
	part(
		m,
		"Soil",
		CYL,
		Vector3.new(0.3, 6.8, 6.8),
		CFrame.new(at + Vector3.new(0, 1, 0)) * UP,
		Color3.fromRGB(96, 66, 44),
		Enum.Material.Ground
	)
	local colors = {
		Color3.fromRGB(255, 120, 150),
		Color3.fromRGB(255, 214, 90),
		Color3.fromRGB(170, 140, 255),
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 150, 80),
	}
	for k = 1, 9 do
		local a = k * 2.4 + rng:NextNumber(0, 0.5)
		local r = if k == 9 then 0 else rng:NextNumber(1.2, 2.6)
		local p = at + Vector3.new(math.cos(a) * r, 1.15, math.sin(a) * r)
		part(m, "Leaf", BALL, Vector3.new(1.3, 0.8, 1.3), CFrame.new(p), Color3.fromRGB(80, 150, 70))
		part(
			m,
			"Bloom",
			BALL,
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(p + Vector3.new(0, 0.55, 0)),
			colors[(k % #colors) + 1]
		)
	end
end

local function lamp(m: Instance, at: Vector3)
	local metal = Color3.fromRGB(52, 54, 64)
	part(
		m,
		"LampBase",
		CYL,
		Vector3.new(0.6, 1.6, 1.6),
		CFrame.new(at + Vector3.new(0, 0.55, 0)) * UP,
		metal,
		Enum.Material.Metal,
		true
	)
	part(
		m,
		"LampPole",
		CYL,
		Vector3.new(7.5, 0.5, 0.5),
		CFrame.new(at + Vector3.new(0, 4.4, 0)) * UP,
		metal,
		Enum.Material.Metal,
		true
	)
	part(
		m,
		"LampCap",
		BLOCK,
		Vector3.new(1.7, 0.4, 1.7),
		CFrame.new(at + Vector3.new(0, 9.4, 0)),
		metal,
		Enum.Material.Metal
	)
	local glass = part(
		m,
		"Lantern",
		BLOCK,
		Vector3.new(1.3, 1.5, 1.3),
		CFrame.new(at + Vector3.new(0, 8.5, 0)),
		Color3.fromRGB(255, 226, 160),
		Enum.Material.Glass
	)
	glass.Transparency = 0.25
	local bulb = part(
		m,
		"Bulb",
		BALL,
		Vector3.new(0.6, 0.6, 0.6),
		CFrame.new(at + Vector3.new(0, 8.5, 0)),
		Color3.fromRGB(255, 220, 150),
		Enum.Material.Neon
	)
	bulb.Transparency = 0.3
end

local function flag(m: Instance, at: Vector3, color: Color3, facing: number)
	part(
		m,
		"FlagPole",
		CYL,
		Vector3.new(14, 0.4, 0.4),
		CFrame.new(at + Vector3.new(0, 7, 0)) * UP,
		Color3.fromRGB(235, 232, 220),
		Enum.Material.Metal,
		true
	)
	part(
		m,
		"FlagTop",
		BALL,
		Vector3.new(0.8, 0.8, 0.8),
		CFrame.new(at + Vector3.new(0, 14.2, 0)),
		Color3.fromRGB(255, 205, 80),
		Enum.Material.Metal
	)
	local rot = CFrame.Angles(0, facing, 0)
	part(
		m,
		"Flag",
		BLOCK,
		Vector3.new(3.6, 2.4, 0.08),
		CFrame.new(at + Vector3.new(0, 12.4, 0)) * rot * CFrame.new(1.9, 0, 0) * CFrame.Angles(0, 0.18, 0),
		color,
		Enum.Material.Fabric
	)
	part(
		m,
		"FlagTail",
		BLOCK,
		Vector3.new(1.4, 1.2, 0.08),
		CFrame.new(at + Vector3.new(0, 12.0, 0)) * rot * CFrame.new(4.3, 0, 0.35) * CFrame.Angles(0, 0.4, 0),
		lerp(color, Color3.new(1, 1, 1), 0.25),
		Enum.Material.Fabric
	)
end

-- Статуя питомца (котёнок) на фонтане
local function statue(m: Instance, at: Vector3)
	local stone = Color3.fromRGB(232, 226, 210)
	local gold = Color3.fromRGB(230, 190, 90)
	part(
		m,
		"StatuePedestal",
		CYL,
		Vector3.new(1.6, 3.2, 3.2),
		CFrame.new(at + Vector3.new(0, 0.8, 0)) * UP,
		gold,
		Enum.Material.Metal,
		true
	)
	part(
		m,
		"StatueBody",
		BALL,
		Vector3.new(3.2, 3, 3.6),
		CFrame.new(at + Vector3.new(0, 3, 0)),
		stone,
		Enum.Material.Marble,
		true
	)
	local head = part(
		m,
		"StatueHead",
		BALL,
		Vector3.new(2.8, 2.6, 2.6),
		CFrame.new(at + Vector3.new(0, 5.4, 0.9)),
		stone,
		Enum.Material.Marble,
		true
	)
	for _, sx in ipairs({ -1, 1 }) do
		part(
			m,
			"StatueEar",
			BLOCK,
			Vector3.new(0.7, 1.1, 0.4),
			CFrame.new(at + Vector3.new(sx * 0.8, 6.8, 0.8)) * CFrame.Angles(0, 0, -sx * 0.3),
			stone,
			Enum.Material.Marble
		)
		part(
			m,
			"StatueEye",
			BALL,
			Vector3.new(0.35, 0.45, 0.2),
			CFrame.new(at + Vector3.new(sx * 0.55, 5.6, 2.15)),
			Color3.fromRGB(70, 60, 60)
		)
		part(
			m,
			"StatuePaw",
			BALL,
			Vector3.new(0.9, 0.7, 1.2),
			CFrame.new(at + Vector3.new(sx * 0.9, 1.9, 1.5)),
			stone,
			Enum.Material.Marble
		)
	end
	part(
		m,
		"StatueTail",
		CYL,
		Vector3.new(2.6, 0.6, 0.6),
		CFrame.new(at + Vector3.new(1.2, 2.6, -1.8)) * CFrame.Angles(0.5, 0.6, 0.9),
		stone,
		Enum.Material.Marble
	)
	part(
		m,
		"StatueCollar",
		CYL,
		Vector3.new(0.35, 2.2, 2.2),
		CFrame.new(at + Vector3.new(0, 4.3, 0.5)) * UP,
		gold,
		Enum.Material.Metal
	)
	return head
end

export type SignTarget = { Key: string, Pos: Vector3 }

-- Указатель: столб с досками-стрелками, повернутыми к цели; подпись — у острия стрелки
local function signpost(m: Instance, at: Vector3, targets: { SignTarget }, hooks: Hooks)
	local wood = Color3.fromRGB(140, 96, 58)
	part(
		m,
		"SignPole",
		CYL,
		Vector3.new(9, 0.7, 0.7),
		CFrame.new(at + Vector3.new(0, 4.5, 0)) * UP,
		Color3.fromRGB(110, 76, 46),
		Enum.Material.Wood,
		true
	)
	part(
		m,
		"SignTop",
		BALL,
		Vector3.new(0.9, 0.9, 0.9),
		CFrame.new(at + Vector3.new(0, 9.1, 0)),
		Color3.fromRGB(255, 205, 80),
		Enum.Material.Metal
	)
	for i, t in ipairs(targets) do
		local y = 8.3 - (i - 1) * 1.15
		local flatDir = Vector3.new(t.Pos.X - at.X, 0, t.Pos.Z - at.Z)
		if flatDir.Magnitude < 0.1 then
			continue
		end
		local dir = flatDir.Unit
		local base = CFrame.lookAt(at + Vector3.new(0, y, 0), at + Vector3.new(0, y, 0) + dir)
		-- доска вдоль -Z (LookVector), острие — повернутый квадрат
		local board = part(
			m,
			"Arrow",
			BLOCK,
			Vector3.new(0.18, 0.85, 3.2),
			base * CFrame.new(0, 0, -1.9),
			lerp(wood, Color3.new(1, 1, 1), (i % 2) * 0.12),
			Enum.Material.Wood
		)
		part(
			m,
			"ArrowTip",
			BLOCK,
			Vector3.new(0.18, 0.6, 0.6),
			base * CFrame.new(0, 0, -3.5) * CFrame.Angles(math.rad(45), 0, 0),
			board.Color,
			Enum.Material.Wood
		)
		local gui = hooks.billboard(board, Vector3.new(0, 0, 0), 84, 15)
		gui.MaxDistance = 28
		gui.StudsOffsetWorldSpace = dir * 1.2
		hooks.label(gui, t.Key, UDim2.fromScale(1, 1), Color3.fromRGB(255, 240, 200))
	end
end

function WorldDecor.buildSpawnPlaza(hub: Instance, spawnAt: Vector3, targets: { SignTarget }, hooks: Hooks)
	local m = Instance.new("Model")
	m.Name = "SpawnPlaza"
	local rng = Random.new(303)
	-- узор: кольца и лучи-дорожки
	local ring1 = Color3.fromRGB(205, 192, 164)
	local ring2 = Color3.fromRGB(238, 230, 212)
	flat(m, "PatternRing", 46, Vector3.zero, ring1, 0.01)
	flat(m, "PatternRing", 43, Vector3.zero, ring2, 0.02)
	flat(m, "PatternRing", 36, Vector3.zero, Color3.fromRGB(190, 160, 120), 0.03, Enum.Material.Slate)
	flat(m, "PatternRing", 34, Vector3.zero, ring2, 0.04)
	for k = 0, 15 do
		local a = k * math.pi / 8
		local r = 19.5
		local tile = part(
			m,
			"PatternTile",
			BLOCK,
			Vector3.new(1.6, 0.04, 1.6),
			CFrame.new(math.cos(a) * r, PLAZA_TOP + 0.07, math.sin(a) * r)
				* CFrame.Angles(0, -a + math.pi / 4, 0),
			if k % 2 == 0 then Color3.fromRGB(120, 170, 220) else Color3.fromRGB(230, 180, 90),
			Enum.Material.Marble
		)
		local _ = tile
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		local len = 50
		part(
			m,
			"PatternPath",
			BLOCK,
			Vector3.new(len, 0.04, 3.2),
			CFrame.new(math.cos(a) * (23 + len / 2), PLAZA_TOP + 0.02, math.sin(a) * (23 + len / 2))
				* CFrame.Angles(0, -a, 0),
			Color3.fromRGB(214, 202, 178),
			Enum.Material.Pavement
		)
	end
	-- коврик точки спавна
	flat(m, "SpawnRing", 16, spawnAt, Color3.fromRGB(240, 200, 110), 0.05)
	flat(m, "SpawnInner", 13.4, spawnAt, Color3.fromRGB(250, 240, 220), 0.06)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		part(
			m,
			"SpawnStar",
			BLOCK,
			Vector3.new(1.2, 0.04, 1.2),
			CFrame.new(spawnAt + Vector3.new(math.cos(a) * 5, PLAZA_TOP + 0.09, math.sin(a) * 5))
				* CFrame.Angles(0, math.pi / 4, 0),
			Color3.fromRGB(240, 170, 80),
			Enum.Material.Marble
		)
	end
	-- фонтан: второй ярус, струи и статуя питомца
	part(
		m,
		"FountainRim",
		CYL,
		Vector3.new(0.6, 27.2, 27.2),
		CFrame.new(0, 2.5, 0) * UP,
		Color3.fromRGB(214, 206, 190),
		Enum.Material.Marble,
		true
	)
	part(
		m,
		"FountainTier",
		CYL,
		Vector3.new(1.4, 11, 11),
		CFrame.new(0, 3.2, 0) * UP,
		Color3.fromRGB(196, 190, 180),
		Enum.Material.Marble,
		true
	)
	local tierWater = part(
		m,
		"TierWater",
		CYL,
		Vector3.new(0.3, 9.6, 9.6),
		CFrame.new(0, 3.95, 0) * UP,
		Color3.fromRGB(110, 190, 240),
		Enum.Material.Glass
	)
	tierWater.Transparency = 0.35
	for k = 0, 5 do
		local a = k * math.pi / 3
		local jet = part(
			m,
			"Jet",
			CYL,
			Vector3.new(2.6, 0.35, 0.35),
			CFrame.new(math.cos(a) * 7.5, 3.6, math.sin(a) * 7.5)
				* CFrame.Angles(0, -a, 0)
				* CFrame.Angles(0, 0, math.rad(60)),
			Color3.fromRGB(190, 230, 255),
			Enum.Material.Glass
		)
		jet.Transparency = 0.45
	end
	local head = statue(m, Vector3.new(0, 3.9, 0))
	-- клумбы, фонари, флаги
	for _, p in ipairs({
		Vector3.new(-16, 0, 48),
		Vector3.new(16, 0, 48),
		Vector3.new(-50, 0, 24),
		Vector3.new(50, 0, 22),
		Vector3.new(-20, 0, -30),
		Vector3.new(20, 0, -30),
	}) do
		flowerbed(m, p, rng)
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		lamp(m, Vector3.new(math.cos(a) * 24.5, 0, math.sin(a) * 24.5))
	end
	local origins = WorldDecor.portalOrigins()
	local ids = {}
	for _, zone in ipairs(ZoneData.List) do
		table.insert(ids, zone.Id)
	end
	for i = 1, #ids - 1 do
		local a = origins[ids[i]].Position
		local b = origins[ids[i + 1]].Position
		local mid = (a + b) / 2
		local za = ZoneData.ById[ids[i]]
		local zb = ZoneData.ById[ids[i + 1]]
		flag(m, mid * 1.02, lerp(za.Accent, zb.Accent, 0.5), math.atan2(mid.X, mid.Z) + math.pi / 2)
	end
	signpost(m, spawnAt + Vector3.new(13, 0, 4), targets, hooks)
	m.Parent = hub
	return head
end

return WorldDecor
