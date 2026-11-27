class_name BattleManager
extends Node2D

const CAMPAIGN_SCENE_PATH: String = "res://scenes/MainHubScene.tscn"
const PLAY_AREA := Rect2(90.0, 240.0, 540.0, 780.0)
const BASE_TOP_BAR_HEIGHT: float = 154.0
const BASE_TOP_MARGIN: float = 24.0
const BASE_BOTTOM_BAR_HEIGHT: float = 124.0
const BASE_BOTTOM_MARGIN: float = 20.0
const BASE_SKILL_BAR_TOP: float = -192.0
const BASE_SKILL_BAR_BOTTOM: float = -136.0
const TOUCH_SELECT_PADDING: float = 16.0
const RATIO_OPTIONS := [0.25, 0.5, 0.75, 1.0]
const EMULATED_DEVICE_ID: int = -1

const PORTAL_DASH_LENGTH: float = 14.0
const PORTAL_GAP_LENGTH: float = 10.0

const BONUS_CAPTURE_ALL_GOLD: int = 30
const BONUS_NO_BASE_LOST_GOLD: int = 20
const BONUS_FAST_CLEAR_GOLD: int = 20
const FAST_CLEAR_LIMIT_SEC: float = 90.0

const BOSS_SKILL_INTERVAL: float = 12.0
const BOSS_CHARGE_DURATION: float = 2.0
const BOSS_SUMMON_TROOPS: float = 8.0
const BOSS_SURGE_RATIO: float = 0.40

@export var base_node_scene: PackedScene = preload("res://scenes/BaseNode.tscn")
@export var army_group_scene: PackedScene = preload("res://scenes/ArmyGroup.tscn")

@onready var camera_2d: Camera2D = $Camera2D
@onready var paths_layer: Node2D = $PathsLayer
@onready var portals_layer: Node2D = $PortalsLayer
@onready var nodes_layer: Node2D = $NodesLayer
@onready var vfx_layer: Node2D = $VfxLayer
@onready var army_groups_layer: Node2D = $ArmyGroupsLayer
@onready var drag_line: Line2D = $DragLine
@onready var ai_controller: AIController = $AIController
@onready var creature_manager: CreatureManager = $CreatureManager

@onready var top_bar: PanelContainer = $HUD/HUDRoot/TopBar
@onready var top_margin: MarginContainer = $HUD/HUDRoot/TopBar/TopMargin
@onready var sfx_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/TopHeaderRow/SfxBtn
@onready var stats_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/TopHeaderRow/StatsLabel
@onready var seed_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/SeedLabel
@onready var tier_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/TierLabel
@onready var next_map_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/NextMapBtn
@onready var tier_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/TierBtn
@onready var back_btn: Button = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/MapControlsRow/BackBtn
@onready var timer_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/StatusInfoRow/TimerLabel
@onready var no_loss_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/StatusInfoRow/NoLossLabel
@onready var boss_gauge_box: HBoxContainer = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/StatusInfoRow/BossGaugeBox
@onready var boss_gauge_label: Label = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/StatusInfoRow/BossGaugeBox/BossGaugeLabel
@onready var boss_gauge_bar: ProgressBar = $HUD/HUDRoot/TopBar/TopMargin/TopVBox/StatusInfoRow/BossGaugeBox/BossGaugeBar
@onready var boss_banner_label: Label = $HUD/HUDRoot/BossBannerLabel

@onready var skill_bar: HBoxContainer = $HUD/HUDRoot/SkillBar
@onready var skill_btn: Button = $HUD/HUDRoot/SkillBar/SkillBtn
@onready var switch_creature_btn: Button = $HUD/HUDRoot/SkillBar/SwitchCreatureBtn

@onready var bottom_bar: PanelContainer = $HUD/HUDRoot/BottomBar
@onready var bottom_margin: MarginContainer = $HUD/HUDRoot/BottomBar/BottomMargin
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
var _is_boss_test_mode: bool = false
var _current_level_info: Dictionary = {}
var _current_ai_difficulty: CampaignData.AIDifficulty = CampaignData.AIDifficulty.NORMAL
var _match_elapsed_time: float = 0.0
var _player_lost_base: bool = false

