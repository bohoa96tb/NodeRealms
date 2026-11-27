class_name BaseNode
extends Area2D

signal faction_changed(node: BaseNode, old_faction: Faction, new_faction: Faction)

enum Faction { NEUTRAL, PLAYER, ENEMY }

const RADIUS: float = 42.0
const BOSS_RADIUS: float = 56.0
const BASE_MAX_TROOPS: int = 50
const BOSS_MAX_TROOPS: int = 80
const BOSS_PRODUCTION_RATE: float = 0.85
const BOSS_POWER_MULTIPLIER: float = 1.15

const ISLAND_SCALE_NORMAL := Vector2(0.64, 0.64)
const ISLAND_SCALE_BOSS := Vector2(0.72, 0.72)

const COLOR_PLAYER_FILL := Color(0.18, 0.525, 0.871, 1.0)
const COLOR_PLAYER_RIM := Color(0.45, 0.78, 1.0, 1.0)
const COLOR_ENEMY_FILL := Color(0.86, 0.25, 0.27, 1.0)
const COLOR_ENEMY_RIM := Color(1.0, 0.52, 0.52, 1.0)
const COLOR_NEUTRAL_FILL := Color(0.36, 0.41, 0.45, 1.0)
const COLOR_NEUTRAL_RIM := Color(0.62, 0.72, 0.76, 1.0)

const COLOR_SELECTED_GLOW := Color(1.0, 0.90, 0.42, 0.98)
const COLOR_VALID_TARGET := Color(0.33, 0.95, 0.78, 0.88)
const COLOR_HOVERED_TARGET := Color(1.0, 1.0, 1.0, 0.98)
const COLOR_PORTAL_ORCHID := Color.MEDIUM_ORCHID
const COLOR_PORTAL_CYAN := Color.CYAN
const COLOR_BOSS_CRIMSON := Color(0.92, 0.16, 0.38, 1.0)
const COLOR_BOSS_PURPLE := Color(0.66, 0.18, 0.86, 1.0)

@export var tex_neutral: Texture2D
@export var tex_player: Texture2D
@export var tex_enemy: Texture2D
@export var tex_boss: Texture2D

@export var node_id: int = 0
@export var faction: Faction = Faction.NEUTRAL:
	set(value):
		if faction != value:
			var prev_faction: Faction = faction
			faction = value
			_update_effective_max_troops()
			_refresh_visuals()
			if is_inside_tree():
				faction_changed.emit(self, prev_faction, faction)
@export var troops: float = 10.0:
	set(value):
		troops = maxf(0.0, value)
		_update_troop_label()
		queue_redraw()
@export var max_troops: int = 50
@export var production_rate: float = 0.5
@export var power_multiplier: float = 1.0
@export var is_boss_node: bool = false:
	set(value):
		if is_boss_node != value:
			is_boss_node = value
			_apply_boss_state()
@export var connected_nodes: Array[BaseNode] = []
@export var portal_nodes: Array[BaseNode] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var portal_ring_sprite: Sprite2D = $PortalRingSprite
@onready var reticle_sprite: Sprite2D = $ReticleSprite
@onready var island_sprite: Sprite2D = $IslandSprite
@onready var troop_label: Label = $TroopLabel
@onready var boss_label: Label = $BossLabel

var creature_manager: CreatureManager = null
var barracks_bonus: int = 0:
	set(value):
		barracks_bonus = maxi(0, value)
		_update_effective_max_troops()
		queue_redraw()

var is_boss_charging: bool = false:
	set(value):
		is_boss_charging = value
		queue_redraw()

var is_selected: bool = false:
	set(value):
		if is_selected != value:
			is_selected = value
			_refresh_selection_visuals()
			queue_redraw()

var is_valid_target: bool = false:
	set(value):
		if is_valid_target != value:
			is_valid_target = value
			_refresh_selection_visuals()
			queue_redraw()

var is_hovered_target: bool = false:
	set(value):
		if is_hovered_target != value:
			is_hovered_target = value
			_refresh_selection_visuals()
			queue_redraw()

var _is_mouse_over: bool = false
var _portal_angle: float = 0.0
var _reticle_angle: float = 0.0
var _target_pulse: float = 0.0
var _boss_angle: float = 0.0
var _boss_charge_pulse: float = 0.0
var _buff_pulse: float = 0.0
var _burst_progress: float = 1.0
var _burst_color: Color = Color.WHITE
var _impact_flash: float = 0.0
var _pulse_tween: Tween
var _burst_tween: Tween
var _flash_tween: Tween
var _label_tween: Tween


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if troop_label:
		troop_label.pivot_offset = troop_label.size * 0.5
	_apply_boss_state()
	_refresh_visuals()
	_refresh_selection_visuals()


