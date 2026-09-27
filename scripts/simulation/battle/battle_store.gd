extends RefCounted

const Definition := preload("res://scripts/simulation/battle/battle_definition.gd")
const State := preload("res://scripts/simulation/battle/battle_state.gd")
const CLEAR_PAIRS := "clear_pairs"
const ADD_WORK := "add_work"
const SET_STATS := "set_stats"
const CPU_STEP := "cpu_step"
const Attacks := preload("res://scripts/simulation/battle/battle_attacks.gd")
const SEND_ATTACK := "send_attack"
const ADVANCE_ATTACKS := "advance_attacks"
const BattleBoard := preload("res://scripts/simulation/battle/battle_board.gd")
const BIND_BOARD := "bind_board"
const BOARD_INPUT := "board_input"
const PLAYER_EVENT := "player_event"
const Charge := preload("res://scripts/simulation/battle/battle_charge.gd")
const Cpu := preload("res://scripts/simulation/battle/battle_cpu.gd")

var _definition: Dictionary = {}
var _state: Dictionary = {}
var _timeline: Array[Dictionary] = []
var _command_ids: Dictionary = {}
var _errors: Array[String] = []


func _init(definition: Dictionary) -> void:
	_errors = Definition.validation_errors(definition)
	if not _errors.is_empty():
		return
	_definition = definition.duplicate(true)
	_state = State.initial(_definition)


func validation_errors() -> Array[String]:
	return _errors.duplicate()


func definition_snapshot() -> Dictionary:
	return _definition.duplicate(true)


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func transactions() -> Array[Dictionary]:
	return _timeline.duplicate(true)


func submit(command: Dictionary) -> Dictionary:
	var built := _build(command)
	if not built.accepted:
		return built
	return _commit(built.transaction)


## Recompute before accepting a recorded transaction: malformed, reordered,
## duplicated, or tampered records cannot partially change Battle state.
func apply_transaction(transaction: Dictionary) -> Dictionary:
	if not transaction.get("command") is Dictionary:
		return _reject("invalid_transaction")
	var built := _build(transaction.command)
	if not built.accepted or built.transaction != transaction:
		return _reject("invalid_transaction")
	return _commit(built.transaction)


