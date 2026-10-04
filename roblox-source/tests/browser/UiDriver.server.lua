--!nocheck
-- Серверный помощник для браузерного UI-теста: ждёт команд из атрибута Workspace.UiCmd (ставит Playwright)
-- и выполняет их ЧЕРЕЗ ТЕ ЖЕ сервисы игры (выдача ресурсов, телепорт, события). Клики по интерфейсу делает сам тест.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Server = ServerScriptService:WaitForChild("Main"):WaitForChild("Server", 5)
	or ServerScriptService:WaitForChild("Server")
local AntiExploit = require(Server.AntiExploit)
local DataService = require(Server.DataService)
local Economy = require(Server.Economy)
local EventService = require(Server.EventService)
local Session = require(Server.Session)
local State = require(Server.State)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
while
	not (
		Session.get(player)
		and Session.get(player).Ready
		and player.Character
		and player.Character:FindFirstChild("HumanoidRootPart")
	)
do
	task.wait(0.2)
end

local function tp(x, z)
	AntiExploit.markTeleport(player)
	player.Character:PivotTo(CFrame.new(x, 5, z))
end

local handlers = {}
function handlers.seed()
	Economy.grant(player, {
		Coins = 60000,
		Gems = 600,
		Res = { Wood = 40, Herb = 30, Ore = 20, Stone = 30, Crystal = 10, Essence = 20 },
		Item = "catalyst",
		ItemCount = 2,
	})
	for _, spec in ipairs({
		{ "bunbun", "Normal" },
		{ "bunbun", "Normal" },
		{ "bunbun", "Normal" },
		{ "sunfox", "Normal" },
		{ "chirpy", "Golden" },
		{ "mushling", "Normal" },
	}) do
		Economy.addPet(player, spec[1], spec[2])
	end
	DataService.get(player).Zones.Forest = true
	State.markPets(player)
end
function handlers.tp(arg)
	local x, z = string.match(arg, "(-?[%d%.]+),(-?[%d%.]+)")
	tp(tonumber(x), tonumber(z))
end
function handlers.tpenemy()
	local folder = Workspace:FindFirstChild("Enemies")
	local root = player.Character.HumanoidRootPart
	local best, bd = nil, 1e9
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if not m:GetAttribute("IsBoss") then
			local d = (m:GetPivot().Position - root.Position).Magnitude
			if d < bd then
				best, bd = m, d
			end
		end
	end
	if best then
		local p = best:GetPivot().Position
		tp(p.X + 6, p.Z + 6)
	end
end
function handlers.event(arg)
	EventService.force(arg, true)
end
function handlers.raid()
	EventService.force("BossRaid", true)
end
function handlers.bpxp(arg)
	Economy.addBpXp(player, tonumber(arg))
end

local last
while true do
	local cmd = Workspace:GetAttribute("UiCmd")
	if cmd and cmd ~= last then
		last = cmd
		local name, arg = string.match(cmd, "^([%w_]+):?(.*)$")
		local ok, err = pcall(handlers[name] or function() end, arg)
		print(ok and ("UIDRIVER ok " .. cmd) or ("UIDRIVER FAIL " .. cmd .. " " .. tostring(err)))
	end
	task.wait(0.1)
end
