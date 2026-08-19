extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")

var _selectability := BoardSelectabilityScript.new()


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
	var singles: Array[String] = []
	var pairs: Array = []
	if not _search_singles(active, state.tray_tile_ids.size(), singles, pairs):
		return {}
	return {"tray_slots": singles, "pair_slots": pairs}


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
	var selectable: Array = []
	for tile in active:
		if _selectability.call("is_selectable", tile, active):
			selectable.append(tile)
	selectable.sort_custom(_slot_precedes)
	return selectable


func _slot_precedes(first: Variant, second: Variant) -> bool:
	if first.position.z != second.position.z:
		return first.position.z > second.position.z
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	if first.position.x != second.position.x:
		return first.position.x < second.position.x
	return first.id < second.id
