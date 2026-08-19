extends RefCounted

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")

func is_selectable(tile: Variant, tiles: Array) -> bool:
	if tile == null or not tiles.has(tile):
		return false

	if _has_tile_above(tile, tiles):
		return false

	return not (_has_left_blocker(tile, tiles) and _has_right_blocker(tile, tiles))


func is_visible(tile: Variant, tiles: Array) -> bool:
	if tile == null or not tiles.has(tile):
		return false

	for cell_x in range(tile.position.x, tile.position.x + BoardPositionScript.FOOTPRINT_SIZE):
		for cell_y in range(tile.position.y, tile.position.y + BoardPositionScript.FOOTPRINT_SIZE):
			if not _is_cell_covered(tile, cell_x, cell_y, tiles):
				return true
	return false


func _is_cell_covered(tile: Variant, cell_x: int, cell_y: int, tiles: Array) -> bool:
	for other in tiles:
		if not _is_active_other(tile, other) or other.position.z <= tile.position.z:
			continue
		if cell_x >= other.position.x \
				and cell_x < other.position.x + BoardPositionScript.FOOTPRINT_SIZE \
				and cell_y >= other.position.y \
				and cell_y < other.position.y + BoardPositionScript.FOOTPRINT_SIZE:
			return true
	return false


func _has_tile_above(tile: Variant, tiles: Array) -> bool:
	for other in tiles:
		if _is_active_other(tile, other) and other.position.z > tile.position.z and other.position.overlaps_footprint(tile.position):
			return true

	return false


func _has_left_blocker(tile: Variant, tiles: Array) -> bool:
	for other in tiles:
		if _is_active_other(tile, other) and other.position.is_immediately_left_of(tile.position):
			return true

	return false


func _has_right_blocker(tile: Variant, tiles: Array) -> bool:
	for other in tiles:
		if _is_active_other(tile, other) and other.position.is_immediately_right_of(tile.position):
			return true

	return false


func _is_active_other(tile: Variant, other: Variant) -> bool:
	return other != null and other != tile
