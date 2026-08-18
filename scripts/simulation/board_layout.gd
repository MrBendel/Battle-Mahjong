extends RefCounted

var id: String
var positions: Array


func _init(layout_id: String, layout_positions: Array) -> void:
	id = layout_id
	positions = layout_positions.duplicate()


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("layout id must not be empty")
	if positions.is_empty() or positions.size() % 2 != 0:
		errors.append("layout must contain a positive even number of positions")

	for index in range(positions.size()):
		var position: Variant = positions[index]
		if position == null or position.z < 0:
			errors.append("position %d must exist at a non-negative z level" % index)
			continue
		for other_index in range(index):
			var other: Variant = positions[other_index]
			if other != null and position.z == other.z and position.overlaps_footprint(other):
				errors.append("positions %d and %d overlap on the same z level" % [other_index, index])

	return errors


func has_partial_overlap() -> bool:
	for index in range(positions.size()):
		for other_index in range(index):
			var first: Variant = positions[index]
			var second: Variant = positions[other_index]
			if first.z != second.z and first.overlaps_footprint(second):
				var x_offset: int = absi(first.x - second.x)
				var y_offset: int = absi(first.y - second.y)
				if x_offset % 2 == 1 or y_offset % 2 == 1:
					return true
	return false
