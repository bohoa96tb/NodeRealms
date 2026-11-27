extends Node

const SAVE_PATH := "user://node_realms_save.json"
const CURRENT_VERSION: int = 1
const MAX_CAMPAIGN_LEVEL: int = 15

var data: Dictionary = {}

# Runtime navigation state passed between MainHubScene and BattleScene
var is_campaign: bool = false
var is_boss_test: bool = false
var current_level_id: int = 1
var last_hub_tab: int = 0


func _ready() -> void:
	load_game()


func start_campaign_level(level_id: int) -> void:
	is_campaign = true
	is_boss_test = false
	current_level_id = clampi(level_id, 1, MAX_CAMPAIGN_LEVEL)


func start_sandbox_mode() -> void:
	is_campaign = false
	is_boss_test = false
	current_level_id = 1


func start_boss_test() -> void:
	is_campaign = false
	is_boss_test = true
	current_level_id = 15


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


func is_sfx_enabled() -> bool:
	var settings: Dictionary = data.get("settings", {})
	return bool(settings.get("sfx_enabled", true))


func set_sfx_enabled(enabled: bool) -> void:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	data["settings"]["sfx_enabled"] = enabled
	save_game()


func is_tutorial_completed() -> bool:
	var settings: Dictionary = data.get("settings", {})
	return bool(settings.get("tutorial_completed", false))


func set_tutorial_completed(completed: bool) -> void:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	data["settings"]["tutorial_completed"] = completed
	save_game()


func is_portal_hint_seen() -> bool:
	var settings: Dictionary = data.get("settings", {})
	return bool(settings.get("portal_hint_seen", false))


func set_portal_hint_seen(seen: bool) -> void:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	data["settings"]["portal_hint_seen"] = seen
	save_game()


func complete_all_tutorials() -> void:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	data["settings"]["tutorial_completed"] = true
	data["settings"]["portal_hint_seen"] = true
	save_game()


func spend_gold(amount: int) -> bool:
	if amount < 0 or get_gold() < amount:
		return false
	data["player"]["gold"] = get_gold() - amount
	save_game()
	return true


func spend_essence(amount: int) -> bool:
	if amount < 0 or get_essence() < amount:
		return false
	data["player"]["essence"] = get_essence() - amount
	save_game()
	return true


func get_unlocked_level() -> int:
	return clampi(int(data["campaign"]["unlocked_level"]), 1, MAX_CAMPAIGN_LEVEL)


func get_completed_levels_count() -> int:
	var completed: Array = data["campaign"]["completed_levels"]
	return completed.size()


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


func get_creature_level(creature_id: String) -> int:
	var levels: Dictionary = data["creatures"]["levels"]
	return clampi(int(levels.get(creature_id, 1)), 1, CreatureData.MAX_CREATURE_LEVEL)


func upgrade_creature(creature_id: String) -> bool:
	var current_lv: int = get_creature_level(creature_id)
	if current_lv >= CreatureData.MAX_CREATURE_LEVEL:
		return false
	var cost: int = CreatureData.get_upgrade_cost(current_lv)
	if cost < 0 or not spend_essence(cost):
		return false
	data["creatures"]["levels"][creature_id] = current_lv + 1
	save_game()
	return true


func get_building_level(building_id: String) -> int:
	var buildings: Dictionary = data["kingdom"]["buildings"]
	return clampi(int(buildings.get(building_id, 1)), 1, KingdomData.MAX_BUILDING_LEVEL)


func can_upgrade_building(building_id: String) -> Dictionary:
	var current_lv: int = get_building_level(building_id)
	if current_lv >= KingdomData.MAX_BUILDING_LEVEL:
		return {"ok": false, "reason": "MAX"}

	if building_id != "castle":
		var castle_lv: int = get_building_level("castle")
		if current_lv >= castle_lv:
			return {"ok": false, "reason": "Need Castle LV %d" % (current_lv + 1)}

	var cost: int = KingdomData.get_upgrade_cost(current_lv)
	if get_gold() < cost:
		return {"ok": false, "reason": "Need %d Gold" % cost}

	return {"ok": true, "reason": ""}


func upgrade_building(building_id: String) -> bool:
	var check: Dictionary = can_upgrade_building(building_id)
	if not check["ok"]:
		return false

	# Claim pending Gold Mine income before changing mine level
	if building_id == "gold_mine":
		claim_mine_gold()

	var current_lv: int = get_building_level(building_id)
	var cost: int = KingdomData.get_upgrade_cost(current_lv)
	if cost < 0 or not spend_gold(cost):
		return false

	data["kingdom"]["buildings"][building_id] = current_lv + 1
	if building_id == "castle":
		data["player"]["level"] = current_lv + 1
	save_game()
	return true


func get_pending_mine_gold() -> int:
	var mine_lv: int = get_building_level("gold_mine")
	var now: int = int(Time.get_unix_time_from_system())
	var last_claim: int = int(data["kingdom"].get("last_claim_time", now))
	var max_seconds: int = KingdomData.GOLD_MINE_MAX_HOURS * 3600
	var elapsed: int = clampi(now - last_claim, 0, max_seconds)
	var gold_per_sec: float = float(mine_lv * KingdomData.GOLD_MINE_RATE_PER_MIN) / 60.0
	return floori(float(elapsed) * gold_per_sec)


