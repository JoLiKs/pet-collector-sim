--!strict
--[[
	AttackFx — визуал удара на КЛИЕНТЕ (урон считает только сервер).
	  * замах правой рукой через Motor6D.C0 (R6: Torso["Right Shoulder"], R15: RightUpperArm.RightShoulder) + поворот торса (RootJoint/Root);
	  * меч из примитивов в руке на время удара;
	  * след удара — неоновый полумесяц из сегментов, пролетает справа налево и тает (Transparency);
	  * лёгкий рывок вперёд (только свой персонаж), рывок питомцев (PetFollower читает AttackFx.lastSwing);
	  * вспышка и искры при попадании (AttackFx.impact).
	Только стандартные API: Motor6D, CFrame, TweenService, Part/Neon — одинаково в Roblox и в эмуляторе roblox2web.
]]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AttackFx = {}

AttackFx.SWING_TIME = 0.38
AttackFx.lastSwing = {} :: { [any]: { T: number, Dir: Vector3 } } -- ключ: Player или модель бота

local WINDUP = 0.07
local SLASH = 0.11
local ARC_RADIUS = 5.2
local ARC_SEGMENTS = 11

local running: { [Model]: { Stop: () -> () } } = {}

local function fxFolder(): Folder
	local f = Workspace:FindFirstChild("ClientFx")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "ClientFx"
	nf.Parent = Workspace
	return nf
end

local function fxPart(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number): Part
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
	p.Parent = fxFolder()
	return p
end

local function fadeAndDestroy(p: BasePart, delay: number, duration: number, goal: { [string]: any }?)
	task.delay(delay, function()
		if not p.Parent then
			return
		end
		local g: { [string]: any } = goal or {}
		g.Transparency = 1
		local tw = TweenService:Create(
			p,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			g
		)
		tw:Play()
		task.delay(duration + 0.05, function()
			p:Destroy()
		end)
	end)
end

local function findMotor(
	character: Model,
	r6Parent: string,
	r6Name: string,
	r15Parent: string,
	r15Name: string
): Motor6D?
	local a = character:FindFirstChild(r6Parent)
	local m = a and a:FindFirstChild(r6Name)
	if m and m:IsA("Motor6D") then
		return m
	end
	local b = character:FindFirstChild(r15Parent)
	local m2 = b and b:FindFirstChild(r15Name)
	if m2 and m2:IsA("Motor6D") then
		return m2
	end
	return nil
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Ключевые позы руки в пространстве торса: yaw (вокруг вертикали), pitch (подъём вперёд), twist торса
local POSES = {
	rest = { Yaw = 0, Pitch = 0, Twist = 0 },
	windup = { Yaw = -1.5, Pitch = 2.3, Twist = -0.35 },
	slash = { Yaw = 1.25, Pitch = 1.3, Twist = 0.42 },
}

-- Поза в момент t (секунды от начала удара)
function AttackFx.poseAt(t: number): (number, number, number)
	local a, b, k
	if t < WINDUP then
		a, b, k = POSES.rest, POSES.windup, t / WINDUP
	elseif t < WINDUP + SLASH then
		local u = (t - WINDUP) / SLASH
		a, b, k = POSES.windup, POSES.slash, 1 - (1 - u) * (1 - u) -- резкий удар с замедлением в конце
	elseif t < AttackFx.SWING_TIME then
		a, b, k = POSES.slash, POSES.rest, (t - WINDUP - SLASH) / (AttackFx.SWING_TIME - WINDUP - SLASH)
	else
		return 0, 0, 0
	end
	return lerp(a.Yaw, b.Yaw, k), lerp(a.Pitch, b.Pitch, k), lerp(a.Twist, b.Twist, k)
end

