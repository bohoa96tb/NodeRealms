class_name GeometryBlueprints
extends RefCounted

# Anonymous normalized geometry blueprints (coordinates in [0.0, 1.0]).
# Tier 1: 4-7 nodes, single connected cluster.
# Tier 2: 7-10 nodes, single connected cluster with richer branching.
# Tier 3: 8-14 nodes, 2 separated clusters (triggers Portal linking).
# Tier 4: 12-20 nodes, 2-3 separated clusters (multi-Portal maps).

static func get_blueprints_for_tier(tier: int) -> Array[Dictionary]:
	var clamped_tier: int = clampi(tier, 1, 4)
	var result: Array[Dictionary] = []
	for bp in _get_all_blueprints():
		if bp["tier"] == clamped_tier:
			result.append(bp)
	return result


static func _get_all_blueprints() -> Array[Dictionary]:
	return [
		# --- TIER 1 (4 blueprints) ---
		{
			"id": "T1_01",
			"tier": 1,
			"strokes": [
				[Vector2(0.50, 0.08), Vector2(0.18, 0.50), Vector2(0.50, 0.92), Vector2(0.82, 0.50), Vector2(0.50, 0.08)],
				[Vector2(0.18, 0.50), Vector2(0.82, 0.50)],
			],
		},
		{
			"id": "T1_02",
			"tier": 1,
			"strokes": [
				[Vector2(0.20, 0.14), Vector2(0.80, 0.86)],
				[Vector2(0.80, 0.14), Vector2(0.20, 0.86)],
				[Vector2(0.20, 0.14), Vector2(0.80, 0.14)],
				[Vector2(0.20, 0.86), Vector2(0.80, 0.86)],
			],
		},
		{
			"id": "T1_03",
			"tier": 1,
			"strokes": [
				[Vector2(0.50, 0.08), Vector2(0.50, 0.92)],
				[Vector2(0.16, 0.34), Vector2(0.50, 0.48), Vector2(0.84, 0.34)],
				[Vector2(0.16, 0.66), Vector2(0.50, 0.52), Vector2(0.84, 0.66)],
			],
		},
		{
			"id": "T1_04",
			"tier": 1,
			"strokes": [
				[Vector2(0.50, 0.10), Vector2(0.16, 0.38), Vector2(0.24, 0.88), Vector2(0.76, 0.88), Vector2(0.84, 0.38), Vector2(0.50, 0.10)],
				[Vector2(0.16, 0.38), Vector2(0.76, 0.88)],
			],
		},

		# --- TIER 2 (4 blueprints) ---
		{
			"id": "T2_01",
			"tier": 2,
			"strokes": [
				[Vector2(0.50, 0.06), Vector2(0.16, 0.30), Vector2(0.50, 0.52), Vector2(0.84, 0.30), Vector2(0.50, 0.06)],
				[Vector2(0.50, 0.52), Vector2(0.16, 0.72), Vector2(0.50, 0.94), Vector2(0.84, 0.72), Vector2(0.50, 0.52)],
				[Vector2(0.16, 0.30), Vector2(0.16, 0.72)],
				[Vector2(0.84, 0.30), Vector2(0.84, 0.72)],
			],
		},
		{
			"id": "T2_02",
			"tier": 2,
			"strokes": [
				[Vector2(0.16, 0.12), Vector2(0.84, 0.12), Vector2(0.84, 0.88), Vector2(0.16, 0.88), Vector2(0.16, 0.12)],
				[Vector2(0.16, 0.12), Vector2(0.84, 0.88)],
				[Vector2(0.84, 0.12), Vector2(0.16, 0.88)],
				[Vector2(0.16, 0.50), Vector2(0.84, 0.50)],
			],
		},
		{
			"id": "T2_03",
			"tier": 2,
			"strokes": [
				[Vector2(0.50, 0.06), Vector2(0.14, 0.28), Vector2(0.14, 0.72), Vector2(0.50, 0.94), Vector2(0.86, 0.72), Vector2(0.86, 0.28), Vector2(0.50, 0.06)],
				[Vector2(0.14, 0.28), Vector2(0.50, 0.50), Vector2(0.86, 0.28)],
				[Vector2(0.14, 0.72), Vector2(0.50, 0.50), Vector2(0.86, 0.72)],
			],
		},
		{
			"id": "T2_04",
			"tier": 2,
			"strokes": [
				[Vector2(0.22, 0.08), Vector2(0.78, 0.24), Vector2(0.22, 0.44), Vector2(0.78, 0.64), Vector2(0.22, 0.86), Vector2(0.78, 0.94)],
				[Vector2(0.22, 0.08), Vector2(0.22, 0.44)],
				[Vector2(0.78, 0.24), Vector2(0.78, 0.64)],
				[Vector2(0.22, 0.44), Vector2(0.22, 0.86)],
				[Vector2(0.78, 0.64), Vector2(0.78, 0.94)],
			],
		},

		# --- TIER 3 (4 blueprints, 2 separated clusters) ---
		{
			"id": "T3_01",
			"tier": 3,
			"strokes": [
				# Upper cluster
				[Vector2(0.50, 0.06), Vector2(0.16, 0.24), Vector2(0.50, 0.40), Vector2(0.84, 0.24), Vector2(0.50, 0.06)],
				[Vector2(0.16, 0.24), Vector2(0.84, 0.24)],
				# Lower cluster
				[Vector2(0.50, 0.60), Vector2(0.16, 0.76), Vector2(0.50, 0.94), Vector2(0.84, 0.76), Vector2(0.50, 0.60)],
				[Vector2(0.16, 0.76), Vector2(0.84, 0.76)],
			],
		},
		{
			"id": "T3_02",
			"tier": 3,
			"strokes": [
				# Upper-left cluster
				[Vector2(0.14, 0.08), Vector2(0.62, 0.08), Vector2(0.42, 0.38), Vector2(0.14, 0.28), Vector2(0.14, 0.08)],
				[Vector2(0.14, 0.08), Vector2(0.42, 0.38)],
				# Lower-right cluster
				[Vector2(0.58, 0.62), Vector2(0.86, 0.72), Vector2(0.86, 0.92), Vector2(0.38, 0.92), Vector2(0.58, 0.62)],
				[Vector2(0.58, 0.62), Vector2(0.86, 0.92)],
			],
		},
		{
			"id": "T3_03",
			"tier": 3,
			"strokes": [
				# Upper arch cluster
				[Vector2(0.14, 0.34), Vector2(0.24, 0.10), Vector2(0.50, 0.06), Vector2(0.76, 0.10), Vector2(0.86, 0.34)],
				[Vector2(0.24, 0.10), Vector2(0.50, 0.28), Vector2(0.76, 0.10)],
				# Lower cross cluster
				[Vector2(0.20, 0.62), Vector2(0.80, 0.62), Vector2(0.50, 0.94), Vector2(0.20, 0.62)],
				[Vector2(0.50, 0.52), Vector2(0.50, 0.94)],
			],
		},
		{
			"id": "T3_04",
			"tier": 3,
			"strokes": [
				# Upper grid cluster
				[Vector2(0.18, 0.08), Vector2(0.82, 0.08), Vector2(0.82, 0.36), Vector2(0.18, 0.36), Vector2(0.18, 0.08)],
				[Vector2(0.50, 0.08), Vector2(0.50, 0.36)],
				# Lower trident cluster
				[Vector2(0.16, 0.64), Vector2(0.50, 0.56), Vector2(0.84, 0.64)],
				[Vector2(0.16, 0.64), Vector2(0.24, 0.92), Vector2(0.76, 0.92), Vector2(0.84, 0.64)],
				[Vector2(0.50, 0.56), Vector2(0.50, 0.78), Vector2(0.24, 0.92)],
				[Vector2(0.50, 0.78), Vector2(0.76, 0.92)],
			],
		},

		# --- TIER 4 (4 blueprints, 2-3 separated clusters) ---
		{
			"id": "T4_01",
			"tier": 4,
			"strokes": [
				# Top cluster
				[Vector2(0.50, 0.05), Vector2(0.18, 0.18), Vector2(0.50, 0.30), Vector2(0.82, 0.18), Vector2(0.50, 0.05)],
				# Middle cluster
				[Vector2(0.14, 0.44), Vector2(0.50, 0.44), Vector2(0.86, 0.44)],
				[Vector2(0.14, 0.56), Vector2(0.50, 0.56), Vector2(0.86, 0.56)],
				[Vector2(0.50, 0.44), Vector2(0.50, 0.56)],
				# Bottom cluster
				[Vector2(0.50, 0.70), Vector2(0.18, 0.82), Vector2(0.50, 0.95), Vector2(0.82, 0.82), Vector2(0.50, 0.70)],
			],
		},
		{
			"id": "T4_02",
			"tier": 4,
			"strokes": [
				# Top-left cluster
				[Vector2(0.12, 0.06), Vector2(0.46, 0.06), Vector2(0.46, 0.28), Vector2(0.12, 0.28), Vector2(0.12, 0.06)],
				[Vector2(0.12, 0.06), Vector2(0.46, 0.28)],
				# Center cluster
				[Vector2(0.50, 0.38), Vector2(0.20, 0.50), Vector2(0.50, 0.62), Vector2(0.80, 0.50), Vector2(0.50, 0.38)],
				[Vector2(0.20, 0.50), Vector2(0.80, 0.50)],
				# Bottom-right cluster
				[Vector2(0.54, 0.72), Vector2(0.88, 0.72), Vector2(0.88, 0.94), Vector2(0.54, 0.94), Vector2(0.54, 0.72)],
				[Vector2(0.88, 0.72), Vector2(0.54, 0.94)],
			],
		},
		{
			"id": "T4_03",
			"tier": 4,
			"strokes": [
				# Upper 6-node fortress
				[Vector2(0.16, 0.06), Vector2(0.50, 0.06), Vector2(0.84, 0.06)],
				[Vector2(0.16, 0.28), Vector2(0.50, 0.28), Vector2(0.84, 0.28)],
				[Vector2(0.16, 0.06), Vector2(0.16, 0.28)],
				[Vector2(0.50, 0.06), Vector2(0.50, 0.28)],
				[Vector2(0.84, 0.06), Vector2(0.84, 0.28)],
				# Middle twin-bar
				[Vector2(0.22, 0.46), Vector2(0.78, 0.46)],
				[Vector2(0.22, 0.58), Vector2(0.78, 0.58)],
				[Vector2(0.22, 0.46), Vector2(0.78, 0.58)],
				# Lower 5-node fortress
				[Vector2(0.16, 0.76), Vector2(0.50, 0.72), Vector2(0.84, 0.76), Vector2(0.74, 0.94), Vector2(0.26, 0.94), Vector2(0.16, 0.76)],
			],
		},
		{
			"id": "T4_04",
			"tier": 4,
			"strokes": [
				# Upper crown
				[Vector2(0.14, 0.12), Vector2(0.50, 0.06), Vector2(0.86, 0.12), Vector2(0.74, 0.30), Vector2(0.26, 0.30), Vector2(0.14, 0.12)],
				[Vector2(0.50, 0.06), Vector2(0.50, 0.20), Vector2(0.26, 0.30)],
				[Vector2(0.50, 0.20), Vector2(0.74, 0.30)],
				# Lower twin-islands
				[Vector2(0.12, 0.50), Vector2(0.40, 0.44), Vector2(0.32, 0.68), Vector2(0.12, 0.50)],
				[Vector2(0.60, 0.44), Vector2(0.88, 0.50), Vector2(0.68, 0.68), Vector2(0.60, 0.44)],
				# Bottom gate
				[Vector2(0.22, 0.84), Vector2(0.50, 0.78), Vector2(0.78, 0.84), Vector2(0.50, 0.95), Vector2(0.22, 0.84)],
			],
		},
	]
