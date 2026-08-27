extends RefCounted

const EXTRA_LIFE := "extra_life"
const COLD_SNAP := "cold_snap"
const SCORE_MULTIPLIER := "score_multiplier"
const TRAY_PLUS_ONE := "tray_plus_one"

const TYPES := [EXTRA_LIFE, COLD_SNAP, SCORE_MULTIPLIER, TRAY_PLUS_ONE]


static func starter() -> Array:
	return [{
		"modifier_id": "starter_multiplier",
		"type": SCORE_MULTIPLIER,
		"level": 0,
	}]


static func playtest_all() -> Array:
	var loadout: Array = []
	for type in TYPES:
		loadout.append({
			"modifier_id": "playtest_%s" % type,
			"type": type,
			"level": 0,
		})
	return loadout


static func normalize(entries: Array, capacity: int) -> Dictionary:
	var errors: Array[String] = []
	var normalized: Array = []
	var ids := {}
	var types := {}
	if capacity < 0:
		errors.append("Modifier loadout capacity cannot be negative.")
	if entries.size() > capacity:
		errors.append("Modifier loadout contains %d entries but capacity is %d." % [entries.size(), capacity])

	for index in range(entries.size()):
		if not entries[index] is Dictionary:
			errors.append("Modifier loadout entry %d must be a dictionary." % index)
			continue
		var entry: Dictionary = entries[index]
		var modifier_id := str(entry.get("modifier_id", ""))
		var type := str(entry.get("type", ""))
		var level := int(entry.get("level", -1))
		if modifier_id.is_empty():
			errors.append("Modifier loadout entry %d requires a modifier_id." % index)
		elif ids.has(modifier_id):
			errors.append("Modifier id '%s' is duplicated." % modifier_id)
		if type not in TYPES:
			errors.append("Modifier '%s' has unknown type '%s'." % [modifier_id, type])
		elif types.has(type):
			errors.append("M5 allows at most one equipped modifier of each type: '%s'." % type)
		if level < 0:
			errors.append("Modifier '%s' level cannot be negative." % modifier_id)
		if modifier_id.is_empty() or type not in TYPES or level < 0 or ids.has(modifier_id) or types.has(type):
			continue
		ids[modifier_id] = true
		types[type] = true
		normalized.append({
			"modifier_id": modifier_id,
			"type": type,
			"level": level,
		})

	return {"loadout": normalized, "errors": errors}
