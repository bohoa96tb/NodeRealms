class_name BattleManager
extends Node2D

const CAMPAIGN_SCENE_PATH: String = "res://scenes/CampaignScene.tscn"
const PLAY_AREA := Rect2(90.0, 185.0, 540.0, 835.0)
const TOUCH_SELECT_PADDING: float = 16.0
const RATIO_OPTIONS := [0.25, 0.5, 0.75, 1.0]
const EMULATED_DEVICE_ID: int = -1

const PORTAL_DASH_LENGTH: float = 14.0
const PORTAL_GAP_LENGTH: float = 10.0

const BONUS_CAPTURE_ALL_GOLD: int = 30
const BONUS_NO_BASE_LOST_GOLD: int = 20
const BONUS_FAST_CLEAR_GOLD: int = 20
const FAST_CLEAR_LIMIT_SEC: float = 90.0

@export var base_node_scene: PackedScene = preload("res://scenes/BaseNode.tscn")
@export var army_group_scene: PackedScene = preload("res://scenes/ArmyGroup.tscn")

@onready var paths_layer: Node2D = $PathsLayer
@onready var portals_layer: Node2D = $PortalsLayer
@onready var nodes_layer: Node2D = $NodesLayer
@onready var army_groups_layer: Node2D = $ArmyGroupsLayer
@onready var drag_line: Line2D = $DragLine
@onready var ai_controller: AIController = $AIController
@onready var creature_manager: CreatureManager = $CreatureManager

@onready var stats_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/TopHeaderRow/StatsLabel
@onready var seed_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/SeedLabel
@onready var tier_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/TierLabel
@onready var next_map_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/NextMapBtn
@onready var tier_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/TierBtn
@onready var back_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/BackBtn

@onready var skill_btn: Button = $HUD/HUDRoot/SkillBar/SkillBtn
@onready var switch_creature_btn: Button = $HUD/HUDRoot/SkillBar/SwitchCreatureBtn

@onready var btn_25: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn25
@onready var btn_50: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn50
@onready var btn_75: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn75
@onready var btn_100: Button = $HUD/HUDRoot/BottomBar/BottomMargin/RatioContainer/Btn100
@onready var result_overlay: ColorRect = $HUD/HUDRoot/ResultOverlay
@onready var result_title: Label = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/ResultTitle
@onready var result_subtitle: Label = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/ResultSubtitle
@onready var reward_details_label: Label = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/RewardDetailsLabel
@onready var next_level_btn: Button = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/PopupButtonsRow/NextLevelBtn
@onready var restart_button: Button = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/PopupButtonsRow/RestartButton
@onready var campaign_btn: Button = $HUD/HUDRoot/ResultOverlay/CenterContainer/ResultPopup/PopupMargin/PopupVBox/PopupButtonsRow/CampaignBtn

var ratio_buttons: Array[Button] = []
var all_nodes: Array[BaseNode] = []
var selected_ratio: float = 0.5
var current_seed: int = 0
var current_tier: int = 1

var _is_campaign_mode: bool = false
var _current_level_info: Dictionary = {}
var _current_ai_difficulty: CampaignData.AIDifficulty = CampaignData.AIDifficulty.NORMAL
var _match_elapsed_time: float = 0.0
var _player_lost_base: bool = false

var _map_generator := MapGenerator.new()
var _portal_visuals: Array[Line2D] = []
var _portal_anim_time: float = 0.0
var _skill_blink_time: float = 0.0

var _drag_source_node: BaseNode = null
var _hovered_target_node: BaseNode = null
var _active_touch_index: int = -1
var _is_mouse_dragging: bool = false
var _game_ended: bool = false
var _stats_refresh_timer: float = 0.0

var _style_btn_normal: StyleBoxFlat
var _style_btn_active: StyleBoxFlat
var _style_skill_ready: StyleBoxFlat
var _style_skill_active: StyleBoxFlat
var _style_skill_cooldown: StyleBoxFlat
var _style_switch_btn: StyleBoxFlat


