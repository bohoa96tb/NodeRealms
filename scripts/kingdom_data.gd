class_name KingdomData
extends RefCounted

const BUILDING_ORDER := ["castle", "gold_mine", "barracks", "laboratory", "habitat"]
const MAX_BUILDING_LEVEL: int = 5
const UPGRADE_COSTS := [100, 200, 350, 550]
const GOLD_MINE_RATE_PER_MIN: int = 10
const GOLD_MINE_MAX_HOURS: int = 4


static func get_all_buildings() -> Dictionary:
	return {
		"castle": {
			"id": "castle",
			"name": "Castle",
			"color": Color(0.45, 0.72, 1.0, 1.0),
			"summary": "Heart of your realm. Required level >= other buildings.",
		},
		"gold_mine": {
			"id": "gold_mine",
			"name": "Gold Mine",
			"color": Color(1.0, 0.80, 0.25, 1.0),
			"summary": "Produces passive Gold (+10/min per level, 4h cap).",
		},
		"barracks": {
			"id": "barracks",
			"name": "Barracks",
			"color": Color(0.92, 0.42, 0.34, 1.0),
			"summary": "Boosts PLAYER base max capacity (+3 max troops per level).",
		},
		"laboratory": {
			"id": "laboratory",
			"name": "Laboratory",
			"color": Color(0.68, 0.46, 0.96, 1.0),
			"summary": "Reduces creature skill cooldown (-5% per level).",
		},
		"habitat": {
			"id": "habitat",
			"name": "Creature Habitat",
			"color": Color(0.28, 0.86, 0.62, 1.0),
			"summary": "Increases campaign Essence rewards (+5% per level).",
		},
	}


static func get_building(building_id: String) -> Dictionary:
	var all_buildings: Dictionary = get_all_buildings()
	if all_buildings.has(building_id):
		return all_buildings[building_id]
	return all_buildings[BUILDING_ORDER[0]]


static func get_upgrade_cost(current_level: int) -> int:
	if current_level >= MAX_BUILDING_LEVEL:
		return -1
	var idx: int = clampi(current_level - 1, 0, UPGRADE_COSTS.size() - 1)
	return UPGRADE_COSTS[idx]


static func get_effect_text(building_id: String, level: int) -> String:
	var lv: int = clampi(level, 1, MAX_BUILDING_LEVEL)
	match building_id:
		"castle":
			return "Unlocks upgrades up to LV %d for all buildings" % lv
		"gold_mine":
			return "Income: +%d Gold/min (Max %d Gold)" % [lv * GOLD_MINE_RATE_PER_MIN, lv * GOLD_MINE_RATE_PER_MIN * 60 * GOLD_MINE_MAX_HOURS]
		"barracks":
			return "PLAYER Base Cap: +%d Max Troops" % (lv * 3)
		"laboratory":
			return "Skill Cooldown: -%d%%" % (lv * 5)
		"habitat":
			return "Victory Essence: +%d%%" % (lv * 5)
		_:
			return ""
