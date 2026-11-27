class_name KingdomIsland
extends Control

var building_levels: Dictionary = {
	"castle": 1,
	"gold_mine": 1,
	"barracks": 1,
	"laboratory": 1,
	"habitat": 1,
}

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_building_levels(levels: Dictionary) -> void:
	building_levels = levels.duplicate()
	queue_redraw()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, TAU * 100.0)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 10.0 or h <= 10.0:
		return

	var cx: float = w * 0.5
	var bob: float = sin(_time * 1.8) * 4.0
	var cy: float = h * 0.56 + bob

	# Subtle starry sky backdrop
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.075, 0.118, 1.0))
	var star_positions := [
		Vector2(0.10, 0.16), Vector2(0.22, 0.10), Vector2(0.37, 0.22),
		Vector2(0.64, 0.12), Vector2(0.79, 0.20), Vector2(0.90, 0.14),
		Vector2(0.15, 0.78), Vector2(0.86, 0.80),
	]
	for i in range(star_positions.size()):
		var sp: Vector2 = star_positions[i]
		var twinkle: float = 0.35 + 0.45 * sin(_time * 2.2 + float(i) * 1.3)
		draw_circle(Vector2(sp.x * w, sp.y * h), 1.8, Color(0.75, 0.88, 1.0, twinkle))

	# Ambient island halo
	draw_circle(Vector2(cx, cy - 8.0), 155.0, Color(0.16, 0.34, 0.48, 0.14))

	# Floating rocky underside
	var rock_pts := PackedVector2Array([
		Vector2(cx - 245.0, cy + 8.0),
		Vector2(cx + 245.0, cy + 8.0),
		Vector2(cx + 185.0, cy + 56.0),
		Vector2(cx + 70.0, cy + 86.0),
		Vector2(cx - 50.0, cy + 92.0),
		Vector2(cx - 175.0, cy + 58.0),
	])
	draw_colored_polygon(rock_pts, Color(0.19, 0.22, 0.29, 1.0))
	var rock_shadow := PackedVector2Array([
		Vector2(cx, cy + 12.0),
		Vector2(cx + 245.0, cy + 8.0),
		Vector2(cx + 185.0, cy + 56.0),
		Vector2(cx + 70.0, cy + 86.0),
		Vector2(cx - 50.0, cy + 92.0),
	])
	draw_colored_polygon(rock_shadow, Color(0.13, 0.15, 0.21, 0.85))

	# Lush emerald island surface plateau
	var grass_pts := PackedVector2Array([
		Vector2(cx - 255.0, cy + 6.0),
		Vector2(cx - 200.0, cy - 34.0),
		Vector2(cx - 75.0, cy - 52.0),
		Vector2(cx + 75.0, cy - 52.0),
		Vector2(cx + 200.0, cy - 34.0),
		Vector2(cx + 255.0, cy + 6.0),
		Vector2(cx + 180.0, cy + 32.0),
		Vector2(cx, cy + 40.0),
		Vector2(cx - 180.0, cy + 32.0),
	])
	draw_colored_polygon(grass_pts, Color(0.16, 0.46, 0.30, 1.0))
	draw_polyline(grass_pts, Color(0.36, 0.78, 0.50, 0.85), 2.5, true)

	# Stylized trees around island rim
	_draw_tree(Vector2(cx - 210.0, cy - 10.0), 1.0)
	_draw_tree(Vector2(cx - 165.0, cy - 32.0), 0.85)
	_draw_tree(Vector2(cx + 210.0, cy - 8.0), 0.95)
	_draw_tree(Vector2(cx + 165.0, cy - 30.0), 0.82)
	_draw_tree(Vector2(cx - 35.0, cy + 26.0), 0.78)

	# Draw the 5 Kingdom buildings scaled by level (1..5)
	_draw_gold_mine(Vector2(cx - 150.0, cy - 12.0), int(building_levels.get("gold_mine", 1)))
	_draw_laboratory(Vector2(cx + 130.0, cy - 26.0), int(building_levels.get("laboratory", 1)))
	_draw_castle(Vector2(cx, cy - 32.0), int(building_levels.get("castle", 1)))
	_draw_barracks(Vector2(cx - 95.0, cy + 16.0), int(building_levels.get("barracks", 1)))
	_draw_habitat(Vector2(cx + 105.0, cy + 14.0), int(building_levels.get("habitat", 1)))


