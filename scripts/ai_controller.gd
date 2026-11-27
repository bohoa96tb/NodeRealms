class_name AIController
extends Node

var difficulty: CampaignData.AIDifficulty = CampaignData.AIDifficulty.NORMAL

var _battle_manager: BattleManager = null
var _timer: float = 0.0


func initialize(manager: BattleManager, ai_diff: CampaignData.AIDifficulty = CampaignData.AIDifficulty.NORMAL) -> void:
	_battle_manager = manager
	difficulty = ai_diff
	_timer = 0.0


func _process(delta: float) -> void:
	if _battle_manager == null or _battle_manager.is_game_ended():
		return

	var interval: float = _get_think_interval()
	_timer += delta
	if _timer >= interval:
		_timer -= interval
		_execute_ai_turn()


func _get_think_interval() -> float:
	match difficulty:
		CampaignData.AIDifficulty.EASY:
			return 3.0
		CampaignData.AIDifficulty.NORMAL:
			return 2.2
		CampaignData.AIDifficulty.HARD:
			return 1.6
		_:
			return 2.2


func _get_min_troops() -> float:
	match difficulty:
		CampaignData.AIDifficulty.EASY:
			return 13.0
		CampaignData.AIDifficulty.NORMAL:
			return 12.0
		CampaignData.AIDifficulty.HARD:
			return 10.0
		_:
			return 12.0


func _get_send_ratio() -> float:
	return 0.55 if difficulty == CampaignData.AIDifficulty.HARD else 0.5


func _execute_ai_turn() -> void:
	var min_troops: float = _get_min_troops()
	var send_ratio: float = _get_send_ratio()
	var enemy_nodes: Array[BaseNode] = _battle_manager.get_nodes_by_faction(BaseNode.Faction.ENEMY)

	for source in enemy_nodes:
		if not is_instance_valid(source) or source.troops < min_troops:
			continue

		var target: BaseNode = _pick_target_for(source, send_ratio)
		if target != null:
			_battle_manager.spawn_army(source, target, send_ratio)


func _pick_target_for(source: BaseNode, send_ratio: float) -> BaseNode:
	match difficulty:
		CampaignData.AIDifficulty.EASY:
			return _pick_nearest_target(source)
		CampaignData.AIDifficulty.HARD:
			return _pick_aggressive_target(source, send_ratio)
		_:
			return _pick_weakest_target(source, send_ratio)


func _pick_nearest_target(source: BaseNode) -> BaseNode:
	var best_target: BaseNode = null
	var best_dist: float = INF

	for neighbor in source.get_all_reachable_nodes():
		if not is_instance_valid(neighbor) or neighbor.faction == BaseNode.Faction.ENEMY:
			continue
		var d: float = source.position.distance_to(neighbor.position)
		if d < best_dist:
			best_dist = d
			best_target = neighbor

	return best_target


func _pick_weakest_target(source: BaseNode, send_ratio: float) -> BaseNode:
	var best_target: BaseNode = null
	var best_score: float = INF
	var send_estimate: float = floorf(source.troops * send_ratio)

	for neighbor in source.get_all_reachable_nodes():
		if not is_instance_valid(neighbor) or neighbor.faction == BaseNode.Faction.ENEMY:
			continue

		var score: float = neighbor.troops
		if neighbor.faction == BaseNode.Faction.PLAYER and neighbor.troops >= send_estimate:
			score += 100.0

		if score < best_score:
			best_score = score
			best_target = neighbor

	return best_target


func _pick_aggressive_target(source: BaseNode, send_ratio: float) -> BaseNode:
	var best_target: BaseNode = null
	var best_score: float = INF
	var send_estimate: float = floorf(source.troops * send_ratio)

	# 1. Prioritize winnable non-enemy targets (especially vulnerable PLAYER bases)
	for neighbor in source.get_all_reachable_nodes():
		if not is_instance_valid(neighbor) or neighbor.faction == BaseNode.Faction.ENEMY:
			continue

		var effective_def: float = neighbor.troops * neighbor.power_multiplier
		if neighbor.faction == BaseNode.Faction.PLAYER and _battle_manager.creature_manager != null:
			effective_def *= _battle_manager.creature_manager.get_defense_mult()

		var score: float = effective_def
		if neighbor.faction == BaseNode.Faction.PLAYER and send_estimate > effective_def:
			# Proactive strike on capturable player base
			score -= 25.0
		elif neighbor.faction == BaseNode.Faction.PLAYER and effective_def >= send_estimate:
			# Counter-pressure or wait if too fortified
			score += 60.0

		if score < best_score:
			best_score = score
			best_target = neighbor

	if best_target != null:
		return best_target

	# 2. If surrounded by allied ENEMY bases and heavily stocked, reinforce a frontline ENEMY base
	if source.troops >= 20.0:
		var best_ally: BaseNode = null
		var lowest_ally_troops: float = INF
		for neighbor in source.get_all_reachable_nodes():
			if not is_instance_valid(neighbor) or neighbor.faction != BaseNode.Faction.ENEMY:
				continue
			if _has_non_enemy_neighbor(neighbor) and neighbor.troops < lowest_ally_troops and neighbor.troops < float(neighbor.max_troops - 5):
				lowest_ally_troops = neighbor.troops
				best_ally = neighbor
		return best_ally

	return null


func _has_non_enemy_neighbor(node: BaseNode) -> bool:
	for n in node.get_all_reachable_nodes():
		if is_instance_valid(n) and n.faction != BaseNode.Faction.ENEMY:
			return true
	return false