func claim_mine_gold() -> int:
	var pending: int = get_pending_mine_gold()
	var now: int = int(Time.get_unix_time_from_system())
	data["kingdom"]["last_claim_time"] = now
	if pending > 0:
		data["player"]["gold"] = get_gold() + pending
	save_game()
	return pending


func get_barracks_max_troops_bonus() -> int:
	return get_building_level("barracks") * 3


func get_habitat_essence_bonus_ratio() -> float:
	return float(get_building_level("habitat")) * 0.05


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

	var level_info: Dictionary = CampaignData.get_level(level_id)
	if bool(level_info.get("is_boss", false)):
		_increment_boss_victory()

	_increment_win_stats()
	save_game()


func record_sandbox_victory() -> void:
	_increment_win_stats()
	save_game()


func record_boss_victory() -> void:
	_increment_boss_victory()
	_increment_win_stats()
	save_game()


func record_defeat() -> void:
	if not (data.get("statistics") is Dictionary):
		data["statistics"] = {}
	data["statistics"]["losses"] = int(data["statistics"].get("losses", 0)) + 1
	data["statistics"]["current_streak"] = 0
	save_game()


func get_statistics() -> Dictionary:
	var stats: Dictionary = data.get("statistics", {})
	var wins: int = maxi(0, int(stats.get("wins", 0)))
	var losses: int = maxi(0, int(stats.get("losses", 0)))
	var current_streak: int = maxi(0, int(stats.get("current_streak", 0)))
	var best_streak: int = maxi(current_streak, int(stats.get("best_streak", 0)))
	var boss_victories: int = maxi(0, int(stats.get("boss_victories", 0)))
	return {
		"wins": wins,
		"losses": losses,
		"total_battles": wins + losses,
		"current_streak": current_streak,
		"best_streak": best_streak,
		"boss_victories": boss_victories,
		"campaign_completed": get_completed_levels_count(),
		"campaign_total": MAX_CAMPAIGN_LEVEL,
		"unlocked_level": get_unlocked_level(),
	}


func _increment_win_stats() -> void:
	if not (data.get("statistics") is Dictionary):
		data["statistics"] = {}
	data["statistics"]["wins"] = int(data["statistics"].get("wins", 0)) + 1
	var streak: int = int(data["statistics"].get("current_streak", 0)) + 1
	data["statistics"]["current_streak"] = streak
	if streak > int(data["statistics"].get("best_streak", 0)):
		data["statistics"]["best_streak"] = streak


func _increment_boss_victory() -> void:
	if not (data.get("statistics") is Dictionary):
		data["statistics"] = {}
	data["statistics"]["boss_victories"] = int(data["statistics"].get("boss_victories", 0)) + 1


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
		if cr.get("levels") is Dictionary:
			var loaded_levels: Dictionary = cr["levels"]
			for cid in CreatureData.CREATURE_ORDER:
				result["creatures"]["levels"][cid] = clampi(int(loaded_levels.get(cid, 1)), 1, CreatureData.MAX_CREATURE_LEVEL)

	if loaded.get("kingdom") is Dictionary:
		var k: Dictionary = loaded["kingdom"]
		if k.get("buildings") is Dictionary:
			var loaded_buildings: Dictionary = k["buildings"]
			for bid in KingdomData.BUILDING_ORDER:
				result["kingdom"]["buildings"][bid] = clampi(int(loaded_buildings.get(bid, 1)), 1, KingdomData.MAX_BUILDING_LEVEL)
		if k.get("decorations") is Array:
			result["kingdom"]["decorations"] = k["decorations"].duplicate(true)
		var claim_ts: int = int(k.get("last_claim_time", 0))
		if claim_ts > 0:
			result["kingdom"]["last_claim_time"] = claim_ts

	if loaded.get("statistics") is Dictionary:
		var s: Dictionary = loaded["statistics"]
		var wins: int = maxi(0, int(s.get("wins", 0)))
		var losses: int = maxi(0, int(s.get("losses", 0)))
		var current_streak: int = maxi(0, int(s.get("current_streak", 0)))
		var best_streak: int = maxi(current_streak, int(s.get("best_streak", 0)))
		var boss_victories: int = maxi(0, int(s.get("boss_victories", 0)))
		result["statistics"]["wins"] = wins
		result["statistics"]["losses"] = losses
		result["statistics"]["best_streak"] = best_streak
		result["statistics"]["current_streak"] = current_streak
		result["statistics"]["boss_victories"] = boss_victories

	if loaded.get("settings") is Dictionary:
		var st: Dictionary = loaded["settings"]
		result["settings"]["sfx_enabled"] = bool(st.get("sfx_enabled", true))
		result["settings"]["tutorial_completed"] = bool(st.get("tutorial_completed", false))
		result["settings"]["portal_hint_seen"] = bool(st.get("portal_hint_seen", false))

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
			"levels": {
				"flame_golem": 1,
				"aqua_spirit": 1,
				"forest_guardian": 1,
				"stone_titan": 1,
			},
		},
		"kingdom": {
			"buildings": {
				"castle": 1,
				"gold_mine": 1,
				"barracks": 1,
				"laboratory": 1,
				"habitat": 1,
			},
			"decorations": [],
			"last_claim_time": int(Time.get_unix_time_from_system()),
		},
		"statistics": {
			"wins": 0,
			"losses": 0,
			"best_streak": 0,
			"current_streak": 0,
			"boss_victories": 0,
		},
		"settings": {
			"sfx_enabled": true,
			"tutorial_completed": false,
			"portal_hint_seen": false,
		},
	}