func _exit_tree() -> void:
	_kill_all_tweens()


func _process(delta: float) -> void:
	var needs_redraw: bool = false

	if faction == Faction.PLAYER or faction == Faction.ENEMY:
		if troops < float(max_troops):
			var prod_mult: float = 1.0
			if faction == Faction.PLAYER and creature_manager != null and is_instance_valid(creature_manager):
				prod_mult = creature_manager.get_production_mult()
			troops = minf(float(max_troops), troops + production_rate * prod_mult * delta)

	var portal_active: bool = has_portal()
	if portal_ring_sprite:
		portal_ring_sprite.visible = portal_active
	if portal_active:
		_portal_angle = fmod(_portal_angle + delta * 1.4, TAU)
		if portal_ring_sprite:
			portal_ring_sprite.rotation = _portal_angle
			var ring_scale: float = 0.56 if is_boss_node else 0.46
			portal_ring_sprite.scale = Vector2(ring_scale, ring_scale)
		needs_redraw = true

	if is_selected or is_hovered_target or is_valid_target:
		_reticle_angle = fmod(_reticle_angle + delta * (1.8 if is_selected else -1.2), TAU)
		_target_pulse = fmod(_target_pulse + delta * 6.0, TAU)
		if reticle_sprite and reticle_sprite.visible:
			reticle_sprite.rotation = _reticle_angle
			var base_s: float = 0.64 if is_boss_node else 0.54
			var pulse_s: float = base_s + (0.03 * sin(_target_pulse) if is_hovered_target or is_selected else 0.0)
			reticle_sprite.scale = Vector2(pulse_s, pulse_s)
		needs_redraw = true

	if is_boss_node:
		_boss_angle = fmod(_boss_angle + delta * 0.9, TAU)
		if is_boss_charging:
			_boss_charge_pulse = fmod(_boss_charge_pulse + delta * 12.0, TAU)
		needs_redraw = true

	if _is_player_buff_active():
		_buff_pulse = fmod(_buff_pulse + delta * 5.0, TAU)
		needs_redraw = true

	if _burst_progress < 1.0 or _impact_flash > 0.01:
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	var rad: float = get_visual_radius()
	var rim_color: Color = _get_rim_color()
	var core_center := Vector2(0.0, -5.0)

	# Boss outer energy crown & charging telegraph
	if is_boss_node:
		var spike_count: int = 8
		for i in range(spike_count):
			var ang: float = _boss_angle + float(i) * TAU / float(spike_count)
			var perp: Vector2 = Vector2.from_angle(ang + PI * 0.5)
			var base_center: Vector2 = Vector2.from_angle(ang) * (rad + 4.0)
			var tip: Vector2 = Vector2.from_angle(ang) * (rad + 18.0)
			var col: Color = COLOR_BOSS_CRIMSON if (i % 2 == 0) else COLOR_BOSS_PURPLE
			draw_colored_polygon(PackedVector2Array([tip, base_center + perp * 5.5, base_center - perp * 5.5]), col)

		if is_boss_charging:
			var warn_alpha: float = 0.5 + 0.5 * sin(_boss_charge_pulse)
			draw_arc(Vector2.ZERO, rad + 22.0, 0.0, TAU, 56, Color(1.0, 0.25, 0.30, warn_alpha), 4.5, true)

	# Active creature buff glow ring for PLAYER nodes
	if _is_player_buff_active():
		var creature: Dictionary = creature_manager.get_equipped_creature()
		var glow_col: Color = creature["color"]
		var border_col: Color = creature["border_color"]
		var pulse_alpha: float = 0.55 + 0.35 * sin(_buff_pulse)
		draw_circle(core_center, rad * 0.65, Color(glow_col.r, glow_col.g, glow_col.b, 0.16 * pulse_alpha))
		draw_arc(core_center, rad + 3.0, 0.0, TAU, 48, Color(border_col.r, border_col.g, border_col.b, pulse_alpha), 3.0, true)

	# Selection / target highlight rings around the citadel core
	if is_selected:
		var sel_alpha: float = 0.8 + 0.2 * sin(_target_pulse)
		draw_arc(Vector2.ZERO, rad + 6.0, 0.0, TAU, 48, Color(COLOR_SELECTED_GLOW.r, COLOR_SELECTED_GLOW.g, COLOR_SELECTED_GLOW.b, sel_alpha), 3.5, true)
	elif is_hovered_target:
		var hov_alpha: float = 0.85 + 0.15 * sin(_target_pulse)
		draw_arc(Vector2.ZERO, rad + 7.0, 0.0, TAU, 48, Color(COLOR_HOVERED_TARGET.r, COLOR_HOVERED_TARGET.g, COLOR_HOVERED_TARGET.b, hov_alpha), 3.5, true)
		draw_arc(Vector2.ZERO, rad + 2.5, 0.0, TAU, 40, COLOR_VALID_TARGET, 2.5, true)
	elif is_valid_target:
		var tgt_alpha: float = 0.55 + 0.30 * sin(_target_pulse)
		draw_arc(Vector2.ZERO, rad + 4.5, 0.0, TAU, 44, Color(COLOR_VALID_TARGET.r, COLOR_VALID_TARGET.g, COLOR_VALID_TARGET.b, tgt_alpha), 2.5, true)
	elif _is_mouse_over and faction == Faction.PLAYER:
		draw_arc(Vector2.ZERO, rad + 4.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.45), 2.0, true)

	# Capacity progress arc around the inner central medallion
	if max_troops > 0:
		var fill_ratio: float = clampf(troops / float(max_troops), 0.0, 1.0)
		if fill_ratio > 0.01:
			var arc_r: float = rad * (0.50 if is_boss_node else 0.56)
			var start_angle: float = -PI * 0.5
			var end_angle: float = start_angle + TAU * fill_ratio
			draw_arc(core_center, arc_r, start_angle, end_angle, 36, Color(rim_color.r, rim_color.g, rim_color.b, 0.82), 3.0, true)

	# Impact white flash when hit by hostile army
	if _impact_flash > 0.01:
		draw_circle(core_center, rad * 0.78, Color(1.0, 1.0, 1.0, _impact_flash * 0.60))

	# Skill / Capture expanding shockwave ripple
	if _burst_progress < 1.0:
		var ripple_r: float = rad + _burst_progress * 40.0
		var ripple_alpha: float = (1.0 - _burst_progress) * 0.92
		draw_arc(Vector2.ZERO, ripple_r, 0.0, TAU, 48, Color(_burst_color.r, _burst_color.g, _burst_color.b, ripple_alpha), 4.0, true)


