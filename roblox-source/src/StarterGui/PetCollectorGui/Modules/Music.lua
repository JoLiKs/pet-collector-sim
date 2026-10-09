--!nonstrict
--[[
	Music (v3.1) — фоновая музыка и короткие звуки на клиенте.
	  * спокойная тема (Config.SOUNDS.MUSIC_CALM) всё время, эпичная (MUSIC_EPIC) — пока идёт «Суперсила»
	    (атрибут gui HuntActive от HuntHud); между ними плавный кроссфейд Config.MUSIC.FADE секунд;
	  * настройки игрока Core.Audio (AudioData): музыка вкл/выкл, громкость, звуки вкл/выкл;
	  * ID = 0 — трека нет: модуль ничего не создаёт и не играет (никаких ошибок и пустых Sound);
	  * Sound создаются на клиенте в SoundService — слышит только этот игрок.
	Music.sfx(key, pos?) — короткий звук из Config.SOUNDS (если звуки включены); с pos — в точке мира.
	Звуки морского сундука (Remotes "SeaChest"): тихий сигнал появления и звук открытия.
	v3.2.2: группы SoundService «Music» и «SFX» (переключатели настроек = громкость групп; все звуки мира и
	персонажей — в «SFX»); TimedOut при загрузке — повтор с паузой, а не удаление трека; Play по Sound.Loaded;
	строка состояния в консоль ([Music] ...) и атрибут gui MusicStatus.
	v3.2: если ассет не загрузился (отклонён модерацией, удалён, нет сети) — одна запись в лог, звук пропускается,
	игра работает дальше (вторая тема играет вместо сломанной; Play не повторяется каждый кадр). Атрибут gui
	AudioFailed — список сломанных ключей (для тестов).
]]
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioData = require(Shared:WaitForChild("AudioData"))
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = require(script.Parent.ClientState)

local Music = {}

type Track = { Sound: Sound, Mix: number, Base: number, Key: string, Loaded: boolean, Logged: string? }
local tracks: { [string]: Track } = {}
local settings = AudioData.normalize(nil)
local hunt = false
local rain = false -- v3.3: идёт «Дождь монет» (атрибут gui RainActive от Hud/Fx)
local health = AudioData.newHealth()
local guiRef: ScreenGui? = nil
local musicGroup: SoundGroup? = nil
local sfxGroup: SoundGroup? = nil
local lastStatus = ""

local function publish()
	local g = guiRef
	if g then
		g:SetAttribute(
			"MusicTracks",
			(if tracks.Calm then "Calm" else "")
				.. (if tracks.Epic then "Epic" else "")
				.. (if tracks.Rain then "Rain" else "")
		)
		g:SetAttribute("AudioFailed", AudioData.failedList(health))
	end
end

-- v3.2.2: группы звука в SoundService — «Музыка» и «Звуки». Переключатели настроек управляют громкостью групп,
-- поэтому «Звуки: выкл» глушит все эффекты, включая стандартные звуки персонажей (шаги, прыжок, приземление).
local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if g and g:IsA("SoundGroup") then
		return g
	end
	local ng = Instance.new("SoundGroup")
	ng.Name = name
	ng.Volume = 1
	ng.Parent = SoundService
	return ng
end

local function applyGroups()
	if musicGroup then
		musicGroup.Volume = if settings.Music then 1 else 0
	end
	if sfxGroup then
		sfxGroup.Volume = if settings.Sfx then 1 else 0
	end
end

-- любой звук без группы (звуки персонажей RbxCharacterSounds, звуки в мире) — в группу «Звуки»
function Music.route(o: Instance)
	local g = sfxGroup
	if g and o:IsA("Sound") and o.SoundGroup == nil then
		o.SoundGroup = g
	end
end

-- ассет окончательно недоступен (несколько ответов Failure подряд): одна запись в лог, трек больше не выбирается
-- (играет другой), но Sound не уничтожается
function Music.fail(key: string, why: string?)
	if not AudioData.reportFailure(health, key, why) then
		return
	end
	warn(
		("[Music] sound %s (%s) unavailable after %d attempts: %s; skipped"):format(
			key,
			tostring(Config.SOUNDS[key]),
			AudioData.MAX_FAILURES,
			why or "?"
		)
	)
	publish()