func _draw_tree(pos: Vector2, scale_f: float) -> void:
	draw_rect(Rect2(pos + Vector2(-2.5, -6.0) * scale_f, Vector2(5.0, 10.0) * scale_f), Color(0.38, 0.25, 0.16, 1.0))
	draw_circle(pos + Vector2(0.0, -14.0) * scale_f, 11.0 * scale_f, Color(0.14, 0.56, 0.34, 1.0))
	draw_circle(pos + Vector2(-4.0, -17.0) * scale_f, 7.0 * scale_f, Color(0.24, 0.70, 0.44, 0.9))


func _draw_castle(pos: Vector2, lv: int) -> void:
	var scale_h: float = 1.0 + float(lv - 1) * 0.12
	var glow: float = 0.25 + float(lv) * 0.15
	draw_circle(pos + Vector2(0.0, -24.0), 34.0 * scale_h, Color(0.35, 0.65, 1.0, glow * 0.35))

	# Main keep
	var keep_w: float = 42.0
	var keep_h: float = 36.0 * scale_h
	draw_rect(Rect2(pos.x - keep_w * 0.5, pos.y - keep_h, keep_w, keep_h), Color(0.46, 0.54, 0.68, 1.0))
	draw_rect(Rect2(pos.x - 7.0, pos.y - 16.0, 14.0, 16.0), Color(0.16, 0.20, 0.28, 1.0))

	# Side towers unlocked/grown with level
	if lv >= 2:
		var side_h: float = 28.0 + float(lv) * 4.0
		draw_rect(Rect2(pos.x - 32.0, pos.y - side_h, 14.0, side_h), Color(0.38, 0.46, 0.60, 1.0))
		draw_rect(Rect2(pos.x + 18.0, pos.y - side_h, 14.0, side_h), Color(0.38, 0.46, 0.60, 1.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x - 34.0, pos.y - side_h),
			Vector2(pos.x - 25.0, pos.y - side_h - 12.0),
			Vector2(pos.x - 16.0, pos.y - side_h),
		]), Color(0.22, 0.54, 0.88, 1.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(pos.x + 16.0, pos.y - side_h),
			Vector2(pos.x + 25.0, pos.y - side_h - 12.0),
			Vector2(pos.x + 34.0, pos.y - side_h),
		]), Color(0.22, 0.54, 0.88, 1.0))

	# Central spire
	var roof_pts := PackedVector2Array([
		Vector2(pos.x - 24.0, pos.y - keep_h),
		Vector2(pos.x, pos.y - keep_h - 18.0 - float(lv) * 2.0),
		Vector2(pos.x + 24.0, pos.y - keep_h),
	])
	draw_colored_polygon(roof_pts, Color(0.24, 0.58, 0.94, 1.0))
	if lv >= 4:
		draw_circle(Vector2(pos.x, pos.y - keep_h - 22.0 - float(lv) * 2.0), 4.5, Color(1.0, 0.88, 0.35, 1.0))

	_draw_level_pips(pos + Vector2(0.0, 8.0), lv, Color(0.45, 0.78, 1.0, 1.0))


