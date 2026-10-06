--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Locale"))

local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Actions = require(script.Parent.Actions)
local ClientState = require(script.Parent.ClientState)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local DailyPanel = {}

function DailyPanel.init(gui: ScreenGui)
	local panel = Widgets.panel(gui, "Daily Rewards")
	local body = panel.Body

	local grid = Widgets.New("Frame", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 1, -140),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UIGridLayout", {
		CellSize = UDim2.new(0.25, -8, 0.5, -8),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cards = {}
	for day, reward in ipairs(Config.DAILY_REWARDS) do
		local card = Widgets.New("Frame", {
			BackgroundColor3 = Theme.BgCard,
			LayoutOrder = day,
			ZIndex = 23,
			Parent = grid,
		})
		Widgets.corner(card, 12)
		local stroke = Widgets.stroke(card, Theme.BgLight, 3)
		Widgets.label({
			Text = L.k("daily.day", { n = day }),
			Size = UDim2.new(1, -8, 0.25, 0),
			Position = UDim2.fromOffset(4, 4),
			Font = Theme.Font,
			ZIndex = 24,
			Parent = card,
		})
		Widgets.label({
			Text = L.k(if reward.Luck2Minutes then "daily.card_luck" else "daily.card", {
				n = reward.Gems,
				clicks = Util.formatNumber(reward.Clicks),
				m = reward.Luck2Minutes,
			}),
			Size = UDim2.new(1, -8, 0.6, 0),
			Position = UDim2.new(0, 4, 0.32, 0),
			TextColor3 = Theme.Gem,
			ZIndex = 24,
			Parent = card,
		})
		cards[day] = { Card = card, Stroke = stroke }
	end

	local streakLabel = Widgets.label({
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.new(0, 12, 1, -122),
		TextColor3 = Theme.TextDim,
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 16, Parent = streakLabel })
	local bonusLabel = Widgets.label({
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.new(0, 12, 1, -98),
		TextColor3 = Theme.Gold,
		Text = L.k("daily.bonus", { n = Config.PASS_EFFECTS.PREMIUM_DAILY_GEMS }),
		ZIndex = 22,
		Parent = body,
	})
	Widgets.New("UITextSizeConstraint", { MaxTextSize = 14, Parent = bonusLabel })

	local claim = Widgets.button({
		Text = L.k("daily.claim"),
		Color = Theme.Green,
		Size = UDim2.new(0.6, 0, 0, 52),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		ZIndex = 23,
		OnClick = function()
			local core = ClientState.Core
			if core and core.Daily.CanClaim then
				Actions.call("ClaimDaily")
			end
		end,
		Parent = body,
	})

	local function refresh()
		local core = ClientState.Core
		if not core then
			return
		end
		local d = core.Daily
		for day, c in pairs(cards) do
			local isNext = day == d.Day
			c.Stroke.Color = if isNext then Theme.Gold else Theme.BgLight
			c.Card.BackgroundColor3 = if isNext then Theme.BgLight else Theme.BgCard
		end
		streakLabel.Text = L.t("daily.streak", { n = d.Streak })
		if d.CanClaim then
			claim.Text = L.t("daily.claim_day", { n = d.Day })
			Widgets.setEnabled(claim, true, Theme.Green)
		else
			local left = d.SecondsLeft - (os.clock() - ClientState.ReceivedClock)
			claim.Text = L.t("daily.next_in", { time = Util.formatTime(left) })
			Widgets.setEnabled(claim, false)
		end
	end

	ClientState.onCore(refresh)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 and panel.IsOpen() then
			acc = 0
			refresh()
		end
	end)
	return panel
end

return DailyPanel
