extends RefCounted

const BASIS_POINTS_ONE := 10000
const NOTABLE := "notable"
const EXCEPTIONAL := "exceptional"


static func evaluate(pair_opportunity: Dictionary, configuration: Dictionary) -> Dictionary:
	if str(pair_opportunity.get("source", "")) != "board_pair":
		return {}
	var score := int(pair_opportunity.get("score", 0))
	var percentile := int(pair_opportunity.get("difficulty_percentile_bps", 0))
	if _qualifies(
		score,
		percentile,
		int(configuration.difficulty_exceptional_min_score),
		int(configuration.difficulty_exceptional_min_percentile_basis_points)
	):
		return _reward(
			EXCEPTIONAL,
			"eagle_eyes",
			score,
			percentile,
			int(configuration.difficulty_exceptional_bonus_basis_points)
		)
	if _qualifies(
		score,
		percentile,
		int(configuration.difficulty_notable_min_score),
		int(configuration.difficulty_notable_min_percentile_basis_points)
	):
		return _reward(
			NOTABLE,
			"great",
			score,
			percentile,
			int(configuration.difficulty_notable_bonus_basis_points)
		)
	return {}


static func bonus_for(base_score_gain: int, reward: Dictionary) -> int:
	return int(
		base_score_gain * int(reward.get("bonus_basis_points", 0))
		/ BASIS_POINTS_ONE
	)


static func _qualifies(score: int, percentile: int, minimum_score: int, minimum_percentile: int) -> bool:
	return score >= minimum_score and percentile >= minimum_percentile


static func _reward(
		tier: String,
		callout_key: String,
		score: int,
		percentile: int,
		bonus_basis_points: int
) -> Dictionary:
	return {
		"tier": tier,
		"callout_key": callout_key,
		"difficulty_score": score,
		"difficulty_percentile_bps": percentile,
		"bonus_basis_points": bonus_basis_points,
	}