func _ready() -> void:
	randomize()
	ratio_buttons.assign([btn_25, btn_50, btn_75, btn_100])
	_setup_hud_styles()
	_connect_hud_signals()
	_connect_creature_signals()
	_select_ratio_index(1) # Default 50%

	if creature_manager:
		creature_manager.equipped_creature_id = SaveManager.get_equipped_creature()

	if SaveManager.is_campaign:
		load_campaign_level(SaveManager.current_level_id)
	else:
		_is_campaign_mode = false
		_current_level_info = {}
		var initial_seed: int = randi_range(10000, 99999)
		load_generated_map(initial_seed, 1, CampaignData.AIDifficulty.NORMAL)

	_refresh_creature_hud()


func _process(delta: float) -> void:
	_portal_anim_time += delta
	if not _portal_visuals.is_empty():
		var pulse_alpha: float = 0.65 + 0.3 * sin(_portal_anim_time * 3.5)
		for line in _portal_visuals:
			if is_instance_valid(line):
				line.modulate.a = pulse_alpha

	if creature_manager != null and creature_manager.is_skill_active():
		_skill_blink_time += delta * 8.0
		_update_active_skill_blink()

	if _game_ended:
		return

	_match_elapsed_time += delta

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


func load_campaign_level(level_id: int) -> void:
	SaveManager.start_campaign_level(level_id)
	_is_campaign_mode = true
	_current_level_info = CampaignData.get_level(level_id)
	load_generated_map(
		int(_current_level_info["seed"]),
		int(_current_level_info["tier"]),
		_current_level_info["ai_difficulty"]
	)


func load_generated_map(
	seed_value: int,
	tier: int,
	ai_diff: CampaignData.AIDifficulty = CampaignData.AIDifficulty.NORMAL
) -> void:
	_cancel_drag()
	_game_ended = false
	_stats_refresh_timer = 0.0
	_match_elapsed_time = 0.0
	_player_lost_base = false
	_current_ai_difficulty = ai_diff

	if creature_manager:
		creature_manager.set_paused(false)
		creature_manager.reset_state()

	if drag_line:
		drag_line.visible = false
	if result_overlay:
		result_overlay.visible = false

	_clear_layer_children(army_groups_layer)
	_clear_layer_children(nodes_layer)
	_clear_layer_children(paths_layer)
	_clear_layer_children(portals_layer)
	all_nodes.clear()
	_portal_visuals.clear()

	var map_data: Dictionary = _map_generator.generate_map(seed_value, tier, PLAY_AREA)
	current_seed = int(map_data["seed"])
	current_tier = int(map_data["tier"])

	var node_by_id: Dictionary = {}
	for node_info in map_data["nodes"]:
		var node: BaseNode = base_node_scene.instantiate() as BaseNode
		node.node_id = int(node_info["id"])
		node.position = node_info["position"]
		node.faction = node_info["faction"] as BaseNode.Faction
		node.troops = float(node_info["troops"])
		node.creature_manager = creature_manager
		nodes_layer.add_child(node)
		node.faction_changed.connect(_on_node_faction_changed)
		all_nodes.append(node)
		node_by_id[node.node_id] = node

	for edge in map_data["edges"]:
		var node_a: BaseNode = node_by_id.get(edge.x) as BaseNode
		var node_b: BaseNode = node_by_id.get(edge.y) as BaseNode
		if node_a != null and node_b != null:
			_add_bidirectional_link(node_a, node_b, false)

	for portal in map_data["portal_pairs"]:
		var node_a: BaseNode = node_by_id.get(portal.x) as BaseNode
		var node_b: BaseNode = node_by_id.get(portal.y) as BaseNode
		if node_a != null and node_b != null:
			_add_bidirectional_link(node_a, node_b, true)

	_build_path_lines()
	_build_portal_lines()

	if ai_controller:
		ai_controller.initialize(self, _current_ai_difficulty)

	_update_map_hud_labels()
	_update_stats_label()
	_refresh_creature_hud()


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

	var is_portal: bool = from_node.is_portal_connected_to(to_node)
	var army: ArmyGroup = army_group_scene.instantiate() as ArmyGroup
	army_groups_layer.add_child(army)
	army.setup(from_node, to_node, sent_troops, is_portal, creature_manager)
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


