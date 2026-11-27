class_name MainHub
extends Control

const BATTLE_SCENE_PATH: String = "res://scenes/BattleScene.tscn"

enum HubTab { CAMPAIGN, CREATURES, KINGDOM }

@onready var kingdom_lv_label: Label = $TopBar/TopMargin/TopRow/RealmVBox/KingdomLvLabel
@onready var gold_label: Label = $TopBar/TopMargin/TopRow/ResourcesVBox/GoldLabel
@onready var essence_label: Label = $TopBar/TopMargin/TopRow/ResourcesVBox/EssenceLabel

@onready var campaign_tab: Control = $ContentArea/CampaignTab
@onready var level_grid: GridContainer = $ContentArea/CampaignTab/CampaignVBox/GridCenter/LevelGrid
@onready var sandbox_btn: Button = $ContentArea/CampaignTab/CampaignVBox/SandboxCenter/SandboxBtn

@onready var creatures_tab: Control = $ContentArea/CreaturesTab
@onready var creatures_list: VBoxContainer = $ContentArea/CreaturesTab/CreaturesScroll/CreaturesList

@onready var kingdom_tab: Control = $ContentArea/KingdomTab
@onready var kingdom_island: KingdomIsland = $ContentArea/KingdomTab/KingdomIsland
@onready var buildings_list: VBoxContainer = $ContentArea/KingdomTab/BuildingsScroll/BuildingsMargin/BuildingsList

@onready var tab_campaign_btn: Button = $BottomTabBar/TabMargin/TabRow/TabCampaignBtn
@onready var tab_creatures_btn: Button = $BottomTabBar/TabMargin/TabRow/TabCreaturesBtn
@onready var tab_kingdom_btn: Button = $BottomTabBar/TabMargin/TabRow/TabKingdomBtn

var _current_tab: HubTab = HubTab.CAMPAIGN
var _mine_refresh_timer: float = 0.0
var _mine_claim_btn: Button = null

var _style_completed: StyleBoxFlat
var _style_completed_hover: StyleBoxFlat
var _style_unlocked: StyleBoxFlat
var _style_unlocked_hover: StyleBoxFlat
var _style_locked: StyleBoxFlat
var _style_sandbox: StyleBoxFlat
var _style_sandbox_hover: StyleBoxFlat
var _style_tab_normal: StyleBoxFlat
var _style_tab_active: StyleBoxFlat


class CheckmarkBadge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 10.0, Color(0.22, 0.78, 0.42, 1.0))
		draw_arc(center, 10.0, 0.0, TAU, 24, Color(0.75, 1.0, 0.82, 1.0), 1.5, true)
		var pts := PackedVector2Array([
			center + Vector2(-4.5, 0.5),
			center + Vector2(-1.2, 3.8),
			center + Vector2(5.0, -3.5),
		])
		draw_polyline(pts, Color.WHITE, 2.4, true)


class CreatureEmblem extends Control:
	var element: CreatureData.Element = CreatureData.Element.FIRE
	var primary_color: Color = Color.ORANGE_RED
	var border_color: Color = Color.GOLD

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(72, 72)

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 32.0, Color(primary_color.r, primary_color.g, primary_color.b, 0.22))
		draw_arc(center, 32.0, 0.0, TAU, 36, border_color, 2.5, true)

		match element:
			CreatureData.Element.FIRE:
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(0.0, -20.0),
					center + Vector2(16.0, 4.0),
					center + Vector2(0.0, 20.0),
					center + Vector2(-16.0, 4.0),
				]), primary_color)
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(0.0, -10.0),
					center + Vector2(7.0, 4.0),
					center + Vector2(0.0, 12.0),
					center + Vector2(-7.0, 4.0),
				]), Color(1.0, 0.86, 0.42, 1.0))
			CreatureData.Element.WATER:
				draw_circle(center + Vector2(0.0, 4.0), 14.0, primary_color)
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(0.0, -19.0),
					center + Vector2(13.0, 2.0),
					center + Vector2(-13.0, 2.0),
				]), primary_color)
				draw_arc(center + Vector2(0.0, 4.0), 8.0, 0.0, PI, 18, Color(0.8, 1.0, 1.0, 0.9), 2.5, true)
			CreatureData.Element.NATURE:
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(0.0, -20.0),
					center + Vector2(17.0, -2.0),
					center + Vector2(0.0, 18.0),
					center + Vector2(-17.0, -2.0),
				]), primary_color)
				draw_line(center + Vector2(0.0, -14.0), center + Vector2(0.0, 18.0), Color(0.85, 1.0, 0.88, 0.9), 2.5)
			CreatureData.Element.EARTH:
				var hex := PackedVector2Array()
				for i in range(6):
					var ang: float = float(i) * TAU / 6.0 - PI * 0.5
					hex.append(center + Vector2.from_angle(ang) * 18.0)
				draw_colored_polygon(hex, primary_color)
				draw_arc(center, 9.0, 0.0, TAU, 24, border_color, 2.5, true)


