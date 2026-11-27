class_name CampaignData
extends RefCounted

enum AIDifficulty { EASY, NORMAL, HARD }

const REALM_NAME: String = "VERDANT REALM"
const TOTAL_LEVELS: int = 15


static func get_all_levels() -> Array[Dictionary]:
	return [
		# Tier 1: Levels 1-4 (EASY)
		{"level_id": 1, "name": "Sprout Clearing", "seed": 10421, "tier": 1, "ai_difficulty": AIDifficulty.EASY, "base_gold": 100, "base_essence": 15},
		{"level_id": 2, "name": "Mossy Crossing", "seed": 11834, "tier": 1, "ai_difficulty": AIDifficulty.EASY, "base_gold": 110, "base_essence": 16},
		{"level_id": 3, "name": "Briar Watch", "seed": 12907, "tier": 1, "ai_difficulty": AIDifficulty.EASY, "base_gold": 120, "base_essence": 18},
		{"level_id": 4, "name": "Fern Hollow", "seed": 14253, "tier": 1, "ai_difficulty": AIDifficulty.EASY, "base_gold": 130, "base_essence": 20},

		# Tier 2: Levels 5-8 (EASY -> NORMAL)
		{"level_id": 5, "name": "Timber Crossroads", "seed": 20518, "tier": 2, "ai_difficulty": AIDifficulty.EASY, "base_gold": 145, "base_essence": 22},
		{"level_id": 6, "name": "Canopy Ridge", "seed": 21942, "tier": 2, "ai_difficulty": AIDifficulty.EASY, "base_gold": 160, "base_essence": 24},
		{"level_id": 7, "name": "Rootbound Gate", "seed": 23765, "tier": 2, "ai_difficulty": AIDifficulty.NORMAL, "base_gold": 175, "base_essence": 26},
		{"level_id": 8, "name": "Willow Bastion", "seed": 25419, "tier": 2, "ai_difficulty": AIDifficulty.NORMAL, "base_gold": 190, "base_essence": 28},

		# Tier 3: Levels 9-12 (NORMAL, with Portals)
		{"level_id": 9, "name": "Rift Glade", "seed": 30812, "tier": 3, "ai_difficulty": AIDifficulty.NORMAL, "base_gold": 210, "base_essence": 32},
		{"level_id": 10, "name": "Split Thicket", "seed": 32490, "tier": 3, "ai_difficulty": AIDifficulty.NORMAL, "base_gold": 230, "base_essence": 35},
		{"level_id": 11, "name": "Mistwood Span", "seed": 34177, "tier": 3, "ai_difficulty": AIDifficulty.NORMAL, "base_gold": 250, "base_essence": 38},
		{"level_id": 12, "name": "Sunken Shrine", "seed": 36824, "tier": 3, "ai_difficulty": AIDifficulty.NORMAL, "base_gold": 275, "base_essence": 42},

		# Tier 4: Levels 13-15 (HARD, Multi-Portal Finale)
		{"level_id": 13, "name": "Ancient Archway", "seed": 40915, "tier": 4, "ai_difficulty": AIDifficulty.HARD, "base_gold": 300, "base_essence": 46},
		{"level_id": 14, "name": "Emerald Citadel", "seed": 42763, "tier": 4, "ai_difficulty": AIDifficulty.HARD, "base_gold": 330, "base_essence": 50},
		{"level_id": 15, "name": "Heart of Verdant", "seed": 45991, "tier": 4, "ai_difficulty": AIDifficulty.HARD, "base_gold": 380, "base_essence": 60},
	]


static func get_level(level_id: int) -> Dictionary:
	var all_levels: Array[Dictionary] = get_all_levels()
	var idx: int = clampi(level_id, 1, TOTAL_LEVELS) - 1
	return all_levels[idx]


static func get_difficulty_label(difficulty: AIDifficulty) -> String:
	match difficulty:
		AIDifficulty.EASY:
			return "EASY"
		AIDifficulty.NORMAL:
			return "NORMAL"
		AIDifficulty.HARD:
			return "HARD"
		_:
			return "NORMAL"
