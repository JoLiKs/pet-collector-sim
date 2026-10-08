--!strict
--[[
	Logo (v2.6) — логотип игры для экрана загрузки и таблички в хабе.
	Config.ASSETS.LOGO ~= 0 -> картинка (загруженная assets/icon_512.png); 0 -> логотип из примитивов GUI:
	солнечные лучи, яйцо, меч, монета и самоцвет (Icons.lua) на ярком градиенте — без картинок и эмодзи.
	Logo.make(props) -> Frame (квадрат): props Name, Size, Position, AnchorPoint, ZIndex, Parent, Px (размер в пикселях).
]]
local Assets = require(script.Parent.Assets)
local Icons = require(script.Parent.Icons)

local Logo = {}

local c3 = Color3.fromRGB

function Logo.make(props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local px: number = p.Px or 200
	local z: number = p.ZIndex or 1
	local root = Instance.new("Frame")
	root.Name = p.Name or "Logo"
	root.Size = p.Size or UDim2.fromOffset(px, px)
	root.Position = p.Position or UDim2.new()
	root.AnchorPoint = p.AnchorPoint or Vector2.zero
	root.BackgroundTransparency = 1
	root.ZIndex = z
	local img = Assets.image("LOGO")
	if img then
		root:SetAttribute("LogoKind", "image")
		local il = Instance.new("ImageLabel")
		il.Name = "Image"
		il.BackgroundTransparency = 1
		il.Image = img
		il.ScaleType = Enum.ScaleType.Fit
		il.Size = UDim2.fromScale(1, 1)
		il.ZIndex = z + 1
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.18, 0)
		cr.Parent = il
		il.Parent = root
	else
		root:SetAttribute("LogoKind", "primitives")
		local bg = Instance.new("Frame")
		bg.Name = "Bg"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.new(1, 1, 1)
		bg.BorderSizePixel = 0
		bg.ZIndex = z + 1
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.18, 0)
		cr.Parent = bg
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(c3(255, 230, 110), c3(255, 125, 40))
		g.Rotation = 90
		g.Parent = bg
		local st = Instance.new("UIStroke")
		st.Color = c3(27, 24, 64)
		st.Thickness = math.max(2, px * 0.03)
		st.Parent = bg
		bg.Parent = root
		-- лучи: тонкие полосы через центр (вписаны в круг — не выходят за квадрат)
		for i = 0, 5 do
			local ray = Instance.new("Frame")
			ray.Name = "Ray" .. i
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromScale(0.94, 0.11)
			ray.Rotation = i * 30
			ray.BackgroundColor3 = Color3.new(1, 1, 1)
			ray.BackgroundTransparency = 0.72
			ray.BorderSizePixel = 0
			ray.ZIndex = z + 2
			ray.Parent = root
		end
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.52)
		glow.Size = UDim2.fromScale(0.7, 0.7)
		glow.BackgroundColor3 = c3(255, 250, 200)
		glow.BackgroundTransparency = 0.45
		glow.BorderSizePixel = 0
		glow.ZIndex = z + 3
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0.5, 0)
		gc.Parent = glow
		glow.Parent = root
		local function icon(kind: string, x: number, y: number, s: number, zz: number)
			Icons.make(kind, {
				Name = kind,
				Px = px * s,
				Size = UDim2.fromScale(s, s),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				ZIndex = zz,
				Parent = root,
			})
		end
		icon("Sword", 0.58, 0.43, 0.7, z + 4)
		icon("Egg", 0.46, 0.56, 0.56, z + 20)
		icon("Coin", 0.2, 0.22, 0.26, z + 40)
		icon("Gem", 0.82, 0.78, 0.24, z + 40)
		icon("Coin", 0.2, 0.8, 0.2, z + 40)
	end
	if p.Parent then
		root.Parent = p.Parent
	end
	return root
end

return Logo
