extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")

const LOCAL_RADIUS := 4


func analyze(definition: Variant, state: Variant) -> Dictionary:
	var board := BoardStateScript.new(definition, state)
	var active: Array = board.call("active_tiles")
	var selectable: Array = board.call("selectable_tiles")
	selectable.sort_custom(func(first: Variant, second: Variant) -> bool: return first.id < second.id)
	var bounds := _bounds(active)
	var maximum_z := 0
	for tile in active:
		maximum_z = maxi(maximum_z, tile.position.z)

	var tile_scores: Array = []
	var tile_scores_by_id := {}
	for tile in selectable:
		var entry := _score_tile(tile, active, selectable, bounds, maximum_z)
		tile_scores.append(entry)
		tile_scores_by_id[tile.id] = entry
	_rank_entries(tile_scores)

	var pair_scores: Array = []
	for first_index in range(selectable.size()):
		for second_index in range(first_index + 1, selectable.size()):
			var first: Variant = selectable[first_index]
			var second: Variant = selectable[second_index]
			if not first.face.equals(second.face):
				continue
			pair_scores.append(_score_pair(
				first,
				second,
				tile_scores_by_id,
				selectable,
				bounds
			))
	_rank_entries(pair_scores)

	return {
		"board_revision": state.revision,
		"active_tile_count": active.size(),
		"selectable_tile_count": selectable.size(),
		"available_pair_count": pair_scores.size(),
		"tile_scores": tile_scores,
		"pair_scores": pair_scores,
		"hardest_tile": _extreme_entry(tile_scores, true),
		"easiest_tile": _extreme_entry(tile_scores, false),
		"hardest_pair": _extreme_entry(pair_scores, true),
		"easiest_pair": _extreme_entry(pair_scores, false),
	}


func tile_entry(analysis: Dictionary, tile_id: String) -> Dictionary:
	for entry in analysis.get("tile_scores", []):
		if str(entry.get("tile_id", "")) == tile_id:
			return entry.duplicate(true)
	return {}


func pair_entries_for_tile(analysis: Dictionary, tile_id: String) -> Array:
	var matches: Array = []
	for entry in analysis.get("pair_scores", []):
		if tile_id in entry.get("tile_ids", []):
			matches.append(entry.duplicate(true))
	return matches


func _score_tile(tile: Variant, active: Array, selectable: Array, bounds: Dictionary, maximum_z: int) -> Dictionary:
	var local_neighbors := 0
	for other in active:
		if other.id == tile.id:
			continue
		if absi(other.position.x - tile.position.x) <= LOCAL_RADIUS \
				and absi(other.position.y - tile.position.y) <= LOCAL_RADIUS:
			local_neighbors += 1

	var selectable_mates := 0
	for other in selectable:
		if other.id != tile.id and other.face.equals(tile.face):
			selectable_mates += 1
	var horizontal_depth := mini(
		tile.position.x - int(bounds.minimum_x),
		int(bounds.maximum_x) - tile.position.x
	)
	var vertical_depth := mini(
		tile.position.y - int(bounds.minimum_y),
		int(bounds.maximum_y) - tile.position.y
	)
	var interior_depth: int = maxi(0, mini(horizontal_depth, vertical_depth))
	var components := {
		"base": 10,
		"search_space": selectable.size() * 2,
		"local_crowding": local_neighbors * 4,
		"lower_layer_depth": (maximum_z - tile.position.z) * 8,
		"interior_depth": interior_depth * 2,
		"alternate_mate_relief": -maxi(0, selectable_mates - 1) * 8,
	}
	return {
		"id": tile.id,
		"tile_id": tile.id,
		"face_id": tile.face.logical_id(),
		"score": maxi(0, _component_total(components)),
		"components": components,
		"selectable_mate_count": selectable_mates,
	}


func _score_pair(
		first: Variant,
		second: Variant,
		tile_scores_by_id: Dictionary,
		selectable: Array,
		bounds: Dictionary
) -> Dictionary:
	var ids: Array[String] = [first.id, second.id]
	ids.sort()
	var identity_count := 0
	for tile in selectable:
		if tile.face.equals(first.face):
			identity_count += 1
	var crosses_x: bool = _opposite_sides(
		first.position.x,
		second.position.x,
		int(bounds.minimum_x) + int(bounds.maximum_x)
	)
	var crosses_y: bool = _opposite_sides(
		first.position.y,
		second.position.y,
		int(bounds.minimum_y) + int(bounds.maximum_y)
	)
	var first_score: int = int(tile_scores_by_id[first.id].score)
	var second_score: int = int(tile_scores_by_id[second.id].score)
	var components := {
		"tile_difficulty": int((first_score + second_score) / 2),
		"spatial_separation": (
			absi(first.position.x - second.position.x) \
			+ absi(first.position.y - second.position.y)
		) * 2,
		"layer_separation": absi(first.position.z - second.position.z) * 8,
		"region_span": (int(crosses_x) + int(crosses_y)) * 8,
		"alternate_mate_relief": -maxi(0, identity_count - 2) * 6,
	}
	return {
		"id": "%s|%s" % ids,
		"tile_ids": ids,
		"face_id": first.face.logical_id(),
		"score": maxi(0, _component_total(components)),
		"components": components,
		"selectable_identity_count": identity_count,
	}


func _rank_entries(entries: Array) -> void:
	var ordered := entries.duplicate(true)
	ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if int(first.score) == int(second.score):
			return str(first.id) < str(second.id)
		return int(first.score) > int(second.score)
	)
	var rank_by_id := {}
	for index in ordered.size():
		rank_by_id[str(ordered[index].id)] = index + 1
	for entry in entries:
		var rank: int = int(rank_by_id[entry.id])
		entry["difficulty_rank"] = rank
		entry["difficulty_percentile_bps"] = 10000 if entries.size() == 1 else int(
			10000 * (entries.size() - rank) / (entries.size() - 1)
		)


func _extreme_entry(entries: Array, hardest: bool) -> Dictionary:
	if entries.is_empty():
		return {}
	var target_rank := 1 if hardest else entries.size()
	for entry in entries:
		if int(entry.difficulty_rank) == target_rank:
			return entry.duplicate(true)
	return {}


func _bounds(tiles: Array) -> Dictionary:
	if tiles.is_empty():
		return {"minimum_x": 0, "maximum_x": 0, "minimum_y": 0, "maximum_y": 0}
	var minimum_x: int = tiles[0].position.x
	var maximum_x: int = minimum_x
	var minimum_y: int = tiles[0].position.y
	var maximum_y: int = minimum_y
	for tile in tiles:
		minimum_x = mini(minimum_x, tile.position.x)
		maximum_x = maxi(maximum_x, tile.position.x)
		minimum_y = mini(minimum_y, tile.position.y)
		maximum_y = maxi(maximum_y, tile.position.y)
	return {
		"minimum_x": minimum_x,
		"maximum_x": maximum_x,
		"minimum_y": minimum_y,
		"maximum_y": maximum_y,
	}


func _component_total(components: Dictionary) -> int:
	var total := 0
	for value in components.values():
		total += int(value)
	return total


func _opposite_sides(first: int, second: int, doubled_midpoint: int) -> bool:
	return (first * 2 < doubled_midpoint and second * 2 > doubled_midpoint) \
		or (second * 2 < doubled_midpoint and first * 2 > doubled_midpoint)
