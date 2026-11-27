class_name BattleManager
extends Node2D

const DEFAULT_GRAPH_EDGES := [
	Vector2i(1, 2),
	Vector2i(1, 3),
	Vector2i(2, 4),
	Vector2i(2, 5),
	Vector2i(3, 4),
	Vector2i(3, 6),
	Vector2i(4, 5),
	Vector2i(4, 6),
	Vector2i(5, 7),
	Vector2i(6, 7),
]

const TOUCH_SELECT_PADDING: float = 16.0
const RATIO_OPTIONS := [0.25, 0.5, 0.75, 1.0]
const EMULATED_DEVICE_ID: int = -1

@export var army_group_scene: PackedScene = preload("res://scenes/ArmyGroup.tscn")

@onready var paths_layer: Node2D = $PathsLayer
@onready var nodes_layer: Node2D = $NodesLayer
@onready var army_groups_layer: Node2D = $ArmyGroupsLayer
@onready var drag_line: Line2D = $DragLine
@onready var ai_controller: AIController = $AIController

@onready var stats_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/StatsLabel
@onready var btn_25: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn25
@onready var btn_50: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn50
@onready var btn_75: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn75
@onready var btn_100: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn100
@onready var result_overlay: ColorRect = $HUD/HUDRoot/ResultOverlay
@onready var result_title: Label = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/ResultTitle
@onready var result_subtitle: Label = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/ResultSubtitle
@onready var restart_button: Button = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/RestartButton

var ratio_buttons: Array[Button] = []
var all_nodes: Array[BaseNode] = []
var selected_ratio: float = 0.5

var _drag_source_node: BaseNode = null
var _hovered_target_node: BaseNode = null
var _active_touch_index: int = -1
var _is_mouse_dragging: bool = false
var _game_ended: bool = false
var _stats_refresh_timer: float = 0.0

var _style_btn_normal: StyleBoxFlat
var _style_btn_active: StyleBoxFlat


func _ready() -> void:
	ratio_buttons = [btn_25, btn_50, btn_75, btn_100]
	_collect_nodes()
	_setup_graph_connections()
	_build_path_lines()
	_setup_hud_styles()
	_connect_hud_signals()
	_select_ratio_index(1) # Default 50%

	if drag_line:
		drag_line.visible = false
	if result_overlay:
		result_overlay.visible = false
	if ai_controller:
		ai_controller.initialize(self)

	_update_stats_label()


func _process(delta: float) -> void:
	if _game_ended:
		return

	# Cancel drag cleanly if source node is lost or captured mid-drag
	if _drag_source_node != null:
		if not is_instance_valid(_drag_source_node) or _drag_source_node.faction != BaseNode.Faction.PLAYER:
			_cancel_drag()

	_stats_refresh_timer += delta
	if _stats_refresh_timer >= 0.25:
		_stats_refresh_timer = 0.0
		_update_stats_label()


func _unhandled_input(event: InputEvent) -> void:
	if _game_ended:
		return

	# Ignore emulated events to prevent double-triggering between mouse and touch
	if event.device == EMULATED_DEVICE_ID:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		var world_pos: Vector2 = _screen_to_world(touch_event.position)
		if touch_event.pressed:
			if _active_touch_index == -1 and not _is_mouse_dragging:
				if _begin_drag(world_pos):
					_active_touch_index = touch_event.index
		else:
			if touch_event.index == _active_touch_index:
				_end_drag(world_pos)
				_active_touch_index = -1

	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if drag_event.index == _active_touch_index:
			_update_drag(_screen_to_world(drag_event.position))

	elif event is InputEventMouseButton:
		var mouse_btn: InputEventMouseButton = event
		if mouse_btn.button_index == MOUSE_BUTTON_LEFT and _active_touch_index == -1:
			var world_pos: Vector2 = _screen_to_world(mouse_btn.position)
			if mouse_btn.pressed:
				if _begin_drag(world_pos):
					_is_mouse_dragging = true
			elif _is_mouse_dragging:
				_end_drag(world_pos)
				_is_mouse_dragging = false

	elif event is InputEventMouseMotion:
		if _is_mouse_dragging and _active_touch_index == -1:
			_update_drag(_screen_to_world(event.position))


func spawn_army(from_node: BaseNode, to_node: BaseNode, ratio: float) -> void:
	if _game_ended:
		return
	if from_node == null or to_node == null or from_node == to_node:
		return
	if not from_node.is_connected_to(to_node):
		return

	var sent_troops: int = from_node.extract_troops(ratio)
	if sent_troops <= 0:
		return

	var army: ArmyGroup = army_group_scene.instantiate() as ArmyGroup
	army_groups_layer.add_child(army)
	army.setup(from_node, to_node, sent_troops)
	army.arrived.connect(_on_army_arrived)
	_update_stats_label()


func is_game_ended() -> bool:
	return _game_ended