var _boss_node: BaseNode = null
var _boss_skill_timer: float = 0.0
var _boss_charging: bool = false
var _boss_charge_timer: float = 0.0
var _boss_blink_time: float = 0.0

var _shake_time: float = 0.0
var _shake_duration: float = 0.15
var _shake_intensity: float = 0.0

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
var _style_boss_bar_fill: StyleBoxFlat


func _ready() -> void:
	randomize()
	ratio_buttons.assign([btn_25, btn_50, btn_75, btn_100])
	_apply_safe_area_padding()
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_safe_area_padding):
		vp.size_changed.connect(_apply_safe_area_padding)
	_setup_hud_styles()
	_connect_hud_signals()
	_connect_creature_signals()
	_select_ratio_index(1) # Default 50%
	_refresh_sfx_button()

	if creature_manager:
		creature_manager.sync_from_save()

	if SaveManager.is_campaign:
		load_campaign_level(SaveManager.current_level_id)
	elif SaveManager.is_boss_test:
		load_boss_test_level()
	else:
		_is_campaign_mode = false
		_is_boss_test_mode = false
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

	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		if camera_2d:
			var decay: float = _shake_time / maxf(0.01, _shake_duration)
			camera_2d.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (_shake_intensity * decay)
		if _shake_time <= 0.0 and camera_2d:
			camera_2d.offset = Vector2.ZERO
			_shake_intensity = 0.0

	if creature_manager != null and creature_manager.is_skill_active():
		_skill_blink_time += delta * 8.0
		_update_active_skill_blink()

	if _game_ended or get_tree().paused:
		return

	_match_elapsed_time += delta
	_process_boss_skill(delta)
	_update_battle_readability_hud()

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
	_is_boss_test_mode = false
	_current_level_info = CampaignData.get_level(level_id)
	load_generated_map(
		int(_current_level_info["seed"]),
		int(_current_level_info["tier"]),
		_current_level_info["ai_difficulty"]
	)


func load_boss_test_level() -> void:
	SaveManager.start_boss_test()
	_is_campaign_mode = false
	_is_boss_test_mode = true
	_current_level_info = CampaignData.get_level(15)
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

	_boss_node = null
	_boss_skill_timer = 0.0
	_boss_charging = false
	_boss_charge_timer = 0.0
	_boss_blink_time = 0.0
	_shake_time = 0.0
	_shake_intensity = 0.0
	if camera_2d:
		camera_2d.offset = Vector2.ZERO
	if boss_banner_label:
		boss_banner_label.visible = false

	if creature_manager:
		creature_manager.set_paused(false)
		creature_manager.sync_from_save()
		creature_manager.reset_state()

	if drag_line:
		drag_line.visible = false
	if result_overlay:
		result_overlay.visible = false

	_clear_layer_children(army_groups_layer)
	_clear_layer_children(vfx_layer)
	_clear_layer_children(nodes_layer)
	_clear_layer_children(paths_layer)
	_clear_layer_children(portals_layer)
	all_nodes.clear()
	_portal_visuals.clear()

	var map_data: Dictionary = _map_generator.generate_map(seed_value, tier, PLAY_AREA)
	current_seed = int(map_data["seed"])
	current_tier = int(map_data["tier"])

	var is_boss_stage: bool = (
		(_is_campaign_mode and bool(_current_level_info.get("is_boss", false)))
		or _is_boss_test_mode
	)

	var barracks_bonus: int = SaveManager.get_barracks_max_troops_bonus()
	var node_by_id: Dictionary = {}
	for node_info in map_data["nodes"]:
		var node: BaseNode = base_node_scene.instantiate() as BaseNode
		node.node_id = int(node_info["id"])
		node.position = node_info["position"]
		node.barracks_bonus = barracks_bonus
		node.faction = node_info["faction"] as BaseNode.Faction
		node.troops = float(node_info["troops"])
		node.creature_manager = creature_manager

		if is_boss_stage and node.faction == BaseNode.Faction.ENEMY and _boss_node == null:
			node.is_boss_node = true
			node.troops = 35.0
			_boss_node = node

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
	_update_battle_readability_hud()
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

	if from_node.faction == BaseNode.Faction.PLAYER:
		if is_portal:
			AudioManager.play_portal()
		else:
			AudioManager.play_send()

	_update_stats_label()


