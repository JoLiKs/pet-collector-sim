--!strict
-- Жизненный цикл игрока: загрузка данных, leaderstats, спавн, респавн, оверхед-тег, выход.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local Locale = require(Shared.Locale)
local BattlePassData = require(Shared.BattlePassData)
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local Badges = require(script.Parent.Badges)
local DataService = require(script.Parent.DataService)
local Economy = require(script.Parent.Economy)
local LanguageService = require(script.Parent.LanguageService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Dailies = require(script.Parent.Dailies)
local Monetization = require(script.Parent.Monetization)
local OfflineService = require(script.Parent.OfflineService)
local Notify = require(script.Parent.Notify)
local Session = require(script.Parent.Session)
local State = require(script.Parent.State)
local WorldBuilder = require(script.Parent.WorldBuilder)
local ZoneService = require(script.Parent.ZoneService)
local ZoneData = require(Shared.ZoneData)

local PlayerService = {}

local RESPAWN_DELAY = 2.5

local function updateLeaderstats(player: Player)
	local data = DataService.get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local rebirths = stats:FindFirstChild("Rebirths") :: IntValue?
	local coins = stats:FindFirstChild("Coins") :: StringValue?
	local gems = stats:FindFirstChild("Gems") :: StringValue?
	if rebirths then
		rebirths.Value = data.Rebirths
	end
	if coins then
		coins.Value = Util.formatNumber(data.Coins)
	end
	if gems then
		gems.Value = Util.formatNumber(data.Gems)
	end
end

local function createLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local gems = Instance.new("StringValue")
	gems.Name = "Gems"
	gems.Parent = stats
	stats.Parent = player
	updateLeaderstats(player)
end

local function createTag(): BillboardGui
	local g = Instance.new("BillboardGui")
	g.Name = "OverheadTag"
	g.Size = UDim2.fromOffset(170, 42) -- v3.2: компактнее; порядок с другими подписями — клиент WorldLabels
	g.StudsOffset = Vector3.new(0, 2.6, 0)
	g.MaxDistance = 60
	g.LightInfluence = 0
	g:SetAttribute("LabelKind", "Player")
	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.5
	name.Parent = g
	local sub = Instance.new("TextLabel")
	sub.Name = "SubLabel"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.55)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 214, 90)
	sub.TextStrokeTransparency = 0.5
	sub.Parent = g
	return g
end

-- Оверхед-тег над головой: ник, [VIP], число ребёрт
local function refreshTag(player: Player)
	local character = player.Character
	local data = DataService.get(player)
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or not data then
		return
	end
	local existing = head:FindFirstChild("OverheadTag")
	local gui: BillboardGui
	if existing and existing:IsA("BillboardGui") then
		gui = existing
	else
		gui = createTag()
		gui.Parent = head
	end
	local nameLabel = gui:FindFirstChild("NameLabel") :: TextLabel
	local subLabel = gui:FindFirstChild("SubLabel") :: TextLabel
	nameLabel.Text = player.DisplayName
	local vip = Economy.isVip(player)
	local key = if vip and data.Rebirths > 0
		then "tag.vip_rebirth"
		elseif vip then "tag.vip"
		elseif data.Rebirths > 0 then "tag.rebirth"
		else "tag.none"
	-- текст видят все игроки: клиентский WorldLocalizer переводит его на язык смотрящего
	Locale.setWorld(subLabel, key, { n = data.Rebirths })
end

-- LoadCharacterAsync — актуальный API; LoadCharacter оставлен как запасной вариант для старых версий Studio
local function loadCharacter(player: Player)
	local ok = pcall(function()
		player:LoadCharacterAsync()
	end)
	if not ok then
		pcall(function()
			(player :: any):LoadCharacter()
		end)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local data = DataService.get(player)
	if not data then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root or not player.Parent then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Economy.getJumpPower(player)
	humanoid.WalkSpeed = Economy.getWalkSpeed(player, data)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	ZoneService.moveToZone(player, ZoneData.HUB)
	refreshTag(player)

	humanoid.Died:Connect(function()
		task.delay(RESPAWN_DELAY, function()
			if player.Parent and player.Character == character and Session.get(player) then
				loadCharacter(player)
			end
		end)
	end)
