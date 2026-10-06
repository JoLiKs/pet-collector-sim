--!strict
-- Боевые эффекты от сервера: удары других игроков и ботов, попадания (вспышка/искры) и событие «Суперсила»
-- (аура суперигрока, превращение, ударная волна, остановка, оглушение). Урон считается только на сервере.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("AttackFx"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SuperFx = require(Shared:WaitForChild("SuperFx"))

Remotes.getEvent("CombatFx").OnClientEvent:Connect(function(kind: any, a: any, b: any)
	if kind == "Swing" and typeof(a) == "Instance" then
		if a:IsA("Player") then
			if a ~= Players.LocalPlayer then -- свой удар уже нарисован по нажатию
				AttackFx.swing(a, false)
			end
		elseif a:IsA("Model") then -- бот
			AttackFx.swing(a, false)
		end
	elseif kind == "Impact" and typeof(a) == "Vector3" then
		AttackFx.impact(a, if typeof(b) == "Vector3" then b else nil)
	elseif kind == "SuperStart" then
		if typeof(a) == "Instance" and a:IsA("Model") then
			SuperFx.aura(a)
		end
		if typeof(b) == "Vector3" then
			SuperFx.transform(b)
		end
	elseif kind == "Shockwave" and typeof(a) == "Vector3" then
		SuperFx.shockwave(a, if type(b) == "number" then b else 14)
	elseif kind == "SuperEnd" then
		SuperFx.clearAura()
		if typeof(a) == "Vector3" and b == "stopped" then
			SuperFx.burst(a)
		end
	elseif kind == "Stun" and typeof(a) == "Instance" and a:IsA("Model") then
		SuperFx.stun(a, if type(b) == "number" then b else 1)
	end
end)

-- Аура держится по состоянию события (на случай входа в середине раунда или респавна модели)
Remotes.getEvent("Superpower").OnClientEvent:Connect(function(st: any)
	if type(st) ~= "table" then
		return
	end
	local m = st.Model
	if st.Active and typeof(m) == "Instance" and m:IsA("Model") then
		SuperFx.aura(m)
	elseif not st.Active and SuperFx.auraModel() then
		SuperFx.clearAura()
	end
end)
