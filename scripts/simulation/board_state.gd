extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")

var tiles: Array
var _definition: Variant
var _state: Variant
var _selectability := BoardSelectabilityScript.new()


func _init(definition: Variant, state: Variant) -> void:
	_definition = definition
	_state = state
	tiles = []
	for physical_tile in definition.tiles:
		var slot_id: String = str(state.tile_slot_ids.get(physical_tile.id, physical_tile.id))
		if slot_id == physical_tile.id:
			tiles.append(physical_tile)
			continue
		var slot_tile: Variant = definition.get_tile(slot_id)
		tiles.append(TileInstanceScript.new(physical_tile.id, physical_tile.face, slot_tile.position))


func get_tile(tile_id: String) -> Variant:
	if _state.tile_slot_ids.get(tile_id) == tile_id:
		return _definition.get_tile(tile_id)
	for tile in tiles:
		if tile.id == tile_id:
			return tile
	return null


func active_tiles() -> Array:
	return _active_tiles_excluding("")


func selectable_tiles() -> Array:
	return _selectable_tiles_from(active_tiles())


func selectable_tiles_without(tile_id: String) -> Array:
	return _selectable_tiles_from(_active_tiles_excluding(tile_id))


func is_tile_active(tile_id: String) -> bool:
	return _state.tile_zones.get(tile_id) == GameStateDataScript.ZONE_BOARD


func is_tile_selectable(tile_id: String) -> bool:
	var tile: Variant = get_tile(tile_id)
	return tile != null and _selectability.call("is_selectable", tile, active_tiles())


func _active_tiles_excluding(excluded_tile_id: String) -> Array:
	var active: Array = []
	for tile in tiles:
		if tile.id != excluded_tile_id and is_tile_active(tile.id):
			active.append(tile)
	return active


func _selectable_tiles_from(active: Array) -> Array:
	var selectable: Array = []
	for tile in active:
		if _selectability.call("is_selectable", tile, active):
			selectable.append(tile)
	return selectable
