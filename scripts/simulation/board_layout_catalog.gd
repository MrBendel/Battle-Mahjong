extends RefCounted

const BoardLayoutScript := preload("res://scripts/simulation/board_layout.gd")
const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")

const CLASSIC_96 := "classic_96"
const STAGGERED_96 := "staggered_96"
const PORTRAIT_STACK_96 := "portrait_stack_96"
const DEFAULT_LAYOUT_ID := PORTRAIT_STACK_96


func get_layout(layout_id: String = DEFAULT_LAYOUT_ID) -> Variant:
	match layout_id:
		CLASSIC_96:
			return BoardLayoutScript.new(layout_id, _layered_positions([0, 0, 0], [0, 2, 4]))
		STAGGERED_96:
			return BoardLayoutScript.new(layout_id, _layered_positions([0, 1, 2], [0, 1, 3]))
		PORTRAIT_STACK_96:
			return BoardLayoutScript.new(layout_id, _portrait_stack_positions())
		_:
			return null


func layout_ids() -> Array[String]:
	return [CLASSIC_96, STAGGERED_96, PORTRAIT_STACK_96]


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


func _portrait_stack_positions() -> Array:
	var positions: Array = []
	for y in range(0, 13, 2):
		_add_row(positions, y, 0, [0, 2, 4, 6, 8, 10])

	_add_row(positions, 0, 1, [1, 3, 7, 9])
	_add_row(positions, 1, 1, [5])
	_add_row(positions, 2, 1, [1, 3, 7, 9])
	_add_row(positions, 3, 1, [5])
	_add_row(positions, 5, 1, [0, 2, 4, 6, 8, 10])
	_add_row(positions, 7, 1, [1, 3, 5, 7, 9])
	_add_row(positions, 9, 1, [5])
	_add_row(positions, 10, 1, [1, 3, 7, 9])
	_add_row(positions, 11, 1, [5])
	_add_row(positions, 12, 1, [1, 3, 7, 9])

	_add_row(positions, 0, 2, [2, 8])
	_add_row(positions, 1, 2, [5])
	_add_row(positions, 4, 2, [3, 7])
	_add_row(positions, 5, 2, [1, 9])
	_add_row(positions, 6, 2, [3, 5, 7])
	_add_row(positions, 8, 2, [5])
	_add_row(positions, 10, 2, [2, 4, 6, 8])
	_add_row(positions, 12, 2, [2, 8])

	_add_row(positions, 2, 3, [3])
	_add_row(positions, 5, 3, [2, 8])
	_add_row(positions, 6, 3, [4, 6])
	_add_row(positions, 10, 3, [7])
	return positions


func _add_row(positions: Array, y: int, z: int, x_values: Array) -> void:
	for x in x_values:
		positions.append(BoardPositionScript.new(int(x), y, z))
