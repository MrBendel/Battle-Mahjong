extends RefCounted

func is_selectable(tile: Variant, tiles: Array) -> bool:
	if tile == null or not tiles.has(tile):
		return false

	if _has_tile_above(tile, tiles):
		return false

	return not (_has_left_blocker(tile, tiles) and _has_right_blocker(tile, tiles))


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
