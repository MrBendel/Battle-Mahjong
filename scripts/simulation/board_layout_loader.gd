extends RefCounted

const BoardLayoutScript := preload("res://scripts/simulation/board_layout.gd")
const BoardPositionScript := preload("res://scripts/simulation/board_position.gd")
const LayoutSlotScript := preload("res://scripts/simulation/layout_slot.gd")


func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Board layout file does not exist: %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("Board layout file must contain a JSON object: %s" % path)
		return null
	return from_dict(data)


func from_dict(data: Dictionary) -> Variant:
	if int(data.get("schema_version", 0)) != BoardLayoutScript.SCHEMA_VERSION:
		push_error("Unsupported board layout schema version")
		return null

	var entries: Array = []
	if data.has("slots"):
		for slot_data in data.get("slots", []):
			if not slot_data is Dictionary:
				continue
			var position := BoardPositionScript.new(
				int(slot_data.get("x", 0)),
				int(slot_data.get("y", 0)),
				int(slot_data.get("z", 0))
			)
			entries.append(LayoutSlotScript.new(
				str(slot_data.get("slot_id", LayoutSlotScript.coordinate_id(position))),
				position
			))
	else:
		for layer_data in data.get("layers", []):
			if not layer_data is Dictionary:
				continue
			var z := int(layer_data.get("z", 0))
			for row_data in layer_data.get("rows", []):
				if not row_data is Dictionary:
					continue
				var y := int(row_data.get("y", 0))
				for x_value in row_data.get("x", []):
					var position := BoardPositionScript.new(int(x_value), y, z)
					entries.append(LayoutSlotScript.new(LayoutSlotScript.coordinate_id(position), position))

	var layout := BoardLayoutScript.new(
		str(data.get("layout_id", "")),
		entries,
		int(data.get("revision", 1)),
		data.get("metadata", {})
	)
	var errors: Array[String] = layout.validation_errors()
	if not errors.is_empty():
		push_error("Invalid board layout %s: %s" % [layout.id, "; ".join(errors)])
		return null
	return layout
