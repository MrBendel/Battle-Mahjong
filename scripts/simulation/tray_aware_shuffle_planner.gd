extends RefCounted

const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")

var _above_by_id: Dictionary = {}
var _left_by_id: Dictionary = {}
var _right_by_id: Dictionary = {}


func build_slot_plan(definition: Variant, state: Variant) -> Dictionary:
	var active: Array = []
	for tile_id in state.tile_zones:
		if state.tile_zones[tile_id] != "board":
			continue
		var slot_id: String = str(state.tile_slot_ids[tile_id])
		var slot_tile: Variant = definition.get_tile(slot_id)
		if slot_tile == null:
			return {}
		active.append(TileInstanceScript.new(slot_id, TileFaceScript.new("shuffle", "slot"), slot_tile.position))
	_index_blockers(active)
	var singles: Array[String] = []
	var pairs: Array = []
	if not _search_singles(active, state.tray_tile_ids.size(), singles, pairs):
		return {}
	return {"tray_slots": singles, "pair_slots": pairs}


func verify_mapping_route(
	definition: Variant,
	state: Variant,
	mapping_after: Dictionary,
	route: Array[String]
) -> Dictionary:
	var active: Array = []
	var active_by_id := {}
	for physical_tile in definition.tiles:
		if state.tile_zones[physical_tile.id] != "board":
			continue
		var slot_id: String = str(mapping_after.get(physical_tile.id, ""))
		var slot_tile: Variant = definition.get_tile(slot_id)
		if slot_tile == null:
			return {"valid": false, "reason": "route maps a tile to a missing slot"}
		var projected := TileInstanceScript.new(
			physical_tile.id,
			physical_tile.face,
			slot_tile.position
		)
		active.append(projected)
		active_by_id[projected.id] = projected
	if route.size() != active.size():
		return {"valid": false, "reason": "route length does not match active Board tiles"}
	_index_blockers(active)

	var route_index := 0
	for tray_tile_id in state.tray_tile_ids:
		if route_index >= route.size():
			return {"valid": false, "reason": "route cannot resolve every held tray tile"}
		var routed: Variant = active_by_id.get(route[route_index])
		var held: Variant = definition.get_tile(tray_tile_id)
		if routed == null or held == null or not routed.face.equals(held.face):
			return {"valid": false, "reason": "route does not resolve the held tray prefix"}
		if not _is_selectable_indexed(routed.id, active_by_id):
			return {"valid": false, "reason": "tray-prefix route tile is not selectable"}
		active.erase(routed)
		active_by_id.erase(routed.id)
		route_index += 1

	while route_index < route.size():
		if route_index + 1 >= route.size():
			return {"valid": false, "reason": "pair route has an unmatched final tile"}
		var first: Variant = active_by_id.get(route[route_index])
		var second: Variant = active_by_id.get(route[route_index + 1])
		if first == null or second == null or not first.face.equals(second.face):
			return {"valid": false, "reason": "pair route contains a missing or mismatched pair"}
		if not _is_selectable_indexed(first.id, active_by_id) \
				or not _is_selectable_indexed(second.id, active_by_id):
			return {"valid": false, "reason": "pair route contains a blocked tile"}
		active.erase(first)
		active.erase(second)
		active_by_id.erase(first.id)
		active_by_id.erase(second.id)
		route_index += 2

	return {"valid": active.is_empty(), "reason": "" if active.is_empty() else "route leaves active tiles"}


func _search_singles(active: Array, remaining: int, singles: Array[String], pairs: Array) -> bool:
	if remaining == 0:
		var pair_plan := _build_pair_plan(active)
		if pair_plan.size() * 2 != active.size():
			return false
		pairs.assign(pair_plan)
		return true
	var selectable := _selectable(active)
	for slot in selectable:
		var next := active.duplicate()
		next.erase(slot)
		singles.append(slot.id)
		if _search_singles(next, remaining - 1, singles, pairs):
			return true
		singles.pop_back()
	return false


func _build_pair_plan(active_tiles: Array) -> Array:
	var active := active_tiles.duplicate()
	var plan: Array = []
	while not active.is_empty():
		var selectable := _selectable(active)
		if selectable.size() < 2:
			return []
		var first: Variant = selectable[0]
		var second: Variant = selectable[1]
		plan.append([first.id, second.id])
		active.erase(first)
		active.erase(second)
	return plan


func _selectable(active: Array) -> Array:
	var active_by_id := {}
	for tile in active:
		active_by_id[tile.id] = tile
	var selectable: Array = []
	for tile in active:
		if _is_selectable_indexed(tile.id, active_by_id):
			selectable.append(tile)
	selectable.sort_custom(_slot_precedes)
	return selectable


func _index_blockers(tiles: Array) -> void:
	_above_by_id.clear()
	_left_by_id.clear()
	_right_by_id.clear()
	for tile in tiles:
		_above_by_id[tile.id] = []
		_left_by_id[tile.id] = []
		_right_by_id[tile.id] = []
	for tile in tiles:
		for other in tiles:
			if other == tile:
				continue
			if other.position.z > tile.position.z \
					and other.position.overlaps_footprint(tile.position):
				_above_by_id[tile.id].append(other.id)
			if other.position.is_immediately_left_of(tile.position):
				_left_by_id[tile.id].append(other.id)
			if other.position.is_immediately_right_of(tile.position):
				_right_by_id[tile.id].append(other.id)


func _is_selectable_indexed(tile_id: String, active_by_id: Dictionary) -> bool:
	if not active_by_id.has(tile_id):
		return false
	for blocker_id in _above_by_id.get(tile_id, []):
		if active_by_id.has(blocker_id):
			return false
	var has_left := false
	for blocker_id in _left_by_id.get(tile_id, []):
		if active_by_id.has(blocker_id):
			has_left = true
			break
	if not has_left:
		return true
	for blocker_id in _right_by_id.get(tile_id, []):
		if active_by_id.has(blocker_id):
			return false
	return true


func _slot_precedes(first: Variant, second: Variant) -> bool:
	if first.position.z != second.position.z:
		return first.position.z > second.position.z
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	if first.position.x != second.position.x:
		return first.position.x < second.position.x
	return first.id < second.id
