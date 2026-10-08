--!nonstrict
-- Клиентское состояние: хранит последний снимок от сервера и рассылает подписчикам.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = {}

ClientState.Core = nil :: any
ClientState.Pets = {} :: { [string]: any }
ClientState.ReceivedClock = os.clock()
ClientState.TimeOffset = 0

local coreListeners: { (any) -> () } = {}
-- v2.8: клиентские флаги интерфейса (например, «окно ежедневной награды открыто/ждёт показа» —
-- чтобы плашка обучения не появлялась одновременно с ним)
ClientState.Flags = {} :: { [string]: any }
local flagListeners: { (string, any) -> () } = {}

function ClientState.setFlag(name: string, value: any)
	if ClientState.Flags[name] == value then
		return
	end
	ClientState.Flags[name] = value
	for _, fn in ipairs(flagListeners) do
		task.spawn(fn, name, value)
	end
end

function ClientState.onFlag(fn: (string, any) -> ())
	table.insert(flagListeners, fn)
end
local petListeners: { () -> () } = {}

function ClientState.onCore(fn: (any) -> ())
	table.insert(coreListeners, fn)
	if ClientState.Core then
		fn(ClientState.Core)
	end
end

function ClientState.onPets(fn: () -> ())
	table.insert(petListeners, fn)
end

-- Повторно рассылает последний снимок подписчикам (например, после смены языка)
function ClientState.refresh()
	if ClientState.Core then
		for _, fn in ipairs(coreListeners) do
			task.spawn(fn, ClientState.Core)
		end
	end
	for _, fn in ipairs(petListeners) do
		task.spawn(fn)
	end
end

-- v3.1: мгновенно применить подтверждённое сервером изменение (например, назначение быстрого слота),
-- не дожидаясь следующего снимка; следующий снимок от сервера всё равно перезапишет Core целиком.
function ClientState.patchCore(key: string, value: any)
	local core = ClientState.Core
	if type(core) ~= "table" then
		return
	end
	core[key] = value
	for _, fn in ipairs(coreListeners) do
		task.spawn(fn, core)
	end
end

-- Серверное время (unix) с поправкой, чтобы таймеры были одинаковыми у всех
function ClientState.serverNow(): number
	return os.time() + ClientState.TimeOffset
end

function ClientState.init()
	Remotes.getEvent("State").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Pets then
			ClientState.Pets = payload.Pets
			for _, fn in ipairs(petListeners) do
				task.spawn(fn)
			end
		end
		if payload.Core then
			ClientState.Core = payload.Core
			ClientState.ReceivedClock = os.clock()
			ClientState.TimeOffset = payload.Core.ServerTime - os.time()
			for _, fn in ipairs(coreListeners) do
				task.spawn(fn, payload.Core)
			end
		end
	end)
end

-- Просит сервер прислать полный снимок (на случай, если первый пакет пришёл до подключения UI)
function ClientState.requestResync()
	task.spawn(function()
		local fn = Remotes.getFunction("Action")
		for _ = 1, 30 do
			local ok, result = pcall(fn.InvokeServer, fn, "Resync")
			if ok and type(result) == "table" and result.ok then
				return
			end
			task.wait(1)
		end
	end)
end

return ClientState
