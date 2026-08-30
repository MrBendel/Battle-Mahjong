extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")


func build_route(definition: Variant, state: Variant, pair_count: int) -> Array:
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


func _first_selectable_pair(definition: Variant, state: Variant) -> Array[String]:
	var selectable: Array = BoardStateScript.new(definition, state).call("selectable_tiles")
	selectable.sort_custom(func(first: Variant, second: Variant) -> bool: return first.id < second.id)
	for first_index in range(selectable.size()):
		var first: Variant = selectable[first_index]
		if _face_is_held(definition, state, first.face):
			continue
		for second_index in range(first_index + 1, selectable.size()):
			var second: Variant = selectable[second_index]
			if first.face.equals(second.face):
				return [first.id, second.id]
	return []


func _face_is_held(definition: Variant, state: Variant, face: Variant) -> bool:
	for tile_id in state.tray_tile_ids:
		var held: Variant = definition.get_tile(tile_id)
		if held != null and held.face.equals(face):
			return true
	return false
