class_name MapGenerator
extends RefCounted

const MERGE_DISTANCE_PX: float = 90.0
const EDGE_THROUGH_NODE_PX: float = 28.0
const MAX_VALIDATION_RETRIES: int = 20
const STARTING_FACTION_TROOPS: float = 20.0
const NEUTRAL_TROOPS_MIN: int = 8
const NEUTRAL_TROOPS_MAX: int = 16


func generate_map(seed_value: int, tier: int, play_area: Rect2) -> Dictionary:
	var clamped_tier: int = clampi(tier, 1, 4)

	for attempt in range(MAX_VALIDATION_RETRIES):
		var current_seed: int = seed_value + attempt
		var candidate: Dictionary = _build_candidate_map(current_seed, clamped_tier, play_area)
		var validation: Dictionary = MapValidator.validate_map(candidate)
		if validation["valid"]:
			candidate["validation"] = validation
			return candidate

	# Fallback to deterministic safe map if all retries somehow fail
	return _build_fallback_map(seed_value, clamped_tier, play_area)


func _build_candidate_map(seed_value: int, tier: int, play_area: Rect2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value)

	var pool: Array[Dictionary] = GeometryBlueprints.get_blueprints_for_tier(tier)
	var blueprint: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]

	var flip_x: bool = rng.randf() < 0.5
	var flip_y: bool = rng.randf() < 0.5
	var rot_angle: float = rng.randf_range(-0.16, 0.16)
	var scale_x: float = rng.randf_range(0.92, 1.0)
	var scale_y: float = rng.randf_range(0.92, 1.0)
	var jitter: Vector2 = Vector2(rng.randf_range(-0.025, 0.025), rng.randf_range(-0.025, 0.025))

	# 1. Transform strokes into world-space segments
	var segments: Array[Dictionary] = []
	for stroke in blueprint["strokes"]:
		var world_pts: Array[Vector2] = []
		for norm_pt in stroke:
			var pt: Vector2 = _transform_point(norm_pt, flip_x, flip_y, rot_angle, scale_x, scale_y, jitter)
			var world_pt := Vector2(
				clampf(play_area.position.x + pt.x * play_area.size.x, play_area.position.x, play_area.end.x),
				clampf(play_area.position.y + pt.y * play_area.size.y, play_area.position.y, play_area.end.y)
			)
			world_pts.append(world_pt)

		for i in range(world_pts.size() - 1):
			var a: Vector2 = world_pts[i]
			var b: Vector2 = world_pts[i + 1]
			if a.distance_to(b) > 4.0:
				segments.append({"a": a, "b": b})

	# 2. Split segments at intersections and extract sub-segments
	var raw_edges: Array[Dictionary] = _split_segments_at_intersections(segments)

	# 3. Cluster & merge close vertices (< 90 px)
	var cluster_positions: Array[Vector2] = _extract_and_merge_vertices(raw_edges, MERGE_DISTANCE_PX)

	# 4. Build merged edges and split any edge passing near a non-endpoint node
	var edge_set: Dictionary = {}
	for seg in raw_edges:
		var idx_a: int = _find_nearest_cluster(seg["a"], cluster_positions)
		var idx_b: int = _find_nearest_cluster(seg["b"], cluster_positions)
		if idx_a != -1 and idx_b != -1 and idx_a != idx_b:
			_add_edge_splitting_intermediate(idx_a, idx_b, cluster_positions, edge_set)

	var edges: Array[Vector2i] = []
	for key in edge_set.keys():
		edges.append(edge_set[key])

	# 5. Connect disconnected components with 2-way portals
	var portal_pairs: Array[Vector2i] = _connect_components_with_portals(cluster_positions, edges)

	var portal_node_flags: Dictionary = {}
	for p in portal_pairs:
		portal_node_flags[p.x] = true
		portal_node_flags[p.y] = true

	# 6. Place PLAYER (lower preference) & ENEMY (upper preference) at max graph distance
	var combined_adj: Dictionary = _build_combined_adj(cluster_positions.size(), edges, portal_pairs)
	var placement: Vector2i = _pick_faction_pair(cluster_positions, combined_adj)
	var player_idx: int = placement.x
	var enemy_idx: int = placement.y

	var nodes: Array[Dictionary] = []
	for i in range(cluster_positions.size()):
		var faction: BaseNode.Faction = BaseNode.Faction.NEUTRAL
		var troops: float = float(rng.randi_range(NEUTRAL_TROOPS_MIN, NEUTRAL_TROOPS_MAX))
		if i == player_idx:
			faction = BaseNode.Faction.PLAYER
			troops = STARTING_FACTION_TROOPS
		elif i == enemy_idx:
			faction = BaseNode.Faction.ENEMY
			troops = STARTING_FACTION_TROOPS

		nodes.append({
			"id": i,
			"position": cluster_positions[i],
			"faction": faction,
			"troops": troops,
			"has_portal": portal_node_flags.has(i),
		})

	return {
		"seed": seed_value,
		"tier": tier,
		"blueprint_id": blueprint["id"],
		"nodes": nodes,
		"edges": edges,
		"portal_pairs": portal_pairs,
	}


