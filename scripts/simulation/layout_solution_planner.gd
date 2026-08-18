extends RefCounted

const BoardSelectabilityScript := preload("res://scripts/simulation/board_selectability.gd")
const TileFaceScript := preload("res://scripts/simulation/tile_face.gd")
const TileInstanceScript := preload("res://scripts/simulation/tile_instance.gd")


func build_plan(layout: Variant) -> Array:
	if layout == null or not layout.call("validation_errors").is_empty():
		return []

	var placeholder_face := TileFaceScript.new("layout", "slot")
	var active: Array = []
	for index in range(layout.positions.size()):
		active.append(TileInstanceScript.new("slot_%03d" % index, placeholder_face, layout.positions[index]))

	var plan: Array = []
	var selectability := BoardSelectabilityScript.new()
	while not active.is_empty():
		var selectable: Array = []
		for slot in active:
			if selectability.call("is_selectable", slot, active):
				selectable.append(slot)
		selectable.sort_custom(_slot_precedes)
		if selectable.size() < 2:
			return []

		var first: Variant = selectable[0]
		var second: Variant = selectable[1]
		plan.append([int(first.id.trim_prefix("slot_")), int(second.id.trim_prefix("slot_"))])
		active.erase(first)
		active.erase(second)

	return plan


func _slot_precedes(first: Variant, second: Variant) -> bool:
	if first.position.z != second.position.z:
		return first.position.z > second.position.z
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	return first.position.x < second.position.x