-- Меч из примитивов: позиционируется каждый кадр по руке (без Weld — одинаково в Roblox и эмуляторе)
local function buildSword(): { Parts: { { Part: Part, Offset: CFrame } } }
	local parts = {}
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = fxPart(name, size, CFrame.new(), color, 0)
		p.Material = material
		table.insert(parts, { Part = p, Offset = offset })
	end
	add(
		"SwordHandle",
		Vector3.new(0.22, 0.75, 0.22),
		CFrame.new(0, 0.1, 0),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	add(
		"SwordGuard",
		Vector3.new(0.28, 0.16, 1.0),
		CFrame.new(0, -0.32, 0),
		Color3.fromRGB(230, 190, 70),
		Enum.Material.SmoothPlastic
	)
	add(
		"SwordBlade",
		Vector3.new(0.14, 3.2, 0.42),
		CFrame.new(0, -2.0, 0),
		Color3.fromRGB(205, 215, 230),
		Enum.Material.SmoothPlastic
	)
	add(
		"SwordEdge",
		Vector3.new(0.06, 3.1, 0.1),
		CFrame.new(0, -2.0, -0.24),
		Color3.fromRGB(200, 240, 255),
		Enum.Material.Neon
	)
	return { Parts = parts }
end

-- След удара: полумесяц из неоновых сегментов, появляется справа налево и тает
function AttackFx.slashArc(origin: CFrame)
	-- плоскость дуги наклонена к камере (видна сзади-сверху) и по диагонали: удар сверху-справа вниз-влево
	local arcCF = origin * CFrame.new(0, 0.9, -0.6) * CFrame.Angles(math.rad(38), 0, math.rad(-24))
	local a0, a1 = math.rad(-80), math.rad(85)
	local function point(a: number, r: number): Vector3
		return (arcCF * CFrame.new(-math.sin(a) * r, 0, -math.cos(a) * r)).Position
	end
	local up = arcCF.UpVector
	for i = 0, ARC_SEGMENTS - 1 do
		local k = i / (ARC_SEGMENTS - 1)
		local aa = lerp(a0, a1, i / ARC_SEGMENTS)
		local ab = lerp(a0, a1, (i + 1) / ARC_SEGMENTS)
		local pa, pb = point(aa, ARC_RADIUS), point(ab, ARC_RADIUS)
		local mid = (pa + pb) / 2
		local len = (pb - pa).Magnitude * 1.18
		local width = 0.25 + 1.55 * math.sin(math.pi * k) -- толще в середине — полумесяц
		local cf = CFrame.lookAt(mid, pb, up)
		local appear = SLASH * k * 0.9
		local core = fxPart("SlashArc", Vector3.new(width, 0.1, len), cf, Color3.fromRGB(255, 205, 70), 1)
		local glow = fxPart(
			"SlashGlow",
			Vector3.new(width * 1.9, 0.05, len * 1.05),
			cf * CFrame.new(width * 0.35, 0, 0),
			Color3.fromRGB(90, 175, 255),
			1
		)
		task.delay(appear, function()
			if core.Parent then
				core.Transparency = 0
				glow.Transparency = 0.35
			end
		end)
		local outward = (mid - arcCF.Position).Unit * 0.9
		fadeAndDestroy(core, appear + 0.05, 0.22, { CFrame = cf + outward })
		fadeAndDestroy(glow, appear + 0.03, 0.2, { CFrame = cf + outward * 1.3 })
	end
end

-- Вспышка и искры в точке попадания
function AttackFx.impact(pos: Vector3, dir: Vector3?)
	local d = if dir and dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	local flash =
		fxPart("HitFlash", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos), Color3.fromRGB(255, 240, 160), 0.1)
	flash.Shape = Enum.PartType.Ball
	fadeAndDestroy(flash, 0, 0.18, { Size = Vector3.new(4.5, 4.5, 4.5) })
	local rng = Random.new()
	for _ = 1, 8 do
		local spread = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		local v = (d + spread * 0.9).Unit
		local cf = CFrame.lookAt(pos, pos + v)
		local spark = fxPart("HitSpark", Vector3.new(0.18, 0.18, 0.9), cf, Color3.fromRGB(255, 200, 80), 0)
		fadeAndDestroy(spark, 0, 0.3, { CFrame = cf + v * rng:NextNumber(2.5, 4.5) })
	end
end

