--!strict
--[[
	EnemyVisuals: клиентская рисовка и анимация врагов.
	Сервер (CombatService) держит в Workspace.Enemies только невидимые хитбоксы Body с атрибутами
	EnemyId/Hp/MaxHp/IsBoss/IsRaid/Atk. Здесь по ним строится модель из EnemyVisual и анимируется:
	  - плавное догоняющее движение к серверной позиции (интерполяция), поворот по ходу;
	  - idle-дыхание, шаги/прыжки/взмахи крыльев по скорости;
	  - замах (атрибут Atk растёт) — телеграф удара;
	  - вспышка + отдача при уроне; смерть — сжатие, исчезновение и осколки;
	  - компактная полоска HP (у босса — с именем и короной).
	Дальние враги не строятся/не анимируются (бюджет частей).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnemyData = require(Shared:WaitForChild("EnemyData"))
local EnemyVisual = require(Shared:WaitForChild("EnemyVisual"))
local Locale = require(Shared:WaitForChild("Locale"))

local BUILD_DIST = 170
local DROP_DIST = 220
local ANIM_DIST = 120
local DEATH_TIME = 0.55
local FLASH_TIME = 0.09
local WHITE = Color3.new(1, 1, 1)

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "EnemyVisuals"
folder.Parent = Workspace

type Entry = {
	Src: Model,
	Body: BasePart,
	Rig: any,
	Half: number,
	Pos: Vector3,
	Rot: CFrame,
	Phase: number,
	Hp: number,
	MaxHp: number,
	Atk: number,
	AtkAt: number,
	WindDur: number,
	FlashUntil: number,
	Flashing: boolean,
	Recoil: number,
	DeadAt: number?,
	Bar: BillboardGui?,
	Fill: Frame?,
	BarText: TextLabel?,
	Seed: number,
}

local entries: { [Model]: Entry } = {}
local dying: { Entry } = {}
local bits: { { Part: BasePart, Vel: Vector3, Born: number } } = {}

local function defOf(m: Model): any
	local id = tostring(m:GetAttribute("EnemyId"))
	if m:GetAttribute("IsRaid") then
		return EnemyData.RAID_BOSS
	end
	if id == EnemyData.MOONLING.Id then
		return EnemyData.MOONLING
	end
	return EnemyData.ById[id] or (id == EnemyData.RAID_BOSS.Id and EnemyData.RAID_BOSS) or nil
end

-- только поворот по Y из LookVector хитбокса (устойчиво к любым «кривым» CFrame)
local function yawOf(body: BasePart): CFrame
	local lv = body.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 1e-3 or flat.Magnitude ~= flat.Magnitude then
		return CFrame.identity
	end
	flat = flat.Unit
	return CFrame.lookAt(Vector3.zero, flat)
end

local function barColor(r: number): Color3
	if r > 0.5 then
		return Color3.fromRGB(110, 230, 90)
	elseif r > 0.25 then
		return Color3.fromRGB(255, 205, 60)
	end
	return Color3.fromRGB(255, 80, 70)
end

local function stroke(parent: Instance, thick: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = thick
	s.Color = color or Color3.new(0, 0, 0)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function makeBar(e: Entry, def: any)
	local boss = e.Rig.Boss
	local g = Instance.new("BillboardGui")
	g.Name = "HpBar"
	g.Size = if boss then UDim2.fromOffset(190, 40) else UDim2.fromOffset(64, 12)
	g.StudsOffset = Vector3.new(0, 0.4, 0)
	g.MaxDistance = if boss then 200 else 70
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.Adornee = e.Rig.Anchor
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
	back.BorderSizePixel = 0
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.fromScale(0.5, 1)
	back.Size = if boss then UDim2.new(1, 0, 0, 14) else UDim2.fromScale(1, 1)
	back.Parent = g
	corner(back, if boss then 6 else 5)
	stroke(back, 2, if boss then Color3.fromRGB(255, 205, 60) else nil)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = if boss then Color3.fromRGB(240, 70, 70) else barColor(1)
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	corner(fill, if boss then 6 else 5)
	e.Fill = fill
	if boss then
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 22)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(255, 215, 90)
		name.Text = "👑 " .. Locale.n(def.Name)
		name.Parent = g
		stroke(name, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		e.BarText = name
	end
	g.Parent = e.Rig.Model
	e.Bar = g
end

local function updateBar(e: Entry, dist: number)
	local fill = e.Fill
	if not (fill and e.Bar) then
		return
	end
	local r = math.clamp(e.Hp / math.max(1, e.MaxHp), 0, 1)
	fill.Size = UDim2.fromScale(r, 1)
	if not e.Rig.Boss then
		fill.BackgroundColor3 = barColor(r)
		-- обычным врагам полоска нужна только в бою или вблизи — меньше шума на экране
		e.Bar.Enabled = e.DeadAt == nil and (r < 0.999 or dist < 26)
	else
		e.Bar.Enabled = e.DeadAt == nil
	end
end

local function setFlash(e: Entry, on: boolean)
	if e.Flashing == on then
		return
	end
	e.Flashing = on
	for _, rp in ipairs(e.Rig.Parts) do
		if rp.Trans < 1 then
			rp.Part.Color = if on then WHITE else rp.Color
		end
	end
end

local function build(m: Model): Entry?
	local body = m:FindFirstChild("Body")
	local def = defOf(m)
	if not (body and body:IsA("BasePart") and def) then
		return nil
	end
	local rig = EnemyVisual.build(def, if m:GetAttribute("EnemyId") == "moonling" then "moonling" else nil)
	local e: Entry = {
		Src = m,
		Body = body,
		Rig = rig,
		Half = body.Size.Y / 2,
		Pos = body.Position,
		Rot = yawOf(body),
		Phase = 0,
		Hp = tonumber(m:GetAttribute("Hp")) or 1,
		MaxHp = tonumber(m:GetAttribute("MaxHp")) or 1,
		Atk = tonumber(m:GetAttribute("Atk")) or 0,
		AtkAt = -10,
		WindDur = if m:GetAttribute("IsRaid") then 0.75 else 0.5,
		FlashUntil = 0,
		Flashing = false,
		Recoil = 0,
		DeadAt = nil,
		Bar = nil,
		Fill = nil,
		BarText = nil,
		Seed = math.random() * 10,
	}
	makeBar(e, def)
	rig.Model.Parent = folder
	return e
end

local function spawnBits(e: Entry, center: Vector3)
	local n = if e.Rig.Boss then 14 else 8
	local s = e.Rig.Scale
	for i = 1, n do
		local p: BasePart = Instance.new("Part")
		p.Name = "Bit"
		local d = s * (0.08 + math.random() * 0.08)
		p.Size = Vector3.new(d, d, d)
		p.Color = if i % 3 == 0 then e.Rig.Accent else (e.Rig.Parts[1] and e.Rig.Parts[1].Color or WHITE)
		p.Material = if i % 3 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = CFrame.new(center)
		p.Parent = folder
		local a = math.random() * math.pi * 2
		local sp = s * (2 + math.random() * 3)
		table.insert(bits, {
			Part = p,
			Vel = Vector3.new(math.cos(a) * sp, s * (3 + math.random() * 3), math.sin(a) * sp),
			Born = os.clock(),
		})
	end
end

local function startDeath(e: Entry)
	if e.DeadAt then
		return
	end
	e.DeadAt = os.clock()
	setFlash(e, false)
	if e.Bar then
		e.Bar.Enabled = false
	end
	spawnBits(e, e.Pos)
	table.insert(dying, e)
end

local function watch(m: Model)
	if entries[m] then
		return
	end
	local e = build(m)
	if not e then
		return
	end
	entries[m] = e
	m:GetAttributeChangedSignal("Hp"):Connect(function()
		local hp = tonumber(m:GetAttribute("Hp")) or 0
		if hp < e.Hp then
			e.FlashUntil = os.clock() + FLASH_TIME
			e.Recoil = 1
		end
		e.Hp = hp
		e.MaxHp = tonumber(m:GetAttribute("MaxHp")) or e.MaxHp
		if hp <= 0 then
			startDeath(e)
		end
	end)
	m:GetAttributeChangedSignal("Atk"):Connect(function()
		e.Atk = tonumber(m:GetAttribute("Atk")) or 0
		e.AtkAt = os.clock()
	end)
end

local function unwatch(m: Model, kill: boolean)
	local e = entries[m]
	if not e then
		return
	end
	entries[m] = nil
	if kill then
		startDeath(e)
	else
		e.Rig.Model:Destroy()
	end
end

-- ---------------------------------------------------------------------------
-- Анимация
-- ---------------------------------------------------------------------------
local ang = CFrame.Angles

local function animate(e: Entry, now: number, dt: number, near: boolean)
	local body = e.Body
	local target = body.Position
	if target.Magnitude > 1e6 or target.X ~= target.X then
		return
	end
	local rig = e.Rig
	local s = rig.Scale
	local prev = e.Pos
	local a = 1 - math.exp(-12 * dt)
	e.Pos = prev:Lerp(target, a)
	e.Rot = e.Rot:Lerp(yawOf(body), a)
	local speed = Vector3.new(e.Pos.X - prev.X, 0, e.Pos.Z - prev.Z).Magnitude / math.max(dt, 1e-3)
	local moving = math.clamp(speed / 6, 0, 1)
	e.Phase += dt * (3 + speed * 1.6 / math.max(1, s * 0.5))
	local t = now + e.Seed
	local ph = e.Phase

	local root = CFrame.new(e.Pos.X, e.Pos.Y - e.Half, e.Pos.Z) * e.Rot
	local bodyY, bodyZ, lean, roll = 0, 0, 0, 0
	local arch = rig.Arch
	if rig.Hover then
		bodyY = math.sin(t * 2.6) * 0.1 * s
		lean = -0.18 * moving
	elseif arch == "slime" then
		bodyY = math.abs(math.sin(ph * 1.2)) * 0.28 * s * moving + math.sin(t * 2.4) * 0.03 * s
		lean = -0.12 * moving
	else
		bodyY = math.abs(math.sin(ph * 2)) * 0.035 * s * moving + math.sin(t * 2) * 0.012 * s
		roll = math.sin(ph) * 0.05 * moving
	end

	-- замах: откинуться назад -> выпад вперёд
	local wind = 0
	local w = (now - e.AtkAt) / e.WindDur
	if w >= 0 and w < 1 then
		if w < 0.65 then
			wind = math.sin(w / 0.65 * math.pi / 2)
			lean += 0.3 * wind
		else
			local k = (w - 0.65) / 0.35
			wind = 1 - k
			lean -= 0.42 * math.sin(k * math.pi)
			bodyZ -= 0.25 * s * math.sin(k * math.pi)
		end
	end
	-- отдача от удара
	if e.Recoil > 0.01 then
		bodyZ += 0.22 * s * e.Recoil
		lean += 0.22 * e.Recoil
		e.Recoil *= math.exp(-10 * dt)
	end
	setFlash(e, now < e.FlashUntil)

	local groups: { [string]: CFrame } = {}
	if near then
		local swing = math.sin(ph * 2) * 0.55 * moving
		for _, l in ipairs(rig.Legs) do
			local amp = if arch == "bug" then 0.6 else 1
			groups[l.G] = ang(math.sin(ph * 2 + l.Ph) * 0.55 * moving * amp, 0, 0)
		end
		for i, g in ipairs(rig.Arms) do
			local side = if i == 1 then 1 else -1
			local raise = -1.6 * wind
			if arch == "bug" then
				groups[g] = ang(0, side * (0.35 * wind + math.sin(t * 3) * 0.05), 0)
			else
				groups[g] = ang(swing * side * 0.8 + raise + math.sin(t * 2) * 0.04, 0, 0)
			end
		end
		for i, g in ipairs(rig.Wings) do
			local side = if i == 1 then -1 else 1
			local speedF = if rig.Hover then 16 else 3
			groups[g] = ang(0, 0, side * math.sin(t * speedF) * (if rig.Hover then 0.6 else 0.15))
		end
		if rig.Pivots.tail then
			groups.tail = ang(0, math.sin(t * (if moving > 0.2 then 9 else 3)) * 0.35, 0)
		end
		if rig.Pivots.head then
			groups.head = ang(math.sin(t * 1.7) * 0.05 - 0.25 * wind, math.sin(t * 0.9) * 0.08, 0)
		end
		if rig.Pivots.orbit then
			groups.orbit = ang(0, t * 2.2, 0)
		end
		if rig.Pivots.flame then
			groups.flame = CFrame.new(0, math.sin(t * 11) * 0.03 * s, 0) * ang(0, t * 3, 0)
		end
		if rig.Pivots.aura then
			groups.aura = ang(0, t * 0.8, 0)
		end
	end
	local bodyCF = CFrame.new(0, bodyY, bodyZ) * ang(lean, 0, roll)
	local cfs = EnemyVisual.pose(rig, root, bodyCF, groups)
	local parts = table.create(#rig.Parts)
	for i, rp in ipairs(rig.Parts) do
		parts[i] = rp.Part
	end
	Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

local function animateDeath(e: Entry, now: number): boolean
	local k = math.clamp((now - (e.DeadAt or now)) / DEATH_TIME, 0, 1)
	local rig = e.Rig
	local shrink = math.max(0.05, 1 - k * k)
	local root = CFrame.new(e.Pos.X, e.Pos.Y - e.Half + k * rig.Scale * 0.6, e.Pos.Z)
		* e.Rot
		* ang(0, k * 4, 0)
	for _, rp in ipairs(rig.Parts) do
		local p = rp.Part
		p.Size = rp.Size * shrink
		if rp.Trans < 1 then
			p.Transparency = rp.Trans + (1 - rp.Trans) * k
		end
		local rel = rp.Rel
		p.CFrame = root * CFrame.new(rel.Position * shrink) * (rel - rel.Position)
	end
	if k >= 1 then
		rig.Model:Destroy()
		return true
	end
	return false
end

local function enemiesFolder(): Instance?
	return Workspace:FindFirstChild("Enemies")
end

local function connectFolder(f: Instance)
	f.ChildRemoved:Connect(function(m)
		if m:IsA("Model") then
			unwatch(m, true)
		end
	end)
end

task.spawn(function()
	local f = Workspace:WaitForChild("Enemies")
	connectFolder(f)
end)

local scanAt = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = Workspace.CurrentCamera
	local here = if hrp then hrp.Position elseif cam then cam.CFrame.Position else Vector3.zero
	-- раз в 0.4 с: построить ближних, снять дальних
	if now >= scanAt then
		scanAt = now + 0.4
		local f = enemiesFolder()
		if f then
			for _, m in ipairs(f:GetChildren()) do
				if m:IsA("Model") then
					local body = m:FindFirstChild("Body")
					if body and body:IsA("BasePart") then
						local d = (body.Position - here).Magnitude
						local hp = tonumber(m:GetAttribute("Hp")) or 1
						if not entries[m] and d < BUILD_DIST and hp > 0 then
							watch(m)
						elseif entries[m] and d > DROP_DIST then
							unwatch(m, false)
						end
					end
				end
			end
		end
	end
	for m, e in pairs(entries) do
		if m.Parent == nil then
			unwatch(m, true)
		elseif not e.DeadAt then
			local d = (e.Body.Position - here).Magnitude
			animate(e, now, math.min(dt, 0.1), d < ANIM_DIST)
			updateBar(e, d)
		end
	end
	for i = #dying, 1, -1 do
		if animateDeath(dying[i], now) then
			table.remove(dying, i)
		end
	end
	for i = #bits, 1, -1 do
		local b = bits[i]
		local age = now - b.Born
		if age > 0.7 or not b.Part.Parent then
			b.Part:Destroy()
			table.remove(bits, i)
		else
			b.Vel += Vector3.new(0, -60, 0) * math.min(dt, 0.1)
			b.Part.CFrame = (b.Part.CFrame + b.Vel * math.min(dt, 0.1)) * ang(0.3, 0.2, 0)
			b.Part.Transparency = math.clamp(age / 0.7, 0, 1)
		end
	end
end)
