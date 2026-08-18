extends RefCounted

const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")
const BoardStateScript := preload("res://scripts/simulation/board_state.gd")

func m1_smoke_layout() -> Variant:
	var bamboo_1 = TileFaceScript.new(TileFaceScript.FAMILY_BAMBOO, "1")
	var dots_2 = TileFaceScript.new(TileFaceScript.FAMILY_DOTS, "2")
	var east = TileFaceScript.new(TileFaceScript.FAMILY_WIND, TileFaceScript.WIND_EAST)

	var tiles: Array = [
		TileInstanceScript.new("tile_001", bamboo_1, BoardPositionScript.new(0, 0, 0)),
		TileInstanceScript.new("tile_002", bamboo_1, BoardPositionScript.new(6, 0, 0)),
		TileInstanceScript.new("tile_003", dots_2, BoardPositionScript.new(2, 0, 0)),
		TileInstanceScript.new("tile_004", dots_2, BoardPositionScript.new(4, 0, 0)),
		TileInstanceScript.new("tile_005", east, BoardPositionScript.new(2, 0, 1)),
		TileInstanceScript.new("tile_006", east, BoardPositionScript.new(4, 0, 1)),
	]

	return BoardStateScript.new(tiles)