local function nearestEnemyPos(from: Vector3, range: number): Vector3?
	local folder = Workspace:FindFirstChild("Enemies")
	if not folder then
		return nil
	end
	local best, bd = nil, range
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and (m:GetAttribute("Hp") or 0) > 0 then
			local p = m:GetPivot().Position
			local d = (Vector3.new(p.X, from.Y, p.Z) - from).Magnitude
			if d < bd then
				best, bd = p, d
			end
		end
	end
	return best
end

-- Удар персонажа игрока (или модели бота). isLocal = свой персонаж (поворот к цели и рывок делаем только для него).
function AttackFx.swing(who: Player | Model, isLocal: boolean)
	local character: Model? = if typeof(who) == "Instance" and who:IsA("Player")
		then (who :: Player).Character
		else who :: Model
	local player = who
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local prev = running[character]
	if prev then
		prev.Stop()
	end

	-- направление удара: к ближайшему врагу, иначе куда смотрит камера (свой) / персонаж (чужой)
	local dir = root.CFrame.LookVector
	if isLocal then
		local target = nearestEnemyPos(root.Position, 24)
		if target then
			dir = target - root.Position
		else
			local cam = Workspace.CurrentCamera
			if cam then
				dir = cam.CFrame.LookVector
			end
		end
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	if isLocal then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	AttackFx.lastSwing[player] = { T = os.clock(), Dir = flat }

	local shoulder = findMotor(character, "Torso", "Right Shoulder", "RightUpperArm", "RightShoulder")
	local rootJoint = findMotor(character, "HumanoidRootPart", "RootJoint", "LowerTorso", "Root")
	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	local shoulderBase = shoulder and shoulder.C0
	local rootBase = rootJoint and rootJoint.C0
	local sword = buildSword()
	local t0 = os.clock()
	local arcDone, lunged = false, 0
	local conn: RBXScriptConnection? = nil

	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if shoulder and shoulderBase then
			shoulder.C0 = shoulderBase
		end
		if rootJoint and rootBase then
			rootJoint.C0 = rootBase
		end
		for _, s in ipairs(sword.Parts) do
			s.Part:Destroy()
		end
		running[character] = nil
	end
	running[character] = { Stop = stop }

	local function step()
		local t = os.clock() - t0
		if t >= AttackFx.SWING_TIME or not character.Parent then
			stop()
			return
		end
		local yaw, pitch, twist = AttackFx.poseAt(t)
		if shoulder and shoulderBase then
			shoulder.C0 = CFrame.new(shoulderBase.Position)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(pitch, 0, 0)
				* shoulderBase.Rotation
		end
		if rootJoint and rootBase then
			rootJoint.C0 = CFrame.new(rootBase.Position) * CFrame.Angles(0, twist, 0) * rootBase.Rotation
		end
		-- меч в руке: рукоять в кисти, клинок продолжает руку с наклоном вперёд
		if arm and arm:IsA("BasePart") then
			local grip = arm.CFrame * CFrame.new(0, -0.85, 0) * CFrame.Angles(math.rad(30), 0, 0)
			for _, s in ipairs(sword.Parts) do
				s.Part.CFrame = grip * s.Offset
			end
		end
		if not arcDone and t >= WINDUP then
			arcDone = true
			AttackFx.slashArc(CFrame.lookAt(root.Position, root.Position + flat))
		end
		-- рывок вперёд в фазе удара (только свой персонаж — его позицией владеет клиент)
		if isLocal and t >= WINDUP and lunged < 4 then
			lunged += 1
			root.CFrame = root.CFrame + flat * 0.4
		end
	end
	conn = RunService.RenderStepped:Connect(step)
	step()
end

-- Смещение питомца при рывке (0..1 по времени удара)
function AttackFx.petLunge(player: Player): Vector3
	local s = AttackFx.lastSwing[player]
	if not s then
		return Vector3.zero
	end
	local t = (os.clock() - s.T) / 0.4
	if t < 0 or t > 1 then
		return Vector3.zero
	end
	local k = math.sin(math.pi * t)
	return s.Dir * (3.5 * k) + Vector3.new(0, 0.9 * k, 0)
end

return AttackFx
