extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")


func build_route(
	definition: Variant,
	state: Variant,
	pair_count: int,
	prioritize_top_layers := true
) -> Array:
	if pair_count <= 0:
		return []
	if prioritize_top_layers:
		var board := BoardStateScript.new(definition, state)
		var eligible_pairs := _selectable_pairs(definition, state, board)
		_sort_pairs_top_down(eligible_pairs, board)
		var fixed_route: Array = []
		var used_tile_ids := {}
		for pair in eligible_pairs:
			if used_tile_ids.has(pair[0]) or used_tile_ids.has(pair[1]):
				continue
			fixed_route.append(pair)
			used_tile_ids[pair[0]] = true
			used_tile_ids[pair[1]] = true
			if fixed_route.size() >= pair_count:
				break
		return fixed_route

	var projected: Variant = state.duplicate_data()
	var route: Array = []
	for _step in range(maxi(0, pair_count)):
		var pair := _first_selectable_pair(definition, projected)
		if pair.is_empty():
			break
		route.append(pair)
		for tile_id in pair:
			projected.tile_zones[tile_id] = GameStateDataScript.ZONE_RESOLVED
	return route


func build_random_route(definition: Variant, state: Variant, pair_count: int) -> Dictionary:
	var projected: Variant = state.duplicate_data()
	var rng := DeterministicRngScript.new(state.rng_state)
	var route: Array = []
	for _step in range(maxi(0, pair_count)):
		var pairs := _selectable_pairs(definition, projected)
		if pairs.is_empty():
			break
		var pair: Array = pairs[rng.call("range_int", 0, pairs.size() - 1)]
		route.append(pair)
		for tile_id in pair:
			projected.tile_zones[tile_id] = GameStateDataScript.ZONE_RESOLVED
	return {"route": route, "rng_state": rng.call("get_state")}


func _first_selectable_pair(
	definition: Variant,
	state: Variant
) -> Array[String]:
	var board := BoardStateScript.new(definition, state)
	var pairs := _selectable_pairs(definition, state, board)
	if pairs.is_empty():
		return []
	var result: Array[String] = []
	result.assign(pairs[0])
	return result


func _sort_pairs_top_down(pairs: Array, board: Variant) -> void:
	pairs.sort_custom(func(first: Array, second: Array) -> bool:
		var first_layers := _pair_layers(board, first)
		var second_layers := _pair_layers(board, second)
		if first_layers.x != second_layers.x:
			return first_layers.x > second_layers.x
		if first_layers.y != second_layers.y:
			return first_layers.y > second_layers.y
		return "|".join(first) < "|".join(second)
	)


func _pair_layers(board: Variant, pair: Array) -> Vector2i:
	var lowest_layer := 2147483647
	var highest_layer := -1
	for tile_id in pair:
		var tile: Variant = board.get_tile(tile_id)
		if tile != null:
			lowest_layer = mini(lowest_layer, tile.position.z)
			highest_layer = maxi(highest_layer, tile.position.z)
	return Vector2i(lowest_layer, highest_layer)


func _selectable_pairs(definition: Variant, state: Variant, board: Variant = null) -> Array:
	var projected_board: Variant = BoardStateScript.new(definition, state) if board == null else board
	var selectable: Array = projected_board.call("selectable_tiles")
	selectable.sort_custom(func(first: Variant, second: Variant) -> bool: return first.id < second.id)
	var pairs: Array = []
	for first_index in range(selectable.size()):
		var first: Variant = selectable[first_index]
		if _face_has_active_modifier(definition, state, first.face) \
				or _face_is_held(definition, state, first.face):
			continue
		for second_index in range(first_index + 1, selectable.size()):
			var second: Variant = selectable[second_index]
			if first.face.equals(second.face):
				pairs.append([first.id, second.id])
				break
	return pairs


func _face_is_held(definition: Variant, state: Variant, face: Variant) -> bool:
	for tile_id in state.tray_tile_ids:
		var held: Variant = definition.get_tile(tile_id)
		if held != null and held.face.equals(face):
			return true
	return false


func _face_has_active_modifier(definition: Variant, state: Variant, face: Variant) -> bool:
	for tile in definition.tiles:
		if state.tile_zones.get(tile.id) != GameStateDataScript.ZONE_RESOLVED \
				and tile.face.equals(face) \
				and not definition.modifier_for_tile(tile.id).is_empty():
			return true
	return false
