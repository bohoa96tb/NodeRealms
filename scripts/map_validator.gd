class_name MapValidator
extends RefCounted

const MIN_NODES: int = 4
const MAX_NODES: int = 25
const MIN_NODE_DISTANCE: float = 85.0
const MIN_FACTION_GRAPH_HOPS: int = 2


static func validate_map(map_data: Dictionary) -> Dictionary:
	var nodes: Array = map_data.get("nodes", [])
	var edges: Array = map_data.get("edges", [])
	var portals: Array = map_data.get("portal_pairs", [])

	var node_count: int = nodes.size()
	if node_count < MIN_NODES or node_count > MAX_NODES:
		return {
			"valid": false,
			"reason": "Node count (%d) out of range [%d..%d]." % [node_count, MIN_NODES, MAX_NODES],
		}

	# Condition 2: Minimum Euclidean distance >= 85 px between any two nodes
	for i in range(node_count):
		var pos_a: Vector2 = nodes[i]["position"]
		for j in range(i + 1, node_count):
			var pos_b: Vector2 = nodes[j]["position"]
			if pos_a.distance_to(pos_b) < MIN_NODE_DISTANCE:
				return {
					"valid": false,
					"reason": "Nodes %d and %d too close (%.1f px)." % [i, j, pos_a.distance_to(pos_b)],
				}

	# Build combined adjacency graph (normal edges + portals)
	var adj: Dictionary = {}
	for n in nodes:
		adj[int(n["id"])] = []

	for edge in edges:
		var a: int = edge.x
		var b: int = edge.y
		if adj.has(a) and adj.has(b):
			if not adj[a].has(b):
				adj[a].append(b)
			if not adj[b].has(a):
				adj[b].append(a)

	for portal in portals:
		var a: int = portal.x
		var b: int = portal.y
		if adj.has(a) and adj.has(b):
			if not adj[a].has(b):
				adj[a].append(b)
			if not adj[b].has(a):
				adj[b].append(a)

	# Condition 1: Global connectivity across all nodes
	var start_id: int = int(nodes[0]["id"])
	var distances: Dictionary = _bfs_distances(adj, start_id)
	if distances.size() != node_count:
		return {
			"valid": false,
			"reason": "Map is not fully connected (%d/%d reachable)." % [distances.size(), node_count],
		}

	# Condition 3: PLAYER & ENEMY bases exist, have >= 1 connection, and >= 2 hops apart
	var player_id: int = -1
	var enemy_id: int = -1
	for n in nodes:
		var faction: int = int(n["faction"])
		if faction == BaseNode.Faction.PLAYER:
			player_id = int(n["id"])
		elif faction == BaseNode.Faction.ENEMY:
			enemy_id = int(n["id"])

	if player_id == -1 or enemy_id == -1:
		return {
			"valid": false,
			"reason": "Missing PLAYER or ENEMY starting node.",
		}

	if adj[player_id].is_empty() or adj[enemy_id].is_empty():
		return {
			"valid": false,
			"reason": "PLAYER or ENEMY starting node is isolated.",
		}

	var faction_dists: Dictionary = _bfs_distances(adj, player_id)
	var hops: int = int(faction_dists.get(enemy_id, -1))
	if hops < MIN_FACTION_GRAPH_HOPS:
		return {
			"valid": false,
			"reason": "PLAYER and ENEMY too close (%d hops < %d)." % [hops, MIN_FACTION_GRAPH_HOPS],
		}

	return {
		"valid": true,
		"reason": "OK",
	}


static func _bfs_distances(adj: Dictionary, start_id: int) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array[int] = [start_id]
	dist[start_id] = 0
	var head: int = 0

	while head < queue.size():
		var current: int = queue[head]
		head += 1
		var current_dist: int = int(dist[current])
		for neighbor in adj.get(current, []):
			if not dist.has(neighbor):
				dist[neighbor] = current_dist + 1
				queue.append(neighbor)

	return dist
