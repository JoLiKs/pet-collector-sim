--!nonstrict
-- Небольшая обёртка для создания интерфейса кодом (никаких внешних ассетов).
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Widgets = {}

-- Универсальный конструктор: New("Frame", { Name = "X", Size = ..., Parent = ... }, { children })
function Widgets.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
local New = Widgets.New

function Widgets.corner(parent: Instance, radius: number?): UICorner
	return New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Widgets.stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	return New("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Widgets.padding(parent: Instance, px: number)
	return New("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function Widgets.label(props: { [string]: any }): TextLabel
	local p = {
		BackgroundTransparency = 1,
		Font = Theme.FontBody,
		TextColor3 = Theme.Text,
		TextScaled = true,
		TextWrapped = true,
		Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return New("TextLabel", p)
end

function Widgets.tween(inst: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Кнопка со скруглением, обводкой и анимацией нажатия
function Widgets.button(props: { [string]: any }): TextButton
	local onClick = props.OnClick
	local maxTextSize: number = props.MaxTextSize or 28
	local baseColor: Color3 = props.Color or Theme.Blue
	local p = {
		BackgroundColor3 = baseColor,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextScaled = true,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(120, 40),
	}
	for k, v in pairs(props) do
		if k ~= "OnClick" and k ~= "Color" and k ~= "MaxTextSize" then
			p[k] = v
		end
	end
	local btn: TextButton = New("TextButton", p)
	Widgets.corner(btn, 10)
	Widgets.stroke(btn, Color3.new(0, 0, 0), 2).Transparency = 0.6
	New("UITextSizeConstraint", { MaxTextSize = maxTextSize, MinTextSize = 8, Parent = btn })
	local scale = New("UIScale", { Parent = btn })

	btn.MouseEnter:Connect(function()
		Widgets.tween(scale, 0.1, { Scale = 1.05 })
	end)
	btn.MouseLeave:Connect(function()
		Widgets.tween(scale, 0.1, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		Widgets.tween(scale, 0.06, { Scale = 0.94 })
	end)
	btn.MouseButton1Up:Connect(function()
		Widgets.tween(scale, 0.1, { Scale = 1.05 })
	end)
	if onClick then
		btn.Activated:Connect(onClick)
	end
	return btn
end

function Widgets.setEnabled(btn: TextButton, enabled: boolean, color: Color3?)
	btn.Active = enabled
	btn.BackgroundColor3 = if enabled then (color or Theme.Green) else Theme.Disabled
end

-- Модальная панель с заголовком и крестиком. Возвращает { Root, Body, Open, Close, IsOpen }.
function Widgets.panel(gui: ScreenGui, title: string, onClose: (() -> ())?)
	local root = New("Frame", {
		Name = title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.72),
		BackgroundColor3 = Theme.Bg,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	Widgets.corner(root, 16)
	Widgets.stroke(root, Theme.BgLight, 3)
	New(
		"UISizeConstraint",
		{ MaxSize = Vector2.new(760, 540), MinSize = Vector2.new(300, 240), Parent = root }
	)
	local scale = New("UIScale", { Parent = root })

	local header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 21,
		Parent = root,
	})
	Widgets.corner(header, 16)
	Widgets.label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -120, 1, -14),
		Position = UDim2.fromOffset(16, 7),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font,
		ZIndex = 22,
		Parent = header,
	})

	local api = { Root = root }
	local function close()
		root.Visible = false
		if onClose then
			onClose()
		end
	end
	local closeBtn = Widgets.button({
		Text = "X",
		Color = Theme.Red,
		Size = UDim2.fromOffset(40, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		ZIndex = 22,
		OnClick = close,
		Parent = header,
	})
	closeBtn.Name = "Close"

	local body = New("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = root,
	})
	api.Body = body
	api.Header = header

	function api.Open()
		root.Visible = true
		scale.Scale = 0.85
		Widgets.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	api.Close = close
	function api.IsOpen(): boolean
		return root.Visible
	end
	return api
end

function Widgets.scroller(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local p = {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = parent,
	}
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	return New("ScrollingFrame", p)
end

function Widgets.clear(container: Instance, keep: { string }?)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			local skip = false
			if keep then
				for _, name in ipairs(keep) do
					if child.Name == name then
						skip = true
					end
				end
			end
			if not skip then
				child:Destroy()
			end
		end
	end
end

return Widgets