func _build(command: Dictionary) -> Dictionary:
	if not _errors.is_empty():
		return _reject("invalid_definition")
	if not command.get("id") is String or command.id.strip_edges().is_empty():
		return _reject("invalid_command_id")
	if _command_ids.has(command.id):
		return _reject("duplicate_command")
	if not command.get("expected_revision") is int or command.expected_revision != _state.revision:
		return _reject("stale_revision")
	if _state.status != State.PLAYING:
		return _reject("battle_finished")
	if command.get("side") not in [State.PLAYER, State.CPU]:
		return _reject("invalid_side")
	var type: String = str(command.get("type", ""))
	if type not in [CLEAR_PAIRS, ADD_WORK, SET_STATS, CPU_STEP, PLAYER_EVENT, SEND_ATTACK, ADVANCE_ATTACKS, BIND_BOARD, BOARD_INPUT]:
		return _reject("invalid_command_type")
	var allowed := ["id", "expected_revision", "side", "type"]
	allowed.append("event" if type == PLAYER_EVENT else "at_ms" if type == CPU_STEP else "stats" if type == SET_STATS else "pair_count")
	if type in [SEND_ATTACK, ADVANCE_ATTACKS]:
		allowed = ["id", "expected_revision", "side", "type", "at_ms"]
		if type == SEND_ATTACK:
			allowed.append("pair_count")
	if type == BIND_BOARD:
		allowed = ["id", "expected_revision", "side", "type", "game_definition"]
		if _definition.rules_version >= 8:
			allowed.append("route")
	elif type == BOARD_INPUT:
		allowed = ["id", "expected_revision", "side", "type", "action", "tile_id", "at_ms"]
	for key in command:
		if key not in allowed:
			return _reject("unknown_command_field")
	if type in [BIND_BOARD, BOARD_INPUT] and _definition.rules_version < 6:
		return _reject("board_unavailable")
	if _state.has("player_board") and not _state.player_board.is_empty() and (type == PLAYER_EVENT or (command.side == "player" and type in [CLEAR_PAIRS, ADD_WORK, SET_STATS])):
		return _reject("bound_board_owns_player_state")
	var candidate := _state.duplicate(true)
	var side: Dictionary = candidate.sides[command.side]
	var events: Array = []
	if type in [SEND_ATTACK, ADVANCE_ATTACKS] and _definition.rules_version < 4:
		return _reject("attacks_unavailable")
	if _definition.rules_version >= 4 and type in [CPU_STEP, PLAYER_EVENT, SEND_ATTACK, ADVANCE_ATTACKS, BOARD_INPUT]:
		var at_ms: Variant = command.get("at_ms")
		if type == PLAYER_EVENT and command.get("event") is Dictionary:
			at_ms = command.event.get("at_ms")
		var time_error := Attacks.advance(candidate, at_ms, events)
		if not time_error.is_empty():
			return _reject(time_error)
	# Reject malformed intent before a due insertion can terminate the battle.
	if type == SEND_ATTACK and (not _counter(command.get("pair_count")) or command.pair_count == 0):
		return _reject("invalid_pair_count")
	if type == CPU_STEP and (_definition.rules_version < 2 or command.side != State.CPU or command.get("at_ms") != candidate.cpu_schedule.next_event_ms):
		return _reject("invalid_cpu_time")
	if type == BOARD_INPUT and command.get("action") == "break_combo" and _definition.rules_version < 8:
		return _reject("invalid_board_input")
	if type == BOARD_INPUT and (candidate.player_board.is_empty() or command.side != State.PLAYER \
			or command.get("action") not in ["select_tile", "reveal_tile", "break_combo"] or not command.get("tile_id") is String \
			or not candidate.player_board.state.tile_zones.has(command.tile_id)):
		return _reject("invalid_board_input")
	if _definition.rules_version >= 7 and type in [CPU_STEP, PLAYER_EVENT, SEND_ATTACK, ADVANCE_ATTACKS, BOARD_INPUT]:
		var pressure_error := _deliver_cpu_pressure(candidate, events)
		if not pressure_error.is_empty():
			return _reject(pressure_error)
	if _definition.rules_version >= 6 and type in [CPU_STEP, SEND_ATTACK, ADVANCE_ATTACKS, BOARD_INPUT]:
		BattleBoard.deliver(candidate, _definition.insertion, events)
	if candidate.status != State.PLAYING:
		pass
	elif type == BIND_BOARD:
		if command.side != "player":
			return _reject("invalid_board_side")
		if not command.get("route", []) is Array:
			return _reject("invalid_board_route")
		var error := BattleBoard.bind(candidate, command.get("game_definition"), _definition.insertion, _definition.seed, command.get("route", []))
		if not error.is_empty():
			return _reject(error)
	elif type == BOARD_INPUT:
		var error := BattleBoard.input(candidate, command, _definition, events)
		if not error.is_empty():
			return _reject(error)
	elif type == PLAYER_EVENT:
		if _definition.rules_version < 3 or command.side != State.PLAYER or not command.get("event") is Dictionary:
			return _reject("invalid_player_event")
		var error := Charge.event_error(command.event, candidate)
		if not error.is_empty():
			return _reject(error)
		error = Charge.apply(candidate, command.event, _definition.charge, _definition.get("attacks", {}), events, _definition.get("payload", {}))
		if not error.is_empty():
			return _reject(error)
	elif type == CPU_STEP:
		if _definition.rules_version < 2 or command.side != State.CPU:
			return _reject("cpu_unavailable")
		if not command.get("at_ms") is int or command.at_ms != candidate.cpu_schedule.next_event_ms \
				or command.at_ms > Cpu.MAX_TIME_MS:
			return _reject("invalid_cpu_time")
		var cleared_before: int = candidate.sides.cpu.cleared_pairs
		Cpu.step(candidate, _definition.cpu)
		if _definition.rules_version >= 8 and candidate.status == State.PLAYING and candidate.sides.cpu.cleared_pairs > cleared_before:
			var total: int = candidate.sides.cpu.attack_charge_units + _definition.cpu_attack_charge_units
			var pairs := int(total / int(_definition.charge.attack_threshold_units))
			candidate.sides.cpu.attack_charge_units = total % int(_definition.charge.attack_threshold_units)
			if pairs > 0:
				var error := Attacks.send(candidate, State.CPU, pairs, _definition.attacks, events, _definition.payload)
				if not error.is_empty():
					return _reject(error)
	elif type == SEND_ATTACK:
		if not _counter(command.get("pair_count")) or command.pair_count == 0:
			return _reject("invalid_pair_count")
		var error := Attacks.send(candidate, command.side, command.pair_count, _definition.attacks, events, _definition.get("payload", {}))
		if not error.is_empty():
			return _reject(error)
	elif type == ADVANCE_ATTACKS:
		pass
	elif type == SET_STATS:
		if not command.get("stats") is Dictionary or command.stats.is_empty():
			return _reject("invalid_stats")
		for key in command.stats:
			if key not in ["score", "streak", "momentum_units"] or not _counter(command.stats[key]):
				return _reject("invalid_stats")
			side[key] = command.stats[key]
	else:
		if not _counter(command.get("pair_count")) or command.pair_count == 0:
			return _reject("invalid_pair_count")
		var count: int = command.pair_count
		if type == CLEAR_PAIRS:
			if count > side.remaining_pairs:
				return _reject("too_many_pairs")
			side.remaining_pairs -= count
			side.cleared_pairs += count
			if side.remaining_pairs == 0:
				candidate.winner = command.side
				candidate.status = State.PLAYER_WON if command.side == State.PLAYER else State.CPU_WON
		else:
			if side.remaining_pairs + side.cleared_pairs + count > Definition.MAX_COUNTER:
				return _reject("work_limit")
			side.remaining_pairs += count
	candidate.revision += 1
	var transaction := {
		"schema_version": 1,
		"definition": _definition.duplicate(true),
		"command": command.duplicate(true),
		"before": _state.duplicate(true),
		"after": candidate,
	}
	if _definition.rules_version >= 4:
		transaction["events"] = events
	return {"accepted": true, "transaction": transaction}


