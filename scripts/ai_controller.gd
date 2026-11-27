class_name AIController
extends Node

const THINK_INTERVAL: float = 2.5
const MIN_TROOPS_TO_ATTACK: float = 12.0
const SEND_RATIO: float = 0.5

var _battle_manager: BattleManager = null
var _timer: float = 0.0


func initialize(manager: BattleManager) -> void:
	_battle_manager = manager
	_timer = 0.0


func _process(delta: float) -> void:
	if _battle_manager == null or _battle_manager.is_game_ended():
		return

	_timer += delta
	if _timer >= THINK_INTERVAL:
		_timer -= THINK_INTERVAL
		_execute_ai_turn()


func _execute_ai_turn() -> void:
	var enemy_nodes: Array[BaseNode] = _battle_manager.get_nodes_by_faction(BaseNode.Faction.ENEMY)
	for source in enemy_nodes:
		if source.troops < MIN_TROOPS_TO_ATTACK:
			continue

		var target: BaseNode = _pick_target_for(source)
		if target != null:
			_battle_manager.spawn_army(source, target, SEND_RATIO)


func _pick_target_for(source: BaseNode) -> BaseNode:
	var best_target: BaseNode = null
	var best_score: float = INF
	var send_estimate: float = floorf(source.troops * SEND_RATIO)

	# Prioritize non-enemy reachable nodes (edges + portals) with fewest troops
	for neighbor in source.get_all_reachable_nodes():
		if not is_instance_valid(neighbor) or neighbor.faction == BaseNode.Faction.ENEMY:
			continue

		var score: float = neighbor.troops
		if neighbor.faction == BaseNode.Faction.PLAYER and neighbor.troops >= send_estimate:
			# Still valid if no weaker option exists, but rank after Neutral or weaker Player
			score += 100.0

		if score < best_score:
			best_score = score
			best_target = neighbor

	return best_target