func get_nodes_by_faction(target_faction: BaseNode.Faction) -> Array[BaseNode]:
	var result: Array[BaseNode] = []
	for node in all_nodes:
		if is_instance_valid(node) and node.faction == target_faction:
			result.append(node)
	return result


func _collect_nodes() -> void:
	all_nodes.clear()
	for child in nodes_layer.get_children():
		if child is BaseNode:
			all_nodes.append(child as BaseNode)


func _setup_graph_connections() -> void:
	var has_existing_links: bool = false
	for node in all_nodes:
		if not node.connected_nodes.is_empty():
			has_existing_links = true
			break

	if not has_existing_links:
		var by_id: Dictionary = {}
		for node in all_nodes:
			by_id[node.node_id] = node

		for edge in DEFAULT_GRAPH_EDGES:
			var node_a: BaseNode = by_id.get(edge.x) as BaseNode
			var node_b: BaseNode = by_id.get(edge.y) as BaseNode
			if node_a != null and node_b != null:
				_add_bidirectional_link(node_a, node_b)
	else:
		# Ensure any configured connections remain bidirectional
		for node in all_nodes:
			for neighbor in node.connected_nodes:
				if neighbor != null and neighbor != node and not neighbor.connected_nodes.has(node):
					neighbor.connected_nodes.append(node)


func _add_bidirectional_link(node_a: BaseNode, node_b: BaseNode) -> void:
	if node_a == node_b:
		return
	if not node_a.connected_nodes.has(node_b):
		node_a.connected_nodes.append(node_b)
	if not node_b.connected_nodes.has(node_a):
		node_b.connected_nodes.append(node_a)


func _build_path_lines() -> void:
	for child in paths_layer.get_children():
		child.queue_free()

	var drawn_pairs: Dictionary = {}
	for node in all_nodes:
		for neighbor in node.connected_nodes:
			if neighbor == null or neighbor == node:
				continue
			var id_a: int = mini(node.get_instance_id(), neighbor.get_instance_id())
			var id_b: int = maxi(node.get_instance_id(), neighbor.get_instance_id())
			var key: String = "%d_%d" % [id_a, id_b]
			if drawn_pairs.has(key):
				continue
			drawn_pairs[key] = true

			var outer_line := Line2D.new()
			outer_line.width = 10.0
			outer_line.default_color = Color(0.11, 0.145, 0.21, 0.95)
			outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
			outer_line.add_point(node.position)
			outer_line.add_point(neighbor.position)
			paths_layer.add_child(outer_line)

			var inner_line := Line2D.new()
			inner_line.width = 3.5
			inner_line.default_color = Color(0.32, 0.42, 0.56, 0.8)
			inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
			inner_line.add_point(node.position)
			inner_line.add_point(neighbor.position)
			paths_layer.add_child(inner_line)


func _begin_drag(world_pos: Vector2) -> bool:
	var hit_node: BaseNode = _find_node_at_position(world_pos)
	if hit_node == null or hit_node.faction != BaseNode.Faction.PLAYER:
		return false

	_drag_source_node = hit_node
	_drag_source_node.is_selected = true
	_drag_source_node.play_pulse(1.1)

	for neighbor in _drag_source_node.connected_nodes:
		if is_instance_valid(neighbor):
			neighbor.is_valid_target = true

	_update_drag(world_pos)
	return true


func _update_drag(world_pos: Vector2) -> void:
	if _drag_source_node == null:
		return

	var candidate: BaseNode = _find_node_at_position(world_pos)
	var new_hovered: BaseNode = null
	if candidate != null and candidate != _drag_source_node and _drag_source_node.is_connected_to(candidate):
		new_hovered = candidate

	if _hovered_target_node != new_hovered:
		if _hovered_target_node != null and is_instance_valid(_hovered_target_node):
			_hovered_target_node.is_hovered_target = false
		_hovered_target_node = new_hovered
		if _hovered_target_node != null:
			_hovered_target_node.is_hovered_target = true

	var end_pos: Vector2 = _hovered_target_node.global_position if _hovered_target_node != null else world_pos
	drag_line.clear_points()
	drag_line.add_point(_drag_source_node.global_position)
	drag_line.add_point(end_pos)
	drag_line.default_color = Color(0.33, 0.94, 0.77, 0.95) if _hovered_target_node != null else Color(0.45, 0.78, 1.0, 0.85)
	drag_line.visible = true


func _end_drag(world_pos: Vector2) -> void:
	if _drag_source_node == null:
		return

	var target: BaseNode = _find_node_at_position(world_pos)
	if target != null and target != _drag_source_node and _drag_source_node.faction == BaseNode.Faction.PLAYER:
		if _drag_source_node.is_connected_to(target):
			spawn_army(_drag_source_node, target, selected_ratio)

	_cancel_drag()


