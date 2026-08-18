extends RefCounted

const SELECT_TILE := "select_tile"
const UNDO := "undo"

var command_id: String
var actor_id: String
var expected_revision: int
var type: String
var payload: Dictionary


func _init(
		command_type: String,
		command_payload: Dictionary,
		revision: int,
		id: String = "",
		actor: String = "local"
) -> void:
	type = command_type
	payload = command_payload.duplicate(true)
	expected_revision = revision
	command_id = id if not id.is_empty() else "cmd_%06d" % (revision + 1)
	actor_id = actor


func to_dict() -> Dictionary:
	return {
		"command_id": command_id,
		"actor_id": actor_id,
		"expected_revision": expected_revision,
		"type": type,
		"payload": payload.duplicate(true),
	}
