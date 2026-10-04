--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Formulas = require(Shared:WaitForChild("Formulas"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local RebirthPanel = {}

function RebirthPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Rebirth")
	local body = panel.Body

	local main = Widgets.label({
		Size = UDim2.new(1, -30, 0, 70),
		Position = UDim2.fromOffset(15, 10),
		Font = Theme.Font,
		TextColor3 = Theme.Purple,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 32, Parent = main })
	local detail = Widgets.label({
		Size = UDim2.new(1, -30, 0, 90),
		Position = UDim2.fromOffset(15, 84),
		TextColor3 = Theme.TextDim,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 20, Parent = detail })

	local barBg = Widgets.New("Frame", {
		Position = UDim2.fromOffset(15, 184),
		Size = UDim2.new(1, -30, 0, 26),
		BackgroundColor3 = Theme.BgLight,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.corner(barBg, 13)
	local bar = Widgets.New("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Purple,
		ZIndex = 23,
		Parent = barBg,
	})
	Widgets.corner(bar, 13)
	local barText = Widgets.label({ Size = UDim2.fromScale(1, 1), ZIndex = 24, Parent = barBg })
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 16, Parent = barText })

	local confirm = false
	local btn
	btn = Widgets.button({
		Text = "REBIRTH",
		Color = Theme.Purple,
		Size = UDim2.new(0.6, 0, 0, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		ZIndex = 23,
		OnClick = function()
			local core = ClientState.Core
			if not core or core.Coins < core.RebirthCost then
				Actions.call("Rebirth") -- сервер вернёт понятную ошибку
				return
			end
			if not confirm then
				confirm = true
				btn.Text = "Tap again to confirm!"
				task.delay(3, function()
					confirm = false
					btn.Text = "REBIRTH"
				end)
				return
			end
			confirm = false
			btn.Text = "REBIRTH"
			Actions.call("Rebirth")
		end,
		Parent = body,
	})

	ClientState.onCore(function(core)
		local cur = Formulas.rebirthMultiplier(core.Rebirths)
		local nxt = Formulas.rebirthMultiplier(core.Rebirths + 1)
		main.Text = ("Coin bonus: x%.1f  >  x%.1f"):format(cur, nxt)
		detail.Text = ("Cost: %s coins\nReward: +%d gems and a permanent coin bonus.\nResets: coins and Click Power. You keep pets, gems, worlds and other upgrades."):format(
			Util.formatNumber(core.RebirthCost),
			Formulas.rebirthGems(core.Rebirths)
		)
		local ratio = math.clamp(core.Coins / core.RebirthCost, 0, 1)
		bar.Size = UDim2.fromScale(ratio, 1)
		barText.Text = ("%s / %s"):format(Util.formatNumber(core.Coins), Util.formatNumber(core.RebirthCost))
		btn.BackgroundColor3 = if ratio >= 1 then Theme.Purple else Theme.Disabled
	end)
	return panel
end

return RebirthPanel