func _clear_layer_children(layer: Node) -> void:
	if layer == null:
		return
	var children: Array[Node] = layer.get_children()
	for child in children:
		layer.remove_child(child)
		child.queue_free()


func _add_bidirectional_link(node_a: BaseNode, node_b: BaseNode, is_portal: bool) -> void:
	if node_a == node_b:
		return
	if is_portal:
		if not node_a.portal_nodes.has(node_b):
			node_a.portal_nodes.append(node_b)
		if not node_b.portal_nodes.has(node_a):
			node_b.portal_nodes.append(node_a)
	else:
		if not node_a.connected_nodes.has(node_b):
			node_a.connected_nodes.append(node_b)
		if not node_b.connected_nodes.has(node_a):
			node_b.connected_nodes.append(node_a)


func _build_path_lines() -> void:
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


func _build_portal_lines() -> void:
	var drawn_pairs: Dictionary = {}
	for node in all_nodes:
		for partner in node.portal_nodes:
			if partner == null or partner == node:
				continue
			var id_a: int = mini(node.get_instance_id(), partner.get_instance_id())
			var id_b: int = maxi(node.get_instance_id(), partner.get_instance_id())
			var key: String = "%d_%d" % [id_a, id_b]
			if drawn_pairs.has(key):
				continue
			drawn_pairs[key] = true

			var glow_line := Line2D.new()
			glow_line.width = 12.0
			glow_line.default_color = Color(0.42, 0.22, 0.68, 0.22)
			glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
			glow_line.add_point(node.position)
			glow_line.add_point(partner.position)
			portals_layer.add_child(glow_line)
			_portal_visuals.append(glow_line)

			var delta_vec: Vector2 = partner.position - node.position
			var total_dist: float = delta_vec.length()
			if total_dist < 1.0:
				continue
			var dir: Vector2 = delta_vec / total_dist
			var step_len: float = PORTAL_DASH_LENGTH + PORTAL_GAP_LENGTH
			var cursor: float = 0.0
			var dash_idx: int = 0

			while cursor < total_dist:
				var seg_end: float = minf(cursor + PORTAL_DASH_LENGTH, total_dist)
				var dash_line := Line2D.new()
				dash_line.width = 3.5
				dash_line.default_color = Color.CYAN if (dash_idx % 2 == 0) else Color.MEDIUM_ORCHID
				dash_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
				dash_line.end_cap_mode = Line2D.LINE_CAP_ROUND
				dash_line.add_point(node.position + dir * cursor)
				dash_line.add_point(node.position + dir * seg_end)
				portals_layer.add_child(dash_line)
				_portal_visuals.append(dash_line)

				cursor += step_len
				dash_idx += 1


func _begin_drag(world_pos: Vector2) -> bool:
	var hit_node: BaseNode = _find_node_at_position(world_pos)
	if hit_node == null or hit_node.faction != BaseNode.Faction.PLAYER:
		return false

	_drag_source_node = hit_node
	_drag_source_node.is_selected = true
	_drag_source_node.play_pulse(1.1)

	for neighbor in _drag_source_node.get_all_reachable_nodes():
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

	if _hovered_target_node != null and _drag_source_node.is_portal_connected_to(_hovered_target_node):
		drag_line.default_color = Color.CYAN
	elif _hovered_target_node != null:
		drag_line.default_color = Color(0.33, 0.94, 0.77, 0.95)
	else:
		drag_line.default_color = Color(0.45, 0.78, 1.0, 0.85)
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
		for neighbor in _drag_source_node.get_all_reachable_nodes():
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


func _on_node_faction_changed(_node: BaseNode, old_faction: BaseNode.Faction, new_faction: BaseNode.Faction) -> void:
	if old_faction == BaseNode.Faction.PLAYER and new_faction != BaseNode.Faction.PLAYER:
		_player_lost_base = true


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


func _are_all_nodes_captured_by_player() -> bool:
	for node in all_nodes:
		if is_instance_valid(node) and node.faction != BaseNode.Faction.PLAYER:
			return false
	return not all_nodes.is_empty()


