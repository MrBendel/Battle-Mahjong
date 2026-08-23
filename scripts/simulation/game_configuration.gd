extends RefCounted

const DEFAULT_TRAY_CAPACITY := 4
const DEFAULT_FLIPPED_TILE_COUNT := 0


static func create(tray_capacity: int = DEFAULT_TRAY_CAPACITY) -> Dictionary:
	return {
		"tray_capacity": tray_capacity,
		"flipped_tile_count": DEFAULT_FLIPPED_TILE_COUNT,
		"momentum_max": 100000,
		"momentum_pair_gain": 30000,
		"momentum_selection_gain": 2500,
		"momentum_thresholds": [0, 20000, 40000, 60000, 80000],
		"momentum_decay_per_ms": [5, 7, 10, 14, 19],
		"pair_base_score": 100,
		"difficulty_notable_min_score": 160,
		"difficulty_notable_min_percentile_basis_points": 7500,
		"difficulty_notable_bonus_basis_points": 2500,
		"difficulty_exceptional_min_score": 220,
		"difficulty_exceptional_min_percentile_basis_points": 9000,
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
	}
