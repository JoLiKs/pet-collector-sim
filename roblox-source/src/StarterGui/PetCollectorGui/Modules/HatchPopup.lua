--!nonstrict
-- Анимация результата открытия яиц: карточки с 3D-превью питомцев (ViewportFrame из примитивов).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local PetData = require(Shared:WaitForChild("PetData"))
local PetModel = require(Shared:WaitForChild("PetModel"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local HatchPopup = {}

local function petViewport(parent: Instance, petId: string, gold: boolean): ViewportFrame
	local vp = Widgets.New("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.55),
		Position = UDim2.fromOffset(0, 4),
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -0.8, 0.6),
		ZIndex = 53,
		Parent = parent,
	})
	local model = PetModel.build(petId, gold)
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = vp
	vp.CurrentCamera = cam
	local center, size = model:GetBoundingBox()
	local dist = size.Magnitude * 1.25
	-- питомец смотрит в -Z, камера стоит перед ним
	cam.CFrame =
		CFrame.lookAt(center.Position + Vector3.new(size.X * 0.35, size.Y * 0.25, -dist), center.Position)
	return vp
end

function HatchPopup.init(gui: ScreenGui)
	local overlay = Widgets.New("TextButton", {
		Name = "HatchOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 50,
		Parent = gui,
	})
	local title = Widgets.label({
		Text = "You hatched!",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.fromOffset(360, 56),
		Font = Theme.Font,
		TextColor3 = Theme.Gold,
		ZIndex = 51,
		Parent = overlay,
	})
	local row = Widgets.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0, 230),
		BackgroundTransparency = 1,
		ZIndex = 51,
		Parent = overlay,
	})
	Widgets.New("UISizeConstraint", { MaxSize = Vector2.new(640, 260), Parent = row })
	Widgets.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = row,
	})

	local buttons = Widgets.New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 140),
		Size = UDim2.fromOffset(340, 50),
		BackgroundTransparency = 1,
		ZIndex = 51,
		Parent = overlay,
	})
	Widgets.New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		Parent = buttons,
	})
	Widgets.button({
		Text = "Awesome!",
		Color = Theme.Green,
		Size = UDim2.fromOffset(160, 46),
		ZIndex = 52,
		OnClick = function()
			overlay.Visible = false
		end,
		Parent = buttons,
	})
	Widgets.button({
		Text = "Equip Best",
		Color = Theme.Blue,
		Size = UDim2.fromOffset(160, 46),
		ZIndex = 52,
		OnClick = function()
			Actions.call("EquipBest")
			overlay.Visible = false
		end,
		Parent = buttons,
	})
	overlay.Activated:Connect(function() end) -- перехватываем клики под окном

	Remotes.getEvent("HatchResult").OnClientEvent:Connect(function(results)
		if type(results) ~= "table" or #results == 0 then
			return
		end
		Widgets.clear(row)
		overlay.Visible = true
		local best = 0
		for i, r in ipairs(results) do
			local def = PetData.PetsById[r.Id]
			if def then
				local rarity = PetData.Rarities[def.Rarity]
				best = math.max(best, rarity.Order)
				local card = Widgets.New("Frame", {
					Size = UDim2.fromOffset(190, 220),
					BackgroundColor3 = Theme.BgCard,
					LayoutOrder = i,
					ZIndex = 52,
					Parent = row,
				})
				Widgets.corner(card, 16)
				Widgets.stroke(card, rarity.Color, 4)
				Widgets.New("UISizeConstraint", { MaxSize = Vector2.new(200, 230), Parent = card })
				local scale = Widgets.New("UIScale", { Scale = 0.2, Parent = card })
				petViewport(card, r.Id, r.Gold == true)
				Widgets.label({
					Text = (if r.Gold then "GOLDEN " else "") .. def.Name,
					Size = UDim2.new(1, -12, 0, 30),
					Position = UDim2.new(0, 6, 0.57, 0),
					TextColor3 = rarity.Color,
					Font = Theme.Font,
					ZIndex = 53,
					Parent = card,
				})
				Widgets.label({
					Text = def.Rarity,
					Size = UDim2.new(1, -12, 0, 20),
					Position = UDim2.new(0, 6, 0.57, 32),
					TextColor3 = Theme.TextDim,
					ZIndex = 53,
					Parent = card,
				})
				Widgets.label({
					Text = "Power x" .. Util.formatNumber(PetData.getPower(r.Id, r.Gold)),
					Size = UDim2.new(1, -12, 0, 24),
					Position = UDim2.new(0, 6, 0.57, 56),
					ZIndex = 53,
					Parent = card,
				})
				task.delay((i - 1) * 0.15, function()
					Widgets.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
			end
		end
		title.Text = if best >= 5 then "INCREDIBLE!" elseif best >= 4 then "Great find!" else "You hatched!"
	end)
end

return HatchPopup
