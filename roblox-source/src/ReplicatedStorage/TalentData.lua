--!strict
--[[
	Дерево талантов (открывается ребёртами). Очки: Formulas.talentPoints(rebirths) - потрачено.
	Effect: ключ суммируется по уровням: bonus = sum(level * PerLevel). Сброс талантов — за гемы.
]]
local TalentData = {}

export type Node = {
	Id: string,
	Name: string,
	Desc: string,
	Branch: string,
	Max: number,
	Requires: { [string]: number },
	Stat: string,
	PerLevel: number,
	Row: number,
	Col: number,
}

local function n(id, name, desc, branch, max, requires, stat, per, row, col): Node
	return {
		Id = id,
		Name = name,
		Desc = desc,
		Branch = branch,
		Max = max,
		Requires = requires,
		Stat = stat,
		PerLevel = per,
		Row = row,
		Col = col,
	}
end

TalentData.Branches = {
	Economy = { Color = Color3.fromRGB(255, 208, 70) },
	Combat = { Color = Color3.fromRGB(235, 85, 85) },
	Nature = { Color = Color3.fromRGB(100, 210, 120) },
} :: { [string]: { Color: Color3 } }
TalentData.BranchOrder = { "Economy", "Combat", "Nature" }

TalentData.List = {
	n("eco_coins", "Golden Touch", "+10% coins per level.", "Economy", 5, {}, "Coins", 0.10, 1, 1),
	n(
		"eco_start",
		"Head Start",
		"Start each rebirth with +2,000 coins per level.",
		"Economy",
		3,
		{ eco_coins = 2 },
		"StartCoins",
		2000,
		2,
		1
	),
	n(
		"eco_offline",
		"Sleeping Partner",
		"+25% offline income per level.",
		"Economy",
		4,
		{ eco_coins = 1 },
		"Offline",
		0.25,
		2,
		2
	),
	n(
		"eco_slot",
		"Roomy Team",
		"+1 pet slot.",
		"Economy",
		1,
		{ eco_start = 2, eco_offline = 1 },
		"Slots",
		1,
		3,
		1
	),
	n("cmb_dmg", "Sharpened Claws", "+10% team damage per level.", "Combat", 5, {}, "Damage", 0.10, 1, 1),
	n(
		"cmb_hp",
		"Thick Skin",
		"-6% damage taken per level.",
		"Combat",
		4,
		{ cmb_dmg = 1 },
		"Defense",
		0.06,
		2,
		1
	),
	n(
		"cmb_player",
		"Warrior's Spirit",
		"+20% your own attack per level.",
		"Combat",
		4,
		{ cmb_dmg = 2 },
		"PlayerDamage",
		0.20,
		2,
		2
	),
	n(
		"cmb_xp",
		"Quick Learners",
		"+15% pet experience per level.",
		"Combat",
		4,
		{ cmb_hp = 1 },
		"Xp",
		0.15,
		3,
		1
	),
	n("nat_gather", "Green Thumb", "+20% resources per level.", "Nature", 5, {}, "Gather", 0.20, 1, 1),
	n(
		"nat_luck",
		"Fortune's Favor",
		"+5% hatch luck per level.",
		"Nature",
		5,
		{ nat_gather = 1 },
		"Luck",
		0.05,
		2,
		1
	),
	n(
		"nat_speed",
		"Light Feet",
		"+4% walk speed per level.",
		"Nature",
		4,
		{ nat_gather = 1 },
		"Speed",
		0.04,
		2,
		2
	),
	n(
		"nat_essence",
		"Essence Seeker",
		"+25% Essence from monsters per level.",
		"Nature",
		4,
		{ nat_luck = 1 },
		"Essence",
		0.25,
		3,
		1
	),
}

TalentData.ById = {} :: { [string]: Node }
for _, x in ipairs(TalentData.List) do
	TalentData.ById[x.Id] = x
end

TalentData.RESPEC_GEMS = 50

function TalentData.bonus(levels: { [string]: number }, stat: string): number
	local total = 0
	for _, node in ipairs(TalentData.List) do
		if node.Stat == stat then
			total += (levels[node.Id] or 0) * node.PerLevel
		end
	end
	return total
end

function TalentData.spent(levels: { [string]: number }): number
	local s = 0
	for id, lv in pairs(levels) do
		if TalentData.ById[id] then
			s += lv
		end
	end
	return s
end

-- Можно ли купить следующий уровень: (ok, reason)
function TalentData.canBuy(levels: { [string]: number }, id: string, pointsFree: number): (boolean, string?)
	local node = TalentData.ById[id]
	if not node then
		return false, "Unknown talent"
	end
	if (levels[id] or 0) >= node.Max then
		return false, "Maxed"
	end
	if pointsFree < 1 then
		return false, "No talent points"
	end
	for req, lv in pairs(node.Requires) do
		if (levels[req] or 0) < lv then
			return false,
				"Requires " .. (TalentData.ById[req] and TalentData.ById[req].Name or req) .. " " .. tostring(
					lv
				)
		end
	end
	return true, nil
end

return TalentData
