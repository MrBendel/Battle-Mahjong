extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")


func analyze(layout: Variant, constraints: Dictionary = {}) -> Dictionary:
	if layout == null or not layout.call("validation_errors").is_empty():
		return {"valid": false, "errors": ["layout is invalid"], "metrics": {}}

	var positions: Array = layout.positions
	var minimum_x: int = positions[0].x
	var maximum_x: int = positions[0].x
	var minimum_y: int = positions[0].y
	var maximum_y: int = positions[0].y
	var maximum_z := 0
	var rows_by_layer := {}
	for position in positions:
		minimum_x = mini(minimum_x, position.x)
		maximum_x = maxi(maximum_x, position.x)
		minimum_y = mini(minimum_y, position.y)
		maximum_y = maxi(maximum_y, position.y)
		maximum_z = maxi(maximum_z, position.z)
		var layer_rows: Dictionary = rows_by_layer.get(position.z, {})
		layer_rows[position.y] = int(layer_rows.get(position.y, 0)) + 1
		rows_by_layer[position.z] = layer_rows

	var width_units: int = maximum_x - minimum_x + 2
	var height_units: int = maximum_y - minimum_y + 2
	var width_to_height_bps: int = width_units * 10000 / height_units
	var placeholder_face := TileFaceScript.new("layout", "mobile_fit")
	var tiles: Array = []
	for index in range(positions.size()):
		tiles.append(TileInstanceScript.new("fit_%03d" % index, placeholder_face, positions[index]))
	var selectability := BoardSelectabilityScript.new()
	var initial_selectable := 0
	for tile in tiles:
		if selectability.call("is_selectable", tile, tiles):
			initial_selectable += 1

	var reference_width := int(constraints.get("reference_board_width_px", 0))
	var reference_height := int(constraints.get("reference_board_height_px", 0))
	var tile_height_bps := int(constraints.get("tile_height_to_width_bps", 12500))
	var rendered_tile_width := 0
	if reference_width > 0 and reference_height > 0 and tile_height_bps > 0:
		var width_limited: int = reference_width * 2 / width_units
		var height_limited: int = reference_height * 2 * 10000 / (height_units * tile_height_bps)
		rendered_tile_width = mini(width_limited, height_limited)

	var row_width_variation := 0
	var widest_row_tile_count := 0
	for layer_rows in rows_by_layer.values():
		var widths: Array = layer_rows.values()
		if not widths.is_empty():
			row_width_variation += _maximum(widths) - _minimum(widths)
			widest_row_tile_count = maxi(widest_row_tile_count, _maximum(widths))

	var metrics := {
		"width_units": width_units,
		"height_units": height_units,
		"width_to_height_basis_points": width_to_height_bps,
		"layer_count": maximum_z + 1,
		"initial_selectable_tile_count": initial_selectable,
		"estimated_reference_tile_width_px": rendered_tile_width,
		"row_width_variation": row_width_variation,
		"widest_row_tile_count": widest_row_tile_count,
		"has_partial_overlap": layout.call("has_partial_overlap"),
	}
	var errors: Array[String] = []
	_check_maximum(errors, "width-to-height ratio", width_to_height_bps, constraints, "maximum_width_to_height_bps")
	_check_minimum(errors, "initial selectable tiles", initial_selectable, constraints, "minimum_initial_selectable_tiles")
	_check_maximum(errors, "initial selectable tiles", initial_selectable, constraints, "maximum_initial_selectable_tiles")
	_check_maximum(errors, "layer count", maximum_z + 1, constraints, "maximum_layer_count")
	_check_minimum(errors, "estimated tile width", rendered_tile_width, constraints, "minimum_tile_width_px")
	_check_minimum(errors, "row width variation", row_width_variation, constraints, "minimum_row_width_variation")
	_check_minimum(errors, "widest row tile count", widest_row_tile_count, constraints, "minimum_widest_row_tiles")
	if bool(constraints.get("require_partial_overlap", false)) and not layout.call("has_partial_overlap"):
		errors.append("layout requires partial overlap")
	return {"valid": errors.is_empty(), "errors": errors, "metrics": metrics}


func _check_minimum(
		errors: Array[String], label: String, value: int, constraints: Dictionary, key: String
) -> void:
	if constraints.has(key) and value < int(constraints[key]):
		errors.append("%s %d is below minimum %d" % [label, value, int(constraints[key])])


func _check_maximum(
		errors: Array[String], label: String, value: int, constraints: Dictionary, key: String
) -> void:
	if constraints.has(key) and value > int(constraints[key]):
		errors.append("%s %d exceeds maximum %d" % [label, value, int(constraints[key])])


func _minimum(values: Array) -> int:
	var result := int(values[0])
	for value in values:
		result = mini(result, int(value))
	return result


func _maximum(values: Array) -> int:
	var result := int(values[0])
	for value in values:
		result = maxi(result, int(value))
	return result
