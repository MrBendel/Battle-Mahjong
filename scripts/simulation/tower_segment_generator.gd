extends RefCounted

const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const LayoutDifficultyAnalyzerScript := preload("res://scripts/simulation/layout_difficulty_analyzer.gd")
const BoardLayoutRequirementsScript := preload("res://scripts/simulation/board_layout_requirements.gd")
const ProceduralLayoutGeneratorScript := preload("res://scripts/simulation/procedural_layout_generator.gd")
const ReferenceGameFactoryScript := preload("res://scripts/simulation/reference_game_factory.gd")

const SCHEMA_VERSION := 1


func generate(profile: Variant, segment_seed: int) -> Dictionary:
	if profile == null or not profile.call("validation_errors").is_empty():
		return _invalid("invalid Tower generation profile")
	var requirements: Variant = BoardLayoutRequirementsScript.load_file(profile.requirements_path)
	if requirements == null or not requirements.call("validation_errors").is_empty():
		return _invalid("invalid layout requirements")

	var rng := DeterministicRngScript.new(segment_seed)
	var layout_generator := ProceduralLayoutGeneratorScript.new()
	var factory := ReferenceGameFactoryScript.new()
	var analyzer := LayoutDifficultyAnalyzerScript.new()
	var candidates: Array = []
	for candidate_index in range(profile.candidate_count):
		var layout_seed: int = rng.call("next_int")
		var deal_seed: int = rng.call("next_int")
		var candidate_layout_id := "%s_seed_%010d" % [profile.id, layout_seed]
		var layout: Variant = layout_generator.call(
			"generate", requirements, layout_seed, candidate_layout_id
		)
		if layout == null:
			return _invalid("candidate %d layout generation failed" % candidate_index)
		var generated: Dictionary = factory.call(
			"create_generated_for_layout",
			deal_seed,
			layout,
			profile.tray_capacity,
			{"flipped_tile_count": 0},
			[],
			false,
			profile.deal_options
		)
		if generated.is_empty():
			return _invalid("candidate %d deal generation failed" % candidate_index)
		var difficulty: Dictionary = analyzer.call(
			"analyze_solution",
			generated.definition,
			generated.solution,
			profile.difficulty_weights
		)
		if not bool(difficulty.get("valid", false)):
			return _invalid("candidate %d analysis failed: %s" % [candidate_index, difficulty.get("reason", "")])
		candidates.append({
			"candidate_index": candidate_index,
			"layout_seed": layout_seed,
			"deal_seed": deal_seed,
			"layout_hash": layout.content_hash(),
			"definition_hash": generated.definition.definition_hash(),
			"layout": layout.to_dict(),
			"solution": generated.solution.duplicate(),
			"difficulty": difficulty,
		})

	candidates.sort_custom(_candidate_precedes)
	var floors: Array = []
	for floor_index in range(profile.floor_count):
		var bucket_start: int = floor_index * candidates.size() / profile.floor_count
		var bucket_end: int = ((floor_index + 1) * candidates.size() / profile.floor_count) - 1
		var candidate_index: int = (bucket_start + bucket_end) / 2
		var floor: Dictionary = candidates[candidate_index].duplicate(true)
		floor["floor_number"] = floor_index + 1
		floor["floor_id"] = "%s_floor_%03d" % [profile.id, floor_index + 1]
		floors.append(floor)

	return {
		"valid": true,
		"reason": "",
		"schema_version": SCHEMA_VERSION,
		"segment_id": profile.id,
		"segment_revision": profile.revision,
		"segment_seed": segment_seed,
		"profile_hash": profile.call("content_hash"),
		"requirements_id": requirements.id,
		"requirements_revision": requirements.revision,
		"requirements_hash": requirements.call("content_hash"),
		"candidate_count": candidates.size(),
		"difficulty_axes": {
			"board_columns": requirements.columns,
			"board_rows": requirements.rows,
			"board_tile_count": requirements.tile_count,
			"board_layer_count": requirements.layer_counts.size(),
			"unique_tile_count": int(profile.deal_options.unique_tile_count),
			"shuffle_basis_points": int(profile.deal_options.shuffle_basis_points),
			"randomize_removal_pairs": bool(profile.deal_options.randomize_removal_pairs),
		},
		"floors": floors,
	}


func _candidate_precedes(first: Dictionary, second: Dictionary) -> bool:
	var first_score := int(first.difficulty.difficulty_score)
	var second_score := int(second.difficulty.difficulty_score)
	if first_score != second_score:
		return first_score < second_score
	if str(first.layout_hash) != str(second.layout_hash):
		return str(first.layout_hash) < str(second.layout_hash)
	return int(first.deal_seed) < int(second.deal_seed)


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
