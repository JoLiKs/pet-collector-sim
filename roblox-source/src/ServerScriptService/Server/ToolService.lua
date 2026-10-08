--!strict
--[[
	ToolService (v2.5) — настоящие инструменты в Backpack вместо кнопок «УДАР» и «СОБРАТЬ».
	  * "Sword"     — меч: выбран в хотбаре → клик/тап по миру = удар (клиент: AttackFx + действие Attack);
	  * "Collector" — магнит сбора: удержание клика/тапа = сбор монет (remote Click, сервер ограничивает частоту).
	Модели собираются кодом и кладутся в StarterPack: Roblox сам копирует их в Backpack при каждом появлении
	персонажа. Сервер не слушает Activated — урон и монеты считают существующие действия (Attack/Click),
	поэтому античит и лимиты прежние. Детали инструмента без коллизий и запросов (не мешают рейкастам).
]]
local StarterPack = game:GetService("StarterPack")

local ToolService = {}

ToolService.NAMES = { "Sword", "Collector" }

local function part(
	tool: Tool,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	if handle then
		p.CFrame = handle.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	else
		p.CFrame = offset
	end
	p.Parent = tool
	return p
end

-- Ось Y рукояти смотрит вперёд из кулака (стандартный RightGrip Roblox), Grip сдвигает хват к низу рукояти
function ToolService.buildSword(): Tool
	local t = Instance.new("Tool")
	t.Name = "Sword"
	t.ToolTip = "Sword"
	t.CanBeDropped = false
	t.RequiresHandle = true
	t.Grip = CFrame.new(0, -0.35, 0)
	local base = CFrame.new(0, 50, 0)
	part(t, "Handle", Vector3.new(0.32, 1.2, 0.32), base, Color3.fromRGB(110, 70, 42), Enum.Material.Wood)
	part(
		t,
		"Pommel",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(0, -0.7, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	part(
		t,
		"Guard",
		Vector3.new(1.3, 0.26, 0.42),
		CFrame.new(0, 0.68, 0),
		Color3.fromRGB(255, 200, 60),
		Enum.Material.SmoothPlastic
	)
	part(
		t,
		"Blade",
		Vector3.new(0.2, 3.2, 0.55),
		CFrame.new(0, 2.4, 0),
		Color3.fromRGB(215, 225, 240),
		Enum.Material.SmoothPlastic
	)
	part(
		t,
		"Edge",
		Vector3.new(0.24, 3.0, 0.12),
		CFrame.new(0, 2.35, -0.3),
		Color3.fromRGB(120, 220, 255),
		Enum.Material.Neon
	)
	part(
		t,
		"Tip",
		Vector3.new(0.2, 0.42, 0.42),
		CFrame.new(0, 4.05, 0) * CFrame.Angles(math.rad(45), 0, 0),
		Color3.fromRGB(215, 225, 240),
		Enum.Material.SmoothPlastic
	)
	return t
end

function ToolService.buildCollector(): Tool
	local t = Instance.new("Tool")
	t.Name = "Collector"
	t.ToolTip = "Collector"
	t.CanBeDropped = false
	t.RequiresHandle = true
	t.Grip = CFrame.new(0, -0.3, 0)
	local base = CFrame.new(0, 60, 0)
	part(
		t,
		"Handle",
		Vector3.new(0.34, 1.2, 0.34),
		base,
		Color3.fromRGB(70, 74, 90),
		Enum.Material.SmoothPlastic
	)
	local red = Color3.fromRGB(235, 60, 60)
	part(t, "Bar", Vector3.new(1.7, 0.45, 0.45), CFrame.new(0, 0.8, 0), red, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -0.62, 0.62 }) do
		part(
			t,
			"Prong",
			Vector3.new(0.45, 1.1, 0.45),
			CFrame.new(x, 1.5, 0),
			red,
			Enum.Material.SmoothPlastic
		)
		part(
			t,
			"PoleTip",
			Vector3.new(0.47, 0.32, 0.47),
			CFrame.new(x, 2.18, 0),
			Color3.fromRGB(255, 230, 120),
			Enum.Material.Neon
		)
	end
	return t
end

function ToolService.init()
	for _, name in ipairs(ToolService.NAMES) do
		local old = StarterPack:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	ToolService.buildSword().Parent = StarterPack
	ToolService.buildCollector().Parent = StarterPack
end

return ToolService
