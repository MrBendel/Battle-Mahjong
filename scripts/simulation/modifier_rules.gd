extends RefCounted

const BASIS_POINTS_ONE := 1000


static func effect_for(modifier: Dictionary, configuration: Dictionary) -> Dictionary:
	var level := maxi(0, int(modifier.get("level", 0)))
	match str(modifier.get("type", "")):
		"extra_life":
			return {"charges": int(configuration.modifier_extra_life_base_charges) + level * int(configuration.modifier_extra_life_charges_per_level)}
		"cold_snap":
			return {"duration_ms": int(configuration.modifier_cold_snap_base_duration_ms) + level * int(configuration.modifier_cold_snap_duration_ms_per_level)}
		"score_multiplier":
			return {
				"basis_points": int(configuration.modifier_score_multiplier_base_basis_points) + level * int(configuration.modifier_score_multiplier_basis_points_per_level),
				"duration_ms": int(configuration.modifier_score_multiplier_duration_ms),
			}
		"tray_plus_one":
			return {"pair_duration": int(configuration.modifier_tray_plus_one_base_pairs) + level * int(configuration.modifier_tray_plus_one_pairs_per_level)}
		"three_pair_clear":
			return {"pair_count": int(configuration.modifier_three_pair_clear_base_pairs) + level * int(configuration.modifier_three_pair_clear_pairs_per_level)}
		"bomb":
			return {"pair_count": int(configuration.modifier_bomb_base_pairs) + level * int(configuration.modifier_bomb_pairs_per_level)}
	return {}


static func active_score_basis_points(state: Variant, playback_time_ms: int) -> int:
	if playback_time_ms < state.score_multiplier_until_ms:
		return maxi(BASIS_POINTS_ONE, state.score_multiplier_basis_points)
	return BASIS_POINTS_ONE


static func effective_tray_capacity(definition: Variant, state: Variant) -> int:
	return definition.tray_capacity() + state.tray_bonus_capacity


static func momentum_decay_elapsed_ms(state: Variant, playback_time_ms: int) -> int:
	var start_ms: int = state.elapsed_time_ms
	var end_ms := maxi(start_ms, playback_time_ms)
	if state.cold_snap_until_ms <= start_ms:
		return end_ms - start_ms
	if end_ms <= state.cold_snap_until_ms:
		return 0
	return end_ms - state.cold_snap_until_ms
