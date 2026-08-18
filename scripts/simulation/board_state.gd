extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")

var tiles: Array
var _definition: Variant
var _state: Variant
var _selectability := BoardSelectabilityScript.new()


func _init(definition: Variant, state: Variant) -> void:
	_definition = definition
	_state = state
	tiles = definition.tiles


func get_tile(tile_id: String) -> Variant:
	return _definition.get_tile(tile_id)


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
