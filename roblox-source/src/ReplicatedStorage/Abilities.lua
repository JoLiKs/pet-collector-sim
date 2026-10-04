--!strict
--[[
	Abilities — способности питомцев.
	Kind = "Active": срабатывает автоматически в бою по кулдауну (CombatService).
	Kind = "Passive": постоянный бонус, пока питомец в команде (Economy / CombatService читают Stat).
	Value масштабируется множителем эволюции (PetMeta.abilityScale).
]]
export type Ability = {
	Id: string,
	Name: string,
	Kind: string, -- "Active" | "Passive"
	Cooldown: number?, -- сек (Active)
	Effect: string, -- Active: "Damage" | "AoE" | "Heal" | "Shield" | "Frenzy" | "Mine"; Passive: Stat ниже
	Value: number,
	Desc: string,
}

local Abilities = {}

local function a(
	id: string,
	name: string,
	kind: string,
	cd: number?,
	effect: string,
	value: number,
	desc: string
): Ability
	return { Id = id, Name = name, Kind = kind, Cooldown = cd, Effect = effect, Value = value, Desc = desc }
end

Abilities.List = {
	-- Активные
	a("fireball", "Fireball", "Active", 6, "AoE", 3, "Burst of flame: 3x damage to every nearby enemy."),
	a(
		"tidal",
		"Tidal Wave",
		"Active",
		7,
		"Damage",
		4,
		"A crashing wave: 4x damage to the target and heals you 5%."
	),
	a("quake", "Quake", "Active", 8, "AoE", 2.5, "Ground shatters: 2.5x damage to all nearby enemies."),
	a("gust", "Gust", "Active", 5, "Damage", 2.5, "Wind slash: 2.5x damage to the target."),
	a("mend", "Mending Song", "Active", 9, "Heal", 0.25, "Heals you for 25% of max health."),
	a("ward", "Guardian Ward", "Active", 12, "Shield", 0.5, "Halves incoming damage for 6 seconds."),
	a(
		"frenzy",
		"Battle Frenzy",
		"Active",
		14,
		"Frenzy",
		0.5,
		"+50% damage for the whole team for 6 seconds."
	),
	a("dig", "Treasure Dig", "Active", 10, "Mine", 1, "Instantly harvests the nearest resource node."),
	-- Пассивные
	a("greed", "Greed", "Passive", nil, "Coins", 0.10, "+10% coins from everything."),
	a("lucky", "Lucky Charm", "Passive", nil, "Luck", 0.08, "+8% hatch luck."),
	a("scholar", "Scholar", "Passive", nil, "Xp", 0.20, "+20% pet experience."),
	a("sturdy", "Sturdy Hide", "Passive", nil, "Hp", 0.10, "-10% damage taken."),
	a("swift", "Swift Paws", "Passive", nil, "Speed", 0.06, "+6% walk speed."),
	a("forager", "Forager", "Passive", nil, "Gather", 0.25, "+25% resources from gathering."),
	a("slayer", "Slayer", "Passive", nil, "Damage", 0.12, "+12% team damage."),
}

Abilities.ById = {} :: { [string]: Ability }
for _, ab in ipairs(Abilities.List) do
	Abilities.ById[ab.Id] = ab
end

return Abilities
