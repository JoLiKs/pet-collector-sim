--!nonstrict
-- Основной HUD: валюты, мир, кнопка COLLECT, автосбор, меню слева.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Remotes = require(Shared:WaitForChild("Remotes"))
local Util = require(Shared:WaitForChild("Util"))
local ZoneData = require(Shared:WaitForChild("ZoneData"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Hud = {}

local MENU = {
	{ Id = "Pets", Text = "PETS", Color = Theme.Orange },
	{ Id = "Upgrades", Text = "UPGRADES", Color = Theme.Blue },
	{ Id = "Zones", Text = "WORLDS", Color = Theme.Green },
	{ Id = "Rebirth", Text = "REBIRTH", Color = Theme.Purple },
	{ Id = "Daily", Text = "DAILY", Color = Theme.Gold },
	{ Id = "Shop", Text = "SHOP", Color = Theme.Red },
}

local function statPill(parent: Instance, order: number, icon: string, color: Color3): TextLabel
	local pill = Widgets.New("Frame", {
		Name = "Stat" .. order,
		Size = UDim2.fromOffset(190, 38),
		Position = UDim2.fromOffset(12, 12 + (order - 1) * 44),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Parent = parent,
	})
	Widgets.corner(pill, 19)
	Widgets.stroke(pill, color, 2)
	local badge = Widgets.label({
		Text = icon,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Theme.Font,
		Parent = pill,
	})
	Widgets.corner(badge, 15)
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 18, Parent = badge })
	local value = Widgets.label({
		Name = "Value",
		Size = UDim2.new(1, -46, 1, -10),
		Position = UDim2.fromOffset(40, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font,
		Parent = pill,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 24, Parent = value })
	return value
end

function Hud.init(gui: ScreenGui, openPanel: (string) -> ())
	local clickRemote = Remotes.getEvent("Click")

	local coinsLabel = statPill(gui, 1, "$", Theme.Gold)
	local gemsLabel = statPill(gui, 2, "G", Theme.Gem)
	local rebirthLabel = statPill(gui, 3, "R", Theme.Purple)

	-- Мир и множитель сверху по центру
	local zoneBox = Widgets.New("Frame", {
		Name = "ZoneBox",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(300, 54),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	Widgets.corner(zoneBox, 14)
	Widgets.stroke(zoneBox, Theme.BgLight, 2)
	local zoneLabel = Widgets.label({
		Size = UDim2.new(1, -12, 0.55, -2),
		Position = UDim2.fromOffset(6, 3),
		Font = Theme.Font,
		Parent = zoneBox,
	})
	local buffLabel = Widgets.label({
		Size = UDim2.new(1, -12, 0.4, -2),
		Position = UDim2.new(0, 6, 0.58, 0),
		TextColor3 = Theme.TextDim,
		Parent = zoneBox,
	})

	-- Кнопка COLLECT
	local perClickLabel = Widgets.label({
		Name = "PerClick",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(260, 24),
		TextColor3 = Theme.Gold,
		TextStrokeTransparency = 0.5,
		Parent = gui,
	})
	local collect = Widgets.button({
		Name = "Collect",
		Text = "COLLECT",
		Color = Theme.Orange,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(250, 76),
		MaxTextSize = 40,
		Parent = gui,
	})

	local autoBtn = Widgets.button({
		Name = "AutoToggle",
		Text = "AUTO: ON",
		Color = Theme.Green,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.5, 140, 1, -24),
		Size = UDim2.fromOffset(110, 40),
		Visible = false,
		Parent = gui,
		OnClick = function()
			local core = ClientState.Core
			if core then
				Actions.call("SetAutoCollect", not core.AutoCollect)
			end
		end,
	})

	-- Удержание кнопки = повторные клики (сервер всё равно ограничивает частоту)
	local holding = false
	local function popup(text: string)
		local absPos = collect.AbsolutePosition
		local absSize = collect.AbsoluteSize
		-- координаты переводим в систему ScreenGui (учитывает верхний отступ GUI inset)
		local x = absPos.X - gui.AbsolutePosition.X + absSize.X * (0.2 + math.random() * 0.6)
		local y = absPos.Y - gui.AbsolutePosition.Y - 10
		local l = Widgets.label({
			Text = text,
			Size = UDim2.fromOffset(110, 28),
			Position = UDim2.fromOffset(x - 55, y),
			TextColor3 = Theme.Gold,
			TextStrokeTransparency = 0.3,
			Font = Theme.Font,
			ZIndex = 40,
			Parent = gui,
		})
		local tw = Widgets.tween(
			l,
			0.7,
			{ Position = UDim2.fromOffset(x - 55, y - 70), TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		tw.Completed:Once(function()
			l:Destroy()
		end)
	end
	local function collectOnce()
		clickRemote:FireServer()
		local core = ClientState.Core
		if core then
			popup("+" .. Util.formatNumber(core.PerClick))
		end
	end
	local function startHolding()
		if holding then
			return
		end
		holding = true
		task.spawn(function()
			while holding do
				collectOnce()
				task.wait(0.1)
			end
		end)
	end
	collect.MouseButton1Down:Connect(startHolding)
	collect.MouseButton1Up:Connect(function()
		holding = false
	end)
	collect.MouseLeave:Connect(function()
		holding = false
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
		then
			holding = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			collectOnce()
		end
	end)

	-- Меню слева
	local menu = Widgets.New("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 40),
		Size = UDim2.fromOffset(112, #MENU * 46),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Widgets.New("UIListLayout", { Padding = UDim.new(0, 6), Parent = menu })
	local dailyDot
	for _, item in ipairs(MENU) do
		local b = Widgets.button({
			Name = item.Id,
			Text = item.Text,
			Color = item.Color,
			Size = UDim2.fromOffset(112, 40),
			OnClick = function()
				openPanel(item.Id)
			end,
			Parent = menu,
		})
		if item.Id == "Daily" then
			dailyDot = Widgets.label({
				Text = "!",
				BackgroundTransparency = 0,
				BackgroundColor3 = Theme.Red,
				Size = UDim2.fromOffset(22, 22),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Font = Theme.Font,
				Visible = false,
				ZIndex = 5,
				Parent = b,
			})
			Widgets.corner(dailyDot, 11)
		end
	end

	-- Обновление при каждом снимке состояния
	ClientState.onCore(function(core)
		coinsLabel.Text = Util.formatNumber(core.Coins)
		gemsLabel.Text = Util.formatNumber(core.Gems)
		rebirthLabel.Text = "Rebirth " .. tostring(core.Rebirths)
		local zone = ZoneData.ById[core.CurrentZone]
		if zone then
			zoneLabel.Text = ("%s  (x%d)"):format(zone.Name, zone.Multiplier)
		end
		perClickLabel.Text = "+" .. Util.formatNumber(core.PerClick) .. " per collect"
		autoBtn.Visible = core.Passes.AUTO_COLLECT == true
		autoBtn.Text = if core.AutoCollect then "AUTO: ON" else "AUTO: OFF"
		autoBtn.BackgroundColor3 = if core.AutoCollect then Theme.Green else Theme.Disabled
		if dailyDot then
			dailyDot.Visible = core.Daily.CanClaim
		end
	end)

	-- Таймер буста удачи (обновляется каждый кадр "дёшево": только текст раз в 0.5с)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local core = ClientState.Core
		if not core then
			return
		end
		local left = core.LuckBoostEnds - ClientState.serverNow()
		if core.LuckBoost > 1 and left > 0 then
			buffLabel.Text = ("Luck x%d  %s"):format(core.LuckBoost, Util.formatTime(left))
			buffLabel.TextColor3 = Theme.Green
		else
			buffLabel.Text = ("Luck x%.2f"):format(core.Luck)
			buffLabel.TextColor3 = Theme.TextDim
		end
	end)
end

return Hud
