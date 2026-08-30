extends Resource
class_name ModifierTuning

@export_category("Loadout")
@export_range(0, 12, 1) var loadout_capacity := 3

@export_category("Extra Life")
@export_range(1, 10, 1) var extra_life_base_charges := 1
@export_range(0, 10, 1) var extra_life_charges_per_level := 1

@export_category("Cold Snap")
@export_range(1, 60000, 1) var cold_snap_base_duration_ms := 8000
@export_range(0, 10000, 1) var cold_snap_duration_ms_per_level := 500

@export_category("Score Multiplier")
## 2000 means 2.0x; fixed-point values keep replay scoring exact.
@export_range(1000, 10000, 1) var score_multiplier_base_basis_points := 2000
@export_range(0, 1000, 1) var score_multiplier_basis_points_per_level := 100
@export_range(1, 60000, 1) var score_multiplier_duration_ms := 10000

@export_category("Tray +1")
@export_range(1, 48, 1) var tray_plus_one_base_pairs := 3
@export_range(0, 12, 1) var tray_plus_one_pairs_per_level := 1

@export_category("Three Pair Clear")
@export_range(1, 12, 1) var three_pair_clear_base_pairs := 3
@export_range(0, 12, 1) var three_pair_clear_pairs_per_level := 0

@export_category("Bomb")
@export_range(1, 12, 1) var bomb_base_pairs := 5
@export_range(0, 12, 1) var bomb_pairs_per_level := 0


func configuration_overrides() -> Dictionary:
	return {
		"modifier_loadout_capacity": loadout_capacity,
		"modifier_extra_life_base_charges": extra_life_base_charges,
		"modifier_extra_life_charges_per_level": extra_life_charges_per_level,
		"modifier_cold_snap_base_duration_ms": cold_snap_base_duration_ms,
		"modifier_cold_snap_duration_ms_per_level": cold_snap_duration_ms_per_level,
		"modifier_score_multiplier_base_basis_points": score_multiplier_base_basis_points,
		"modifier_score_multiplier_basis_points_per_level": score_multiplier_basis_points_per_level,
		"modifier_score_multiplier_duration_ms": score_multiplier_duration_ms,
		"modifier_tray_plus_one_base_pairs": tray_plus_one_base_pairs,
		"modifier_tray_plus_one_pairs_per_level": tray_plus_one_pairs_per_level,
		"modifier_three_pair_clear_base_pairs": three_pair_clear_base_pairs,
		"modifier_three_pair_clear_pairs_per_level": three_pair_clear_pairs_per_level,
		"modifier_bomb_base_pairs": bomb_base_pairs,
		"modifier_bomb_pairs_per_level": bomb_pairs_per_level,
	}


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if loadout_capacity < 0:
		errors.append("Loadout capacity cannot be negative.")
	if extra_life_base_charges <= 0 or extra_life_charges_per_level < 0:
		errors.append("Extra Life charges must have a positive base and non-negative level gain.")
	if cold_snap_base_duration_ms <= 0 or cold_snap_duration_ms_per_level < 0:
		errors.append("Cold Snap duration must have a positive base and non-negative level gain.")
	if score_multiplier_base_basis_points < 1000 or score_multiplier_basis_points_per_level < 0:
		errors.append("Score Multiplier must be at least 1.0x with non-negative level gain.")
	if score_multiplier_duration_ms <= 0:
		errors.append("Score Multiplier duration must be positive.")
	if tray_plus_one_base_pairs <= 0 or tray_plus_one_pairs_per_level < 0:
		errors.append("Tray +1 duration must have a positive base and non-negative level gain.")
	if three_pair_clear_base_pairs <= 0 or three_pair_clear_pairs_per_level < 0:
		errors.append("Three Pair Clear must have a positive base and non-negative level gain.")
	if bomb_base_pairs <= 0 or bomb_pairs_per_level < 0:
		errors.append("Bomb must have a positive base and non-negative level gain.")
	return errors