func _ready() -> void:
	_setup_styles()
	_connect_signals()
	_refresh_top_bar()
	_populate_campaign_grid()
	_populate_creatures_list()
	_populate_kingdom_tab()

	var start_tab: int = clampi(SaveManager.last_hub_tab, 0, 2)
	_switch_tab(start_tab as HubTab)


func _process(delta: float) -> void:
	if _current_tab == HubTab.KINGDOM:
		_mine_refresh_timer += delta
		if _mine_refresh_timer >= 1.0:
			_mine_refresh_timer = 0.0
			_refresh_mine_claim_button()


func _setup_styles() -> void:
	_style_completed = StyleBoxFlat.new()
	_style_completed.bg_color = Color(0.12, 0.38, 0.24, 0.96)
	_style_completed.border_color = Color(0.36, 0.88, 0.54, 1.0)
	_style_completed.set_border_width_all(2)
	_style_completed.set_corner_radius_all(12)

	_style_completed_hover = _style_completed.duplicate() as StyleBoxFlat
	_style_completed_hover.bg_color = Color(0.16, 0.48, 0.30, 1.0)
	_style_completed_hover.border_color = Color(0.62, 1.0, 0.74, 1.0)

	_style_unlocked = StyleBoxFlat.new()
	_style_unlocked.bg_color = Color(0.16, 0.32, 0.56, 0.98)
	_style_unlocked.border_color = Color(1.0, 0.82, 0.28, 1.0)
	_style_unlocked.set_border_width_all(3)
	_style_unlocked.set_corner_radius_all(12)

	_style_unlocked_hover = _style_unlocked.duplicate() as StyleBoxFlat
	_style_unlocked_hover.bg_color = Color(0.22, 0.42, 0.70, 1.0)
	_style_unlocked_hover.border_color = Color(1.0, 0.92, 0.55, 1.0)

	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.12, 0.14, 0.19, 0.88)
	_style_locked.border_color = Color(0.24, 0.28, 0.36, 0.8)
	_style_locked.set_border_width_all(2)
	_style_locked.set_corner_radius_all(12)

	_style_sandbox = StyleBoxFlat.new()
	_style_sandbox.bg_color = Color(0.20, 0.25, 0.35, 0.96)
	_style_sandbox.border_color = Color(0.45, 0.72, 0.95, 0.95)
	_style_sandbox.set_border_width_all(2)
	_style_sandbox.set_corner_radius_all(12)

	_style_sandbox_hover = _style_sandbox.duplicate() as StyleBoxFlat
	_style_sandbox_hover.bg_color = Color(0.26, 0.34, 0.48, 1.0)
	_style_sandbox_hover.border_color = Color(0.68, 0.88, 1.0, 1.0)

	_style_tab_normal = StyleBoxFlat.new()
	_style_tab_normal.bg_color = Color(0.12, 0.16, 0.23, 0.95)
	_style_tab_normal.border_color = Color(0.26, 0.34, 0.46, 0.9)
	_style_tab_normal.set_border_width_all(2)
	_style_tab_normal.set_corner_radius_all(12)

	_style_tab_active = StyleBoxFlat.new()
	_style_tab_active.bg_color = Color(0.18, 0.50, 0.84, 1.0)
	_style_tab_active.border_color = Color(0.65, 0.90, 1.0, 1.0)
	_style_tab_active.set_border_width_all(3)
	_style_tab_active.set_corner_radius_all(12)

	if sandbox_btn:
		sandbox_btn.add_theme_stylebox_override("normal", _style_sandbox)
		sandbox_btn.add_theme_stylebox_override("hover", _style_sandbox_hover)
		sandbox_btn.add_theme_stylebox_override("pressed", _style_sandbox_hover)
		sandbox_btn.add_theme_stylebox_override("focus", _style_sandbox)


