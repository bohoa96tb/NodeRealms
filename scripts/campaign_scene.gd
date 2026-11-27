class_name CampaignScene
extends Control

const BATTLE_SCENE_PATH: String = "res://scenes/BattleScene.tscn"

@onready var realm_label: Label = $TopBar/TopMargin/TopRow/RealmVBox/RealmLabel
@onready var progress_label: Label = $TopBar/TopMargin/TopRow/RealmVBox/ProgressLabel
@onready var gold_label: Label = $TopBar/TopMargin/TopRow/ResourcesVBox/GoldLabel
@onready var essence_label: Label = $TopBar/TopMargin/TopRow/ResourcesVBox/EssenceLabel
@onready var level_grid: GridContainer = $CenterArea/GridCenter/LevelGrid
@onready var sandbox_btn: Button = $BottomBar/BottomMargin/BottomRow/SandboxBtn

var _style_completed: StyleBoxFlat
var _style_completed_hover: StyleBoxFlat
var _style_unlocked: StyleBoxFlat
var _style_unlocked_hover: StyleBoxFlat
var _style_locked: StyleBoxFlat
var _style_sandbox: StyleBoxFlat
var _style_sandbox_hover: StyleBoxFlat


class CheckmarkBadge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(24, 24)

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 11.0, Color(0.22, 0.78, 0.42, 1.0))
		draw_arc(center, 11.0, 0.0, TAU, 24, Color(0.75, 1.0, 0.82, 1.0), 1.5, true)
		var pts := PackedVector2Array([
			center + Vector2(-5.0, 0.5),
			center + Vector2(-1.5, 4.0),
			center + Vector2(5.5, -4.0),
		])
		draw_polyline(pts, Color.WHITE, 2.5, true)


func _ready() -> void:
	_setup_styles()
	_connect_signals()
	_refresh_header()
	_populate_level_grid()


func _setup_styles() -> void:
	_style_completed = StyleBoxFlat.new()
	_style_completed.bg_color = Color(0.12, 0.38, 0.24, 0.96)
	_style_completed.border_color = Color(0.36, 0.88, 0.54, 1.0)
	_style_completed.set_border_width_all(2)
	_style_completed.set_corner_radius_all(14)

	_style_completed_hover = _style_completed.duplicate() as StyleBoxFlat
	_style_completed_hover.bg_color = Color(0.16, 0.48, 0.30, 1.0)
	_style_completed_hover.border_color = Color(0.62, 1.0, 0.74, 1.0)

	_style_unlocked = StyleBoxFlat.new()
	_style_unlocked.bg_color = Color(0.16, 0.32, 0.56, 0.98)
	_style_unlocked.border_color = Color(1.0, 0.82, 0.28, 1.0)
	_style_unlocked.set_border_width_all(3)
	_style_unlocked.set_corner_radius_all(14)

	_style_unlocked_hover = _style_unlocked.duplicate() as StyleBoxFlat
	_style_unlocked_hover.bg_color = Color(0.22, 0.42, 0.70, 1.0)
	_style_unlocked_hover.border_color = Color(1.0, 0.92, 0.55, 1.0)

	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.12, 0.14, 0.19, 0.88)
	_style_locked.border_color = Color(0.24, 0.28, 0.36, 0.8)
	_style_locked.set_border_width_all(2)
	_style_locked.set_corner_radius_all(14)

	_style_sandbox = StyleBoxFlat.new()
	_style_sandbox.bg_color = Color(0.20, 0.25, 0.35, 0.96)
	_style_sandbox.border_color = Color(0.45, 0.72, 0.95, 0.95)
	_style_sandbox.set_border_width_all(2)
	_style_sandbox.set_corner_radius_all(14)

	_style_sandbox_hover = _style_sandbox.duplicate() as StyleBoxFlat
	_style_sandbox_hover.bg_color = Color(0.26, 0.34, 0.48, 1.0)
	_style_sandbox_hover.border_color = Color(0.68, 0.88, 1.0, 1.0)

	if sandbox_btn:
		sandbox_btn.add_theme_stylebox_override("normal", _style_sandbox)
		sandbox_btn.add_theme_stylebox_override("hover", _style_sandbox_hover)
		sandbox_btn.add_theme_stylebox_override("pressed", _style_sandbox_hover)
		sandbox_btn.add_theme_stylebox_override("focus", _style_sandbox)