func _draw_gold_mine(pos: Vector2, lv: int) -> void:
	var pulse: float = 0.7 + 0.3 * sin(_time * 3.0)
	draw_circle(pos + Vector2(0.0, -10.0), 18.0 + float(lv) * 2.5, Color(1.0, 0.78, 0.2, 0.14 * pulse))
	# Rock mound & mine arch
	draw_circle(pos + Vector2(0.0, -8.0), 17.0, Color(0.34, 0.32, 0.36, 1.0))
	draw_rect(Rect2(pos.x - 8.0, pos.y - 14.0, 16.0, 14.0), Color(0.12, 0.12, 0.15, 1.0))
	# Gold crystals proportional to level
	for i in range(lv):
		var offset_x: float = (float(i) - float(lv - 1) * 0.5) * 6.5
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(offset_x - 3.5, -12.0),
			pos + Vector2(offset_x, -22.0 - float(lv) * 1.5),
			pos + Vector2(offset_x + 3.5, -12.0),
		]), Color(1.0, 0.84, 0.25, 1.0))

	_draw_level_pips(pos + Vector2(0.0, 8.0), lv, Color(1.0, 0.82, 0.28, 1.0))


func _draw_barracks(pos: Vector2, lv: int) -> void:
	var w: float = 28.0 + float(lv) * 2.5
	var h: float = 18.0 + float(lv) * 2.0
	draw_rect(Rect2(pos.x - w * 0.5, pos.y - h, w, h), Color(0.48, 0.42, 0.40, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(pos.x - w * 0.55, pos.y - h),
		Vector2(pos.x, pos.y - h - 11.0),
		Vector2(pos.x + w * 0.55, pos.y - h),
	]), Color(0.84, 0.32, 0.28, 1.0))
	if lv >= 3:
		draw_line(Vector2(pos.x, pos.y - h - 11.0), Vector2(pos.x, pos.y - h - 22.0), Color.WHITE, 2.0)
		draw_rect(Rect2(pos.x, pos.y - h - 22.0, 9.0, 5.0), Color(1.0, 0.42, 0.36, 1.0))

	_draw_level_pips(pos + Vector2(0.0, 8.0), lv, Color(0.95, 0.45, 0.38, 1.0))


func _draw_laboratory(pos: Vector2, lv: int) -> void:
	var h: float = 22.0 + float(lv) * 3.5
	var orb_y: float = pos.y - h - 10.0 + sin(_time * 2.6) * 2.5
	draw_circle(Vector2(pos.x, orb_y), 14.0 + float(lv) * 2.0, Color(0.65, 0.42, 1.0, 0.24))
	draw_rect(Rect2(pos.x - 13.0, pos.y - h, 26.0, h), Color(0.36, 0.34, 0.52, 1.0))
	draw_circle(Vector2(pos.x, pos.y - h), 13.0, Color(0.55, 0.38, 0.85, 1.0))
	draw_circle(Vector2(pos.x, orb_y), 4.5 + float(lv) * 0.6, Color(0.55, 0.96, 1.0, 1.0))

	_draw_level_pips(pos + Vector2(0.0, 8.0), lv, Color(0.72, 0.52, 1.0, 1.0))


func _draw_habitat(pos: Vector2, lv: int) -> void:
	var pulse: float = 0.65 + 0.35 * sin(_time * 2.4 + 1.0)
	draw_circle(pos + Vector2(0.0, -6.0), 18.0 + float(lv) * 2.5, Color(0.22, 0.84, 0.58, 0.16 * pulse))
	draw_arc(pos + Vector2(0.0, -4.0), 16.0, 0.0, TAU, 24, Color(0.32, 0.88, 0.62, 0.9), 2.5, true)
	draw_circle(pos + Vector2(0.0, -10.0), 5.0 + float(lv) * 0.8, Color(0.42, 0.98, 0.72, 1.0))
	if lv >= 2:
		draw_circle(pos + Vector2(-12.0, -7.0), 3.5, Color(0.95, 0.55, 0.32, 0.95))
	if lv >= 4:
		draw_circle(pos + Vector2(12.0, -7.0), 3.5, Color(0.32, 0.85, 1.0, 0.95))

	_draw_level_pips(pos + Vector2(0.0, 8.0), lv, Color(0.32, 0.9, 0.66, 1.0))


func _draw_level_pips(center: Vector2, lv: int, color: Color) -> void:
	var total_w: float = float(lv - 1) * 6.0
	for i in range(lv):
		var p := Vector2(center.x - total_w * 0.5 + float(i) * 6.0, center.y)
		draw_circle(p, 2.1, color)
