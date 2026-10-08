--!nonstrict
-- Небольшая обёртка для создания интерфейса кодом (никаких внешних ассетов).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local L = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"))
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local Widgets = {}

-- Универсальный конструктор: New("Frame", { Name = "X", Size = ..., Parent = ... }, { children })
-- Текстовое свойство может быть маркером L.k("ключ", args) — тогда оно перерисуется при смене языка.
function Widgets.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			elseif L.isMarker(v) then
				L.bind(inst, k, v)
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

-- v2.5: жирная подпись HUD с толстой чёрной обводкой (как в популярных симуляторах)
function Widgets.bold(props: { [string]: any }): TextLabel
	local strokeSize = props.Stroke or 2.5
	local maxSize = props.MaxTextSize
	local minSize = props.MinTextSize
	local p = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextWrapped = false,
		Text = "",
	}
	for k, v in pairs(props) do
		if k ~= "Stroke" and k ~= "MaxTextSize" and k ~= "MinTextSize" then
			p[k] = v
		end
	end
	local l: TextLabel = New("TextLabel", p)
	New("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = strokeSize,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = l,
	})
	if maxSize or minSize then
		New("UITextSizeConstraint", { MaxTextSize = maxSize or 100, MinTextSize = minSize or 1, Parent = l })
	end
	return l
end

-- v2.5: яркая кнопка HUD: толстая чёрная рамка, иконка (эмодзи) и/или жирная подпись с обводкой.
-- props: Name, Color, Icon, Text (строка или L.k), Size, Position, AnchorPoint, Parent, OnClick, Layout ("row" | "column")
function Widgets.hudButton(props: { [string]: any }): TextButton
	local color: Color3 = props.Color or Theme.Blue
	local btn: TextButton = New("TextButton", {
		Name = props.Name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = props.Size or UDim2.fromOffset(64, 64),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 4,
		Parent = props.Parent,
	})
	Widgets.corner(btn, props.Radius or 12)
	New("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = props.StrokeSize or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = btn,
	})
	-- светлая «глянцевая» полоса сверху — объём без картинок
	local shine = New("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0.36, 0),
		ZIndex = (props.ZIndex or 4) + 1,
		Parent = btn,
	})
	Widgets.corner(shine, 9)
	local z = (props.ZIndex or 4) + 2
	local column = props.Layout == "column"
	if props.Icon then
		New("TextLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Text = props.Icon,
			TextScaled = true,
			Font = Theme.Font,
			TextColor3 = Color3.new(1, 1, 1),
			AnchorPoint = if column then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
			Position = if column then UDim2.fromScale(0.5, 0.08) else UDim2.new(0, 8, 0.5, 0),
			Size = if column then UDim2.fromScale(0.62, 0.62) else UDim2.fromOffset(30, 30),
			ZIndex = z,
			Parent = btn,
		})
	end
	if props.Text then
		local cap = Widgets.bold({
			Name = "Caption",
			Text = props.Text,
			Stroke = props.TextStroke or 2.5,
			MaxTextSize = props.MaxTextSize or 26,
			MinTextSize = props.MinTextSize or 10,
			TextXAlignment = if props.Icon and not column
				then Enum.TextXAlignment.Left
				else Enum.TextXAlignment.Center,
			AnchorPoint = if column then Vector2.new(0.5, 1) else Vector2.new(0, 0.5),
			Position = if column
				then UDim2.new(0.5, 0, 1, -3)
				elseif props.Icon then UDim2.fromScale(0, 0.5)
				else UDim2.new(0, 8, 0.5, 0),
			Size = if column then UDim2.new(1, -4, 0.3, 0) else UDim2.new(1, -16, 0.62, 0),
			ZIndex = z,
			Parent = btn,
		})
		if props.Icon and not column then
			-- подпись справа от квадратной иконки (размеры в «дизайнерских» пикселях: UIScale кластера масштабирует всё сразу)
			local h = (props.Size and props.Size.Y.Offset) or 56
			local sz = math.floor(h * 0.72)
			local icon = btn:FindFirstChild("Icon") :: TextLabel
			icon.Size = UDim2.fromOffset(sz, sz)
			cap.Position = UDim2.new(0, sz + 14, 0.5, 0)
			cap.Size = UDim2.new(1, -(sz + 20), 0.62, 0)
		end
	end
	local scale = New("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		Widgets.tween(scale, 0.1, { Scale = 1.06 })
	end)
	btn.MouseLeave:Connect(function()
		Widgets.tween(scale, 0.1, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		Widgets.tween(scale, 0.06, { Scale = 0.92 })
	end)
	btn.MouseButton1Up:Connect(function()
		Widgets.tween(scale, 0.1, { Scale = 1 })
	end)
	if props.OnClick then
		btn.Activated:Connect(props.OnClick)
	end
	return btn
end

-- Красная точка «!» на кнопке (есть что забрать)
function Widgets.dot(parent: GuiObject): TextLabel
	local d = Widgets.label({
		Name = "Dot",
		Text = "!",
		Font = Theme.Font,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Red,
		TextStrokeTransparency = 0.2,
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -3, 0, 3),
		Visible = false,
		ZIndex = 9,
		Parent = parent,
	})
	Widgets.corner(d, 11)
	New("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = d,
	})
	return d
end

function Widgets.setEnabled(btn: TextButton, enabled: boolean, color: Color3?)
	btn.Active = enabled
	btn.BackgroundColor3 = if enabled then (color or Theme.Green) else Theme.Disabled
end

-- Модальная панель с заголовком и крестиком. Возвращает { Root, Body, Open, Close, IsOpen }.
-- title — английское имя панели (Name = title .. "Panel"); заголовок берётся из ключа "panel.<title без пробелов>".
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
	-- телефон (v2.4): панель почти во всю ширину; вертикально — чуть выше центра, снизу место для тостов
	Layout.onChanged(function(lay)
		if lay.Mode == "portrait" then
			root.Size = UDim2.new(1, -16, 0.68, 0)
			root.Position = UDim2.fromScale(0.5, 0.46)
		elseif lay.Mode == "landscape" and lay.Touch then
			-- справа — кнопка прыжка: панель сдвинута влево, чтобы не перекрывать её кнопки
			root.Size = UDim2.new(1, -140, 1, -24)
			root.Position = UDim2.new(0.5, -55, 0.5, 0)
		elseif lay.Mode == "landscape" then
			root.Size = UDim2.new(0.84, 0, 1, -24)
			root.Position = UDim2.fromScale(0.5, 0.5)
		else
			root.Size = UDim2.fromScale(0.62, 0.72)
			root.Position = UDim2.fromScale(0.5, 0.5)
		end
	end)

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
		Text = L.k("panel." .. string.gsub(title, " ", "")),
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