func _show_end_screen(victory: bool) -> void:
	_game_ended = true
	_cancel_drag()

	if creature_manager:
		creature_manager.set_paused(true)
	_refresh_creature_hud()

	if victory:
		result_title.text = "VICTORY"
		result_title.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0, 1.0))

		if _is_campaign_mode:
			var level_id: int = int(_current_level_info["level_id"])
			var level_name: String = str(_current_level_info["name"])
			var base_gold: int = int(_current_level_info["base_gold"])
			var base_essence: int = int(_current_level_info["base_essence"])

			var cap_all: bool = _are_all_nodes_captured_by_player()
			var no_lost: bool = not _player_lost_base
			var fast_clear: bool = _match_elapsed_time < FAST_CLEAR_LIMIT_SEC

			var bonus_cap: int = BONUS_CAPTURE_ALL_GOLD if cap_all else 0
			var bonus_no_lost: int = BONUS_NO_BASE_LOST_GOLD if no_lost else 0
			var bonus_fast: int = BONUS_FAST_CLEAR_GOLD if fast_clear else 0
			var total_gold: int = base_gold + bonus_cap + bonus_no_lost + bonus_fast

			SaveManager.record_campaign_victory(level_id, total_gold, base_essence)

			result_subtitle.text = "LV %d: %s Cleared! (%ds)" % [level_id, level_name, int(_match_elapsed_time)]
			reward_details_label.text = (
				"Base Clear: +%d Gold\n"
				+ "%s Capture All Nodes: +%d Gold\n"
				+ "%s No Base Lost: +%d Gold\n"
				+ "%s Fast Clear (<90s): +%d Gold\n"
				+ "Total Earned: +%d Gold  |  +%d Essence"
			) % [
				base_gold,
				"[OK]" if cap_all else "[--]", bonus_cap,
				"[OK]" if no_lost else "[--]", bonus_no_lost,
				"[OK]" if fast_clear else "[--]", bonus_fast,
				total_gold, base_essence,
			]
			reward_details_label.visible = true
			next_level_btn.visible = level_id < CampaignData.TOTAL_LEVELS
			restart_button.text = "Replay"
		else:
			SaveManager.record_sandbox_victory()
			result_subtitle.text = "All enemy realms conquered! (%ds)" % int(_match_elapsed_time)
			reward_details_label.text = "Sandbox Seed #%d (Tier %d) Cleared!" % [current_seed, current_tier]
			reward_details_label.visible = true
			next_level_btn.visible = false
			restart_button.text = "Replay"
	else:
		SaveManager.record_defeat()
		result_title.text = "DEFEAT"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0))
		result_subtitle.text = "Your realms have fallen!"
		reward_details_label.text = "Match Time: %ds\nTip: Use your Creature Skill to push the front!" % int(_match_elapsed_time)
		reward_details_label.visible = true
		next_level_btn.visible = false
		restart_button.text = "Retry"

	result_overlay.visible = true


