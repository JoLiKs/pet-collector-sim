--!strict
-- Единая точка создания/получения RemoteEvent и RemoteFunction.
-- Сервер создаёт их при старте (Remotes.init), клиент ждёт через WaitForChild.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

Remotes.Events = {
	"Fx", -- S->C: боевые эффекты (kind, ...)
	"CombatFx", -- S->C (игрокам рядом): ("Swing", attacker|model) | ("Impact", pos, dir) | Super*: см. SuperFx
	"Superpower", -- S->C: состояние события «Суперсила / Охота» (персонально: цель, HP, таймер, свой урон)
	"EventState", -- S->C: активные события и таймеры
	"Dialog", -- S->C: диалог NPC
	"OpenUi", -- S->C: открыть панель (станция в мире)
	"TradeUpdate", -- S->C: состояние обмена
	"Offline", -- S->C: оффлайн-награда при входе
	"Boards", -- S->C: таблицы лидеров
	"State", -- S->C: снимок состояния игрока
	"Notify", -- S->C: всплывающее сообщение (text, kind)
	"HatchResult", -- S->C: результат открытия яиц
	"OpenEgg", -- S->C: открыть окно яйца (eggId) — по ProximityPrompt
	"Click", -- C->S: сбор монет
}
Remotes.Functions = {
	"Action", -- C->S: все остальные действия (см. Router на сервере)
}

local folder: Folder? = nil

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init must be called on the server")
	local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
	end
	local fld = f :: Folder
	for _, name in ipairs(Remotes.Events) do
		if not fld:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = fld
		end
	end
	for _, name in ipairs(Remotes.Functions) do
		if not fld:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = fld
		end
	end
	folder = fld
end

local function getFolder(): Folder
	if folder then
		return folder
	end
	local f = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	folder = f
	return f
end

function Remotes.getEvent(name: string): RemoteEvent
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.getFunction(name: string): RemoteFunction
	return getFolder():WaitForChild(name) :: RemoteFunction
end

return Remotes
