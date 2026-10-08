--!strict
--[[
	SeaChestService (v3.1) — морской сундук в хабе.
	  * раз в Config.SEA_CHEST.INTERVAL секунд появляется в случайном свободном месте хаба (SeaChestLogic.pickSpot:
	    вне спавна, порталов, станций, NPC и яиц + проверка мира GetPartBoundsInBox — не внутри построек и декора);
	    неоткрытый старый сундук при этом исчезает;
	  * о появлении сообщает только тихий звук в точке сундука (Remotes "SeaChest" -> клиент, Config.SOUNDS.CHEST_SPAWN);
	  * открыть: ProximityPrompt или касание. Всё решает сервер: живой персонаж настоящего игрока с загруженными
	    данными, не дальше OPEN_DISTANCE, не чаще раза в 0.3 с; первый открывший получает награду, сундук сразу
	    помечается открытым (одна выдача). ИИ-боты — не Player, поэтому открыть не могут;
	  * модель — ServerStorage.SeaChest (assets/models/SeaChest.rbxmx через Rojo — XML-копия присланного
	    assets/models/source/SeaChest.rbxm; скрипты, если появятся, удаляются).
	    Нет модели (веб-демо: roblox2web не читает .rbxm/.rbxmx) — сундук собирается из деталей.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Locale)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local SeaChestLogic = require(script.Parent.SeaChestLogic)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)

local SeaChestService = {}

type Chest = { Model: Model, Pos: Vector3, Opened: boolean, Id: number, Lid: BasePart? }

local rng = Random.new()
local folder: Folder? = nil
local current: Chest? = nil
local counter = 0
local lastTry: { [Player]: number } = {}

SeaChestService.stats = { Spawned = 0, Opened = 0 }

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "SeaChests"
	f.Parent = Workspace
	folder = f
	return f
end

local function part(
	m: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

-- запасная модель (дно на y = 0): тёмное дерево, бирюзовые «морские» полосы и ракушка-замок
local function buildFallback(): Model
	local m = Instance.new("Model")
	local wood, band = Color3.fromRGB(110, 72, 44), Color3.fromRGB(70, 190, 185)
	local body =
		part(m, "body_geom", Vector3.new(3.6, 2.2, 2.6), CFrame.new(0, 1.1, 0), wood, Enum.Material.Wood)
	part(
		m,
		"lid_geom",
		Vector3.new(3.7, 1, 2.7),
		CFrame.new(0, 2.7, 0),
		Color3.fromRGB(125, 84, 50),
		Enum.Material.Wood
	)
	for _, dx in ipairs({ -1.2, 1.2 }) do
		part(m, "Band", Vector3.new(0.35, 3.25, 2.75), CFrame.new(dx, 1.62, 0), band, Enum.Material.Metal)
	end
	part(
		m,
		"Shell",
		Vector3.new(0.7, 0.7, 0.3),
		CFrame.new(0, 2.1, -1.4),
		Color3.fromRGB(255, 225, 200),
		Enum.Material.SmoothPlastic
	)
	m.PrimaryPart = body
	return m
end

local function lidOf(m: Model): BasePart?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "lid_geom" or d.Name == "Lid") then
			return d
		end
	end
	return nil
end

function SeaChestService.makeModel(): (Model, boolean)
	local src = ServerStorage:FindFirstChild("SeaChest")
	local m: Model
	local fromAsset = false
	if src and src:IsA("Model") then
		m = src:Clone()
		fromAsset = true
		-- в присланной модели скриптов нет (проверено), но на всякий случай: никакого чужого кода в мире
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		pcall(function()
			m:ScaleTo(1.4) -- модель ~2.9 studs — чуть крупнее, чтобы сундук было видно в хабе
		end)
	else
		m = buildFallback()
	end
	m.Name = "SeaChest"
	local biggest: BasePart? = nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true
			d.CanTouch = true
			if not biggest or d.Size.Magnitude > biggest.Size.Magnitude then
				biggest = d
			end
		end
	end
	if not m.PrimaryPart and biggest then
		m.PrimaryPart = biggest
	end
	return m, fromAsset
end

local function groundY(pos: Vector3): number
	local ok, y = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { getFolder() }
		local hit = Workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)
		return if hit then hit.Position.Y else 0
	end)
	return if ok and type(y) == "number" and y < 10 then y else 0
end

-- проверка мира: в объёме сундука нет видимых/твёрдых деталей (здания, деревья, фонари, NPC, порталы)
local function isFree(pos: Vector3): boolean
	local ok, free = pcall(function()
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip: { Instance } = { getFolder() }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(skip, p.Character)
			end
		end
		for _, name in ipairs({ "AiBots", "Pets", "GoldenRain" }) do
			local f = Workspace:FindFirstChild(name)
			if f then
				table.insert(skip, f)
			end
		end
		params.FilterDescendantsInstances = skip
		local c = Config.SEA_CHEST.CLEARANCE
		local parts =
			Workspace:GetPartBoundsInBox(CFrame.new(pos + Vector3.new(0, 4, 0)), Vector3.new(c, 6, c), params)
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") and (p.CanCollide or p.Transparency < 0.95) then
				return false
			end
		end
		return true
	end)
	return not ok or free == true
end

function SeaChestService.current(): Chest?
	return current
end

function SeaChestService.despawn()
	local c = current
	current = nil
	if c and c.Model.Parent then
		c.Model:Destroy()
	end
end

