extends RefCounted

const SCHEMA_VERSION := 1
const LayoutSlotScript := preload("res://scripts/simulation/layout_slot.gd")

var id: String:
	get:
		return _id

var revision: int:
	get:
		return _revision

var metadata: Dictionary:
	get:
		return _metadata.duplicate(true)

var slots: Array:
	get:
		var result: Array = []
		for slot in _slots:
			result.append(LayoutSlotScript.new(slot.id, slot.position))
		return result

var positions: Array:
	get:
		var result: Array = []
		for slot in _slots:
			result.append(slot.position)
		return result

var _slots: Array = []
var _content_hash := ""
var _id: String
var _revision: int
var _metadata: Dictionary


func _init(
		layout_id: String,
		layout_entries: Array,
		layout_revision: int = 1,
		layout_metadata: Dictionary = {}
) -> void:
	_id = layout_id
	_revision = layout_revision
	_metadata = layout_metadata.duplicate(true)
	for entry in layout_entries:
		if entry != null and entry.get_script() == LayoutSlotScript:
			_slots.append(LayoutSlotScript.new(entry.id, entry.position))
		elif entry != null:
			_slots.append(LayoutSlotScript.new(LayoutSlotScript.coordinate_id(entry), entry))
	_slots.sort_custom(_slot_precedes)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.is_empty():
		errors.append("layout id must not be empty")
	if revision < 1:
		errors.append("layout revision must be positive")
	if _slots.is_empty() or _slots.size() % 2 != 0:
		errors.append("layout must contain a positive even number of slots")

	var slot_ids := {}
	for index in range(_slots.size()):
		var slot: Variant = _slots[index]
		if slot.id.is_empty():
			errors.append("slot %d must have an id" % index)
		elif slot_ids.has(slot.id):
			errors.append("duplicate slot id: %s" % slot.id)
		slot_ids[slot.id] = true
		if slot.position.z < 0:
			errors.append("slot %s must be at a non-negative z level" % slot.id)
		for other_index in range(index):
			var other: Variant = _slots[other_index]
			if slot.position.z == other.position.z and slot.position.overlaps_footprint(other.position):
				errors.append("slots %s and %s overlap on the same z level" % [other.id, slot.id])

	return errors


func has_partial_overlap() -> bool:
	for index in range(_slots.size()):
		for other_index in range(index):
			var first: Variant = _slots[index].position
			var second: Variant = _slots[other_index].position
			if first.z != second.z and first.overlaps_footprint(second):
				var x_offset: int = absi(first.x - second.x)
				var y_offset: int = absi(first.y - second.y)
				if x_offset % 2 == 1 or y_offset % 2 == 1:
					return true
	return false


func content_hash() -> String:
	if _content_hash.is_empty():
		var parts: Array[String] = []
		for slot in _slots:
			parts.append("%s@%s" % [slot.id, slot.position.to_key()])
		_content_hash = ("%d|%s|%d|%s" % [SCHEMA_VERSION, id, revision, ",".join(parts)]).sha256_text()
	return _content_hash


func to_dict() -> Dictionary:
	var serialized_slots: Array = []
	for slot in _slots:
		serialized_slots.append(slot.to_dict())
	return {
		"schema_version": SCHEMA_VERSION,
		"layout_id": id,
		"revision": revision,
		"metadata": _metadata.duplicate(true),
		"slots": serialized_slots,
	}


func _slot_precedes(first: Variant, second: Variant) -> bool:
	if first.position.z != second.position.z:
		return first.position.z < second.position.z
	if first.position.y != second.position.y:
		return first.position.y < second.position.y
	if first.position.x != second.position.x:
		return first.position.x < second.position.x
	return first.id < second.id