func shake_camera(intensity: float = 3.2, duration: float = 0.15) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = duration
	_shake_time = duration


func is_game_ended() -> bool:
	return _game_ended


func get_nodes_by_faction(target_faction: BaseNode.Faction) -> Array[BaseNode]:
	var result: Array[BaseNode] = []
	for node in all_nodes:
		if is_instance_valid(node) and node.faction == target_faction:
			result.append(node)
	return result


func _process_boss_skill(delta: float) -> void:
	if _boss_node == null or not is_instance_valid(_boss_node) or not _boss_node.is_boss_node or _boss_node.faction != BaseNode.Faction.ENEMY:
		if boss_banner_label and boss_banner_label.visible:
			boss_banner_label.visible = false
		_boss_charging = false
		return

	if _boss_charging:
		_boss_charge_timer -= delta
		_boss_blink_time += delta * 14.0
		if boss_banner_label:
			var blink: float = 0.6 + 0.4 * sin(_boss_blink_time)
			boss_banner_label.modulate.a = blink
		if _boss_charge_timer <= 0.0:
			_execute_boss_skill()
	else:
		_boss_skill_timer += delta
		if _boss_skill_timer >= BOSS_SKILL_INTERVAL:
			_boss_skill_timer = 0.0
			_start_boss_charge()


func _start_boss_charge() -> void:
	_boss_charging = true
	_boss_charge_timer = BOSS_CHARGE_DURATION
	_boss_blink_time = 0.0
	if _boss_node and is_instance_valid(_boss_node):
		_boss_node.is_boss_charging = true
	if boss_banner_label:
		boss_banner_label.text = "BOSS SKILL: OVERGROWTH SURGE!"
		boss_banner_label.modulate.a = 1.0
		boss_banner_label.visible = true


func _execute_boss_skill() -> void:
	_boss_charging = false
	if boss_banner_label:
		boss_banner_label.visible = false
	if _boss_node == null or not is_instance_valid(_boss_node):
		return

	_boss_node.is_boss_charging = false
	_boss_node.troops = minf(float(_boss_node.max_troops), _boss_node.troops + BOSS_SUMMON_TROOPS)
	_boss_node.play_pulse(1.25)
	_boss_node.trigger_skill_burst(BaseNode.COLOR_BOSS_CRIMSON)
	_spawn_capture_particles(_boss_node.position, BaseNode.COLOR_BOSS_CRIMSON)
	AudioManager.play_boss_skill()
	shake_camera(4.0, 0.18)

	var surge_target: BaseNode = _pick_boss_surge_target()
	if surge_target != null:
		spawn_army(_boss_node, surge_target, BOSS_SURGE_RATIO)


func _pick_boss_surge_target() -> BaseNode:
	if _boss_node == null or not is_instance_valid(_boss_node):
		return null

	var best_non_enemy: BaseNode = null
	var best_dist: float = INF
	for neighbor in _boss_node.get_all_reachable_nodes():
		if not is_instance_valid(neighbor) or neighbor.faction == BaseNode.Faction.ENEMY:
			continue
		var d: float = _boss_node.position.distance_to(neighbor.position)
		if d < best_dist:
			best_dist = d
			best_non_enemy = neighbor

	if best_non_enemy != null:
		return best_non_enemy

	# Fallback if surrounded by ENEMY nodes: push toward ally closest to any PLAYER node
	var player_nodes: Array[BaseNode] = get_nodes_by_faction(BaseNode.Faction.PLAYER)
	var best_ally: BaseNode = null
	var best_player_dist: float = INF
	for neighbor in _boss_node.get_all_reachable_nodes():
		if not is_instance_valid(neighbor):
			continue
		for pnode in player_nodes:
			var d: float = neighbor.position.distance_to(pnode.position)
			if d < best_player_dist:
				best_player_dist = d
				best_ally = neighbor
	return best_ally