-- поставить сундук в точку pos (y игнорируется — по земле); без pos — случайное свободное место хаба
function SeaChestService.spawn(pos: Vector3?): Chest?
	local spot = pos or SeaChestLogic.pickSpot(rng, WorldBuilder.getHubBlockers(), isFree)
	if not spot then
		return nil
	end
	SeaChestService.despawn()
	counter += 1
	local m, fromAsset = SeaChestService.makeModel()
	local ground = Vector3.new(spot.X, groundY(spot), spot.Z)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local ok = pcall(function()
		local bcf, size = m:GetBoundingBox()
		local lift = m:GetPivot().Position.Y - (bcf.Position.Y - size.Y / 2)
		m:PivotTo(CFrame.new(ground + Vector3.new(0, lift, 0)) * yaw)
	end)
	if not ok and m.PrimaryPart then
		m.PrimaryPart.CFrame = CFrame.new(ground + Vector3.new(0, 1.1, 0))
	end
	m:SetAttribute("SeaChest", counter)
	m:SetAttribute("FromAsset", fromAsset)
	local chest: Chest = { Model = m, Pos = ground, Opened = false, Id = counter, Lid = lidOf(m) }
	local body = m.PrimaryPart
	if body then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OpenPrompt"
		Locale.setWorld(prompt, "prompt.open", nil, "ActionText")
		Locale.setWorld(prompt, "world.sea_chest", nil, "ObjectText")
		prompt.HoldDuration = Config.SEA_CHEST.PROMPT_HOLD
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = body
		prompt.Triggered:Connect(function(player: Player)
			SeaChestService.tryOpen(player, chest.Id)
		end)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Touched:Connect(function(hit: BasePart)
				local model = hit:FindFirstAncestorOfClass("Model")
				local player = model and Players:GetPlayerFromCharacter(model)
				if player then
					SeaChestService.tryOpen(player, chest.Id)
				end
			end)
		end
	end
	m.Parent = getFolder()
	current = chest
	SeaChestService.stats.Spawned += 1
	Remotes.getEvent("SeaChest"):FireAllClients("Spawn", ground)
	return chest
end

local function describeAll(loot: { { [string]: any } }, lang: string): string
	local parts = {}
	for _, r in ipairs(loot) do
		local s = Economy.describe(r, lang)
		if r.Bonus then
			s = Locale.get(lang, "seachest.bonus", { reward = s })
		end
		table.insert(parts, s)
	end
	return table.concat(parts, ", ")
end

local function openAnim(c: Chest)
	local lid = c.Lid
	if lid then
		pcall(function()
			lid.CanCollide = false
			TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
				CFrame = lid.CFrame * CFrame.new(0, 1.2, 0.6) * CFrame.Angles(math.rad(-35), 0, 0),
			}):Play()
		end)
	end
	task.delay(2.5, function()
		if c.Model.Parent then
			for _, d in ipairs(c.Model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					pcall(function()
						TweenService:Create(d, TweenInfo.new(0.8), { Transparency = 1 }):Play()
					end)
				end
			end
		end
		task.delay(0.9, function()
			if c.Model.Parent then
				c.Model:Destroy()
			end
		end)
	end)
end

-- Попытка открыть. Возвращает ok и причину отказа (для тестов): gone | rate | nodata | dead | far
function SeaChestService.tryOpen(player: Player, chestId: number?): (boolean, string?)
	local c = current
	if not c or c.Opened or (chestId ~= nil and chestId ~= c.Id) then
		return false, "gone"
	end
	local now = os.clock()
	if now - (lastTry[player] or -1) < 0.3 then
		return false, "rate"
	end
	lastTry[player] = now
	local data = DataService.get(player)
	local session = Session.get(player)
	if not data or not session or not session.Ready or player.Parent ~= Players then
		return false, "nodata"
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return false, "dead"
	end
	local d = Vector3.new(root.Position.X - c.Pos.X, 0, root.Position.Z - c.Pos.Z)
	if d.Magnitude > Config.SEA_CHEST.OPEN_DISTANCE or math.abs(root.Position.Y - c.Pos.Y) > 20 then
		return false, "far"
	end
	-- первый открывший: помечаем до выдачи (дальше нет yield — вторая выдача невозможна)
	c.Opened = true
	current = nil
	local loot = SeaChestLogic.loot(rng, { PerClick = Economy.getPerClick(player, data), Zones = data.Zones })
	for _, r in ipairs(loot) do
		Economy.grant(player, r)
	end
	State.markCore(player)
	SeaChestService.stats.Opened += 1
	c.Model:SetAttribute("OpenedBy", player.UserId)
	for _, dsc in ipairs(c.Model:GetDescendants()) do
		if dsc:IsA("ProximityPrompt") then
			dsc.Enabled = false
		end
	end
	Notify.send(
		player,
		Locale.m("seachest.reward", { reward = describeAll(loot, Locale.langOf(player)) }),
		"reward"
	)
	Remotes.getEvent("SeaChest"):FireAllClients("Open", c.Pos)
	openAnim(c)
	return true, nil
end

function SeaChestService.init()
	Players.PlayerRemoving:Connect(function(p)
		lastTry[p] = nil
	end)
	if not Config.SEA_CHEST.ENABLED or Workspace:GetAttribute("SeaChestPaused") == true then
		return
	end
	task.spawn(function()
		task.wait(Config.SEA_CHEST.FIRST_DELAY)
		while true do
			if Workspace:GetAttribute("SeaChestPaused") ~= true then
				SeaChestService.spawn()
			end
			task.wait(Config.SEA_CHEST.INTERVAL)
		end
	end)
end

return SeaChestService
