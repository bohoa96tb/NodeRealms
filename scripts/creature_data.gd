class_name CreatureData
extends RefCounted

enum Element { FIRE, WATER, NATURE, EARTH }

const CREATURE_ORDER := ["flame_golem", "aqua_spirit", "forest_guardian", "stone_titan"]


static func get_all_creatures() -> Dictionary:
	return {
		"flame_golem": {
			"id": "flame_golem",
			"name": "Flame Golem",
			"element": Element.FIRE,
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


static func get_next_creature_id(current_id: String) -> String:
	var idx: int = CREATURE_ORDER.find(current_id)
	if idx == -1:
		return CREATURE_ORDER[0]
	return CREATURE_ORDER[(idx + 1) % CREATURE_ORDER.size()]
