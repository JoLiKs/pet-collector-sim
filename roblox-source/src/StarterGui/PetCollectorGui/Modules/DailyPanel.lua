--!nonstrict
--[[
	DailyPanel (v2.8) — окно ежедневной награды за вход: 7 ярких карточек (цикл из Shared/DailyData).
	  * Открывается само при входе раз в сутки, пока сегодняшняя награда не получена (core.Daily.AutoOpen);
	    после показа клиент шлёт DailySeen — до следующих UTC-суток окно само не всплывает.
	    Ждёт, пока уйдёт экран загрузки; плашка обучения скрыта, пока окно открыто или ждёт показа.
	  * Вручную — станция «Сундук наград» в хабе и пункт «Ещё → Награды дня» (новых кнопок на HUD нет).
	  * Сегодняшняя карточка пульсирует и светится («ЗАБРАТЬ!»), полученные — затемнены с галочкой,
	    день 7 — тайный сундук (силуэт питомца и «???»). Кнопка: «ЗАБРАТЬ» или «Следующая через ЧЧ:ММ».
	  * Белый — только у текста: фон окна — тёмный фиолетово-синий градиент, обводки цветные и тёмные.
	  * Выдача — только на сервере (ClaimDaily); клиент рисует полёт иконки в кошелёк/инвентарь.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Icons = require(Shared:WaitForChild("Icons"))
local DailyData = require(Shared:WaitForChild("DailyData"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local New = Widgets.New
local c3 = Color3.fromRGB

local DailyPanel = {}

-- Палитры карточек: { верх, низ, тёмная обводка, светлый тон для бликов/лучей }
DailyPanel.PALETTE = {
	Yellow = { c3(255, 228, 72), c3(244, 168, 18), c3(140, 82, 0), c3(255, 238, 120) },
	Orange = { c3(255, 172, 62), c3(236, 102, 22), c3(132, 48, 0), c3(255, 196, 110) },
	Red = { c3(255, 98, 92), c3(206, 36, 52), c3(112, 12, 26), c3(255, 150, 140) },
	Indigo = { c3(118, 112, 255), c3(68, 46, 208), c3(30, 16, 112), c3(162, 152, 255) },
	Pink = { c3(248, 142, 240), c3(196, 74, 218), c3(104, 24, 124), c3(255, 170, 246) },
	Lime = { c3(178, 238, 72), c3(96, 186, 30), c3(40, 100, 8), c3(212, 255, 130) },
	Rainbow = { c3(255, 120, 120), c3(140, 90, 255), c3(58, 18, 92), c3(255, 220, 120) },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, c3(255, 82, 82)),
	ColorSequenceKeypoint.new(0.2, c3(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, c3(250, 230, 60)),
	ColorSequenceKeypoint.new(0.6, c3(70, 220, 110)),
	ColorSequenceKeypoint.new(0.8, c3(60, 150, 255)),
	ColorSequenceKeypoint.new(1, c3(190, 80, 255)),
})

local WIN_TOP = c3(78, 48, 170)
local WIN_BOTTOM = c3(28, 24, 88)
local WIN_STROKE = c3(16, 10, 50)

-- Жирный текст с тёмной цветной обводкой
local function bold(props: { [string]: any }, strokeColor: Color3, thickness: number?): TextLabel
	local l = Widgets.bold(props)
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = strokeColor
		st.Thickness = thickness or 2.5
	end
	return l
end

local function gradient(parent: Instance, a: Color3, b: Color3, rotation: number?): UIGradient
	return New("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90, Parent = parent })
end

-- Формат «ЧЧ:ММ» для таймера следующей награды
function DailyPanel.formatHM(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", s // 3600, (s % 3600) // 60)
end

-- Текст суммы на карточке
function DailyPanel.amountText(r: { [string]: any }): string
	if r.Kind == "Chest" then
		return "???"
	end
	return "+" .. Util.formatNumber(r.Amount or 0)
end

function DailyPanel.init(gui: ScreenGui)
	local api: { [string]: any } = {}
	local opener: (() -> ())? = nil

	-- затемнение мира под окном (не белое)
	local backdrop = New("Frame", {
		Name = "DailyBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = c3(8, 6, 24),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 38,
		Parent = gui,
	})

	local root = New("Frame", {
		Name = "DailyPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 400),
		BackgroundColor3 = WIN_TOP,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	})
	Widgets.corner(root, 24)
	gradient(root, WIN_TOP, WIN_BOTTOM)
	New("UIStroke", { Color = WIN_STROKE, Thickness = 5, Parent = root })
	local scale = New("UIScale", { Parent = root })
	-- внутренняя декоративная рамка (фиолетовая, не белая)
	local inner = New("Frame", {
		Name = "Inner",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = root,
	})
	Widgets.corner(inner, 19)
	New("UIStroke", { Color = c3(132, 98, 240), Thickness = 2, Transparency = 0.35, Parent = inner })
	-- звёздочки на фоне
	local stars = {}
	for i = 1, 9 do
		local st = New("Frame", {
			Name = "Star" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			Rotation = 45,
			BackgroundColor3 = c3(180, 150, 255),
			BackgroundTransparency = 0.6,
			ZIndex = 41,
			Parent = root,
		})
		Widgets.corner(st, 2)
		stars[i] = st
	end

	-- шапка: календарь «31», заголовок, метка VIP, крестик
	local header = New("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		ZIndex = 42,
		Parent = root,
	})
	local cal = New("Frame", {
		Name = "Calendar",
		BackgroundColor3 = c3(255, 236, 190),
		ZIndex = 43,
		Parent = header,
	})
	Widgets.corner(cal, 8)
	New("UIStroke", { Color = c3(60, 20, 40), Thickness = 3, Parent = cal })
	gradient(cal, c3(255, 228, 170), c3(236, 186, 120))
	local calTop = New("Frame", {
		Name = "Top",
		Size = UDim2.fromScale(1, 0.34),
		BackgroundColor3 = c3(235, 60, 80),
		ZIndex = 44,
		Parent = cal,
	})
	Widgets.corner(calTop, 8)
	gradient(calTop, c3(255, 95, 110), c3(205, 35, 60))
	for i, x in ipairs({ 0.3, 0.7 }) do
		local ringf = New("Frame", {
			Name = "Ring" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.02),
			Size = UDim2.fromScale(0.12, 0.26),
			BackgroundColor3 = c3(60, 30, 50),
			ZIndex = 45,
			Parent = cal,
		})
		Widgets.corner(ringf, 4)
	end
	local calNum = New("TextLabel", {
		Name = "Num",
		Text = "31",
		Font = Enum.Font.FredokaOne,
		TextColor3 = c3(60, 30, 50),
		TextScaled = true,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.08, 0.36),
		Size = UDim2.fromScale(0.84, 0.6),
		ZIndex = 45,
		Parent = cal,
	})
	local _ = calNum
	local title = bold({
		Name = "Title",
		Text = L.k("daily.title"),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 43,
		Parent = header,
	}, c3(30, 14, 70), 3)
	local vipChip =
		New("Frame", { Name = "VipChip", BackgroundColor3 = c3(255, 200, 60), ZIndex = 43, Parent = header })
	Widgets.corner(vipChip, 12)
	local vipGrad = gradient(vipChip, c3(255, 226, 90), c3(232, 150, 20))
	local vipStroke = New("UIStroke", { Color = c3(120, 60, 0), Thickness = 2.5, Parent = vipChip })
	local vipText = bold({
		Name = "Text",
		Text = L.k("daily.vip"),
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		ZIndex = 44,
		Parent = vipChip,
	}, c3(100, 45, 0), 2)

	local function close()
		root.Visible = false
		backdrop.Visible = false
		ClientState.setFlag("DailyOpen", false)
	end
	local closeBtn = New("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -8,
		BackgroundColor3 = c3(235, 60, 75),
		ZIndex = 46,
		Parent = root,
	})
	Widgets.corner(closeBtn, 12)
	gradient(closeBtn, c3(255, 100, 110), c3(200, 30, 55))
	New("UIStroke", {
		Color = c3(100, 10, 25),
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = closeBtn,
	})
	bold({
		Name = "X",
		Text = "X",
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.1, 0.08),
		ZIndex = 47,
		Parent = closeBtn,
	}, c3(100, 10, 25), 3)
	closeBtn.Activated:Connect(close)

	-- карточки
	local cardsBox = New("Frame", { Name = "Cards", BackgroundTransparency = 1, ZIndex = 42, Parent = root })
	local cards = {}
	for day = 1, DailyData.CYCLE do
		local def = DailyData.Rewards[day]
		local pal = DailyPanel.PALETTE[def.Color] or DailyPanel.PALETTE.Yellow
		local glow = New("Frame", {
			Name = "Glow" .. day,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = c3(255, 214, 70),
			BackgroundTransparency = 1,
			ZIndex = 42,
			Parent = cardsBox,
		})
		Widgets.corner(glow, 20)
		local card = New("TextButton", {
			Name = "Day" .. day,
			Text = "",
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = pal[1],
			ZIndex = 43,
			Parent = cardsBox,
		})
		Widgets.corner(card, 14)
		if def.Color == "Rainbow" then
			New("UIGradient", { Color = RAINBOW, Rotation = 35, Parent = card })
		else
			gradient(card, pal[1], pal[2])
		end
		local stroke = New(
			"UIStroke",
			{ Color = pal[3], Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card }
		)
		local cscale = New("UIScale", { Parent = card })
		-- блик сверху (светлый тон карточки, не белый)
		local gloss = New("Frame", {
			Name = "Gloss",
			Position = UDim2.new(0.08, 0, 0, 5),
			Size = UDim2.fromScale(0.84, 0.1),
			BackgroundColor3 = pal[4],
			BackgroundTransparency = 0.55,
			ZIndex = 44,
			Parent = card,
		})
		Widgets.corner(gloss, 8)
		-- лучи и сияние за иконкой
		local rays = New("Frame", {
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 44,
			Parent = card,
		})
		local rayBars = {}
		for i = 0, 5 do
			local bar = New("Frame", {
				Name = "Ray" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.16, 1),
				Rotation = i * 30,
				BackgroundColor3 = pal[4],
				BackgroundTransparency = 0.78,
				ZIndex = 44,
				Parent = rays,
			})
			Widgets.corner(bar, 10)
			rayBars[i + 1] = bar
		end
		local halo = New("Frame", {
			Name = "Halo",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = pal[4],
			BackgroundTransparency = 0.6,
			ZIndex = 45,
			Parent = card,
		})
		Widgets.corner(halo, 100)
		local top = bold(
			{ Name = "Top", Text = L.k("daily.day", { n = day }), ZIndex = 47, Parent = card },
			pal[3],
			2.5
		)
		local amount = bold({ Name = "Amount", Text = "", ZIndex = 47, Parent = card }, pal[3], 3)
		local vipTag = New("Frame", {
			Name = "VipTag",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 12,
			BackgroundColor3 = c3(255, 210, 60),
			Visible = false,
			ZIndex = 49,
			Parent = card,
		})
		Widgets.corner(vipTag, 8)
		gradient(vipTag, c3(255, 232, 100), c3(235, 150, 20))
		New("UIStroke", { Color = c3(110, 50, 0), Thickness = 2, Parent = vipTag })
		bold({
			Name = "Text",
			Text = L.k("daily.vip"),
			Size = UDim2.new(1, -6, 1, -4),
			Position = UDim2.fromOffset(3, 2),
			ZIndex = 50,
			Parent = vipTag,
		}, c3(110, 50, 0), 1.5)
		local done = New("Frame", {
			Name = "Done",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = c3(18, 12, 40),
			BackgroundTransparency = 0.42,
			Visible = false,
			ZIndex = 51,
			Parent = card,
		})
		Widgets.corner(done, 14)
		local doneScale = New("UIScale", { Parent = done })
		cards[day] = {
			Card = card,
			Glow = glow,
			Stroke = stroke,
			Scale = cscale,
			Gloss = gloss,
			Rays = rays,
			RayBars = rayBars,
			Halo = halo,
			Top = top,
			Amount = amount,
			VipTag = vipTag,
			Done = done,
			DoneScale = doneScale,
			Palette = pal,
			Icon = nil,
			IconKind = nil,
			Check = nil,
		}
		card.Activated:Connect(function()
			local core = ClientState.Core
			if core and core.Daily and core.Daily.CanClaim and core.Daily.Day == day then
				api.Claim()
			end
		end)
	end

	local hint = Widgets.label({
		Name = "Hint",
		Text = L.k("daily.hint"),
		TextColor3 = c3(200, 186, 255),
		Font = Enum.Font.GothamBold,
		ZIndex = 42,
		Parent = root,
	})
	local hintSize = New("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8, Parent = hint })

	-- кнопка «ЗАБРАТЬ» / таймер
	local claimBtn = New("TextButton", {
		Name = "Claim",
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = c3(80, 205, 90),
		ZIndex = 43,
		Parent = root,
	})
	Widgets.corner(claimBtn, 16)
	local claimGrad = gradient(claimBtn, c3(120, 232, 96), c3(36, 166, 62))
	local claimStroke = New("UIStroke", {
		Color = c3(16, 86, 30),
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = claimBtn,
	})
	local claimGloss = New("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0.05, 0, 0, 4),
		Size = UDim2.fromScale(0.9, 0.28),
		BackgroundColor3 = c3(190, 255, 170),
		BackgroundTransparency = 0.6,
		ZIndex = 44,
		Parent = claimBtn,
	})
	Widgets.corner(claimGloss, 10)
	local gift = Icons.make("Gift", { Name = "Gift", Px = 40, ZIndex = 45, Parent = claimBtn })
	local claimText =
		bold({ Name = "Text", Text = L.k("daily.claim"), ZIndex = 46, Parent = claimBtn }, c3(16, 86, 30), 3)

	-- белый в окне — только у текста: белые блики иконок (общих с игрой) подкрашиваем в тёплый кремовый
	local function warmWhites(inst: Instance)
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("Frame") and d.BackgroundTransparency < 1 then
				local col = d.BackgroundColor3
				if math.min(col.R, col.G, col.B) >= 0.9 then
					d.BackgroundColor3 = c3(255, 234, 150)
				end
			elseif d:IsA("UIGradient") then
				local kps = {}
				for _, kp in ipairs(d.Color.Keypoints) do
					local v = kp.Value
					table.insert(
						kps,
						ColorSequenceKeypoint.new(
							kp.Time,
							if math.min(v.R, v.G, v.B) >= 0.9 then c3(255, 234, 150) else v
						)
					)
				end
				d.Color = ColorSequence.new(kps)
			end
		end
	end
	DailyPanel.warmWhites = warmWhites

	local function setIcon(c, kind: string, px: number)
		if c.IconKind == kind and c.Icon and c.IconPx == px then
			return
		end
		if c.Icon then
			c.Icon:Destroy()
		end
		c.Icon = Icons.make(kind, {
			Name = "Icon",
			Px = px,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 46,
			Parent = c.Card,
		})
		warmWhites(c.Icon)
		c.IconKind, c.IconPx = kind, px
		if kind == "Mystery" then
			bold({
				Name = "Q",
				Text = "?",
				Size = UDim2.fromScale(0.5, 0.5),
				Position = UDim2.fromScale(0.25, 0.3),
				TextColor3 = c3(255, 226, 90),
				ZIndex = 60,
				Parent = c.Icon,
			}, c3(40, 10, 70), 2)
		end
	end

	-- раскладка под экран: в один ряд (ПК и телефон горизонтально) или 4+3 (телефон вертикально)
	local cur = { W = 1280, H = 720, Mode = "wide", CardW = 110, CardH = 160, K = Theme.UI_SCALE }
	local function layout(li)
		-- v3.0: окно в Theme.uiScale раз меньше; раскладка считается в «виртуальных» пикселях W/k × H/k
		local k = Theme.uiScale(li)
		local W, H = li.W / k, li.H / k
		local portrait = li.Mode == "portrait"
		local pad, gap = 14, 8
		local headerH = if li.Mode == "landscape" then 50 else 62
		local winW, cols, rows
		-- v3.1: окно меньше (Theme.PANEL_SHRINK): ПК — в 1.5 раза по ширине, телефон — мягче (текст читается)
		if portrait then
			winW = math.min(W - 16, 520) * 0.86
			cols, rows = 4, 2
		elseif li.Mode == "landscape" then
			winW = math.min(W - 24, 960) / 1.3
			cols, rows = 7, 1
		else
			winW = math.min(W - 80, 940) / Theme.PANEL_SHRINK
			cols, rows = 7, 1
		end
		winW = math.floor(winW)
		local cardW = math.floor((winW - 2 * pad - (cols - 1) * gap) / cols)
		local cardH = math.floor(cardW * (if portrait then 1.62 else 1.48))
		local btnH = if li.Mode == "landscape" then 44 else 54
		local hintH = if portrait then 30 else 18
		local fixed = headerH + 10 + hintH + 8 + btnH + 16
		local maxCardsH = H - 24 - fixed
		local cardsH = rows * cardH + (rows - 1) * (gap + 6)
		if cardsH > maxCardsH then
			cardH = math.floor((maxCardsH - (rows - 1) * (gap + 6)) / rows)
			cardsH = rows * cardH + (rows - 1) * (gap + 6)
		end
		local winH = fixed + cardsH
		root.Size = UDim2.fromOffset(winW, winH)
		root.Position = UDim2.fromScale(0.5, 0.5)
		header.Position = UDim2.fromOffset(pad, 8)
		header.Size = UDim2.new(1, -2 * pad - 40, 0, headerH - 8)
		local calS = headerH - 14
		cal.Size = UDim2.fromOffset(calS, calS)
		cal.Position = UDim2.fromOffset(0, 3)
		-- метка «VIP x2» прижата вправо (перед крестиком), заголовок занимает остаток и не налезает на неё
		local headerW = winW - 2 * pad - 40
		local chipW = if portrait then 78 else 96
		local chipH = math.min(30, headerH - 22)
		vipChip.Size = UDim2.fromOffset(chipW, chipH)
		vipChip.Position = UDim2.new(1, -chipW - 8, 0.5, -chipH / 2)
		title.Position = UDim2.fromOffset(calS + 10, 4)
		title.Size = UDim2.new(0, math.min(300, headerW - calS - 10 - chipW - 18), 1, -8)
		local cbS = if li.Mode == "landscape" then 40 else 48
		closeBtn.Size = UDim2.fromOffset(cbS, cbS)
		-- на узком экране крестик не выходит за край (с учётом поворота)
		local out = math.min(6, (W - winW) / 2 - 6)
		closeBtn.Position = UDim2.new(1, -cbS / 2 + out, 0, cbS / 2 - 6)
		cardsBox.Position = UDim2.fromOffset(pad, headerH + 4)
		cardsBox.Size = UDim2.new(1, -2 * pad, 0, cardsH)
		for day, c in ipairs(cards) do
			local col, row, rowCount
			if portrait then
				row = if day <= 4 then 0 else 1
				col = if day <= 4 then day - 1 else day - 5
				rowCount = if day <= 4 then 4 else 3
			else
				row, col, rowCount = 0, day - 1, 7
			end
			local rowW = rowCount * cardW + (rowCount - 1) * gap
			local x0 = ((winW - 2 * pad) - rowW) / 2
			local cx = x0 + col * (cardW + gap) + cardW / 2
			local cy = row * (cardH + gap + 6) + cardH / 2
			c.Card.Position = UDim2.fromOffset(cx, cy)
			c.Card.Size = UDim2.fromOffset(cardW, cardH)
			c.Glow.Position = UDim2.fromOffset(cx, cy)
			c.Glow.Size = UDim2.fromOffset(cardW + 14, cardH + 14)
			local iconPx = math.floor(math.min(cardW * 0.66, cardH * 0.44))
			c.Rays.Size = UDim2.fromOffset(cardW * 0.94, cardW * 0.94)
			c.Rays.Position = UDim2.fromScale(0.5, 0.5)
			c.Halo.Size = UDim2.fromOffset(iconPx * 1.05, iconPx * 1.05)
			local topH = math.max(14, math.floor(cardH * 0.15))
			c.Top.Position = UDim2.fromOffset(4, math.floor(cardH * 0.05))
			c.Top.Size = UDim2.new(1, -8, 0, topH)
			local amtH = math.max(16, math.floor(cardH * 0.19))
			c.Amount.Position = UDim2.new(0, 4, 1, -amtH - math.floor(cardH * 0.05))
			c.Amount.Size = UDim2.new(1, -8, 0, amtH)
			c.VipTag.Size = UDim2.fromOffset(math.max(34, cardW * 0.46), math.max(16, cardH * 0.12))
			c.VipTag.Position = UDim2.new(1, -cardW * 0.14, 0, cardH * 0.2)
			c.IconPxWanted = iconPx
			if c.Icon then
				setIcon(c, c.IconKind, iconPx)
			end
			if c.Check then
				c.Check.Size = UDim2.fromOffset(iconPx * 0.6, iconPx * 0.6)
			end
		end
		hint.Position = UDim2.fromOffset(pad, headerH + 4 + cardsH + 6)
		hint.Size = UDim2.new(1, -2 * pad, 0, hintH)
		hintSize.MaxTextSize = if portrait then 12 else 15
		local bw = math.min(winW - 2 * pad, if portrait then 300 else 340)
		claimBtn.Size = UDim2.fromOffset(bw, btnH)
		claimBtn.Position = UDim2.new(0.5, 0, 1, -12)
		gift.Size = UDim2.fromOffset(btnH - 14, btnH - 14)
		gift.Position = UDim2.fromOffset(12, 7)
		claimText.Position = UDim2.fromOffset(btnH, 8)
		claimText.Size = UDim2.new(1, -btnH - 12, 1, -16)
		-- звёзды по краям
		local spots = {
			{ 0.03, 0.9 },
			{ 0.97, 0.88 },
			{ 0.6, 0.06 },
			{ 0.82, 0.07 },
			{ 0.15, 0.95 },
			{ 0.88, 0.96 },
			{ 0.42, 0.97 },
			{ 0.5, 0.05 },
			{ 0.72, 0.95 },
		}
		for i, st in ipairs(stars) do
			local sp = spots[i]
			st.Position = UDim2.fromScale(sp[1], sp[2])
		end
		cur.W, cur.H, cur.Mode, cur.CardW, cur.CardH, cur.K = li.W, li.H, li.Mode, cardW, cardH, k
		if not root.Visible then
			scale.Scale = k
		end
	end
	Layout.onChanged(layout)

	local lastClaimed = -1
	local function refresh()
		local core = ClientState.Core
		local d = core and core.Daily
		if not d or not d.Rewards then
			return
		end
		local vip = d.Vip == true
		vipText.Text = L.t("daily.vip")
		vipGrad.Color = if vip
			then ColorSequence.new(c3(255, 226, 90), c3(232, 150, 20))
			else ColorSequence.new(c3(96, 72, 170), c3(62, 44, 130))
		vipStroke.Color = if vip then c3(120, 60, 0) else c3(26, 16, 70)
		for day, c in ipairs(cards) do
			local r = d.Rewards[day]
			local claimed = day <= d.Claimed
			local isToday = d.CanClaim and day == d.Day
			setIcon(c, r.Icon, c.IconPxWanted or 60)
			c.Amount.Text = DailyPanel.amountText(r)
			if isToday then
				c.Top.Text = L.t("daily.card_claim")
			else
				c.Top.Text = L.t("daily.day", { n = day })
			end
			c.VipTag.Visible = vip and not claimed or (vip and r.Kind == "Chest" and not claimed)
			c.Done.Visible = claimed
			if claimed and not c.Check then
				c.Check = Icons.make("Check", {
					Name = "Check",
					Px = 40,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset((c.IconPxWanted or 60) * 0.6, (c.IconPxWanted or 60) * 0.6),
					ZIndex = 52,
					Parent = c.Done,
				})
			end
			c.Today = isToday
			for _, bar in ipairs(c.RayBars) do
				bar.BackgroundTransparency = if isToday then 0.55 else 0.8
			end
			c.Halo.BackgroundTransparency = if isToday then 0.45 else 0.65
			c.Stroke.Color = if isToday then c3(255, 200, 40) else c.Palette[3]
			c.Stroke.Thickness = if isToday then 5 else 4
			if not isToday then
				c.Glow.BackgroundTransparency = 1
				c.Scale.Scale = 1
			end
		end
		-- «поп» галочки у только что полученной карточки
		if lastClaimed >= 0 and d.Claimed > lastClaimed then
			local c = cards[d.Claimed]
			if c then
				c.DoneScale.Scale = 1.5
				Widgets.tween(c.DoneScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		lastClaimed = d.Claimed
		if d.CanClaim then
			claimText.Text = L.t("daily.claim")
			claimGrad.Color = ColorSequence.new(c3(120, 232, 96), c3(36, 166, 62))
			claimStroke.Color = c3(16, 86, 30)
			claimGloss.BackgroundColor3 = c3(190, 255, 170)
			gift.Visible = true
			claimBtn.AutoButtonColor = true
			local st = claimText:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = c3(16, 86, 30)
			end
		else
			local left = (d.SecondsLeft or 0) - (os.clock() - ClientState.ReceivedClock)
			claimText.Text = L.t("daily.next_in", { time = DailyPanel.formatHM(left) })
			claimGrad.Color = ColorSequence.new(c3(110, 92, 190), c3(66, 50, 140))
			claimStroke.Color = c3(28, 18, 76)
			claimGloss.BackgroundColor3 = c3(170, 150, 240)
			gift.Visible = true
			claimBtn.AutoButtonColor = false
			local st = claimText:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = c3(28, 18, 76)
			end
		end
	end
	ClientState.onCore(refresh)
	L.onChanged(refresh)

	-- полёт иконок награды в кошелёк / инвентарь / к питомцам
	local function targetFor(kind: string): GuiObject?
		local name
		if kind == "Coin" then
			name = "Coins"
		elseif kind == "Gem" then
			name = "Gems"
		end
		if name then
			local currency = gui:FindFirstChild("Currency", true)
			local t = currency and currency:FindFirstChild(name, true)
			if t and t:IsA("GuiObject") then
				return t
			end
		end
		local btn = gui:FindFirstChild(if kind == "Mystery" then "PetsBtn" else "InventoryBtn", true)
		if btn and btn:IsA("GuiObject") then
			return btn
		end
		return nil
	end
	local function flyReward(c)
		if not c or not c.Icon then
			return
		end
		local kind = c.IconKind
		local target = targetFor(kind)
		local from = c.Icon.AbsolutePosition - gui.AbsolutePosition
		local size = c.Icon.AbsoluteSize
		local to = if target
			then target.AbsolutePosition - gui.AbsolutePosition + target.AbsoluteSize * 0.5
			else Vector2.new(cur.W * 0.1, cur.H * 0.9)
		local n = if kind == "Coin" or kind == "Gem" then 5 else 1
		for i = 1, n do
			task.delay((i - 1) * 0.08, function()
				local fly = Icons.make(if kind == "Mystery" then "Gift" else kind, {
					Name = "DailyFly",
					Px = math.max(24, size.X),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(
						from.X + size.X / 2 + (i - 1) * 6 - (n - 1) * 3,
						from.Y + size.Y / 2
					),
					Size = UDim2.fromOffset(size.X, size.Y),
					ZIndex = 70,
					Parent = gui,
				})
				warmWhites(fly)
				Widgets.tween(fly, 0.65, {
					Position = UDim2.fromOffset(to.X, to.Y),
					Size = UDim2.fromOffset(size.X * 0.35, size.Y * 0.35),
				}, Enum.EasingStyle.Quad)
				task.delay(0.7, function()
					fly:Destroy()
					if target and i == n then
						local sc = target:FindFirstChild("DailyBump")
						if not sc then
							sc = New("UIScale", { Name = "DailyBump", Parent = target })
						end
						sc.Scale = 1.25
						Widgets.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
					end
				end)
			end)
		end
	end

	local busy = false
	function api.Claim()
		local core = ClientState.Core
		if busy or not (core and core.Daily and core.Daily.CanClaim) then
			return
		end
		busy = true
		local c = cards[core.Daily.Day]
		if Actions.call("ClaimDaily") then
			flyReward(c)
		end
		busy = false
	end
	claimBtn.Activated:Connect(api.Claim)

	-- анимации: пульсация и свечение сегодняшней карточки, вращение лучей, таймер
	local t = 0
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not root.Visible then
			return
		end
		t += dt
		for _, c in ipairs(cards) do
			if c.Today then
				local k = 0.5 + 0.5 * math.sin(t * 4)
				c.Scale.Scale = 1 + 0.045 * k
				c.Glow.BackgroundTransparency = 0.25 + 0.45 * (1 - k)
				c.Rays.Rotation = (t * 40) % 360
			end
		end
		acc += dt
		if acc >= 1 then
			acc = 0
			local core = ClientState.Core
			if core and core.Daily and not core.Daily.CanClaim then
				refresh()
			end
		end
	end)

	function api.Open()
		layout(Layout.get())
		refresh()
		backdrop.Visible = true
		root.Visible = true
		scale.Scale = 0.8 * cur.K
		Widgets.tween(scale, 0.22, { Scale = cur.K }, Enum.EasingStyle.Back)
		ClientState.setFlag("DailyOpen", true)
	end
	api.Close = close
	function api.IsOpen(): boolean
		return root.Visible
	end
	api.Root = root
	function api.SetOpener(fn: () -> ())
		opener = fn
	end

	-- автопоказ при входе: раз в сутки, после экрана загрузки (DailySeen фиксирует показ на сервере)
	local autoDone = false
	ClientState.onCore(function(core)
		if autoDone or not (core and core.Daily and core.Daily.AutoOpen) then
			return
		end
		autoDone = true
		ClientState.setFlag("DailyPending", true)
		task.spawn(function()
			local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			local t0 = os.clock()
			while pg and pg:FindFirstChild("LoadingScreen") and os.clock() - t0 < 25 do
				task.wait(0.2)
			end
			task.wait(0.6)
			if opener then
				opener()
			else
				api.Open()
			end
			ClientState.setFlag("DailyPending", false)
			Actions.call("DailySeen")
		end)
	end)

	return api
end

return DailyPanel
