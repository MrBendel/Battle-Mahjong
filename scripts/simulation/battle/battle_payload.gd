extends RefCounted

const Rng := preload("res://scripts/simulation/deterministic_rng.gd")
const Face := preload("res://scripts/simulation/tile_face.gd")

static func validation_errors(tuning: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if tuning.size() != 2 or not tuning.get("max_pairs") is int or tuning.max_pairs < 1 or tuning.max_pairs > 1024:
		errors.append("Payload max_pairs must be an integer from 1 to 1024.")
	if not tuning.get("faces") is Array or tuning.faces.is_empty() or tuning.faces.size() > 58:
		errors.append("Payload requires a nonempty supported face pool.")
		return errors
	var seen := {}
	for face in tuning.faces:
		if not face is Dictionary or face.size() != 2 or not face.get("family") is String or not face.get("value") is String:
			errors.append("Invalid payload face.")
			continue
		var valid := false
		match face.family:
			"reference":
				valid = face.value in _values(24, true)
			"bamboo", "dots", "characters":
				valid = face.value in _values(9, false)
			"wind":
				valid = face.value in ["east", "south", "west", "north"]
			"dragon":
				valid = face.value in ["red_dragon", "green_dragon", "white_dragon"]
		var identity: String = Face.new(face.family, face.value).logical_id()
		if not valid or seen.has(identity):
			errors.append("Unsupported or duplicate payload face: %s" % identity)
		seen[identity] = true
	return errors

static func _values(count: int, padded: bool) -> Array[String]:
	var values: Array[String] = []
	for index in range(1, count + 1):
		values.append(("%02d" if padded else "%d") % index)
	return values

## Draw without replacement within each attack; refill only after exhausting
## the pool. Independent RNG state prevents attacks from changing CPU cadence.
static func generate(state: Dictionary, attack_id: String, count: int, tuning: Dictionary) -> Array:
	var rng := Rng.new(state.payload_rng_state)
	var bag: Array = []
	var pairs: Array = []
	for index in count:
		if bag.is_empty():
			bag = tuning.faces.duplicate(true)
		var face: Dictionary = bag.pop_at(rng.range_int(0, bag.size() - 1))
		var pair_id := "%s_pair_%d" % [attack_id, index]
		var tiles: Array = []
		for member in 2:
			tiles.append({"id": "%s_tile_%d" % [pair_id, member],
				"face_family": face.family, "face_value": face.value})
		pairs.append({"id": pair_id, "tiles": tiles})
	state.payload_rng_state = rng.get_state()
	return pairs