func _transform_point(
	p: Vector2,
	flip_x: bool,
	flip_y: bool,
	rot_angle: float,
	scale_x: float,
	scale_y: float,
	jitter: Vector2
) -> Vector2:
	var centered := p - Vector2(0.5, 0.5)
	if flip_x:
		centered.x = -centered.x
	if flip_y:
		centered.y = -centered.y
	centered.x *= scale_x
	centered.y *= scale_y
	centered = centered.rotated(rot_angle)
	var final_pt := centered + Vector2(0.5, 0.5) + jitter
	return Vector2(clampf(final_pt.x, 0.03, 0.97), clampf(final_pt.y, 0.03, 0.97))


func _split_segments_at_intersections(segments: Array[Dictionary]) -> Array[Dictionary]:
	var split_edges: Array[Dictionary] = []
	var count: int = segments.size()

	for i in range(count):
		var a: Vector2 = segments[i]["a"]
		var b: Vector2 = segments[i]["b"]
		var ab: Vector2 = b - a
		var len_sq: float = ab.length_squared()
		if len_sq < 1.0:
			continue

		var points_on_seg: Array[Vector2] = [a, b]
		for j in range(count):
			if i == j:
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, segments[j]["a"], segments[j]["b"])
			if hit is Vector2:
				var hit_pt: Vector2 = hit
				var is_dup: bool = false
				for existing in points_on_seg:
					if existing.distance_to(hit_pt) < 2.0:
						is_dup = true
						break
				if not is_dup:
					points_on_seg.append(hit_pt)

		points_on_seg.sort_custom(func(p1: Vector2, p2: Vector2) -> bool:
			return (p1 - a).dot(ab) < (p2 - a).dot(ab)
		)

		for k in range(points_on_seg.size() - 1):
			var p1: Vector2 = points_on_seg[k]
			var p2: Vector2 = points_on_seg[k + 1]
			if p1.distance_to(p2) >= 4.0:
				split_edges.append({"a": p1, "b": p2})

	return split_edges


func _extract_and_merge_vertices(raw_edges: Array[Dictionary], merge_dist: float) -> Array[Vector2]:
	var raw_points: Array[Vector2] = []
	for seg in raw_edges:
		raw_points.append(seg["a"])
		raw_points.append(seg["b"])

	var clusters: Array[Dictionary] = []
	for pt in raw_points:
		var best_idx: int = -1
		var best_d: float = merge_dist
		for idx in range(clusters.size()):
			var d: float = clusters[idx]["center"].distance_to(pt)
			if d < best_d:
				best_d = d
				best_idx = idx

		if best_idx == -1:
			clusters.append({"points": [pt], "center": pt})
		else:
			var pts: Array = clusters[best_idx]["points"]
			pts.append(pt)
			clusters[best_idx]["center"] = _average_points(pts)

	# Repeatedly merge any two cluster centers that drifted closer than merge_dist
	var merged_any: bool = true
	while merged_any:
		merged_any = false
		for i in range(clusters.size()):
			for j in range(i + 1, clusters.size()):
				if clusters[i]["center"].distance_to(clusters[j]["center"]) < merge_dist:
					var combined: Array = clusters[i]["points"] + clusters[j]["points"]
					clusters[i]["points"] = combined
					clusters[i]["center"] = _average_points(combined)
					clusters.remove_at(j)
					merged_any = true
					break
			if merged_any:
				break

	var result: Array[Vector2] = []
	for c in clusters:
		result.append(c["center"])
	return result


