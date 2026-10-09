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

-- «Суперсила» в UI-тестах по умолчанию на паузе (чтобы случайный раунд не мешал старым сценариям);
-- ?attr.SuperpowerAuto=true в URL оставляет обычный цикл.
if Workspace:GetAttribute("SuperpowerAuto") ~= true then
	Workspace:SetAttribute("SuperpowerPaused", true)
end

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
-- v3.0: look:x,z,tx,tz — встать в (x,z) лицом к (tx,tz) (камера за спиной — для скриншотов)
function handlers.look(arg)
	local x, z, tx, tz = string.match(arg, "(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+)")
	AntiExploit.markTeleport(player)
	player.Character:PivotTo(
		CFrame.lookAt(Vector3.new(tonumber(x), 4, tonumber(z)), Vector3.new(tonumber(tx), 4, tonumber(tz)))
	)
end
-- v3.0: hp:0.3 — здоровье персонажа = доля от максимума (проверка зелий лечения/регенерации)
function handlers.hp(arg)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = hum.MaxHealth * (tonumber(arg) or 0.5)
	end
end
function handlers.tpenemy()
	local folder = Workspace:FindFirstChild("Enemies")
	local root = player.Character.HumanoidRootPart
	local best, bd = nil, 1e9
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if m:IsA("Model") and not m:GetAttribute("IsBoss") then
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
-- super:me | super:bot — начать раунд сейчас; super:on — снять паузу; super:fast — ускорить цикл x10;
-- super:end — дотянуть таймер до конца (исход «продержался»); super:near — встать рядом с суперигроком
function handlers.super(arg)
	local SuperpowerService = require(Server.SuperpowerService)
	if arg == "me" or arg == "bot" then
		Workspace:SetAttribute("SuperpowerForce", arg)
	elseif arg == "on" then
		Workspace:SetAttribute("SuperpowerPaused", false)
	elseif arg == "fast" then
		Workspace:SetAttribute("SuperpowerTimeScale", 10)
		Workspace:SetAttribute("SuperpowerPaused", false)
	elseif arg == "end" then
		local r = SuperpowerService.current()
		if r then
			r.Ends = os.clock() + 0.2
		end
	elseif arg == "near" then
		local t = SuperpowerService.targetRoot()
		if t then
			local d = player.Character.HumanoidRootPart.Position - t.Position
			local flat = Vector3.new(d.X, 0, d.Z)
			local off = if flat.Magnitude > 0.1 then flat.Unit * 6 else Vector3.new(6, 0, 0)
			AntiExploit.markTeleport(player)
			player.Character:PivotTo(CFrame.lookAt(t.Position + off, t.Position))
		end
	end
