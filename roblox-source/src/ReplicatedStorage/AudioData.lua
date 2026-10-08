--!strict
--[[
	AudioData (v3.1) — общие правила звука для сервера и клиента.
	  * настройки игрока data.Settings.Audio = { Music = bool, Sfx = bool, MusicVol = 0..1 (шаг 0.1) };
	  * soundId: ID из Config.SOUNDS -> "rbxassetid://ID" или nil (0, не число, дробь — звука нет, игра молчит
	    без ошибок: так музыку можно выключить, не дожидаясь загрузки ассетов);
	  * musicTarget: какой трек должен звучать (эпичный во время «Суперсилы», иначе спокойный; если нужного
	    нет — запасной из имеющихся);
	  * fadeStep / gain: плавный кроссфейд (равная мощность, чтобы на стыке не было провала громкости).
]]
local AudioData = {}

AudioData.DEFAULT = { Music = true, Sfx = true, MusicVol = 0.6 }
AudioData.VOL_STEP = 0.1
AudioData.KEYS = { Music = "boolean", Sfx = "boolean", MusicVol = "number" }

local function round(v: number): number
	-- делением, а не умножением на 0.1: 6 / 10 == 0.6 точно (6 * 0.1 даёт 0.6000000000000001)
	local k = math.floor(1 / AudioData.VOL_STEP + 0.5)
	return math.floor(v * k + 0.5) / k
end

-- копия настроек с подставленными значениями по умолчанию и отсечёнными мусорными полями
function AudioData.normalize(a: any): { Music: boolean, Sfx: boolean, MusicVol: number }
	local src = if type(a) == "table" then a else {}
	local vol = src.MusicVol
	if type(vol) ~= "number" or vol ~= vol then
		vol = AudioData.DEFAULT.MusicVol
	end
	return {
		Music = if type(src.Music) == "boolean" then src.Music else AudioData.DEFAULT.Music,
		Sfx = if type(src.Sfx) == "boolean" then src.Sfx else AudioData.DEFAULT.Sfx,
		MusicVol = math.clamp(round(vol), 0, 1),
	}
end

-- сервер: изменить одно поле; возвращает новые настройки или nil, ключ ошибки
function AudioData.set(a: any, key: any, value: any): (any, string?)
	if type(key) ~= "string" or AudioData.KEYS[key] == nil then
		return nil, "err.bad_request"
	end
	if type(value) ~= AudioData.KEYS[key] then
		return nil, "err.bad_request"
	end
	if key == "MusicVol" and (value ~= value or value < 0 or value > 1) then
		return nil, "err.bad_request"
	end
	local out = AudioData.normalize(a)
	out[key] = if key == "MusicVol" then math.clamp(round(value), 0, 1) else value
	return out, nil
end

function AudioData.soundId(id: any): string?
	if type(id) == "number" and id > 0 and id == math.floor(id) and id < 2 ^ 53 then
		return "rbxassetid://" .. string.format("%d", id)
	end
	return nil
end

-- "Epic" | "Calm" | nil
function AudioData.musicTarget(hunt: boolean, hasCalm: boolean, hasEpic: boolean): string?
	if hunt and hasEpic then
		return "Epic"
	end
	if hasCalm then
		return "Calm"
	end
	return if hasEpic then "Epic" else nil
end

-- сдвиг «доли» трека к цели (0 или 1) за dt при длительности кроссфейда fade секунд
function AudioData.fadeStep(mix: number, target: number, dt: number, fade: number): number
	local step = if fade > 0 then dt / fade else 1
	if mix < target then
		return math.min(target, mix + step)
	end
	return math.max(target, mix - step)
end

-- громкость Sound: кривая равной мощности × базовая громкость трека × ползунок игрока (vol 0..1).
-- Выключение музыки — это цель 0 для всех треков (плавное затухание), а не мгновенный ноль.
function AudioData.gain(mix: number, base: number, vol: number): number
	return math.sin(math.clamp(mix, 0, 1) * math.pi / 2) * base * math.clamp(vol, 0, 1)
end

return AudioData