end

local function statusName(st: any): string
	if st == Enum.AssetFetchStatus.Success then
		return "Success"
	elseif st == Enum.AssetFetchStatus.Failure then
		return "Failure"
	elseif st == Enum.AssetFetchStatus.TimedOut then
		return "TimedOut"
	end
	return tostring(st)
end

-- загрузка ассета (асинхронно) с повторами: TimedOut — ждём и пробуем снова (паузы растут), Failure — сломан
-- только после AudioData.MAX_FAILURES попыток подряд
local function load(key: string, target: any, onLoaded: (() -> ())?)
	task.spawn(function()
		while true do
			local status = "Success" -- если обратный вызов не пришёл, а PreloadAsync вернулся — ассет готов
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync({ target }, function(_contentId, st)
					status = statusName(st)
				end)
			end)
			if not ok then
				status = "Failure"
			end
			if typeof(target) == "Instance" and target:IsA("Sound") and target.IsLoaded then
				status = "Success"
			end
			local res, delay = AudioData.loadResult(health, key, status)
			if res == "ok" then
				if onLoaded then
					onLoaded()
				end
				return
			elseif res == "broken" then
				Music.fail(key, if ok then status else tostring(err))
				return
			end
			print(("[Music] %s: %s, retry in %ds"):format(key, status, delay or 0))
			task.wait(delay or 5)
			if typeof(target) == "Instance" and target:IsA("Sound") and not target.IsLoaded then
				-- переназначение SoundId заставляет Roblox запросить ассет заново
				local id = target.SoundId
				target.SoundId = ""
				target.SoundId = id
			end
		end
	end)
end

function Music.settings()
	return settings
end

local function usable(name: string): boolean
	local t = tracks[name]
	return t ~= nil and not AudioData.isFailed(health, t.Key)
end

function Music.target(): string?
	if not settings.Music then
		return nil
	end
	return AudioData.musicTarget(hunt, usable("Calm"), usable("Epic"), rain, usable("Rain"))
end

-- состояние музыки для окна настроек: "off" | "playing" | "loading" | "error", код ошибки
function Music.status(): (string, string?)
	local target = Music.target()
	local t = if target then tracks[target] else nil
	local err = health.Failed.MUSIC_CALM or health.Failed.MUSIC_EPIC or health.Failed.MUSIC_RAIN
	return AudioData.musicStatus(
		settings.Music,
		t ~= nil,
		t ~= nil and (t.Loaded or t.Sound.IsLoaded),
		t ~= nil and t.Sound.IsPlaying,
		err
	)
end

local function startTrack(name: string, t: Track)
	local s = t.Sound
	if s.IsPaused and name == "Calm" then
		s:Resume() -- спокойная тема продолжает с того же места
	else
		s.TimePosition = 0 -- эпичная и «дождь» — каждый раз с начала
		s:Play()
	end
end

local function step(dt: number)
	local target = Music.target()
	for name, t in pairs(tracks) do
		t.Mix = AudioData.fadeStep(t.Mix, if name == target then 1 else 0, dt, Config.MUSIC.FADE)
		local s = t.Sound
		s.Volume = AudioData.gain(t.Mix, t.Base, settings.MusicVol)
		if t.Mix > 0 and not s.IsPlaying then
			if AudioData.tryPlay(health, t.Key, os.clock()) then
				startTrack(name, t)
			end
		elseif t.Mix <= 0 and s.IsPlaying then
			s:Pause()
		end
	end
	-- одна строка в консоль (F9) при каждой смене состояния
	local st, code = Music.status()
	local line = st .. (if code then " " .. code else "")
	if line ~= lastStatus then
		lastStatus = line
		local t = if target then tracks[target] else nil
		print(
			("[Music] status=%s track=%s loaded=%s playing=%s volume=%.2f group=%.2f musicOn=%s vol=%.1f"):format(
				line,
				target or "-",
				tostring(t ~= nil and t.Sound.IsLoaded),
				tostring(t ~= nil and t.Sound.IsPlaying),
				if t then t.Sound.Volume else 0,
				if musicGroup then musicGroup.Volume else -1,
				tostring(settings.Music),
				settings.MusicVol
			)
		)
		local g = guiRef
		if g then
			g:SetAttribute("MusicStatus", line)
		end
	end
