--!nonstrict
-- Всплывающие уведомления сверху экрана и баннеры событий (общий стек: совпавшие события не перекрывают друг друга).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local L = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Toasts = {}

local container: Frame
local order = 0

local function nextOrder(): number
	order += 1
	return order
end

local COLORS = {
	info = Theme.Blue,
	success = Theme.Green,
	error = Theme.Red,
	reward = Theme.Purple,
}

-- text: готовая строка, ключ Locale или L.m(...) — всё переводится на текущий язык
function Toasts.show(msg: any, kind: string?)
	if not container then
		return
	end
	local text = L.renderLocal(msg) or ""
	local color = COLORS[kind or "info"] or Theme.Blue
	local toast = Widgets.New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = color,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Theme.FontBody,
		TextScaled = true,
		TextWrapped = true,
		ZIndex = 60,
		LayoutOrder = nextOrder(),
		Parent = container,
	})
	Widgets.corner(toast, 10)
	Widgets.stroke(toast, Color3.new(0, 0, 0), 2).Transparency = 0.5
	Widgets.New("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		Parent = toast,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10, Parent = toast })
	task.delay(3.2, function()
		if toast.Parent then
			local tw = Widgets.tween(toast, 0.4, { BackgroundTransparency = 1, TextTransparency = 1 })
			tw.Completed:Once(function()
				toast:Destroy()
			end)
		end
	end)
end

-- Крупный баннер события: заголовок + подзаголовок (строки или L.m(...)), цветная рамка, seconds на экране
function Toasts.banner(title: any, sub: any?, color: Color3?, seconds: number?): Frame?
	if not container then
		return nil
	end
	local accent = color or Theme.Gold
	local b = Widgets.New("Frame", {
		Name = "Banner",
		Size = UDim2.new(1, 0, 0, if sub then 56 else 40),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.05,
		ZIndex = 60,
		LayoutOrder = nextOrder(),
		Parent = container,
	})
	Widgets.corner(b, 12)
	local stroke = Widgets.stroke(b, accent, 3)
	local t = Widgets.label({
		Name = "Title",
		Text = L.renderLocal(title) or "",
		Size = UDim2.new(1, -20, 0, 27),
		Position = UDim2.fromOffset(10, 3),
		Font = Theme.Font,
		TextColor3 = accent,
		ZIndex = 61,
		Parent = b,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 10, Parent = t })
	local s: TextLabel? = nil
	if sub then
		s = Widgets.label({
			Name = "Sub",
			Text = L.renderLocal(sub) or "",
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.fromOffset(10, 31),
			TextColor3 = Theme.Text,
			ZIndex = 61,
			Parent = b,
		})
		Widgets.New("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9, Parent = s })
	end
	task.delay(seconds or 4, function()
		if b.Parent then
			local tw = Widgets.tween(b, 0.4, { BackgroundTransparency = 1 })
			Widgets.tween(t, 0.4, { TextTransparency = 1 })
			Widgets.tween(stroke, 0.4, { Transparency = 1 })
			if s then
				Widgets.tween(s, 0.4, { TextTransparency = 1 })
			end
			tw.Completed:Once(function()
				b:Destroy()
			end)
		end
	end)
	return b
end

function Toasts.init(gui: ScreenGui)
	container = Widgets.New("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140), -- ниже панели мира и полосы босса
		Size = UDim2.new(0.5, 0, 0, 260),
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = gui,
	})
	Widgets.New("UISizeConstraint", { MaxSize = Vector2.new(460, 300), Parent = container })
	Widgets.New("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = container,
	})
	Remotes.getEvent("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" or type(text) == "table" then
			Toasts.show(text, if type(kind) == "string" then kind else "info")
		end
	end)
end

return Toasts
