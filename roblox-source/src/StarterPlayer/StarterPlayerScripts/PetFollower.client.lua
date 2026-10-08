--!strict
--[[
	PetFollower — отрисовка питомцев ВСЕХ игроков на клиенте.
	Сервер лишь публикует атрибут игрока "EquippedPets" ("id:Variant,id:Variant"); модели строятся и анимируются
	локально из примитивов (PetModel). Это дёшево для сервера и не создаёт лишней физики/репликации.
	v3.0: так же рисуются питомцы ИИ-ботов (модели в Workspace.AiBots с тем же атрибутом).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("AttackFx"))
local PetModel = require(Shared:WaitForChild("PetModel"))

local RENDER_DISTANCE = 220
local MAX_PETS_PER_PLAYER = 8

type PetEntry = { Model: Model, Index: number, Current: CFrame? }
type Rendered = { Key: string, Pets: { PetEntry } }

local container = Instance.new("Folder")
container.Name = "ClientPets"
container.Parent = Workspace

-- владелец — игрок или модель ИИ-бота (v3.0)
local rendered: { [Instance]: Rendered } = {}

local function rootOf(owner: Instance): BasePart?
	local character = if owner:IsA("Player") then (owner :: Player).Character else owner
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function clear(player: Instance)
	local r = rendered[player]
	if r then
		for _, entry in ipairs(r.Pets) do
			entry.Model:Destroy()
		end
		rendered[player] = nil
	end
end

local function rebuild(player: Instance)
	local attr = player:GetAttribute("EquippedPets")
	local key = if type(attr) == "string" then attr else ""
	local existing = rendered[player]
	if existing and existing.Key == key then
		return
	end
	clear(player)
	if key == "" then
		return
	end
	local pets: { PetEntry } = {}
	for token in string.gmatch(key, "[^,]+") do
		local id, variant = string.match(token, "^([%w_]+):(%a+)$")
		if id and #pets < MAX_PETS_PER_PLAYER then
			local model = PetModel.build(id, variant)
			model.Name = player.Name .. "_" .. id
			table.insert(pets, { Model = model, Index = #pets + 1, Current = nil })
		end
	end
	rendered[player] = { Key = key, Pets = pets }
end

local function watch(player: Instance)
	rebuild(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	watch(p)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(clear)

-- ИИ-боты: папка Workspace.AiBots появляется, когда на сервер приходит первый бот
local function watchBots(f: Instance)
	for _, m in ipairs(f:GetChildren()) do
		watch(m)
	end
	f.ChildAdded:Connect(watch)
	f.ChildRemoved:Connect(clear)
end
local botsFolder = Workspace:FindFirstChild("AiBots")
if botsFolder then
	watchBots(botsFolder)
else
	Workspace.ChildAdded:Connect(function(c: Instance)
		if c:IsA("Folder") and c.Name == "AiBots" then
			watchBots(c)
		end
	end)
end

-- Позиция питомца за спиной игрока веером
local function slotOffset(index: number, count: number): Vector3
	local radius = 4.5 + math.floor((count - 1) / 4) * 1.5
	if count == 1 then
		return Vector3.new(0, 0, 4)
	end
	local spread = math.rad(math.min(150, 40 + count * 18))
	local a = -spread / 2 + spread * (index - 1) / (count - 1)
	return Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
end

RunService.RenderStepped:Connect(function(dt)
	local camera = Workspace.CurrentCamera
	local camPos = if camera then camera.CFrame.Position else Vector3.zero
	local t = os.clock()
	local alpha = 1 - math.exp(-dt * 9)

	for player, r in pairs(rendered) do
		local root = rootOf(player)
		if root and (root.Position - camPos).Magnitude < RENDER_DISTANCE then
			local count = #r.Pets
			local lunge = AttackFx.petLunge(player :: any) -- рывок питомцев вместе с ударом хозяина
			for _, entry in ipairs(r.Pets) do
				local offset = slotOffset(entry.Index, count)
				local bob = math.sin(t * 3 + entry.Index * 1.7) * 0.25
				local worldPos = (root.CFrame * CFrame.new(offset.X, 0, offset.Z)).Position
					+ Vector3.new(0, -1.4 + 1.1 + bob, 0)
					+ lunge
				local look = root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.01 then
					flat = Vector3.new(0, 0, -1)
				end
				local target = CFrame.lookAt(worldPos, worldPos + flat)
				local previous = entry.Current
				local nextCf: CFrame
				if previous == nil or (previous.Position - target.Position).Magnitude > 40 then
					nextCf = target -- первое появление/телепорт
				else
					nextCf = previous:Lerp(target, alpha)
				end
				entry.Current = nextCf
				entry.Model:PivotTo(nextCf)
				if entry.Model.Parent ~= container then
					entry.Model.Parent = container
				end
			end
		else
			for _, entry in ipairs(r.Pets) do
				if entry.Model.Parent ~= nil then
					entry.Model.Parent = nil
				end
			end
		end
	end
end)