func _update_map_hud_labels() -> void:
	if _is_campaign_mode:
		if next_map_btn:
			next_map_btn.visible = false
		if tier_btn:
			tier_btn.visible = false
		if back_btn:
			back_btn.visible = true
		if seed_label:
			seed_label.text = "VERDANT - LV %d (%s)" % [int(_current_level_info["level_id"]), str(_current_level_info["name"])]
		if tier_label:
			tier_label.text = CampaignData.get_difficulty_label(_current_ai_difficulty)
	else:
		if next_map_btn:
			next_map_btn.visible = true
		if tier_btn:
			tier_btn.visible = true
		if back_btn:
			back_btn.visible = true
		if seed_label:
			seed_label.text = "Seed: #%d" % current_seed
		if tier_label:
			tier_label.text = "Tier: %d" % current_tier


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

	stats_label.text = "BLUE %d  |  RED %d" % [player_troops, enemy_troops]


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

	var style_top_btn := StyleBoxFlat.new()
	style_top_btn.bg_color = Color(0.16, 0.22, 0.32, 0.95)
	style_top_btn.border_color = Color(0.4, 0.54, 0.72, 0.9)
	style_top_btn.set_border_width_all(2)
	style_top_btn.set_corner_radius_all(8)
	style_top_btn.content_margin_left = 10.0
	style_top_btn.content_margin_right = 10.0
	style_top_btn.content_margin_top = 4.0
	style_top_btn.content_margin_bottom = 4.0

	var style_top_btn_hover := style_top_btn.duplicate() as StyleBoxFlat
	style_top_btn_hover.bg_color = Color(0.22, 0.32, 0.46, 1.0)
	style_top_btn_hover.border_color = Color(0.6, 0.82, 1.0, 1.0)

	for top_btn in [next_map_btn, tier_btn, back_btn]:
		if top_btn:
			top_btn.add_theme_stylebox_override("normal", style_top_btn)
			top_btn.add_theme_stylebox_override("hover", style_top_btn_hover)
			top_btn.add_theme_stylebox_override("pressed", style_top_btn_hover)
			top_btn.add_theme_stylebox_override("focus", style_top_btn)

	_style_skill_ready = StyleBoxFlat.new()
	_style_skill_ready.set_border_width_all(2)
	_style_skill_ready.set_corner_radius_all(14)
	_style_skill_ready.content_margin_left = 12.0
	_style_skill_ready.content_margin_right = 12.0

	_style_skill_active = StyleBoxFlat.new()
	_style_skill_active.set_border_width_all(3)
	_style_skill_active.set_corner_radius_all(14)
	_style_skill_active.content_margin_left = 12.0
	_style_skill_active.content_margin_right = 12.0

	_style_skill_cooldown = StyleBoxFlat.new()
	_style_skill_cooldown.bg_color = Color(0.12, 0.14, 0.2, 0.85)
	_style_skill_cooldown.border_color = Color(0.28, 0.32, 0.4, 0.75)
	_style_skill_cooldown.set_border_width_all(2)
	_style_skill_cooldown.set_corner_radius_all(14)
	_style_skill_cooldown.content_margin_left = 12.0
	_style_skill_cooldown.content_margin_right = 12.0

	_style_switch_btn = StyleBoxFlat.new()
	_style_switch_btn.bg_color = Color(0.13, 0.17, 0.24, 0.94)
	_style_switch_btn.border_color = Color(0.45, 0.56, 0.72, 0.9)
	_style_switch_btn.set_border_width_all(2)
	_style_switch_btn.set_corner_radius_all(14)
	_style_switch_btn.content_margin_left = 12.0
	_style_switch_btn.content_margin_right = 12.0


func _connect_hud_signals() -> void:
	for i in range(ratio_buttons.size()):
		var btn: Button = ratio_buttons[i]
		btn.pressed.connect(_on_ratio_button_pressed.bind(i))

	if next_level_btn:
		next_level_btn.pressed.connect(_on_next_level_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if campaign_btn:
		campaign_btn.pressed.connect(_on_back_to_campaign_pressed)
	if next_map_btn:
		next_map_btn.pressed.connect(_on_next_map_pressed)
	if tier_btn:
		tier_btn.pressed.connect(_on_tier_button_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_to_campaign_pressed)
	if skill_btn:
		skill_btn.pressed.connect(_on_skill_button_pressed)
	if switch_creature_btn:
		switch_creature_btn.pressed.connect(_on_switch_creature_pressed)


func _connect_creature_signals() -> void:
	if creature_manager == null:
		return
	creature_manager.skill_activated.connect(_on_skill_activated)
	creature_manager.skill_ended.connect(_on_skill_ended)
	creature_manager.cooldown_updated.connect(_on_cooldown_updated)
	creature_manager.creature_changed.connect(_on_creature_changed)


func _refresh_creature_hud() -> void:
	if creature_manager == null:
		return

	var creature: Dictionary = creature_manager.get_equipped_creature()
	var base_col: Color = creature["color"]
	var border_col: Color = creature["border_color"]

	if switch_creature_btn:
		switch_creature_btn.text = "%s [Swap]" % creature["name"]
		_style_switch_btn.border_color = border_col
		switch_creature_btn.add_theme_stylebox_override("normal", _style_switch_btn)
		switch_creature_btn.add_theme_stylebox_override("hover", _style_switch_btn)
		switch_creature_btn.add_theme_stylebox_override("pressed", _style_switch_btn)
		switch_creature_btn.add_theme_stylebox_override("focus", _style_switch_btn)
		switch_creature_btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))

	if skill_btn == null:
		return

	_style_skill_ready.bg_color = base_col
	_style_skill_ready.border_color = border_col
	_style_skill_active.bg_color = base_col.darkened(0.15)
	_style_skill_active.border_color = border_col

	if creature_manager.is_skill_active():
		skill_btn.disabled = true
		skill_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		skill_btn.text = "ACTIVE (%ds)" % maxi(1, ceili(creature_manager.active_timer))
		skill_btn.add_theme_stylebox_override("disabled", _style_skill_active)
		skill_btn.add_theme_color_override("font_disabled_color", Color.WHITE)
	elif creature_manager.cooldown_timer > 0.0:
		skill_btn.disabled = true
		skill_btn.modulate = Color(1.0, 1.0, 1.0, 0.65)
		skill_btn.text = "%ds" % maxi(1, ceili(creature_manager.cooldown_timer))
		skill_btn.add_theme_stylebox_override("disabled", _style_skill_cooldown)
		skill_btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.78, 0.86, 1.0))
	else:
		skill_btn.disabled = _game_ended
		skill_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		skill_btn.text = creature["skill_name"]
		skill_btn.add_theme_stylebox_override("normal", _style_skill_ready)
		skill_btn.add_theme_stylebox_override("hover", _style_skill_ready)
		skill_btn.add_theme_stylebox_override("pressed", _style_skill_ready)
		skill_btn.add_theme_stylebox_override("focus", _style_skill_ready)
		skill_btn.add_theme_stylebox_override("disabled", _style_skill_cooldown)
		skill_btn.add_theme_color_override("font_color", Color.WHITE)


