--!strict
--[[
	WorldLabels (v3.2) — порядок среди подписей мира на этом клиенте (LabelLayout — правила, покрыты тестами).
	Сервер ставит у BillboardGui атрибут LabelKind (Player, Bot, Npc, Super, Egg, Zone, Sign) и размер в пикселях.
	Раз в UPDATE секунд:
	  * подпись проецируется на экран (Camera:WorldToViewportPoint) — дальше предела вида скрыта, у предела гаснет;
	  * размер = базовый × масштаб экрана × масштаб расстояния (на телефоне меньше, вдали чуть меньше);
	  * при наложении важные подписи (своя, игроки) остаются, подписи персонажей поднимаются «стопкой»,
	    таблички и подписи ботов скрываются;
	  * подпись, задевающая HUD (хотбар, кнопки, валюты, плашки событий), скрывается.
	Меняются только локальные копии (Enabled, Size, StudsOffset, прозрачность текста) — у других игроков своё.
	Атрибуты для тестов на BillboardGui: LabelShown (true/false).
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LabelLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LabelLayout"))

local UPDATE = 0.1
local player = Players.LocalPlayer

type Fade = { Obj: Instance, Text: number?, Stroke: number?, Back: number? }
type Rec = {
	Gui: BillboardGui,
	Kind: string,
	W: number,
	H: number,
	Offset: Vector3,
	Fades: { Fade }?,
	Shown: boolean?,
	Scale: number?,
	Alpha: number?,
	Shift: number?,
}

local recs: { [BillboardGui]: Rec } = {}

local function collectFades(g: BillboardGui): { Fade }
	local list: { Fade } = {}
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(list, {
				Obj = d :: Instance,
				Text = d.TextTransparency,
				Stroke = d.TextStrokeTransparency,
				Back = d.BackgroundTransparency,
			})
		elseif d:IsA("Frame") then
			table.insert(list, { Obj = d :: Instance, Back = d.BackgroundTransparency })
		end
	end
	return list
end

local orig: { [Instance]: any } = setmetatable({}, { __mode = "k" }) :: any

local function track(inst: Instance)
	if not inst:IsA("BillboardGui") or recs[inst] then
		return
	end
	local kind = inst:GetAttribute("LabelKind")
	if type(kind) ~= "string" then
		return
	end
	-- Аудит v3.2: исходный размер запоминается один раз — подпись, вынутая из Workspace и вставленная
	-- обратно, не берёт за «исходный» уже уменьшенный нами размер; подписки тоже ставятся один раз
	local o = orig[inst]
	local first = o == nil
	if not o then
		local size = inst.Size
		if size.X.Offset <= 0 or size.Y.Offset <= 0 then
			return -- размер в студах — не наш случай (например, логотип на щите)
		end
		o = { W = size.X.Offset, H = size.Y.Offset, Offset = inst.StudsOffset }
		orig[inst] = o
	end
	local oo = o :: { W: number, H: number, Offset: Vector3 }
	recs[inst] = {
		Gui = inst,
		Kind = kind,
		W = oo.W,
		H = oo.H,
		Offset = oo.Offset,
	}
	if not first then
		return
	end
	inst.AncestryChanged:Connect(function()
		if not inst:IsDescendantOf(Workspace) then
			recs[inst] = nil
		end
	end)
	inst.DescendantAdded:Connect(function()
		local r = recs[inst]
		if r then
			r.Fades = nil -- пересобрать список при следующем изменении прозрачности
			r.Alpha = nil
		end
	end)
end

for _, d in ipairs(Workspace:GetDescendants()) do
	track(d)
end
Workspace.DescendantAdded:Connect(track)

-- HUD: прямоугольники, которые подписи не должны задевать (в координатах вьюпорта)
local SELF = { "Hotbar", "Currency", "Tutorial" }
local KIDS = { "LeftButtons", "RightButtons", "Timer" }

local function visibleChain(o: Instance, stop: Instance): boolean
	local cur: Instance? = o
	while cur and cur ~= stop do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		cur = cur.Parent
	end
	return true
end

local function hudBlocks(): { LabelLayout.Rect }
	local out: { LabelLayout.Rect } = {}
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local gui = pg and pg:FindFirstChild("PetCollectorGui")
	if not gui or not gui:IsA("ScreenGui") then
		return out
	end
	local inset = Vector2.zero
	if not gui.IgnoreGuiInset then
		local ok, tl = pcall(function()
			return (GuiService:GetGuiInset())
		end)
		if ok and typeof(tl) == "Vector2" then
			inset = tl
		end
	end
	local function add(o: Instance)
		if o:IsA("GuiObject") and visibleChain(o, gui) then
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			if s.X > 1 and s.Y > 1 then
				table.insert(out, { X = p.X + inset.X, Y = p.Y + inset.Y, W = s.X, H = s.Y })
			end
		end
	end
	for _, name in ipairs(SELF) do
		local o = gui:FindFirstChild(name)
		if o then
			add(o)
		end
	end
	for _, name in ipairs(KIDS) do
		local o = gui:FindFirstChild(name)
		if o then
			for _, c in ipairs(o:GetChildren()) do
				add(c)
			end
		end
	end
	return out
end

local function adorneePos(g: BillboardGui): Vector3?
	local ad: Instance? = g.Adornee or g.Parent
	if ad and ad:IsA("BasePart") then
		return ad.Position
	elseif ad and ad:IsA("Attachment") then
		return ad.WorldPosition
	elseif ad and ad:IsA("Model") then
		local pp = ad.PrimaryPart
		return if pp then pp.Position else nil
	end
	return nil
end

local function applyAlpha(r: Rec, a: number)
	if r.Alpha and math.abs(r.Alpha - a) < 0.04 then
		return
	end
	r.Alpha = a
	local fades = r.Fades or collectFades(r.Gui)
	r.Fades = fades
	for _, f in ipairs(fades) do
		local o = f.Obj :: any
		if f.Text then
			o.TextTransparency = f.Text + (1 - f.Text) * a
		end
		if f.Stroke then
			o.TextStrokeTransparency = f.Stroke + (1 - f.Stroke) * a
		end
		if f.Back and f.Back < 1 then
			o.BackgroundTransparency = f.Back + (1 - f.Back) * a
		end
	end
end

local function update()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	if vp.X <= 1 or vp.Y <= 1 then
		return
	end
	local camPos = cam.CFrame.Position
	local char = player.Character
	local items: { LabelLayout.Item } = {}
	local list: { Rec } = {}

	for g, r in pairs(recs) do
		local pos = adorneePos(g)
		if pos then
			local wp = pos + r.Offset + g.StudsOffsetWorldSpace
			local sp, on = cam:WorldToViewportPoint(wp)
			local kind = r.Kind
			if char and (kind == "Player" or kind == "Super") and g:IsDescendantOf(char) then
				kind = if kind == "Player" then "Own" else kind
			end
			table.insert(list, r)
			table.insert(items, {
				Kind = kind,
				X = sp.X,
				Y = sp.Y,
				W = r.W,
				H = r.H,
				Dist = (camPos - wp).Magnitude,
				OnScreen = on and sp.Z > 0,
			})
		end
	end
	local res = LabelLayout.solve(items, hudBlocks(), { W = vp.X, H = vp.Y })
	local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
	for i, r in ipairs(list) do
		local x = res[i]
		local g = r.Gui
		if r.Shown ~= x.Show then
			r.Shown = x.Show
			g.Enabled = x.Show
			g:SetAttribute("LabelShown", x.Show)
		end
		if x.Show then
			if not r.Scale or math.abs(r.Scale - x.Scale) > 0.02 then
				r.Scale = x.Scale
				g.Size = UDim2.fromOffset(math.floor(r.W * x.Scale + 0.5), math.floor(r.H * x.Scale + 0.5))
			end
			-- сдвиг «стопкой»: пиксели -> студы на расстоянии подписи
			local studsPerPx = 2 * items[i].Dist * tanHalf / vp.Y
			local shift = x.Shift * studsPerPx
			if r.Shift == nil or math.abs(r.Shift - shift) > 0.05 then
				r.Shift = shift
				g.StudsOffset = r.Offset + Vector3.new(0, shift, 0)
			end
			applyAlpha(r, x.Alpha)
		end
	end
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < UPDATE then
		return
	end
	acc = 0
	update()
end)
