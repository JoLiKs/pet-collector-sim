--!nonstrict
--[[
	Layout — режим раскладки HUD под размер экрана (v2.4, аудит В6).
	  * "wide"      — десктоп/планшет: исходная раскладка;
	  * "portrait"  — узкий экран (ширина < 700, высота больше ширины): телефон вертикально;
	  * "landscape" — низкий экран (высота < 500): телефон горизонтально.
	Модули HUD подписываются через Layout.onChanged(fn) и сами переставляют элементы (якоря + Scale).
	ViewportSize в разных средах не всегда шлёт сигнал изменения, поэтому размер опрашивается раз в 0.5 с.
	Layout.isTouch() — тач-устройство: подписи клавиш ([Q], [F]) не показываются.
]]
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Layout = {}

export type Info = { Mode: string, W: number, H: number, Touch: boolean }

local listeners: { (Info) -> () } = {}
local current: Info = { Mode = "wide", W = 1280, H = 720, Touch = false }

-- Чистая функция (покрыта тестом): режим по размеру экрана
function Layout.modeFor(w: number, h: number): string
	if w < 700 and h >= w then
		return "portrait"
	end
	if h < 500 or w < 700 then
		return "landscape"
	end
	return "wide"
end

local function measure(): Info
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local w, h = vp.X, vp.Y
	if w <= 1 or h <= 1 then
		w, h = 1280, 720
	end
	return { Mode = Layout.modeFor(w, h), W = w, H = h, Touch = UserInputService.TouchEnabled == true }
end

function Layout.get(): Info
	return current
end

function Layout.compact(): boolean
	return current.Mode ~= "wide"
end

function Layout.isTouch(): boolean
	return current.Touch
end

-- Ширина правой колонки (плашка мира, события, охота, трекер) в компактных режимах
function Layout.rightWidth(info: Info): number
	if info.Mode == "portrait" then
		return math.clamp(info.W - 196, 150, 300)
	elseif info.Mode == "landscape" then
		return math.clamp(info.W - 528, 150, 260)
	end
	return 250
end

-- Верх колонки событий (под плашкой мира и строкой множителей)
function Layout.eventsTop(info: Info): number
	if info.Mode == "portrait" then
		return 84
	elseif info.Mode == "landscape" then
		return 80
	end
	return 12
end

-- fn вызывается сразу и при каждой смене режима/размера/тача
function Layout.onChanged(fn: (Info) -> ())
	table.insert(listeners, fn)
	fn(current)
end

local started = false
function Layout.init()
	if started then
		return
	end
	started = true
	current = measure()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local m = measure()
		if
			m.Mode ~= current.Mode
			or math.abs(m.W - current.W) > 1
			or math.abs(m.H - current.H) > 1
			or m.Touch ~= current.Touch
		then
			current = m
			for _, fn in ipairs(listeners) do
				task.spawn(fn, current)
			end
		end
	end)
end

Layout.init()

return Layout
