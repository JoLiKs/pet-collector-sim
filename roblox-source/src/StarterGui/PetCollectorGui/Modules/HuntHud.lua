--!nonstrict
--[[
	HuntHud — интерфейс события «Суперсила / Охота» (только отображение; всё решает сервер).
	  * карточка "HuntCard" первой в списке событий справа: задание «Останови X!» / «Продержись»,
	    полоса HP суперигрока, таймер, твой урон и порог награды, дистанция, оглушение;
	    вне раунда за 15 с до выбора — «Суперсила через 0:08»;
	  * экранный указатель-стрелка к цели (на краю эллипса вокруг центра или над целью, если она в кадре);
	  * 3D-стрелка-компас на земле перед своим персонажем, повернутая к цели;
	  * баннеры начала/итога в общем стеке Toasts.
	Состояние приходит персонально событием Remotes "Superpower" (раз в 0.5 с во время охоты).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.Layout)
local Toasts = require(script.Parent.Toasts)
local UiKit = require(script.Parent.UiKit)
local Widgets = require(script.Parent.Widgets)

local HuntHud = {}

local CARD_H = 100
local IDLE_H = 42
local SHOW_NEXT = 15
local ARROW_COLOR = Color3.fromRGB(255, 196, 40)

local st: any = nil
local gotAt = 0
local lastStartBanner = 0
local lastOutcomeBanner = 0
local roundWasYou: { [number]: boolean } = {}

local function displayName(s: any): string
	local n = tostring(s.Target or "?")
	return if s.TargetIsBot then L.t("bot.tag", { player = n }) else n
end

local function leftNow(): number
	if not st or not st.Left then
		return 0
	end
	return math.max(0, st.Left - (os.clock() - gotAt))
end

local function myRoot(): BasePart?
	local c = Players.LocalPlayer.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function targetRoot(): BasePart?
	local m = st and st.Model
	if typeof(m) ~= "Instance" or not m.Parent then
		return nil
	end
	local r = m:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function hunting(): boolean
	return st ~= nil and st.Active == true and not st.IsYou
end

-- ---------------------------------------------------------------------------
-- 3D-стрелка-компас у своего персонажа
-- ---------------------------------------------------------------------------
local arrowParts: { Part } = {}

local function arrow3d(): { Part }
	if #arrowParts > 0 and arrowParts[1].Parent then
		return arrowParts
	end
	local folder = Workspace:FindFirstChild("ClientFx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientFx"
		folder.Parent = Workspace
	end
	arrowParts = {}
	for i, size in ipairs({
		Vector3.new(0.7, 0.3, 3.4),
		Vector3.new(0.7, 0.3, 2.1),
		Vector3.new(0.7, 0.3, 2.1),
	}) do
		local p = Instance.new("Part")
		p.Name = if i == 1 then "HuntArrow" else "HuntArrowHead"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = ARROW_COLOR
		p.Size = size
		p.Transparency = 1
		p.Parent = folder
		table.insert(arrowParts, p)
	end
	return arrowParts
end

local function hideArrow3d()
	for _, p in ipairs(arrowParts) do
		p.Transparency = 1
	end
end

-- ---------------------------------------------------------------------------
-- init
-- ---------------------------------------------------------------------------
function HuntHud.init(gui: ScreenGui, events: Frame)
	local card = Widgets.New("Frame", {
		Name = "HuntCard",
		Size = UDim2.new(1, 0, 0, CARD_H),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.05,
		LayoutOrder = 0,
		Visible = false,
		ZIndex = 6,
		Parent = events,
	})
	Widgets.corner(card, 10)
	local stroke = Widgets.stroke(card, Theme.Orange, 2)
	local title = UiKit.text(
		card,
		"",
		UDim2.fromOffset(8, 2),
		UDim2.new(1, -66, 0, 20),
		{ Font = Theme.Font, TextColor3 = Theme.Orange, MaxSize = 15, ZIndex = 7 }
	)
	title.Name = "Title"
	local timer = UiKit.text(card, "", UDim2.new(1, -58, 0, 2), UDim2.fromOffset(50, 20), {
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Gold,
		MaxSize = 15,
		ZIndex = 7,
	})
	timer.Name = "Timer"
	local objective = UiKit.text(
		card,
		"",
		UDim2.fromOffset(8, 22),
		UDim2.new(1, -16, 0, 17),
		{ TextColor3 = Theme.Text, MaxSize = 12, ZIndex = 7 }
	)
	objective.Name = "Objective"
	local hpBar = UiKit.bar(card, UDim2.fromOffset(8, 42), UDim2.new(1, -16, 0, 16), Theme.Red)
	hpBar.Back.Name = "HpBar"
	local damage = UiKit.text(
		card,
		"",
		UDim2.fromOffset(8, 61),
		UDim2.new(1, -16, 0, 16),
		{ TextColor3 = Theme.TextDim, MaxSize = 11, ZIndex = 7 }
	)
	damage.Name = "Damage"
	local extra = UiKit.text(
		card,
		"",
		UDim2.fromOffset(8, 79),
		UDim2.new(1, -16, 0, 17),
		{ Font = Theme.Font, TextColor3 = Theme.Gold, MaxSize = 12, ZIndex = 7 }
	)
	extra.Name = "Extra"

	-- экранный указатель (три повёрнутые полоски) + подпись
	local pointer = Widgets.New("Frame", {
		Name = "HuntPointer",
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	local function bar(name: string, w: number, h: number): Frame
		local f = Widgets.New("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = ARROW_COLOR,
			BorderSizePixel = 0,
			ZIndex = 31,
			Parent = pointer,
		})
		Widgets.corner(f, 3)
		Widgets.stroke(f, Color3.fromRGB(70, 40, 0), 2)
		return f
	end
	local shaft = bar("Shaft", 44, 11)
	local headA = bar("HeadA", 24, 11)
	local headB = bar("HeadB", 24, 11)
	local pointerLabel = Widgets.label({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(150, 20),
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextStrokeTransparency = 0.2,
		ZIndex = 32,
		Parent = pointer,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8, Parent = pointerLabel })

	local function place(f: GuiObject, x: number, y: number, rot: number)
		f.Position = UDim2.fromOffset(x, y)
		f.Rotation = rot
	end

	local function drawPointer()
		local tRoot = targetRoot()
		local cam = Workspace.CurrentCamera
		if not hunting() or not tRoot or not cam then
			pointer.Visible = false
			hideArrow3d()
			return
		end
		local me0 = myRoot()
		if me0 and (tRoot.Position - me0.Position).Magnitude < 14 then
			pointer.Visible = false -- цель рядом: указатель не нужен (дистанция есть в карточке)
			hideArrow3d()
			return
		end
		local vp = cam.ViewportSize
		local off = gui.AbsolutePosition
		local scale = (st.Model and st.Model:GetAttribute("Super")) and 1.6 or 1
		local v = cam:WorldToViewportPoint(tRoot.Position + Vector3.new(0, 5 * scale, 0))
		local cx, cy = vp.X / 2, vp.Y / 2
		local dx, dy = v.X - cx, v.Y - cy
		if v.Z < 0 then
			dx, dy = -dx, -dy
		end
		local px, py, ang
		if v.Z > 0 and math.abs(dx) < vp.X * 0.36 and math.abs(dy) < vp.Y * 0.32 then
			-- цель в кадре: стрелка над ней, остриём вниз
			px, py, ang = v.X, v.Y - 42, math.pi / 2
		else
			ang = math.atan2(dy, dx)
			px = cx + math.cos(ang) * vp.X * 0.38
			py = cy + math.sin(ang) * vp.Y * 0.34
		end
		-- не залезаем на HUD: меню слева, карточки справа, панели сверху и кнопки снизу
		local lay = Layout.get()
		local mx = if lay.Mode == "wide" then 215 else math.floor(vp.X * 0.22)
		local top = if lay.Mode == "portrait" then 390 elseif lay.Mode == "landscape" then 120 else 125
		local bottom = if lay.Mode == "wide" then 140 else 150
		px = math.clamp(px, mx, math.max(mx + 1, vp.X - mx))
		py = math.clamp(py, top, math.max(top + 1, vp.Y - bottom))
		px -= off.X
		py -= off.Y
		local dirX, dirY = math.cos(ang), math.sin(ang)
		local deg = math.deg(ang)
		place(shaft, px, py, deg)
		local tipX, tipY = px + dirX * 22, py + dirY * 22
		for i, h in ipairs({ headA, headB }) do
			local a = ang + (if i == 1 then 1 else -1) * math.rad(140)
			place(h, tipX + math.cos(a) * 10, tipY + math.sin(a) * 10, math.deg(a))
		end
		local me = myRoot()
		local dist = if me then (tRoot.Position - me.Position).Magnitude else 0
		pointerLabel.Text = displayName(st) .. " · " .. L.t("hunt.distance", { n = math.floor(dist + 0.5) })
		place(pointerLabel, px - dirX * 42, py - dirY * 36 + (if math.abs(dirY) > 0.7 then 0 else 14), 0)
		pointer.Visible = true

		if me and dist > 10 then
			local parts = arrow3d()
			local flat = Vector3.new(tRoot.Position.X - me.Position.X, 0, tRoot.Position.Z - me.Position.Z)
			if flat.Magnitude > 0.1 then
				-- стрелка-компас лежит на земле перед персонажем (её не закрывают баннеры и подписи)
				local myScale = me.Parent and (me.Parent :: Model):GetScale() or 1
				local base = me.Position + flat.Unit * 4.5 - Vector3.new(0, 2.75 * myScale, 0)
				local cf = CFrame.lookAt(base, base + flat.Unit)
				parts[1].CFrame = cf * CFrame.new(0, 0, -0.2)
				parts[2].CFrame = cf * CFrame.new(-0.62, 0, -1.3) * CFrame.Angles(0, math.rad(-40), 0)
				parts[3].CFrame = cf * CFrame.new(0.62, 0, -1.3) * CFrame.Angles(0, math.rad(40), 0)
				for _, p in ipairs(parts) do
					p.Transparency = 0.05
				end
			end
		else
			hideArrow3d()
		end
	end

	local function drawCard()
		if not st then
			card.Visible = false
			return
		end
		if st.Active then
			card.Visible = true
			card.Size = UDim2.new(1, 0, 0, CARD_H)
			hpBar.Back.Visible = true
			local left = leftNow()
			timer.Text = Util.formatTime(math.ceil(left))
			hpBar.Set(
				(st.Hp or 0) / math.max(1, st.MaxHp or 1),
				("%d / %d"):format(st.Hp or 0, st.MaxHp or 0)
			)
			if st.IsYou then
				stroke.Color = Theme.Gold
				title.TextColor3 = Theme.Gold
				title.Text = L.t("hunt.you_title")
				objective.Text =
					L.t(if Layout.isTouch() then "hunt.you_objective_touch" else "hunt.you_objective")
				damage.Text = ""
				extra.Text = ""
			else
				stroke.Color = Theme.Orange
				title.TextColor3 = Theme.Orange
				title.Text = L.t("hunt.card_title", { player = displayName(st) })
				objective.Text = L.t("hunt.objective", { player = displayName(st) })
				local n, min = st.YourDamage or 0, st.MinDamage or 0
				local hits, minHits = st.YourHits or 0, st.MinHits or 0
				local ok = n >= min and hits >= minHits
				damage.Text = if ok
					then L.t("hunt.damage_ok", { n = n })
					elseif n >= min then L.t("hunt.need_hits", { n = hits, min = minHits })
					else L.t("hunt.damage", { n = n, min = min })
				damage.TextColor3 = if ok then Theme.Green else Theme.TextDim
				if st.Stunned then
					extra.Text = L.t("hunt.stunned")
					extra.TextColor3 = Theme.Red
				else
					local me, t = myRoot(), targetRoot()
					extra.Text = if me and t
						then "→ " .. L.t(
							"hunt.distance",
							{ n = math.floor((t.Position - me.Position).Magnitude + 0.5) }
						)
						else ""
					extra.TextColor3 = Theme.Gold
				end
			end
		elseif st.NextIn and not st.Waiting and st.NextIn - (os.clock() - gotAt) <= SHOW_NEXT then
			card.Visible = true
			card.Size = UDim2.new(1, 0, 0, IDLE_H)
			stroke.Color = Theme.Orange
			title.TextColor3 = Theme.Orange
			title.Text = L.t(
				"hunt.next",
				{ time = Util.formatTime(math.max(0, math.ceil(st.NextIn - (os.clock() - gotAt)))) }
			)
			timer.Text = ""
			objective.Text = L.t("hunt.next_desc")
			hpBar.Back.Visible = false
			damage.Text = ""
			extra.Text = ""
		else
			card.Visible = false
		end
	end

	local function banners()
		if st.Active and st.Round ~= lastStartBanner then
			lastStartBanner = st.Round
			roundWasYou[st.Round] = st.IsYou == true
			if st.IsYou then
				Toasts.banner(
					L.t("hunt.banner_you"),
					L.t("hunt.banner_you_sub", { time = Util.formatTime(math.ceil(st.Left or 0)) }),
					Theme.Gold,
					4.5
				)
			else
				Toasts.banner(
					L.t("hunt.banner_start"),
					L.t("hunt.banner_start_sub", { player = displayName(st) }),
					Theme.Orange,
					4.5
				)
			end
		end
		local o = st.Outcome
		if type(o) == "table" and o.Round ~= lastOutcomeBanner and o.Round == lastStartBanner then
			lastOutcomeBanner = o.Round
			local you = roundWasYou[o.Round]
			local who = { player = tostring(o.Target or "?") }
			if o.Kind == "stopped" then
				if you then
					Toasts.banner(
						L.t("hunt.banner_you_stopped"),
						L.t("hunt.banner_you_stopped_sub"),
						Theme.Blue,
						4
					)
				else
					Toasts.banner(
						L.t("hunt.banner_stopped"),
						L.t("hunt.banner_stopped_sub", who),
						Theme.Green,
						4
					)
				end
			elseif o.Kind == "survived" then
				if you then
					Toasts.banner(
						L.t("hunt.banner_you_survived"),
						L.t("hunt.banner_you_survived_sub"),
						Theme.Gold,
						4
					)
				else
					Toasts.banner(
						L.t("hunt.banner_survived"),
						L.t("hunt.banner_survived_sub", who),
						Theme.Purple,
						4
					)
				end
			end
		end
	end

	Remotes.getEvent("Superpower").OnClientEvent:Connect(function(s)
		if type(s) ~= "table" then
			return
		end
		st = s
		gotAt = os.clock()
		gui:SetAttribute("HuntActive", s.Active == true)
		gui:SetAttribute("HuntHp", s.Hp)
		banners()
		drawCard()
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		drawPointer()
		acc += dt
		if acc >= 0.25 then
			acc = 0
			drawCard()
		end
	end)

	return card
end

return HuntHud
