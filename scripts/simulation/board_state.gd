extends RefCounted

const TileMatcherScript := preload("res://scripts/simulation/tile_matcher.gd")
const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")

var tiles: Array = []
var _matcher := TileMatcherScript.new()
var _selectability := BoardSelectabilityScript.new()

func _init(initial_tiles: Array = []) -> void:
	tiles = initial_tiles.duplicate()


func get_tile(tile_id: String) -> Variant:
	for tile in tiles:
		if tile.id == tile_id:
			return tile

	return null


func active_tiles() -> Array:
	var active: Array = []
	for tile in tiles:
		if not tile.removed:
			active.append(tile)

	return active


func selectable_tiles() -> Array:
	var selectable: Array = []
	for tile in tiles:
		if _selectability.call("is_selectable", tile, tiles):
			selectable.append(tile)

	return selectable


func is_tile_selectable(tile_id: String) -> bool:
	return _selectability.call("is_selectable", get_tile(tile_id), tiles)


func take_tile(tile_id: String) -> Variant:
	var tile: Variant = get_tile(tile_id)
	if not _selectability.call("is_selectable", tile, tiles):
		return null

	tile.removed = true
	return tile


func remove_matching_pair(first_tile_id: String, second_tile_id: String) -> bool:
	var first: Variant = get_tile(first_tile_id)
	var second: Variant = get_tile(second_tile_id)

	if first == null or second == null or first == second:
		return false

	if first.removed or second.removed:
		return false

	if not _matcher.call("tiles_match", first, second):
		return false

	if not _selectability.call("is_selectable", first, tiles):
		return false

	if not _selectability.call("is_selectable", second, tiles):
		return false

	first.removed = true
	second.removed = true
	return true
