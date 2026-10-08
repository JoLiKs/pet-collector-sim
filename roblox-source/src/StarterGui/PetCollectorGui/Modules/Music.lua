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
]]
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

local tracks: { [string]: { Sound: Sound, Mix: number, Base: number } } = {}
local settings = AudioData.normalize(nil)
local hunt = false

function Music.settings()
	return settings
end

function Music.target(): string?
	if not settings.Music then
		return nil
	end
	return AudioData.musicTarget(hunt, tracks.Calm ~= nil, tracks.Epic ~= nil)
end

local function step(dt: number)
	local target = Music.target()
	for name, t in pairs(tracks) do
		t.Mix = AudioData.fadeStep(t.Mix, if name == target then 1 else 0, dt, Config.MUSIC.FADE)
		local s = t.Sound
		s.Volume = AudioData.gain(t.Mix, t.Base, settings.MusicVol)
		if t.Mix > 0 and not s.IsPlaying then
			if s.IsPaused and name == "Calm" then
				s:Resume() -- спокойная тема продолжает с того же места
			else
				s.TimePosition = 0 -- эпичная — каждый раз с начала
				s:Play()
			end
		elseif t.Mix <= 0 and s.IsPlaying then
			s:Pause()
		end
	end
end

function Music.init(gui: ScreenGui)
	local folder = Instance.new("Folder")
	folder.Name = "PcsMusic"
	folder.Parent = SoundService
	for name, key in pairs({ Calm = "MUSIC_CALM", Epic = "MUSIC_EPIC" }) do
		local id = AudioData.soundId(Config.SOUNDS[key])
		if id then
			local s = Instance.new("Sound")
			s.Name = "Music" .. name
			s.SoundId = id
			s.Looped = true
			s.Volume = 0
			s.Parent = folder
			tracks[name] = {
				Sound = s,
				Mix = 0,
				Base = if name == "Epic" then Config.MUSIC.EPIC_VOLUME else Config.MUSIC.CALM_VOLUME,
			}
		end
	end
	gui:SetAttribute(
		"MusicTracks",
		(if tracks.Calm then "Calm" else "") .. (if tracks.Epic then "Epic" else "")
	)
	gui:GetAttributeChangedSignal("HuntActive"):Connect(function()
		hunt = gui:GetAttribute("HuntActive") == true
	end)
	ClientState.onCore(function(core)
		settings = AudioData.normalize(core and core.Audio)
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
	end)
end

function Music.sfx(key: string, pos: Vector3?, volume: number?)
	local id = AudioData.soundId(Config.SOUNDS[key])
	if not id or not settings.Sfx then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. key
	s.SoundId = id
	s.Volume = volume or Config.MUSIC.SFX_VOLUME
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