func _spawn_capture_particles(world_pos: Vector2, burst_color: Color) -> void:
	if vfx_layer == null:
		return
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.amount = 18
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 75.0
	particles.initial_velocity_max = 175.0
	particles.damping_min = 140.0
	particles.damping_max = 220.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = burst_color
	vfx_layer.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


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
	AudioManager.play_select()

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
	var best_dist: float = INF
	for node in all_nodes:
		if not is_instance_valid(node):
			continue
		var max_hit_dist: float = node.get_visual_radius() + TOUCH_SELECT_PADDING
		var dist: float = node.global_position.distance_to(world_pos)
		if dist <= max_hit_dist and dist < best_dist:
			best_dist = dist
			best_node = node
	return best_node


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _on_node_faction_changed(node: BaseNode, old_faction: BaseNode.Faction, new_faction: BaseNode.Faction) -> void:
	if old_faction == BaseNode.Faction.PLAYER and new_faction != BaseNode.Faction.PLAYER:
		_player_lost_base = true
		AudioManager.play_lost()
		_update_battle_readability_hud()
	elif new_faction == BaseNode.Faction.PLAYER:
		AudioManager.play_capture()

	if is_instance_valid(node):
		_spawn_capture_particles(node.position, node.get_faction_color(new_faction))
		shake_camera(3.2, 0.15)


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

	if boss_banner_label:
		boss_banner_label.visible = false
	if creature_manager:
		creature_manager.set_paused(true)
	_update_battle_readability_hud()
	_refresh_creature_hud()

	var time_secs: int = floori(_match_elapsed_time)
	var time_str: String = "%02d:%02d" % [time_secs / 60, time_secs % 60]

	if victory:
		AudioManager.play_victory()
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
			var habitat_ratio: float = SaveManager.get_habitat_essence_bonus_ratio()
			var bonus_essence: int = roundi(float(base_essence) * habitat_ratio)
			var total_essence: int = base_essence + bonus_essence

			SaveManager.record_campaign_victory(level_id, total_gold, total_essence)

			result_subtitle.text = "LV %d: %s Cleared! (%s)" % [level_id, level_name, time_str]
			reward_details_label.text = (
				"Base Clear: +%d Gold\n"
				+ "%s Capture All Nodes: +%d Gold\n"
				+ "%s No Base Lost: +%d Gold\n"
				+ "%s Fast Clear (<01:30): +%d Gold\n"
				+ "Total Earned: +%d Gold  |  +%d Essence (+%d Habitat)"
			) % [
				base_gold,
				"[OK]" if cap_all else "[--]", bonus_cap,
				"[OK]" if no_lost else "[--]", bonus_no_lost,
				"[OK]" if fast_clear else "[--]", bonus_fast,
				total_gold, total_essence, bonus_essence,
			]
			reward_details_label.visible = true
			next_level_btn.visible = level_id < CampaignData.TOTAL_LEVELS
			restart_button.text = "Replay"
		elif _is_boss_test_mode:
			result_subtitle.text = "Verdant Overlord Defeated! (%s)" % time_str
			reward_details_label.text = "Boss Practice Cleared!\n(Unlock LV 15 in Campaign to claim +300 Gold & +60 Essence)"
			reward_details_label.visible = true
			next_level_btn.visible = false
			restart_button.text = "Replay"
		else:
			SaveManager.record_sandbox_victory()
			result_subtitle.text = "All enemy realms conquered! (%s)" % time_str
			reward_details_label.text = "Sandbox Seed #%d (Tier %d) Cleared!" % [current_seed, current_tier]
			reward_details_label.visible = true
			next_level_btn.visible = false
			restart_button.text = "Replay"
	else:
		AudioManager.play_defeat()
		SaveManager.record_defeat()
		result_title.text = "DEFEAT"
		result_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42, 1.0))
		result_subtitle.text = "Your realms have fallen!"
		reward_details_label.text = "Match Time: %s\nTip: Use your Creature Skill to push the front!" % time_str
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
			tier_label.text = "BOSS" if bool(_current_level_info.get("is_boss", false)) else CampaignData.get_difficulty_label(_current_ai_difficulty)
	elif _is_boss_test_mode:
		if next_map_btn:
			next_map_btn.visible = false
		if tier_btn:
			tier_btn.visible = false
		if back_btn:
			back_btn.visible = true
		if seed_label:
			seed_label.text = "BOSS TEST - VERDANT OVERLORD"
		if tier_label:
			tier_label.text = "BOSS"
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


