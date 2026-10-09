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

-- "Epic" | "Rain" | "Calm" | nil. Приоритет (v3.3): «Суперсила» (Epic) > «Дождь монет» (Rain, только пока
-- событие идёт) > спокойная тема; если нужного трека нет — запасной из имеющихся.
function AudioData.musicTarget(
	hunt: boolean,
	hasCalm: boolean,
	hasEpic: boolean,
	rain: boolean?,
	hasRain: boolean?
): string?
	if hunt and hasEpic then
		return "Epic"
	end
	if rain and hasRain then
		return "Rain"
	end
	if hasCalm then
		return "Calm"
	end
	if hasEpic then
		return "Epic"
	end
	return if hasRain then "Rain" else nil
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

-- ---------------------------------------------------------------------------
-- v3.2: здоровье звуковых ассетов. Если ассет не загрузился (например, отклонён модерацией), звук помечается
-- сломанным: одна запись в лог, дальше он просто пропускается (без повторных Play и спама ошибок).
-- Пока ассет грузится, Play повторяется не чаще RETRY секунд.
-- ---------------------------------------------------------------------------
AudioData.RETRY = 3

export type Health = {
	Failed: { [string]: string },
	Tries: { [string]: number },
	Fails: { [string]: number },
	Waits: { [string]: number },
}

function AudioData.newHealth(): Health
	return { Failed = {}, Tries = {}, Fails = {}, Waits = {} }
end

-- ---------------------------------------------------------------------------
-- v3.2.2: результат загрузки ассета (ContentProvider.PreloadAsync). Первая загрузка большого трека в Roblox
-- нередко отдаёт TimedOut — это НЕ поломка: повторяем с нарастающей паузой бесконечно. Сломанным ассет
-- считается только после MAX_FAILURES подряд статусов Failure.
-- Возвращает "ok" | "retry" | "broken" и паузу до повтора (для "retry").
-- ---------------------------------------------------------------------------
AudioData.MAX_FAILURES = 3
AudioData.BACKOFF = { 2, 4, 8, 15, 30 }

function AudioData.retryDelay(n: number): number
	local b = AudioData.BACKOFF
	return b[math.clamp(n, 1, #b)]
end

function AudioData.loadResult(h: Health, key: string, status: string): (string, number?)
	if status == "Success" then
		h.Fails[key] = 0
		h.Waits[key] = 0
		return "ok", nil
	end
	if status == "Failure" then
		local n = (h.Fails[key] or 0) + 1
		h.Fails[key] = n
		if n >= AudioData.MAX_FAILURES then
			return "broken", nil
		end
		return "retry", AudioData.retryDelay(n)
	end
	-- TimedOut и прочее (None, Loading) — только повтор, никогда не «сломан»
	local w = (h.Waits[key] or 0) + 1
	h.Waits[key] = w
	return "retry", AudioData.retryDelay(w)
end

-- строка состояния музыки для окна настроек: "off" | "playing" | "loading" | "error" (+ код ошибки)
function AudioData.musicStatus(
	enabled: boolean,
	hasTrack: boolean,
	loaded: boolean,
	playing: boolean,
	err: string?
): (string, string?)
	if not enabled then
		return "off", nil
	end
	if not hasTrack then
		return "error", err or "no track" -- l10n-ok
	end
	if loaded and playing then
		return "playing", nil
	end
	return "loading", nil
end

-- true — это первая ошибка по ключу (её нужно записать в лог); повторные — false
function AudioData.reportFailure(h: Health, key: string, why: string?): boolean
	if h.Failed[key] ~= nil then
		return false
	end
	h.Failed[key] = why or "load failed" -- l10n-ok
	return true
end

function AudioData.isFailed(h: Health, key: string): boolean
	return h.Failed[key] ~= nil
end

-- можно ли сейчас вызвать Play для ключа (не сломан и с прошлой попытки прошло RETRY секунд); отмечает попытку
function AudioData.tryPlay(h: Health, key: string, now: number): boolean
	if h.Failed[key] ~= nil then
		return false
	end
	local last = h.Tries[key]
	if last and now - last < AudioData.RETRY then
		return false
	end
	h.Tries[key] = now
	return true
end

-- строка для атрибута/теста: сломанные ключи через запятую (по алфавиту)
function AudioData.failedList(h: Health): string
	local keys = {}
	for k in pairs(h.Failed) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

return AudioData
