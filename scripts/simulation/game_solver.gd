extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const GameStateScript := preload("res://scripts/simulation/game_state.gd")

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

	for index in range(0, tile_ids.size(), 2):
		if game.call("select_tile", str(tile_ids[index])) != GameStateScript.SELECTED:
			return {"valid": false, "reason": "tile %d is not a legal first selection" % index}
		if game.call("select_tile", str(tile_ids[index + 1])) != GameStateScript.PAIR_RESOLVED:
			return {"valid": false, "reason": "tiles %d-%d do not resolve a legal pair" % [index, index + 1]}

	return {"valid": game.status == GameStateScript.WON, "reason": "" if game.status == GameStateScript.WON else "solution did not win"}


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