end

function Music.init(gui: ScreenGui)
	guiRef = gui
	musicGroup = group("Music")
	sfxGroup = group("SFX")
	applyGroups()
	local folder = Instance.new("Folder")
	folder.Name = "PcsMusic"
	folder.Parent = SoundService
	for name, key in pairs({ Calm = "MUSIC_CALM", Epic = "MUSIC_EPIC", Rain = "MUSIC_RAIN" }) do
		local id = AudioData.soundId(Config.SOUNDS[key])
		if id then
			local s = Instance.new("Sound")
			s.Name = "Music" .. name
			s.SoundId = id
			s.Looped = true
			s.Volume = 0
			s.SoundGroup = musicGroup
			s.Parent = folder
			local t: Track = {
				Sound = s,
				Mix = 0,
				Base = if name == "Epic"
					then Config.MUSIC.EPIC_VOLUME
					elseif name == "Rain" then Config.MUSIC.RAIN_VOLUME
					else Config.MUSIC.CALM_VOLUME,
				Key = key,
				Loaded = false,
			}
			tracks[name] = t
			local function onLoaded()
				if t.Loaded then
					return
				end
				t.Loaded = true
				print(("[Music] %s loaded (%s, %.0fs)"):format(name, id, s.TimeLength))
				-- уже должен звучать — запускаем сразу, не дожидаясь следующей попытки
				if t.Mix > 0 and not s.IsPlaying then
					startTrack(name, t)
				end
			end
			s.Loaded:Connect(onLoaded)
			load(key, s, onLoaded)
		end
	end
	for _, key in ipairs({ "CHEST_SPAWN", "CHEST_OPEN" }) do
		local id = AudioData.soundId(Config.SOUNDS[key])
		if id then
			load(key, id, nil)
		end
	end
	publish()
	-- звуки персонажей и мира — в группу «Звуки» (и те, что появятся позже: новые персонажи, респавн)
	for _, d in ipairs(Workspace:GetDescendants()) do
		Music.route(d)
	end
	Workspace.DescendantAdded:Connect(Music.route)
	gui:GetAttributeChangedSignal("RainActive"):Connect(function()
		rain = gui:GetAttribute("RainActive") == true
	end)
	rain = gui:GetAttribute("RainActive") == true
	gui:GetAttributeChangedSignal("HuntActive"):Connect(function()
		hunt = gui:GetAttribute("HuntActive") == true
	end)
	ClientState.onCore(function(core)
		settings = AudioData.normalize(core and core.Audio)
		applyGroups()
	end)
	-- v3.1: морской сундук — о появлении сообщает только тихий звук в точке сундука (без значков и сообщений)
	Remotes.getEvent("SeaChest").OnClientEvent:Connect(function(kind, pos)
		if typeof(pos) ~= "Vector3" then
			return
		end
		gui:SetAttribute("SeaChestSfx", kind)
		if kind == "Spawn" then
			Music.sfx("CHEST_SPAWN", pos, Config.MUSIC.CHEST_SPAWN_VOLUME)
		elseif kind == "Open" then
			Music.sfx("CHEST_OPEN", pos)
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		step(dt)
		gui:SetAttribute("MusicTarget", Music.target() or "")
		gui:SetAttribute("SfxVolume", if sfxGroup then sfxGroup.Volume else -1)
	end)
end

function Music.sfx(key: string, pos: Vector3?, volume: number?)
	local id = AudioData.soundId(Config.SOUNDS[key])
	if not id or not settings.Sfx or AudioData.isFailed(health, key) then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. key
	s.SoundId = id
	s.Volume = volume or Config.MUSIC.SFX_VOLUME
	s.SoundGroup = sfxGroup
	if pos then
		-- в точке мира: тихо и только рядом (RollOff), чтобы сигнал не «кричал» на весь хаб
		local att = Instance.new("Attachment")
		att.Name = "SfxAt"
		att.Position = pos -- Terrain в начале координат: Position == мировая точка
		att.Parent = Workspace.Terrain
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = 90
		s.Parent = att
		Debris:AddItem(att, 6)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 6)
	end
	s:Play()
end

return Music
