--!strict
--[[
	WorldLocalizer: перевод текстов мира (билборды, таблички, ProximityPrompt) на язык игрока.
	Сервер пишет английский текст и атрибут Loc_<Свойство> = закодированный ключ+аргументы (Locale.setWorld).
	Клиент локально подменяет свойство на текст своего языка и перерисовывает его:
	  - при появлении инстанса и изменении атрибута;
	  - если сервер снова записал свойство (репликация может прийти после атрибута);
	  - при смене языка (Locale.onChanged).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local L = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))

local PREFIX = "Loc_"
local tracked: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any -- prop -> показанный текст
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isCandidate(inst: Instance): boolean
	return inst:IsA("TextLabel")
		or inst:IsA("TextButton")
		or inst:IsA("TextBox")
		or inst:IsA("ProximityPrompt")
end

local function apply(inst: Instance, prop: string)
	local enc = inst:GetAttribute(PREFIX .. prop)
	if type(enc) ~= "string" then
		return
	end
	local text = L.renderEncoded(L.lang(), enc)
	local shown = tracked[inst] or {}
	tracked[inst] = shown
	shown[prop] = text
	if (inst :: any)[prop] ~= text then
		(inst :: any)[prop] = text
	end
end

local function watchProp(inst: Instance, prop: string)
	local shown = tracked[inst]
	if shown and shown[prop] ~= nil then
		return -- уже подписаны на это свойство
	end
	apply(inst, prop)
	local ok, signal = pcall(function()
		return inst:GetPropertyChangedSignal(prop)
	end)
	if ok and signal then
		signal:Connect(function()
			local s = tracked[inst]
			if s and (inst :: any)[prop] ~= s[prop] then
				apply(inst, prop) -- сервер перезаписал текст — снова переводим (без зацикливания: сравнение с показанным)
			end
		end)
	end
end

local function scanAttrs(inst: Instance)
	for name in pairs(inst:GetAttributes()) do
		if string.sub(name, 1, #PREFIX) == PREFIX then
			watchProp(inst, string.sub(name, #PREFIX + 1))
		end
	end
end

local function watch(inst: Instance)
	if watched[inst] or not isCandidate(inst) then
		return
	end
	watched[inst] = true
	scanAttrs(inst)
	inst.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, #PREFIX) == PREFIX then
			local prop = string.sub(name, #PREFIX + 1)
			local shown = tracked[inst]
			if shown and shown[prop] ~= nil then
				apply(inst, prop)
			else
				watchProp(inst, prop)
			end
		end
	end)
end

for _, inst in ipairs(Workspace:GetDescendants()) do
	watch(inst)
end
Workspace.DescendantAdded:Connect(watch)

L.onChanged(function()
	for inst, props in pairs(tracked) do
		if inst.Parent then
			for prop in pairs(props) do
				apply(inst, prop)
			end
		end
	end
end)
