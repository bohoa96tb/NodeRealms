extends Node

const SAVE_PATH := "user://node_realms_save.json"
const CURRENT_VERSION: int = 1
const MAX_CAMPAIGN_LEVEL: int = 15

var data: Dictionary = {}

# Runtime navigation state passed between CampaignScene and BattleScene
var is_campaign: bool = false
var current_level_id: int = 1


func _ready() -> void:
	load_game()


func start_campaign_level(level_id: int) -> void:
	is_campaign = true
	current_level_id = clampi(level_id, 1, MAX_CAMPAIGN_LEVEL)


func start_sandbox_mode() -> void:
	is_campaign = false
	current_level_id = 1


func load_game() -> void:
	var defaults: Dictionary = _get_default_data()
	if not FileAccess.file_exists(SAVE_PATH):
		data = defaults
		save_game()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: Could not open save file, restoring defaults.")
		data = defaults
		save_game()
		return

	var raw_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(raw_text)
	if err != OK or not (json.data is Dictionary):
		push_warning("SaveManager: Corrupted save JSON, restoring defaults.")
		data = defaults
		save_game()
		return

	data = _sanitize_loaded_data(json.data as Dictionary, defaults)


func save_game() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Failed to write save file.")
		return false

	var json_text: String = JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()
	return true


func get_gold() -> int:
	return int(data["player"]["gold"])


func get_essence() -> int:
	return int(data["player"]["essence"])


func get_unlocked_level() -> int:
	return clampi(int(data["campaign"]["unlocked_level"]), 1, MAX_CAMPAIGN_LEVEL)


func is_level_completed(level_id: int) -> bool:
	var completed: Array = data["campaign"]["completed_levels"]
	for item in completed:
		if int(item) == level_id:
			return true
	return false


func get_equipped_creature() -> String:
	var equipped: String = str(data["creatures"]["equipped"])
	var owned: Array = data["creatures"]["owned"]
	if owned.has(equipped):
		return equipped
	return "flame_golem"


func set_equipped_creature(creature_id: String) -> void:
	var owned: Array = data["creatures"]["owned"]
	if not owned.has(creature_id):
		owned.append(creature_id)
	data["creatures"]["equipped"] = creature_id
	save_game()


func record_campaign_victory(level_id: int, gold_earned: int, essence_earned: int) -> void:
	data["player"]["gold"] = int(data["player"]["gold"]) + maxi(0, gold_earned)
	data["player"]["essence"] = int(data["player"]["essence"]) + maxi(0, essence_earned)

	if not is_level_completed(level_id):
		var completed: Array = data["campaign"]["completed_levels"]
		completed.append(level_id)

	var current_unlocked: int = get_unlocked_level()
	var next_unlock: int = clampi(level_id + 1, 1, MAX_CAMPAIGN_LEVEL)
	if next_unlock > current_unlocked:
		data["campaign"]["unlocked_level"] = next_unlock

	_increment_win_stats()
	save_game()


func record_sandbox_victory() -> void:
	_increment_win_stats()
	save_game()


func record_defeat() -> void:
	data["statistics"]["losses"] = int(data["statistics"]["losses"]) + 1
	data["statistics"]["current_streak"] = 0
	save_game()


func _increment_win_stats() -> void:
	data["statistics"]["wins"] = int(data["statistics"]["wins"]) + 1
	var streak: int = int(data["statistics"]["current_streak"]) + 1
	data["statistics"]["current_streak"] = streak
	if streak > int(data["statistics"]["best_streak"]):
		data["statistics"]["best_streak"] = streak


func _sanitize_loaded_data(loaded: Dictionary, defaults: Dictionary) -> Dictionary:
	var result: Dictionary = defaults.duplicate(true)
	result["version"] = CURRENT_VERSION

	if loaded.get("player") is Dictionary:
		var p: Dictionary = loaded["player"]
		result["player"]["level"] = maxi(1, int(p.get("level", 1)))
		result["player"]["gold"] = maxi(0, int(p.get("gold", 100)))
		result["player"]["essence"] = maxi(0, int(p.get("essence", 0)))

	if loaded.get("campaign") is Dictionary:
		var c: Dictionary = loaded["campaign"]
		result["campaign"]["unlocked_level"] = clampi(int(c.get("unlocked_level", 1)), 1, MAX_CAMPAIGN_LEVEL)
		var clean_completed: Array = []
		if c.get("completed_levels") is Array:
			for lvl in c["completed_levels"]:
				var lvl_int: int = int(lvl)
				if lvl_int >= 1 and lvl_int <= MAX_CAMPAIGN_LEVEL and not clean_completed.has(lvl_int):
					clean_completed.append(lvl_int)
		result["campaign"]["completed_levels"] = clean_completed

	if loaded.get("creatures") is Dictionary:
		var cr: Dictionary = loaded["creatures"]
		if cr.get("owned") is Array and not (cr["owned"] as Array).is_empty():
			var clean_owned: Array = []
			for cid in cr["owned"]:
				clean_owned.append(str(cid))
			result["creatures"]["owned"] = clean_owned
		var eq: String = str(cr.get("equipped", "flame_golem"))
		if (result["creatures"]["owned"] as Array).has(eq):
			result["creatures"]["equipped"] = eq

	if loaded.get("kingdom") is Dictionary:
		var k: Dictionary = loaded["kingdom"]
		if k.get("buildings") is Dictionary:
			result["kingdom"]["buildings"] = k["buildings"].duplicate(true)
		if k.get("decorations") is Array:
			result["kingdom"]["decorations"] = k["decorations"].duplicate(true)

	if loaded.get("statistics") is Dictionary:
		var s: Dictionary = loaded["statistics"]
		result["statistics"]["wins"] = maxi(0, int(s.get("wins", 0)))
		result["statistics"]["losses"] = maxi(0, int(s.get("losses", 0)))
		result["statistics"]["best_streak"] = maxi(0, int(s.get("best_streak", 0)))
		result["statistics"]["current_streak"] = maxi(0, int(s.get("current_streak", 0)))

	return result


func _get_default_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"player": {
			"level": 1,
			"gold": 100,
			"essence": 0,
		},
		"campaign": {
			"unlocked_level": 1,
			"completed_levels": [],
		},
		"creatures": {
			"owned": ["flame_golem", "aqua_spirit", "forest_guardian", "stone_titan"],
			"equipped": "flame_golem",
		},
		"kingdom": {
			"buildings": {},
			"decorations": [],
		},
		"statistics": {
			"wins": 0,
			"losses": 0,
			"best_streak": 0,
			"current_streak": 0,
		},
	}