func _cancel_drag() -> void:
	if _drag_source_node != null and is_instance_valid(_drag_source_node):
		_drag_source_node.is_selected = false
		for neighbor in _drag_source_node.connected_nodes:
			if is_instance_valid(neighbor):
				neighbor.is_valid_target = false

	if _hovered_target_node != null and is_instance_valid(_hovered_target_node):
		_hovered_target_node.is_hovered_target = false

	_drag_source_node = null
	_hovered_target_node = null
	_is_mouse_dragging = false
	_active_touch_index = -1

	if drag_line:
		drag_line.visible = false
		drag_line.clear_points()


func _find_node_at_position(world_pos: Vector2) -> BaseNode:
	var best_node: BaseNode = null
	var best_dist: float = BaseNode.RADIUS + TOUCH_SELECT_PADDING
	for node in all_nodes:
		if not is_instance_valid(node):
			continue
		var dist: float = node.global_position.distance_to(world_pos)
		if dist <= best_dist:
			best_dist = dist
			best_node = node
	return best_node


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _on_army_arrived(_army: ArmyGroup) -> void:
	_update_stats_label()
	_check_win_lose_conditions()


func _check_win_lose_conditions() -> void:
	if _game_ended:
		return

	var player_nodes: int = 0
	var enemy_nodes: int = 0
	for node in all_nodes:
		if not is_instance_valid(node):
			continue
		if node.faction == BaseNode.Faction.PLAYER:
			player_nodes += 1
		elif node.faction == BaseNode.Faction.ENEMY:
			enemy_nodes += 1

	var player_armies: int = 0
	var enemy_armies: int = 0
	for child in army_groups_layer.get_children():
		if child is ArmyGroup:
			var army: ArmyGroup = child as ArmyGroup
			if army.is_resolved or army.is_queued_for_deletion():
				continue
			if army.faction == BaseNode.Faction.PLAYER:
				player_armies += 1
			elif army.faction == BaseNode.Faction.ENEMY:
				enemy_armies += 1

	if enemy_nodes == 0 and enemy_armies == 0:
		_show_end_screen(true)
	elif player_nodes == 0 and player_armies == 0:
		_show_end_screen(false)


func _show_end_screen(victory: bool) -> void:
	_game_ended = true
	_cancel_drag()

	if victory:
		result_title.text = "VICTORY"
		result_title.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0, 1.0))
		result_subtitle.text = "All enemy realms conquered!"
	else:
		result_title.text = "DEFEAT"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0))
		result_subtitle.text = "Your realms have fallen!"

	result_overlay.visible = true


func _update_stats_label() -> void:
	if stats_label == null:
		return

	var player_troops: int = 0
	var enemy_troops: int = 0
	for node in all_nodes:
		if not is_instance_valid(node):
			continue
		if node.faction == BaseNode.Faction.PLAYER:
			player_troops += floori(node.troops)
		elif node.faction == BaseNode.Faction.ENEMY:
			enemy_troops += floori(node.troops)

	for child in army_groups_layer.get_children():
		if child is ArmyGroup:
			var army: ArmyGroup = child as ArmyGroup
			if army.is_resolved or army.is_queued_for_deletion():
				continue
			if army.faction == BaseNode.Faction.PLAYER:
				player_troops += army.troops
			elif army.faction == BaseNode.Faction.ENEMY:
				enemy_troops += army.troops

	stats_label.text = "REALM FORCES   BLUE: %d   |   RED: %d" % [player_troops, enemy_troops]


func _setup_hud_styles() -> void:
	_style_btn_normal = StyleBoxFlat.new()
	_style_btn_normal.bg_color = Color(0.14, 0.18, 0.25, 0.95)
	_style_btn_normal.border_color = Color(0.32, 0.4, 0.52, 0.9)
	_style_btn_normal.set_border_width_all(2)
	_style_btn_normal.set_corner_radius_all(12)

	_style_btn_active = StyleBoxFlat.new()
	_style_btn_active.bg_color = Color(0.18, 0.525, 0.871, 1.0)
	_style_btn_active.border_color = Color(0.65, 0.88, 1.0, 1.0)
	_style_btn_active.set_border_width_all(3)
	_style_btn_active.set_corner_radius_all(12)


func _connect_hud_signals() -> void:
	for i in range(ratio_buttons.size()):
		var btn: Button = ratio_buttons[i]
		btn.pressed.connect(_on_ratio_button_pressed.bind(i))

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


func _on_ratio_button_pressed(index: int) -> void:
	_select_ratio_index(index)


func _select_ratio_index(index: int) -> void:
	if index < 0 or index >= RATIO_OPTIONS.size():
		return

	selected_ratio = RATIO_OPTIONS[index]
	for i in range(ratio_buttons.size()):
		var btn: Button = ratio_buttons[i]
		var is_active: bool = (i == index)
		var style: StyleBoxFlat = _style_btn_active if is_active else _style_btn_normal
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.75, 0.82, 0.9, 1.0))


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
