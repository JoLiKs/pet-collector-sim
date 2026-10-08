--!nonstrict
--[[
	TutorialHud — плашка обучения первой сессии (v2.4, аудит Г3). Только отображение:
	шаги и прогресс приходят в снимке ядра (core.Tutorial), всё засчитывает сервер (TutorialService).
	v2.5: плашка над хотбаром (в портрете — между кнопками и валютами), а нужный элемент HUD подсвечивается
	пульсирующей рамкой: «сбор» — слот 2 (магнит), «яйцо» — кнопка «Яйца», «в команду» — «Питомцы»,
	«враг» — слот 1 (меч). Кнопка «Пропустить» — действие TutorialSkip.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local TutorialData = require(Shared:WaitForChild("TutorialData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local TutorialHud = {}

-- шаг обучения → имя подсвечиваемого элемента HUD
TutorialHud.TARGETS = { collect = "Slot2", hatch = "EggsBtn", equip = "PetsBtn", kill = "Slot1" }

function TutorialHud.init(gui: ScreenGui)
	local box = Widgets.New("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 102),
		Size = UDim2.fromOffset(420, 36),
		BackgroundColor3 = Theme.Blue,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	Widgets.corner(box, 10)
	Widgets.stroke(box, Color3.new(1, 1, 1), 2).Transparency = 0.4
	local text = Widgets.label({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -96, 1, -6),
		Position = UDim2.fromOffset(10, 3),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font,
		ZIndex = 6,
		Parent = box,
	})
	local tsc = Widgets.New("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9, Parent = text })
	Widgets.button({
		Name = "Skip",
		Text = L.k("tutorial.skip"),
		Color = Theme.BgLight,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(80, 26),
		MaxTextSize = 13,
		ZIndex = 6,
		OnClick = function()
			Actions.call("TutorialSkip")
		end,
		Parent = box,
	})

	Layout.onChanged(function(li)
		if li.Mode == "portrait" then
			box.AnchorPoint = Vector2.new(0.5, 0)
			box.Position = UDim2.new(0.5, 0, 0.45, 132)
			box.Size = UDim2.fromOffset(math.max(200, li.W - 24), 48)
			tsc.MinTextSize = 11
		elseif li.Mode == "landscape" then
			box.AnchorPoint = Vector2.new(0.5, 1)
			box.Position = UDim2.new(0.5, 0, 1, -74)
			box.Size = UDim2.fromOffset(math.min(330, li.W - 420), 42)
			tsc.MinTextSize = 10
		else
			box.AnchorPoint = Vector2.new(0.5, 1)
			box.Position = UDim2.new(0.5, 0, 1, -100)
			box.Size = UDim2.fromOffset(470, 40)
			tsc.MinTextSize = 10
		end
	end)

	-- подсветка нужного элемента HUD
	local ring = Widgets.New("Frame", {
		Name = "TutorialRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		ZIndex = 12,
		Visible = false,
	})
	Widgets.corner(ring, 16)
	local ringStroke = Widgets.stroke(ring, Theme.Gold, 4)
	local pulse = 0
	RunService.Heartbeat:Connect(function(dt)
		if ring.Visible then
			pulse += dt * 5
			ringStroke.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(pulse))
		end
	end)
	local function highlight(name: string?)
		local target = name and gui:FindFirstChild(name, true)
		if target and target:IsA("GuiObject") then
			ring.Parent = target
			ring.Visible = true
		else
			ring.Visible = false
			ring.Parent = nil
		end
	end

	local function refresh()
		local core = ClientState.Core
		local t = core and core.Tutorial
		local step = t and TutorialData.Steps[t.Step]
		-- v2.8: не одновременно с окном ежедневной награды (у новичка оно показывается первым)
		if ClientState.Flags.DailyOpen or ClientState.Flags.DailyPending then
			step = nil
		end
		box.Visible = step ~= nil
		highlight(step and TutorialHud.TARGETS[step.Id])
		if not step then
			return
		end
		text.Text = L.t("tutorial.title", {
			i = t.Step,
			n = #TutorialData.Steps,
			text = L.t(step.Text, { c = step.Count }),
		}) .. (if step.Count > 1 then L.t("tutorial.progress", { p = t.P, c = step.Count }) else "")
	end
	ClientState.onCore(refresh)
	ClientState.onFlag(refresh)
	L.onChanged(refresh)
end

return TutorialHud