end

-- Кэш дружбы пар игроков на время сессии сервера (IsFriendsWithAsync — сетевой вызов)
local friendCache: { [string]: boolean } = {}

local function onPlayerAdded(player: Player)
	local session = Session.create(player)

	local data, err = DataService.load(player)
	if not data then
		Session.destroy(player)
		if player.Parent then
			local lang = Locale.detect(nil, LanguageService.localeId(player), nil)
			player:Kick(Locale.get(lang, "kick.load_failed", { err = tostring(err) }))
		end
		return
	end
	if not player.Parent then
		return
	end

	Monetization.loadPlayer(player)
	if not player.Parent then
		return
	end

	LanguageService.apply(player)
	createLeaderstats(player)
	Dailies.ensure(data)
	BattlePassData.syncSeason(data.BattlePass) -- v2.4 (М1): сезон пропуска сверяется при входе
	PlayerService.refreshFriends(player)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			task.spawn(PlayerService.refreshFriends, other)
		end
	end
	session.Ready = true
	OfflineService.onJoin(player)
	Economy.deliverPetMail(player) -- v2.4 (С10): место могло освободиться (например, куплен слот)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	State.push(player, true)
	Badges.award(player, "WELCOME") -- v2.6: значок «Добро пожаловать» (Config.BADGES.WELCOME, 0 = выкл.)
	if DataService.isNewPlayer(player) then
		Notify.send(player, "welcome.new", "info")
	end
	loadCharacter(player)
end

local function onPlayerRemoving(player: Player)
	local data = DataService.get(player)
	if data then
		OfflineService.touch(player)
		-- последняя отправка в лидерборд (в фоне) и сохранение со снятием session lock
		local userId, total = player.UserId, data.TotalCoins
		task.spawn(LeaderboardService.submit, userId, total)
	end
	DataService.release(player)
	Session.destroy(player)
	WorldBuilder.clearPlayer(player)
	-- бонус друзей у оставшихся (v2.4, С2) и очистка кэша пар уходящего
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			task.spawn(PlayerService.refreshFriends, other, player)
		end
	end
	local id = tostring(player.UserId)
	for key in pairs(friendCache) do
		local a, b = string.match(key, "^(%d+):(%d+)$")
		if a == id or b == id then
			friendCache[key] = nil
		end
	end
end

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end
local function areFriends(player: Player, other: Player): boolean
	local key = pairKey(player.UserId, other.UserId)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return player:IsFriendsWithAsync(other.UserId)
	end)
	if ok then
		friendCache[key] = result == true -- ошибки сети не кэшируем
	end
	return ok and result == true
end

-- Считает друзей на сервере (yield при первом запросе пары). Бот «Trader Tom» считается другом только в демо.
-- v2.4 (аудит С2): пересчитывается у всех игроков при каждом входе и выходе; `leaving` — уходящий игрок.
function PlayerService.refreshFriends(player: Player, leaving: Player?)
	local n = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other ~= leaving and areFriends(player, other) then
			n += 1
		end
	end
	if Config.DEMO_BOT_ENABLED then
		n += 1
	end
	local s = Session.get(player)
	if s then
		s.Friends = n
	end
end

function PlayerService.init()
	Economy.onChanged = function(player: Player)
		State.markCore(player)
		updateLeaderstats(player)
	end

	table.insert(Monetization.onStatusChanged, refreshTag)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Обновление тега после ребёрта
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				local s = Session.get(player)
				if s and s.Ready then
					refreshTag(player)
					OfflineService.touch(player)
				end
			end
		end
	end)
end

return PlayerService
