--!strict
-- Боевые эффекты от сервера: удары других игроков и попадания (вспышка/искры). Урон считается только на сервере.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("AttackFx"))
local Remotes = require(Shared:WaitForChild("Remotes"))

Remotes.getEvent("CombatFx").OnClientEvent:Connect(function(kind: any, a: any, b: any)
	if kind == "Swing" and typeof(a) == "Instance" and a:IsA("Player") then
		if a ~= Players.LocalPlayer then -- свой удар уже нарисован по нажатию
			AttackFx.swing(a, false)
		end
	elseif kind == "Impact" and typeof(a) == "Vector3" then
		AttackFx.impact(a, if typeof(b) == "Vector3" then b else nil)
	end
end)
