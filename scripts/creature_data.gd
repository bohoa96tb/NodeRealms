class_name CreatureData
extends RefCounted

enum Element { FIRE, WATER, NATURE, EARTH }

const CREATURE_ORDER := ["flame_golem", "aqua_spirit", "forest_guardian", "stone_titan"]
const MAX_CREATURE_LEVEL: int = 5
const UPGRADE_COSTS := [30, 60, 100, 150]


static func get_all_creatures() -> Dictionary:
	return {
		"flame_golem": {
			"id": "flame_golem",
			"name": "Flame Golem",
			"element": Element.FIRE,
			"element_name": "FIRE",
			"skill_name": "Blaze Surge",
			"color": Color(0.95, 0.36, 0.14, 1.0),
			"border_color": Color(1.0, 0.68, 0.35, 1.0),
			"duration": 6.0,
			"cooldown": 18.0,
			"attack_mult": 1.4,
			"defense_mult": 1.0,
			"production_mult": 1.0,
			"instant_heal": 0,
		},
		"aqua_spirit": {
			"id": "aqua_spirit",
			"name": "Aqua Spirit",
			"element": Element.WATER,
			"element_name": "WATER",
			"skill_name": "Tidal Mend",
			"color": Color(0.10, 0.78, 0.76, 1.0),
			"border_color": Color(0.55, 0.98, 0.96, 1.0),
			"duration": 0.0,
			"cooldown": 20.0,
			"attack_mult": 1.0,
			"defense_mult": 1.0,
			"production_mult": 1.0,
			"instant_heal": 6,
		},
		"forest_guardian": {
			"id": "forest_guardian",
			"name": "Forest Guardian",
			"element": Element.NATURE,
			"element_name": "NATURE",
			"skill_name": "Verdant Bloom",
			"color": Color(0.18, 0.74, 0.36, 1.0),
			"border_color": Color(0.55, 0.96, 0.65, 1.0),
			"duration": 8.0,
			"cooldown": 22.0,
			"attack_mult": 1.0,
			"defense_mult": 1.0,
			"production_mult": 2.0,
			"instant_heal": 0,
		},
		"stone_titan": {
			"id": "stone_titan",
			"name": "Stone Titan",
			"element": Element.EARTH,
			"element_name": "EARTH",
			"skill_name": "Iron Bastion",
			"color": Color(0.76, 0.58, 0.20, 1.0),
			"border_color": Color(0.96, 0.84, 0.48, 1.0),
			"duration": 7.0,
			"cooldown": 20.0,
			"attack_mult": 1.0,
			"defense_mult": 1.5,
			"production_mult": 1.0,
			"instant_heal": 0,
		},
	}


static func get_creature(creature_id: String) -> Dictionary:
	var all_data: Dictionary = get_all_creatures()
	if all_data.has(creature_id):
		return all_data[creature_id]
	return all_data[CREATURE_ORDER[0]]


static func get_creature_stats(creature_id: String, level: int = 1, lab_level: int = 1) -> Dictionary:
	var base: Dictionary = get_creature(creature_id).duplicate(true)
	var lv: int = clampi(level, 1, MAX_CREATURE_LEVEL)
	var bonus_steps: int = lv - 1
	var lab_mult: float = maxf(0.5, 1.0 - float(clampi(lab_level, 1, 5)) * 0.05)

	var base_cd: float = maxf(6.0, float(base["cooldown"]) - float(bonus_steps) * 1.0)
	base["cooldown"] = snappedf(base_cd * lab_mult, 0.5)
	base["level"] = lv

	match creature_id:
		"flame_golem":
			base["attack_mult"] = 1.4 + 0.05 * float(bonus_steps)
		"aqua_spirit":
			base["instant_heal"] = 6 + bonus_steps
		"forest_guardian":
			base["production_mult"] = 2.0 + 0.15 * float(bonus_steps)
		"stone_titan":
			base["defense_mult"] = 1.5 + 0.08 * float(bonus_steps)

	return base


static func get_skill_description(creature_id: String, level: int) -> String:
	var stats: Dictionary = get_creature_stats(creature_id, level, 1)
	var cd_val: int = roundi(float(stats["cooldown"]))
	match creature_id:
		"flame_golem":
			var atk_pct: int = roundi((float(stats["attack_mult"]) - 1.0) * 100.0)
			return "%s: +%d%% Attack for %ds (CD: %ds)" % [stats["skill_name"], atk_pct, int(stats["duration"]), cd_val]
		"aqua_spirit":
			return "%s: Heal +%d Troops to all PLAYER bases (CD: %ds)" % [stats["skill_name"], int(stats["instant_heal"]), cd_val]
		"forest_guardian":
			return "%s: %.2fx Troop Production for %ds (CD: %ds)" % [stats["skill_name"], float(stats["production_mult"]), int(stats["duration"]), cd_val]
		"stone_titan":
			var def_pct: int = roundi((float(stats["defense_mult"]) - 1.0) * 100.0)
			return "%s: +%d%% Defense for %ds (CD: %ds)" % [stats["skill_name"], def_pct, int(stats["duration"]), cd_val]
		_:
			return ""


static func get_upgrade_cost(current_level: int) -> int:
	if current_level >= MAX_CREATURE_LEVEL:
		return -1
	var idx: int = clampi(current_level - 1, 0, UPGRADE_COSTS.size() - 1)
	return UPGRADE_COSTS[idx]


static func get_next_creature_id(current_id: String) -> String:
	var idx: int = CREATURE_ORDER.find(current_id)
	if idx == -1:
		return CREATURE_ORDER[0]
	return CREATURE_ORDER[(idx + 1) % CREATURE_ORDER.size()]
