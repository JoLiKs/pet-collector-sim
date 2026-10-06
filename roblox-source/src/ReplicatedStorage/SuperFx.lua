--!strict
--[[
	SuperFx — визуал события «Суперсила» на КЛИЕНТЕ (урон и награды считает только сервер).
	  * aura(model)      — неоновая оболочка, PointLight и вращающееся кольцо из сегментов вокруг суперигрока;
	  * transform(pos)   — превращение: вспышка, столб света, расходящееся кольцо (рост делает сервер через ScaleTo);
	  * shockwave(pos,r) — ударная волна: плоский диск и кольцо осколков до радиуса r;
	  * burst(pos)       — остановка: взрыв неоновых частиц;
	  * stun(model, s)   — оглушение: звёздочки над головой.
	Только Part/Neon/PointLight/TweenService — одинаково в Roblox и в эмуляторе roblox2web.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SuperFx = {}

local GOLD = Color3.fromRGB(255, 205, 60)
local ORANGE = Color3.fromRGB(255, 120, 40)
local RING_SEGMENTS = 12

local function folder(): Folder
	local f = Workspace:FindFirstChild("ClientFx")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "ClientFx"
	nf.Parent = Workspace
	return nf
end

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	transparency: number,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Parent = folder()
	return p
end

local function fade(p: BasePart, delay: number, duration: number, goal: { [string]: any }?)
	task.delay(delay, function()
		if not p.Parent then
			return
		end
		local g: { [string]: any } = goal or {}
		g.Transparency = 1
		TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), g)
			:Play()
		task.delay(duration + 0.05, function()
			p:Destroy()
		end)
	end)
end

local function rootOf(model: Model?): BasePart?
	local r = model and model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- ---------------------------------------------------------------------------
-- Аура
-- ---------------------------------------------------------------------------
local aura: { Model: Model, Parts: { Part }, Shell: Part, Conn: RBXScriptConnection }? = nil

function SuperFx.clearAura()
	local a = aura
	if not a then
		return
	end
	aura = nil
	a.Conn:Disconnect()
	for _, p in ipairs(a.Parts) do
		p:Destroy()
	end
end

function SuperFx.auraModel(): Model?
	return if aura then aura.Model else nil
end

function SuperFx.aura(model: Model)
	if aura and aura.Model == model then
		return
	end
	SuperFx.clearAura()
	local root = rootOf(model)
	if not root then
		return
	end
	local parts: { Part } = {}
	local shell = part("SuperAura", Vector3.new(8, 10, 8), root.CFrame, GOLD, 0.82, Enum.PartType.Ball)
	table.insert(parts, shell)
	local light = Instance.new("PointLight")
	light.Name = "SuperLight"
	light.Color = GOLD
	light.Brightness = 3
	light.Range = 18
	light.Parent = shell
	for i = 1, RING_SEGMENTS do
		table.insert(
			parts,
			part(
				"SuperRing",
				Vector3.new(0.35, 0.35, 2.1),
				root.CFrame,
				if i % 2 == 0 then ORANGE else GOLD,
				0.1
			)
		)
	end
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local r = rootOf(model)
		if not r or not model.Parent then
			SuperFx.clearAura()
			return
		end
		local t = os.clock() - t0
		local scale = 1
		pcall(function()
			scale = model:GetScale()
		end)
		local center = r.Position + Vector3.new(0, 0.4 * scale, 0)
		local pulse = 1 + 0.06 * math.sin(t * 6)
		shell.Size = Vector3.new(4.6, 6.4, 4.6) * scale * pulse
		shell.CFrame = CFrame.new(center)
		local radius = 3.3 * scale
		local ringY = center.Y - 1.2 * scale + 0.5 * math.sin(t * 2)
		for i = 1, RING_SEGMENTS do
			local a = t * 2.4 + (i / RING_SEGMENTS) * math.pi * 2
			local pos = Vector3.new(center.X + math.cos(a) * radius, ringY, center.Z + math.sin(a) * radius)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			parts[i + 1].CFrame = CFrame.lookAt(pos, pos + tangent)
		end
	end)
	aura = { Model = model, Parts = parts, Shell = shell, Conn = conn }
