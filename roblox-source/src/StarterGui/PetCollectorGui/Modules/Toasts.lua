--!nonstrict
-- Всплывающие уведомления сверху экрана.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Toasts = {}

local container: Frame

local COLORS = {
	info = Theme.Blue,
	success = Theme.Green,
	error = Theme.Red,
	reward = Theme.Purple,
}

function Toasts.show(text: string, kind: string?)
	if not container then
		return
	end
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

function Toasts.init(gui: ScreenGui)
	container = Widgets.New("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(0.5, 0, 0, 200),
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
		if type(text) == "string" then
			Toasts.show(text, if type(kind) == "string" then kind else "info")
		end
	end)
end

return Toasts