func _apply_safe_area_padding() -> void:
	var extra_top: float = 0.0
	var extra_bottom: float = 0.0
	var vp: Viewport = get_viewport()
	var vp_height: float = vp.get_visible_rect().size.y if vp != null else 1280.0
	if vp_height <= 0.0:
		vp_height = 1280.0

	var screen_size: Vector2i = DisplayServer.screen_get_size()
	if screen_size.y > 0:
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		if safe_area.size.y > 0:
			if safe_area.position.y > 0:
				var canvas_top_inset: float = (float(safe_area.position.y) / float(screen_size.y)) * vp_height
				extra_top = clampf(canvas_top_inset - BASE_TOP_MARGIN, 0.0, 36.0)
			var safe_bottom_px: int = maxi(0, screen_size.y - (safe_area.position.y + safe_area.size.y))
			if safe_bottom_px > 0:
				var canvas_bottom_inset: float = (float(safe_bottom_px) / float(screen_size.y)) * vp_height
				var cam_center_y: float = camera_2d.position.y if camera_2d else 640.0
				var max_bottom_for_play_area: float = maxf(0.0, (cam_center_y + vp_height * 0.5 + BASE_SKILL_BAR_TOP) - (PLAY_AREA.end.y + 24.0))
				var max_extra_bottom: float = minf(72.0, max_bottom_for_play_area)
				extra_bottom = clampf(canvas_bottom_inset - BASE_BOTTOM_MARGIN, 0.0, max_extra_bottom)

	var final_top_margin: int = roundi(BASE_TOP_MARGIN + extra_top)
	var final_bar_height: float = BASE_TOP_BAR_HEIGHT + extra_top
	var final_bottom_margin: int = roundi(BASE_BOTTOM_MARGIN + extra_bottom)
	var final_bottom_height: float = BASE_BOTTOM_BAR_HEIGHT + extra_bottom

	if top_margin:
		top_margin.add_theme_constant_override("margin_top", final_top_margin)
	if top_bar:
		top_bar.offset_bottom = final_bar_height
	if boss_banner_label:
		boss_banner_label.offset_top = final_bar_height + 4.0
		boss_banner_label.offset_bottom = final_bar_height + 36.0
	if bottom_margin:
		bottom_margin.add_theme_constant_override("margin_bottom", final_bottom_margin)
	if bottom_bar:
		bottom_bar.offset_top = -final_bottom_height
	if skill_bar:
		skill_bar.offset_top = BASE_SKILL_BAR_TOP - extra_bottom
		skill_bar.offset_bottom = BASE_SKILL_BAR_BOTTOM - extra_bottom


