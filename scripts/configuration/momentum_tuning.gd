extends Resource
class_name MomentumTuning

const GameConfigurationScript := preload("res://scripts/simulation/game_configuration.gd")

@export_category("Momentum Meter")
## Integer meter capacity used by deterministic simulation.
@export_range(1, 1000000, 1) var maximum := 100000
## Momentum added after a pair scores, building the multiplier for the next pair.
@export_range(1, 1000000, 1) var pair_gain := 10000
## Small Momentum reward for each accepted natural tile selection.
@export_range(0, 1000000, 1) var selection_gain := 2000
## Inclusive lower bounds for x1, x2, and subsequent multiplier tiers. Must start at 0.
@export var multiplier_thresholds: Array[int] = [0, 12500, 25000, 37500, 50000, 62500, 75000, 87500]

@export_category("Decay")
## One rate per multiplier tier. Values must be positive multiples of 1000.
@export var decay_per_second: Array[int] = [3000, 4000, 5000, 6000, 7000, 8000, 10000, 12000]

@export_category("Scoring")
## Points awarded per pair before applying the current multiplier.
@export_range(1, 1000000, 1) var pair_base_score := 100

@export_category("Pair Difficulty Rewards")
## Minimum absolute pair score for a GREAT recognition event.
@export_range(0, 1000, 1) var difficulty_notable_min_score := 130
## Minimum contextual percentile for GREAT, expressed as 0..10000 basis points.
@export_range(0, 10000, 100) var difficulty_notable_min_percentile_basis_points := 6000
## Additional score percentage for GREAT, expressed as basis points (2500 = 25%).
@export_range(0, 10000, 100) var difficulty_notable_bonus_basis_points := 2500
## Minimum absolute pair score for an EAGLE EYES recognition event.
@export_range(0, 1000, 1) var difficulty_exceptional_min_score := 190
## Minimum contextual percentile for EAGLE EYES, expressed as 0..10000 basis points.
@export_range(0, 10000, 100) var difficulty_exceptional_min_percentile_basis_points := 8500
## Additional score percentage for EAGLE EYES, expressed as basis points (5000 = 50%).
@export_range(0, 20000, 100) var difficulty_exceptional_bonus_basis_points := 5000


func configuration_overrides() -> Dictionary:
	var decay_per_ms: Array[int] = []
	for rate in decay_per_second:
		decay_per_ms.append(int(rate / 1000))
	return {
		"momentum_max": maximum,
		"momentum_pair_gain": pair_gain,
		"momentum_selection_gain": selection_gain,
		"momentum_thresholds": multiplier_thresholds.duplicate(),
		"momentum_decay_per_ms": decay_per_ms,
		"pair_base_score": pair_base_score,
		"difficulty_notable_min_score": difficulty_notable_min_score,
		"difficulty_notable_min_percentile_basis_points": difficulty_notable_min_percentile_basis_points,
		"difficulty_notable_bonus_basis_points": difficulty_notable_bonus_basis_points,
		"difficulty_exceptional_min_score": difficulty_exceptional_min_score,
		"difficulty_exceptional_min_percentile_basis_points": difficulty_exceptional_min_percentile_basis_points,
		"difficulty_exceptional_bonus_basis_points": difficulty_exceptional_bonus_basis_points,
	}


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if maximum <= 0:
		errors.append("Maximum must be positive.")
	if pair_gain <= 0 or pair_gain > maximum:
		errors.append("Pair gain must be positive and no greater than Maximum.")
	if selection_gain < 0 or selection_gain > maximum:
		errors.append("Selection gain cannot be negative or greater than Maximum.")
	if multiplier_thresholds.is_empty() or multiplier_thresholds[0] != 0:
		errors.append("Multiplier thresholds must start at 0 for x1.")
	for index in range(1, multiplier_thresholds.size()):
		if multiplier_thresholds[index] <= multiplier_thresholds[index - 1]:
			errors.append("Multiplier thresholds must be strictly increasing.")
			break
	if not multiplier_thresholds.is_empty() and multiplier_thresholds[-1] > maximum:
		errors.append("Multiplier thresholds cannot exceed Maximum.")
	if decay_per_second.size() != multiplier_thresholds.size():
		errors.append("Decay must contain one rate for each multiplier threshold.")
	for rate in decay_per_second:
		if rate <= 0 or rate % 1000 != 0:
			errors.append("Decay rates must be positive multiples of 1000 units per second.")
			break
	if pair_base_score <= 0:
		errors.append("Pair base score must be positive.")
	if difficulty_notable_min_score < 0 or difficulty_exceptional_min_score < 0:
		errors.append("Pair difficulty score thresholds cannot be negative.")
	if difficulty_exceptional_min_score < difficulty_notable_min_score:
		errors.append("Exceptional difficulty score must be at least the notable threshold.")
	if difficulty_notable_min_percentile_basis_points < 0 \
			or difficulty_notable_min_percentile_basis_points > 10000 \
			or difficulty_exceptional_min_percentile_basis_points < 0 \
			or difficulty_exceptional_min_percentile_basis_points > 10000:
		errors.append("Pair difficulty percentiles must be between 0 and 10000.")
	if difficulty_exceptional_min_percentile_basis_points \
			< difficulty_notable_min_percentile_basis_points:
		errors.append("Exceptional difficulty percentile must be at least the notable threshold.")
	if difficulty_notable_bonus_basis_points < 0 \
			or difficulty_exceptional_bonus_basis_points < difficulty_notable_bonus_basis_points:
		errors.append("Difficulty bonuses must be non-negative and exceptional cannot be lower than notable.")
	return errors


static func default_overrides() -> Dictionary:
	var configuration := GameConfigurationScript.create()
	return {
		"momentum_max": configuration.momentum_max,
		"momentum_pair_gain": configuration.momentum_pair_gain,
		"momentum_selection_gain": configuration.momentum_selection_gain,
		"momentum_thresholds": configuration.momentum_thresholds.duplicate(),
		"momentum_decay_per_ms": configuration.momentum_decay_per_ms.duplicate(),
		"pair_base_score": configuration.pair_base_score,
		"difficulty_notable_min_score": configuration.difficulty_notable_min_score,
		"difficulty_notable_min_percentile_basis_points": configuration.difficulty_notable_min_percentile_basis_points,
		"difficulty_notable_bonus_basis_points": configuration.difficulty_notable_bonus_basis_points,
		"difficulty_exceptional_min_score": configuration.difficulty_exceptional_min_score,
		"difficulty_exceptional_min_percentile_basis_points": configuration.difficulty_exceptional_min_percentile_basis_points,
		"difficulty_exceptional_bonus_basis_points": configuration.difficulty_exceptional_bonus_basis_points,
	}