func get_visual_radius() -> float:
	return BOSS_RADIUS if is_boss_node else RADIUS


func get_faction_color(target_faction: Faction) -> Color:
	match target_faction:
		Faction.PLAYER:
			return COLOR_PLAYER_RIM
		Faction.ENEMY:
			return COLOR_ENEMY_RIM
		_:
			return COLOR_NEUTRAL_RIM


func extract_troops(ratio: float) -> int:
	var available: int = floori(troops)
	if available <= 0:
		return 0
	var amount: int = floori(float(available) * ratio)
	if amount <= 0 and ratio > 0.0:
		amount = 1
	amount = mini(amount, available)
	troops -= float(amount)
	play_pulse(0.92)
	return amount


func receive_heal(amount: int, burst_color: Color) -> void:
	if amount <= 0:
		return
	troops = minf(float(max_troops), troops + float(amount))
	play_pulse(1.18)
	trigger_skill_burst(burst_color)


func trigger_skill_burst(burst_color: Color) -> void:
	if not is_inside_tree():
		return
	_burst_color = burst_color
	_burst_progress = 0.0
	if _burst_tween and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_property(self, "_burst_progress", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	queue_redraw()


func trigger_impact_flash() -> void:
	if not is_inside_tree():
		return
	_impact_flash = 1.0
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "_impact_flash", 0.0, 0.16).set_ease(Tween.EASE_OUT)

	if troop_label:
		if _label_tween and _label_tween.is_valid():
			_label_tween.kill()
		troop_label.scale = Vector2(1.36, 1.36)
		_label_tween = create_tween()
		_label_tween.tween_property(troop_label, "scale", Vector2.ONE, 0.16).set_ease(Tween.EASE_OUT)
	queue_redraw()


func receive_army(incoming_faction: Faction, incoming_troops: int, attack_mult: float) -> void:
	if incoming_troops <= 0:
		return

	if incoming_faction == faction:
		troops = minf(float(max_troops), troops + float(incoming_troops))
		play_pulse(1.12)
		return

	trigger_impact_flash()

	var defense_mult: float = power_multiplier
	if faction == Faction.PLAYER and creature_manager != null and is_instance_valid(creature_manager):
		defense_mult *= creature_manager.get_defense_mult()

	var attack_power: float = float(incoming_troops) * attack_mult
	var defense_power: float = troops * defense_mult

	if attack_power > defense_power:
		var winner_mult: float = maxf(0.01, attack_mult)
		var remaining: float = absf(attack_power - defense_power) / winner_mult
		if is_boss_node and incoming_faction != Faction.ENEMY:
			is_boss_node = false
			is_boss_charging = false
		faction = incoming_faction
		troops = minf(float(max_troops), remaining)
		play_pulse(1.22)
		trigger_skill_burst(get_faction_color(faction))
	else:
		var winner_mult: float = maxf(0.01, defense_mult)
		var remaining: float = absf(attack_power - defense_power) / winner_mult
		troops = remaining
		play_pulse(0.92)


