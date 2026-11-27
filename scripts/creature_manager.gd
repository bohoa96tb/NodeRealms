class_name CreatureManager
extends Node

signal skill_activated(creature: Dictionary)
signal skill_ended(creature: Dictionary)
signal cooldown_updated(remaining_cooldown: float, remaining_active: float)
signal creature_changed(creature: Dictionary)

var equipped_creature_id: String = "flame_golem"
var equipped_creature_level: int = 1
var laboratory_level: int = 1
var active_timer: float = 0.0
var cooldown_timer: float = 0.0

var _is_paused: bool = false


func _process(delta: float) -> void:
	if _is_paused:
		return

	var changed: bool = false
	var creature: Dictionary = get_equipped_creature()

	if active_timer > 0.0:
		active_timer = maxf(0.0, active_timer - delta)
		changed = true
		if active_timer <= 0.0:
			cooldown_timer = float(creature["cooldown"])
			skill_ended.emit(creature)
	elif cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)
		changed = true

	if changed:
		cooldown_updated.emit(cooldown_timer, active_timer)


func set_paused(paused: bool) -> void:
	_is_paused = paused


func sync_from_save() -> void:
	equipped_creature_id = SaveManager.get_equipped_creature()
	equipped_creature_level = SaveManager.get_creature_level(equipped_creature_id)
	laboratory_level = SaveManager.get_building_level("laboratory")


func get_equipped_creature() -> Dictionary:
	return CreatureData.get_creature_stats(equipped_creature_id, equipped_creature_level, laboratory_level)


func cycle_creature() -> Dictionary:
	equipped_creature_id = CreatureData.get_next_creature_id(equipped_creature_id)
	equipped_creature_level = SaveManager.get_creature_level(equipped_creature_id)
	laboratory_level = SaveManager.get_building_level("laboratory")
	reset_state()
	var creature: Dictionary = get_equipped_creature()
	creature_changed.emit(creature)
	return creature


func reset_state() -> void:
	var was_active: bool = active_timer > 0.0
	active_timer = 0.0
	cooldown_timer = 0.0
	if was_active:
		skill_ended.emit(get_equipped_creature())
	cooldown_updated.emit(cooldown_timer, active_timer)


func is_skill_ready() -> bool:
	return active_timer <= 0.0 and cooldown_timer <= 0.0


func is_skill_active() -> bool:
	return active_timer > 0.0


func is_element_buff_active(element: CreatureData.Element) -> bool:
	if active_timer <= 0.0:
		return false
	var creature: Dictionary = get_equipped_creature()
	return int(creature["element"]) == int(element)


func get_attack_mult() -> float:
	if active_timer <= 0.0:
		return 1.0
	return float(get_equipped_creature()["attack_mult"])


func get_defense_mult() -> float:
	if active_timer <= 0.0:
		return 1.0
	return float(get_equipped_creature()["defense_mult"])


func get_production_mult() -> float:
	if active_timer <= 0.0:
		return 1.0
	return float(get_equipped_creature()["production_mult"])


func activate_skill(player_nodes: Array[BaseNode]) -> bool:
	if not is_skill_ready():
		return false

	var creature: Dictionary = get_equipped_creature()
	var burst_color: Color = creature["color"]
	var heal_amount: int = int(creature["instant_heal"])
	var duration: float = float(creature["duration"])

	for node in player_nodes:
		if not is_instance_valid(node):
			continue
		if heal_amount > 0:
			node.receive_heal(heal_amount, burst_color)
		else:
			node.trigger_skill_burst(burst_color)

	if duration > 0.0:
		active_timer = duration
	else:
		cooldown_timer = float(creature["cooldown"])

	skill_activated.emit(creature)
	cooldown_updated.emit(cooldown_timer, active_timer)
	return true
