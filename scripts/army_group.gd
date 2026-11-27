class_name ArmyGroup
extends Area2D

signal arrived(army: ArmyGroup)

const RADIUS: float = 16.0
const PORTAL_SPEED_MULTIPLIER: float = 1.8

@export var move_speed: float = 220.0

var faction: BaseNode.Faction = BaseNode.Faction.NEUTRAL
var troops: int = 0
var power_multiplier: float = 1.0
var source_node: BaseNode = null
var target_node: BaseNode = null
var is_portal_travel: bool = false
var is_resolved: bool = false
var creature_manager: CreatureManager = null

var _move_dir: Vector2 = Vector2.RIGHT
var _warp_pulse: float = 0.0
var _fire_pulse: float = 0.0

@onready var troop_label: Label = $TroopLabel


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_update_label()
	queue_redraw()


func setup(
	from_node: BaseNode,
	to_node: BaseNode,
	troop_count: int,
	portal_travel: bool = false,
	mgr: CreatureManager = null
) -> void:
	source_node = from_node
	target_node = to_node
	faction = from_node.faction
	troops = troop_count
	power_multiplier = from_node.power_multiplier
	is_portal_travel = portal_travel
	creature_manager = mgr
	global_position = from_node.global_position
	_move_dir = (to_node.global_position - from_node.global_position).normalized()
	if troop_label:
		_update_label()
	if is_portal_travel and is_inside_tree():
		scale = Vector2(1.25, 1.25)
		modulate = Color(1.3, 1.7, 2.0, 1.0)
		var warp_tween: Tween = create_tween()
		warp_tween.set_parallel(true)
		warp_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT)
		warp_tween.tween_property(self, "modulate", Color.WHITE, 0.25).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _process(delta: float) -> void:
	if is_resolved:
		return
	if target_node == null or not is_instance_valid(target_node):
		is_resolved = true
		queue_free()
		return

	var effective_speed: float = move_speed * (PORTAL_SPEED_MULTIPLIER if is_portal_travel else 1.0)
	var to_target: Vector2 = target_node.global_position - global_position
	var distance: float = to_target.length()
	var step: float = effective_speed * delta

	if distance <= step or distance <= BaseNode.RADIUS * 0.75:
		_resolve_arrival()
		return

	_move_dir = to_target / distance
	global_position += _move_dir * step

	var needs_redraw: bool = false
	if is_portal_travel:
		_warp_pulse = fmod(_warp_pulse + delta * 12.0, TAU)
		needs_redraw = true
	if _is_fire_buff_active():
		_fire_pulse = fmod(_fire_pulse + delta * 10.0, TAU)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	var fill_color: Color = _get_fill_color()
	var rim_color: Color = _get_rim_color()
	var fire_active: bool = _is_fire_buff_active()

	# Shadow
	draw_circle(Vector2(0.0, 2.0), RADIUS + 2.0, Color(0.0, 0.0, 0.0, 0.35))

	# FIRE buff glowing aura when Blaze Surge is active on PLAYER armies
	if fire_active:
		var fire_alpha: float = 0.65 + 0.3 * sin(_fire_pulse)
		draw_circle(Vector2.ZERO, RADIUS + 7.0, Color(1.0, 0.36, 0.12, 0.28 * fire_alpha))
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 32, Color(1.0, 0.45, 0.12, fire_alpha), 3.0, true)
		rim_color = Color(1.0, 0.68, 0.28, 1.0)

	# Portal warp aura & trail while traveling across a Portal
	if is_portal_travel:
		var pulse_r: float = RADIUS + 5.0 + sin(_warp_pulse) * 1.5
		draw_line(Vector2.ZERO, -_move_dir * (RADIUS + 16.0), Color(0.0, 0.9, 1.0, 0.55), 5.0, true)
		draw_arc(Vector2.ZERO, pulse_r, 0.0, TAU, 32, Color.CYAN, 2.0, true)

	# Direction chevron ahead of the circle
	var tip: Vector2 = _move_dir * (RADIUS + 6.0)
	var perp: Vector2 = Vector2(-_move_dir.y, _move_dir.x)
	var left_pt: Vector2 = _move_dir * (RADIUS - 2.0) + perp * 6.0
	var right_pt: Vector2 = _move_dir * (RADIUS - 2.0) - perp * 6.0
	draw_colored_polygon(PackedVector2Array([tip, left_pt, right_pt]), rim_color)

	# Main troop circle
	draw_circle(Vector2.ZERO, RADIUS, fill_color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, rim_color, 2.5, true)


func _on_area_entered(area: Area2D) -> void:
	if is_resolved:
		return
	if area == target_node:
		_resolve_arrival()


func _resolve_arrival() -> void:
	if is_resolved:
		return
	is_resolved = true

	if target_node != null and is_instance_valid(target_node):
		var effective_attack_mult: float = power_multiplier
		if faction == BaseNode.Faction.PLAYER and creature_manager != null and is_instance_valid(creature_manager):
			effective_attack_mult *= creature_manager.get_attack_mult()
		target_node.receive_army(faction, troops, effective_attack_mult)

	arrived.emit(self)
	queue_free()


func _is_fire_buff_active() -> bool:
	return (
		faction == BaseNode.Faction.PLAYER
		and creature_manager != null
		and is_instance_valid(creature_manager)
		and creature_manager.is_element_buff_active(CreatureData.Element.FIRE)
	)


func _update_label() -> void:
	if troop_label:
		troop_label.text = str(troops)


func _get_fill_color() -> Color:
	match faction:
		BaseNode.Faction.PLAYER:
			return BaseNode.COLOR_PLAYER_FILL
		BaseNode.Faction.ENEMY:
			return BaseNode.COLOR_ENEMY_FILL
		_:
			return BaseNode.COLOR_NEUTRAL_FILL


func _get_rim_color() -> Color:
	match faction:
		BaseNode.Faction.PLAYER:
			return BaseNode.COLOR_PLAYER_RIM
		BaseNode.Faction.ENEMY:
			return BaseNode.COLOR_ENEMY_RIM
		_:
			return BaseNode.COLOR_NEUTRAL_RIM
