--!strict
--[[
	EventService — события по расписанию (EventData): Золотой дождь, Лунная ночь, Рейд «Каменный колосс».
	Расписание детерминированно от os.time(), поэтому все серверы показывают одно и то же без обмена сообщениями.
	  * Золотой дождь: с неба падают золотые монеты в хабе; множитель монет x2 (Economy.getCoinBoost).
	  * Лунная ночь: ночь в Lighting, лунные существа в мирах, продаётся Лунное яйцо.
	  * Рейд: общий босс с HP, растущим с числом игроков; награда всем, кто нанёс достаточно урона.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared

local EventData = require(Shared.EventData)
local Remotes = require(Shared.Remotes)
local ZoneData = require(Shared.ZoneData)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local EventState = require(script.Parent.EventState)
local Notify = require(script.Parent.Notify)
local Progress = require(script.Parent.Progress)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)

local EventService = {}

local rng = Random.new()
local active: { [string]: boolean } = {}
local rainFolder: Folder? = nil
local coins: { { Part: Part, Born: number } } = {}
local collected: { [Player]: number } = {}

local function isActive(id: string, now: number): (boolean, number)
	return EventState.status(id, now)
end

function EventService.force(id: string, on: boolean?)
	EventState.force(id, on)
end

local function broadcast(now: number)
	local list = {}
	for _, e in ipairs(EventData.List) do
		local on, left = isActive(e.Id, now)
		table.insert(list, { Id = e.Id, Name = e.Name, Active = on, Left = left, Desc = e.Desc })
	end
	Remotes.getEvent("EventState"):FireAllClients(list)
end

-- ---------------------------------------------------------------------------
-- Золотой дождь
-- ---------------------------------------------------------------------------

local function dropCoin()
	local f = rainFolder
	if not f then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(5, ZoneData.HUB_RADIUS * 0.55)
	local x, z = math.cos(angle) * radius, math.sin(angle) * radius
	local p = Instance.new("Part")
	p.Name = "GoldenCoin"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.4, 3, 3)
	p.Color = Color3.fromRGB(255, 205, 50)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = CFrame.new(x, 45, z) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = f
	local tween = TweenService:Create(
		p,
		TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(x, 2.5, z) * CFrame.Angles(0, 0, math.rad(90)) }
	)
	tween:Play()
	table.insert(coins, { Part = p, Born = os.clock() })
end

local function pollCoins(now: number)
	for i = #coins, 1, -1 do
		local c = coins[i]
		local gone = false
		if now - c.Born > 14 then
			gone = true
		elseif now - c.Born > 1.8 then -- пока монета падает, поднять её нельзя
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local data = DataService.get(player)
				if root and data and (root.Position - c.Part.Position).Magnitude <= 7 then
					local value = Economy.getPerClick(player, data) * EventData.RAIN_COIN_VALUE
					Economy.addCoins(player, value)
					collected[player] = (collected[player] or 0) + 1
					Progress.record(player, "rain", nil, 1, nil)
					Remotes.getEvent("Fx")
						:FireClient(player, "Coin", c.Part.Position, "+" .. tostring(value), "rain")
					gone = true
					break
				end
			end
		end
		if gone then
			c.Part:Destroy()
			table.remove(coins, i)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Старт/конец событий
-- ---------------------------------------------------------------------------

local function onStart(id: string, left: number)
	local def = EventData.ById[id]
	local msg = def.Name .. " has begun! " .. def.Desc
	for _, player in ipairs(Players:GetPlayers()) do
		Notify.send(player, msg, "reward")
	end
	if id == "LunarNight" then
		Lighting.ClockTime = 0
		Lighting.Brightness = 1.2
		Lighting.OutdoorAmbient = Color3.fromRGB(70, 80, 140)
		CombatService.setLunar(true)
	elseif id == "BossRaid" then
		local n = math.max(1, #Players:GetPlayers())
		CombatService.spawnRaid(
			n,
			left,
			function(defeated: boolean, damage: { [Player]: number }, total: number)
				local def2 = EventData.ById["BossRaid"]
				if not defeated then
					for _, player in ipairs(Players:GetPlayers()) do
						Notify.send(player, "The Stone Colossus escaped... Better luck next time!", "error")
					end
					return
				end
				local r = EventData.RAID_REWARD
				for player, dealt in pairs(damage) do
					if player.Parent and total > 0 and dealt / total >= EventData.RAID_MIN_SHARE then
						Economy.grant(
							player,
							{ Coins = r.Coins, Gems = r.Gems, Res = { Essence = r.Essence }, BpXp = r.BpXp }
						)
						Progress.record(player, "raid", nil, 1, nil)
						Notify.send(
							player,
							("%s defeated! You dealt %d damage: %s"):format(
								def2.Name,
								dealt,
								Economy.describe({
									Coins = r.Coins,
									Gems = r.Gems,
									Res = { Essence = r.Essence },
								})
							),
							"reward"
						)
					elseif player.Parent then
						Notify.send(
							player,
							"The Colossus fell, but you did too little damage for a reward.",
							"info"
						)
					end
				end
			end
		)
	elseif id == "GoldenRain" then
		collected = {}
	end
end

local function onStop(id: string)
	if id == "LunarNight" then
		Lighting.ClockTime = 14
		Lighting.Brightness = 2.5
		Lighting.OutdoorAmbient = Color3.fromRGB(130, 135, 150)
		CombatService.setLunar(false)
	elseif id == "BossRaid" then
		CombatService.endRaid()
	elseif id == "GoldenRain" then
		for _, c in ipairs(coins) do
			c.Part:Destroy()
		end
		coins = {}
	end
end

function EventService.isActive(id: string): boolean
	return EventState.isActive(id)
end

function EventService.init()
	-- Новая сессия: события стартуют «с нуля» (Offset = секунды до первого запуска).
	EventState.setEpoch(os.time())
	local f = Instance.new("Folder")
	f.Name = "Rain"
	f.Parent = Workspace
	rainFolder = f

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for _, e in ipairs(EventData.List) do
				local on, left = isActive(e.Id, now)
				if on and not active[e.Id] then
					active[e.Id] = true
					onStart(e.Id, left)
				elseif not on and active[e.Id] then
					active[e.Id] = false
					onStop(e.Id)
				end
			end
			broadcast(now)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				if s and s.Ready then
					State.markCore(player)
				end
			end
		end
	end)

	task.spawn(function()
		local acc = 0
		while true do
			task.wait(0.2)
			acc += 0.2
			if active["GoldenRain"] then
				if acc >= EventData.RAIN_DROP_INTERVAL then
					acc = 0
					dropCoin()
				end
				pollCoins(os.clock())
			end
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if player.Parent then
				broadcast(os.time())
			end
		end)
	end)
end

return EventService
