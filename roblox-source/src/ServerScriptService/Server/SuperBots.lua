--!strict
--[[
	SuperBots — серверные боты-игроки для события «Суперсила» (только при Config.DEMO_BOTS).
	Нужны, когда игрок на сервере один (веб-демо): 2–3 бота бегают по хабу, охотятся на суперигрока
	(подбегают и бьют — урон считает SuperpowerService) и сами иногда становятся суперигроками,
	которых должен останавливать живой игрок. Риг — стандартный R6 (Motor6D, Humanoid:MoveTo), как у игроков.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Locale = require(Shared.Locale)
local Remotes = require(Shared.Remotes)
local ZoneData = require(Shared.ZoneData)

local Knockback = require(script.Parent.Knockback)
local SuperpowerService = require(script.Parent.SuperpowerService)

local C = Config.SUPERPOWER

local SuperBots = {}

export type Bot = {
	Key: string,
	Name: string,
	Index: number,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Unit: SuperpowerService.Unit,
	NextWander: number,
	Home: Vector3,
}

local bots: { Bot } = {}
local rng = Random.new()

local SHIRTS = {
	Color3.fromRGB(231, 76, 60),
	Color3.fromRGB(46, 204, 113),
	Color3.fromRGB(155, 89, 182),
	Color3.fromRGB(241, 196, 15),
}

-- Стандартный R6-риг: те же имена частей и Motor6D (C0/C1), что у персонажа Roblox
local function buildRig(name: string, shirt: Color3): (Model, BasePart, Humanoid)
	local m = Instance.new("Model")
	m.Name = "Bot_" .. name
	local skin = Color3.fromRGB(245, 205, 165)
	local pants = Color3.fromRGB(44, 62, 80)
	local function part(n: string, size: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = n ~= "HumanoidRootPart"
		p.Parent = m
		return p
	end
	local hrp = part("HumanoidRootPart", Vector3.new(2, 2, 1), shirt)
	hrp.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), shirt)
	local head = part("Head", Vector3.new(2, 1, 1), skin)
	local la = part("Left Arm", Vector3.new(1, 2, 1), skin) -- l10n-ok: имя части R6
	local ra = part("Right Arm", Vector3.new(1, 2, 1), skin) -- l10n-ok: имя части R6
	local ll = part("Left Leg", Vector3.new(1, 2, 1), pants) -- l10n-ok: имя части R6
	local rl = part("Right Leg", Vector3.new(1, 2, 1), pants) -- l10n-ok: имя части R6
	local function motor(n: string, parent: Instance, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local j = Instance.new("Motor6D")
		j.Name = n
		j.Part0 = p0
		j.Part1 = p1
		j.C0 = c0
		j.C1 = c1
		j.Parent = parent
	end
	local NK = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local RS = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	local LS = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	motor("RootJoint", hrp, hrp, torso, NK, NK)
	motor("Right Shoulder", torso, torso, ra, CFrame.new(1, 0.5, 0) * RS, CFrame.new(-0.5, 0.5, 0) * RS) -- l10n-ok: имя части R6
	motor("Left Shoulder", torso, torso, la, CFrame.new(-1, 0.5, 0) * LS, CFrame.new(0.5, 0.5, 0) * LS) -- l10n-ok: имя части R6
	motor("Right Hip", torso, torso, rl, CFrame.new(1, -1, 0) * RS, CFrame.new(0.5, 1, 0) * RS) -- l10n-ok: имя части R6
	motor("Left Hip", torso, torso, ll, CFrame.new(-1, -1, 0) * LS, CFrame.new(-0.5, 1, 0) * LS) -- l10n-ok: имя части R6
	motor("Neck", torso, torso, head, CFrame.new(0, 1, 0) * NK, CFrame.new(0, -0.5, 0) * NK)
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 0
	hum.WalkSpeed = C.BOT_SPEED
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = m
	m.PrimaryPart = hrp
	-- табличка над головой: «Бот Max» (переводит WorldLocalizer)
	local g = Instance.new("BillboardGui")
	g.Name = "OverheadTag"
	g.Size = UDim2.fromOffset(160, 26)
	g.StudsOffset = Vector3.new(0, 2.4, 0)
	g.MaxDistance = 60
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	local l = Instance.new("TextLabel")
	l.Name = "NameLabel"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(200, 230, 255)
	l.TextStrokeTransparency = 0.4
	l.ZIndex = 1
	Locale.setWorld(l, "bot.tag", { player = name })
	l.Parent = g
	g.Parent = head
	m:SetAttribute("IsBot", true)
	return m, hrp, hum
end

local function moveTo(b: Bot, pos: Vector3)
	b.Humanoid:MoveTo(Vector3.new(pos.X, b.Root.Position.Y - 3, pos.Z))
end

local function swingFx(b: Bot)
	local ev = Remotes.getEvent("CombatFx")
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		ev:FireClient(p, "Swing", b.Model)
	end
end

local function nearestOther(b: Bot, range: number): Vector3?
	local best, bd = nil, range
	local players = game:GetService("Players"):GetPlayers()
	local function consider(r: BasePart?)
		if r and r ~= b.Root then
			local d = (r.Position - b.Root.Position).Magnitude
			if d < bd then
				best, bd = r.Position, d
			end
		end
	end
	for _, p in ipairs(players) do
		local character = p.Character
		consider(character and character:FindFirstChild("HumanoidRootPart") :: BasePart?)
	end
	for _, o in ipairs(bots) do
		consider(o.Root)
	end
	return best
end

local function think(b: Bot, now: number)
	local u = b.Unit
	local hum = b.Humanoid
	if b.Model.Parent == nil then
		return
	end
	local isSuper = SuperpowerService.isSuperKey(b.Key)
	local base = C.BOT_SPEED * (if isSuper then C.SPEED_MULT else 1)
	if u.StunnedUntil > now then
		hum.WalkSpeed = 0
		return
	end
	hum.WalkSpeed = base
	local pos = b.Root.Position
	local active = SuperpowerService.isActive()
	local targetRoot = SuperpowerService.targetRoot()
	if active and isSuper then
		-- суперигрок-бот: идёт на ближайшего охотника и бьёт ударной волной
		local foe = nearestOther(b, 70)
		if foe then
			if (foe - pos).Magnitude <= C.SLAM_RANGE * 0.7 then
				if SuperpowerService.superSlam(b.Key) then
					swingFx(b)
				end
			end
			moveTo(b, foe)
		elseif now >= b.NextWander then
			b.NextWander = now + rng:NextNumber(2, 4)
			moveTo(b, b.Home + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30)))
		end
	elseif active and targetRoot then
		local tp = targetRoot.Position
		local d = (tp - pos).Magnitude
		if d > 140 then
			-- цель в другом мире: «бежим» туда (телепорт на 30 стадов от цели)
			local ang = b.Index * 2.1
			b.Model:PivotTo(CFrame.new(tp + Vector3.new(math.cos(ang) * 30, 3, math.sin(ang) * 30)))
			return
		end
		local ang = b.Index * 2.1 + now * 0.3
		moveTo(b, tp + Vector3.new(math.cos(ang) * 6, 0, math.sin(ang) * 6))
		if d <= C.HIT_RANGE * 0.85 and SuperpowerService.botHit(b.Key) then
			swingFx(b)
		end
	else
		if (pos - b.Home).Magnitude > ZoneData.HUB_RADIUS + 60 then
			b.Model:PivotTo(CFrame.new(b.Home + Vector3.new(0, 3, 0)))
			return
		end
		if now >= b.NextWander then
			b.NextWander = now + rng:NextNumber(3, 6)
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(14, 48)
			moveTo(b, Vector3.new(math.cos(a) * r, 0, 20 + math.sin(a) * r * 0.6))
		end
	end
