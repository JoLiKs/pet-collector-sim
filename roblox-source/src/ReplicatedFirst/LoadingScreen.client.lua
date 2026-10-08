--!nonstrict
--[[
	LoadingScreen (v2.6) — свой экран загрузки с логотипом игры (Logo: картинка Config.ASSETS.LOGO или логотип из
	примитивов). Показывается сразу (ReplicatedFirst), убирается, когда игра загружена и построен основной интерфейс.
	Текста почти нет: название игры — имя собственное, точки-индикатор вместо слова «Загрузка».
]]
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local bg = Instance.new("Frame")
bg.Name = "Bg"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(80, 170, 255), Color3.fromRGB(60, 30, 160))
grad.Rotation = 90
grad.Parent = bg
bg.Parent = gui

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logo = require(Shared:WaitForChild("Logo"))
local logo = Logo.make({
	Name = "Logo",
	Px = 220,
	Size = UDim2.fromOffset(220, 220),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	ZIndex = 2,
	Parent = bg,
})
local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0.42, 128)
title.Size = UDim2.fromOffset(520, 56)
title.Font = Enum.Font.FredokaOne
title.Text = "Pet Collector Simulator" -- l10n-ok (название игры)
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 220, 70)
title.ZIndex = 5
local ts = Instance.new("UIStroke")
ts.Color = Color3.fromRGB(27, 24, 64)
ts.Thickness = 4
ts.Parent = title
local tc = Instance.new("UITextSizeConstraint")
tc.MaxTextSize = 44
tc.Parent = title
title.Parent = bg

-- индикатор: три точки по очереди
local dots = {}
for i = 1, 3 do
	local d = Instance.new("Frame")
	d.Name = "Dot" .. i
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.new(0.5, (i - 2) * 30, 0.42, 212)
	d.Size = UDim2.fromOffset(16, 16)
	d.BackgroundColor3 = Color3.new(1, 1, 1)
	d.ZIndex = 5
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = d
	d.Parent = bg
	dots[i] = d
end
local logoScale = Instance.new("UIScale")
logoScale.Parent = logo
gui.Parent = playerGui

local done = false
task.spawn(function()
	local k = 0
	while not done do
		k += 1
		for i, d in ipairs(dots) do
			d.BackgroundTransparency = if (k % 3) + 1 == i then 0 else 0.6
		end
		logoScale.Scale = if k % 2 == 0 then 1 else 1.04
		task.wait(0.25)
	end
end)

local t0 = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
playerGui:WaitForChild("PetCollectorGui", 30)
task.wait(math.max(0, 1.2 - (os.clock() - t0))) -- логотип виден хотя бы ~1 с
done = true
local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(bg, info, { Position = UDim2.fromScale(0, -1) }):Play()
task.wait(0.5)
gui:Destroy()
