extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")


func is_ready(definition: Variant, state: Variant) -> bool:
	var board := BoardStateScript.new(definition, state)
	var active: Array = board.call("active_tiles")
	return not active.is_empty() and board.call("visible_tiles").size() == active.size()


func next_step(definition: Variant, state: Variant) -> Dictionary:
	if not is_ready(definition, state):
		return {}
	var board := BoardStateScript.new(definition, state)
	var interactive := _interactive_tiles(board)
	for held_id in state.tray_tile_ids:
		var held: Variant = definition.get_tile(held_id)
		for tile in interactive:
			if held != null and tile.face.equals(held.face):
				return {"kind": "tray_match", "tile_ids": [tile.id]}
	if state.tray_tile_ids.size() < definition.tray_capacity() - 1:
		for first_index in range(interactive.size()):
			var first: Variant = interactive[first_index]
			if board.call("is_tile_face_down", first.id):
				continue
			for second_index in range(first_index + 1, interactive.size()):
				var second: Variant = interactive[second_index]
				if not board.call("is_tile_face_down", second.id) \
						and first.face.equals(second.face):
					return {"kind": "pair", "tile_ids": [first.id, second.id]}
	for tile in interactive:
		if board.call("is_tile_face_down", tile.id):
			return {"kind": "reveal", "tile_ids": [tile.id]}
	if state.tray_tile_ids.size() < definition.tray_capacity() - 1:
		for tile in interactive:
			if board.call("is_tile_revealed_flipped", tile.id):
				return {"kind": "stage_revealed", "tile_ids": [tile.id]}
	return {}


func _interactive_tiles(board: Variant) -> Array:
	var by_id := {}
	for tile in board.call("selectable_tiles"):
		by_id[tile.id] = tile
	for tile in board.call("revealable_tiles"):
		by_id[tile.id] = tile
	for tile in board.call("active_tiles"):
		if board.call("is_tile_revealed_flipped", tile.id) \
				and board.call("is_tile_accessible", tile.id):
			by_id[tile.id] = tile
	var result: Array = by_id.values()
	result.sort_custom(func(first: Variant, second: Variant) -> bool:
		if first.position.z != second.position.z:
			return first.position.z > second.position.z
		if first.position.y != second.position.y:
			return first.position.y < second.position.y
		if first.position.x != second.position.x:
			return first.position.x < second.position.x
		return first.id < second.id
	)
	return result
