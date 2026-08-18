extends RefCounted

const BoardLayoutScript := preload("res://scripts/simulation/board_layout.gd")
const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")

const CLASSIC_96 := "classic_96"
const STAGGERED_96 := "staggered_96"
const DEFAULT_LAYOUT_ID := STAGGERED_96


func get_layout(layout_id: String = DEFAULT_LAYOUT_ID) -> Variant:
	match layout_id:
		CLASSIC_96:
			return BoardLayoutScript.new(layout_id, _layered_positions([0, 0, 0], [0, 2, 4]))
		STAGGERED_96:
			return BoardLayoutScript.new(layout_id, _layered_positions([0, 1, 2], [0, 1, 3]))
		_:
			return null


func layout_ids() -> Array[String]:
	return [CLASSIC_96, STAGGERED_96]


func _layered_positions(x_offsets: Array, y_offsets: Array) -> Array:
	var positions: Array = []
	var rows_by_layer := [6, 4, 2]
	for z in range(rows_by_layer.size()):
		for row_index in range(rows_by_layer[z]):
			for column_index in range(8):
				positions.append(BoardPositionScript.new(
					int(x_offsets[z]) + column_index * 2,
					int(y_offsets[z]) + row_index * 2,
					z
				))
	return positions
