extends RefCounted

const DEFAULT_TRAY_CAPACITY := 4
const DEFAULT_FLIPPED_TILE_COUNT := 0


static func create(tray_capacity: int = DEFAULT_TRAY_CAPACITY) -> Dictionary:
	return {
		"tray_capacity": tray_capacity,
		"flipped_tile_count": DEFAULT_FLIPPED_TILE_COUNT,
		"momentum_max": 100000,
		"momentum_pair_gain": 10000,
		"momentum_selection_gain": 2000,
		"momentum_thresholds": [0, 12500, 25000, 37500, 50000, 62500, 75000, 87500],
		"momentum_decay_per_ms": [3, 4, 5, 6, 7, 8, 10, 12],
		"pair_base_score": 100,
		"difficulty_notable_min_score": 130,
		"difficulty_notable_min_percentile_basis_points": 6000,
		"difficulty_notable_bonus_basis_points": 2500,
		"difficulty_exceptional_min_score": 190,
		"difficulty_exceptional_min_percentile_basis_points": 8500,
		"difficulty_exceptional_bonus_basis_points": 5000,
		"modifier_loadout_capacity": 3,
		"modifier_extra_life_base_charges": 1,
		"modifier_extra_life_charges_per_level": 1,
		"modifier_cold_snap_base_duration_ms": 8000,
		"modifier_cold_snap_duration_ms_per_level": 500,
		"modifier_score_multiplier_base_basis_points": 2000,
		"modifier_score_multiplier_basis_points_per_level": 100,
		"modifier_score_multiplier_duration_ms": 10000,
		"modifier_tray_plus_one_base_pairs": 3,
		"modifier_tray_plus_one_pairs_per_level": 1,
		"modifier_three_pair_clear_base_pairs": 1,
		"modifier_three_pair_clear_pairs_per_level": 1,
		"modifier_bomb_base_pairs": 1,
		"modifier_bomb_pairs_per_level": 1,
		"modifier_bomb_max_pairs": 6,
	}
