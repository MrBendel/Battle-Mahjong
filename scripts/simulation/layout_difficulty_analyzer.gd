extends RefCounted

const BoardOpportunityAnalysisScript := preload("res://scripts/simulation/board_opportunity_analysis.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")

const DEFAULT_WEIGHTS := {
	"average_pair_difficulty_bps": 10000,
	"peak_pair_difficulty_bps": 2500,
	"constrained_route_step_points": 3,
	"low_pair_availability_target": 6,
	"low_pair_availability_points": 5,
}


func analyze_solution(definition: Variant, solution: Array, scoring_weights: Dictionary = {}) -> Dictionary:
	if definition == null:
		return _invalid("definition is required")
	if solution.size() != definition.tiles.size() or solution.size() % 2 != 0:
		return _invalid("solution must contain every tile in pairs")

	var game := GameStateScript.new(definition)
	var opportunity_analyzer := BoardOpportunityAnalysisScript.new()
	var pair_scores: Array[int] = []
	var selectable_counts: Array[int] = []
	var available_pair_counts: Array[int] = []
	var constrained_steps := 0

	for pair_index in range(0, solution.size(), 2):
		var first_id := str(solution[pair_index])
		var second_id := str(solution[pair_index + 1])
		var opportunity: Dictionary = opportunity_analyzer.call(
			"analyze",
			definition,
			game.call("current_snapshot")
		)
		var pair_entry := _pair_entry(opportunity.get("pair_scores", []), first_id, second_id)
		if pair_entry.is_empty():
			return _invalid("certified pair %d is not selectable" % (pair_index / 2))

		pair_scores.append(int(pair_entry.get("score", 0)))
		selectable_counts.append(int(opportunity.get("selectable_tile_count", 0)))
		var available_pairs := int(opportunity.get("available_pair_count", 0))
		available_pair_counts.append(available_pairs)
		if available_pairs <= 2:
			constrained_steps += 1

		if game.call("select_tile", first_id) != GameStateScript.SELECTED:
			return _invalid("certified pair %d first selection was rejected" % (pair_index / 2))
		if game.call("select_tile", second_id) != GameStateScript.PAIR_RESOLVED:
			return _invalid("certified pair %d did not resolve" % (pair_index / 2))

	if game.status != GameStateScript.WON:
		return _invalid("certified solution did not reach a win")

	var average_pair_score := _average(pair_scores)
	var peak_pair_score := _maximum(pair_scores)
	var average_selectable := _average(selectable_counts)
	var average_available_pairs := _average(available_pair_counts)
	var weights := DEFAULT_WEIGHTS.duplicate()
	weights.merge(scoring_weights, true)
	var components := {
		"average_pair_difficulty": average_pair_score * int(weights.average_pair_difficulty_bps) / 10000,
		"peak_pair_difficulty": peak_pair_score * int(weights.peak_pair_difficulty_bps) / 10000,
		"constrained_route_steps": constrained_steps * int(weights.constrained_route_step_points),
		"low_pair_availability": maxi(
			0,
			int(weights.low_pair_availability_target) - average_available_pairs
		) * int(weights.low_pair_availability_points),
	}
	return {
		"valid": true,
		"reason": "",
		"difficulty_score": _component_total(components),
		"difficulty_components": components,
		"scoring_weights": weights,
		"pair_count": pair_scores.size(),
		"average_pair_difficulty": average_pair_score,
		"peak_pair_difficulty": peak_pair_score,
		"initial_selectable_tile_count": selectable_counts[0],
		"minimum_selectable_tile_count": _minimum(selectable_counts),
		"average_selectable_tile_count": average_selectable,
		"initial_available_pair_count": available_pair_counts[0],
		"minimum_available_pair_count": _minimum(available_pair_counts),
		"average_available_pair_count": average_available_pairs,
		"constrained_route_step_count": constrained_steps,
	}


func _pair_entry(entries: Array, first_id: String, second_id: String) -> Dictionary:
	var expected: Array[String] = [first_id, second_id]
	expected.sort()
	for entry in entries:
		var ids: Array = entry.get("tile_ids", []).duplicate()
		ids.sort()
		if ids == expected:
			return entry
	return {}


func _average(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var total := 0
	for value in values:
		total += value
	return total / values.size()


func _minimum(values: Array[int]) -> int:
	var result := values[0]
	for value in values:
		result = mini(result, value)
	return result


func _maximum(values: Array[int]) -> int:
	var result := values[0]
	for value in values:
		result = maxi(result, value)
	return result


func _component_total(components: Dictionary) -> int:
	var total := 0
	for value in components.values():
		total += int(value)
	return maxi(0, total)


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