func _update_active_skill_blink() -> void:
	if _style_skill_active == null or creature_manager == null:
		return
	var creature: Dictionary = creature_manager.get_equipped_creature()
	var border_col: Color = creature["border_color"]
	var blink: float = 0.5 + 0.5 * sin(_skill_blink_time)
	_style_skill_active.border_color = border_col.lerp(Color.WHITE, blink)


func _on_skill_button_pressed() -> void:
	if _game_ended or creature_manager == null:
		return
	var player_nodes: Array[BaseNode] = get_nodes_by_faction(BaseNode.Faction.PLAYER)
	creature_manager.activate_skill(player_nodes)


func _on_switch_creature_pressed() -> void:
	if _game_ended or creature_manager == null:
		return
	creature_manager.cycle_creature()


func _on_skill_activated(_creature: Dictionary) -> void:
	_skill_blink_time = 0.0
	_update_stats_label()
	_refresh_creature_hud()


func _on_skill_ended(_creature: Dictionary) -> void:
	for node in all_nodes:
		if is_instance_valid(node):
			node.queue_redraw()
	_refresh_creature_hud()


func _on_cooldown_updated(_remaining_cooldown: float, _remaining_active: float) -> void:
	_refresh_creature_hud()


func _on_creature_changed(creature: Dictionary) -> void:
	SaveManager.set_equipped_creature(str(creature["id"]))
	for node in all_nodes:
		if is_instance_valid(node):
			node.queue_redraw()
	_refresh_creature_hud()


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


func _on_next_map_pressed() -> void:
	var next_seed: int = randi_range(10000, 99999)
	load_generated_map(next_seed, current_tier, _current_ai_difficulty)


func _on_tier_button_pressed() -> void:
	var next_tier: int = (current_tier % 4) + 1
	var next_seed: int = randi_range(10000, 99999)
	load_generated_map(next_seed, next_tier, _current_ai_difficulty)


func _on_next_level_pressed() -> void:
	if _is_campaign_mode:
		var next_id: int = mini(CampaignData.TOTAL_LEVELS, int(_current_level_info["level_id"]) + 1)
		load_campaign_level(next_id)


func _on_restart_pressed() -> void:
	if _is_campaign_mode:
		load_campaign_level(int(_current_level_info["level_id"]))
	else:
		load_generated_map(current_seed, current_tier, _current_ai_difficulty)


func _on_back_to_campaign_pressed() -> void:
	get_tree().change_scene_to_file(CAMPAIGN_SCENE_PATH)