func _connect_signals() -> void:
	if sandbox_btn:
		sandbox_btn.pressed.connect(_on_sandbox_pressed)


func _refresh_header() -> void:
	if realm_label:
		realm_label.text = CampaignData.REALM_NAME
	if gold_label:
		gold_label.text = "GOLD: %d" % SaveManager.get_gold()
	if essence_label:
		essence_label.text = "ESSENCE: %d" % SaveManager.get_essence()

	var completed_count: int = 0
	for lvl in CampaignData.get_all_levels():
		if SaveManager.is_level_completed(int(lvl["level_id"])):
			completed_count += 1

	if progress_label:
		progress_label.text = "CAMPAIGN  %d / %d CLEARED" % [completed_count, CampaignData.TOTAL_LEVELS]


func _populate_level_grid() -> void:
	for child in level_grid.get_children():
		level_grid.remove_child(child)
		child.queue_free()

	var unlocked_level: int = SaveManager.get_unlocked_level()
	for level_info in CampaignData.get_all_levels():
		var level_id: int = int(level_info["level_id"])
		var is_completed: bool = SaveManager.is_level_completed(level_id)
		var is_unlocked: bool = level_id <= unlocked_level or is_completed

		var card := Button.new()
		card.custom_minimum_size = Vector2(204, 154)
		card.focus_mode = Control.FOCUS_NONE
		card.clip_contents = true

		if is_completed:
			card.add_theme_stylebox_override("normal", _style_completed)
			card.add_theme_stylebox_override("hover", _style_completed_hover)
			card.add_theme_stylebox_override("pressed", _style_completed_hover)
		elif is_unlocked:
			card.add_theme_stylebox_override("normal", _style_unlocked)
			card.add_theme_stylebox_override("hover", _style_unlocked_hover)
			card.add_theme_stylebox_override("pressed", _style_unlocked_hover)
		else:
			card.disabled = true
			card.add_theme_stylebox_override("disabled", _style_locked)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)

		var header_row := HBoxContainer.new()
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(header_row)

		var lv_lbl := Label.new()
		lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv_lbl.text = "LV %d" % level_id
		lv_lbl.add_theme_font_size_override("font_size", 22)
		lv_lbl.add_theme_color_override(
			"font_color",
			Color(0.65, 0.98, 0.76) if is_completed else (Color(1.0, 0.88, 0.45) if is_unlocked else Color(0.45, 0.5, 0.58))
		)
		header_row.add_child(lv_lbl)

		if is_completed:
			var badge := CheckmarkBadge.new()
			header_row.add_child(badge)

		var name_lbl := Label.new()
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		if is_unlocked:
			name_lbl.text = str(level_info["name"])
			name_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		else:
			name_lbl.text = "[Locked]"
			name_lbl.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
		vbox.add_child(name_lbl)

		var meta_lbl := Label.new()
		meta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta_lbl.add_theme_font_size_override("font_size", 13)
		if is_unlocked:
			var diff_str: String = CampaignData.get_difficulty_label(level_info["ai_difficulty"])
			meta_lbl.text = "T%d  |  %s" % [int(level_info["tier"]), diff_str]
			meta_lbl.add_theme_color_override("font_color", Color(0.66, 0.78, 0.92))
		else:
			meta_lbl.text = "Clear LV %d" % maxi(1, level_id - 1)
			meta_lbl.add_theme_color_override("font_color", Color(0.38, 0.42, 0.5))
		vbox.add_child(meta_lbl)

		if is_unlocked:
			card.pressed.connect(_on_level_selected.bind(level_id))

		level_grid.add_child(card)


func _on_level_selected(level_id: int) -> void:
	SaveManager.start_campaign_level(level_id)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_sandbox_pressed() -> void:
	SaveManager.start_sandbox_mode()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
