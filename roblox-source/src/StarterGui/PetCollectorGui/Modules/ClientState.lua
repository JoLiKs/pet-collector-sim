--!nonstrict
-- Клиентское состояние: хранит последний снимок от сервера и рассылает подписчикам.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientState = {}

ClientState.Core = nil :: any
ClientState.Pets = {} :: { [string]: { Id: string, Gold: boolean } }
ClientState.ReceivedClock = os.clock()
ClientState.TimeOffset = 0

local coreListeners: { (any) -> () } = {}
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
