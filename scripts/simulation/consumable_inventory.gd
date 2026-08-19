extends RefCounted

const HINT := "hint"
const UNDO := "undo"
const DELETE_PAIR := "delete_pair"
const SHUFFLE := "shuffle"
const TYPES := [HINT, UNDO, DELETE_PAIR, SHUFFLE]


static func starter() -> Dictionary:
	return {HINT: 1, UNDO: 1, DELETE_PAIR: 1, SHUFFLE: 1}


static func normalize(inventory: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var normalized := {}
	for key in inventory:
		var type := str(key)
		var count := int(inventory[key])
		if type not in TYPES:
			errors.append("Unknown consumable type '%s'." % type)
			continue
		if count < 0:
			errors.append("Consumable '%s' count cannot be negative." % type)
			continue
		normalized[type] = count
	for type in TYPES:
		if not normalized.has(type):
			normalized[type] = 0
	return {"inventory": normalized, "errors": errors}
