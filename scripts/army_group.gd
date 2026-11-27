class_name ArmyGroup
extends Area2D

signal arrived(army: ArmyGroup)

const RADIUS: float = 16.0

@export var move_speed: float = 220.0

var faction: BaseNode.Faction = BaseNode.Faction.NEUTRAL
var troops: int = 0
var power_multiplier: float = 1.0
var source_node: BaseNode = null
var target_node: BaseNode = null
var is_resolved: bool = false

var _move_dir: Vector2 = Vector2.RIGHT

@onready var troop_label: Label = $TroopLabel


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_update_label()
	queue_redraw()


func setup(from_node: BaseNode, to_node: BaseNode, troop_count: int) -> void:
	source_node = from_node
	target_node = to_node
	faction = from_node.faction
	troops = troop_count
	power_multiplier = from_node.power_multiplier
	global_position = from_node.global_position
	_move_dir = (to_node.global_position - from_node.global_position).normalized()
	if troop_label:
		_update_label()
	queue_redraw()


func _process(delta: float) -> void:
	if is_resolved:
		return
	if target_node == null or not is_instance_valid(target_node):
		is_resolved = true
		queue_free()
		return

	var to_target: Vector2 = target_node.global_position - global_position
	var distance: float = to_target.length()
	var step: float = move_speed * delta

	if distance <= step or distance <= BaseNode.RADIUS * 0.75:
		_resolve_arrival()
		return

	_move_dir = to_target / distance
	global_position += _move_dir * step


func _draw() -> void:
	var fill_color: Color = _get_fill_color()
	var rim_color: Color = _get_rim_color()

	# Shadow
	draw_circle(Vector2(0.0, 2.0), RADIUS + 2.0, Color(0.0, 0.0, 0.0, 0.35))

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
		target_node.receive_army(faction, troops, power_multiplier)

	arrived.emit(self)
	queue_free()


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