end

function SuperBots.list(): { Bot }
	return bots
end

-- Создать ботов (идемпотентно). init вызывает это только при Config.DEMO_BOTS; тесты — напрямую.
function SuperBots.spawn()
	if #bots > 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = Workspace
	for i = 1, math.min(C.BOT_COUNT, #C.BOT_NAMES) do
		local name = C.BOT_NAMES[i]
		local home = Vector3.new(-24 + (i - 1) * 24, 0, 40)
		local m, root, hum = buildRig(name, SHIRTS[(i - 1) % #SHIRTS + 1])
		m:PivotTo(CFrame.new(home + Vector3.new(0, 3.2, 0)))
		m.Parent = folder
		pcall(function()
			root:SetNetworkOwner(nil) -- физикой ботов владеет сервер
		end)
		local key = "bot" .. i
		local b: Bot
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
				-- v2.4 (аудит С3): дистанция ограничена препятствиями и опорой под ногами
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
		b = {
			Key = key,
			Name = name,
			Index = i,
			Model = m,
			Root = root,
			Humanoid = hum,
			Unit = unit,
			NextWander = 0,
			Home = home,
		}
		table.insert(bots, b)
		SuperpowerService.addUnit(unit)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			local now = os.clock()
			for _, b in ipairs(bots) do
				think(b, now)
			end
		end
	end)
end

function SuperBots.init()
	if Config.DEMO_BOTS then
		SuperBots.spawn()
	end
end

return SuperBots
