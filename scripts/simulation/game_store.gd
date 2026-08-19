extends RefCounted

const GameCommandProcessorScript := preload("res://scripts/simulation/game_command_processor.gd")
const GameReducerScript := preload("res://scripts/simulation/game_reducer.gd")

var _definition: Variant
var _state: Variant
var _timeline: Array = []
var _processor := GameCommandProcessorScript.new()
var _reducer := GameReducerScript.new()


func _init(definition: Variant, initial_state: Variant) -> void:
	_definition = definition
	_state = initial_state


func submit_command(command: Variant) -> Dictionary:
	var built: Dictionary = _processor.call("build_transaction", command, _definition, _state, _timeline)
	if not built.has("transaction"):
		return {"accepted": false, "result": built.get("result", "rejected")}

	var transaction: Variant = built.transaction
	var candidate: Variant = _reducer.call("apply_forward", _definition, _state, transaction)
	if candidate == null:
		return {"accepted": false, "result": "invalid_transaction"}

	transaction.previous_state_hash = _state.state_hash()
	transaction.next_state_hash = candidate.state_hash()
	return _commit(candidate, transaction)


func apply_transaction(transaction: Variant) -> Dictionary:
	if transaction == null or not transaction.has_method("duplicate_transaction"):
		return {"accepted": false, "result": "invalid_transaction"}
	var owned_transaction: Variant = transaction.call("duplicate_transaction")
	var candidate: Variant = _reducer.call("apply_forward", _definition, _state, owned_transaction)
	if candidate == null:
		return {"accepted": false, "result": "invalid_transaction"}
	return _commit(candidate, owned_transaction)


func _commit(candidate: Variant, transaction: Variant) -> Dictionary:
	_state.assign_from(candidate)
	_timeline.append(transaction)
	return {
		"accepted": true,
		"result": transaction.result,
		"transaction": transaction.call("duplicate_transaction"),
	}


func current_state() -> Variant:
	return _state.duplicate_data()


func transactions() -> Array:
	var copies: Array = []
	for transaction in _timeline:
		copies.append(transaction.call("duplicate_transaction"))
	return copies


func transactions_since(revision: int) -> Array:
	var copies: Array = []
	for transaction in _timeline:
		if transaction.revision > revision:
			copies.append(transaction.call("duplicate_transaction"))
	return copies


func last_transaction() -> Variant:
	if _timeline.is_empty():
		return null
	return _timeline[-1].call("duplicate_transaction")


func can_undo() -> bool:
	return _processor.call("can_undo", _state, _timeline)