func _average_points(points: Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / float(maxi(1, points.size()))


func _find_nearest_cluster(pt: Vector2, centers: Array[Vector2]) -> int:
	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(centers.size()):
		var d: float = pt.distance_to(centers[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _add_edge_splitting_intermediate(
	idx_a: int,
	idx_b: int,
	positions: Array[Vector2],
	edge_set: Dictionary
) -> void:
	var pos_a: Vector2 = positions[idx_a]
	var pos_b: Vector2 = positions[idx_b]
	var ab: Vector2 = pos_b - pos_a

	var intermediate: Array[int] = []
	for i in range(positions.size()):
		if i == idx_a or i == idx_b:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(positions[i], pos_a, pos_b)
		if closest.distance_to(positions[i]) < EDGE_THROUGH_NODE_PX:
			intermediate.append(i)

	if intermediate.is_empty():
		var u: int = mini(idx_a, idx_b)
		var v: int = maxi(idx_a, idx_b)
		edge_set["%d_%d" % [u, v]] = Vector2i(u, v)
		return

	intermediate.sort_custom(func(i1: int, i2: int) -> bool:
		return (positions[i1] - pos_a).dot(ab) < (positions[i2] - pos_a).dot(ab)
	)

	var chain: Array[int] = [idx_a] + intermediate + [idx_b]
	for k in range(chain.size() - 1):
		var n1: int = chain[k]
		var n2: int = chain[k + 1]
		if n1 == n2:
			continue
		var u: int = mini(n1, n2)
		var v: int = maxi(n1, n2)
		edge_set["%d_%d" % [u, v]] = Vector2i(u, v)


func _connect_components_with_portals(positions: Array[Vector2], edges: Array[Vector2i]) -> Array[Vector2i]:
	var node_count: int = positions.size()
	var adj: Dictionary = {}
	for i in range(node_count):
		adj[i] = []
	for e in edges:
		adj[e.x].append(e.y)
		adj[e.y].append(e.x)

	var components: Array = _find_components(node_count, adj)
	var portals: Array[Vector2i] = []

	while components.size() > 1:
		var best_dist: float = INF
		var best_comp_a: int = -1
		var best_comp_b: int = -1
		var best_node_a: int = -1
		var best_node_b: int = -1

		for ci in range(components.size()):
			for cj in range(ci + 1, components.size()):
				for u in components[ci]:
					for v in components[cj]:
						var d: float = positions[u].distance_to(positions[v])
						if d < best_dist:
							best_dist = d
							best_comp_a = ci
							best_comp_b = cj
							best_node_a = u
							best_node_b = v

		if best_comp_a == -1 or best_comp_b == -1:
			break

		var pu: int = mini(best_node_a, best_node_b)
		var pv: int = maxi(best_node_a, best_node_b)
		portals.append(Vector2i(pu, pv))

		# Merge component B into component A
		components[best_comp_a].append_array(components[best_comp_b])
		components.remove_at(best_comp_b)

	return portals


func _find_components(node_count: int, adj: Dictionary) -> Array:
	var visited: Dictionary = {}
	var components: Array = []

	for i in range(node_count):
		if visited.has(i):
			continue
		var comp: Array = []
		var queue: Array[int] = [i]
		visited[i] = true
		var head: int = 0
		while head < queue.size():
			var curr: int = queue[head]
			head += 1
			comp.append(curr)
			for nb in adj.get(curr, []):
				if not visited.has(nb):
					visited[nb] = true
					queue.append(nb)
		components.append(comp)

	return components


func _build_combined_adj(node_count: int, edges: Array[Vector2i], portals: Array[Vector2i]) -> Dictionary:
	var adj: Dictionary = {}
	for i in range(node_count):
		adj[i] = []
	for e in edges:
		if not adj[e.x].has(e.y):
			adj[e.x].append(e.y)
		if not adj[e.y].has(e.x):
			adj[e.y].append(e.x)
	for p in portals:
		if not adj[p.x].has(p.y):
			adj[p.x].append(p.y)
		if not adj[p.y].has(p.x):
			adj[p.y].append(p.x)
	return adj


func _pick_faction_pair(positions: Array[Vector2], adj: Dictionary) -> Vector2i:
	var count: int = positions.size()
	if count < 2:
		return Vector2i(0, 0)

	var max_hops: int = -1
	var best_y_span: float = -1.0
	var best_player: int = 0
	var best_enemy: int = 1

	for i in range(count):
		var dists: Dictionary = _bfs_all(adj, i)
		for j in range(i + 1, count):
			var hops: int = int(dists.get(j, -1))
			if hops < 0:
				continue
			var y_span: float = absf(positions[i].y - positions[j].y)
			if hops > max_hops or (hops == max_hops and y_span > best_y_span):
				max_hops = hops
				best_y_span = y_span
				# Higher Y (lower on screen) -> PLAYER, Lower Y (upper on screen) -> ENEMY
				if positions[i].y >= positions[j].y:
					best_player = i
					best_enemy = j
				else:
					best_player = j
					best_enemy = i

	return Vector2i(best_player, best_enemy)


func _bfs_all(adj: Dictionary, start: int) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array[int] = [start]
	var head: int = 0
	while head < queue.size():
		var curr: int = queue[head]
		head += 1
		var d: int = int(dist[curr])
		for nb in adj.get(curr, []):
			if not dist.has(nb):
				dist[nb] = d + 1
				queue.append(nb)
	return dist


func _build_fallback_map(seed_value: int, tier: int, play_area: Rect2) -> Dictionary:
	var cx: float = play_area.position.x + play_area.size.x * 0.5
	var left_x: float = play_area.position.x + play_area.size.x * 0.18
	var right_x: float = play_area.position.x + play_area.size.x * 0.82
	var top_y: float = play_area.position.y + play_area.size.y * 0.08
	var mid_top_y: float = play_area.position.y + play_area.size.y * 0.34
	var mid_y: float = play_area.position.y + play_area.size.y * 0.52
	var mid_bot_y: float = play_area.position.y + play_area.size.y * 0.70
	var bot_y: float = play_area.position.y + play_area.size.y * 0.92

	var nodes: Array[Dictionary] = [
		{"id": 0, "position": Vector2(cx, top_y), "faction": BaseNode.Faction.ENEMY, "troops": 20.0, "has_portal": false},
		{"id": 1, "position": Vector2(left_x, mid_top_y), "faction": BaseNode.Faction.NEUTRAL, "troops": 12.0, "has_portal": false},
		{"id": 2, "position": Vector2(right_x, mid_top_y), "faction": BaseNode.Faction.NEUTRAL, "troops": 12.0, "has_portal": false},
		{"id": 3, "position": Vector2(cx, mid_y), "faction": BaseNode.Faction.NEUTRAL, "troops": 14.0, "has_portal": false},
		{"id": 4, "position": Vector2(left_x, mid_bot_y), "faction": BaseNode.Faction.NEUTRAL, "troops": 12.0, "has_portal": false},
		{"id": 5, "position": Vector2(right_x, mid_bot_y), "faction": BaseNode.Faction.NEUTRAL, "troops": 12.0, "has_portal": false},
		{"id": 6, "position": Vector2(cx, bot_y), "faction": BaseNode.Faction.PLAYER, "troops": 20.0, "has_portal": false},
	]
	var edges: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, 2),
		Vector2i(1, 3), Vector2i(1, 4),
		Vector2i(2, 3), Vector2i(2, 5),
		Vector2i(3, 4), Vector2i(3, 5),
		Vector2i(4, 6), Vector2i(5, 6),
	]
	return {
		"seed": seed_value,
		"tier": tier,
		"blueprint_id": "FALLBACK",
		"nodes": nodes,
		"edges": edges,
		"portal_pairs": [] as Array[Vector2i],
	}
