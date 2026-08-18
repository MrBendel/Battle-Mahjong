extends RefCounted

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")
const GameDefinitionScript := preload("res://scripts/simulation/game_definition.gd")
const DeterministicRngScript := preload("res://scripts/simulation/deterministic_rng.gd")

const IDENTITY_COUNT := 24
const COPIES_PER_IDENTITY := 4
const PAIR_COUNT := 48
const TILE_COUNT := 96

const _ROWS_BY_LAYER := [6, 4, 2]
const _ROW_START_BY_LAYER := [0, 2, 4]
const _TILES_PER_ROW := 8

func create_definition(seed: int, tray_capacity: int = 4) -> Variant:
	var placement_pairs := _build_placement_pairs()
	var pair_faces := _build_pair_faces()
	_shuffle(pair_faces, DeterministicRngScript.new(seed))

	var tiles: Array = []
	for pair_index in range(placement_pairs.size()):
		var face: Variant = pair_faces[pair_index]
		var positions: Array = placement_pairs[pair_index]
		for copy_index in range(2):
			var tile_number := tiles.size()
			tiles.append(TileInstanceScript.new(
				"tile_%03d" % tile_number,
				face,
				positions[copy_index]
			))

	return GameDefinitionScript.new(seed, tiles, {"tray_capacity": tray_capacity})
func _build_pair_faces() -> Array:
	var faces: Array = []
	for identity_index in range(IDENTITY_COUNT):
		var face = TileFaceScript.new("reference", "%02d" % (identity_index + 1))
		for _pair_copy in range(COPIES_PER_IDENTITY / 2):
			faces.append(face)

	return faces


func _build_placement_pairs() -> Array:
	var pairs: Array = []
	for z in range(_ROWS_BY_LAYER.size()):
		var row_count: int = _ROWS_BY_LAYER[z]
		var first_y: int = _ROW_START_BY_LAYER[z]
		for row_index in range(row_count):
			var y := first_y + row_index * 2
			for depth_index in range(_TILES_PER_ROW / 2):
				var left_x := depth_index * 2
				var right_x := (_TILES_PER_ROW - 1 - depth_index) * 2
				pairs.append([
					BoardPositionScript.new(left_x, y, z),
					BoardPositionScript.new(right_x, y, z),
				])

	return pairs


func _shuffle(values: Array, rng: Variant) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.call("range_int", 0, index)
		var value: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
