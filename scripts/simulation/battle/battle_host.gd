extends RefCounted

const Store := preload("res://scripts/simulation/battle/battle_store.gd")
const Board := preload("res://scripts/simulation/board_state.gd")
const GameDefinition := preload("res://scripts/simulation/game_definition.gd")
const Insertion := preload("res://scripts/simulation/battle/battle_insertion.gd")
const MAX_EVENTS := 128
const Reactions := preload("res://scripts/simulation/battle/battle_reactions.gd")
var reaction_tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://configuration/battle/reaction_cues.json"))
var opening_events: Array = []
var store: RefCounted
var _time := 0

func _init(definition: Dictionary, game_definition: RefCounted, route: Array = []) -> void:
	store = Store.new(definition)
	var bound: Dictionary = store.submit({"id": "bind", "expected_revision": 0,
		"type": "bind_board", "side": "player", "game_definition": game_definition.to_dict(), "route": route})
	if not bound.accepted:
		store = null
	else:
		_append_events(opening_events, bound.transaction)

func _append_events(events: Array, transaction: Dictionary) -> void:
	events.append_array(transaction.get("events", []))
	for cue in Reactions.project(transaction, reaction_tuning):
		events.append({"type": "character_reaction", "cue": cue, "revision": transaction.after.revision})

func next_event_ms() -> int:
	if store == null:
		return -1
	var state: Dictionary = store.snapshot()
	if state.status != "playing":
		return -1
	var next: int = state.cpu_schedule.next_event_ms
	for side in ["player", "cpu"]:
		for attack in state.sides[side].pending_attacks:
			next = mini(next, attack.lands_at_ms)
	return next

## CPU input wins exact input ties; the store lands attacks before either input.
## No idle clock transactions: polling frequency cannot change the timeline.
func advance_to(at_ms: int) -> Dictionary:
	if store == null or at_ms < _time or at_ms > 1000000000:
		return {"accepted": false, "reason": "invalid_host_time"}
	var events: Array = []
	for unused in MAX_EVENTS:
		var due := next_event_ms()
		if due < 0 or due > at_ms:
			_time = at_ms
			return {"accepted": true, "events": events, "pending": false}
		var state: Dictionary = store.snapshot()
		var cpu: bool = due == state.cpu_schedule.next_event_ms
		var result: Dictionary = store.submit({"id": "host_%d" % state.revision,
			"expected_revision": state.revision, "type": "cpu_step" if cpu else "advance_attacks",
			"side": "cpu" if cpu else "player", "at_ms": due})
		if not result.accepted:
			result["events"] = events
			return result
		_append_events(events, result.transaction)
	return {"accepted": true, "events": events, "pending": true}

func tap(tile_id: String, at_ms: int) -> Dictionary:
	var advanced := advance_to(at_ms)
	if not advanced.accepted or advanced.get("pending", false):
		return advanced
	var state: Dictionary = store.snapshot()
	if state.status != "playing":
		return {"accepted": false, "reason": "battle_finished", "events": advanced.events}
	var board: Dictionary = state.player_board
	var face_down: bool = tile_id in board.definition.flipped_tile_ids and tile_id not in board.state.revealed_flipped_tile_ids
	var view := Board.new(GameDefinition.from_dict(board.definition), Insertion.restore(board.state))
	var action := "reveal_tile" if face_down else "select_tile"
	if board.state.tile_zones.get(tile_id) == "board" and not view.is_tile_accessible(tile_id):
		action = "break_combo"
	var result: Dictionary = store.submit({"id": "tap_%d" % state.revision, "expected_revision": state.revision,
		"type": "board_input", "side": "player", "action": action,
		"tile_id": tile_id, "at_ms": at_ms})
	if result.accepted:
		_append_events(advanced.events, result.transaction)
	result["events"] = advanced.events
	return result