func _connect_signals() -> void:
	if sandbox_btn:
		sandbox_btn.pressed.connect(_on_sandbox_pressed)
	if tab_campaign_btn:
		tab_campaign_btn.pressed.connect(_switch_tab.bind(HubTab.CAMPAIGN))
	if tab_creatures_btn:
		tab_creatures_btn.pressed.connect(_switch_tab.bind(HubTab.CREATURES))
	if tab_kingdom_btn:
		tab_kingdom_btn.pressed.connect(_switch_tab.bind(HubTab.KINGDOM))


func _switch_tab(tab: HubTab) -> void:
	_current_tab = tab
	SaveManager.last_hub_tab = int(tab)

	if campaign_tab:
		campaign_tab.visible = (tab == HubTab.CAMPAIGN)
	if creatures_tab:
		creatures_tab.visible = (tab == HubTab.CREATURES)
	if kingdom_tab:
		kingdom_tab.visible = (tab == HubTab.KINGDOM)

	var buttons := [tab_campaign_btn, tab_creatures_btn, tab_kingdom_btn]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		if btn == null:
			continue
		var is_active: bool = (i == int(tab))
		var style: StyleBoxFlat = _style_tab_active if is_active else _style_tab_normal
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)
		btn.add_theme_color_override("font_color", Color.WHITE if is_active else Color(0.70, 0.78, 0.88, 1.0))

	if tab == HubTab.CREATURES:
		_populate_creatures_list()
	elif tab == HubTab.KINGDOM:
		_populate_kingdom_tab()


func _refresh_top_bar() -> void:
	var castle_lv: int = SaveManager.get_building_level("castle")
	var completed_count: int = 0
	for lvl in CampaignData.get_all_levels():
		if SaveManager.is_level_completed(int(lvl["level_id"])):
			completed_count += 1

	if kingdom_lv_label:
		kingdom_lv_label.text = "KINGDOM LV %d  |  %s (%d/%d)" % [
			castle_lv,
			CampaignData.REALM_NAME,
			completed_count,
			CampaignData.TOTAL_LEVELS,
		]
	if gold_label:
		gold_label.text = "GOLD: %d" % SaveManager.get_gold()
	if essence_label:
		essence_label.text = "ESSENCE: %d" % SaveManager.get_essence()


func _populate_campaign_grid() -> void:
	_clear_children(level_grid)

	var unlocked_level: int = SaveManager.get_unlocked_level()
	for level_info in CampaignData.get_all_levels():
		var level_id: int = int(level_info["level_id"])
		var is_completed: bool = SaveManager.is_level_completed(level_id)
		var is_unlocked: bool = level_id <= unlocked_level or is_completed

		var card := Button.new()
		card.custom_minimum_size = Vector2(204, 146)
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
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		card.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)
		margin.add_child(vbox)

		var header_row := HBoxContainer.new()
		header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(header_row)

		var lv_lbl := Label.new()
		lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv_lbl.text = "LV %d" % level_id
		lv_lbl.add_theme_font_size_override("font_size", 21)
		lv_lbl.add_theme_color_override(
			"font_color",
			Color(0.65, 0.98, 0.76) if is_completed else (Color(1.0, 0.88, 0.45) if is_unlocked else Color(0.45, 0.5, 0.58))
		)
		header_row.add_child(lv_lbl)

		if is_completed:
			header_row.add_child(CheckmarkBadge.new())

		var name_lbl := Label.new()
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
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
		meta_lbl.add_theme_font_size_override("font_size", 12)
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