func _update_battle_readability_hud() -> void:
	if timer_label:
		var total_secs: int = floori(_match_elapsed_time)
		var mins: int = total_secs / 60
		var secs: int = total_secs % 60
		timer_label.text = "%02d:%02d / 01:30" % [mins, secs]
		if _match_elapsed_time < FAST_CLEAR_LIMIT_SEC:
			timer_label.add_theme_color_override("font_color", Color(0.38, 0.94, 0.72, 1.0))
		else:
			timer_label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.84, 1.0))

	if no_loss_label:
		if not _player_lost_base:
			no_loss_label.text = "NO LOSS"
			no_loss_label.add_theme_color_override("font_color", Color(0.42, 0.92, 0.58, 1.0))
		else:
			no_loss_label.text = "BASE LOST"
			no_loss_label.add_theme_color_override("font_color", Color(0.84, 0.52, 0.54, 1.0))

	if boss_gauge_box:
		var boss_alive: bool = (
			_boss_node != null
			and is_instance_valid(_boss_node)
			and _boss_node.is_boss_node
			and _boss_node.faction == BaseNode.Faction.ENEMY
		)
		boss_gauge_box.visible = boss_alive
		if boss_alive:
			if _boss_charging:
				if boss_gauge_bar:
					boss_gauge_bar.max_value = BOSS_CHARGE_DURATION
					boss_gauge_bar.value = clampf(BOSS_CHARGE_DURATION - _boss_charge_timer, 0.0, BOSS_CHARGE_DURATION)
				if boss_gauge_label:
					boss_gauge_label.text = "CHARGING! %ds" % maxi(1, ceili(_boss_charge_timer))
					boss_gauge_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.38, 1.0))
				if _style_boss_bar_fill:
					_style_boss_bar_fill.bg_color = Color(1.0, 0.25, 0.32, 1.0)
				boss_gauge_box.modulate.a = 1.0 if _game_ended else (0.55 + 0.45 * sin(_boss_blink_time))
			else:
				boss_gauge_box.modulate.a = 1.0
				if boss_gauge_bar:
					boss_gauge_bar.max_value = BOSS_SKILL_INTERVAL
					boss_gauge_bar.value = clampf(_boss_skill_timer, 0.0, BOSS_SKILL_INTERVAL)
				if boss_gauge_label:
					var rem_sec: int = maxi(1, ceili(BOSS_SKILL_INTERVAL - _boss_skill_timer))
					boss_gauge_label.text = "BOSS SURGE: %ds" % rem_sec
					boss_gauge_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.70, 1.0))
				if _style_boss_bar_fill:
					_style_boss_bar_fill.bg_color = Color(0.84, 0.22, 0.52, 1.0)
		else:
			boss_gauge_box.modulate.a = 1.0


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

	var style_boss_bar_bg := StyleBoxFlat.new()
	style_boss_bar_bg.bg_color = Color(0.14, 0.10, 0.18, 0.95)
	style_boss_bar_bg.border_color = Color(0.45, 0.26, 0.42, 0.9)
	style_boss_bar_bg.set_border_width_all(1)
	style_boss_bar_bg.set_corner_radius_all(6)

	_style_boss_bar_fill = StyleBoxFlat.new()
	_style_boss_bar_fill.bg_color = Color(0.84, 0.22, 0.52, 1.0)
	_style_boss_bar_fill.set_corner_radius_all(5)

	if boss_gauge_bar:
		boss_gauge_bar.add_theme_stylebox_override("background", style_boss_bar_bg)
		boss_gauge_bar.add_theme_stylebox_override("fill", _style_boss_bar_fill)


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
	if sfx_btn:
		sfx_btn.pressed.connect(_on_sfx_pressed)
	AudioManager.sfx_toggled.connect(_on_sfx_toggled)
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


func _refresh_sfx_button() -> void:
	if sfx_btn == null:
		return
	var enabled: bool = AudioManager.is_sfx_enabled()
	sfx_btn.text = "SFX: ON" if enabled else "SFX: OFF"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.36, 0.56, 0.95) if enabled else Color(0.16, 0.18, 0.24, 0.85)
	st.border_color = Color(0.45, 0.80, 1.0, 0.95) if enabled else Color(0.32, 0.36, 0.44, 0.8)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	sfx_btn.add_theme_stylebox_override("normal", st)
	sfx_btn.add_theme_stylebox_override("hover", st)
	sfx_btn.add_theme_stylebox_override("pressed", st)
	sfx_btn.add_theme_color_override("font_color", Color.WHITE if enabled else Color(0.65, 0.70, 0.78))


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
	AudioManager.play_skill()
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


func _on_sfx_pressed() -> void:
	AudioManager.toggle_sfx()


func _on_sfx_toggled(_enabled: bool) -> void:
	_refresh_sfx_button()


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
	elif _is_boss_test_mode:
		load_boss_test_level()
	else:
		load_generated_map(current_seed, current_tier, _current_ai_difficulty)


func _on_back_to_campaign_pressed() -> void:
	get_tree().change_scene_to_file(CAMPAIGN_SCENE_PATH)