func _commit(transaction: Dictionary) -> Dictionary:
	_state = transaction.after.duplicate(true)
	_command_ids[transaction.command.id] = true
	_timeline.append(transaction.duplicate(true))
	return {"accepted": true, "transaction": transaction.duplicate(true)}


func _counter(value: Variant) -> bool:
	return value is int and value >= 0 and value <= Definition.MAX_COUNTER


func _reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


## Preserve the existing solve deadline and RNG: attacks add work, not a stun.
func _deliver_cpu_pressure(candidate: Dictionary, events: Array) -> String:
	var cpu: Dictionary = candidate.sides.cpu
	for attack in candidate.landed_attacks:
		if attack.target != State.CPU or attack.id in candidate.cpu_applied_attacks:
			continue
		if cpu.cleared_pairs + cpu.remaining_pairs + attack.pair_count > Definition.MAX_COUNTER:
			return "work_limit"
		var before: int = cpu.remaining_pairs
		cpu.remaining_pairs += attack.pair_count
		candidate.cpu_applied_attacks.append(attack.id)
		events.append({"type": "cpu_pressure_applied", "attack_id": attack.id,
			"at_ms": attack.lands_at_ms, "pair_count": attack.pair_count,
			"remaining_before": before, "remaining_after": cpu.remaining_pairs})
	return ""