end
-- gallery:mobs | gallery:bosses — витрина рисовки врагов на отдельной площадке в небе (для скриншотов):
-- «пустые» модели с хитбоксом Body и атрибутами, как у CombatService, без ИИ и урона.
function handlers.gallery(arg)
	local EnemyData = require(game:GetService("ReplicatedStorage").Shared.EnemyData)
	local old = Workspace:FindFirstChild("Gallery")
	if old then
		old:Destroy()
	end
	local base = Vector3.new(0, 300, 600)
	local stage = Instance.new("Part")
	stage.Name = "Gallery"
	stage.Anchored = true
	stage.Size = Vector3.new(260, 2, 220) -- с запасом: «оператор» стоит далеко перед рядом боссов
	stage.Position = base - Vector3.new(0, 1, -40)
	stage.Color = Color3.fromRGB(120, 200, 110)
	stage.Material = Enum.Material.Grass
	stage.Parent = Workspace
	local folder = Workspace:FindFirstChild("Enemies")
	for _, m in ipairs(folder:GetChildren()) do
		if string.sub(m.Name, 1, 8) == "Gallery_" then
			m:Destroy()
		end
	end
	local list = {}
	if string.sub(arg, 1, 4) == "ids=" then -- gallery:ids=slimeling+boarlet — крупный план выбранных
		for id in string.gmatch(string.sub(arg, 5), "[^+]+") do
			table.insert(
				list,
				EnemyData.ById[id] or (if id == "moonling" then EnemyData.MOONLING else EnemyData.RAID_BOSS)
			)
		end
	else
		for _, d in ipairs(EnemyData.List) do
			if (arg == "bosses") == (d.Boss == true) and d.Id ~= "stone_colossus" then
				table.insert(list, d)
			end
		end
		if arg == "bosses" then
			table.insert(list, EnemyData.RAID_BOSS)
		end
	end
	local function sizeOf(d): Vector3
		local s = d.Size
		return if d.Shape == "Tall"
			then Vector3.new(s * 0.7, s * 1.5, s * 0.7)
			elseif d.Shape == "Block" then Vector3.new(s, s * 0.8, s)
			else Vector3.new(s, s, s)
	end
	-- боссы и крупный план — одним рядом, шаг по ширине фигур (имена/полоски не наезжают)
	local row1 = arg == "bosses" or string.sub(arg, 1, 4) == "ids="
	local xs, total, maxH = {}, 0, 0
	for i, d in ipairs(list) do
		local w = sizeOf(d).X * (if d.Boss then 3 else 1.6) + 2.5
		xs[i] = total + w / 2
		total += w
		maxH = math.max(maxH, sizeOf(d).Y)
	end
	for i, d in ipairs(list) do
		local size = sizeOf(d)
		local pos
		if row1 then
			pos = base + Vector3.new(xs[i] - total / 2, size.Y / 2, 0)
		else
			local row, col = math.floor((i - 1) / 6), (i - 1) % 6
			local inRow = math.min(6, #list - row * 6)
			pos = base + Vector3.new((col - (inRow - 1) / 2) * 7.5, size.Y / 2, -row * 9)
		end
		local m = Instance.new("Model")
		m.Name = "Gallery_" .. d.Id
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = size
		body.Transparency = 1
		body.Anchored = true
		body.CanCollide = false
		body.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
		body.Parent = m
		m.PrimaryPart = body
		m:SetAttribute("EnemyId", d.Id)
		m:SetAttribute("IsBoss", d.Boss)
		m:SetAttribute("EnemyName", d.Name)
		m:SetAttribute("Hp", if d.Boss then 70 else 100)
		m:SetAttribute("MaxHp", 100)
		m:SetAttribute("Atk", 0)
		m.Parent = folder
	end
	-- персонаж стоит на camZ, камера ~14 студов за ним: ряд шириной total должен влезть в кадр 16:9
	local camZ = if row1 then math.max(4, math.max(total / 2.3, maxH * 1.7) - 12) else 5
	-- персонаж-«оператор» невидим: камера смотрит на витрину, не на него
	for _, d in ipairs(player.Character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.Transparency = 1
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
	AntiExploit.markTeleport(player)
	player.Character:PivotTo(CFrame.lookAt(base + Vector3.new(0, 3, camZ), base + Vector3.new(0, 3, -10)))
end
-- hud:off | hud:on — спрятать интерфейс для чистых скриншотов
function handlers.hud(arg)
	local g = player.PlayerGui:FindFirstChild("PetCollectorGui")
	if g then
		g.Enabled = arg ~= "off"
	end
end
-- icons[:off] — витрина всех иконок Icons.lua крупно (для просмотра рисовки); icons:off — убрать
function handlers.icons(arg)
	local old = player.PlayerGui:FindFirstChild("IconGallery")
	if old then
		old:Destroy()
	end
	if arg == "off" then
		return
	end
	local Icons = require(game:GetService("ReplicatedStorage").Shared.Icons)
	local g = Instance.new("ScreenGui")
	g.Name = "IconGallery"
	g.DisplayOrder = 100
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = if arg == "light" then Color3.fromRGB(120, 200, 120) else Color3.fromRGB(36, 40, 60)
	bg.Parent = g
	local kinds = {}
	for k in pairs(Icons.SPECS) do
		table.insert(kinds, k)
	end
	table.sort(kinds)
	local size = tonumber(arg) or 96
	local cols = math.floor(1200 / (size + 24))
	for i, k in ipairs(kinds) do
		local col, row = (i - 1) % cols, (i - 1) // cols
		Icons.make(k, {
			Px = size,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(30 + col * (size + 24), 20 + row * (size + 30)),
			ZIndex = 2,
			Parent = bg,
		})
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Text = k
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextSize = 11
		t.Size = UDim2.fromOffset(size + 20, 14)
		t.Position = UDim2.fromOffset(20 + col * (size + 24), 20 + row * (size + 30) + size + 2)
		t.ZIndex = 30
		t.Parent = bg
	end
	g.Parent = player.PlayerGui
end
-- item:luck_potion=3 — выдать предметы (v2.9: быстрые слоты); boost:Luck5=600 — буст как от доната
function handlers.item(arg)
	local id, n = string.match(arg, "^([%w_]+)=?(%d*)$")
	Economy.addItem(player, id, tonumber(n) or 1)
end
-- v3.1: ресурс (res:Wood=5) и «фарм» в фоне (farm:on/off) — счётчики меняются, как у игрока в мире
function handlers.res(arg)
	local id, n = string.match(arg, "^([%w_]+)=?(%d*)$")
	Economy.addResource(player, id, tonumber(n) or 1)
end
local farming = false
function handlers.farm(arg)
	local on = arg ~= "off"
	local start = on and not farming
	farming = on
	if start then
		task.spawn(function()
			while farming do
				Economy.addResource(player, "Wood", 1)
				task.wait(0.2)
			end
		end)
	end
end
-- v3.1: открыть окно по имени (как станции хаба: событие OpenUi)
-- v3.1: chest:auto — морской сундук в случайном свободном месте хаба (как по таймеру);
-- chest:x,z — в точке; chest:open — открыть ближайший от имени игрока (тот же серверный путь, что у Prompt)
function handlers.chest(arg)
	local SeaChestService = require(Server.SeaChestService)
	if arg == "auto" then
		local c = SeaChestService.spawn()
		Workspace:SetAttribute("SeaChestAt", c and string.format("%d,%d", c.Pos.X, c.Pos.Z) or "none")
	elseif arg == "open" then
		local c = SeaChestService.current()
		local ok, why = SeaChestService.tryOpen(player, c and c.Id)
		Workspace:SetAttribute("SeaChestOpen", if ok then "ok" else tostring(why))
	else
		local x, z = string.match(arg, "^(-?[%d.]+),(-?[%d.]+)$")
		local c = SeaChestService.spawn(Vector3.new(tonumber(x), 0, tonumber(z)))
		Workspace:SetAttribute("SeaChestAt", c and string.format("%d,%d", c.Pos.X, c.Pos.Z) or "none")
	end
end
-- v3.2 (аудит): relabel — вынуть подпись-табличку (LabelKind=Sign) из Workspace и вернуть; имя родителя —
-- в атрибуте Workspace.RelabelPart (тест: размер подписи после возврата тот же)
-- v3.2.2: звук «шагов» в персонаже (как RbxCharacterSounds) — клиент должен отправить его в группу SFX
function handlers.charsound()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local s = Instance.new("Sound")
		s.Name = "PcsTestRunning"
		s.Looped = true
		s.Parent = hrp
	end
end

function handlers.relabel()
	for _, d in ipairs(Workspace:GetDescendants()) do
		if
			d:IsA("BillboardGui")
			and d:GetAttribute("LabelKind") == "Sign"
			and d.Parent
			and d.Parent:IsA("BasePart")
		then
			local parent = d.Parent
			d:SetAttribute("Relabel", true)
			d.Parent = nil
			task.wait(0.3)
			d.Parent = parent
			Workspace:SetAttribute("RelabelPart", parent:GetFullName())
			return
		end
	end
	Workspace:SetAttribute("RelabelPart", "none")
end
-- v3.2: chestcheck:x,z — серверная проверка места (SeaChestService.check): "ok" или причина отказа
function handlers.chestcheck(arg)
	local SeaChestService = require(Server.SeaChestService)
	local x, z = string.match(arg, "^(-?[%d.]+),(-?[%d.]+)$")
	local ok, why = SeaChestService.check(Vector3.new(tonumber(x), 0, tonumber(z)))
	Workspace:SetAttribute("SeaChestCheck", if ok then "ok" else tostring(why))
end
-- v3.2: pass:KEY — выдать геймпасс в сессии (как после покупки), pass:-KEY — забрать
function handlers.pass(arg)
	local off = string.sub(arg, 1, 1) == "-"
	local key = if off then string.sub(arg, 2) else arg
	Session.get(player).Passes[key] = not off
	State.markCore(player)
end
function handlers.ui(arg)
	require(game:GetService("ReplicatedStorage").Shared.Remotes).getEvent("OpenUi"):FireClient(player, arg)
end
function handlers.boost(arg)
	local kind, sec = string.match(arg, "^(%w+)=(%d+)$")
	Economy.addLuckBoost(DataService.get(player), kind, tonumber(sec))
	State.markCore(player)
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
		-- Сбрасываем, чтобы повторная та же команда (tpenemy/tpenemy) снова сработала.
		Workspace:SetAttribute("UiCmd", "")
		last = ""
	end
	task.wait(0.1)
end
