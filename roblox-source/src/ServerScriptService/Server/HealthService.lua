--!strict
--[[
	HealthService (v3.0) — здоровье игрока: своя регенерация и зелья здоровья/регенерации.
	  * Регенерация: Config.HP_REGEN_RATE доли максимального здоровья в секунду (как стандартный скрипт Roblox: 1%/с).
	    Стандартный скрипт "Health" в персонаже убирается, поэтому темп одинаков в Roblox и в веб-демо.
	  * Зелье регенерации: темп xValue на Seconds секунд; повторное зелье продлевает действие.
	    Время конца — в data.Boosts.Regen (unix, для таймера на быстром слоте) и точнее — в памяти сервера.
	  * Зелье здоровья: сразу +Value доли максимального здоровья. При полном здоровье не тратится.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)

local HealthService = {}

-- player -> os.clock() конца зелья регенерации и его множитель
local regenUntil: { [Player]: number } = {}
local regenMult: { [Player]: number } = {}

local function humanoidOf(player: Player): Humanoid?
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return hum
end

local function maxHp(hum: Humanoid): number
	local m = (hum.MaxHealth :: number?) or 100
	return if m > 0 then m else 100
end

-- Текущий множитель регенерации игрока (1 — без зелья)
function HealthService.regenMultiplier(player: Player): number
	if (regenUntil[player] or 0) > os.clock() then
		return regenMult[player] or 1
	end
	return 1
end

-- Зелье здоровья: +frac максимального здоровья. Ошибки: "item.no_character", "item.hp_full".
function HealthService.heal(player: Player, frac: number): (boolean, string?)
	local hum = humanoidOf(player)
	if not hum or hum.Health <= 0 then
		return false, "item.no_character"
	end
	local mx = maxHp(hum)
	if hum.Health >= mx - 0.5 then
		return false, "item.hp_full"
	end
	hum.Health = math.min(mx, hum.Health + mx * frac)
	return true, nil
end

-- Зелье регенерации: xmult на seconds секунд (продлевает действующее). data — профиль (для таймера на слоте).
function HealthService.addRegen(player: Player, data: any, mult: number, seconds: number): (boolean, string?)
	local hum = humanoidOf(player)
	if not hum or hum.Health <= 0 then
		return false, "item.no_character"
	end
	local now = os.clock()
	regenUntil[player] = math.max(regenUntil[player] or 0, now) + seconds
	regenMult[player] = mult
	if data and type(data.Boosts) == "table" then
		data.Boosts.Regen = math.max(tonumber(data.Boosts.Regen) or 0, os.time()) + seconds
	end
	return true, nil
end

-- Один шаг регенерации (dt секунд) для всех игроков; вызывается из Heartbeat и из тестов
function HealthService.tick(dt: number)
	local rate = Config.HP_REGEN_RATE
	for _, player in ipairs(Players:GetPlayers()) do
		local hum = humanoidOf(player)
		if hum and hum.Health > 0 then
			local mx = maxHp(hum)
			if hum.Health < mx then
				hum.Health = math.min(mx, hum.Health + mx * rate * HealthService.regenMultiplier(player) * dt)
			end
		end
	end
end

-- Убрать стандартный скрипт регенерации Roblox (у нас своя, с зельем)
local function onCharacter(c: Model)
	local s = c:FindFirstChild("Health")
	if s and s:IsA("Script") then
		s:Destroy()
	end
end

function HealthService.init()
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(onCharacter)
		if p.Character then
			onCharacter(p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		regenUntil[p] = nil
		regenMult[p] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.5 then
			HealthService.tick(acc)
			acc = 0
		end
	end)
end

return HealthService
