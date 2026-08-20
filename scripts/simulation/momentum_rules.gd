extends RefCounted


static func decay(momentum_units: int, elapsed_ms: int, configuration: Dictionary) -> int:
	var momentum := clampi(momentum_units, 0, int(configuration.momentum_max))
	var remaining_ms := maxi(0, elapsed_ms)
	var thresholds: Array = configuration.momentum_thresholds
	var decay_rates: Array = configuration.momentum_decay_per_ms

	while momentum > 0 and remaining_ms > 0:
		var tier := multiplier_for(momentum, configuration) - 1
		var rate := int(decay_rates[tier])
		var lower_bound := 0 if tier == 0 else int(thresholds[tier]) - 1
		var units_to_lower_tier := momentum - lower_bound
		var ms_to_lower_tier := ceili(float(units_to_lower_tier) / float(rate))
		var decay_ms := mini(remaining_ms, ms_to_lower_tier)
		momentum = maxi(lower_bound, momentum - rate * decay_ms)
		remaining_ms -= decay_ms

	return momentum


static func multiplier_for(momentum_units: int, configuration: Dictionary) -> int:
	var multiplier := 1
	for threshold in configuration.momentum_thresholds:
		if momentum_units < int(threshold):
			break
		multiplier += 1
	return mini(multiplier - 1, configuration.momentum_thresholds.size())


static func add_pair_gain(momentum_units: int, configuration: Dictionary) -> int:
	return mini(
		int(configuration.momentum_max),
		momentum_units + int(configuration.momentum_pair_gain)
	)


static func add_selection_gain(momentum_units: int, configuration: Dictionary) -> int:
	return mini(
		int(configuration.momentum_max),
		momentum_units + int(configuration.momentum_selection_gain)
	)


static func remove_selection_gain(momentum_units: int, selection_gain: int) -> int:
	return maxi(0, momentum_units - maxi(0, selection_gain))