func _populate_creatures_list() -> void:
	_clear_children(creatures_list)

	var equipped_id: String = SaveManager.get_equipped_creature()
	var current_essence: int = SaveManager.get_essence()

	for cid in CreatureData.CREATURE_ORDER:
		var lv: int = SaveManager.get_creature_level(cid)
		var creature: Dictionary = CreatureData.get_creature(cid)
		var is_equipped: bool = (cid == equipped_id)
		var elem_color: Color = creature["color"]
		var border_color: Color = creature["border_color"]

		var card_panel := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.11, 0.145, 0.215, 0.96)
		card_style.border_color = border_color if is_equipped else Color(0.26, 0.34, 0.46, 0.85)
		card_style.set_border_width_all(3 if is_equipped else 2)
		card_style.set_corner_radius_all(14)
		card_panel.add_theme_stylebox_override("panel", card_style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 14)
		card_panel.add_child(margin)

		var main_row := HBoxContainer.new()
		main_row.add_theme_constant_override("separation", 16)
		margin.add_child(main_row)

		var emblem_center := CenterContainer.new()
		main_row.add_child(emblem_center)

		var emblem := CreatureEmblem.new()
		emblem.element = creature["element"]
		emblem.primary_color = elem_color
		emblem.border_color = border_color
		emblem_center.add_child(emblem)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 8)
		main_row.add_child(info_vbox)

		# Title row: Name + Element + LV X/5
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		info_vbox.add_child(top_row)

		var name_lbl := Label.new()
		name_lbl.text = str(creature["name"])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 21)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
		top_row.add_child(name_lbl)

		var elem_lbl := Label.new()
		elem_lbl.text = str(creature["element_name"])
		elem_lbl.add_theme_font_size_override("font_size", 14)
		elem_lbl.add_theme_color_override("font_color", border_color)
		top_row.add_child(elem_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text = "LV %d/%d" % [lv, CreatureData.MAX_CREATURE_LEVEL]
		lv_lbl.add_theme_font_size_override("font_size", 16)
		lv_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42))
		top_row.add_child(lv_lbl)

		# Skill description at current level
		var desc_lbl := Label.new()
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.text = CreatureData.get_skill_description(cid, lv)
		desc_lbl.add_theme_font_size_override("font_size", 15)
		desc_lbl.add_theme_color_override("font_color", Color(0.76, 0.85, 0.94))
		info_vbox.add_child(desc_lbl)

		# Action buttons row
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 12)
		info_vbox.add_child(btn_row)

		var equip_btn := Button.new()
		equip_btn.custom_minimum_size = Vector2(150, 46)
		equip_btn.focus_mode = Control.FOCUS_NONE
		equip_btn.add_theme_font_size_override("font_size", 16)
		if is_equipped:
			equip_btn.text = "Equipped [OK]"
			equip_btn.disabled = true
			var eq_style := StyleBoxFlat.new()
			eq_style.bg_color = Color(0.16, 0.48, 0.30, 0.98)
			eq_style.border_color = Color(0.45, 0.95, 0.65, 1.0)
			eq_style.set_border_width_all(2)
			eq_style.set_corner_radius_all(10)
			equip_btn.add_theme_stylebox_override("disabled", eq_style)
			equip_btn.add_theme_color_override("font_disabled_color", Color.WHITE)
		else:
			equip_btn.text = "Equip"
			var norm_eq := _make_action_button_style(Color(0.18, 0.36, 0.60, 0.95), Color(0.45, 0.72, 0.98, 1.0))
			equip_btn.add_theme_stylebox_override("normal", norm_eq)
			equip_btn.add_theme_stylebox_override("hover", norm_eq)
			equip_btn.add_theme_stylebox_override("pressed", norm_eq)
			equip_btn.add_theme_color_override("font_color", Color.WHITE)
			equip_btn.pressed.connect(_on_equip_creature.bind(cid))
		btn_row.add_child(equip_btn)

		var upgrade_btn := Button.new()
		upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_btn.custom_minimum_size = Vector2(0, 46)
		upgrade_btn.focus_mode = Control.FOCUS_NONE
		upgrade_btn.add_theme_font_size_override("font_size", 15)

		var cost: int = CreatureData.get_upgrade_cost(lv)
		if cost < 0:
			upgrade_btn.text = "MAX LEVEL"
			upgrade_btn.disabled = true
			var max_style := _make_action_button_style(Color(0.24, 0.28, 0.34, 0.8), Color(0.48, 0.55, 0.64, 0.8))
			upgrade_btn.add_theme_stylebox_override("disabled", max_style)
			upgrade_btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.9, 0.95))
		elif current_essence >= cost:
			upgrade_btn.text = "Upgrade (%d Essence)" % cost
			var up_style := _make_action_button_style(Color(0.10, 0.56, 0.50, 0.96), Color(0.36, 0.94, 0.82, 1.0))
			upgrade_btn.add_theme_stylebox_override("normal", up_style)
			upgrade_btn.add_theme_stylebox_override("hover", up_style)
			upgrade_btn.add_theme_stylebox_override("pressed", up_style)
			upgrade_btn.add_theme_color_override("font_color", Color.WHITE)
			upgrade_btn.pressed.connect(_on_upgrade_creature.bind(cid))
		else:
			upgrade_btn.text = "Upgrade (%d Essence)" % cost
			upgrade_btn.disabled = true
			var dis_style := _make_action_button_style(Color(0.14, 0.16, 0.22, 0.85), Color(0.26, 0.30, 0.38, 0.7))
			upgrade_btn.add_theme_stylebox_override("disabled", dis_style)
			upgrade_btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.56, 0.64))
		btn_row.add_child(upgrade_btn)

		creatures_list.add_child(card_panel)


