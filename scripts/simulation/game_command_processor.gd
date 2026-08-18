extends RefCounted

const BoardStateScript := preload("res://scripts/simulation/board_state.gd")
const GameChangeScript := preload("res://scripts/simulation/game_change.gd")
const GameCommandScript := preload("res://scripts/simulation/game_command.gd")
const GameStateDataScript := preload("res://scripts/simulation/game_state_data.gd")
const GameTransactionScript := preload("res://scripts/simulation/game_transaction.gd")

const SELECTED := "selected"
const PAIR_RESOLVED := "pair_resolved"
const INVALID_SELECTION := "invalid_selection"
const GAME_OVER := "game_over"
const UNDONE := "undone"
const NOTHING_TO_UNDO := "nothing_to_undo"
const STALE_COMMAND := "stale_command"
const UNKNOWN_COMMAND := "unknown_command"


func build_transaction(command: Variant, definition: Variant, state: Variant, timeline: Array) -> Dictionary:
	if command.expected_revision != state.revision:
		return {"result": STALE_COMMAND}

	match command.type:
		GameCommandScript.SELECT_TILE:
			return _build_select(command, definition, state)
		GameCommandScript.UNDO:
			return _build_undo(command, state, timeline)
		_:
			return {"result": UNKNOWN_COMMAND}


func _build_select(command: Variant, definition: Variant, state: Variant) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING:
		return {"result": GAME_OVER}

	var tile_id: String = str(command.payload.get("tile_id", ""))
	var board := BoardStateScript.new(definition, state)
	if not board.call("is_tile_selectable", tile_id):
		return {"result": INVALID_SELECTION}

	var changes: Array = []
	var tray_before: Array[String] = []
	tray_before.assign(state.tray_tile_ids)
	var tray_after: Array[String] = []
	tray_after.assign(tray_before)
	var matching_tile_id := _matching_tray_tile_id(definition, state, tile_id)
	var result := SELECTED

	if matching_tile_id.is_empty():
		tray_after.append(tile_id)
		changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_TRAY))
	else:
		tray_after.erase(matching_tile_id)
		changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_BOARD, GameStateDataScript.ZONE_RESOLVED))
		changes.append(GameChangeScript.new(GameChangeScript.TILE_ZONE, matching_tile_id, GameStateDataScript.ZONE_TRAY, GameStateDataScript.ZONE_RESOLVED))
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "resolved_pair_count", state.resolved_pair_count, state.resolved_pair_count + 1))
		result = PAIR_RESOLVED

	changes.append(GameChangeScript.new(GameChangeScript.TRAY, "tray_tile_ids", tray_before, tray_after))
	changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "selection_count", state.selection_count, state.selection_count + 1))
	var next_peak := maxi(state.max_tray_occupancy, tray_after.size())
	if next_peak != state.max_tray_occupancy:
		changes.append(GameChangeScript.new(GameChangeScript.COUNTER, "max_tray_occupancy", state.max_tray_occupancy, next_peak))

	var next_status: String = state.status
	if tray_after.size() == definition.tray_capacity():
		next_status = GameStateDataScript.LOST
		result = GAME_OVER
	elif _board_tile_count_after(state, changes) == 0 and tray_after.is_empty():
		next_status = GameStateDataScript.WON
	if next_status != state.status:
		changes.append(GameChangeScript.new(GameChangeScript.STATUS, "status", state.status, next_status))

	var transaction := GameTransactionScript.new(command, changes, result)
	transaction.definition_hash = definition.definition_hash()
	return {"result": result, "transaction": transaction}


func _build_undo(command: Variant, state: Variant, timeline: Array) -> Dictionary:
	if state.status != GameStateDataScript.PLAYING or state.tray_tile_ids.is_empty():
		return {"result": NOTHING_TO_UNDO}

	var tile_id: String = state.tray_tile_ids[-1]
	var target_transaction: Variant = _find_selection_transaction(timeline, tile_id)
	if target_transaction == null:
		return {"result": NOTHING_TO_UNDO}

	var tray_before: Array[String] = []
	tray_before.assign(state.tray_tile_ids)
	var tray_after: Array[String] = []
	tray_after.assign(tray_before)
	tray_after.pop_back()
	var changes: Array = [
		GameChangeScript.new(GameChangeScript.TILE_ZONE, tile_id, GameStateDataScript.ZONE_TRAY, GameStateDataScript.ZONE_BOARD),
		GameChangeScript.new(GameChangeScript.TRAY, "tray_tile_ids", tray_before, tray_after),
		GameChangeScript.new(GameChangeScript.COUNTER, "selection_count", state.selection_count, state.selection_count - 1),
	]
	var transaction := GameTransactionScript.new(command, changes, UNDONE, target_transaction.transaction_id)
	transaction.definition_hash = target_transaction.definition_hash
	return {"result": UNDONE, "transaction": transaction}


func _matching_tray_tile_id(definition: Variant, state: Variant, tile_id: String) -> String:
	var tile: Variant = definition.get_tile(tile_id)
	for held_tile_id in state.tray_tile_ids:
		if definition.get_tile(held_tile_id).face.equals(tile.face):
			return held_tile_id
	return ""


func _board_tile_count_after(state: Variant, changes: Array) -> int:
	var count := 0
	for zone in state.tile_zones.values():
		if zone == GameStateDataScript.ZONE_BOARD:
			count += 1
	for change in changes:
		if change.type == GameChangeScript.TILE_ZONE and change.before == GameStateDataScript.ZONE_BOARD:
			count -= 1
	return count


func _find_selection_transaction(timeline: Array, tile_id: String) -> Variant:
	for index in range(timeline.size() - 1, -1, -1):
		var transaction: Variant = timeline[index]
		if transaction.command_type != GameCommandScript.SELECT_TILE:
			continue
		for change in transaction.changes:
			if change.type == GameChangeScript.TILE_ZONE \
					and change.target == tile_id \
					and change.after == GameStateDataScript.ZONE_TRAY:
				return transaction
	return null
