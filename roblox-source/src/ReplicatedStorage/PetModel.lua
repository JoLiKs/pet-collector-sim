--!strict
-- Строит модель питомца из простых примитивов (Ball/Block/Cylinder). Никаких внешних ассетов.
-- Все части Anchored — модель двигается через Model:PivotTo (клиентская анимация следования).
-- Передняя сторона питомца = -Z (LookVector), хвост сзади (+Z).
local PetData = require(script.Parent.PetData)

local PetModel = {}

local GOLD = Color3.fromRGB(255, 208, 70)
local BLACK = Color3.fromRGB(25, 25, 30)
local WHITE = Color3.fromRGB(255, 255, 255)

local function addPart(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = model
	return p
end

local function ball(
	model: Model,
	name: string,
	d: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return addPart(model, name, Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(pos), color, material)
end

local function block(
	model: Model,
	name: string,
	size: Vector3,
	pos: Vector3,
	rot: CFrame?,
	color: Color3,
	material: Enum.Material?
): Part
	local cf = CFrame.new(pos)
	if rot then
		cf = cf * rot
	end
	return addPart(model, name, Enum.PartType.Block, size, cf, color, material)
end

function PetModel.build(petId: string, gold: boolean?): Model
	local def = PetData.PetsById[petId]
	local model = Instance.new("Model")
	model.Name = petId

	if not def then
		local fallback = ball(model, "Body", 1.5, Vector3.zero, Color3.fromRGB(200, 200, 200), nil)
		model.PrimaryPart = fallback
		return model
	end

	local look = def.Look
	local scale = PetData.Rarities[def.Rarity].Scale * 0.9
	local bodyColor = if gold then GOLD else look.Body
	local accent = look.Accent
	local mat = if gold then Enum.Material.Metal else Enum.Material.SmoothPlastic

	-- ----- Тело и голова -----
	local br: number -- радиус тела
	local hr: number -- радиус головы
	local headPos: Vector3
	local body: Part

	if look.Shape == "Tall" then
		br = 0.7 * scale
		hr = 0.55 * scale
		body = ball(model, "Body", br * 2, Vector3.zero, bodyColor, mat)
		headPos = Vector3.new(0, br + hr * 0.55, 0)
		ball(model, "Head", hr * 2, headPos, bodyColor, mat)
	elseif look.Shape == "Wide" then
		br = 0.95 * scale
		hr = 0.55 * scale
		body = ball(model, "Body", br * 2, Vector3.zero, bodyColor, mat)
		headPos = Vector3.new(0, br * 0.45, -br * 0.75)
		ball(model, "Head", hr * 2, headPos, bodyColor, mat)
		-- лапки
		ball(model, "FootL", 0.45 * scale, Vector3.new(-br * 0.55, -br * 0.8, -br * 0.3), accent, mat)
		ball(model, "FootR", 0.45 * scale, Vector3.new(br * 0.55, -br * 0.8, -br * 0.3), accent, mat)
	else -- Round
		br = 0.8 * scale
		hr = br
		body = ball(model, "Body", br * 2, Vector3.zero, bodyColor, mat)
		headPos = Vector3.zero
	end
	model.PrimaryPart = body

	-- ----- Глаза -----
	local eyeD = hr * 0.38
	for _, side in ipairs({ -1, 1 }) do
		local eyePos = headPos + Vector3.new(side * hr * 0.38, hr * 0.12, -hr * 0.88)
		ball(model, "Eye", eyeD, eyePos, BLACK, nil)
		ball(
			model,
			"Glint",
			eyeD * 0.35,
			eyePos + Vector3.new(side * -0.02, eyeD * 0.22, -eyeD * 0.38),
			WHITE,
			nil
		)
	end

	-- ----- Уши -----
	if look.Ears == "Round" then
		for _, side in ipairs({ -1, 1 }) do
			ball(model, "Ear", hr * 0.55, headPos + Vector3.new(side * hr * 0.68, hr * 0.78, 0), accent, mat)
		end
	elseif look.Ears == "Long" then
		for _, side in ipairs({ -1, 1 }) do
			block(
				model,
				"Ear",
				Vector3.new(hr * 0.28, hr * 1.1, hr * 0.22),
				headPos + Vector3.new(side * hr * 0.38, hr * 1.35, 0),
				CFrame.Angles(0, 0, math.rad(-side * 10)),
				bodyColor,
				mat
			)
		end
	elseif look.Ears == "Pointy" then
		for _, side in ipairs({ -1, 1 }) do
			block(
				model,
				"Ear",
				Vector3.new(hr * 0.34, hr * 0.7, hr * 0.2),
				headPos + Vector3.new(side * hr * 0.52, hr * 0.98, 0),
				CFrame.Angles(0, 0, math.rad(-side * 25)),
				accent,
				mat
			)
		end
	end

	-- ----- Дополнения -----
	local topY = headPos.Y + hr
	for _, extra in ipairs(look.Extras) do
		if extra == "Tail" then
			ball(model, "Tail", br * 0.7, Vector3.new(0, -br * 0.15, br + br * 0.2), accent, mat)
		elseif extra == "Wings" then
			for _, side in ipairs({ -1, 1 }) do
				block(
					model,
					"Wing",
					Vector3.new(0.1 * scale, br * 1.0, br * 0.8),
					Vector3.new(side * (br + 0.05), br * 0.2, br * 0.15),
					CFrame.Angles(0, 0, math.rad(side * 22)),
					accent,
					if gold then Enum.Material.Neon else mat
				)
			end
		elseif extra == "Horn" then
			block(
				model,
				"Horn",
				Vector3.new(hr * 0.2, hr * 0.65, hr * 0.2),
				headPos + Vector3.new(0, hr * 1.0, -hr * 0.15),
				CFrame.Angles(math.rad(-12), 0, 0),
				Color3.fromRGB(250, 240, 220),
				nil
			)
		elseif extra == "Crown" then
			local cy = topY + hr * 0.18
			block(
				model,
				"CrownBase",
				Vector3.new(hr * 0.9, hr * 0.2, hr * 0.9),
				Vector3.new(0, cy, headPos.Z),
				nil,
				GOLD,
				Enum.Material.Metal
			)
			for _, dx in ipairs({ -0.3, 0, 0.3 }) do
				block(
					model,
					"CrownSpike",
					Vector3.new(hr * 0.2, hr * 0.3, hr * 0.2),
					Vector3.new(dx * hr, cy + hr * 0.24, headPos.Z),
					nil,
					GOLD,
					Enum.Material.Metal
				)
			end
		elseif extra == "Antenna" then
			for _, side in ipairs({ -1, 1 }) do
				block(
					model,
					"Antenna",
					Vector3.new(0.07, hr * 0.7, 0.07),
					headPos + Vector3.new(side * hr * 0.3, hr * 1.05, -hr * 0.1),
					CFrame.Angles(0, 0, math.rad(-side * 15)),
					BLACK,
					nil
				)
				ball(
					model,
					"AntennaTip",
					hr * 0.2,
					headPos + Vector3.new(side * hr * 0.4, hr * 1.42, -hr * 0.1),
					accent,
					Enum.Material.Neon
				)
			end
		elseif extra == "Fins" then
			for _, side in ipairs({ -1, 1 }) do
				block(
					model,
					"Fin",
					Vector3.new(br * 0.7, 0.08 * scale, br * 0.5),
					Vector3.new(side * (br + 0.2 * scale), -br * 0.1, 0),
					CFrame.Angles(0, 0, math.rad(side * -25)),
					accent,
					mat
				)
			end
		elseif extra == "Flame" then
			ball(
				model,
				"Flame",
				hr * 0.6,
				Vector3.new(0, topY + hr * 0.2, headPos.Z + hr * 0.2),
				Color3.fromRGB(255, 120, 30),
				Enum.Material.Neon
			)
			ball(
				model,
				"FlameCore",
				hr * 0.32,
				Vector3.new(0, topY + hr * 0.22, headPos.Z + hr * 0.2),
				Color3.fromRGB(255, 230, 100),
				Enum.Material.Neon
			)
		elseif extra == "Beak" then
			block(
				model,
				"Beak",
				Vector3.new(hr * 0.4, hr * 0.22, hr * 0.35),
				headPos + Vector3.new(0, -hr * 0.12, -hr * 0.98),
				nil,
				accent,
				nil
			)
		elseif extra == "Halo" then
			local halo = addPart(
				model,
				"Halo",
				Enum.PartType.Cylinder,
				Vector3.new(0.08, hr * 1.5, hr * 1.5),
				CFrame.new(0, topY + hr * 0.75, headPos.Z) * CFrame.Angles(0, 0, math.rad(90)),
				accent,
				Enum.Material.Neon
			)
			halo.Transparency = 0.15
		elseif extra == "Leaf" then
			block(
				model,
				"Leaf",
				Vector3.new(hr * 0.7, 0.06, hr * 0.4),
				headPos + Vector3.new(hr * 0.15, hr * 1.0, 0),
				CFrame.Angles(0, 0, math.rad(-25)),
				Color3.fromRGB(80, 190, 80),
				nil
			)
		end
	end

	return model
end

return PetModel
