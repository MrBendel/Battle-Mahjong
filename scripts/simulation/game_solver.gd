extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")
const GameStoreScript := preload("res://scripts/simulation/game_store.gd")

var _selectability := BoardSelectabilityScript.new()
var _visited: Dictionary = {}
var _nodes := 0
var _node_limit := 0


func find_pair_solution(definition: Variant, node_limit: int = 100000) -> Array[String]:
	_visited.clear()
	_nodes = 0
	_node_limit = node_limit
	var path: Array[String] = []
	if _search(definition.tiles.duplicate(), path):
		return path
	return []


func verify_solution(definition: Variant, tile_ids: Array) -> Dictionary:
	var game := GameStateScript.new(definition)
	if tile_ids.size() != definition.tiles.size():
		return {"valid": false, "reason": "solution length does not match tile count"}

	for index in tile_ids.size():
		var tile_id := str(tile_ids[index])
		if not game.board.call("is_tile_active", tile_id) \
				or game.board.call("is_tile_revealed_flipped", tile_id):
			continue
		var result: String = game.call("tap_tile", tile_id)
		if result not in [
			GameStateScript.SELECTED,
			GameStateScript.TILE_REVEALED,
			GameStateScript.PAIR_RESOLVED,
			GameStateScript.FLIPPED_PAIR_RESOLVED,
		]:
			return {"valid": false, "reason": "route tile %d was rejected" % index}

	return {"valid": game.status == GameStateScript.WON, "reason": "" if game.status == GameStateScript.WON else "solution did not win"}


func verify_state_route(definition: Variant, initial_state: Variant, tile_ids: Array) -> Dictionary:
	var state: Variant = initial_state.duplicate_data()
	var store := GameStoreScript.new(definition, state)
	for index in tile_ids.size():
		var board: Variant = BoardStateScript.new(definition, state)
		var tile_id := str(tile_ids[index])
		if not board.call("is_tile_active", tile_id):
			continue
		if board.call("is_tile_revealed_flipped", tile_id):
			continue
		var command_type := GameCommandScript.REVEAL_TILE if board.call("is_tile_face_down", tile_id) \
			else GameCommandScript.SELECT_TILE
		var command := GameCommandScript.new(
			command_type,
			{"tile_id": tile_id},
			state.revision,
			"verify_%06d" % index,
			"solver",
			state.elapsed_time_ms
		)
		var submitted: Dictionary = store.call("submit_command", command)
		if not bool(submitted.accepted):
			return {"valid": false, "reason": "route tile %d was rejected" % index}
		state = store.call("current_state")
	return {"valid": state.status == GameStateScript.WON, "reason": "" if state.status == GameStateScript.WON else "route did not win"}


func _search(active: Array, path: Array[String]) -> bool:
	_nodes += 1
	if _nodes > _node_limit:
		return false
	if active.is_empty():
		return true

	var key := _state_key(active)
	if _visited.has(key):
		return false
	_visited[key] = true

	var selectable: Array = []
	for tile in active:
		if _selectability.call("is_selectable", tile, active):
			selectable.append(tile)
	selectable.sort_custom(_tile_precedes)

	var candidates: Array = []
	for first_index in range(selectable.size()):
		for second_index in range(first_index + 1, selectable.size()):
			var first: Variant = selectable[first_index]
			var second: Variant = selectable[second_index]
			if first.face.equals(second.face):
				candidates.append([first, second])

	for pair in candidates:
		var remaining := active.duplicate()
		remaining.erase(pair[0])
		remaining.erase(pair[1])
		path.append(pair[0].id)
		path.append(pair[1].id)
		if _search(remaining, path):
			return true
		path.resize(path.size() - 2)

	return false


func _tile_precedes(first: Variant, second: Variant) -> bool:
	if first.position.z != second.position.z:
		return first.position.z > second.position.z
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	return first.position.x < second.position.x


func _state_key(active: Array) -> String:
	var ids: Array[String] = []
	for tile in active:
		ids.append(tile.id)
	return ",".join(ids)