func _populate_kingdom_tab() -> void:
	var levels: Dictionary = {}
	for bid in KingdomData.BUILDING_ORDER:
		levels[bid] = SaveManager.get_building_level(bid)
	if kingdom_island:
		kingdom_island.set_building_levels(levels)

	_clear_children(buildings_list)
	_mine_claim_btn = null

	for bid in KingdomData.BUILDING_ORDER:
		var b_info: Dictionary = KingdomData.get_building(bid)
		var lv: int = int(levels[bid])
		var accent: Color = b_info["color"]

		var card_panel := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.11, 0.145, 0.215, 0.96)
		card_style.border_color = Color(accent.r, accent.g, accent.b, 0.65)
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(12)
		card_panel.add_theme_stylebox_override("panel", card_style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 10)
		card_panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 10)
		vbox.add_child(top_row)

		var name_lbl := Label.new()
		name_lbl.text = str(b_info["name"])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 19)
		name_lbl.add_theme_color_override("font_color", accent)
		top_row.add_child(name_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text = "LV %d/%d" % [lv, KingdomData.MAX_BUILDING_LEVEL]
		lv_lbl.add_theme_font_size_override("font_size", 16)
		lv_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
		top_row.add_child(lv_lbl)

		var effect_lbl := Label.new()
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect_lbl.text = "%s  -  %s" % [KingdomData.get_effect_text(bid, lv), str(b_info["summary"])]
		effect_lbl.add_theme_font_size_override("font_size", 13)
		effect_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90))
		vbox.add_child(effect_lbl)

		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 10)
		vbox.add_child(btn_row)

		if bid == "gold_mine":
			var claim_btn := Button.new()
			claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			claim_btn.custom_minimum_size = Vector2(0, 42)
			claim_btn.focus_mode = Control.FOCUS_NONE
			claim_btn.add_theme_font_size_override("font_size", 15)
			claim_btn.pressed.connect(_on_claim_mine_pressed)
			btn_row.add_child(claim_btn)
			_mine_claim_btn = claim_btn
			_refresh_mine_claim_button()

		var upgrade_btn := Button.new()
		upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_btn.custom_minimum_size = Vector2(0, 42)
		upgrade_btn.focus_mode = Control.FOCUS_NONE
		upgrade_btn.add_theme_font_size_override("font_size", 15)

		var cost: int = KingdomData.get_upgrade_cost(lv)
		var check: Dictionary = SaveManager.can_upgrade_building(bid)
		if cost < 0:
			upgrade_btn.text = "MAX"
			upgrade_btn.disabled = true
			var max_style := _make_action_button_style(Color(0.24, 0.28, 0.34, 0.8), Color(0.48, 0.55, 0.64, 0.8))
			upgrade_btn.add_theme_stylebox_override("disabled", max_style)
			upgrade_btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.9, 0.95))
		elif check["ok"]:
			upgrade_btn.text = "Upgrade (%d Gold)" % cost
			var up_style := _make_action_button_style(Color(0.62, 0.45, 0.12, 0.96), Color(1.0, 0.82, 0.28, 1.0))
			upgrade_btn.add_theme_stylebox_override("normal", up_style)
			upgrade_btn.add_theme_stylebox_override("hover", up_style)
			upgrade_btn.add_theme_stylebox_override("pressed", up_style)
			upgrade_btn.add_theme_color_override("font_color", Color.WHITE)
			upgrade_btn.pressed.connect(_on_upgrade_building.bind(bid))
		else:
			var reason: String = str(check["reason"])
			upgrade_btn.text = reason if reason.begins_with("Need Castle") else ("Upgrade (%d Gold)" % cost)
			upgrade_btn.disabled = true
			var dis_style := _make_action_button_style(Color(0.14, 0.16, 0.22, 0.85), Color(0.26, 0.30, 0.38, 0.7))
			upgrade_btn.add_theme_stylebox_override("disabled", dis_style)
			upgrade_btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.68))

		btn_row.add_child(upgrade_btn)
		buildings_list.add_child(card_panel)


