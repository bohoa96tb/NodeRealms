class_name BaseNode
extends Area2D

enum Faction { NEUTRAL, PLAYER, ENEMY }

const RADIUS: float = 42.0

const COLOR_PLAYER_FILL := Color(0.18, 0.525, 0.871, 1.0)
const COLOR_PLAYER_RIM := Color(0.45, 0.75, 1.0, 1.0)
const COLOR_ENEMY_FILL := Color(0.86, 0.25, 0.27, 1.0)
const COLOR_ENEMY_RIM := Color(1.0, 0.52, 0.52, 1.0)
const COLOR_NEUTRAL_FILL := Color(0.36, 0.41, 0.45, 1.0)
const COLOR_NEUTRAL_RIM := Color(0.62, 0.68, 0.72, 1.0)

const COLOR_SELECTED_GLOW := Color(1.0, 0.92, 0.55, 0.95)
const COLOR_VALID_TARGET := Color(0.33, 0.94, 0.77, 0.85)
const COLOR_HOVERED_TARGET := Color(1.0, 1.0, 1.0, 0.95)

@export var node_id: int = 0
@export var faction: Faction = Faction.NEUTRAL:
	set(value):
		if faction != value:
			faction = value
			_refresh_visuals()
@export var troops: float = 10.0:
	set(value):
		troops = maxf(0.0, value)
		_update_troop_label()
		queue_redraw()
@export var max_troops: int = 50
@export var production_rate: float = 0.5
@export var power_multiplier: float = 1.0
@export var connected_nodes: Array[BaseNode] = []

@onready var troop_label: Label = $TroopLabel

var is_selected: bool = false:
	set(value):
		if is_selected != value:
			is_selected = value
			queue_redraw()

var is_valid_target: bool = false:
	set(value):
		if is_valid_target != value:
			is_valid_target = value
			queue_redraw()

var is_hovered_target: bool = false:
	set(value):
		if is_hovered_target != value:
			is_hovered_target = value
			queue_redraw()

var _is_mouse_over: bool = false
var _pulse_tween: Tween


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visuals()


func _process(delta: float) -> void:
	if faction == Faction.PLAYER or faction == Faction.ENEMY:
		if troops < float(max_troops):
			troops = minf(float(max_troops), troops + production_rate * delta)


func _draw() -> void:
	var fill_color: Color = _get_fill_color()
	var rim_color: Color = _get_rim_color()

	# Soft ambient shadow behind node
	draw_circle(Vector2(0.0, 4.0), RADIUS + 3.0, Color(0.0, 0.0, 0.0, 0.35))

	# Selection / target highlight rings
	if is_selected:
		draw_circle(Vector2.ZERO, RADIUS + 11.0, Color(1.0, 0.92, 0.55, 0.22))
		draw_arc(Vector2.ZERO, RADIUS + 7.0, 0.0, TAU, 48, COLOR_SELECTED_GLOW, 3.5, true)
	elif is_hovered_target:
		draw_circle(Vector2.ZERO, RADIUS + 11.0, Color(0.33, 0.94, 0.77, 0.24))
		draw_arc(Vector2.ZERO, RADIUS + 7.0, 0.0, TAU, 48, COLOR_HOVERED_TARGET, 3.5, true)
	elif is_valid_target:
		draw_arc(Vector2.ZERO, RADIUS + 6.0, 0.0, TAU, 48, COLOR_VALID_TARGET, 2.5, true)
	elif _is_mouse_over and faction == Faction.PLAYER:
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.4), 2.0, true)

	# Main node body
	draw_circle(Vector2.ZERO, RADIUS, fill_color)

	# Subtle inner core shading
	draw_circle(Vector2(0.0, -6.0), RADIUS * 0.72, Color(1.0, 1.0, 1.0, 0.08))

	# Outer rim
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, rim_color, 3.0, true)

	# Capacity progress arc
	if max_troops > 0:
		var fill_ratio: float = clampf(troops / float(max_troops), 0.0, 1.0)
		if fill_ratio > 0.01:
			var start_angle: float = -PI * 0.5
			var end_angle: float = start_angle + TAU * fill_ratio
			draw_arc(Vector2.ZERO, RADIUS - 5.0, start_angle, end_angle, 40, Color(1.0, 1.0, 1.0, 0.38), 2.5, true)


func extract_troops(ratio: float) -> int:
	var available: int = floori(troops)
	if available <= 0:
		return 0
	var amount: int = floori(float(available) * ratio)
	if amount <= 0 and ratio > 0.0:
		amount = 1
	amount = mini(amount, available)
	troops -= float(amount)
	play_pulse(0.9)
	return amount


func receive_army(incoming_faction: Faction, incoming_troops: int, attack_mult: float) -> void:
	if incoming_troops <= 0:
		return

	if incoming_faction == faction:
		troops = minf(float(max_troops), troops + float(incoming_troops))
		play_pulse(1.12)
		return

	var defense_mult: float = power_multiplier
	var attack_power: float = float(incoming_troops) * attack_mult
	var defense_power: float = troops * defense_mult

	if attack_power > defense_power:
		var winner_mult: float = maxf(0.01, attack_mult)
		var remaining: float = absf(attack_power - defense_power) / winner_mult
		faction = incoming_faction
		troops = minf(float(max_troops), remaining)
		play_pulse(1.2)
	else:
		var winner_mult: float = maxf(0.01, defense_mult)
		var remaining: float = absf(attack_power - defense_power) / winner_mult
		troops = remaining
		play_pulse(0.92)


func is_connected_to(other: BaseNode) -> bool:
	return other != null and other in connected_nodes


func play_pulse(peak_scale: float = 1.15) -> void:
	if not is_inside_tree():
		return
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), 0.08).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT)


func _refresh_visuals() -> void:
	_update_troop_label()
	queue_redraw()


func _update_troop_label() -> void:
	if troop_label:
		troop_label.text = str(floori(troops))


func _get_fill_color() -> Color:
	match faction:
		Faction.PLAYER:
			return COLOR_PLAYER_FILL
		Faction.ENEMY:
			return COLOR_ENEMY_FILL
		_:
			return COLOR_NEUTRAL_FILL


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
