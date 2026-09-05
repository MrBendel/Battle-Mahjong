extends RefCounted

const BoardLayoutScript := preload("res://scripts/simulation/board_layout.gd")
const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const LayoutSlotScript := preload("res://scripts/simulation/layout_slot.gd")
const LayoutSolutionPlannerScript := preload("res://scripts/simulation/layout_solution_planner.gd")
const LayoutMobileFitAnalyzerScript := preload("res://scripts/simulation/layout_mobile_fit_analyzer.gd")
const RequirementsScript := preload("res://scripts/simulation/board_layout_requirements.gd")


func generate(requirements: Variant, seed: int, generated_layout_id: String = "") -> Variant:
	if requirements == null:
		return null
	var requirements_errors: Array[String] = requirements.call("validation_errors")
	if not requirements_errors.is_empty():
		push_error("Invalid procedural layout requirements: %s" % "; ".join(requirements_errors))
		return null

	var rng := DeterministicRngScript.new(seed)
	var slots: Array = []
	var lower_positions: Array = []
	var selected_motifs: Array[String] = []
	for z in range(requirements.layer_counts.size()):
		var motif := _choose_motif(requirements, z, rng)
		selected_motifs.append(motif)
		var selected: Array = _generate_layer(requirements, z, lower_positions, rng, motif)
		if selected.size() != requirements.layer_counts[z]:
			push_error("Could not satisfy procedural layout layer %d" % z)
			return null
		lower_positions = []
		for position in selected:
			slots.append(LayoutSlotScript.new(LayoutSlotScript.coordinate_id(position), position))
			lower_positions.append(position)

	var metadata := {
		"source": "procedural",
		"generator_seed": seed,
		"requirements": requirements.to_dict(),
		"requirements_hash": requirements.content_hash(),
	}
	if not requirements.layer_motif_choices.is_empty():
		metadata["selected_motifs"] = selected_motifs
	var layout_id: String = requirements.id if generated_layout_id.is_empty() else generated_layout_id
	var layout := BoardLayoutScript.new(layout_id, slots, requirements.revision, metadata)
	if not layout.validation_errors().is_empty():
		return null
	if not requirements.mobile_constraints.is_empty():
		var mobile_fit: Dictionary = LayoutMobileFitAnalyzerScript.new().call(
			"analyze", layout, requirements.mobile_constraints
		)
		if not mobile_fit.valid:
			push_error("Procedural layout failed mobile fit: %s" % "; ".join(mobile_fit.errors))
			return null
		metadata["mobile_fit"] = mobile_fit.metrics
		layout = BoardLayoutScript.new(layout_id, slots, requirements.revision, metadata)
	var plan: Array = LayoutSolutionPlannerScript.new().call("build_plan", layout)
	if plan.size() * 2 != requirements.tile_count:
		push_error("Procedural layout has no complete removal plan")
		return null
	return layout


func _generate_layer(
		requirements: Variant, z: int, lower_positions: Array, rng: Variant, motif: String
) -> Array:
	var inset: int = z if requirements.progressive_layer_inset else z % 2
	var layer_columns: int = requirements.columns - inset
	var layer_rows: int = requirements.rows - inset
	var start_x := inset
	var start_y := inset
	var candidates := {}
	for row in range(layer_rows):
		for column in range(layer_columns):
			var position := BoardPositionScript.new(start_x + column * 2, start_y + row * 2, z)
			if z > 0 and requirements.require_support and not _has_support(position, lower_positions):
				continue
			candidates[_candidate_key(column, row)] = {
				"column": column,
				"row": row,
				"position": position,
				"score": _shape_score(requirements.shape, column, row, layer_columns, layer_rows)
					+ _motif_score(motif, column, row, layer_columns, layer_rows) * 8,
			}

	if not requirements.horizontal_symmetry:
		var ranked: Array = candidates.values()
		for candidate in ranked:
			candidate["tie"] = rng.call("next_int")
		ranked.sort_custom(_candidate_precedes)
		var selected: Array = []
		for index in range(mini(requirements.layer_counts[z], ranked.size())):
			selected.append(ranked[index].position)
		return selected

	var centers: Array = []
	var pairs: Array = []
	for row in range(layer_rows):
		for column in range((layer_columns + 1) / 2):
			var mirror_column := layer_columns - 1 - column
			var first: Variant = candidates.get(_candidate_key(column, row))
			var second: Variant = candidates.get(_candidate_key(mirror_column, row))
			if first == null or second == null:
				continue
			var group := {
				"positions": [first.position] if column == mirror_column else [first.position, second.position],
				"score": first.score + second.score,
				"tie": rng.call("next_int"),
			}
			if column == mirror_column:
				centers.append(group)
			else:
				pairs.append(group)
	centers.sort_custom(_group_precedes)
	pairs.sort_custom(_group_precedes)

	var target: int = requirements.layer_counts[z]
	var center_count := maxi(target % 2, target - pairs.size() * 2)
	if center_count % 2 != target % 2:
		center_count += 1
	var pair_count := (target - center_count) / 2
	if center_count > centers.size() or pair_count > pairs.size():
		return []

	var selected: Array = []
	for index in range(center_count):
		selected.append_array(centers[index].positions)
	for index in range(pair_count):
		selected.append_array(pairs[index].positions)
	return selected


func _has_support(position: Variant, lower_positions: Array) -> bool:
	for lower in lower_positions:
		if position.overlaps_footprint(lower):
			return true
	return false


func _shape_score(shape: String, column: int, row: int, columns: int, rows: int) -> int:
	var dx := absi(column * 2 - (columns - 1))
	var dy := absi(row * 2 - (rows - 1))
	match shape:
		RequirementsScript.SHAPE_DIAMOND:
			return dx * rows + dy * columns
		RequirementsScript.SHAPE_RECTANGLE:
			return maxi(dx * rows, dy * columns)
		_:
			return dx * dx * rows * rows + dy * dy * columns * columns


func _choose_motif(requirements: Variant, z: int, rng: Variant) -> String:
	if requirements.layer_motif_choices.is_empty():
		return RequirementsScript.MOTIF_SOLID
	var choices: Array = requirements.layer_motif_choices[z]
	return str(choices[rng.call("range_int", 0, choices.size() - 1)])


func _motif_score(motif: String, column: int, row: int, columns: int, rows: int) -> int:
	var dx := absi(column * 2 - (columns - 1))
	var dy := absi(row * 2 - (rows - 1))
	match motif:
		RequirementsScript.MOTIF_WINGS:
			return ((columns - 1) - dx) * rows * 2 + dy * columns
		RequirementsScript.MOTIF_BRIDGE:
			return dy * columns * 3 + dx
		RequirementsScript.MOTIF_TOWER:
			return dx * rows * 2 + dy * columns * 2
		RequirementsScript.MOTIF_HOURGLASS:
			var target_dx: int = dy * maxi(1, columns - 1) / maxi(1, rows - 1)
			return absi(dx - target_dx) * rows * 2
		_:
			return 0


func _candidate_key(column: int, row: int) -> String:
	return "%d,%d" % [column, row]


func _candidate_precedes(first: Dictionary, second: Dictionary) -> bool:
	if first.score != second.score:
		return first.score < second.score
	return first.tie < second.tie


func _group_precedes(first: Dictionary, second: Dictionary) -> bool:
	if first.score != second.score:
		return first.score < second.score
	return first.tie < second.tie
