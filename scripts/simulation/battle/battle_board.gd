extends RefCounted

const Definition := preload("res://scripts/simulation/game_definition.gd")
const Data := preload("res://scripts/simulation/game_state_data.gd")
const Command := preload("res://scripts/simulation/game_command.gd")
const Processor := preload("res://scripts/simulation/game_command_processor.gd")
const Reducer := preload("res://scripts/simulation/game_reducer.gd")
const Insertion := preload("res://scripts/simulation/battle/battle_insertion.gd")
const Charge := preload("res://scripts/simulation/battle/battle_charge.gd")
const Momentum := preload("res://scripts/simulation/momentum_rules.gd")
const Rng := preload("res://scripts/simulation/deterministic_rng.gd")
const Configuration := preload("res://scripts/simulation/game_configuration.gd")

static func bind(state: Dictionary, serialized: Variant, tuning: Dictionary, seed: int, supplied_route: Array = []) -> String:
	if state.revision != 0 or not serialized is Dictionary or not serialized.get("tiles") is Array:
		return "invalid_board_binding"
	if serialized.tiles.size() != state.sides.player.remaining_pairs * 2 or serialized.tiles.size() > tuning.max_tiles:
		return "invalid_board_workload"
	var seen := {}
	for tile in serialized.tiles:
		if not tile is Dictionary or not tile.get("tile_id") is String or tile.tile_id.is_empty() or tile.tile_id.begins_with("attack_") or seen.has(tile.tile_id) \
				or not tile.get("position") is Dictionary or not tile.get("face_family") is String or not tile.get("face_value") is String:
			return "invalid_board_tile"
		for axis in ["x", "y", "z"]:
			if not tile.position.get(axis) is int:
				return "invalid_board_position"
		seen[tile.tile_id] = true
	# Binding is a typed in-memory GameDefinition snapshot, not a JSON importer.
	for key in ["configuration", "modifier_attachments", "consumable_inventory"]:
		if not serialized.get(key) is Dictionary:
			return "invalid_board_definition"
	for key in ["modifier_loadout", "flipped_tile_ids"]:
		if not serialized.get(key) is Array:
			return "invalid_board_definition"
	for key in ["seed", "schema_version", "rules_version"]:
		if not serialized.get(key) is int:
			return "invalid_board_definition"
	var defaults := Configuration.create()
	for key in defaults:
		var value: Variant = serialized.configuration.get(key, defaults[key])
		if typeof(value) != typeof(defaults[key]):
			return "invalid_board_configuration"
		if value is int and value < 0:
			return "invalid_board_configuration"
		if value is Array:
			if value.size() != defaults[key].size():
				return "invalid_board_configuration"
			for number in value:
				if not number is int or number < 0:
					return "invalid_board_configuration"
	if int(serialized.configuration.get("tray_capacity", 4)) < 2:
		return "invalid_board_configuration"
	var definition := Definition.from_dict(serialized)
	if definition == null or definition.rules_version != Definition.CURRENT_RULES_VERSION:
		return "unsupported_board_rules"
	var data := Data.new(definition)
	if not Insertion.geometry_valid(Insertion.active_slots(serialized, data.to_dict()), [], tuning.max_layer):
		return "invalid_board_geometry"
	var planner := Insertion.new()
	var route: Array[String] = []
	if not supplied_route.is_empty():
		if supplied_route.size() != serialized.tiles.size():
			return "invalid_board_route"
		for id in supplied_route:
			if not id is String:
				return "invalid_board_route"
			route.append(id)
	else:
		route = planner.find_route(definition, data, tuning.solver_nodes)
	if route.is_empty() or not Insertion.Solver.new().verify_state_route(definition, data, route).valid:
		return "uncertified_board"
	state.player_board = {"original_definition": serialized.duplicate(true), "definition": serialized.duplicate(true),
		"state": data.to_dict(), "rng_state": Rng.new(seed).get_state(), "applied_attacks": [], "route": route}
	return ""

static func deliver(state: Dictionary, tuning: Dictionary, events: Array) -> void:
	if state.player_board.is_empty():
		return
	var board: Dictionary = state.player_board
	for attack in state.landed_attacks:
		if attack.target != "player" or attack.id in board.applied_attacks:
			continue
		var plan := Insertion.new().plan(board, attack, tuning)
		if plan.status == "unverified":
			events.append({"type": "attack_insertion_deferred", "attack_id": attack.id, "reason": plan.reason})
			break
		if plan.status != "inserted":
			state.status = "cpu_won"
			state.winner = "cpu"
			events.append({"type": "board_overflow", "attack_id": attack.id, "reason": plan.reason})
			return
		board.definition = plan.definition
		board.state = plan.state
		board.rng_state = plan.rng_state
		board.route = plan.route
		board.applied_attacks.append(attack.id)
		state.sides.player.remaining_pairs += attack.pair_count
		events.append({"type": "attack_inserted", "attack_id": attack.id,
			"placements": plan.placements, "route": plan.route, "pair_count": attack.pair_count})

static func input(state: Dictionary, command: Dictionary, definition: Dictionary, events: Array) -> String:
	if state.player_board.is_empty() or command.side != "player" or command.get("action") not in ["select_tile", "reveal_tile", "break_combo"] \
			or not command.get("tile_id") is String:
		return "invalid_board_input"
	var board: Dictionary = state.player_board
	var effective := Definition.from_dict(board.definition)
	var before := Insertion.restore(board.state)
	var input_command := Command.new(command.action, {"tile_id": command.tile_id}, before.revision, command.id, "player", command.at_ms)
	var built := Processor.new().build_transaction(input_command, effective, before, [])
	if not built.has("transaction"):
		return str(built.get("result", "invalid_board_command"))
	var transaction: RefCounted = built.transaction
	var after: Variant = Reducer.new().apply_forward(effective, before, transaction)
	if after == null:
		return "invalid_board_transaction"
	transaction.previous_state_hash = before.state_hash()
	transaction.next_state_hash = after.state_hash()
	var pairs: int = after.resolved_pair_count - before.resolved_pair_count
	var layers: Array = []
	var before_layers := _layers(effective, before)
	var after_layers := _layers(effective, after)
	if pairs > 0:
		for layer in before_layers:
			if not after_layers.has(layer):
				layers.append(layer)
	layers.sort()
	var event := {"source_hash": Definition.from_dict(board.original_definition).definition_hash(),
		"source_revision": state.player_charge.source_revision + 1, "at_ms": command.at_ms,
		"pair_count": pairs, "natural_pairs": 1 if transaction.result in ["pair_resolved", "flipped_pair_resolved"] else 0,
		"score": after.score, "streak": after.combo_count, "momentum_units": after.momentum_units,
		"momentum_tier": Momentum.multiplier_for(after.momentum_units, effective.configuration), "cleared_layers": layers}
	var error := Charge.event_error(event, state)
	if not error.is_empty():
		return error
	error = Charge.apply(state, event, definition.charge, definition.attacks, events, definition.payload)
	if not error.is_empty():
		return error
	board.state = after.to_dict()
	board.route = []
	if after.status == "lost":
		state.status = "cpu_won"
		state.winner = "cpu"
	events.append({"type": "board_transaction", "transaction": transaction.to_dict()})
	return ""

static func _layers(definition: RefCounted, state: RefCounted) -> Dictionary:
	var layers := {}
	for tile in definition.tiles:
		if state.tile_zones[tile.id] != "resolved":
			layers[definition.get_tile(state.tile_slot_ids[tile.id]).position.z] = true
	return layers
