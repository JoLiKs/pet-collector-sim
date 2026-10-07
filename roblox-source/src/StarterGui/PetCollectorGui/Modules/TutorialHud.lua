--!nonstrict
--[[
	TutorialHud — плашка обучения первой сессии (v2.4, аудит Г3). Только отображение:
	шаги и прогресс приходят в снимке ядра (core.Tutorial), всё засчитывает сервер (TutorialService).
	Расположение зависит от раскладки (Layout): под плашкой мира на широком экране, слева над кнопкой
	удара в портрете, под меню в ландшафте. Кнопка «Пропустить» — действие TutorialSkip.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local TutorialData = require(Shared:WaitForChild("TutorialData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local TutorialHud = {}

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
			box.AnchorPoint = Vector2.new(0, 1)
			-- над кнопками «УДАР»/«СОБРАТЬ», на всю ширину: текст не мельче 11 px
			box.Position = UDim2.new(0, 12, 1, -188)
			box.Size = UDim2.fromOffset(math.max(200, li.W - 24), 50)
			tsc.MinTextSize = 11
		elseif li.Mode == "landscape" then
			box.AnchorPoint = Vector2.new(0, 0)
			box.Position = UDim2.fromOffset(172, 118)
			box.Size = UDim2.fromOffset(336, 44)
			tsc.MinTextSize = 9
		else
			box.AnchorPoint = Vector2.new(0.5, 0)
			box.Position = UDim2.new(0.5, 0, 0, 102)
			box.Size = UDim2.fromOffset(420, 36)
			tsc.MinTextSize = 9
		end
	end)

	local function refresh()
		local core = ClientState.Core
		local t = core and core.Tutorial
		local step = t and TutorialData.Steps[t.Step]
		box.Visible = step ~= nil
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
	L.onChanged(refresh)
end

return TutorialHud