func has_portal() -> bool:
	return not portal_nodes.is_empty()


func is_connected_to(other: BaseNode) -> bool:
	return other != null and (other in connected_nodes or other in portal_nodes)


func is_portal_connected_to(other: BaseNode) -> bool:
	return other != null and other in portal_nodes


func get_all_reachable_nodes() -> Array[BaseNode]:
	var result: Array[BaseNode] = []
	for n in connected_nodes:
		if is_instance_valid(n) and not result.has(n):
			result.append(n)
	for p in portal_nodes:
		if is_instance_valid(p) and not result.has(p):
			result.append(p)
	return result


func play_pulse(peak_scale: float = 1.15) -> void:
	if not is_inside_tree():
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), 0.08).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT)


func _kill_all_tweens() -> void:
	for tw in [_pulse_tween, _burst_tween, _flash_tween, _label_tween]:
		if tw != null and tw.is_valid():
			tw.kill()
	_pulse_tween = null
	_burst_tween = null
	_flash_tween = null
	_label_tween = null


func _apply_boss_state() -> void:
	if is_boss_node:
		production_rate = BOSS_PRODUCTION_RATE
		power_multiplier = BOSS_POWER_MULTIPLIER
	else:
		production_rate = 0.5
		power_multiplier = 1.0

	_update_effective_max_troops()

	if collision_shape and collision_shape.shape is CircleShape2D:
		var new_circle := CircleShape2D.new()
		new_circle.radius = (BOSS_RADIUS + 2.0) if is_boss_node else (RADIUS + 2.0)
		collision_shape.shape = new_circle

	if boss_label:
		boss_label.visible = is_boss_node

	_refresh_island_sprite()
	queue_redraw()


func _is_player_buff_active() -> bool:
	return faction == Faction.PLAYER and creature_manager != null and is_instance_valid(creature_manager) and creature_manager.is_skill_active()


func _refresh_visuals() -> void:
	_update_effective_max_troops()
	_update_troop_label()
	_refresh_island_sprite()
	queue_redraw()


func _refresh_island_sprite() -> void:
	if island_sprite == null:
		return
	if is_boss_node:
		island_sprite.texture = tex_boss if tex_boss != null else tex_enemy
		island_sprite.scale = ISLAND_SCALE_BOSS
		island_sprite.position = Vector2(0.0, 2.0)
	else:
		island_sprite.scale = ISLAND_SCALE_NORMAL
		island_sprite.position = Vector2(0.0, 2.0)
		match faction:
			Faction.PLAYER:
				island_sprite.texture = tex_player
			Faction.ENEMY:
				island_sprite.texture = tex_enemy
			_:
				island_sprite.texture = tex_neutral


func _refresh_selection_visuals() -> void:
	if reticle_sprite == null:
		return
	if is_selected:
		reticle_sprite.visible = true
		reticle_sprite.modulate = COLOR_SELECTED_GLOW
	elif is_hovered_target:
		reticle_sprite.visible = true
		reticle_sprite.modulate = Color(0.55, 1.0, 0.88, 1.0)
	elif is_valid_target:
		reticle_sprite.visible = true
		reticle_sprite.modulate = Color(0.35, 0.92, 0.78, 0.65)
	else:
		reticle_sprite.visible = false


func _update_effective_max_troops() -> void:
	if is_boss_node:
		max_troops = BOSS_MAX_TROOPS
	else:
		max_troops = BASE_MAX_TROOPS + (barracks_bonus if faction == Faction.PLAYER else 0)


func _update_troop_label() -> void:
	if troop_label:
		troop_label.text = str(floori(troops))


func _get_rim_color() -> Color:
	match faction:
		Faction.PLAYER:
			return COLOR_PLAYER_RIM
		Faction.ENEMY:
			return COLOR_ENEMY_RIM
		_:
			return COLOR_NEUTRAL_RIM


func _on_mouse_entered() -> void:
	_is_mouse_over = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_mouse_over = false
	queue_redraw()