end

-- ---------------------------------------------------------------------------
-- Разовые эффекты
-- ---------------------------------------------------------------------------
function SuperFx.transform(pos: Vector3)
	local flash = part(
		"SuperFlash",
		Vector3.new(2, 2, 2),
		CFrame.new(pos),
		Color3.fromRGB(255, 250, 200),
		0.05,
		Enum.PartType.Ball
	)
	fade(flash, 0, 0.5, { Size = Vector3.new(16, 16, 16) })
	local pillar =
		part("SuperPillar", Vector3.new(3, 40, 3), CFrame.new(pos + Vector3.new(0, 18, 0)), GOLD, 0.3)
	fade(pillar, 0.15, 0.8, { Size = Vector3.new(0.4, 60, 0.4) })
	SuperFx.shockwave(pos - Vector3.new(0, 2.5, 0), 14)
end

function SuperFx.shockwave(pos: Vector3, radius: number)
	local ground = pos - Vector3.new(0, 2.6, 0)
	local disc = part(
		"Shockwave",
		Vector3.new(0.3, 2, 2),
		CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 230, 150),
		0.35,
		Enum.PartType.Cylinder
	)
	fade(disc, 0, 0.45, { Size = Vector3.new(0.3, radius * 2, radius * 2) })
	local n = 18
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local start = ground + dir * 1.5 + Vector3.new(0, 0.6, 0)
		local shard =
			part("ShockShard", Vector3.new(0.5, 0.5, 1.6), CFrame.lookAt(start, start + dir), ORANGE, 0.05)
		fade(shard, 0, 0.45, { CFrame = CFrame.lookAt(start + dir * radius, start + dir * (radius + 1)) })
	end
end

function SuperFx.burst(pos: Vector3)
	local rng = Random.new()
	local flash = part(
		"StopFlash",
		Vector3.new(3, 3, 3),
		CFrame.new(pos),
		Color3.fromRGB(255, 255, 255),
		0,
		Enum.PartType.Ball
	)
	fade(flash, 0, 0.4, { Size = Vector3.new(14, 14, 14) })
	for _ = 1, 28 do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.1, 1.2), rng:NextNumber(-1, 1))
		if v.Magnitude < 0.05 then
			v = Vector3.new(0, 1, 0)
		end
		v = v.Unit
		local color = if rng:NextNumber() < 0.5 then GOLD else Color3.fromRGB(255, 90, 60)
		local s = rng:NextNumber(0.5, 1.1)
		local p = part("StopParticle", Vector3.new(s, s, s), CFrame.new(pos), color, 0)
		fade(p, 0.05, rng:NextNumber(0.6, 1.0), {
			CFrame = CFrame.new(pos + v * rng:NextNumber(7, 14))
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			Size = Vector3.new(0.2, 0.2, 0.2),
		})
	end
	SuperFx.shockwave(pos, 10)
end

function SuperFx.stun(model: Model, seconds: number)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local stars: { Part } = {}
	for i = 1, 3 do
		table.insert(
			stars,
			part(
				"StunStar",
				Vector3.new(0.6, 0.6, 0.6),
				head.CFrame,
				Color3.fromRGB(255, 240, 90),
				0,
				Enum.PartType.Ball
			)
		)
		local _ = i
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > seconds or not head.Parent then
			if conn then
				conn:Disconnect()
			end
			for _, s in ipairs(stars) do
				s:Destroy()
			end
			return
		end
		for i, s in ipairs(stars) do
			local a = t * 6 + i * (math.pi * 2 / 3)
			s.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.3, 1.3, math.sin(a) * 1.3))
		end
	end)
end

return SuperFx