func _refresh_mine_claim_button() -> void:
	if _mine_claim_btn == null or not is_instance_valid(_mine_claim_btn):
		return
	var pending: int = SaveManager.get_pending_mine_gold()
	_mine_claim_btn.text = "Claim (+%d Gold)" % pending
	if pending > 0:
		_mine_claim_btn.disabled = false
		var st := _make_action_button_style(Color(0.16, 0.56, 0.32, 0.96), Color(0.45, 0.94, 0.62, 1.0))
		_mine_claim_btn.add_theme_stylebox_override("normal", st)
		_mine_claim_btn.add_theme_stylebox_override("hover", st)
		_mine_claim_btn.add_theme_stylebox_override("pressed", st)
		_mine_claim_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		_mine_claim_btn.disabled = true
		var dis := _make_action_button_style(Color(0.14, 0.16, 0.22, 0.85), Color(0.26, 0.30, 0.38, 0.7))
		_mine_claim_btn.add_theme_stylebox_override("disabled", dis)
		_mine_claim_btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.68))


func _make_action_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	return st


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_level_selected(level_id: int) -> void:
	SaveManager.start_campaign_level(level_id)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_sandbox_pressed() -> void:
	SaveManager.start_sandbox_mode()
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _on_equip_creature(creature_id: String) -> void:
	SaveManager.set_equipped_creature(creature_id)
	_populate_creatures_list()


func _on_upgrade_creature(creature_id: String) -> void:
	if SaveManager.upgrade_creature(creature_id):
		_refresh_top_bar()
		_populate_creatures_list()


func _on_upgrade_building(building_id: String) -> void:
	if SaveManager.upgrade_building(building_id):
		_refresh_top_bar()
		_populate_kingdom_tab()


func _on_claim_mine_pressed() -> void:
	var claimed: int = SaveManager.claim_mine_gold()
	if claimed > 0:
		_refresh_top_bar()
		_populate_kingdom_tab()
