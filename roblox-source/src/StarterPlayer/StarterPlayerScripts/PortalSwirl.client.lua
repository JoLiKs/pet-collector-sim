--!strict
-- v3.0: медленно вращает вихри арок порталов (модели с атрибутом PortalSwirl = скорость, рад/с).
-- Только визуал на клиенте; вращаются лишь вихри поблизости (экономия на телефонах).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NEAR = 140

type Swirl = { Model: Model, Base: CFrame, Speed: number, Angle: number }
local swirls: { Swirl } = {}

local function add(inst: Instance)
	if inst:IsA("Model") and inst:GetAttribute("PortalSwirl") ~= nil then
		local speed = inst:GetAttribute("PortalSwirl")
		table.insert(swirls, {
			Model = inst,
			Base = inst:GetPivot(),
			Speed = if type(speed) == "number" then speed else 0.7,
			Angle = 0,
		})
	end
end

local function scan(world: Instance)
	for _, d in ipairs(world:GetDescendants()) do
		add(d)
	end
	world.DescendantAdded:Connect(add)
end

local world = Workspace:FindFirstChild("World") or Workspace:WaitForChild("World", 30)
if world then
	scan(world)
end

local acc = 0
RunService.RenderStepped:Connect(function(dt: number)
	acc += dt
	if acc < 1 / 30 then
		return
	end
	local step = acc
	acc = 0
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = if root and root:IsA("BasePart") then root.Position else nil
	for _, s in ipairs(swirls) do
		if s.Model.Parent and (not at or (s.Base.Position - at).Magnitude < NEAR) then
			s.Angle = (s.Angle + s.Speed * step) % (math.pi * 2)
			s.Model:PivotTo(s.Base * CFrame.Angles(0, 0, s.Angle))
		end
	end
end)
