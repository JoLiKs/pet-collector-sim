--!strict
-- Добыча ресурсов: деревья, камни, жилы, кусты, кристаллы и сундуки в мирах. Узлы возрождаются по таймеру.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local Remotes = require(Shared.Remotes)
local ResourceData = require(Shared.ResourceData)
local ZoneData = require(Shared.ZoneData)

local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local State = require(script.Parent.State)

local ResourceService = {}

type Node = { Model: Model, Zone: string, Kind: string, Depleted: boolean, Chest: boolean, Pos: Vector3 }

local nodes: { Node } = {}
local nodeOf: { [Instance]: Node } = {}
local rng = Random.new()

local function part(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.Parent = parent
	return p
end

local function buildNodeModel(def: any, pos: Vector3, name: string): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = name
	local main: BasePart
	local c = def.Color
	if def.Shape == "Tree" then
		main = part(
			m,
			"Trunk",
			Enum.PartType.Block,
			Vector3.new(2, 8, 2),
			pos + Vector3.new(0, 4, 0),
			Color3.fromRGB(120, 85, 55),
			Enum.Material.Wood
		)
		main.CanCollide = true
		part(
			m,
			"Leaves",
			Enum.PartType.Ball,
			Vector3.new(8, 7, 8),
			pos + Vector3.new(0, 10, 0),
			c,
			Enum.Material.Grass
		)
	elseif def.Shape == "Bush" then
		main = part(
			m,
			"Bush",
			Enum.PartType.Ball,
			Vector3.new(5, 3.5, 5),
			pos + Vector3.new(0, 1.7, 0),
			c,
			Enum.Material.Grass
		)
		for i = 1, 4 do
			local a = i * 1.6
			part(
				m,
				"Berry" .. i,
				Enum.PartType.Ball,
				Vector3.new(0.8, 0.8, 0.8),
				pos + Vector3.new(math.cos(a) * 1.9, 2.3 + (i % 2) * 0.5, math.sin(a) * 1.9),
				Color3.fromRGB(255, 90, 110)
			)
		end
	elseif def.Shape == "Crystal" then
		main = part(
			m,
			"Crystal",
			Enum.PartType.Block,
			Vector3.new(2.4, 7, 2.4),
			pos + Vector3.new(0, 3.5, 0),
			c,
			Enum.Material.Neon
		)
		part(
			m,
			"Shard1",
			Enum.PartType.Block,
			Vector3.new(1.4, 4, 1.4),
			pos + Vector3.new(1.8, 2, 0.6),
			c,
			Enum.Material.Neon
		)
		part(
			m,
			"Shard2",
			Enum.PartType.Block,
			Vector3.new(1.2, 3.4, 1.2),
			pos + Vector3.new(-1.6, 1.7, -0.8),
			c,
			Enum.Material.Neon
		)
	else
		main = part(
			m,
			"Rock",
			Enum.PartType.Ball,
			Vector3.new(6, 4.5, 6),
			pos + Vector3.new(0, 2, 0),
			c,
			Enum.Material.Slate
		)
		main.CanCollide = true
		part(
			m,
			"Rock2",
			Enum.PartType.Ball,
			Vector3.new(3.5, 3, 3.5),
			pos + Vector3.new(3, 1.3, 1),
			c,
			Enum.Material.Slate
		)
	end
	m.PrimaryPart = main
	return m, main
end

local function setVisible(node: Node, visible: boolean)
	for _, d in ipairs(node.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = if visible then 0 else 1
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = visible
		end
	end
	node.Model:SetAttribute("Depleted", not visible)
end

local function respawnLater(node: Node, seconds: number)
	task.delay(seconds, function()
		node.Depleted = false
		setVisible(node, true)
	end)
end

local function playerRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function nearPos(player: Player, pos: Vector3, range: number): boolean
	local root = playerRoot(player)
	return root ~= nil and (root.Position - pos).Magnitude <= range
end

-- Результат добычи для узла (без проверки расстояния)
local function harvest(player: Player, node: Node): boolean
	local data = DataService.get(player)
	if not data or node.Depleted then
		return false
	end
	node.Depleted = true
	setVisible(node, false)
	local zone = ZoneData.ById[node.Zone]
	if node.Chest then
		local total = 0
		for _, l in ipairs(ResourceData.ChestLoot) do
			total += l.Weight
		end
		local r = rng:NextNumber() * total
		local kind = "Coins"
		for _, l in ipairs(ResourceData.ChestLoot) do
			r -= l.Weight
			if r <= 0 then
				kind = l.Kind
				break
			end
		end
		local idx = ZoneData.Index[node.Zone] or 1
		local reward: { [string]: any } = {}
		if kind == "Coins" then
			reward.Coins = Economy.getPerClick(player, data) * rng:NextInteger(25, 60)
		elseif kind == "Gems" then
			reward.Gems = 3 + idx * 2
		elseif kind == "Res" then
			local list = if zone then zone.Resources else { "Wood" }
			reward.Res = { [list[rng:NextInteger(1, #list)]] = rng:NextInteger(3, 6) + idx }
		else
			local items = { "catalyst", "luck_potion", "coin_elixir", "xp_treat" }
			reward.Item = items[rng:NextInteger(1, #items)]
			reward.ItemCount = 1
		end
		Economy.grant(player, reward)
		Notify.send(
			player,
			Locale.m("chest.reward", { reward = Economy.describe(reward, Locale.langOf(player)) }),
			"reward"
		)
		respawnLater(node, ResourceData.CHEST_RESPAWN)
		return true
	end

	local def = ResourceData.Nodes[node.Kind]
	local base = rng:NextInteger(def.Min, def.Max)
	local amount = math.max(1, math.floor(base * Economy.getGatherMultiplier(data) + 0.5))
	if Economy.hasItem(data, "pickaxe") then
		amount += 1
	end
	Economy.addResource(player, def.Res, amount)
	Progress.record(player, "gather", def.Res, amount, node.Zone)
	Remotes.getEvent("Fx"):FireClient(
		player,
		"gather",
		node.Pos + Vector3.new(0, 4, 0),
		"+" .. tostring(amount) .. " " .. Locale.np(player, ResourceData.Resources[def.Res].Name)
	)
	State.markCore(player)
	respawnLater(node, def.Respawn)
	return true
end

-- Способность «Treasure Dig»: мгновенно собирает ближайший узел
function ResourceService.harvestNearest(player: Player, pos: Vector3, radius: number): boolean
	local best: Node? = nil
	local bestDist = radius
	for _, node in ipairs(nodes) do
		if not node.Depleted and not node.Chest then
			local d = (node.Pos - pos).Magnitude
			if d < bestDist then
				best, bestDist = node, d
			end
		end
	end
	if best then
		return harvest(player, best)
	end
	return false
end

local function attachPrompt(node: Node, main: BasePart, action: string, object: string, hold: number)
	local prompt = Instance.new("ProximityPrompt")
	Locale.setWorld(prompt, action, nil, "ActionText")
	Locale.setWorld(prompt, object, nil, "ObjectText")
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = main
	prompt.Triggered:Connect(function(player: Player)
		if node.Depleted or not nearPos(player, node.Pos, ResourceData.GATHER_RANGE) then
			return
		end
		harvest(player, node)
	end)
end

local function spawnNode(parent: Folder, zone: ZoneData.ZoneDef, kindKey: string, pos: Vector3, index: number)
	local def = ResourceData.Nodes[kindKey]
	local m, main = buildNodeModel(def, pos, ("%s_%s_%d"):format(def.Name:gsub(" ", ""), zone.Id, index))
	m:SetAttribute("Res", def.Res)
	m:SetAttribute("NodeName", def.Name)
	m.Parent = parent
	local node: Node =
		{ Model = m, Zone = zone.Id, Kind = kindKey, Depleted = false, Chest = false, Pos = pos }
	table.insert(nodes, node)
	nodeOf[m] = node
	attachPrompt(node, main, "prompt.gather", def.Name, def.Hold)
end

local function spawnChest(parent: Folder, zone: ZoneData.ZoneDef, pos: Vector3, index: number)
	local m = Instance.new("Model")
	m.Name = ("Chest_%s_%d"):format(zone.Id, index)
	local body = part(
		m,
		"Body",
		Enum.PartType.Block,
		Vector3.new(4, 2.4, 2.8),
		pos + Vector3.new(0, 1.2, 0),
		Color3.fromRGB(150, 100, 55),
		Enum.Material.Wood
	)
	body.CanCollide = true
	part(
		m,
		"Lid",
		Enum.PartType.Block,
		Vector3.new(4.2, 0.8, 3),
		pos + Vector3.new(0, 2.7, 0),
		Color3.fromRGB(255, 205, 80),
		Enum.Material.Metal
	)
	part(
		m,
		"Lock",
		Enum.PartType.Block,
		Vector3.new(0.6, 0.8, 0.3),
		pos + Vector3.new(0, 2.1, -1.5),
		Color3.fromRGB(255, 240, 150),
		Enum.Material.Neon
	)
	m.PrimaryPart = body
	m:SetAttribute("NodeName", "Treasure Chest")
	m.Parent = parent
	local node: Node =
		{ Model = m, Zone = zone.Id, Kind = "Chest", Depleted = false, Chest = true, Pos = pos }
	table.insert(nodes, node)
	nodeOf[m] = node
	attachPrompt(node, body, "prompt.open", "Treasure Chest", 0.6)
end

function ResourceService.init()
	local f = Instance.new("Folder")
	f.Name = "Nodes"
	f.Parent = Workspace
	for zi, zone in ipairs(ZoneData.List) do
		local zr = Random.new(2000 + zi)
		local zf = Instance.new("Folder")
		zf.Name = zone.Id
		zf.Parent = f
		for i = 1, ResourceData.NODES_PER_ZONE do
			local angle = zr:NextNumber(0, math.pi * 2)
			local radius = zr:NextNumber(34, 88)
			local pos = zone.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local kind = zone.Resources[(i - 1) % #zone.Resources + 1]
			if i == 4 and zone.Id ~= "Meadow" then
				kind = "Crystal"
			end
			spawnNode(zf, zone, kind, pos, i)
		end
		for i = 1, ResourceData.CHESTS_PER_ZONE do
			local angle = zr:NextNumber(0, math.pi * 2)
			local radius = zr:NextNumber(40, 85)
			spawnChest(
				zf,
				zone,
				zone.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
				i
			)
		end
	end
end

return ResourceService
